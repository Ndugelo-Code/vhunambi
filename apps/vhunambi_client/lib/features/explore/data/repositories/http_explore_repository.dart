import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// Immutable cloud discovery bundle payload returned by `GET /api/explore`.
@immutable
class ExploreCloudBundle {
  final List<Track> tracks;
  final List<Map<String, dynamic>> posts;
  final ExploreRadioStation? radio;
  final int serverSeq;
  final bool isFromCloud;

  const ExploreCloudBundle({
    this.tracks = const <Track>[],
    this.posts = const <Map<String, dynamic>>[],
    this.radio,
    this.serverSeq = 0,
    this.isFromCloud = false,
  });
}

/// Immutable Genre Radio harmonic rotation returned by `GET /api/explore/radio/:genre`.
@immutable
class ExploreRadioStation {
  final String genre;
  final String stationTitle;
  final String description;
  final double seedBpm;
  final List<Track> rotation;

  const ExploreRadioStation({
    required this.genre,
    required this.stationTitle,
    required this.description,
    this.seedBpm = 113.0,
    this.rotation = const <Track>[],
  });

  factory ExploreRadioStation.fromJson(Map<String, dynamic> json) {
    final rawRotation = json['rotation'] as List<dynamic>? ?? const <dynamic>[];
    return ExploreRadioStation(
      genre: (json['genre'] ?? 'All').toString(),
      stationTitle: (json['stationTitle'] ?? 'Vhunambi Sovereign Radio')
          .toString(),
      description: (json['description'] ?? '').toString(),
      seedBpm: (json['seedBpm'] as num?)?.toDouble() ?? 113.0,
      rotation: rawRotation
          .whereType<Map>()
          .map((e) => Track.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }
}

/// HTTP repository bridging Vhunambi Explore discovery (`GET /api/explore*`)
/// with offline-first local fallback for headless tests and disconnected mode.
class HttpExploreRepository {
  final Dio _dio;
  final String _baseUrl;
  final bool isTestMode;
  final bool _hasCustomDio;

  HttpExploreRepository({
    Dio? dio,
    String? baseUrl,
    bool? isTestMode,
    Interceptor? authInterceptor,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 4),
               receiveTimeout: const Duration(seconds: 4),
               headers: <String, dynamic>{
                 'Content-Type': 'application/json',
                 'Accept': 'application/json',
               },
             ),
           ),
       _baseUrl = baseUrl ?? _resolveDefaultBaseUrl(),
       isTestMode = isTestMode ?? _detectTestMode(),
       _hasCustomDio = dio != null {
    if (dio == null && authInterceptor != null) {
      _dio.interceptors.add(authInterceptor);
    }
  }

  bool get _shouldSkipNetwork => isTestMode && !_hasCustomDio;

  static bool _detectTestMode() {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  static String _resolveDefaultBaseUrl() => AppConstants.apiRestBaseUrl;

  /// Fetches the unified discovery bundle from `GET /api/explore`.
  Future<ExploreCloudBundle> fetchExploreBundle({
    String? genre,
    String? stage,
    int limit = 50,
  }) async {
    if (_shouldSkipNetwork) {
      return const ExploreCloudBundle();
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/explore',
        queryParameters: <String, dynamic>{
          if (genre != null && genre.isNotEmpty && genre != 'All')
            'genre': genre,
          if (stage != null && stage.isNotEmpty) 'stage': stage,
          'limit': limit,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final rawTracks = data['tracks'] as List<dynamic>? ?? const <dynamic>[];
        final rawPosts = data['posts'] as List<dynamic>? ?? const <dynamic>[];
        final radioRaw = data['radio'];
        return ExploreCloudBundle(
          tracks: rawTracks
              .whereType<Map>()
              .map((e) => Track.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false),
          posts: rawPosts
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false),
          radio: radioRaw is Map
              ? ExploreRadioStation.fromJson(
                  Map<String, dynamic>.from(radioRaw),
                )
              : null,
          serverSeq: (data['serverSeq'] as num?)?.toInt() ?? 0,
          isFromCloud: true,
        );
      }
    } catch (e) {
      debugPrint('[HttpExploreRepository] fetchExploreBundle fallback: $e');
    }
    return const ExploreCloudBundle();
  }

  /// Fetches filtered tracks from `GET /api/explore/tracks`.
  Future<List<Track>> fetchExploreTracks({
    String? genre,
    String? stage,
    String sort = 'trending',
    String? search,
    int limit = 50,
  }) async {
    if (_shouldSkipNetwork) {
      return const <Track>[];
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/explore/tracks',
        queryParameters: <String, dynamic>{
          if (genre != null && genre.isNotEmpty && genre != 'All')
            'genre': genre,
          if (stage != null && stage.isNotEmpty) 'stage': stage,
          'sort': sort,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
          'limit': limit,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final list =
            (response.data!['items'] ?? response.data!['tracks'])
                as List<dynamic>? ??
            const <dynamic>[];
        return list
            .whereType<Map>()
            .map((e) => Track.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false);
      }
    } catch (e) {
      debugPrint('[HttpExploreRepository] fetchExploreTracks fallback: $e');
    }
    return const <Track>[];
  }

  /// Fetches curated genre radio harmonic rotation via `GET /api/explore/radio/:genre`.
  Future<ExploreRadioStation?> fetchGenreRadio(
    String genre, {
    int limit = 20,
  }) async {
    if (_shouldSkipNetwork) {
      return null;
    }
    try {
      final encodedGenre = Uri.encodeComponent(genre.isEmpty ? 'All' : genre);
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/explore/radio/$encodedGenre',
        queryParameters: <String, dynamic>{'limit': limit},
      );
      if (response.statusCode == 200 && response.data != null) {
        return ExploreRadioStation.fromJson(response.data!);
      }
    } catch (e) {
      debugPrint('[HttpExploreRepository] fetchGenreRadio fallback: $e');
    }
    return null;
  }

  /// Publishes a track directly to `POST /api/explore/tracks`.
  Future<Track?> publishTrack(Track track) async {
    if (_shouldSkipNetwork) {
      return null;
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/explore/tracks',
        data: track.toJson(),
      );
      if ((response.statusCode == 201 || response.statusCode == 200) &&
          response.data != null &&
          response.data!['track'] is Map) {
        return Track.fromJson(
          Map<String, dynamic>.from(response.data!['track'] as Map),
        );
      }
    } catch (e) {
      debugPrint('[HttpExploreRepository] publishTrack fallback: $e');
    }
    return null;
  }
}
