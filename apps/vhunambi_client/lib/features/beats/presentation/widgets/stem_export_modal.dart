import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/producer_beat_entity.dart';

/// Stems bundle manifest sheet (REQ-BEAT-20).
///
/// Lists the four stem tracks with their availability, exposes per-stem
/// audition / download simulation and the full ZIP manifest action.
class StemExportModal extends StatelessWidget {
  final ProducerBeatEntity beat;

  /// Simulated per-stem audition (Drums / Bass / Melody / Other).
  final void Function(String stemLabel)? onAuditionStem;

  /// Simulated per-stem download.
  final void Function(String stemLabel)? onDownloadStem;

  /// Simulated ZIP bundle export.
  final VoidCallback? onDownloadBundle;

  const StemExportModal({
    super.key,
    required this.beat,
    this.onAuditionStem,
    this.onDownloadStem,
    this.onDownloadBundle,
  });

  List<_StemEntry> get _stems => <_StemEntry>[
        _StemEntry(
          label: 'Drums',
          icon: Icons.album_rounded,
          url: beat.stemPackage.drumsUrl,
        ),
        _StemEntry(
          label: 'Bass',
          icon: Icons.graphic_eq_rounded,
          url: beat.stemPackage.bassUrl,
        ),
        _StemEntry(
          label: 'Melody',
          icon: Icons.piano_rounded,
          url: beat.stemPackage.melodyUrl,
        ),
        _StemEntry(
          label: 'Other',
          icon: Icons.auto_awesome_rounded,
          url: beat.stemPackage.otherUrl,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceModal,
        borderRadius: AppRadius.modalBorder,
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: AppRadius.pillBorder,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(
                Icons.download_rounded,
                size: 18,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Stems Package (${beat.stemPackage.stemCount}/4)',
                  style: AppTypography.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${beat.title} • ${beat.genre} • ${beat.bpmLabel}',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final stem in _stems) ...[
            _StemRow(
              stem: stem,
              onAudition: onAuditionStem == null
                  ? null
                  : () => onAuditionStem!(stem.label),
              onDownload: onDownloadStem == null
                  ? null
                  : () => onDownloadStem!(stem.label),
            ),
            const SizedBox(height: AppSpacing.xxs),
          ],
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              key: const Key('stem_download_bundle'),
              onPressed: () {
                onDownloadBundle?.call();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.folder_zip_rounded, size: 16),
              label: const Text('Download Full ZIP Manifest'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.brandContrast,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StemEntry {
  final String label;
  final IconData icon;
  final String? url;

  const _StemEntry({required this.label, required this.icon, this.url});

  bool get isReady => url != null && url!.isNotEmpty;

  String get slug => label.toLowerCase();
}

class _StemRow extends StatelessWidget {
  final _StemEntry stem;
  final VoidCallback? onAudition;
  final VoidCallback? onDownload;

  const _StemRow({
    required this.stem,
    this.onAudition,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final ready = stem.isReady;

    return Material(
      color: AppColors.surfaceSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.inputBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      child: ListTile(
        key: Key('stem_row_${stem.slug}'),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        leading: Icon(
          stem.icon,
          size: 18,
          color: ready ? AppColors.textPrimary : AppColors.textTertiary,
        ),
        title: Text(
          stem.label,
          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          ready ? 'Ready' : 'Not separated yet',
          style: AppTypography.caption.copyWith(
            color: ready ? AppColors.success : AppColors.textTertiary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: Key('stem_audition_${stem.slug}'),
              tooltip: 'Audition ${stem.label}',
              onPressed: ready ? onAudition : null,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              color: AppColors.textPrimary,
            ),
            IconButton(
              key: Key('stem_download_${stem.slug}'),
              tooltip: 'Download ${stem.label}',
              onPressed: ready ? onDownload : null,
              icon: const Icon(Icons.download_rounded, size: 18),
              color: AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
