import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../creator_dna/domain/entities/creator_dna_profile.dart';

/// Role option displayed in the [RoleCarouselWidget].
@immutable
class RoleOption {
  final CreativeRole role;
  final String label;
  final String emoji;
  final String description;

  const RoleOption({
    required this.role,
    required this.label,
    required this.emoji,
    required this.description,
  });
}

/// Horizontal card carousel for selecting a creative role during onboarding.
class RoleCarouselWidget extends ConsumerStatefulWidget {
  final List<RoleOption> roles;
  final CreativeRole selectedRole;
  final ValueChanged<CreativeRole> onRoleSelected;

  const RoleCarouselWidget({
    super.key,
    required this.roles,
    required this.selectedRole,
    required this.onRoleSelected,
  });

  @override
  ConsumerState<RoleCarouselWidget> createState() => _RoleCarouselWidgetState();
}

class _RoleCarouselWidgetState extends ConsumerState<RoleCarouselWidget> {
  late final PageController _pageController;
  int _centerIndex = 0;

  @override
  void initState() {
    super.initState();
    _centerIndex = widget.roles.indexWhere(
      (r) => r.role == widget.selectedRole,
    );
    if (_centerIndex < 0) _centerIndex = 0;
    _pageController = PageController(
      initialPage: _centerIndex,
      viewportFraction: 0.72,
    );
  }

  @override
  void didUpdateWidget(covariant RoleCarouselWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedRole != oldWidget.selectedRole) {
      final newIndex = widget.roles.indexWhere(
        (r) => r.role == widget.selectedRole,
      );
      if (newIndex >= 0 && newIndex != _centerIndex) {
        _centerIndex = newIndex;
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            newIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onRoleTap(RoleOption role) {
    if (role.role == widget.selectedRole) return;
    HapticsService().lightImpact();
    widget.onRoleSelected(role.role);
  }

  void _onPageChanged(int index) {
    setState(() => _centerIndex = index);
    if (!AccessibilityService.isReduceMotionEnabled(context)) {
      HapticsService().selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AccessibilityService.isReduceMotionEnabled(context);

    return SizedBox(
      height: 120,
      child: PageView.builder(
        key: const Key('role_carousel'),
        controller: _pageController,
        itemCount: widget.roles.length,
        onPageChanged: _onPageChanged,
        physics: const PageScrollPhysics(),
        itemBuilder: (context, index) {
          final role = widget.roles[index];
          final isSelected = role.role == widget.selectedRole;
          final isCenter = index == _centerIndex;

          final double scale = isCenter ? 1.0 : 0.88;
          final double opacity = isCenter ? 1.0 : 0.6;

          return Padding(
            key: Key('onboarding_role_card_${role.role.name}'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: AnimatedScale(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              scale: scale,
              child: AnimatedOpacity(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
                opacity: opacity,
                child: Semantics(
                  button: true,
                  selected: isSelected,
                  label: '${role.label} creative role${isSelected ? ', selected' : ''}',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onRoleTap(role),
                      borderRadius: AppRadius.cardBorder,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 100),
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
                            color: isSelected || isCenter
                                ? AppColors.brandPrimary
                                : AppColors.borderSubtle,
                            width: isSelected || isCenter ? 2.0 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              role.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    role.label,
                                    style: AppTypography.titleMedium.copyWith(
                                      color: isSelected || isCenter
                                          ? AppColors.brandPrimary
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    role.description,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: AppColors.brandPrimary,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
