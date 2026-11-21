import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../../../core/widgets/vhunambi_track_artwork.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../providers/offline_providers.dart';

/// Modal dialog/bottom-sheet presenting vault storage quota, cached tracks,
/// and cache eviction controls (REQ-OFF-06, REQ-OFF-11).
class VaultStorageModal extends ConsumerWidget {
  const VaultStorageModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceModalOf(context),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.modalBorder,
        side: BorderSide(color: AppColors.borderSubtleOf(context)),
      ),
      builder: (_) => const VaultStorageModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(cacheStorageStatsProvider);
    final allTracks = ref.watch(libraryTracksProvider);
    final cachedTracks = allTracks
        .where((t) => t.syncStatus == TrackSyncStatus.cachedLocally)
        .toList(growable: false);
    final prefs = ref.watch(offlinePreferencesProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Drag Handle & Title
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withAlpha(30),
                    borderRadius: AppRadius.cardBorder,
                  ),
                  child: const PhosphorIcon(
                    PhosphorIconsRegular.hardDrives,
                    color: AppColors.brandPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vault Storage Quota',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${stats.cachedTrackCount} songs cached offline • Playable anywhere',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  child: IconButton(
                    icon: PhosphorIcon(
                      PhosphorIconsRegular.x,
                      color: AppColors.textSecondaryOf(context),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // 2. Storage Quota Bar Card
            VhunambiGlassSurface(
              key: const Key('vault_storage_meter'),
              variant: VhunambiGlassVariant.card,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Storage Used',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                      Text(
                        '${stats.formattedBytesUsed} / ${stats.formattedStorageLimit}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: AppRadius.pillBorder,
                    child: LinearProgressIndicator(
                      value: stats.quotaUsagePercentage == 0
                          ? 0.01
                          : stats.quotaUsagePercentage,
                      backgroundColor: AppColors.surfaceSecondaryOf(context),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.brandPrimary,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${stats.formattedRemainingBytes} free space remaining in your vault quota.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondaryOf(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Max Storage Ceiling',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                _LimitChip(label: '1.0 GB', bytes: 1073741824, current: prefs.storageLimitBytes),
                _LimitChip(label: '2.0 GB', bytes: 2147483648, current: prefs.storageLimitBytes),
                _LimitChip(label: '5.0 GB', bytes: 5368709120, current: prefs.storageLimitBytes),
                _LimitChip(label: '10.0 GB', bytes: 10737418240, current: prefs.storageLimitBytes),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // 3. Cached Tracks Shelf Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CACHED AUDIO MASTERS',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
                if (cachedTracks.isNotEmpty)
                  TextButton(
                    onPressed: () => _confirmClearAll(context, ref),
                    child: Text(
                      'Clear All',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            // 4. Cached Tracks List or Empty State
            if (cachedTracks.isEmpty)
              VhunambiGlassSurface(
                variant: VhunambiGlassVariant.card,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.lg,
                  horizontal: AppSpacing.md,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      PhosphorIcon(
                        PhosphorIconsRegular.cloudArrowDown,
                        size: 32,
                        color: AppColors.textSecondaryOf(context),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'No tracks cached offline yet',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap "Download Offline" on any vault track to enable playback without an internet connection.',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: cachedTracks.length,
                  separatorBuilder: (_, _) =>
                      Divider(color: AppColors.borderSubtle, height: 1),
                  itemBuilder: (context, index) {
                    final track = cachedTracks[index];
                    return _CachedTrackTile(track: track);
                  },
                ),
              ),

            const SizedBox(height: AppSpacing.md),

            // 5. Offline Preferences Toggle Strip
            InkWell(
              key: const Key('vault_wifi_only_switch'),
              borderRadius: AppRadius.cardBorder,
              onTap: () => ref.read(offlinePreferencesProvider.notifier).toggleWifiOnly(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Text('Download over Wi-Fi only', style: AppTypography.bodySmall),
                    const Spacer(),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 24,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.pillBorder,
                        color: prefs.downloadWifiOnly ? AppColors.brandPrimary : AppColors.surfaceSecondary,
                      ),
                      child: Align(
                        alignment: prefs.downloadWifiOnly ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceCanvasOf(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondaryOf(context),
                borderRadius: AppRadius.cardBorder,
              ),
              child: Row(
                children: [
                  PhosphorIcon(
                    PhosphorIconsRegular.wifiSlash,
                    size: 18,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Force Offline Simulation Mode',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    key: const Key('vault_force_offline_switch'),
                    value: prefs.isOfflineModeForced,
                    activeTrackColor: AppColors.brandPrimary,
                    onChanged: (_) {
                      ref
                          .read(offlinePreferencesProvider.notifier)
                          .toggleOfflineMode();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('vault_clear_all_downloads_btn'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  side: const BorderSide(color: AppColors.error),
                  foregroundColor: AppColors.error,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
                icon: const PhosphorIcon(PhosphorIconsRegular.broom, size: 18),
                label: const Text('Clear All Offline Downloads'),
                onPressed: cachedTracks.isEmpty ? null : () => _confirmClearAll(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceModalOf(dialogCtx),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.cardBorder,
            side: BorderSide(color: AppColors.borderSubtleOf(dialogCtx)),
          ),
          title: Text(
            'Clear all downloaded audio?',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textPrimaryOf(dialogCtx),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'This will delete all offline audio files from your device. You can download them again at any time.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryOf(dialogCtx),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(
                'Cancel',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondaryOf(dialogCtx),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.brandContrast,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
              onPressed: () {
                ref
                    .read(downloadManagerProvider.notifier)
                    .clearAllOfflineTracks();
                Navigator.of(dialogCtx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('All offline audio files cleared from device.'),
                    backgroundColor: AppColors.surfaceElevated,
                  ),
                );
              },
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }
}

class _CachedTrackTile extends ConsumerWidget {
  final LibraryTrack track;

  const _CachedTrackTile({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          VhunambiTrackArtwork(
            coverUrl: track.coverImageUrl,
            genre: track.genre,
            trackId: track.id,
            width: 36,
            height: 36,
            borderRadius: AppRadius.cardBorder,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${track.genre} • ~8.5 MB',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: IconButton(
              icon: PhosphorIcon(
                AppIcons.trash,
                color: AppColors.textSecondaryOf(context),
                size: 18,
              ),
              tooltip: 'Remove offline file',
            onPressed: () {
              ref
                  .read(downloadManagerProvider.notifier)
                  .removeOfflineTrack(track.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed "${track.title}" from offline vault.'),
                  backgroundColor: AppColors.surfaceElevatedOf(context),
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

class _LimitChip extends ConsumerWidget {
  final String label;
  final int bytes;
  final int current;

  const _LimitChip({
    required this.label,
    required this.bytes,
    required this.current,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = bytes == current;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.brandPrimary.withAlpha(50),
      backgroundColor: AppColors.surfaceSecondary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.brandPrimary : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) {
        ref
            .read(offlinePreferencesProvider.notifier)
            .setStorageLimitBytes(bytes);
      },
    );
  }
}
