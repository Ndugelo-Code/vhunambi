import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/models/lyrics_review_models.dart';
import '../../domain/services/i_lyrics_generation_service.dart';
import 'fake_lyrics_generation_service.dart';

/// Production HTTP lyrics synthesis service talking to Vhunambi API (Phase 15).
///
/// Calls `POST /v1/lyrics/generate` to synthesize authentic African lyrics
/// structured into bracketed stanzas ([INTRO], [VERSE 1], [CHORUS], etc.).
/// If the server is unreachable, gracefully degrades to
/// [FakeLyricsGenerationService] so the user can continue offline.
class HttpLyricsGenerationService implements ILyricsGenerationService {
  final Dio _dio;
  final String _baseUrl;
  final FakeLyricsGenerationService _fallback;

  HttpLyricsGenerationService({
    Dio? dio,
    String? baseUrl,
    FakeLyricsGenerationService? fallback,
  })  : _dio = dio ?? Dio(),
        _baseUrl = baseUrl ?? AppConstants.apiBaseUrl,
        _fallback = fallback ?? FakeLyricsGenerationService();

  @override
  Future<LyricsReviewDraft> generateLyrics({
    required String prompt,
    required String genre,
    required String language,
  }) async {
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
      debugPrint('HttpLyricsGenerationService network error: $error — using fallback generator');
    }

    // Graceful offline fallback
    return _fallback.generateLyrics(
      prompt: prompt,
      genre: genre,
      language: language,
    );
  }

  @override
  List<String> getCulturalIdioms(String language) {
    return _fallback.getCulturalIdioms(language);
  }
}
