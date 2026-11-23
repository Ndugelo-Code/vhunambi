import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/features/studio/domain/services/bantu_lyric_translation_service.dart';

/// Compact Light/Dark-safe glass sheet explaining an indigenous Southern Bantu
/// lyric word across all 9 constitutional languages (`REQ-P77-LYR-04`).
class BantuWordGlossarySheet extends StatelessWidget {
  final BantuWordDefinition definition;
  final Color? accentColor;

  const BantuWordGlossarySheet({
    super.key,
    required this.definition,
    this.accentColor,
  });

  static Future<void> show(
    BuildContext context, {
    required BantuWordDefinition definition,
    Color? accentColor,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BantuWordGlossarySheet(
        definition: definition,
        accentColor: accentColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.brandPrimary;
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final borderSubtle = AppColors.borderSubtleOf(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: VhunambiGlassSurface(
          key: const Key('bantu_word_glossary_sheet'),
          variant: VhunambiGlassVariant.chrome,
          enableLiveBlur: false,
          borderRadius: AppRadius.modalBorder,
          borderColorOverride: accent.withValues(alpha: 0.35),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          definition.originalWord,
                          style: AppTypography.titleLarge.copyWith(
                            color: textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            borderRadius: AppRadius.pillBorder,
                            border: Border.all(
                              color: accent.withValues(alpha: 0.32),
                            ),
                          ),
                          child: Text(
                            '${definition.sourceLanguage.displayName} · ${definition.branchLabel}',
                            style: AppTypography.badge.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('bantu_glossary_close_btn'),
                    tooltip: 'Close word glossary',
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: PhosphorIcon(
                      AppIcons.close,
                      size: 20,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevatedOf(context),
                  borderRadius: AppRadius.cardBorder,
                  border: Border.all(color: borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRONUNCIATION (PENULTIMATE STRESS)',
                      style: AppTypography.badge.copyWith(
                        color: textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    BantuLyricTranslationService.buildStyledPhoneticGuide(
                      definition.syllabifiedPhonetic,
                      baseStyle: AppTypography.titleSmall.copyWith(
                        color: textPrimary,
                      ),
                      accentColor: accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevatedOf(context),
                  borderRadius: AppRadius.cardBorder,
                  border: Border.all(color: borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MEANING',
                      style: AppTypography.badge.copyWith(
                        color: textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      definition.hasMeaning
                          ? definition.meaning
                          : 'Syllable-verified indigenous root (${definition.sourceLanguage.displayName}); direct glossary entry not yet curated.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (definition.cognates.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'SOUTHERN BANTU COGNATES (${definition.cognates.length})',
                  style: AppTypography.badge.copyWith(
                    color: textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final cognate in definition.cognates)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: AppRadius.pillBorder,
                          border: Border.all(
                            color: accent.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          '${cognate.target.displayName}: ${cognate.targetWord} (${cognate.score}%)',
                          style: AppTypography.caption.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
