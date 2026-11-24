import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/media/sovereign_media_storage_service.dart';
import 'package:vhunambi_client/core/utils/creator_id_utils.dart';
import 'package:vhunambi_client/features/media/data/repositories/http_media_upload_repository.dart';
import 'package:vhunambi_client/features/media/domain/models/uploaded_media_asset.dart';
import 'package:vhunambi_client/features/social/domain/repositories/i_social_repository.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_repository_provider.dart';

/// Optional custom [IMediaUploadRepository] override for unit/widget tests.
final customMediaUploadRepositoryProvider = Provider<IMediaUploadRepository?>(
  (ref) => null,
);

final mediaUploadRepositoryProvider = Provider<IMediaUploadRepository>((ref) {
  final custom = ref.watch(customMediaUploadRepositoryProvider);
  if (custom != null) return custom;
  return HttpMediaUploadRepository(
    authInterceptor: ref.watch(authDioInterceptorProvider),
  );
});

final mediaUploadQueueProvider =
    StateNotifierProvider<MediaUploadQueueNotifier, List<UploadedMediaAsset>>((
      ref,
    ) {
      final creatorId = ref.watch(currentCreatorIdProvider);
      final repo = ref.watch(mediaUploadRepositoryProvider);
      final hasCustomMediaRepo =
          ref.watch(customMediaUploadRepositoryProvider) != null;
      final socialRepo = ref.watch(socialRepositoryProvider);
      return MediaUploadQueueNotifier(
        creatorId: creatorId,
        repository: repo,
        fallbackSocialRepository: socialRepo,
        useTestSocialFallback:
            SovereignMediaStorageService.isTestEnv && !hasCustomMediaRepo,
      );
    });

class MediaUploadQueueNotifier extends StateNotifier<List<UploadedMediaAsset>> {
  final String creatorId;
  final IMediaUploadRepository repository;
  final ISocialRepository fallbackSocialRepository;
  final bool useTestSocialFallback;
  final Map<String, Uint8List> _inMemoryBytes = <String, Uint8List>{};

  MediaUploadQueueNotifier({
    required this.creatorId,
    required this.repository,
    required this.fallbackSocialRepository,
    required this.useTestSocialFallback,
  }) : super(
         SovereignMediaStorageService.loadCreatorAssets(
           canonicalizeCreatorId(creatorId),
         ),
       );

  /// Stages [bytes] locally in <50ms, records [UploadedMediaAsset] in Hive,
  /// and starts background R2 upload (or awaits completion when [awaitUpload] is true).
  Future<UploadedMediaAsset> stageAndEnqueue({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required MediaAssetKind kind,
    String? title,
    String sourceSurface = 'vault',
    int? durationMs,
    int? width,
    int? height,
    bool awaitUpload = false,
  }) async {
    final cid = canonicalizeCreatorId(creatorId);
    final id = 'upl_${DateTime.now().microsecondsSinceEpoch}';
    final localPath = await SovereignMediaStorageService.stageMediaBytes(
      creatorId: cid,
      assetId: id,
      kind: kind,
      filename: filename,
      mimeType: mimeType,
      bytes: bytes,
    );
    final resolvedTitle = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : filename.replaceAll(RegExp(r'\.[^.]+$'), '').trim();

    final initial = UploadedMediaAsset(
      id: id,
      creatorId: cid,
      kind: kind,
      title: resolvedTitle.isEmpty ? 'Uploaded Media' : resolvedTitle,
      filename: filename,
      mimeType: mimeType,
      sizeBytes: bytes.length,
      localFilePath: localPath,
      sourceSurface: sourceSurface,
      durationMs: durationMs,
      width: width,
      height: height,
      status: MediaUploadStatus.queued,
      progress: 0.0,
      createdAt: DateTime.now(),
    );

    _inMemoryBytes[id] = bytes;
    state = <UploadedMediaAsset>[
      initial,
      ...state.where((e) => e.id != id),
    ];
    await SovereignMediaStorageService.saveAsset(initial);

    if (awaitUpload) {
      return _performUpload(id);
    }
    unawaited(_performUpload(id));
    return initial;
  }

  Future<UploadedMediaAsset> _performUpload(String assetId) async {
    final idx = state.indexWhere((a) => a.id == assetId);
    if (idx == -1) {
      throw StateError('Upload asset $assetId not found');
    }
    final current = state[idx];
    Uint8List? bytes = _inMemoryBytes[assetId];
    if (bytes == null &&
        !kIsWeb &&
        current.localFilePath != null &&
        File(current.localFilePath!).existsSync()) {
      bytes = SovereignMediaStorageService.isTestEnv
          ? File(current.localFilePath!).readAsBytesSync()
          : await File(current.localFilePath!).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) {
      final failedMissing = current.copyWith(
        status: MediaUploadStatus.failed,
        clearRemoteUrl: true,
        errorMessage: 'Local media file unavailable for upload.',
      );
      await _replaceAsset(failedMissing);
      return failedMissing;
    }

    final uploading = current.copyWith(
      status: MediaUploadStatus.uploading,
      progress: 0.05,
      clearError: true,
    );
    await _replaceAsset(uploading);

    try {
      if (useTestSocialFallback) {
        final socialRes = await fallbackSocialRepository.uploadReelMedia(
          bytes: bytes,
          filename: uploading.filename,
          mimeType: uploading.mimeType,
        );
        final syncedTest = uploading.copyWith(
          remoteUrl: socialRes.url,
          remoteKey: socialRes.url.replaceFirst(RegExp(r'^/r2/'), ''),
          status: MediaUploadStatus.synced,
          progress: 1.0,
          clearError: true,
        );
        await _replaceAsset(syncedTest);
        return syncedTest;
      }

      final synced = await repository.uploadMedia(
        staged: uploading,
        bytes: bytes,
        onProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          final pct = (sent / total).clamp(0.05, 0.98);
          _updateProgressInMemory(assetId, pct);
        },
      );
      await _replaceAsset(synced);
      return synced;
    } catch (e) {
      final failed = uploading.copyWith(
        status: MediaUploadStatus.failed,
        clearRemoteUrl: true,
        progress: 0.0,
        errorMessage: e.toString(),
      );
      await _replaceAsset(failed);
      return failed;
    }
  }

  void _updateProgressInMemory(String assetId, double progress) {
    final idx = state.indexWhere((a) => a.id == assetId);
    if (idx == -1) return;
    final next = List<UploadedMediaAsset>.of(state);
    next[idx] = next[idx].copyWith(
      status: MediaUploadStatus.uploading,
      progress: progress,
    );
    state = next;
  }

  Future<void> _replaceAsset(UploadedMediaAsset updated) async {
    if (!mounted) return;
    state = <UploadedMediaAsset>[
      for (final item in state)
        if (item.id == updated.id) updated else item,
    ];
    await SovereignMediaStorageService.saveAsset(updated);
  }

  Future<UploadedMediaAsset?> retryUpload(String assetId) async {
    final exists = state.any((a) => a.id == assetId);
    if (!exists) return null;
    return _performUpload(assetId);
  }

  Future<void> retryAllPending() async {
    final pendingIds = state
        .where(
          (a) =>
              a.status == MediaUploadStatus.failed ||
              a.status == MediaUploadStatus.queued,
        )
        .map((a) => a.id)
        .toList();
    for (final id in pendingIds) {
      await _performUpload(id);
    }
  }

  Future<void> deleteUpload(String assetId) async {
    final target = state.where((a) => a.id == assetId).firstOrNull;
    if (target == null) return;
    _inMemoryBytes.remove(assetId);
    state = state.where((a) => a.id != assetId).toList();
    await SovereignMediaStorageService.removeAsset(target);
    if (!SovereignMediaStorageService.isTestEnv &&
        target.status == MediaUploadStatus.synced) {
      try {
        await repository.deleteRemoteUpload(assetId);
      } catch (_) {}
    }
  }

  Future<void> syncFromCloud() async {
    if (useTestSocialFallback) return;
    try {
      final remote = await repository.fetchUploads(
        creatorId: canonicalizeCreatorId(creatorId),
      );
      if (!mounted || remote.isEmpty) return;
      final byId = <String, UploadedMediaAsset>{
        for (final local in state) local.id: local,
      };
      for (final cloudItem in remote) {
        final existing = byId[cloudItem.id];
        byId[cloudItem.id] = existing != null
            ? cloudItem.copyWith(localFilePath: existing.localFilePath)
            : cloudItem;
        await SovereignMediaStorageService.saveAsset(byId[cloudItem.id]!);
      }
      final merged = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = merged;
    } catch (_) {}
  }
}
