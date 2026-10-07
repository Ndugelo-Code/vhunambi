import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/studio_form_provider.dart';

class MultilingualLanguageSelector extends ConsumerStatefulWidget {
  const MultilingualLanguageSelector({super.key});

  @override
  ConsumerState<MultilingualLanguageSelector> createState() =>
      _MultilingualLanguageSelectorState();
}

class _MultilingualLanguageSelectorState
    extends ConsumerState<MultilingualLanguageSelector> {
  bool _isExpanded = false;

  static const List<String> _saOfficialLanguages = [
    'Tshivenḓa',
    'isiZulu',
    'isiXhosa',
    'Afrikaans',
    'English',
    'Sesotho sa Leboa',
    'Setswana',
    'Sesotho',
    'Xitsonga',
    'siSwati',
    'isiNdebele',
  ];

  static const List<String> _continentalLanguages = [
    'Kiswahili',
    'Hausa',
    'Yorùbá',
    'Igbo',
    'አማርኛ',
    'Soomaali',
    'ChiShona',
    'Luganda',
    'Kinyarwanda',
    'Lingála',
    'Wolof',
    'Twi',
  ];

  static const List<String> _globalLanguages = [
    'Français',
    'Português',
    'العربية',
    'Español',
    'Hindi',
  ];

  @override
  Widget build(BuildContext context) {
    final activeLanguage =
        ref.watch(studioFormProvider.select((s) => s.language));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Accordion Toggle
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: AppRadius.cardBorder,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.translate_rounded,
                    size: 20,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Language',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      activeLanguage,
                      style: AppTypography.badge.copyWith(
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            const Divider(color: AppColors.borderSubtle, height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'South African Official Languages',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _buildLanguageChipWrap(_saOfficialLanguages, activeLanguage),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Continental African Languages',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _buildLanguageChipWrap(_continentalLanguages, activeLanguage),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Diaspora & Global Languages',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _buildLanguageChipWrap(_globalLanguages, activeLanguage),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLanguageChipWrap(List<String> languages, String activeLanguage) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: languages.map((lang) {
        final isSelected = lang == activeLanguage;
        return InkWell(
          onTap: () {
            ref.read(studioFormProvider.notifier).setLanguage(lang);
          },
          borderRadius: AppRadius.pillBorder,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.brandPrimary
                  : AppColors.surfaceSecondary,
              borderRadius: AppRadius.pillBorder,
              border: Border.all(
                color: isSelected
                    ? AppColors.brandPrimary
                    : AppColors.borderSubtle,
              ),
            ),
            child: Text(
              lang,
              style: AppTypography.bodySmall.copyWith(
                color: isSelected
                    ? AppColors.brandContrast
                    : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
