import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/library_models.dart';
import 'library_badges.dart';
import 'library_cover_art.dart';

/// Song Details / Musical DNA inspector (Mission 12).
///
/// Surfaces the metadata every generated song carries — genre, language,
/// lifetime play count, favourite status, offline/cloud presence and the
/// creation date — in a single modal bottom sheet.
class TrackDetailsModal extends StatelessWidget {
  final LibraryTrack track;

  const TrackDetailsModal({super.key, required this.track});

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
      builder: (_) => TrackDetailsModal(track: track),
    );
  }

  @override
  Widget build(BuildContext context) {
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

              // Header: cover, title, creator, duration
              Row(
                children: [
                  LibraryCoverArt(track: track, size: 64),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          track.creatorName,
                          style: AppTypography.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          track.formattedDuration,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(color: AppColors.borderSubtle, height: 1),
              const SizedBox(height: AppSpacing.md),

              // Musical specs
              Text(
                'Musical Specs',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  GenreBadge(genre: track.genre),
                  _SpecPill(
                    icon: Icons.translate_rounded,
                    label: track.language,
                  ),
                  _SpecPill(
                    icon: Icons.headphones_rounded,
                    label: track.playCountLabel,
                  ),
                  _SpecPill(
                    icon: track.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: track.isFavorite ? 'Favourited' : 'Not favourited',
                    accent: track.isFavorite,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Storage info
              Text(
                'Storage',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  SyncStatusBadge(track: track),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      track.isOfflineAvailable
                          ? 'Cached on this device • playable offline'
                          : 'Streamed from the cloud • not cached',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _DetailRow(label: 'Created', value: track.createdAgoLabel),
              _DetailRow(label: 'License', value: track.licenseType),
              const SizedBox(height: AppSpacing.md),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool accent;

  const _SpecPill({
    required this.icon,
    required this.label,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: accent ? AppColors.brandPrimary : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: accent ? AppColors.brandPrimary : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
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
