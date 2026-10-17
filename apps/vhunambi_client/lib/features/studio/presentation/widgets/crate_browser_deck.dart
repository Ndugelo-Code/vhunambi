import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/heritage_crate_models.dart';
import '../providers/heritage_crate_provider.dart';

/// Indigenous Heritage Sound Archive browser with a spinning vinyl audition
/// graphic and 1-tap MPC chop hand-off (REQ-HRC-01 … REQ-HRC-03).
class CrateBrowserDeck extends ConsumerWidget {
  final void Function(HeritageSampleEntity sample)? onChop;
  const CrateBrowserDeck({super.key, this.onChop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(heritageCrateProvider);
    final samples = state.filteredSamples;

    return Container(
      color: AppColors.surfaceCanvas,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header + vinyl
          Row(
            children: [
              _VinylDiskWidget(
                  isSpinning: state.auditioningSampleId != null),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Heritage Crate Digging 💿',
                        style: AppTypography.titleLarge
                            .copyWith(fontWeight: FontWeight.bold)),
                    Text('Indigenous Sound Archive',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Search
          TextField(
            key: const Key('crate_search_field'),
            style: AppTypography.bodySmall,
            onChanged: (v) =>
                ref.read(heritageCrateProvider.notifier).setSearchQuery(v),
            decoration: InputDecoration(
              hintText: 'Search instruments, regions, tags…',
              hintStyle:
                  AppTypography.caption.copyWith(color: AppColors.textTertiary),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surfaceSecondary,
              isDense: true,
              border: const OutlineInputBorder(
                borderRadius: AppRadius.inputBorder,
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Category rail
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: HeritageCrateCategory.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, i) {
                final cat = HeritageCrateCategory.values[i];
                final isActive = cat == state.activeCategory;
                return _CategoryChip(
                  category: cat,
                  isActive: isActive,
                  onTap: () =>
                      ref.read(heritageCrateProvider.notifier).setCategory(cat),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Sample list
          Expanded(
            child: samples.isEmpty
                ? const Center(child: Text('No samples match your dig.'))
                : ListView.separated(
                    itemCount: samples.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, i) => _SampleTile(
                      sample: samples[i],
                      isAuditioning:
                          state.auditioningSampleId == samples[i].id,
                      onAudition: () {
                        final notifier =
                            ref.read(heritageCrateProvider.notifier);
                        if (state.auditioningSampleId == samples[i].id) {
                          notifier.stopAudition();
                        } else {
                          notifier.startAudition(samples[i].id);
                        }
                      },
                      onFavorite: () => ref
                          .read(heritageCrateProvider.notifier)
                          .toggleFavorite(samples[i].id),
                      onChop: () {
                        ref
                            .read(mpcSlicerProvider.notifier)
                            .sliceSample(samples[i]);
                        onChop?.call(samples[i]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}


class _VinylDiskWidget extends StatefulWidget {
  final bool isSpinning;
  const _VinylDiskWidget({required this.isSpinning});

  @override
  State<_VinylDiskWidget> createState() => _VinylDiskWidgetState();
}

class _VinylDiskWidgetState extends State<_VinylDiskWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.isSpinning) _controller.repeat();
  }

  @override
  void didUpdateWidget(_VinylDiskWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpinning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isSpinning && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * 3.14159,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceElevated,
              border: Border.all(color: AppColors.borderSubtle, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(90),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Grooved vinyl ring
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.borderSubtle.withAlpha(80),
                      width: 1.5,
                    ),
                  ),
                ),
                // Center disc label with authentic African Heritage crate cover
                ClipOval(
                  child: Image.asset(
                    AppAssets.heritageCrateCover,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.brandPrimary,
                      ),
                      child: const Icon(
                        Icons.music_note_rounded,
                        size: 14,
                        color: AppColors.brandContrast,
                      ),
                    ),
                  ),
                ),
                // Spindle hole
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceCanvas,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final HeritageCrateCategory category;
  final bool isActive;
  final VoidCallback onTap;
  const _CategoryChip(
      {required this.category, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('crate_cat_${category.name}'),
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.brandPrimary : AppColors.surfaceSecondary,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: isActive ? AppColors.brandPrimary : AppColors.borderSubtle,
          ),
        ),
        child: Text('${category.emoji} ${category.label}',
            style: AppTypography.caption.copyWith(
              color:
                  isActive ? AppColors.brandContrast : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            )),
      ),
    );
  }
}

class _SampleTile extends StatelessWidget {
  final HeritageSampleEntity sample;
  final bool isAuditioning;
  final VoidCallback onAudition;
  final VoidCallback onFavorite;
  final VoidCallback onChop;
  const _SampleTile({
    required this.sample,
    required this.isAuditioning,
    required this.onAudition,
    required this.onFavorite,
    required this.onChop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.inputBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppRadius.thumbBorder,
            child: Image.asset(
              AppAssets.heritageCrateCover,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.thumbBorder,
                ),
                child: const Icon(Icons.graphic_eq_rounded,
                    color: AppColors.brandPrimary, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sample.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold)),
                Text(sample.cultureRegion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _pill('${sample.bpm} BPM'),
                    const SizedBox(width: 6),
                    _pill(sample.rootKey),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('audition_${sample.id}'),
            iconSize: 20,
            onPressed: onAudition,
            icon: Icon(
              isAuditioning
                  ? Icons.pause_circle_rounded
                  : Icons.play_circle_rounded,
              color: AppColors.brandPrimary,
            ),
          ),
          IconButton(
            key: Key('fav_${sample.id}'),
            iconSize: 18,
            onPressed: onFavorite,
            icon: Icon(
              sample.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: sample.isFavorite
                  ? AppColors.brandPrimary
                  : AppColors.textTertiary,
            ),
          ),
          TextButton.icon(
            key: Key('chop_${sample.id}'),
            onPressed: onChop,
            icon: const Icon(Icons.content_cut_rounded,
                size: 16, color: AppColors.coinGold),
            label: Text('Chop',
                style: AppTypography.caption.copyWith(color: AppColors.coinGold)),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.pillBorder,
      ),
      child: Text(text,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
    );
  }
}
