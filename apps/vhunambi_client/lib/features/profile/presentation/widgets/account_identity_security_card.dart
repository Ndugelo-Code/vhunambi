import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/features/auth/presentation/widgets/sovereign_auth_sheet.dart';

/// Displays active Sovereign multi-tenant creator identity, JWT + AES-256
/// security badge, and quick account switch / sign-out controls (`Phase 61`).
class AccountIdentitySecurityCard extends ConsumerWidget {
  const AccountIdentitySecurityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final hasActiveAccount =
        session.isAuthenticated ||
        !session.isGuest ||
        session.canonicalCreatorId != 'creator_cern';

    final statusColor = session.isAuthenticated
        ? AppColors.success
        : (hasActiveAccount ? AppColors.badgeCyan : AppColors.textSecondaryOf(context));
    final statusIcon = session.isAuthenticated
        ? PhosphorIconsFill.shieldCheck
        : (hasActiveAccount
              ? PhosphorIconsFill.key
              : PhosphorIconsRegular.userCircle);
    final statusLabel = session.isAuthenticated
        ? 'JWT + AES-256 Active'
        : (hasActiveAccount
              ? 'Studio Identity Active'
              : 'Local Studio Guest');

    return Container(
      key: const Key('account_identity_security_card'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedOf(context),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtleOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withAlpha(28),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.brandPrimary.withAlpha(90),
                  ),
                ),
                child: Text(
                  session.monogram,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            session.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.textPrimaryOf(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          session.handle,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.brandPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tenant: ${session.canonicalCreatorId}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            key: const Key('account_security_status_pill'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(24),
              borderRadius: AppRadius.pillBorder,
              border: Border.all(color: statusColor.withAlpha(90)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(statusIcon, size: 13, color: statusColor),
                const SizedBox(width: 5),
                Text(
                  statusLabel,
                  style: AppTypography.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('account_switch_signin_btn'),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    SovereignAuthSheet.show(context);
                  },
                  icon: PhosphorIcon(
                    hasActiveAccount
                        ? PhosphorIconsRegular.userSwitch
                        : PhosphorIconsRegular.signIn,
                    size: 14,
                    color: AppColors.brandPrimary,
                  ),
                  label: Text(
                    hasActiveAccount ? 'Switch Account' : 'Sign In / Switch',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.brandPrimary.withAlpha(110),
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                ),
              ),
              if (hasActiveAccount) ...[
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('account_sign_out_btn'),
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      await ref.read(authSessionProvider.notifier).signOut();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Signed out and sanitized private local caches',
                          ),
                          backgroundColor: AppColors.brandPrimary,
                        ),
                      );
                    },
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.signOut,
                      size: 14,
                      color: AppColors.error,
                    ),
                    label: Text(
                      'Sign Out',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.error.withAlpha(110)),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.pillBorder,
                      ),
                      minimumSize: const Size(0, 36),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

