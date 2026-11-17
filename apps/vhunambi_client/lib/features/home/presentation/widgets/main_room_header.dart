import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/services/haptics_service.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/theme/theme_provider.dart';
import 'package:vhunambi_client/features/home/presentation/providers/creator_allowance_provider.dart';
import 'package:vhunambi_client/features/home/presentation/utils/african_greeting_resolver.dart';
import 'package:vhunambi_client/features/home/presentation/widgets/subscription_upgrade_modal.dart';
import 'package:vhunambi_client/features/notifications/presentation/views/notifications_view.dart';
import 'package:vhunambi_client/features/notifications/presentation/widgets/notification_bell_button.dart';
import 'package:vhunambi_client/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:vhunambi_client/features/profile/presentation/providers/profile_providers.dart';
import 'package:vhunambi_client/features/profile/presentation/views/owner_profile_view.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/avatar_customization_modal.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/creator_avatar.dart';
import 'package:vhunambi_client/features/social/presentation/providers/creator_wallet_provider.dart';

/// Zone 1: Compact "Main Room" top utility bar (`REQ-P68-FEED-01`, `REQ-P68-QUOTA-03`).
///
/// Uses a two-tier layout on mobile (`!isDesktop`) so greeting + utility actions
/// stay clean on row 1 and status pills stay overflow-free on row 2 across narrow
/// `360dp` screens, while desktop renders all items in a single airy row.
class MainRoomHeader extends ConsumerWidget {
  final bool isDesktop;

  const MainRoomHeader({
    super.key,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerProfile = ref.watch(ownerProfileProvider);
    final wallet = ref.watch(creatorWalletProvider);
    final allowance = ref.watch(creatorAllowanceProvider);
    final onboarding = ref.watch(onboardingStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userLanguage = onboarding.selectedLanguages.isNotEmpty
        ? onboarding.selectedLanguages.first
        : 'Tshivenḓa';
    final greetingText = AfricanGreetingResolver.getGreeting(
      language: userLanguage,
    );
    final greetingIcon = AfricanGreetingResolver.resolvePhosphorIcon();

    final quotaColor = allowance.isLowQuota
        ? AppColors.coinGold
        : allowance.isPaidUnlimited
            ? AppColors.accentElectric
            : AppColors.success;

    void openUpgradeModal() {
      FocusManager.instance.primaryFocus?.unfocus();
      HapticsService().lightImpact();
      SubscriptionUpgradeModal.show(context);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 32 : 16,
        12,
        isDesktop ? 32 : 16,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              CreatorAvatar(
                avatarKey: const Key('home_avatar_btn'),
                avatarUrl: ownerProfile.avatarUrl,
                monogram: ownerProfile.monogram.isNotEmpty
                    ? ownerProfile.monogram
                    : 'ND',
                size: 42,
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  HapticsService().lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OwnerProfileView(),
                    ),
                  );
                },
                onLongPress: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  AvatarCustomizationModal.show(context);
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            greetingText,
                            key: const Key('home_greeting_text'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.textPrimaryOf(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        PhosphorIcon(
                          greetingIcon,
                          size: 14,
                          color: AppColors.coinGold,
                        ),
                      ],
                    ),
                    Text(
                      ownerProfile.displayName.isNotEmpty
                          ? ownerProfile.displayName
                          : 'Creator',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (isDesktop) ...<Widget>[
                _HeaderMetricPill(
                  pillKey: const Key('home_streak_pill'),
                  icon: PhosphorIconsFill.flame,
                  iconColor: AppColors.brandPrimary,
                  label: '${ownerProfile.dayStreak} Streak',
                  semanticLabel: '${ownerProfile.dayStreak} Streak',
                  bgColor: AppColors.brandPrimary.withValues(alpha: 0.14),
                  borderColor: AppColors.brandPrimary.withValues(alpha: 0.35),
                  onTap: null,
                ),
                const SizedBox(width: 8),
                _HeaderMetricPill(
                  pillKey: const Key('home_allowance_pill'),
                  icon: PhosphorIconsFill.musicNoteSimple,
                  iconColor: quotaColor,
                  label: allowance.isPaidUnlimited
                      ? 'Pro Unlimited'
                      : '${allowance.pillLabel} Free',
                  semanticLabel:
                      'Monthly free allowance ${allowance.pillLabel}',
                  bgColor: quotaColor.withValues(alpha: 0.14),
                  borderColor: quotaColor.withValues(alpha: 0.38),
                  onTap: openUpgradeModal,
                ),
                const SizedBox(width: 8),
                _HeaderMetricPill(
                  pillKey: const Key('home_coins_pill'),
                  icon: PhosphorIconsFill.coins,
                  iconColor: AppColors.coinGold,
                  label: '${wallet.userCoinsBalance} Coins',
                  semanticLabel: '${wallet.userCoinsBalance} Coins',
                  bgColor: AppColors.coinGold.withValues(alpha: 0.14),
                  borderColor: AppColors.coinGold.withValues(alpha: 0.35),
                  onTap: openUpgradeModal,
                ),
                const SizedBox(width: 8),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: IconButton(
                  key: const Key('home_theme_toggle_btn'),
                  tooltip:
                      isDark ? 'Switch to Morning Mist' : 'Switch to Night Mode',
                  padding: EdgeInsets.zero,
                  icon: PhosphorIcon(
                    isDark ? PhosphorIconsFill.sun : PhosphorIconsFill.moonStars,
                    size: 19,
                    color: isDark ? AppColors.coinGold : AppColors.brandPrimary,
                  ),
                  onPressed: () {
                    HapticsService().selectionClick();
                    ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
                  },
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Center(
                  child: NotificationBellButton(
                    key: const Key('home_notifications_btn'),
                    color: AppColors.textPrimaryOf(context),
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const NotificationsView(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          if (!isDesktop) ...<Widget>[
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _HeaderMetricPill(
                    pillKey: const Key('home_streak_pill'),
                    icon: PhosphorIconsFill.flame,
                    iconColor: AppColors.brandPrimary,
                    label: '${ownerProfile.dayStreak} Streak',
                    semanticLabel: '${ownerProfile.dayStreak} Streak',
                    bgColor: AppColors.brandPrimary.withValues(alpha: 0.14),
                    borderColor: AppColors.brandPrimary.withValues(alpha: 0.35),
                    onTap: null,
                  ),
                  const SizedBox(width: 8),
                  _HeaderMetricPill(
                    pillKey: const Key('home_allowance_pill'),
                    icon: PhosphorIconsFill.musicNoteSimple,
                    iconColor: quotaColor,
                    label: allowance.isPaidUnlimited
                        ? 'Pro Unlimited'
                        : '${allowance.pillLabel} Free',
                    semanticLabel:
                        'Monthly free allowance ${allowance.pillLabel}',
                    bgColor: quotaColor.withValues(alpha: 0.14),
                    borderColor: quotaColor.withValues(alpha: 0.38),
                    onTap: openUpgradeModal,
                  ),
                  const SizedBox(width: 8),
                  _HeaderMetricPill(
                    pillKey: const Key('home_coins_pill'),
                    icon: PhosphorIconsFill.coins,
                    iconColor: AppColors.coinGold,
                    label: '${wallet.userCoinsBalance} Coins',
                    semanticLabel: '${wallet.userCoinsBalance} Coins',
                    bgColor: AppColors.coinGold.withValues(alpha: 0.14),
                    borderColor: AppColors.coinGold.withValues(alpha: 0.35),
                    onTap: openUpgradeModal,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderMetricPill extends StatelessWidget {
  final Key pillKey;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String semanticLabel;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback? onTap;

  const _HeaderMetricPill({
    required this.pillKey,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.semanticLabel,
    required this.bgColor,
    required this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pillBody = Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PhosphorIcon(icon, size: 13, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: GestureDetector(
        key: pillKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(child: pillBody),
        ),
      ),
    );
  }
}
