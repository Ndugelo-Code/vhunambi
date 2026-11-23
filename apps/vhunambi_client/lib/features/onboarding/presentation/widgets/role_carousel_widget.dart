import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../../creator_dna/domain/entities/creator_dna_profile.dart';

/// Role option displayed in the [RoleCarouselWidget].
@immutable
class RoleOption {
  final CreativeRole role;
  final String label;

  /// Legacy optional field preserved so historical widget tests compile;
  /// production UI renders [resolvedIcon] via [PhosphorIcon] (`STD-UIUX-001`).
  final String emoji;
  final IconData? icon;
  final String description;

  const RoleOption({
    required this.role,
    required this.label,
    this.emoji = '',
    this.icon,
    required this.description,
  });

  IconData get resolvedIcon => icon ?? _defaultIconForRole(role);

  static IconData _defaultIconForRole(CreativeRole role) {
    return switch (role) {
      CreativeRole.producer => AppIcons.beatstore,
      CreativeRole.vocalist => AppIcons.vocals,
      CreativeRole.songwriter => AppIcons.edit,
      CreativeRole.multiHyphenate => AppIcons.sparkle,
      CreativeRole.musicLover => PhosphorIconsFill.headphones,
    };
  }
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
                  label:
                      '${role.label} creative role${isSelected ? ', selected' : ''}',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onRoleTap(role),
                      borderRadius: AppRadius.cardBorder,
                      child: VhunambiGlassSurface(
                        variant: VhunambiGlassVariant.card,
                        constraints: const BoxConstraints(minHeight: 100),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        borderRadius: AppRadius.cardBorder,
                        enableLiveBlur: false,
                        tintAccent: isSelected ? AppColors.brandPrimary : null,
                        borderColorOverride: isSelected || isCenter
                            ? AppColors.brandPrimary
                            : AppColors.borderSubtleOf(context),
                        borderWidth: isSelected || isCenter ? 2.0 : 1.0,
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected || isCenter
                                    ? AppColors.brandPrimary.withValues(
                                        alpha: 0.16,
                                      )
                                    : AppColors.surfaceSecondaryOf(context),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: PhosphorIcon(
                                  role.resolvedIcon,
                                  size: 20,
                                  color: isSelected || isCenter
                                      ? AppColors.brandPrimary
                                      : AppColors.textPrimaryOf(context),
                                ),
                              ),
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
                                          : AppColors.textPrimaryOf(context),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    role.description,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondaryOf(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const PhosphorIcon(
                                AppIcons.checkCircle,
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
