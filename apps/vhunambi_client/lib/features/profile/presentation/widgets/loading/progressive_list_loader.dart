import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/theme/app_typography.dart';

/// Paginated list loader supporting dynamic item rendering and load-more footer.
class ProgressiveListLoader<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Future<void> Function() onLoadMore;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreError;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsetsGeometry padding;

  const ProgressiveListLoader({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onLoadMore,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreError,
    this.physics,
    this.shrinkWrap = false,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final footerCount = (hasMore || isLoadingMore || loadMoreError != null) ? 1 : 0;

    return ListView.builder(
      physics: physics,
      shrinkWrap: shrinkWrap,
      padding: padding,
      itemCount: items.length + footerCount,
      itemBuilder: (context, index) {
        if (index < items.length) {
          return itemBuilder(context, items[index], index);
        }

        return _buildFooter(context);
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Builder(
          builder: (context) {
            if (isLoadingMore) {
              return const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.brandPrimary,
                  ),
                ),
              );
            }

            if (loadMoreError != null) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    loadMoreError!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextButton.icon(
                    onPressed: onLoadMore,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brandPrimary,
                      minimumSize: const Size(88, 44),
                    ),
                  ),
                ],
              );
            }

            if (hasMore) {
              return ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 120),
                child: OutlinedButton(
                  onPressed: onLoadMore,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderSubtle),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                  child: const Text('Load More'),
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
