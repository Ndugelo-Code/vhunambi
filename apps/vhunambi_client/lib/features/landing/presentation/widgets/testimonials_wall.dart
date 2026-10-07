import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../domain/models/landing_models.dart';
import '../providers/landing_providers.dart';

/// Verified creator testimonials wall (REQ-MKT-10).
class TestimonialsWall extends ConsumerWidget {
  static const String title = 'Loved by African creators';

  const TestimonialsWall({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testimonials = ref.watch(creatorTestimonialsProvider);
    final isMobile = ResponsiveUtils.isMobile(context);
    final columns = isMobile ? 1 : 2;

    final rows = <List<CreatorTestimonial>>[];
    for (var index = 0; index < testimonials.length; index += columns) {
      final end = index + columns > testimonials.length
          ? testimonials.length
          : index + columns;
      rows.add(testimonials.sublist(index, end));
    }

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
          for (final row in rows) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < row.length; index++) ...[
                  Expanded(child: _TestimonialCard(testimonial: row[index])),
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

class _TestimonialCard extends StatelessWidget {
  final CreatorTestimonial testimonial;

  const _TestimonialCard({required this.testimonial});

  @override
  Widget build(BuildContext context) {
    final stars = List.filled(testimonial.rating, '⭐').join();

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
          Text(
            stars,
            style: AppTypography.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '"${testimonial.quote}"',
            style: AppTypography.bodySmall.copyWith(height: 1.5),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.brandPrimaryDark,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  testimonial.initials,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      testimonial.authorName,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${testimonial.handle} • ${testimonial.location}',
                      style: AppTypography.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
