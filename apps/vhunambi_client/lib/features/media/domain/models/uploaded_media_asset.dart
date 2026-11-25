import 'package:flutter/foundation.dart';

enum MediaAssetKind { audio, video, image }

enum MediaUploadStatus { queued, uploading, synced, failed }

/// Immutable local+cloud user media descriptor (`EP-P79-MEDIA-UPLOAD-ENGINE`).
@immutable
class UploadedMediaAsset {
  final String id;
  final String creatorId;
  final MediaAssetKind kind;
  final String title;
  final String filename;
  final String mimeType;
  final int sizeBytes;
  final String? localFilePath;
  final String? thumbnailLocalPath;
  final String? thumbnailUrl;
  final String? remoteUrl;
  final String? remoteKey;
  final int? durationMs;
  final int? width;
  final int? height;
  final String sourceSurface;
  final String? artist;
  final String? album;
  final String? genre;
  final int? bpm;
  final String? contentSha256;
  final MediaUploadStatus status;
  final double progress;
  final String? errorMessage;
  final DateTime createdAt;

  const UploadedMediaAsset({
    required this.id,
    required this.creatorId,
    required this.kind,
    required this.title,
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
    this.localFilePath,
    this.thumbnailLocalPath,
    this.thumbnailUrl,
    this.remoteUrl,
    this.remoteKey,
    this.durationMs,
    this.width,
    this.height,
    this.sourceSurface = 'vault',
    this.artist,
    this.album,
    this.genre,
    this.bpm,
    this.contentSha256,
    this.status = MediaUploadStatus.queued,
    this.progress = 0.0,
    this.errorMessage,
    required this.createdAt,
  });

  String? get bestCoverSource {
    if (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty) {
      return thumbnailUrl;
    }
    if (thumbnailLocalPath != null && thumbnailLocalPath!.trim().isNotEmpty) {
      return thumbnailLocalPath;
    }
    return null;
  }

  String? get bestPlayableOrRenderableSource {
    if (localFilePath != null && localFilePath!.trim().isNotEmpty) {
      return localFilePath;
    }
    if (remoteUrl != null && remoteUrl!.trim().isNotEmpty) {
      return remoteUrl;
    }
    return null;
  }

  UploadedMediaAsset copyWith({
    String? title,
    String? localFilePath,
    String? thumbnailLocalPath,
    String? thumbnailUrl,
    String? remoteUrl,
    bool clearRemoteUrl = false,
    String? remoteKey,
    int? durationMs,
    int? width,
    int? height,
    String? artist,
    String? album,
    String? genre,
    int? bpm,
    String? contentSha256,
    MediaUploadStatus? status,
    double? progress,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UploadedMediaAsset(
      id: id,
      creatorId: creatorId,
      kind: kind,
      title: title ?? this.title,
      filename: filename,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      localFilePath: localFilePath ?? this.localFilePath,
      thumbnailLocalPath: thumbnailLocalPath ?? this.thumbnailLocalPath,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      remoteUrl: clearRemoteUrl ? null : (remoteUrl ?? this.remoteUrl),
      remoteKey: remoteKey ?? this.remoteKey,
      durationMs: durationMs ?? this.durationMs,
      width: width ?? this.width,
      height: height ?? this.height,
      sourceSurface: sourceSurface,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      bpm: bpm ?? this.bpm,
      contentSha256: contentSha256 ?? this.contentSha256,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'creatorId': creatorId,
    'mediaKind': kind.name,
    'title': title,
    'filename': filename,
    'mimeType': mimeType,
    'sizeBytes': sizeBytes,
    if (localFilePath != null) 'localFilePath': localFilePath,
    if (thumbnailLocalPath != null) 'thumbnailLocalPath': thumbnailLocalPath,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    if (remoteUrl != null) 'remoteUrl': remoteUrl,
    if (remoteKey != null) 'r2Key': remoteKey,
    if (durationMs != null) 'durationMs': durationMs,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    'sourceSurface': sourceSurface,
    if (artist != null) 'artist': artist,
    if (album != null) 'album': album,
    if (genre != null) 'genre': genre,
    if (bpm != null) 'bpm': bpm,
    if (contentSha256 != null) 'contentSha256': contentSha256,
    'status': status.name,
    'progress': progress,
    if (errorMessage != null) 'errorMessage': errorMessage,
    'createdAt': createdAt.toIso8601String(),
  };

  factory UploadedMediaAsset.fromJson(Map<String, dynamic> json) {
    final kindRaw = (json['mediaKind'] ?? json['media_kind'] ?? json['kind'] ?? 'image')
        .toString()
        .toLowerCase();
    final kind = switch (kindRaw) {
      'audio' => MediaAssetKind.audio,
      'video' => MediaAssetKind.video,
      _ => MediaAssetKind.image,
    };
    final statusRaw =
        (json['status'] ?? (json['remoteUrl'] != null || json['remote_url'] != null ? 'synced' : 'queued'))
            .toString()
            .toLowerCase();
    final status = switch (statusRaw) {
      'uploading' => MediaUploadStatus.uploading,
      'synced' => MediaUploadStatus.synced,
      'failed' => MediaUploadStatus.failed,
      _ => MediaUploadStatus.queued,
    };
    final rawId3 = json['id3Metadata'] ?? json['id3_metadata_json'];
    final id3Map = rawId3 is Map
        ? Map<String, dynamic>.from(rawId3)
        : const <String, dynamic>{};
    final resolvedThumbUrl =
        (json['thumbnailUrl'] ?? json['thumbnail_url']) as String?;
    return UploadedMediaAsset(
      id: (json['id'] ?? '').toString(),
      creatorId: (json['creatorId'] ?? json['creator_id'] ?? 'creator_cern')
          .toString(),
      kind: kind,
      title: (json['title'] ?? 'Uploaded Media').toString(),
      filename: (json['filename'] ?? 'upload.bin').toString(),
      mimeType:
          (json['mimeType'] ?? json['mime_type'] ?? 'application/octet-stream')
              .toString(),
      sizeBytes:
          ((json['sizeBytes'] ?? json['size_bytes']) as num?)?.toInt() ?? 1,
      localFilePath: json['localFilePath'] as String?,
      thumbnailLocalPath:
          (json['thumbnailLocalPath'] ?? resolvedThumbUrl) as String?,
      thumbnailUrl: resolvedThumbUrl,
      remoteUrl: (json['remoteUrl'] ?? json['remote_url']) as String?,
      remoteKey: (json['r2Key'] ?? json['r2_key']) as String?,
      durationMs: ((json['durationMs'] ?? json['duration_ms']) as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      sourceSurface:
          (json['sourceSurface'] ?? json['source_surface'] ?? 'vault')
              .toString(),
      artist: (json['artist'] ?? id3Map['artist'])?.toString(),
      album: (json['album'] ?? id3Map['album'])?.toString(),
      genre: (json['genre'] ?? id3Map['genre'])?.toString(),
      bpm: ((json['bpm'] ?? id3Map['bpm']) as num?)?.toInt(),
      contentSha256: (json['contentSha256'] ?? json['content_sha256'])?.toString(),
      status: status,
      progress: ((json['progress'] as num?)?.toDouble() ??
              (status == MediaUploadStatus.synced ? 1.0 : 0.0))
          .clamp(0.0, 1.0),
      errorMessage: json['errorMessage'] as String?,
      createdAt:
          DateTime.tryParse(
            (json['createdAt'] ?? json['created_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }
}
