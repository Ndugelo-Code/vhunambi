import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/notification_entity.dart';
import '../utils/notification_category_style.dart';
import '../utils/notification_deep_link_router.dart';
import '../utils/time_ago_utils.dart';

/// Universal notification inspection modal (`REQ-P67-ROUTE-01`).
///
/// Guarantees zero dead taps across System, Creator DNA, Quota, Wallet,
/// Studio, and Social notifications while presenting rich metadata breakdowns
/// and an explicit primary CTA to launch the target workspace.
class NotificationDetailBottomSheet extends ConsumerWidget {
  const NotificationDetailBottomSheet({super.key, required this.notification});

  final NotificationEntity notification;

  static Future<void> show(
    BuildContext context,
    NotificationEntity notification,
  ) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NotificationDetailBottomSheet(notification: notification),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = NotificationCategoryStyle.entityColor(notification);
    final pill = NotificationCategoryStyle.pillLabel(notification);
    final ctaLabel =
        notification.ctaLabel ?? _defaultCtaLabel(notification.effectiveRoute);

    return Container(
      key: const Key('notification_detail_bottom_sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceModalOf(context),
        borderRadius: AppRadius.modalBorder,
        border: Border.all(color: accent.withValues(alpha: 0.30), width: 1),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtleOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.30)),
                    ),
                    child: Center(
                      child: PhosphorIcon(
                        NotificationCategoryStyle.entityIcon(notification),
                        color: accent,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    key: const Key('detail_sheet_category_pill'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(color: accent.withValues(alpha: 0.32)),
                    ),
                    child: Text(
                      pill,
                      style: AppTypography.badge.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    TimeAgoUtils.format(notification.createdAt),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                notification.title,
                key: const Key('detail_sheet_title'),
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.textPrimaryOf(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                notification.message,
                key: const Key('detail_sheet_message'),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondaryOf(context),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _MetadataBreakdownCard(
                notification: notification,
                accent: accent,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (notification.effectiveRoute != null) ...<Widget>[
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const Key('detail_sheet_primary_cta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: AppColors.brandContrast,
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.inputBorder,
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      NotificationDeepLinkRouter.navigateDirect(
                        context,
                        ref,
                        notification,
                      );
                    },
                    icon: const PhosphorIcon(
                      AppIcons.arrowRight,
                      size: 18,
                      color: AppColors.brandContrast,
                    ),
                    label: Text(
                      ctaLabel,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.brandContrast,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              SizedBox(
                height: 44,
                child: TextButton(
                  key: const Key('detail_sheet_close_btn'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _defaultCtaLabel(String? route) {
    if (route == null) return 'Done';
    if (route.startsWith('/studio')) return 'Open Studio Cockpit';
    if (route.startsWith('/creator-dna')) return 'Calibrate Creator DNA';
    if (route.startsWith('/wallet')) return 'View Balance & Usage';
    if (route.startsWith('/track/')) return 'Open Track Cockpit';
    if (route.startsWith('/reel/')) return 'Watch Kinetic Reel';
    if (route.startsWith('/creator/')) return 'View Creator Profile';
    return 'Continue';
  }
}

class _MetadataBreakdownCard extends StatelessWidget {
  const _MetadataBreakdownCard({
    required this.notification,
    required this.accent,
  });

  final NotificationEntity notification;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final sub = notification.subtype?.trim().toLowerCase() ?? '';
    final meta = notification.metadata;

    return Container(
      key: const Key('detail_sheet_breakdown_card'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondaryOf(context),
        borderRadius: AppRadius.inputBorder,
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: switch (sub) {
        'dna_calibration' ||
        'dna_milestone' => _buildDnaBreakdown(context, meta),
        'monthly_quota' => _buildQuotaBreakdown(context, meta),
        _ => _buildGenericBreakdown(context, meta),
      },
    );
  }

  Widget _buildDnaBreakdown(BuildContext context, Map<String, dynamic> meta) {
    final pct = (meta['dnaPercent'] as num?)?.toInt() ?? 8;
    final recorded = ((meta['recordedTraits'] as List?) ?? const <dynamic>[])
        .map((e) => e.toString())
        .toList();
    final uncalibrated =
        ((meta['uncalibratedTraits'] as List?) ?? const <dynamic>[])
            .map((e) => e.toString())
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'DNA CALIBRATION STRENGTH',
              style: AppTypography.badge.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '$pct / 100%',
              style: AppTypography.caption.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: (pct / 100.0).clamp(0.0, 1.0),
          minHeight: 6,
          backgroundColor: AppColors.borderSubtleOf(context),
          color: accent,
          borderRadius: BorderRadius.circular(3),
        ),
        if (recorded.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            'Recorded Traits:',
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final item in recorded)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: <Widget>[
                  PhosphorIcon(AppIcons.checkCircle, size: 13, color: accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (uncalibrated.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Pending Calibration (+90% Unlock):',
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final item in uncalibrated)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: <Widget>[
                  PhosphorIcon(
                    PhosphorIconsRegular.circleDashed,
                    size: 13,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildQuotaBreakdown(BuildContext context, Map<String, dynamic> meta) {
    final total = (meta['freeSongsTotal'] as num?)?.toInt() ?? 10;
    final remaining = (meta['freeSongsRemaining'] as num?)?.toInt() ?? 10;
    final rawPlan = (meta['planTier'] as String?)?.trim() ?? 'free';
    final plan = rawPlan.toLowerCase() == 'free' ? 'Free Creator' : rawPlan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'MONTHLY SONG ALLOWANCE ($plan)',
              style: AppTypography.badge.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '$remaining / $total Songs Left',
              style: AppTypography.caption.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: total > 0 ? (remaining / total).clamp(0.0, 1.0) : 0.0,
          minHeight: 6,
          backgroundColor: AppColors.borderSubtleOf(context),
          color: accent,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 8),
        Text(
          '1 Full AI Song + 4-Stem Demucs Separation = 1 Monthly Credit\n'
          'Allowance resets automatically every 30-day billing cycle\n'
          'Cultural Coins can be topped up anytime for tipping & beat licenses',
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondaryOf(context),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildGenericBreakdown(
    BuildContext context,
    Map<String, dynamic> meta,
  ) {
    final route = notification.effectiveRoute ?? 'In-App Alert';
    return Row(
      children: <Widget>[
        PhosphorIcon(AppIcons.sparkle, size: 16, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Category: ${NotificationCategoryStyle.pillLabel(notification)}  •  Destination: $route',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ),
      ],
    );
  }
}
