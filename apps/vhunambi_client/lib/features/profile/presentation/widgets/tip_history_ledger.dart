import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Master Switch
          Row(
            children: [
              const Icon(
                Icons.monetization_on_rounded,
                size: 20,
                color: AppColors.coinGold,
              ),
              const SizedBox(width: 10),
              Text(
                'Tip History',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    'Tips on',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Switch.adaptive(
                    value: widget.tipsEnabled,
                    activeTrackColor: AppColors.brandPrimary,
                    onChanged: widget.onToggleTips,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Sub-Tab Switcher
          Row(
            children: [
              _buildTabPill(
                title: 'Received',
                isSelected: _showReceived,
                onTap: () => setState(() => _showReceived = true),
              ),
              const SizedBox(width: 8),
              _buildTabPill(
                title: 'Sent',
                isSelected: !_showReceived,
                onTap: () => setState(() => _showReceived = false),
              ),
              const Spacer(),
              Text(
                'Total: ⚡ $totalCredits',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.coinGold,
                ),
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
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredTips.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: AppColors.borderSubtle, height: 16),
              itemBuilder: (context, index) {
                final tip = filteredTips[index];
                return Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.coinGold.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('🪙', style: TextStyle(fontSize: 14)),
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
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'on "${tip.trackTitle}" • ${_formatTimeAgo(tip.timestamp)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '+⚡ ${tip.amountCredits}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.coinGold,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTabPill({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3A2508)
              : AppColors.surfaceSecondary,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : AppColors.borderSubtle,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.coinGold : AppColors.textSecondary,
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
