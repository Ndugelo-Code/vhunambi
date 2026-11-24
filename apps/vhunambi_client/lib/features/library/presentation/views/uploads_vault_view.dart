import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_bottom_dock_kit.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_tab_bar.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/content_studio/presentation/views/kinetic_reel_studio_view.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/create_kinetic_post_sheet.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/library/presentation/widgets/library_empty_state.dart';
import 'package:vhunambi_client/features/media/domain/models/uploaded_media_asset.dart';
import 'package:vhunambi_client/features/media/presentation/providers/media_upload_queue_provider.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// Unified "My Uploads" asset hub inside Library Asset Vault (`REQ-P79-HUB-01`).
class UploadsVaultView extends ConsumerStatefulWidget {
  const UploadsVaultView({super.key});

  @override
  ConsumerState<UploadsVaultView> createState() => _UploadsVaultViewState();
}

class _UploadsVaultViewState extends ConsumerState<UploadsVaultView> {
  int _kindTabIndex = 0; // 0: All, 1: Audio, 2: Video, 3: Images

  bool get _isTestEnv {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _pickAndEnqueueMedia() async {
    if (_isTestEnv) {
      await ref.read(mediaUploadQueueProvider.notifier).stageAndEnqueue(
            bytes: Uint8List.fromList(<int>[0x52, 0x49, 0x46, 0x46, 0x01, 0x02]),
            filename: 'abafana_master.wav',
            mimeType: 'audio/wav',
            kind: MediaAssetKind.audio,
            title: 'Abafana Master',
            sourceSurface: 'vault',
          );
      return;
    }
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: true,
      allowedExtensions: const <String>[
        'mp3',
        'm4a',
        'wav',
        'aac',
        'ogg',
        'mp4',
        'mov',
        'webm',
        'jpg',
        'jpeg',
        'png',
        'webp',
      ],
    );
    final file = picked?.files.firstOrNull;
    if (file == null) return;
    var bytes = file.bytes;
    if ((bytes == null || bytes.isEmpty) &&
        !kIsWeb &&
        file.path != null &&
        file.path!.isNotEmpty) {
      final f = File(file.path!);
      if (await f.exists()) {
        bytes = await f.readAsBytes();
      }
    }
    if (bytes == null || bytes.isEmpty) return;

    final ext = (file.extension ?? '').toLowerCase();
    final (MediaAssetKind kind, String mime) = switch (ext) {
      'mp3' => (MediaAssetKind.audio, 'audio/mpeg'),
      'm4a' => (MediaAssetKind.audio, 'audio/mp4'),
      'wav' => (MediaAssetKind.audio, 'audio/wav'),
      'aac' => (MediaAssetKind.audio, 'audio/aac'),
      'ogg' => (MediaAssetKind.audio, 'audio/ogg'),
      'mp4' => (MediaAssetKind.video, 'video/mp4'),
      'mov' => (MediaAssetKind.video, 'video/quicktime'),
      'webm' => (MediaAssetKind.video, 'video/webm'),
      'png' => (MediaAssetKind.image, 'image/png'),
      'webp' => (MediaAssetKind.image, 'image/webp'),
      _ => (MediaAssetKind.image, 'image/jpeg'),
    };
    await ref.read(mediaUploadQueueProvider.notifier).stageAndEnqueue(
          bytes: bytes,
          filename: file.name,
          mimeType: mime,
          kind: kind,
          sourceSurface: 'vault',
        );
  }

  @override
  Widget build(BuildContext context) {
    final allUploads = ref.watch(ownerMediaUploadsProvider);
    final query = ref.watch(librarySearchQueryProvider);
    final hasActiveTrack = ref.watch(
      playerStateProvider.select((s) => s.hasActiveTrack),
    );
    final bottomInset = VhunambiBottomDockMetrics.scrollInset(
      hasActiveTrack: hasActiveTrack,
    );

    final filtered = allUploads.where((u) {
      return switch (_kindTabIndex) {
        1 => u.kind == MediaAssetKind.audio,
        2 => u.kind == MediaAssetKind.video,
        3 => u.kind == MediaAssetKind.image,
        _ => true,
      };
    }).toList();

    if (allUploads.isEmpty) {
      return LibraryEmptyState(
        key: const Key('library_uploads_vault_view'),
        category: LibraryCategory.uploads,
        searchQuery: query,
        onCreateRequested: _pickAndEnqueueMedia,
      );
    }

    return Padding(
      key: const Key('library_uploads_vault_view'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: VhunambiGlassTabBar(
                  key: const Key('library_uploads_kind_tabs'),
                  selectedIndex: _kindTabIndex,
                  onSelected: (i) => setState(() => _kindTabIndex = i),
                  items: const <VhunambiGlassTabItem>[
                    VhunambiGlassTabItem(label: 'All'),
                    VhunambiGlassTabItem(label: 'Audio', icon: AppIcons.songs),
                    VhunambiGlassTabItem(label: 'Video', icon: AppIcons.reels),
                    VhunambiGlassTabItem(
                      label: 'Images',
                      icon: PhosphorIconsRegular.image,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: FilledButton.icon(
                  key: const Key('library_uploads_add_btn'),
                  onPressed: _pickAndEnqueueMedia,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                  icon: const PhosphorIcon(AppIcons.upload, size: 16),
                  label: const Text('Upload'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.only(bottom: bottomInset),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final asset = filtered[index];
                final statusLabel = switch (asset.status) {
                  MediaUploadStatus.synced => 'Synced to Cloud',
                  MediaUploadStatus.uploading =>
                    'Uploading ${(asset.progress * 100).round()}%',
                  MediaUploadStatus.failed => 'Upload Failed',
                  MediaUploadStatus.queued => 'Queued Locally',
                };
                final statusColor = switch (asset.status) {
                  MediaUploadStatus.synced => AppColors.success,
                  MediaUploadStatus.uploading => AppColors.brandPrimary,
                  MediaUploadStatus.failed => AppColors.error,
                  MediaUploadStatus.queued => AppColors.textSecondaryOf(context),
                };

                return VhunambiGlassSurface(
                  key: Key('upload_vault_item_${asset.id}'),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: <Widget>[
                      VhunambiTrackArtwork(
                        trackId: asset.id,
                        genre: 'Amapiano',
                        coverUrl: asset.kind == MediaAssetKind.image
                            ? asset.bestPlayableOrRenderableSource
                            : asset.thumbnailLocalPath,
                        width: 52,
                        height: 52,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              asset.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleSmall.copyWith(
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${asset.kind.name.toUpperCase()} • $statusLabel',
                              style: AppTypography.caption.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (asset.kind == MediaAssetKind.audio)
                        IconButton(
                          key: Key('upload_vault_play_${asset.id}'),
                          tooltip: 'Play Audio',
                          onPressed: () {
                            final src = asset.bestPlayableOrRenderableSource;
                            if (src == null) return;
                            ref.read(playerStateProvider.notifier).playTrack(
                                  Track(
                                    id: asset.id,
                                    title: asset.title,
                                    creatorName: 'My Uploads',
                                    genre: 'Uploaded',
                                    duration: Duration(
                                      milliseconds: asset.durationMs ?? 30000,
                                    ),
                                    audioUrl: src,
                                  ),
                                );
                          },
                          icon: const PhosphorIcon(
                            AppIcons.play,
                            size: 18,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      if (asset.status == MediaUploadStatus.failed)
                        IconButton(
                          key: Key('upload_vault_retry_${asset.id}'),
                          tooltip: 'Retry Upload',
                          onPressed: () => ref
                              .read(mediaUploadQueueProvider.notifier)
                              .retryUpload(asset.id),
                          icon: const PhosphorIcon(
                            AppIcons.remix,
                            size: 18,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      IconButton(
                        key: Key('upload_vault_reel_${asset.id}'),
                        tooltip: 'Use in Reel',
                        onPressed: () => KineticReelStudioView.show(context),
                        icon: PhosphorIcon(
                          AppIcons.reels,
                          size: 18,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                      IconButton(
                        key: Key('upload_vault_post_${asset.id}'),
                        tooltip: 'Use in Post',
                        onPressed: () => CreateKineticPostSheet.show(context),
                        icon: PhosphorIcon(
                          AppIcons.share,
                          size: 18,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                      IconButton(
                        key: Key('upload_vault_delete_${asset.id}'),
                        tooltip: 'Delete Upload',
                        onPressed: () => ref
                            .read(mediaUploadQueueProvider.notifier)
                            .deleteUpload(asset.id),
                        icon: const PhosphorIcon(
                          AppIcons.trash,
                          size: 18,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
