import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_provider.dart';

/// Settings drawer providing appearance / theme mode controls and system preferences.
class ProfileSettingsDrawer extends ConsumerWidget {
  const ProfileSettingsDrawer({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceModal,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.modalBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (_) => const ProfileSettingsDrawer(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeThemeMode = ref.watch(themeModeProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const PhosphorIcon(
                      PhosphorIconsRegular.gear,
                      color: AppColors.brandPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Appearance & Preferences',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const PhosphorIcon(AppIcons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Theme Mode Section Header
            Text(
              'APPLICATION THEME',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),

            // 3-Way Segmented Theme Controller [ System | Light | Dark ]
            Container(
              height: 46,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: AppRadius.pillBorder,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  _buildThemeOption(
                    context: context,
                    ref: ref,
                    label: 'System',
                    icon: PhosphorIconsRegular.deviceMobile,
                    mode: ThemeMode.system,
                    key: const Key('theme_mode_system'),
                    isSelected: activeThemeMode == ThemeMode.system,
                  ),
                  _buildThemeOption(
                    context: context,
                    ref: ref,
                    label: 'Light',
                    icon: PhosphorIconsRegular.sun,
                    mode: ThemeMode.light,
                    key: const Key('theme_mode_light'),
                    isSelected: activeThemeMode == ThemeMode.light,
                  ),
                  _buildThemeOption(
                    context: context,
                    ref: ref,
                    label: 'Dark',
                    icon: PhosphorIconsRegular.moon,
                    mode: ThemeMode.dark,
                    key: const Key('theme_mode_dark'),
                    isSelected: activeThemeMode == ThemeMode.dark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Audio Fidelity Preference
            Text(
              'AUDIO ENGINE SPECIFICATIONS',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: AppRadius.cardBorder,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const PhosphorIcon(
                      AppIcons.waveform,
                      color: AppColors.brandPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '44.1 kHz Studio Sampling Rate',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Anti-glitch continuous phase accumulator active',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PhosphorIcon(
                    PhosphorIconsFill.checkCircle,
                    color: AppColors.success,
                    size: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required IconData icon,
    required ThemeMode mode,
    required Key key,
    required bool isSelected,
  }) {
    return Expanded(
      child: InkWell(
        key: key,
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(themeModeProvider.notifier).setThemeMode(mode);
        },
        borderRadius: AppRadius.pillBorder,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brandPrimary : Colors.transparent,
            borderRadius: AppRadius.pillBorder,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(
                icon,
                size: 16,
                color: isSelected
                    ? AppColors.brandContrast
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? AppColors.brandContrast
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

