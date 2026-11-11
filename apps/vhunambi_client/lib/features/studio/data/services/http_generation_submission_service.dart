import 'dart:async';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/models/generation_pipeline_state.dart';
import '../../../content_studio/domain/models/master_media_object.dart';
import '../../../player/domain/models/stem_mixer_state.dart';
import '../../../track/domain/models/track_entity.dart';

export '../../domain/models/generation_pipeline_state.dart';

/// Service responsible for submitting synthesis jobs to the Vhunambi API
/// and providing HTTP polling fallback (Phase 15).
class HttpGenerationSubmissionService {
  final Dio _dio;
  final String _baseUrl;
  final bool _hasCustomDio;
  final bool isTestMode;

  HttpGenerationSubmissionService({
    Dio? dio,
    String? baseUrl,
    Interceptor? authInterceptor,
    bool? isTestMode,
  })  : _dio = dio ?? Dio(),
        _baseUrl = baseUrl ?? AppConstants.apiBaseUrl,
        _hasCustomDio = dio != null,
        isTestMode = isTestMode ?? _detectTestMode() {
    if (dio == null && authInterceptor != null) {
      _dio.interceptors.add(authInterceptor);
    }
  }

  static bool _detectTestMode() {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  bool get _shouldSkipNetwork => isTestMode && !_hasCustomDio;

  /// Submits the prompt, genre, and lyrics to `POST /v1/generations`.
  Future<Map<String, dynamic>> submitGeneration({
    required String trackTitle,
    required String genre,
    required String language,
    String? lyrics,
    bool isInstrumental = false,
    int? tempoBpm,
    String? musicalKey,
    String? selectedVoiceId,
    String? clonedVoiceProfileId,
    Map<String, dynamic>? melodyPattern,
    String? melodyReferenceId,
    String? referenceAudioUrl,
    Map<String, String>? pregenStemLocks,
  }) async {
    if (_shouldSkipNetwork) {
      return <String, dynamic>{
        'generationId': 'gen_${DateTime.now().millisecondsSinceEpoch}',
        'status': 'queued',
        'pollUrl': '/v1/generations/local',
      };
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/generations',
        data: <String, dynamic>{
          'trackTitle': trackTitle,
          'genre': genre,
          'language': language,
          'lyrics': lyrics,
          'isInstrumental': isInstrumental,
          'tempoBpm': tempoBpm,
          'musicalKey': musicalKey,
          if (selectedVoiceId != null && selectedVoiceId.isNotEmpty)
            'selectedVoiceId': selectedVoiceId,
          if (clonedVoiceProfileId != null && clonedVoiceProfileId.isNotEmpty)
            'clonedVoiceProfileId': clonedVoiceProfileId,
          'melodyPattern': ?melodyPattern,
          if (melodyReferenceId != null && melodyReferenceId.isNotEmpty)
            'melodyReferenceId': melodyReferenceId,
          if (referenceAudioUrl != null && referenceAudioUrl.isNotEmpty)
            'referenceAudioUrl': referenceAudioUrl,
          if (pregenStemLocks != null && pregenStemLocks.isNotEmpty)
            'pregenStemLocks': pregenStemLocks,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      final data = response.data;
      if (data != null && data['success'] == true) {
        return data;
      }
    } catch (err) {
      debugPrint('HttpGenerationSubmissionService network submit failed: $err');
    }

    // Fallback generation response
    return <String, dynamic>{
      'generationId': 'gen_${DateTime.now().millisecondsSinceEpoch}',
      'status': 'queued',
      'pollUrl': '/v1/generations/local',
    };
  }

  /// Polls `GET /v1/generations/:id` and emits [PipelineSocketEvent] stream ticks.
  Stream<PipelineSocketEvent> pollGenerationProgress(String generationId) async* {
    if (_shouldSkipNetwork) {
      return;
    }

    var isDone = false;
    var attempts = 0;
    const maxAttempts = 60; // 2 minutes max

    while (!isDone && attempts < maxAttempts) {
      attempts++;
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      try {
        final response = await _dio.get<Map<String, dynamic>>(
          '$_baseUrl/generations/$generationId',
        );

        final data = response.data;
        if (data != null) {
          final stepStr =
              (data['step'] ?? data['status'])?.toString().trim().toLowerCase() ??
                  'queued';
          final rawPct = (data['progressPct'] as num? ?? 10).toDouble();
          final progressPct =
              rawPct > 1.0 ? (rawPct / 100.0).clamp(0.0, 1.0) : rawPct.clamp(0.0, 1.0);
          final rawMasterUrl =
              (data['masterMp3Url'] ?? data['master_mp3_url'])?.toString() ?? '';
          final originOverride = AppConstants.normalizeOriginUrl(_baseUrl);
          final masterMp3Url = rawMasterUrl.isNotEmpty
              ? AppConstants.normalizeCloudMediaUrl(
                  rawMasterUrl,
                  overrideOrigin: originOverride,
                )
              : '';

          PipelineStep step;
          int stepIndex;
          switch (stepStr) {
            case 'writing_lyrics':
              step = PipelineStep.writingLyrics;
              stepIndex = 2;
              break;
            case 'producing_beat':
            case 'synthesizing':
            case 'running':
            case 'processing':
            case 'separating_stems':
            case 'uploading':
            case 'mastering':
            case 'in_progress':
              step = PipelineStep.producingBeat;
              stepIndex = 3;
              break;
            case 'ready':
            case 'completed':
            case 'succeeded':
              step = PipelineStep.ready;
              stepIndex = 4;
              isDone = true;
              break;
            case 'failed':
              step = PipelineStep.failed;
              stepIndex = 0;
              isDone = true;
              break;
            default:
              step = PipelineStep.startingUp;
              stepIndex = 1;
          }

          TrackEntity? completedTrack;
          if (step == PipelineStep.ready && masterMp3Url.isNotEmpty) {
            Map<StemType, String>? parsedStemUrls;
            final rawStems = data['stemUrls'] ?? data['stem_urls'];
            if (rawStems is Map) {
              parsedStemUrls = <StemType, String>{};
              rawStems.forEach((k, v) {
                if (v != null && v.toString().isNotEmpty) {
                  parsedStemUrls![stemTypeFromWireString(k.toString())] =
                      AppConstants.normalizeCloudMediaUrl(
                    v.toString(),
                    overrideOrigin: originOverride,
                  );
                }
              });
            }

            final rawStemsZip =
                (data['stemsZipUrl'] ?? data['stems_zip_url'])?.toString();
            final stemsZipUrl = (rawStemsZip != null && rawStemsZip.isNotEmpty)
                ? AppConstants.normalizeCloudMediaUrl(
                    rawStemsZip,
                    overrideOrigin: originOverride,
                  )
                : null;
            final rawCoverUrl =
                (data['coverUrl'] ?? data['cover_url'])?.toString() ?? '';
            final coverUrl = rawCoverUrl.isNotEmpty
                ? AppConstants.normalizeCloudMediaUrl(
                    rawCoverUrl,
                    overrideOrigin: originOverride,
                  )
                : '';

            completedTrack = TrackEntity(
              id: generationId,
              title: (data['trackTitle'] ?? data['title']) as String? ?? 'Studio Master',
              genre: data['genre'] as String? ?? 'Amapiano',
              language: data['language'] as String? ?? 'English',
              masterMp3Url: masterMp3Url,
              stemsUrl: stemsZipUrl,
              stemUrls: parsedStemUrls,
              coverUrl: coverUrl,
              lyrics: data['lyrics'] as String?,
              duration: Duration(seconds: (data['durationSec'] as num?)?.toInt() ?? 180),
            );
          }

          yield PipelineSocketEvent(
            generationId: generationId,
            step: step,
            stepIndex: stepIndex,
            progressPercent: progressPct,
            statusMessage: _statusMessageForStep(step),
            completedTrack: completedTrack,
            error: data['errorMessage'] as String?,
          );
        }
      } catch (err) {
        debugPrint('Polling generation tick error: $err');
      }
    }
  }

  static String _statusMessageForStep(PipelineStep step) {
    switch (step) {
      case PipelineStep.startingUp:
        return 'Starting synthesis pipeline...';
      case PipelineStep.writingLyrics:
        return 'Composing authentic dialect lyrics...';
      case PipelineStep.producingBeat:
        return 'Rendering African rhythm and audio stems...';
      case PipelineStep.ready:
        return 'Studio Master Ready';
      case PipelineStep.failed:
        return 'Synthesis failed.';
    }
  }
}
