import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/models/lyrics_review_models.dart';
import '../../domain/services/i_lyrics_generation_service.dart';
import 'fake_lyrics_generation_service.dart';

/// Production HTTP lyrics synthesis service talking to Vhunambi API (`Phase 15` / `Phase 75`).
///
/// Calls `POST /v1/lyrics/generate`, `POST /v1/lyrics/refine`, and
/// `POST /v1/lyrics/story-transform`. If offline or in headless tests without an
/// injected custom [Dio], gracefully degrades to [FakeLyricsGenerationService].
class HttpLyricsGenerationService implements ILyricsGenerationService {
  final Dio _dio;
  final String _baseUrl;
  final FakeLyricsGenerationService _fallback;
  final bool _hasCustomDio;
  final bool _isTestMode;

  HttpLyricsGenerationService({
    Dio? dio,
    String? baseUrl,
    FakeLyricsGenerationService? fallback,
    Interceptor? authInterceptor,
    bool? isTestMode,
  }) : _dio = dio ?? Dio(),
       _baseUrl = baseUrl ?? AppConstants.apiBaseUrl,
       _fallback = fallback ?? FakeLyricsGenerationService(),
       _hasCustomDio = dio != null,
       _isTestMode = isTestMode ?? _detectTestMode() {
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

  bool get _shouldSkipNetwork => _isTestMode && !_hasCustomDio;

  static const Set<String> _storyGenres = <String>{
    'amapiano',
    'maskandi',
    'gqom',
    'gospel',
    'kwaito',
    'hiphop',
  };

  /// Normalizes Flutter language display labels into 2-3 letter ISO codes expected
  /// by `/v1/lyrics/refine` and `/v1/lyrics/story-transform`.
  static String normalizeLanguageCode(String raw) {
    final cleaned = raw.trim().toLowerCase();
    if (cleaned.isEmpty) return 'zu';
    const map = <String, String>{
      'tshivenḓa': 've',
      'tshivenda': 've',
      'venda': 've',
      've': 've',
      'isizulu': 'zu',
      'zulu': 'zu',
      'zu': 'zu',
      'isixhosa': 'xh',
      'xhosa': 'xh',
      'xh': 'xh',
      'sesotho': 'st',
      'sotho': 'st',
      'st': 'st',
      'setswana': 'tn',
      'tswana': 'tn',
      'tn': 'tn',
      'sepedi': 'nso',
      'northern sotho': 'nso',
      'pedi': 'nso',
      'nso': 'nso',
      'xitsonga': 'ts',
      'tsonga': 'ts',
      'ts': 'ts',
      'siswati': 'ss',
      'swati': 'ss',
      'ss': 'ss',
      'isindebele': 'nr',
      'ndebele': 'nr',
      'nr': 'nr',
      'kiswahili': 'sw',
      'swahili': 'sw',
      'sw': 'sw',
      'yoruba': 'yo',
      'yorùbá': 'yo',
      'yo': 'yo',
      'igbo': 'ig',
      'ig': 'ig',
      'english': 'en',
      'en': 'en',
    };
    return map[cleaned] ?? (cleaned.length <= 3 ? cleaned : 'zu');
  }

  /// Normalizes display genres onto valid backend `STORY_GENRES` (`amapiano` default).
  static String normalizeStoryGenre(String raw) {
    final g = raw.trim().toLowerCase();
    if (g == 'hip-hop' || g == 'hip hop' || g == 'hiphop') {
      return 'hiphop';
    }
    if (g.contains('amapiano')) return 'amapiano';
    if (g.contains('maskandi')) return 'maskandi';
    if (g.contains('gqom')) return 'gqom';
    if (g.contains('gospel')) return 'gospel';
    if (g.contains('kwaito')) return 'kwaito';
    if (_storyGenres.contains(g)) return g;
    return 'amapiano';
  }

  @override
  Future<LyricsReviewDraft> generateLyrics({
    required String prompt,
    required String genre,
    required String language,
  }) async {
    if (!_shouldSkipNetwork) {
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '$_baseUrl/lyrics/generate',
          data: <String, dynamic>{
            'prompt': prompt,
            'genre': genre,
            'language': language,
          },
          options: Options(
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 10),
          ),
        );

        final data = response.data;
        if (data != null && data['success'] == true) {
          final rawLyrics = data['rawLyrics'] as String? ?? '';
          final idioms = getCulturalIdioms(language);

          return LyricsReviewDraft.fromRawText(
            prompt: prompt,
            genre: genre,
            language: language,
            rawText: rawLyrics,
            culturalIdioms: idioms,
          );
        }
      } catch (error) {
        debugPrint(
          'HttpLyricsGenerationService network error: $error — using fallback generator',
        );
      }
    }

    // Graceful offline fallback
    return _fallback.generateLyrics(
      prompt: prompt,
      genre: genre,
      language: language,
    );
  }

  @override
  Future<LyricsReviewDraft> refineLyrics({
    required String currentLyrics,
    required String refinementInstruction,
    String? idiomToInsert,
    required String genre,
    required String language,
    String prompt = '',
  }) async {
    if (!_shouldSkipNetwork) {
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '$_baseUrl/lyrics/refine',
          data: <String, dynamic>{
            'currentLyrics': currentLyrics,
            'refinementInstruction': refinementInstruction,
            if (idiomToInsert != null && idiomToInsert.trim().isNotEmpty)
              'idiomToInsert': idiomToInsert.trim(),
            'genre': genre,
            'language': normalizeLanguageCode(language),
          },
          options: Options(
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 10),
          ),
        );

        final data = response.data;
        final rawLyrics = data?['rawLyrics']?.toString() ?? '';
        if (data != null && data['success'] == true && rawLyrics.isNotEmpty) {
          return LyricsReviewDraft.fromRawText(
            prompt: prompt,
            genre: genre,
            language: language,
            rawText: rawLyrics,
            culturalIdioms: getCulturalIdioms(language),
          );
        }
      } catch (error) {
        debugPrint(
          'HttpLyricsGenerationService.refineLyrics error: $error — using fallback',
        );
      }
    }

    return _fallback.refineLyrics(
      currentLyrics: currentLyrics,
      refinementInstruction: refinementInstruction,
      idiomToInsert: idiomToInsert,
      genre: genre,
      language: language,
      prompt: prompt,
    );
  }

  @override
  Future<LyricsReviewDraft> transformStoryToLyrics({
    required String storyText,
    required String genre,
    required String language,
    List<String>? targetCognateLanguages,
    List<String>? mood,
  }) async {
    if (!_shouldSkipNetwork) {
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '$_baseUrl/lyrics/story-transform',
          data: <String, dynamic>{
            'storyText': storyText,
            'genre': normalizeStoryGenre(genre),
            'baseLanguage': normalizeLanguageCode(language),
            'targetCognateLanguages': ?targetCognateLanguages,
            'mood': ?mood,
          },
          options: Options(
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 10),
          ),
        );

        final data = response.data;
        final structuredLyrics = data?['structuredLyrics']?.toString() ?? '';
        if (data != null &&
            data['success'] == true &&
            structuredLyrics.isNotEmpty) {
          return LyricsReviewDraft.fromRawText(
            prompt: storyText.trim(),
            genre: genre,
            language: language,
            rawText: structuredLyrics,
            culturalIdioms: getCulturalIdioms(language),
          );
        }
      } catch (error) {
        debugPrint(
          'HttpLyricsGenerationService.transformStoryToLyrics error: $error — using fallback',
        );
      }
    }

    return _fallback.transformStoryToLyrics(
      storyText: storyText,
      genre: genre,
      language: language,
      targetCognateLanguages: targetCognateLanguages,
      mood: mood,
    );
  }

  @override
  List<String> getCulturalIdioms(String language) {
    return _fallback.getCulturalIdioms(language);
  }
}
