import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/cultural_translation_spotlight.dart';
import '../widgets/heritage_genre_showcase.dart';
import '../widgets/how_it_works_section.dart';
import '../widgets/landing_footer.dart';
import '../widgets/landing_hero_section.dart';
import '../widgets/pricing_matrix_section.dart';
import '../widgets/social_proof_counters.dart';
import '../widgets/testimonials_wall.dart';
import '../widgets/value_pillars_grid.dart';

/// Marketing Landing Funnel (`/`) — mounted at tab index 0 of `RootShell`.
/// Reference: `docs/phases/phase_06_marketplace/blueprint.md` §3
class HomeLandingView extends StatelessWidget {
  /// Routes the funnel CTAs into the Studio cockpit (tab index 2).
  final VoidCallback? onGetStarted;

  const HomeLandingView({super.key, this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: LandingHeroSection(onGetStarted: onGetStarted),
          ),
          const SliverToBoxAdapter(child: SocialProofCounters()),
          SliverToBoxAdapter(
            child: HowItWorksSection(onGetStarted: onGetStarted),
          ),
          const SliverToBoxAdapter(child: HeritageGenreShowcase()),
          const SliverToBoxAdapter(child: ValuePillarsGrid()),
          const SliverToBoxAdapter(child: CulturalTranslationSpotlight()),
          const SliverToBoxAdapter(child: TestimonialsWall()),
          const SliverToBoxAdapter(child: PricingMatrixSection()),
          const SliverToBoxAdapter(child: LandingFooter()),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }
}
