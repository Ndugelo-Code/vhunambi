import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../domain/models/landing_models.dart';
import '../providers/landing_providers.dart';

/// Six core value pillar cards in a 3x2 responsive grid (REQ-MKT-09).
class ValuePillarsGrid extends ConsumerWidget {
  static const String title = 'Why creators choose Vhunambi';

  const ValuePillarsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pillars = ref.watch(valuePillarsProvider);
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTablet = ResponsiveUtils.isTablet(context);
    final columns = isMobile ? 1 : (isTablet ? 2 : 3);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTypography.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          for (final row in _chunkPillars(pillars, columns)) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < row.length; index++) ...[
                  Expanded(child: _PillarCard(pillar: row[index])),
                  if (index != row.length - 1)
                    const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

List<List<ValuePillar>> _chunkPillars(List<ValuePillar> pillars, int size) {
  final chunks = <List<ValuePillar>>[];
  for (var index = 0; index < pillars.length; index += size) {
    final end = index + size > pillars.length ? pillars.length : index + size;
    chunks.add(pillars.sublist(index, end));
  }
  return chunks;
}

class _PillarCard extends StatelessWidget {
  final ValuePillar pillar;

  const _PillarCard({required this.pillar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withAlpha(38),
              borderRadius: AppRadius.squircleBorder,
            ),
            child: Icon(pillar.iconData, size: 18, color: AppColors.brandPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            pillar.title,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            pillar.description,
            style: AppTypography.bodySmall.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}
