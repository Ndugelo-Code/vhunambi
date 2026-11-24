import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../data/services/http_lyrics_generation_service.dart';

/// Studio V6 AI Assist HTTP service for prompt enhancement, photo-to-lyrics,
/// and ensemble/duet lyric scripting (`Phase 80` / `REQ-P80-PARITY-01`, `04`).
///
/// Kept separate from `ILyricsGenerationService` so existing lyrics test doubles
/// remain untouched.
class StudioAiAssistService {
  final Dio _dio;
  final String _baseUrl;
  final bool _hasCustomDio;
  final bool _isTestMode;

  StudioAiAssistService({
    Dio? dio,
    String? baseUrl,
    bool? isTestMode,
  }) : _dio = dio ?? Dio(),
       _baseUrl = baseUrl ?? AppConstants.apiBaseUrl,
       _hasCustomDio = dio != null,
       _isTestMode = isTestMode ?? _detectTestMode();

  static bool _detectTestMode() {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  bool get _shouldSkipNetwork => _isTestMode && !_hasCustomDio;

  Future<String> improvePrompt({
    required String prompt,
    required String genre,
    String region = 'South Africa',
    String language = 'English',
    String? mood,
    String? ensemble,
    bool isInstrumental = false,
  }) async {
    final trimmed = prompt.trim();
    if (_shouldSkipNetwork) {
      return _localImproveFallback(
        prompt: trimmed,
        genre: genre,
        region: region,
        language: language,
        mood: mood,
        ensemble: ensemble,
        isInstrumental: isInstrumental,
      );
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/studio/improve-prompt',
        data: <String, dynamic>{
          'prompt': trimmed.isEmpty ? '$genre studio groove' : trimmed,
          'genre': genre,
          'region': region,
          'language': HttpLyricsGenerationService.normalizeLanguageCode(
            language,
          ),
          if (mood != null && mood.trim().isNotEmpty) 'mood': mood.trim(),
          if (ensemble != null && ensemble.isNotEmpty) 'ensemble': ensemble,
          'isInstrumental': isInstrumental,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      final improved = response.data?['improvedPrompt']?.toString().trim();
      if (improved != null && improved.isNotEmpty) {
        return improved;
      }
    } catch (err) {
      debugPrint('StudioAiAssistService.improvePrompt fallback: $err');
    }

    return _localImproveFallback(
      prompt: trimmed,
      genre: genre,
      region: region,
      language: language,
      mood: mood,
      ensemble: ensemble,
      isInstrumental: isInstrumental,
    );
  }

  Future<String> generateLyricsFromPhoto({
    required String photoUrl,
    String? captionHint,
    required String genre,
    required String language,
    String? mood,
    String? ensemble,
  }) async {
    if (_shouldSkipNetwork) {
      return _localPhotoLyricsFallback(
        captionHint: captionHint,
        genre: genre,
        language: language,
        ensemble: ensemble,
      );
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/lyrics/from-photo',
        data: <String, dynamic>{
          'photoUrl': photoUrl,
          if (captionHint != null && captionHint.trim().isNotEmpty)
            'captionHint': captionHint.trim(),
          'genre': genre,
          'language': HttpLyricsGenerationService.normalizeLanguageCode(
            language,
          ),
          if (mood != null && mood.trim().isNotEmpty) 'mood': mood.trim(),
          if (ensemble != null && ensemble.isNotEmpty) 'ensemble': ensemble,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 25),
        ),
      );
      final lyrics = response.data?['rawLyrics']?.toString().trim();
      if (lyrics != null && lyrics.isNotEmpty) {
        return lyrics;
      }
    } catch (err) {
      debugPrint('StudioAiAssistService.generateLyricsFromPhoto fallback: $err');
    }

    return _localPhotoLyricsFallback(
      captionHint: captionHint,
      genre: genre,
      language: language,
      ensemble: ensemble,
    );
  }

  Future<String> generateDuetAwareLyrics({
    required String prompt,
    required String genre,
    required String language,
    required String ensemble,
    List<String> voiceCast = const <String>[],
    String? mood,
  }) async {
    if (_shouldSkipNetwork) {
      return _localEnsembleLyricsFallback(
        prompt: prompt,
        genre: genre,
        ensemble: ensemble,
      );
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/lyrics/generate',
        data: <String, dynamic>{
          'prompt': prompt.trim().isEmpty ? '$genre studio song' : prompt.trim(),
          'genre': genre,
          'language': HttpLyricsGenerationService.normalizeLanguageCode(
            language,
          ),
          'ensemble': ensemble,
          if (voiceCast.isNotEmpty) 'voiceCast': voiceCast.take(6).toList(),
          if (mood != null && mood.trim().isNotEmpty) 'mood': mood.trim(),
        },
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 25),
        ),
      );
      final lyrics = response.data?['rawLyrics']?.toString().trim();
      if (lyrics != null && lyrics.isNotEmpty) {
        return lyrics;
      }
    } catch (err) {
      debugPrint('StudioAiAssistService.generateDuetAwareLyrics fallback: $err');
    }

    return _localEnsembleLyricsFallback(
      prompt: prompt,
      genre: genre,
      ensemble: ensemble,
    );
  }

  static String _localImproveFallback({
    required String prompt,
    required String genre,
    required String region,
    required String language,
    String? mood,
    String? ensemble,
    required bool isInstrumental,
  }) {
    final seed = prompt.isEmpty ? '$genre anthem' : prompt;
    final vocalLine = isInstrumental
        ? 'rich instrumental arrangement with dynamic solo lifts'
        : ensemble == 'duet'
            ? 'expressive male and female duet harmonies'
            : ensemble == 'choir'
                ? 'lush layered gospel-inspired choir harmonies'
                : 'passionate headline vocals in $language';
    final moodClause = (mood != null && mood.isNotEmpty) ? mood : 'warm uplifting';
    return '$seed — $region $genre production with $moodClause dynamics, '
        'authentic live percussion, warm low-end pocket, and $vocalLine.';
  }

  static String _localPhotoLyricsFallback({
    String? captionHint,
    required String genre,
    required String language,
    String? ensemble,
  }) {
    final scene = (captionHint != null && captionHint.trim().isNotEmpty)
        ? captionHint.trim()
        : 'Golden evening light across our homeland';
    if (ensemble == 'duet') {
      return '[VERSE 1]\n[VOICE A]\n$scene\nCarries a $genre melody in $language\n'
          '[VOICE B]\nEvery shadow turns to song tonight\n\n'
          '[CHORUS]\n[DUET]\nHold the frame in rhythm and grace\nOur voices rise across this place';
    }
    return '[VERSE 1]\n$scene\nEvery detail tells a $genre story in $language\n\n'
        '[CHORUS]\nHold the moment, let the drums speak clear\nForever captured in sound right here';
  }

  static String _localEnsembleLyricsFallback({
    required String prompt,
    required String genre,
    required String ensemble,
  }) {
    final hook = prompt.trim().isEmpty ? '$genre heartbeat' : prompt.trim();
    if (ensemble == 'duet') {
      return '[VERSE 1]\n[VOICE A]\n$hook\nUnder amber studio lights we begin\n'
          '[VOICE B]\nAnswer the call with soul and fire within\n\n'
          '[CHORUS]\n[DUET]\nTwo voices rising on a $genre groove\nMoving the crowd with every word we prove';
    }
    if (ensemble == 'choir') {
      return '[VERSE 1]\n[VOICE A]\n$hook\n'
          '[CHOIR]\nHear the collective echo rolling strong\n\n'
          '[CHORUS]\n[CHOIR]\nOne family singing in unified flame\nLifting the rhythm in honour and name';
    }
    return '[VERSE 1]\n$hook\nAuthentic story carried in the pocket\n\n'
        '[CHORUS]\nFeel the $genre pulse resonate deep and true';
  }
}

final studioAiAssistServiceProvider = Provider<StudioAiAssistService>((ref) {
  return StudioAiAssistService();
});
