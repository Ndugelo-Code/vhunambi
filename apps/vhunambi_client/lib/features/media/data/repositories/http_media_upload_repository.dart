import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/features/media/domain/models/uploaded_media_asset.dart';

abstract class IMediaUploadRepository {
  Future<UploadedMediaAsset> uploadMedia({
    required UploadedMediaAsset staged,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  });

  Future<List<UploadedMediaAsset>> fetchUploads({
    required String creatorId,
    MediaAssetKind? kind,
  });

  Future<bool> deleteRemoteUpload(String assetId);
}

class HttpMediaUploadRepository implements IMediaUploadRepository {
  final Dio _dio;
  final String _baseUrl;

  HttpMediaUploadRepository({
    Dio? dio,
    String? baseUrl,
    Interceptor? authInterceptor,
  }) : _baseUrl = baseUrl ?? AppConstants.apiRestBaseUrl,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               sendTimeout: const Duration(seconds: 90),
               receiveTimeout: const Duration(seconds: 30),
             ),
           ) {
    if (dio == null && authInterceptor != null) {
      _dio.interceptors.add(authInterceptor);
    }
  }

  @override
  Future<UploadedMediaAsset> uploadMedia({
    required UploadedMediaAsset staged,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  }) async {
    final total = bytes.length;
    onProgress?.call((total * 0.05).round(), total);

    Map<String, dynamic> presignBody = const <String, dynamic>{};
    bool canUsePresignEndpoint = true;
    try {
      final presignRes = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/media/presign-put',
        data: <String, dynamic>{
          'filename': staged.filename,
          'mimeType': staged.mimeType,
          'sizeBytes': bytes.length,
          'title': staged.title,
          'sourceSurface': staged.sourceSurface,
          if (staged.contentSha256 != null)
            'contentSha256': staged.contentSha256,
        },
      );
      presignBody = presignRes.data ?? const <String, dynamic>{};
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // Backward compatibility if a test mock or older node only implements /media/upload
      if (status == 404 || status == 405) {
        canUsePresignEndpoint = false;
      } else {
        rethrow;
      }
    }

    if (canUsePresignEndpoint &&
        presignBody['deduplicated'] == true &&
        presignBody['asset'] is Map) {
      onProgress?.call(total, total);
      return _hydrateSyncedAsset(
        staged,
        Map<String, dynamic>.from(presignBody['asset'] as Map),
        presignBody,
      );
    }

    final strategy =
        (presignBody['uploadStrategy'] ?? 'worker_binary').toString();
    final putUrl = presignBody['putUrl']?.toString();
    final uploadId = presignBody['uploadId']?.toString();
    final r2Key = presignBody['r2Key']?.toString();

    if (canUsePresignEndpoint &&
        strategy == 'r2_presigned_put' &&
        putUrl != null &&
        putUrl.isNotEmpty &&
        uploadId != null &&
        r2Key != null) {
      // Direct-to-R2 PUT: bypasses Worker 25 MB RAM cap and never reuses FormData
      final rawPutDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(minutes: 4),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      await rawPutDio.put<dynamic>(
        putUrl,
        data: Stream<List<int>>.fromIterable(<List<int>>[bytes]),
        options: Options(
          headers: <String, dynamic>{
            Headers.contentLengthHeader: bytes.length,
            Headers.contentTypeHeader: staged.mimeType,
          },
        ),
        onSendProgress: (sent, putTotal) {
          final denom = putTotal > 0 ? putTotal : total;
          final ratio = denom > 0 ? (sent / denom).clamp(0.0, 1.0) : 1.0;
          final scaled = 0.05 + (0.85 * ratio);
          onProgress?.call((scaled * total).round(), total);
        },
      );

      onProgress?.call((total * 0.94).round(), total);

      final finalizeRes = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/media/finalize',
        data: <String, dynamic>{
          'uploadId': uploadId,
          'r2Key': r2Key,
          'filename': staged.filename,
          'mimeType': staged.mimeType,
          'sizeBytes': bytes.length,
          'title': staged.title,
          'sourceSurface': staged.sourceSurface,
          if (staged.durationMs != null) 'durationMs': staged.durationMs,
          if (staged.width != null) 'width': staged.width,
          if (staged.height != null) 'height': staged.height,
          if (staged.contentSha256 != null)
            'contentSha256': staged.contentSha256,
        },
      );

      final finBody = finalizeRes.data ?? const <String, dynamic>{};
      final rawAsset = finBody['asset'] is Map
          ? Map<String, dynamic>.from(finBody['asset'] as Map)
          : <String, dynamic>{};
      onProgress?.call(total, total);
      return _hydrateSyncedAsset(staged, rawAsset, finBody);
    }

    // Fallback (local dev / test without R2 S3 keys): raw binary POST with replayable builder
    final res = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/media/upload',
      data: bytes,
      options: Options(
        contentType: staged.mimeType,
        headers: <String, dynamic>{
          'x-media-filename': staged.filename,
          'x-media-title': staged.title,
          'x-media-surface': staged.sourceSurface,
          if (staged.contentSha256 != null)
            'x-media-sha256': staged.contentSha256!,
        },
        extra: <String, dynamic>{'_p84BodyBuilder': () => bytes},
      ),
      onSendProgress: (sent, uploadTotal) {
        final denom = uploadTotal > 0 ? uploadTotal : total;
        final ratio = denom > 0 ? (sent / denom).clamp(0.0, 1.0) : 1.0;
        final scaled = 0.05 + (0.90 * ratio);
        onProgress?.call((scaled * total).round(), total);
      },
    );

    final body = res.data ?? const <String, dynamic>{};
    final rawAsset = body['asset'] is Map
        ? Map<String, dynamic>.from(body['asset'] as Map)
        : <String, dynamic>{};
    onProgress?.call(total, total);
    return _hydrateSyncedAsset(staged, rawAsset, body);
  }

  UploadedMediaAsset _hydrateSyncedAsset(
    UploadedMediaAsset staged,
    Map<String, dynamic> rawAsset,
    Map<String, dynamic> envelope,
  ) {
    final rawUrl = (rawAsset['remoteUrl'] ?? envelope['url'] ?? '').toString();
    if (rawUrl.isEmpty) {
      throw StateError('Upload response did not include a valid R2 URL');
    }
    final rawThumb =
        (rawAsset['thumbnailUrl'] ??
                rawAsset['thumbnail_url'] ??
                envelope['thumbnailUrl'] ??
                '')
            .toString()
            .trim();
    final id3 = rawAsset['id3Metadata'] is Map
        ? Map<String, dynamic>.from(rawAsset['id3Metadata'] as Map)
        : (envelope['id3Metadata'] is Map
              ? Map<String, dynamic>.from(envelope['id3Metadata'] as Map)
              : const <String, dynamic>{});
    final extractedTitle =
        (rawAsset['title'] ?? id3['title'] ?? '').toString().trim();

    return staged.copyWith(
      title: extractedTitle.isNotEmpty ? extractedTitle : staged.title,
      remoteUrl: AppConstants.normalizeCloudMediaUrl(rawUrl),
      remoteKey: (rawAsset['r2Key'] ?? envelope['key'])?.toString(),
      thumbnailUrl: rawThumb.isNotEmpty
          ? AppConstants.normalizeCloudMediaUrl(rawThumb)
          : staged.thumbnailUrl,
      artist: id3['artist']?.toString() ?? staged.artist,
      album: id3['album']?.toString() ?? staged.album,
      genre: id3['genre']?.toString() ?? staged.genre,
      bpm: (id3['bpm'] as num?)?.toInt() ?? staged.bpm,
      status: MediaUploadStatus.synced,
      progress: 1.0,
      clearError: true,
    );
  }

  @override
  Future<List<UploadedMediaAsset>> fetchUploads({
    required String creatorId,
    MediaAssetKind? kind,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '$_baseUrl/media/uploads',
      queryParameters: <String, dynamic>{
        'creatorId': creatorId,
        if (kind != null) 'kind': kind.name,
      },
    );
    final rawList = res.data?['uploads'];
    if (rawList is! List) return const <UploadedMediaAsset>[];
    return rawList
        .whereType<Map>()
        .map(
          (m) => UploadedMediaAsset.fromJson(Map<String, dynamic>.from(m))
              .copyWith(
                remoteUrl: AppConstants.normalizeCloudMediaUrl(
                  (m['remoteUrl'] ?? m['remote_url'] ?? '').toString(),
                ),
                status: MediaUploadStatus.synced,
                progress: 1.0,
              ),
        )
        .toList();
  }

  @override
  Future<bool> deleteRemoteUpload(String assetId) async {
    final res = await _dio.delete<Map<String, dynamic>>(
      '$_baseUrl/media/uploads/$assetId',
    );
    return res.data?['success'] == true;
  }
}
