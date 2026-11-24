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
    final form = FormData.fromMap(<String, dynamic>{
      'title': staged.title,
      'filename': staged.filename,
      'sourceSurface': staged.sourceSurface,
      if (staged.durationMs != null) 'durationMs': '${staged.durationMs}',
      if (staged.width != null) 'width': '${staged.width}',
      if (staged.height != null) 'height': '${staged.height}',
      'file': MultipartFile.fromBytes(
        bytes,
        filename: staged.filename,
        contentType: DioMediaType.parse(staged.mimeType),
      ),
    });

    final res = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/media/upload',
      data: form,
      onSendProgress: onProgress,
    );

    final body = res.data ?? const <String, dynamic>{};
    final rawAsset = body['asset'] is Map
        ? Map<String, dynamic>.from(body['asset'] as Map)
        : <String, dynamic>{};
    final rawUrl = (rawAsset['remoteUrl'] ?? body['url'] ?? '').toString();
    if (rawUrl.isEmpty) {
      throw DioException(
        requestOptions: res.requestOptions,
        message: 'Upload response did not include a valid R2 URL',
      );
    }
    final normalizedUrl = AppConstants.normalizeCloudMediaUrl(rawUrl);

    return staged.copyWith(
      remoteUrl: normalizedUrl,
      remoteKey: (rawAsset['r2Key'] ?? body['key'])?.toString(),
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
