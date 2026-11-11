import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../sound_signature/domain/models/sound_signature_dna.dart';
import '../../domain/models/melody_sketchpad_models.dart';

/// Phase 63 pre-generation Cloudflare R2 upload & conditioning bridge.
///
/// Wires Sketchpad WAV bounces, 3-line Voice Clone calibration takes,
/// imported Reference Audio stems, and Sound Signature DNA captures to
/// Cloudflare R2 (`/r2/:key`) and backend metadata registration endpoints
/// before dispatching AI synthesis to RunPod.
class PreGenR2UploadService {
  final Dio _dio;
  final String _originUrl;
  final bool _hasCustomDio;
  final bool isTestMode;

  PreGenR2UploadService({
    Dio? dio,
    String? apiRootOverride,
    bool? isTestMode,
    Interceptor? authInterceptor,
  })  : _dio =
            dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 6),
                receiveTimeout: const Duration(seconds: 12),
                sendTimeout: const Duration(seconds: 12),
              ),
            ),
        _originUrl = AppConstants.resolveApiRootUrl(
          overrideOrigin: apiRootOverride,
        ),
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

  String get _v1BaseUrl => '$_originUrl/v1';

  /// Registers and stores a rendered sketchpad WAV pattern on R2 via
  /// `POST /v1/melodies/render-reference` (and optionally uploads high-res WAV bytes).
  Future<({String? referenceId, String? r2ReferenceUrl})> uploadMelodyReference({
    required MelodyPatternEntity pattern,
    Uint8List? wavBytes,
  }) async {
    if (_shouldSkipNetwork) {
      return (referenceId: null, r2ReferenceUrl: null);
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_v1BaseUrl/melodies/render-reference',
        data: pattern.toJson(),
      );
      final data = response.data;
      if (data == null) {
        return (referenceId: null, r2ReferenceUrl: null);
      }

      final referenceId =
          (data['referenceId'] ?? data['patternId'])?.toString();
      final r2ObjectKey = data['r2ObjectKey']?.toString();
      final rawUrl = data['r2ReferenceUrl']?.toString() ?? '';

      if (wavBytes != null &&
          wavBytes.isNotEmpty &&
          r2ObjectKey != null &&
          r2ObjectKey.isNotEmpty) {
        try {
          await _dio.put<dynamic>(
            '$_originUrl/r2/$r2ObjectKey',
            data: wavBytes,
            options: Options(headers: const {'Content-Type': 'audio/wav'}),
          );
        } catch (err) {
          debugPrint('[PreGenR2] Sketchpad WAV PUT failed cleanly: $err');
        }
      }

      final normalizedUrl = rawUrl.isNotEmpty
          ? AppConstants.normalizeCloudMediaUrl(
              rawUrl,
              overrideOrigin: _originUrl,
            )
          : null;
      return (referenceId: referenceId, r2ReferenceUrl: normalizedUrl);
    } catch (err) {
      debugPrint('[PreGenR2] uploadMelodyReference failed: $err');
      return (referenceId: null, r2ReferenceUrl: null);
    }
  }

  /// Uploads a 3-line zero-shot calibration WAV to `PUT /r2/voice-clones/:id_ref.wav`
  /// and registers the profile with `POST /v1/voices/clone`.
  Future<String?> uploadVoiceCloneReference({
    required String profileId,
    required Uint8List wavBytes,
    required String creatorName,
    required String nativeLanguage,
    required List<String> calibrationLines,
    required double recordingDurationSec,
  }) async {
    if (_shouldSkipNetwork || wavBytes.isEmpty) {
      return null;
    }

    final r2Key = 'voice-clones/${profileId}_ref.wav';
    try {
      final putResponse = await _dio.put<Map<String, dynamic>>(
        '$_originUrl/r2/$r2Key',
        data: wavBytes,
        options: Options(headers: const {'Content-Type': 'audio/wav'}),
      );
      final rawUrl =
          putResponse.data?['url']?.toString() ?? '$_originUrl/r2/$r2Key';
      final normalizedUrl = AppConstants.normalizeCloudMediaUrl(
        rawUrl,
        overrideOrigin: _originUrl,
      );

      try {
        await _dio.post<Map<String, dynamic>>(
          '$_v1BaseUrl/voices/clone',
          data: <String, dynamic>{
            'creatorName': creatorName,
            'nativeLanguage': nativeLanguage,
            'calibrationLines': calibrationLines,
            'recordingDurationSec': recordingDurationSec.clamp(3.0, 60.0),
            'r2ReferenceUrl': normalizedUrl,
          },
        );
      } catch (err) {
        debugPrint('[PreGenR2] /voices/clone registration failed: $err');
      }

      return normalizedUrl;
    } catch (err) {
      debugPrint('[PreGenR2] uploadVoiceCloneReference failed: $err');
      return null;
    }
  }

  /// Uploads a picked/imported reference audio file to `PUT /r2/reference-stems/:key`.
  Future<String?> uploadReferenceAudioStem({
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (_shouldSkipNetwork || bytes.isEmpty) {
      return null;
    }

    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final r2Key =
        'reference-stems/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final contentType = safeName.toLowerCase().endsWith('.mp3')
        ? 'audio/mpeg'
        : safeName.toLowerCase().endsWith('.m4a')
            ? 'audio/mp4'
            : 'audio/wav';

    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '$_originUrl/r2/$r2Key',
        data: bytes,
        options: Options(headers: {'Content-Type': contentType}),
      );
      final rawUrl =
          response.data?['url']?.toString() ?? '$_originUrl/r2/$r2Key';
      return AppConstants.normalizeCloudMediaUrl(
        rawUrl,
        overrideOrigin: _originUrl,
      );
    } catch (err) {
      debugPrint('[PreGenR2] uploadReferenceAudioStem failed: $err');
      return null;
    }
  }

  /// Registers a `SoundSignatureDna` take via `POST /v1/voices/signatures`,
  /// uploads its WAV bytes to the returned R2 target, and triggers GPU embedding analysis.
  Future<String?> uploadSoundSignatureTake({
    required SoundSignatureDna signature,
    required Uint8List wavBytes,
  }) async {
    if (_shouldSkipNetwork || wavBytes.isEmpty) {
      return null;
    }

    final descriptor16 = List<double>.generate(
      16,
      (i) => i < signature.identity.cepstralDescriptor.length
          ? signature.identity.cepstralDescriptor[i]
          : 0.0,
    );
    final formants4 = List<double>.generate(
      4,
      (i) => i < signature.identity.formantsHz.length
          ? signature.identity.formantsHz[i]
          : 0.0,
    );

    try {
      final regRes = await _dio.post<Map<String, dynamic>>(
        '$_v1BaseUrl/voices/signatures',
        data: <String, dynamic>{
          'id': signature.id,
          'displayCode': signature.displayCode,
          'source': signature.source.wireValue,
          'durationSec': signature.durationSec.clamp(1.0, 180.0),
          'recipe': signature.recipe.toJson(),
          'descriptor16': descriptor16,
          'formants4': formants4,
          'consentAtIso':
              signature.consentAtIso ?? DateTime.now().toIso8601String(),
          'consentConfirmed': true,
        },
      );
      final data = regRes.data ?? const <String, dynamic>{};
      final r2Key =
          data['r2Key']?.toString() ?? 'signatures/${signature.id}/raw.wav';
      final presignedUrl = data['presignedUploadUrl']?.toString() ??
          data['uploadUrl']?.toString() ??
          '';

      final targetPutUrl = presignedUrl.startsWith('http://') ||
              presignedUrl.startsWith('https://')
          ? presignedUrl
          : '$_originUrl/r2/$r2Key';

      final putRes = await _dio.put<Map<String, dynamic>>(
        targetPutUrl,
        data: wavBytes,
        options: Options(headers: const {'Content-Type': 'audio/wav'}),
      );

      try {
        await _dio.post<Map<String, dynamic>>(
          '$_v1BaseUrl/voices/signatures/${signature.id}/analyze',
          data: const <String, dynamic>{},
        );
      } catch (err) {
        debugPrint('[PreGenR2] Signature analyze trigger failed: $err');
      }

      final rawResultUrl =
          putRes.data?['url']?.toString() ?? '$_originUrl/r2/$r2Key';
      return AppConstants.normalizeCloudMediaUrl(
        rawResultUrl,
        overrideOrigin: _originUrl,
      );
    } catch (err) {
      debugPrint('[PreGenR2] uploadSoundSignatureTake failed: $err');
      return null;
    }
  }
}

final preGenR2UploadServiceProvider = Provider<PreGenR2UploadService>((ref) {
  return PreGenR2UploadService(
    authInterceptor: ref.watch(authDioInterceptorProvider),
  );
});

