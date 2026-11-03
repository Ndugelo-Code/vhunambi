import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/widgets/vhunambi_top_bar_kit.dart';
import '../../../../core/widgets/vhunambi_bottom_dock_kit.dart';
import '../providers/marketplace_providers.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../widgets/beat_card.dart';
import '../widgets/beat_license_modal.dart';
import '../widgets/marketplace_empty_state.dart';
import '../widgets/marketplace_filter_modal.dart';
import '../widgets/marketplace_top_bar.dart';
import '../widgets/seller_callout_banner.dart';

/// Beats Marketplace (`/market`) — mounted at tab index 4 of `RootShell`.
/// Reference: `docs/phases/phase_06_marketplace/blueprint.md` §2
class MarketplaceView extends ConsumerWidget {
  static const String title = 'Beats Marketplace';
  static const String subtitle =
      'License African beats from top producers — pay in credits, download instantly';

  /// Switches the root shell to the Library tab (index 3).
  final VoidCallback? onNavigateToLibrary;

  const MarketplaceView({super.key, this.onNavigateToLibrary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final beats = ref.watch(filteredBeatsProvider);
    final hasActiveTrack =
        ref.watch(playerStateProvider.select((s) => s.hasActiveTrack));

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          isDesktop
              ? VhunambiTopBarMetrics.totalHeight(
                  context,
                  toolbarHeight: MarketplaceTopBar.desktopHeight,
                )
              : VhunambiTopBarMetrics.totalHeight(
                  context,
                  toolbarHeight: MarketplaceTopBar.mobileHeight,
                ),
        ),
        child: const MarketplaceTopBar(),
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Page header + filter trigger
              SliverToBoxAdapter(child: _header(context, ref)),

              // Seller monetization banner
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                sliver: SliverToBoxAdapter(
                  child: SellerCalloutBanner(
                    onGoToLibrary: onNavigateToLibrary,
                  ),
                ),
              ),

              // Beat listing grid or universal empty state
              if (beats.isEmpty)
                const SliverToBoxAdapter(child: MarketplaceEmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _columns(context),
                      crossAxisSpacing: AppSpacing.sm,
                      mainAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 0.68,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final beat = beats[index];
                        return BeatCard(
                          beat: beat,
                          onLicenseRequested: () =>
                              showBeatLicenseModal(context, beat),
                        );
                      },
                      childCount: beats.length,
                    ),
                  ),
                ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: VhunambiBottomDockMetrics.scrollInset(
                    hasActiveTrack: hasActiveTrack,
                  ),
                ),
              ),
            ],
          ),


        ],
      ),
    );
  }

  Widget _header(BuildContext context, WidgetRef ref) {
    final resultCount = ref.watch(filteredBeatsProvider).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PhosphorIcon(
                AppIcons.navMarket,
                size: 22,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => showMarketplaceFilterModal(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.borderSubtle),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
                icon: const PhosphorIcon(AppIcons.beatstore, size: 16),
                label: Text(
                  'Filters',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            style: AppTypography.bodyMuted,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '$resultCount ${resultCount == 1 ? 'listing' : 'listings'} available',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }

  int _columns(BuildContext context) {
    if (ResponsiveUtils.isDesktop(context)) return 4;
    if (ResponsiveUtils.isTablet(context)) return 3;
    return 2;
  }
}
