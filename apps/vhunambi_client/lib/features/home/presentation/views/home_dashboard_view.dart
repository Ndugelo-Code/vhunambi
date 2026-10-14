import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/widgets/vhunambi_bottom_dock_kit.dart';
import '../../../../shared/models/track.dart';
import '../../../explore/presentation/providers/explore_providers.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../profile/presentation/views/owner_profile_view.dart';
import '../../../profile/presentation/widgets/avatar_customization_modal.dart';
import '../../../profile/presentation/widgets/creator_avatar.dart';
import '../../../studio/presentation/providers/studio_form_provider.dart';
import '../../../track/presentation/views/track_detail_view.dart';
import '../utils/african_greeting_resolver.dart';
import '../widgets/subscription_upgrade_modal.dart';
import '../../../social/presentation/widgets/trending_reels_shelf.dart';
import '../../../creator_dna/presentation/widgets/dna_insight_card.dart';
import '../../../creator_dna/presentation/providers/creator_dna_provider.dart';

class HomeDashboardView extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToStudio;
  final VoidCallback? onNavigateToMarket;
  final VoidCallback? onNavigateToLibrary;

  const HomeDashboardView({
    super.key,
    this.onNavigateToStudio,
    this.onNavigateToMarket,
    this.onNavigateToLibrary,
  });

  @override
  ConsumerState<HomeDashboardView> createState() => _HomeDashboardViewState();
}

class _HomeDashboardViewState extends ConsumerState<HomeDashboardView> {
  final TextEditingController _promptController = TextEditingController();

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  void _submitQuickPrompt([String? presetText]) {
    HapticFeedback.mediumImpact();
    final text = presetText ?? _promptController.text.trim();
    if (text.isNotEmpty) {
      ref.read(studioFormProvider.notifier).updatePrompt(text);
    }
    widget.onNavigateToStudio?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final hasActiveTrack =
        ref.watch(playerStateProvider.select((s) => s.hasActiveTrack));
    final onboardingState = ref.watch(onboardingStateProvider);
    final ownerProfile = ref.watch(ownerProfileProvider);
    final exploreTracks = ref.watch(exploreTracksProvider);
    final isPlaying = ref.watch(playerStateProvider.select((s) => s.isPlaying));
    final activeTrackId =
        ref.watch(playerStateProvider.select((s) => s.currentTrack?.id));

    final userLanguage = onboardingState.selectedLanguages.isNotEmpty
        ? onboardingState.selectedLanguages.first
        : 'Tshivenḓa';
    final greetingText =
        AfricanGreetingResolver.getGreeting(language: userLanguage);
    final timeGlyph = AfricanGreetingResolver.getTimeGlyph();

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 1. Dashboard Top Header Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 32 : 16,
                  16,
                  isDesktop ? 32 : 16,
                  12,
                ),
                child: Row(
                  children: [
                    // Creator Profile Avatar / Icon (44x44px HIG target)
                    CreatorAvatar(
                      avatarKey: const Key('home_avatar_btn'),
                      avatarUrl: ownerProfile.avatarUrl,
                      monogram: ownerProfile.monogram.isNotEmpty
                          ? ownerProfile.monogram
                          : 'ND',
                      size: 44,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const OwnerProfileView(),
                          ),
                        );
                      },
                      onLongPress: () {
                        AvatarCustomizationModal.show(context);
                      },
                    ),
                    const SizedBox(width: 12),

                    // Authentic African Greeting (No name, No English subtitles)
                    Expanded(
                      child: Text(
                        '$greetingText $timeGlyph',
                        key: const Key('home_greeting_text'),
                        style: (isDesktop
                                ? AppTypography.titleLarge
                                : AppTypography.titleMedium)
                            .copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Streak Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: AppRadius.pillBorder,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          const Text('🔥'),
                          const SizedBox(width: 4),
                          Text(
                            '2 Streak',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Credit Token Chip (Opens Subscription Modal)
                    GestureDetector(
                      onTap: () => SubscriptionUpgradeModal.show(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary.withAlpha(20),
                          borderRadius: AppRadius.pillBorder,
                          border: Border.all(color: AppColors.brandPrimary),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.bolt_rounded,
                              color: AppColors.brandPrimary,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '10 left',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.brandPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 1b. Creator DNA Insight Card (T6.6 — REQ-DNA-HOME-01/02)
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) {
                  final dna = ref.watch(creatorDnaProvider);
                  if (dna.dnaInsightCardDismissed || dna.strengthPercent == 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      isDesktop ? 32 : 16,
                      0,
                      isDesktop ? 32 : 16,
                      8,
                    ),
                    child: const DnaInsightCard(
                      key: Key('home_dna_insight_card'),
                      animatedMeter: true,
                    ),
                  );
                },
              ),
            ),

            // 2. Quick Studio Creation Prompt Card
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 16,
                  vertical: 12,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: AppRadius.cardBorder,
                    border: Border.all(color: AppColors.borderSubtle),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(50),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: AppColors.brandPrimary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'What are you feeling today?',
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Input Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondary,
                          borderRadius: AppRadius.pillBorder,
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _promptController,
                                style: AppTypography.bodySmall,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Describe a vibe, story, or melody...',
                                  hintStyle: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 13,
                                  ),
                                  border: InputBorder.none,
                                ),
                                onSubmitted: (val) => _submitQuickPrompt(val),
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brandPrimary,
                                foregroundColor: AppColors.brandContrast,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: AppRadius.pillBorder,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                elevation: 0,
                              ),
                              onPressed: () => _submitQuickPrompt(),
                              child: const Text(
                                'Create ✨',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Inspiration Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPresetChip('Amapiano Late-Night Log Drum'),
                            _buildPresetChip('Maskandi Acoustic Folk Story'),
                            _buildPresetChip('Soweto Deep Soul Anthem'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. 4-Card Quick Actions Grid
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.auto_awesome_rounded,
                        title: 'AI Studio',
                        subtitle: 'Compose track',
                        color: AppColors.brandPrimary,
                        onTap: () => widget.onNavigateToStudio?.call(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Beats Market',
                        subtitle: 'License beats',
                        color: const Color(0xFFF59E0B),
                        onTap: () => widget.onNavigateToMarket?.call(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.library_music_outlined,
                        title: 'Asset Vault',
                        subtitle: 'Your tracks',
                        color: const Color(0xFF3B82F6),
                        onTap: () => widget.onNavigateToLibrary?.call(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.layers_outlined,
                        title: 'Stem Lab',
                        subtitle: 'Split 4 tracks',
                        color: const Color(0xFF10B981),
                        onTap: () => widget.onNavigateToStudio?.call(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 4. "Jump Back In" / Recent Session Card
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 32 : 16,
                  20,
                  isDesktop ? 32 : 16,
                  10,
                ),
                child: Row(
                  children: [
                    Text(
                      'Jump Back In',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => widget.onNavigateToLibrary?.call(),
                      child: Text(
                        'View all ->',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 16,
                ),
                child: _buildJumpBackInCard(
                  track: exploreTracks.isNotEmpty
                      ? exploreTracks.first
                      : const Track(
                          id: 'seed-01',
                          title: 'Ndo Mufuna Matibe',
                          creatorName: 'Fifi',
                          genre: 'Amapiano',
                          language: 'Tshivenḓa',
                          duration: Duration(seconds: 198),
                        ),
                  isPlaying: isPlaying &&
                      activeTrackId ==
                          (exploreTracks.isNotEmpty
                              ? exploreTracks.first.id
                              : 'seed-01'),
                ),
              ),
            ),

            // 4.5 Trending Kinetic Reels discovery shelf (Phase 19)
            const SliverToBoxAdapter(child: TrendingReelsShelf()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),

            // 5. Daily Heritage Spotlight Banner
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 32 : 16,
                  24,
                  isDesktop ? 32 : 16,
                  12,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppGradients.forGenre('Maskandi'),
                    borderRadius: AppRadius.cardBorder,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(80),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.album_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DAILY RHYTHM SPOTLIGHT',
                              style: AppTypography.caption.copyWith(
                                color: Colors.white.withAlpha(200),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Maskandi Acoustic Folk Tuning',
                              style: AppTypography.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Explore Zulu finger-picking syncopation with native acoustic presets.',
                              style: AppTypography.bodySmall.copyWith(
                                color: Colors.white.withAlpha(220),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.pillBorder,
                          ),
                        ),
                        onPressed: () => widget.onNavigateToStudio?.call(),
                        child: const Text('Try Rhythm',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 6. Recommended African Beats & Drops
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 32 : 16,
                  20,
                  isDesktop ? 32 : 16,
                  12,
                ),
                child: Row(
                  children: [
                    Text(
                      'Trending in Your Genres',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      onboardingState.selectedGenres.take(2).join(' • '),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 180,
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 32 : 16,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: exploreTracks.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final track = exploreTracks[index];
                    return _buildHorizontalTrackCard(track);
                  },
                ),
              ),
            ),

            // 7. Pro Subscription Upgrade Banner
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 32 : 16,
                  28,
                  isDesktop ? 32 : 16,
                  VhunambiBottomDockMetrics.scrollInset(
                    hasActiveTrack: hasActiveTrack,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.brandPrimary.withAlpha(90),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        color: AppColors.brandPrimary,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upgrade to Creator or Pro',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Up to 2,000 songs/mo, 4-stem isolation, and full commercial license.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary,
                          foregroundColor: AppColors.brandContrast,
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.pillBorder,
                          ),
                        ),
                        onPressed: () =>
                            SubscriptionUpgradeModal.show(context),
                        child: const Text('View Plans',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(text),
        onPressed: () => _submitQuickPrompt(text),
        backgroundColor: AppColors.surfaceSecondary,
        labelStyle: AppTypography.caption.copyWith(color: AppColors.textPrimary),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.pillBorder,
          side: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJumpBackInCard({
    required Track track,
    required bool isPlaying,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppGradients.forGenre(track.genre),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.music_note_rounded, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TrackDetailView(
                      trackId: track.id,
                      onNavigateToStudio: widget.onNavigateToStudio,
                    ),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${track.creatorName} • ${track.genre} • ${track.formattedDuration}',
                    style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            iconSize: 40,
            icon: Icon(
              isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              color: AppColors.brandPrimary,
            ),
            onPressed: () {
              ref.read(playerStateProvider.notifier).playTrack(track);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalTrackCard(Track track) {
    return GestureDetector(
      onTap: () {
        ref.read(playerStateProvider.notifier).playTrack(track);
      },
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppGradients.forGenre(track.genre),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              track.title,
              style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${track.genre} • ${track.formattedDuration}',
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
