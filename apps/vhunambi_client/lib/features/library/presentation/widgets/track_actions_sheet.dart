import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/library_models.dart';
import '../../../offline/presentation/providers/offline_providers.dart';
import '../../../playlists/presentation/widgets/add_to_playlist_sheet.dart';
import '../providers/library_providers.dart';
import 'library_badges.dart';
import 'library_cover_art.dart';

/// Contextual vault asset action sheet (REQ-LIB-06).
///
/// Triggered by the `⋮` control on any vault tile, grid card, or header action.
class TrackActionsSheet extends ConsumerWidget {
  final LibraryTrack track;

  /// Host context retained so follow-up dialogs can mount after the sheet closes.
  final BuildContext? hostContext;

  const TrackActionsSheet({
    super.key,
    required this.track,
    this.hostContext,
  });

  static Future<void> show(BuildContext context, LibraryTrack track) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceModal,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.modalBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (_) => TrackActionsSheet(track: track, hostContext: context),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messenger = ScaffoldMessenger.of(context);

    void close() => Navigator.of(context).pop();

    void notify(String message) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceModal,
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.brandPrimary,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    void handlePlayNow() {
      playLibraryTrack(ref, track);
      close();
      notify('Playing "${track.title}" on the persistent player.');
    }

    void handleAddToPlaylist() {
      // REQ-PL-08 — hand the vault track to the searchable playlist picker.
      final host = hostContext ?? context;
      close();
      AddToPlaylistSheet.show(host, track.toTrack());
    }

    void handleStemSeparation() {
      close();
      notify('Queued 4-stem split for "${track.title}" — Vocals, Drums, Bass & Other.');
    }

    void handleDownloadOffline() {
      ref.read(downloadManagerProvider.notifier).downloadTrack(track);
      close();
      notify('"${track.title}" cached in your device vault — playable offline.');
    }

    void handleRemoveOffline() {
      ref.read(downloadManagerProvider.notifier).removeOfflineTrack(track.id);
      close();
      notify('"${track.title}" removed from offline storage.');
    }

    void handleViewLicense() {
      final host = hostContext ?? context;
      close();
      showLibraryLicenseDialog(host, track);
    }

    void handleShare() {
      close();
      notify('Public preview link: ${track.publicShareUrl}');
    }

    void handleMoveToTrash() {
      final notifier = ref.read(libraryTracksProvider.notifier);
      notifier.deleteTrack(track.id);
      close();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceModal,
          duration: const Duration(seconds: 5),
          content: Text(
            '"${track.title}" moved to Trash — restorable for 30 days.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: AppColors.brandPrimary,
            onPressed: () => notifier.restoreTrack(track.id),
          ),
        ),
      );
    }

    void handleRestore() {
      ref.read(libraryTracksProvider.notifier).restoreTrack(track.id);
      close();
      notify('"${track.title}" restored to your library.');
    }

    void handlePurge() {
      ref.read(libraryTracksProvider.notifier).purgeTrackPermanently(track.id);
      close();
      notify('"${track.title}" permanently deleted.');
    }

    return _TrackActionsLayout(
      track: track,
      onPlayNow: handlePlayNow,
      onAddToPlaylist: handleAddToPlaylist,
      onStemSeparation: handleStemSeparation,
      onDownloadOffline: handleDownloadOffline,
      onRemoveOffline: handleRemoveOffline,
      onViewLicense: handleViewLicense,
      onShare: handleShare,
      onMoveToTrash: handleMoveToTrash,
      onRestore: handleRestore,
      onPurge: handlePurge,
    );
  }
}

class _TrackActionsLayout extends StatelessWidget {
  final LibraryTrack track;
  final VoidCallback onPlayNow;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onStemSeparation;
  final VoidCallback onDownloadOffline;
  final VoidCallback onRemoveOffline;
  final VoidCallback onViewLicense;
  final VoidCallback onShare;
  final VoidCallback onMoveToTrash;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  const _TrackActionsLayout({
    required this.track,
    required this.onPlayNow,
    required this.onAddToPlaylist,
    required this.onStemSeparation,
    required this.onDownloadOffline,
    required this.onRemoveOffline,
    required this.onViewLicense,
    required this.onShare,
    required this.onMoveToTrash,
    required this.onRestore,
    required this.onPurge,
  });

  @override
  Widget build(BuildContext context) {
    final isTrashed = track.isDeleted;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderActive,
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Asset header
              Row(
                children: [
                  LibraryCoverArt(track: track, size: 48),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: AppTypography.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${track.creatorName} • ${track.formattedDuration} • ${track.createdAgoLabel}',
                          style: AppTypography.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            GenreBadge(genre: track.genre),
                            const SizedBox(width: AppSpacing.xs),
                            SyncStatusBadge(track: track),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(),

              if (!isTrashed) ...[
                _ActionTile(
                  icon: Icons.play_arrow_rounded,
                  label: 'Play Now',
                  subtitle: 'Load into the persistent player and start playback',
                  onTap: onPlayNow,
                ),
                _ActionTile(
                  icon: Icons.playlist_add_rounded,
                  label: 'Add to Playlist',
                  subtitle: 'Append to an existing or brand new playlist',
                  onTap: onAddToPlaylist,
                ),
                _ActionTile(
                  icon: Icons.graphic_eq_rounded,
                  label: 'Stem Separation',
                  subtitle: 'Split into Vocals, Drums, Bass & Other',
                  onTap: onStemSeparation,
                ),
                _ActionTile(
                  icon: Icons.download_rounded,
                  label: 'Download Offline',
                  subtitle: track.isOfflineAvailable
                      ? 'Cached in device vault • Tap to re-download'
                      : 'Cache the audio inside your device vault',
                  onTap: onDownloadOffline,
                ),
                if (track.isOfflineAvailable)
                  _ActionTile(
                    icon: Icons.delete_outline_rounded,
                    label: 'Remove Offline Download',
                    subtitle: 'Remove audio from local device storage',
                    onTap: onRemoveOffline,
                  ),
                _ActionTile(
                  icon: Icons.balance_rounded,
                  label: 'View Commercial License',
                  subtitle: '${track.licenseType} • ${track.licenseCertificateId}',
                  onTap: onViewLicense,
                ),
                _ActionTile(
                  icon: Icons.link_rounded,
                  label: 'Share Song',
                  subtitle: track.publicShareUrl,
                  onTap: onShare,
                ),
                const Divider(),
                _ActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Move to Trash',
                  subtitle: 'Restorable for 30 days',
                  isDestructive: true,
                  onTap: onMoveToTrash,
                ),
              ] else ...[
                _ActionTile(
                  icon: Icons.restore_rounded,
                  label: 'Restore Track',
                  subtitle: 'Return this asset to your library',
                  onTap: onRestore,
                ),
                _ActionTile(
                  icon: Icons.delete_forever_rounded,
                  label: 'Delete Permanently',
                  subtitle: 'This cannot be undone',
                  isDestructive: true,
                  onTap: onPurge,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDestructive ? AppColors.error : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.inputBorder,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs + 2,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: AppRadius.thumbBorder,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Icon(icon, size: 17, color: accent),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.bodyLarge.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: AppTypography.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Commercial licensing certificate preview (Blueprint 04 §3.2).
Future<void> showLibraryLicenseDialog(
  BuildContext context,
  LibraryTrack track,
) {
  final messenger = ScaffoldMessenger.of(context);

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.surfaceModal,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.balance_rounded,
                  size: 20,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Commercial License',
                    style: AppTypography.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _LicenseRow(
              label: 'Certificate ID',
              value: track.licenseCertificateId,
            ),
            _LicenseRow(
              label: 'License type',
              value: '${track.licenseType} — 100% ownership',
            ),
            _LicenseRow(
              label: 'Asset',
              value: '${track.title} • ${track.formattedDuration}',
            ),
            _LicenseRow(label: 'Creator', value: track.creatorName),
            _LicenseRow(label: 'Language', value: track.language),
            const SizedBox(height: AppSpacing.md),
            Text(
              'You own 100% of the master recording, publishing and synchronization rights for assets generated on paid plans. Split sheets export with collaborators.',
              style: AppTypography.caption.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Close',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.surfaceModal,
                        duration: const Duration(seconds: 3),
                        content: Text(
                          'PDF export for ${track.licenseCertificateId} ships with the licensing release.',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                  icon: const Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 16,
                    color: AppColors.brandContrast,
                  ),
                  label: Text(
                    'Download PDF',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.brandContrast,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _LicenseRow extends StatelessWidget {
  final String label;
  final String value;

  const _LicenseRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: AppTypography.caption),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
