import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/storage/hive_compaction_scheduler.dart';
import 'package:vhunambi_client/core/storage/sovereign_hive_bootstrap_service.dart';
import 'package:vhunambi_client/core/sync/edge_sync_coordinator.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';

/// Displays real-time health, AES-256 encryption verification, 26-box coverage,
/// fragmentation telemetry, and quick compaction / Edge-Sync controls for the
/// Sovereign Hive Brain (Phase 60 REQ-P60-HUD-01).
class HiveBrainTelemetryCard extends ConsumerStatefulWidget {
  const HiveBrainTelemetryCard({super.key});

  @override
  ConsumerState<HiveBrainTelemetryCard> createState() =>
      _HiveBrainTelemetryCardState();
}

class _HiveBrainTelemetryCardState
    extends ConsumerState<HiveBrainTelemetryCard> {
  bool _isCompacting = false;
  late HiveBrainTelemetrySnapshot _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = SovereignHiveBootstrapService.getTelemetrySnapshot();
  }

  void _refreshSnapshot() {
    if (!mounted) return;
    setState(() {
      _snapshot = SovereignHiveBootstrapService.getTelemetrySnapshot();
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _handleCompactNow() async {
    if (_isCompacting) return;
    HapticFeedback.lightImpact();
    setState(() => _isCompacting = true);
    final compactedCount = await HiveCompactionScheduler.compactAllBoxesNow(
      SovereignHiveBootstrapService.allBoxKeys,
    );
    if (!mounted) return;
    setState(() {
      _isCompacting = false;
      _snapshot = SovereignHiveBootstrapService.getTelemetrySnapshot();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          compactedCount > 0
              ? 'Compacted $compactedCount Sovereign Hive boxes'
              : 'Hive compaction check complete across all 26 boxes',
        ),
        backgroundColor: AppColors.brandPrimary,
      ),
    );
  }

  Future<void> _handleSyncNow() async {
    HapticFeedback.lightImpact();
    final ok = await ref.read(edgeSyncCoordinatorProvider.notifier).syncNow();
    _refreshSnapshot();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Sovereign Hive synchronized with Edge WAL'
              : 'Edge sync queued for next online connection',
        ),
        backgroundColor: ok
            ? AppColors.brandPrimary
            : AppColors.surfaceSecondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(edgeSyncCoordinatorProvider);
    final fragPercent =
        (_snapshot.fragmentationRatio * 100).clamp(0, 100).toStringAsFixed(1);

    return Container(
      key: const Key('hive_brain_status_card'),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const PhosphorIcon(
                  PhosphorIconsFill.database,
                  color: AppColors.brandPrimary,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sovereign Hive Brain',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Tier 0: ${_snapshot.tier0Count} | Tier 1: ${_snapshot.tier1Count} | Tier 2: ${_snapshot.tier2Count}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                key: const Key('hive_box_metrics_badge'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondaryOf(context),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.borderSubtleOf(context)),
                ),
                child: Text(
                  '${_snapshot.openBoxesCount} / ${_snapshot.totalDeclaredBoxes} Boxes',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: 6,
            children: [
              Container(
                key: const Key('hive_encryption_verified_pill'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(24),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.success.withAlpha(90)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PhosphorIcon(
                      PhosphorIconsFill.shieldCheck,
                      size: 13,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AES-256 Encrypted (${_snapshot.encryptedBoxesCount} Boxes)',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _buildMetricChip(
                context,
                icon: PhosphorIconsRegular.hardDrives,
                label:
                    '${_snapshot.totalPersistedRecords} records • ${_formatBytes(_snapshot.estimatedHiveBytes)}',
              ),
              _buildMetricChip(
                context,
                icon: PhosphorIconsRegular.gauge,
                label: 'Frag: $fragPercent% • Seq #${syncState.lastServerSeq}',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('hive_compact_now_btn'),
                  onPressed: _isCompacting ? null : _handleCompactNow,
                  icon: PhosphorIcon(
                    PhosphorIconsRegular.broom,
                    size: 14,
                    color: AppColors.brandPrimary,
                  ),
                  label: Text(
                    _isCompacting ? 'Compacting...' : 'Compact Now',
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
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('hive_sync_now_btn'),
                  onPressed: syncState.status == EdgeSyncStatus.syncing
                      ? null
                      : _handleSyncNow,
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.arrowsClockwise,
                    size: 14,
                    color: AppColors.badgeCyan,
                  ),
                  label: Text(
                    syncState.status == EdgeSyncStatus.syncing
                        ? 'Syncing...'
                        : 'Sync Brain',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(context),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.badgeCyan.withAlpha(110)),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondaryOf(context),
        borderRadius: AppRadius.pillBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(
            icon,
            size: 12,
            color: AppColors.textSecondaryOf(context),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondaryOf(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

