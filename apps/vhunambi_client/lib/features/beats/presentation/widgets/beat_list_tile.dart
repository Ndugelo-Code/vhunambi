import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/producer_beat_entity.dart';
import '../beat_format.dart';
import 'beat_status_badge.dart';

/// Dense vault list row for a producer beat (REQ-BEAT-16).
///
/// Wrapped in `Material` so the ink splash never clips against a decorated
/// `Container` (Blueprint 14 §5.4).
class BeatListTile extends StatelessWidget {
  final ProducerBeatEntity beat;
  final bool isAuditioning;
  final VoidCallback onTap;
  final VoidCallback onAudition;
  final VoidCallback onEdit;
  final VoidCallback onTogglePublish;
  final VoidCallback onExportStems;
  final VoidCallback onDelete;

  const BeatListTile({
    super.key,
    required this.beat,
    required this.onTap,
    required this.onAudition,
    required this.onEdit,
    required this.onTogglePublish,
    required this.onExportStems,
    required this.onDelete,
    this.isAuditioning = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Narrow viewports drop the price chip so the trailing cluster always
        // fits next to the title (ListTile width assertion guard).
        final showPrice = constraints.maxWidth >= 560;

        return Material(
          color: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.cardBorder,
            side: BorderSide(color: AppColors.borderSubtle),
          ),
          child: ListTile(
            key: ValueKey<String>('beat_tile_${beat.id}'),
            onTap: onTap,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
            ),
            leading: _BeatArtworkThumb(
              beat: beat,
              isAuditioning: isAuditioning,
              onPressed: onAudition,
            ),
            title: Text(
              beat.title,
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              beat.metadataLabel,
              style: AppTypography.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showPrice) ...[
                  Text(
                    beat.priceLabel,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.coinGold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                BeatStatusBadge(status: beat.status, compact: true),
                Switch(
                  key: Key('beat_publish_switch_${beat.id}'),
                  value: beat.isPublished,
                  onChanged: (_) => onTogglePublish(),
                ),
                BeatTileOverflowMenu(
                  beat: beat,
                  onEdit: onEdit,
                  onTogglePublish: onTogglePublish,
                  onExportStems: onExportStems,
                  onDelete: onDelete,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Edit / Publish / Export / Delete menu shared by list rows (REQ-BEAT-16).
class BeatTileOverflowMenu extends StatelessWidget {
  final ProducerBeatEntity beat;
  final VoidCallback onEdit;
  final VoidCallback onTogglePublish;
  final VoidCallback onExportStems;
  final VoidCallback onDelete;

  const BeatTileOverflowMenu({
    super.key,
    required this.beat,
    required this.onEdit,
    required this.onTogglePublish,
    required this.onExportStems,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: Key('beat_tile_menu_${beat.id}'),
      icon: Icon(
        Icons.more_vert_rounded,
        size: 18,
        color: AppColors.textSecondary,
      ),
      color: AppColors.surfaceModal,
      tooltip: 'Beat actions',
      onSelected: (action) {
        if (action == 'edit') onEdit();
        if (action == 'publish') onTogglePublish();
        if (action == 'stems') onExportStems();
        if (action == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        const PopupMenuItem<String>(
          value: 'edit',
          child: Text('Edit Beat'),
        ),
        PopupMenuItem<String>(
          value: 'publish',
          child: Text(
            beat.isPublished ? 'Switch to Draft' : 'Publish to Marketplace',
          ),
        ),
        const PopupMenuItem<String>(
          value: 'stems',
          child: Text('Export Stems'),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: AppColors.error)),
        ),
      ],
    );
  }
}

/// 48×48 genre squircle with the audition play / pause trigger (REQ-BEAT-16).
class _BeatArtworkThumb extends StatelessWidget {
  final ProducerBeatEntity beat;
  final bool isAuditioning;
  final VoidCallback onPressed;

  const _BeatArtworkThumb({
    required this.beat,
    required this.isAuditioning,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('beat_tile_play_${beat.id}'),
      onTap: onPressed,
      borderRadius: AppRadius.squircleBorder,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: beatGenreGradient(beat.genre),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.squircleBorder,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Icon(
          isAuditioning ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 22,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
