import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';

/// Selectable card representing a creative role archetype during onboarding and identity setup.
class CreativeRoleCard extends StatelessWidget {
  final String roleKey;
  final String label;
  final String emoji;
  final String? description;
  final bool isSelected;
  final VoidCallback onTap;

  const CreativeRoleCard({
    super.key,
    required this.roleKey,
    required this.label,
    required this.emoji,
    this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label creative role${isSelected ? ", selected" : ""}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('onboarding_role_card_$roleKey'),
          onTap: onTap,
          borderRadius: AppRadius.cardBorder,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56, minWidth: double.infinity),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.brandPrimary.withValues(alpha: 0.15)
                  : AppColors.surfaceElevated,
              borderRadius: AppRadius.cardBorder,
              border: Border.all(
                color: isSelected ? AppColors.brandPrimary : AppColors.borderSubtle,
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: AppTypography.titleMedium.copyWith(
                          color: isSelected ? AppColors.brandPrimary : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          description!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.brandPrimary : AppColors.textTertiary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
