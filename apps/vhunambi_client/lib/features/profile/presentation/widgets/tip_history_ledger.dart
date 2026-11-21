import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../domain/models/profile_models.dart';

/// Financial Tipping Ledger with Received/Sent Sub-Tabs & Master Toggle (REQ-TRK-16).
class TipHistoryLedger extends StatefulWidget {
  final List<TipRecordEntity> tipHistory;
  final bool tipsEnabled;
  final ValueChanged<bool>? onToggleTips;

  const TipHistoryLedger({
    super.key,
    required this.tipHistory,
    this.tipsEnabled = true,
    this.onToggleTips,
  });

  @override
  State<TipHistoryLedger> createState() => _TipHistoryLedgerState();
}

class _TipHistoryLedgerState extends State<TipHistoryLedger> {
  bool _showReceived = true;

  @override
  Widget build(BuildContext context) {
    final filteredTips = widget.tipHistory
        .where((t) => t.isReceived == _showReceived)
        .toList();
    final totalCredits = filteredTips.fold<int>(
      0,
      (sum, t) => sum + t.amountCredits,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: VhunambiGlassSurface(
        variant: VhunambiGlassVariant.card,
        enableLiveBlur: false,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row with Master Switch
            Row(
              children: [
                const PhosphorIcon(
                  PhosphorIconsFill.coins,
                  size: 20,
                  color: AppColors.coinGold,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Tip History',
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimaryOf(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tips on',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch.adaptive(
                        value: widget.tipsEnabled,
                        activeTrackColor: AppColors.brandPrimary,
                        onChanged: widget.onToggleTips,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Sub-Tab Switcher
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTabPill(
                      context: context,
                      title: 'Received',
                      isSelected: _showReceived,
                      onTap: () => setState(() => _showReceived = true),
                    ),
                    const SizedBox(width: 8),
                    _buildTabPill(
                      context: context,
                      title: 'Sent',
                      isSelected: !_showReceived,
                      onTap: () => setState(() => _showReceived = false),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                    const PhosphorIcon(
                      PhosphorIconsFill.lightning,
                      size: 13,
                      color: AppColors.coinGold,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$totalCredits',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.coinGold,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Ledger Content
            if (filteredTips.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    _showReceived
                        ? "You haven't received any tips yet."
                        : "You haven't sent any tips yet.",
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredTips.length,
                separatorBuilder: (context, index) => Divider(
                  color: AppColors.borderSubtleOf(context),
                  height: 16,
                ),
                itemBuilder: (context, index) {
                  final tip = filteredTips[index];
                  return Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.coinGold.withAlpha(24),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: PhosphorIcon(
                            PhosphorIconsFill.coins,
                            size: 16,
                            color: AppColors.coinGold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _showReceived
                                  ? '${tip.senderName} (${tip.senderHandle})'
                                  : 'Tipped to ${tip.recipientName}',
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                            Text(
                              'on "${tip.trackTitle}" • ${_formatTimeAgo(tip.timestamp)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const PhosphorIcon(
                            PhosphorIconsFill.lightning,
                            size: 13,
                            color: AppColors.coinGold,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '+${tip.amountCredits}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.coinGold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPill({
    required BuildContext context,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Center(
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.pillBorder,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.brandPrimary.withAlpha(30)
                  : AppColors.surfaceSecondaryOf(context),
              borderRadius: AppRadius.pillBorder,
              border: Border.all(
                color: isSelected
                    ? AppColors.brandPrimary
                    : AppColors.borderSubtleOf(context),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? AppColors.brandPrimary
                    : AppColors.textSecondaryOf(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
