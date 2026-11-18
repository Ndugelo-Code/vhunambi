import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/safe_network_avatar.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import 'create_kinetic_post_sheet.dart';

/// Feed Composer Bar mounted at the top of the Explore feed (REQ-KPOST-COMP-01).
/// Provides a 1-tap gateway for creators to publish Kinetic Posts with photos,
/// Vhunambi Vision AI imagery, and attached musical snippets.
class KineticPostComposerBar extends ConsumerWidget {
  const KineticPostComposerBar({super.key});

  void _openComposer(BuildContext context, {int initialTab = 0}) {
    HapticFeedback.lightImpact();
    CreateKineticPostSheet.show(context, initialTab: initialTab);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(ownerProfileProvider);
    final fallbackLabel = owner.displayName.isNotEmpty
        ? owner.displayName
        : 'Cern';

    return Container(
      key: const Key('explore_create_kinetic_post_bar'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedOf(context),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtleOf(context)),
      ),
      child: Row(
        children: [
          SafeNetworkAvatar(
            key: const Key('kpost_composer_owner_avatar'),
            radius: 18,
            imageUrl: owner.avatarUrl,
            fallbackLabel: fallbackLabel,
            backgroundColor: AppColors.brandPrimary.withValues(alpha: 0.15),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Tap Target to Launch Full Authoring Workstation
          Expanded(
            child: InkWell(
              onTap: () => _openComposer(context),
              borderRadius: AppRadius.pillBorder,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondaryOf(context),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.borderSubtleOf(context)),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  'Drop a groove, voice take, or beat story...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),

          // Quick Action: Upload Photo
          IconButton(
            key: const Key('kpost_quick_photo_btn'),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const PhosphorIcon(
              PhosphorIconsRegular.image,
              size: 20,
              color: AppColors.brandPrimary,
            ),
            tooltip: 'Add Photo',
            onPressed: () => _openComposer(context, initialTab: 1),
          ),

          // Quick Action: Vhunambi Vision AI
          IconButton(
            key: const Key('kpost_quick_vision_btn'),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const PhosphorIcon(
              PhosphorIconsFill.sparkle,
              size: 20,
              color: AppColors.badgeCyan,
            ),
            tooltip: 'Vhunambi Vision AI',
            onPressed: () => _openComposer(context, initialTab: 2),
          ),
        ],
      ),
    );
  }
}
