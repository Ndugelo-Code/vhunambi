import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/marketplace_models.dart';
import '../providers/marketplace_providers.dart';

/// BPM slider bounds (Blueprint 05 §2.2.6).
const double marketplaceMinBpm = 70;
const double marketplaceMaxBpm = 160;

/// Credit price slider bounds.
const double marketplaceMaxPriceCap = 20;

/// Marketplace filter sheet: genre chips, BPM range and credit price cap
/// (REQ-MKT-05).
Future<void> showMarketplaceFilterModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceModal,
    barrierColor: Colors.black54,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.modalBorder,
      side: BorderSide(color: AppColors.borderSubtle),
    ),
    builder: (_) => const _MarketplaceFilterSheet(),
  );
}

class _MarketplaceFilterSheet extends ConsumerStatefulWidget {
  const _MarketplaceFilterSheet();

  @override
  ConsumerState<_MarketplaceFilterSheet> createState() =>
      _MarketplaceFilterSheetState();
}

class _MarketplaceFilterSheetState
    extends ConsumerState<_MarketplaceFilterSheet> {
  late RangeValues _bpmRange;
  late double _priceCap;

  @override
  void initState() {
    super.initState();
    final filter = ref.read(marketplaceFilterProvider);
    _bpmRange = RangeValues(
      (filter.minBpm ?? marketplaceMinBpm).toDouble(),
      (filter.maxBpm ?? marketplaceMaxBpm).toDouble(),
    );
    _priceCap = (filter.maxPriceCredits ?? marketplaceMaxPriceCap).toDouble();
  }

  void _write(MarketplaceFilterState next) {
    ref.read(marketplaceFilterProvider.notifier).state = next;
  }

  void _applyBpmRange(RangeValues values) {
    setState(() => _bpmRange = values);
    final current = ref.read(marketplaceFilterProvider);
    final isFullRange =
        values.start <= marketplaceMinBpm && values.end >= marketplaceMaxBpm;

    _write(
      isFullRange
          ? current.copyWith(clearBpmRange: true)
          : current.copyWith(
              minBpm: values.start.round(),
              maxBpm: values.end.round(),
            ),
    );
  }

  void _applyPriceCap(double value) {
    setState(() => _priceCap = value);
    final current = ref.read(marketplaceFilterProvider);

    _write(
      value >= marketplaceMaxPriceCap
          ? current.copyWith(clearMaxPrice: true)
          : current.copyWith(maxPriceCredits: value.round()),
    );
  }

  void _clearAll() {
    setState(() {
      _bpmRange = const RangeValues(marketplaceMinBpm, marketplaceMaxBpm);
      _priceCap = marketplaceMaxPriceCap;
    });
    clearMarketplaceFilters(ref);
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(marketplaceFilterProvider);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderActive,
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Filter beats',
                      style: AppTypography.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: _clearAll,
                    borderRadius: AppRadius.pillBorder,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: AppColors.brandPrimary,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          'Clear all',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.brandPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Genre',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final genre in [
                    MarketplaceFilterState.allGenres,
                    ...marketplaceGenreCatalog,
                  ])
                    _MarketplaceFilterChip(
                      label: genre,
                      isActive: genre == filter.genre,
                      onTap: () => _write(
                        ref
                            .read(marketplaceFilterProvider)
                            .copyWith(genre: genre),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'BPM range: ${_bpmRange.start.round()} – ${_bpmRange.end.round()}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              RangeSlider(
                values: _bpmRange,
                min: marketplaceMinBpm,
                max: marketplaceMaxBpm,
                divisions: (marketplaceMaxBpm - marketplaceMinBpm).round(),
                activeColor: AppColors.brandPrimary,
                inactiveColor: AppColors.surfaceSecondary,
                labels: RangeLabels(
                  '${_bpmRange.start.round()} BPM',
                  '${_bpmRange.end.round()} BPM',
                ),
                onChanged: _applyBpmRange,
              ),
              Text(
                'Max price: ${_priceCap.round()} credits',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Slider(
                value: _priceCap,
                min: 1,
                max: marketplaceMaxPriceCap,
                divisions: (marketplaceMaxPriceCap - 1).round(),
                activeColor: AppColors.brandPrimary,
                inactiveColor: AppColors.surfaceSecondary,
                label: '${_priceCap.round()} credits',
                onChanged: _applyPriceCap,
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.brandContrast,
                      fontWeight: FontWeight.bold,
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
}

/// Genre chip used by the marketplace filter sheet.
class _MarketplaceFilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _MarketplaceFilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.brandPrimary : AppColors.surfaceSecondary,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: isActive ? AppColors.brandPrimary : AppColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            fontSize: 12,
            color: isActive ? AppColors.brandContrast : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
