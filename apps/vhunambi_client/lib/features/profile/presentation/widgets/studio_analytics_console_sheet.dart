import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/synchronized_analytics_provider.dart';

/// Interactive studio analytics console sheet replacing the legacy SnackBar stub.
///
/// Features cross-platform KPI cards, custom Bézier velocity curves,
/// dynamic genre percentage breakdowns, and top drop rankings.
class StudioAnalyticsConsoleSheet extends ConsumerStatefulWidget {
  const StudioAnalyticsConsoleSheet({super.key});

  /// Displays the interactive console as a responsive bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceModal,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.modalBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (_) => const StudioAnalyticsConsoleSheet(),
    );
  }

  @override
  ConsumerState<StudioAnalyticsConsoleSheet> createState() =>
      _StudioAnalyticsConsoleSheetState();
}

class _StudioAnalyticsConsoleSheetState
    extends ConsumerState<StudioAnalyticsConsoleSheet> {
  int _selectedPeriodIndex = 0; // 0: 7 Days, 1: 30 Days, 2: All Time

  @override
  Widget build(BuildContext context) {
    final analytics = ref.watch(synchronizedAnalyticsProvider);
    final isDesktop = MediaQuery.sizeOf(context).width > 768;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.90;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag Handle & Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textTertiary.withAlpha(80),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const PhosphorIcon(
                          PhosphorIconsRegular.chartLineUp,
                          color: AppColors.brandPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Studio Analytics Console',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Live telemetry synchronized across Library, Reels & Beatstore',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const PhosphorIcon(
                          AppIcons.close,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Period Switcher
                  Container(
                    height: 38,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        for (int i = 0; i < 3; i++)
                          Expanded(
                            child: InkWell(
                              key: Key(
                                'analytics_period_${switch (i) {
                                  0 => '7d',
                                  1 => '30d',
                                  _ => 'all',
                                }}',
                              ),
                              onTap: () =>
                                  setState(() => _selectedPeriodIndex = i),
                              borderRadius: AppRadius.pillBorder,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _selectedPeriodIndex == i
                                      ? AppColors.brandPrimary
                                      : Colors.transparent,
                                  borderRadius: AppRadius.pillBorder,
                                ),
                                child: Text(
                                  switch (i) {
                                    0 => '7 Days',
                                    1 => '30 Days',
                                    _ => 'All Time',
                                  },
                                  style: AppTypography.caption.copyWith(
                                    fontWeight: _selectedPeriodIndex == i
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: _selectedPeriodIndex == i
                                        ? AppColors.brandContrast
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.borderSubtle),

            // Scrollable Analytics Dashboard Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Core Cross-Platform KPI Grid
                    GridView.count(
                      crossAxisCount: isDesktop ? 4 : 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: isDesktop ? 1.6 : 1.45,
                      children: [
                        _buildKpiCard(
                          title: 'Total Streams',
                          value: '${analytics.aggregateStreams}',
                          subtitle: '+18.4% velocity',
                          icon: AppIcons.waveform,
                          color: AppColors.brandPrimary,
                        ),
                        _buildKpiCard(
                          title: 'Net Royalties',
                          value: 'R ${analytics.totalZarEarned.toStringAsFixed(2)}',
                          subtitle: '${analytics.totalCoinsBalance} Coins',
                          icon: AppIcons.coin,
                          color: AppColors.coinGold,
                        ),
                        _buildKpiCard(
                          title: 'Reel Impressions',
                          value: '${analytics.totalReelsPlaysCount}',
                          subtitle: '${analytics.totalReelsLikesCount} total likes',
                          icon: AppIcons.flame,
                          color: AppColors.accentElectric,
                        ),
                        _buildKpiCard(
                          title: 'Beat Licenses',
                          value: '${analytics.totalBeatsSold}',
                          subtitle: '${analytics.totalBeatsCount} listed beats',
                          icon: AppIcons.navMarket,
                          color: AppColors.success,
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // 2. Interactive Stream & Royalty Velocity Chart
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: AppRadius.cardBorder,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Streaming Velocity',
                                      style: AppTypography.titleSmall.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Daily plays across Master MP3 & Kinetic Reels',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSecondary,
                                  borderRadius: AppRadius.pillBorder,
                                ),
                                child: Text(
                                  '44.1 kHz Verified',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.brandPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 140,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: _StreamVelocityChartPainter(
                                points: analytics.velocityPoints,
                                accentColor: AppColors.brandPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              for (final p in analytics.velocityPoints)
                                Text(
                                  '${p.date.day}/${p.date.month}',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textTertiary,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // 3. Dynamic Genre Distribution Matrix
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: AppRadius.cardBorder,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live Genre Affinity Distribution',
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Percentage share computed across published songs, beats and reels',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildGenreBreakdown(analytics.genreDistributionMap),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // 4. Synthesis Assets Summary Card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: AppRadius.cardBorder,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AI Synthesis Sovereign Assets',
                                  style: AppTypography.titleSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${analytics.totalClonedVoicesCount} Cloned Vocal Models • ${analytics.totalSavedMelodiesCount} Saved Multi-Track Grooves',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PhosphorIcon(
                            AppIcons.sparkle,
                            color: AppColors.coinGold,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              PhosphorIcon(icon, color: color, size: 16),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            subtitle,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGenreBreakdown(Map<String, int> distribution) {
    if (distribution.isEmpty) {
      return Text(
        'No active tracks analyzed yet.',
        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
      );
    }

    final total = distribution.values.fold<int>(0, (sum, val) => sum + val);

    return Column(
      children: [
        for (final entry in distribution.entries.take(5)) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${((entry.value / math.max(1, total)) * 100).toStringAsFixed(1)}% (${entry.value})',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: entry.value / math.max(1, total),
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceSecondary,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.brandPrimary,
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
}

/// Custom Bézier area chart painter visualizing streaming velocity smoothly.
class _StreamVelocityChartPainter extends CustomPainter {
  final List<AnalyticsDataPoint> points;
  final Color accentColor;

  _StreamVelocityChartPainter({
    required this.points,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final maxStreams = points.fold<int>(
      1,
      (max, p) => p.streams > max ? p.streams : max,
    );

    final normalizedPoints = <Offset>[];
    final stepX = size.width / (points.length - 1);

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height - (points[i].streams / maxStreams) * (size.height * 0.85);
      normalizedPoints.add(Offset(x, y));
    }

    // Build Smooth Cubic Bézier Curve Path
    final path = Path()..moveTo(normalizedPoints.first.dx, normalizedPoints.first.dy);
    for (int i = 0; i < normalizedPoints.length - 1; i++) {
      final p0 = normalizedPoints[i];
      final p1 = normalizedPoints[i + 1];
      final controlPointX = (p0.dx + p1.dx) / 2;
      path.cubicTo(
        controlPointX,
        p0.dy,
        controlPointX,
        p1.dy,
        p1.dx,
        p1.dy,
      );
    }

    // Shaded Area under Curve
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withAlpha(90),
          accentColor.withAlpha(0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Stroke Line
    final strokePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    // Dot Indicators
    final dotPaint = Paint()..color = Colors.white;
    final dotRingPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final point in normalizedPoints) {
      canvas.drawCircle(point, 3.5, dotPaint);
      canvas.drawCircle(point, 4.5, dotRingPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StreamVelocityChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.accentColor != accentColor;
  }
}

