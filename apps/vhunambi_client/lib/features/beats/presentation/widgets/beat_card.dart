import 'package:flutter/material.dart';

import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/producer_beat_entity.dart';
import '../beat_format.dart';
import 'beat_status_badge.dart';

/// Responsive grid card for a producer beat (REQ-BEAT-15).
///
/// Renders the regional genre gradient artwork with BPM / key badges, the
/// publication status badge, the price + sales footer and the audition action.
class BeatCard extends StatelessWidget {
  final ProducerBeatEntity beat;

  /// `true` while this beat owns the preview playing in the player dock.
  final bool isAuditioning;
  final VoidCallback onTap;
  final VoidCallback onAudition;
  final VoidCallback onEdit;
  final VoidCallback onTogglePublish;
  final VoidCallback onExportStems;
  final VoidCallback onDelete;

  const BeatCard({
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
    final gradient = beatGenreGradient(beat.genre);

    return Material(
      color: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('beat_card_${beat.id}'),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BeatArtwork(beat: beat, gradient: gradient),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      beat.title,
                      style: AppTypography.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${beat.producerHandle} • '
                      '${beat.stemPackage.stemCountLabel}',
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            beat.salesLabel,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.coinGold,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _AuditionButton(
                          beatId: beat.id,
                          isAuditioning: isAuditioning,
                          onPressed: onAudition,
                        ),
                        _BeatOverflowMenu(
                          beatId: beat.id,
                          isPublished: beat.isPublished,
                          onEdit: onEdit,
                          onTogglePublish: onTogglePublish,
                          onExportStems: onExportStems,
                          onDelete: onDelete,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BeatArtwork extends StatelessWidget {
  final ProducerBeatEntity beat;
  final List<Color> gradient;

  const _BeatArtwork({required this.beat, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MetaPill(label: beat.bpmLabel),
              const SizedBox(width: AppSpacing.xxs),
              Flexible(child: _MetaPill(label: beat.keyLabel)),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              BeatStatusBadge(status: beat.status, compact: true),
              const Spacer(),
              PhosphorIcon(
                AppIcons.waveform,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cyan BPM / musical key badge overlay (Blueprint 14 §2.1).
class _MetaPill extends StatelessWidget {
  final String label;

  const _MetaPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.badgeCyanBg,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: AppColors.badgeCyan),
      ),
      child: Text(
        label,
        style: AppTypography.badge.copyWith(color: AppColors.badgeCyan),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _AuditionButton extends StatelessWidget {
  final String beatId;
  final bool isAuditioning;
  final VoidCallback onPressed;

  const _AuditionButton({
    required this.beatId,
    required this.isAuditioning,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isAuditioning ? 'Pause preview' : 'Audition preview',
      child: InkWell(
        key: Key('beat_play_$beatId'),
        onTap: onPressed,
        borderRadius: AppRadius.thumbBorder,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isAuditioning
                ? AppColors.brandPrimary
                : AppColors.surfaceSecondary,
            borderRadius: AppRadius.thumbBorder,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: PhosphorIcon(
            isAuditioning ? AppIcons.pause : AppIcons.play,
            size: 18,
            color: isAuditioning
                ? AppColors.brandContrast
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Edit / Publish / Export / Delete contextual menu (Blueprint 14 §2.1).
class _BeatOverflowMenu extends StatelessWidget {
  final String beatId;
  final bool isPublished;
  final VoidCallback onEdit;
  final VoidCallback onTogglePublish;
  final VoidCallback onExportStems;
  final VoidCallback onDelete;

  const _BeatOverflowMenu({
    required this.beatId,
    required this.isPublished,
    required this.onEdit,
    required this.onTogglePublish,
    required this.onExportStems,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: Key('beat_menu_$beatId'),
      icon: PhosphorIcon(
        AppIcons.dotsVertical,
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
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_rounded, size: 16, color: AppColors.textPrimary),
              SizedBox(width: AppSpacing.xs),
              Flexible(child: Text('Edit Beat')),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'publish',
          child: Row(
            children: [
              Icon(
                isPublished
                    ? Icons.visibility_off_rounded
                    : Icons.rocket_launch_rounded,
                size: 16,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  isPublished ? 'Switch to Draft' : 'Publish to Marketplace',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'stems',
          child: Row(
            children: [
              Icon(
                Icons.download_rounded,
                size: 16,
                color: AppColors.textPrimary,
              ),
              SizedBox(width: AppSpacing.xs),
              Flexible(child: Text('Export Stems')),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: AppColors.error,
              ),
              SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  'Delete',
                  style: TextStyle(color: AppColors.error),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
