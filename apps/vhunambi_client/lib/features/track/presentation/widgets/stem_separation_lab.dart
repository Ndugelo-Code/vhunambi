import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/track_detail_models.dart';

/// 4-Stem Separation Lab with FSM Progress & Real Stem Controls (REQ-TRK-09 / STD-UIUX-001).
class StemSeparationLab extends StatelessWidget {
  final StemSeparationState stemState;
  final VoidCallback onSeparateStems;
  final ValueChanged<String> onToggleMuteStem;
  final ValueChanged<String> onToggleSoloStem;
  final ValueChanged<StemTrackEntity>? onDownloadStem;
  final VoidCallback? onOpenFullMixer;

  const StemSeparationLab({
    super.key,
    required this.stemState,
    required this.onSeparateStems,
    required this.onToggleMuteStem,
    required this.onToggleSoloStem,
    this.onDownloadStem,
    this.onOpenFullMixer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(
          color: stemState.isReady
              ? AppColors.brandPrimary.withAlpha(90)
              : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title Row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: PhosphorIcon(
                    PhosphorIconsRegular.stack,
                    color: AppColors.brandPrimary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stem Separation Lab',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Split this song into vocals, drums, bass, and instrumental.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!stemState.isReady && !stemState.isProcessing)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A2508),
                    foregroundColor: AppColors.brandPrimary,
                    side: const BorderSide(color: AppColors.brandPrimary),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    elevation: 0,
                  ),
                  onPressed: onSeparateStems,
                  icon: const PhosphorIcon(PhosphorIconsRegular.sliders, size: 16),
                  label: const Text(
                    'Separate',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
            ],
          ),

          // Processing State Indicator
          if (stemState.isProcessing) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          stemState.stepLabel,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${(stemState.progress * 100).round()}%',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: stemState.progress,
                      backgroundColor: AppColors.surfaceCanvas,
                      color: AppColors.brandPrimary,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Ready State: 4 Isolated Stem Cards
          if (stemState.isReady) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.borderSubtle),
            const SizedBox(height: 12),
            ...stemState.stems.map((stem) => _buildStemCard(stem, context)),
            if (onOpenFullMixer != null) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: onOpenFullMixer,
                  icon: const PhosphorIcon(PhosphorIconsRegular.faders, size: 16),
                  label: const Text('Open Pocket Stem Mixer Deck'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStemCard(StemTrackEntity stem, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: stem.isSoloed
            ? AppColors.brandPrimary.withAlpha(20)
            : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: stem.isSoloed
              ? AppColors.brandPrimary
              : (stem.isMuted
                  ? AppColors.borderSubtle.withAlpha(50)
                  : AppColors.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          // Stem Icon
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: PhosphorIcon(
                _getStemIcon(stem.name),
                size: 16,
                color: stem.isMuted
                    ? AppColors.textTertiary
                    : AppColors.brandPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Stem Name
          Expanded(
            child: Text(
              stem.name,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: stem.isMuted
                    ? AppColors.textTertiary
                    : AppColors.textPrimary,
              ),
            ),
          ),

          // Solo Pill Button
          InkWell(
            onTap: () => onToggleSoloStem(stem.id),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: stem.isSoloed
                    ? AppColors.brandPrimary
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: stem.isSoloed
                      ? AppColors.brandPrimary
                      : AppColors.borderSubtle,
                ),
              ),
              child: Text(
                'SOLO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: stem.isSoloed
                      ? AppColors.brandContrast
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Mute Button
          IconButton(
            iconSize: 20,
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: PhosphorIcon(
              stem.isMuted
                  ? PhosphorIconsRegular.speakerSlash
                  : PhosphorIconsRegular.speakerHigh,
              color: stem.isMuted
                  ? AppColors.textTertiary
                  : AppColors.textSecondary,
            ),
            onPressed: () => onToggleMuteStem(stem.id),
          ),

          const SizedBox(width: 4),

          // Download Stem Trigger
          IconButton(
            iconSize: 20,
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const PhosphorIcon(
              PhosphorIconsRegular.downloadSimple,
              color: AppColors.textSecondary,
            ),
            onPressed: () => onDownloadStem?.call(stem),
          ),
        ],
      ),
    );
  }

  IconData _getStemIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('vocal')) return PhosphorIconsRegular.microphone;
    if (lower.contains('drum')) return PhosphorIconsRegular.disc;
    if (lower.contains('bass')) return PhosphorIconsRegular.waveSine;
    return PhosphorIconsRegular.pianoKeys;
  }
}
