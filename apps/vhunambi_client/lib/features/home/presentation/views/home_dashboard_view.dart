import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/widgets/vhunambi_bottom_dock_kit.dart';
import '../../../../shared/models/track.dart';
import '../../../creator_dna/presentation/providers/creator_dna_provider.dart';
import '../../../creator_dna/presentation/widgets/dna_insight_card.dart';
import '../../../explore/presentation/providers/explore_providers.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../mastering/presentation/views/desktop_mastering_studio_view.dart';
import '../../../mastering/presentation/widgets/mobile_quick_master_sheet.dart';
import '../../../notifications/presentation/views/notifications_view.dart';
import '../../../onboarding/presentation/providers/onboarding_providers.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../profile/presentation/views/owner_profile_view.dart';
import '../../../profile/presentation/widgets/avatar_customization_modal.dart';
import '../../../profile/presentation/widgets/creator_avatar.dart';
import '../../../social/presentation/providers/creator_wallet_provider.dart';
import '../../../social/presentation/widgets/trending_reels_shelf.dart';
import '../../../studio/presentation/providers/generation_pipeline_providers.dart';
import '../../../studio/presentation/providers/melody_sketchpad_provider.dart';
import '../../../studio/presentation/providers/studio_form_provider.dart';
import '../../../studio/presentation/widgets/melody_sketchpad_modal.dart';
import '../../../studio/presentation/widgets/vocal_identity_picker_sheet.dart';
import '../../../track/presentation/views/track_detail_view.dart';
import '../../domain/models/african_rhythm_matrix.dart';
import '../utils/african_greeting_resolver.dart';
import '../widgets/subscription_upgrade_modal.dart';

class HomeDashboardView extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToStudio;
  final VoidCallback? onNavigateToMarket;
  final VoidCallback? onNavigateToLibrary;
  final int? injectedWeekday;

  const HomeDashboardView({
    super.key,
    this.onNavigateToStudio,
    this.onNavigateToMarket,
    this.onNavigateToLibrary,
    this.injectedWeekday,
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

  void _openMastering(
    BuildContext context, {
    String? trackId,
    String? trackTitle,
    String? genre,
  }) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    if (isDesktop) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DesktopMasteringStudioView(
            trackId: trackId,
            trackTitle: trackTitle,
            genre: genre,
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => MobileQuickMasterSheet(
          trackId: trackId,
          trackTitle: trackTitle,
          genre: genre,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isCompact = MediaQuery.of(context).size.width < 500;
    final hasActiveTrack = ref.watch(
      playerStateProvider.select((s) => s.hasActiveTrack),
    );
    final onboardingState = ref.watch(onboardingStateProvider);
    final ownerProfile = ref.watch(ownerProfileProvider);
    final creatorWallet = ref.watch(creatorWalletProvider);
    final exploreTracks = ref.watch(exploreTracksProvider);
    final libraryTracks = ref.watch(libraryTracksProvider);
    final pipelineProgress = ref.watch(generationProgressProvider);
    final isPlaying = ref.watch(playerStateProvider.select((s) => s.isPlaying));
    final activeTrackId = ref.watch(
      playerStateProvider.select((s) => s.currentTrack?.id),
    );

    final userLanguage = onboardingState.selectedLanguages.isNotEmpty
        ? onboardingState.selectedLanguages.first
        : 'Tshivenḓa';
    final greetingText = AfricanGreetingResolver.getGreeting(
      language: userLanguage,
    );
    final timeGlyph = AfricanGreetingResolver.getTimeGlyph();

    final spotlight = AfricanRhythmMatrix.forWeekday(widget.injectedWeekday);

    // Resolve real user session from private vault (HOME-002)
    final validVaultTracks = libraryTracks.where((t) => !t.isDeleted).toList();
    final Track jumpBackTrack;
    if (validVaultTracks.isNotEmpty) {
      final latest = validVaultTracks.first;
      jumpBackTrack = Track(
        id: latest.id,
        title: latest.title,
        creatorName: latest.creatorName.isNotEmpty
            ? latest.creatorName
            : ownerProfile.displayName,
        genre: latest.genre,
        language: latest.language,
        duration: Duration(seconds: latest.durationSeconds),
        audioUrl: latest.remoteAudioUrl,
      );
    } else if (exploreTracks.isNotEmpty) {
      jumpBackTrack = exploreTracks.first;
    } else {
      jumpBackTrack = const Track(
        id: 'seed-01',
        title: 'Ndo Mufuna Matibe',
        creatorName: 'Fifi',
        genre: 'Amapiano',
        language: 'Tshivenḓa',
        duration: Duration(seconds: 198),
      );
    }

    // Scoped "Trending in Your Genres" filter (HOME-006)
    final userGenres = onboardingState.selectedGenres
        .map((g) => g.toLowerCase().trim())
        .toSet();
    final scopedTracks = userGenres.isEmpty
        ? exploreTracks
        : exploreTracks
              .where((t) => userGenres.contains(t.genre.toLowerCase().trim()))
              .toList();
    final displayedGenreTracks = scopedTracks.isNotEmpty
        ? scopedTracks
        : exploreTracks;

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 1. Dashboard Top Header Bar (HOME-001, HOME-008)
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
                    const SizedBox(width: 8),

                    // Authentic African Greeting
                    Expanded(
                      child: Text(
                        '$greetingText $timeGlyph',
                        key: const Key('home_greeting_text'),
                        style:
                            (isDesktop
                                    ? AppTypography.titleLarge
                                    : AppTypography.titleMedium)
                                .copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Action Triad:
                    // 1. Streak Badge
                    Container(
                      key: const Key('home_streak_pill'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: AppRadius.pillBorder,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PhosphorIcon(
                            AppIcons.flame,
                            size: 13,
                            color: AppColors.brandPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCompact
                                ? '${ownerProfile.dayStreak}'
                                : '${ownerProfile.dayStreak} Streak',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),

                    // 2. Coin Token Chip (Opens Subscription Modal to satisfy Pin #8)
                    InkWell(
                      key: const Key('home_coins_pill'),
                      onTap: () => SubscriptionUpgradeModal.show(context),
                      borderRadius: AppRadius.pillBorder,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.coinGold.withAlpha(20),
                          borderRadius: AppRadius.pillBorder,
                          border: Border.all(
                            color: AppColors.coinGold.withAlpha(120),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PhosphorIcon(
                              AppIcons.coin,
                              size: 13,
                              color: AppColors.coinGold,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isCompact
                                  ? '${creatorWallet.userCoinsBalance}'
                                  : '${creatorWallet.userCoinsBalance} Coins',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.coinGold,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // 3. 1-Step Notification Bell Button
                    InkWell(
                      key: const Key('home_notifications_btn'),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NotificationsView(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 44,
                        ),
                        child: const Center(
                          child: PhosphorIcon(
                            AppIcons.bell,
                            size: 20,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 1b. In-Flight AI Generation Banner (HOME-007, Safeguard 3)
            if (pipelineProgress != null && pipelineProgress.isGenerating)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 32 : 16,
                    vertical: 6,
                  ),
                  child: InkWell(
                    key: const Key('home_inflight_generation_banner'),
                    onTap: () => widget.onNavigateToStudio?.call(),
                    borderRadius: AppRadius.cardBorder,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: AppRadius.cardBorder,
                        border: Border.all(
                          color: AppColors.brandPrimary.withAlpha(120),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brandPrimary.withAlpha(25),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              value: pipelineProgress.progressPercent > 0
                                  ? pipelineProgress.progressPercent.clamp(
                                      0.0,
                                      1.0,
                                    )
                                  : 0.1,
                              strokeWidth: 2.2,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.brandPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Synthesizing "${pipelineProgress.trackTitle}"',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${pipelineProgress.statusMessage} • ${(pipelineProgress.progressPercent * 100).toInt()}%',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PhosphorIcon(
                            AppIcons.caretRight,
                            size: 14,
                            color: AppColors.brandPrimary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // 1c. Creator DNA Insight Card (T6.6 — REQ-DNA-HOME-01/02)
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
                          const PhosphorIcon(
                            AppIcons.sparkle,
                            color: AppColors.brandPrimary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'What are you feeling today?',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
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

            // 3. Responsive 6-Tool V4.1 Creation Hub (HOME-003, HOME-004)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 16,
                  vertical: 8,
                ),
                child: _buildResponsiveCreationHub(
                  isDesktop: isDesktop,
                  latestVaultTrack: validVaultTracks.isNotEmpty
                      ? validVaultTracks.first
                      : null,
                ),
              ),
            ),

            // 4. True Personal Vault "Jump Back In" Card (HOME-002)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 32 : 16,
                  20,
                  isDesktop ? 32 : 16,
                  10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Jump Back In',
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => widget.onNavigateToLibrary?.call(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
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
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16),
                child: _buildJumpBackInCard(
                  track: jumpBackTrack,
                  isPlaying: isPlaying && activeTrackId == jumpBackTrack.id,
                  rawVaultTrack: validVaultTracks.isNotEmpty
                      ? validVaultTracks.first
                      : null,
                ),
              ),
            ),

            // 4.5 Trending Kinetic Reels discovery shelf (Phase 19)
            const SliverToBoxAdapter(child: TrendingReelsShelf()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),

            // 5. Dynamic 7-Day Rotating Indigenous Rhythm Matrix (HOME-005)
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
                    gradient: AppGradients.forGenre(spotlight.genre),
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
                        child: const PhosphorIcon(
                          AppIcons.disc,
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
                              'DAILY RHYTHM SPOTLIGHT • ${spotlight.dayName.toUpperCase()}',
                              style: AppTypography.caption.copyWith(
                                color: Colors.white.withAlpha(200),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${spotlight.title} (${spotlight.bpm} BPM • ${spotlight.musicalKey})',
                              style: AppTypography.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              spotlight.description,
                              style: AppTypography.bodySmall.copyWith(
                                color: Colors.white.withAlpha(220),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        key: const Key('home_try_rhythm_btn'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.pillBorder,
                          ),
                        ),
                        onPressed: () {
                          // Inject spotlight presets into Studio & Sketchpad
                          ref
                              .read(studioFormProvider.notifier)
                              .setGenre(spotlight.genre);
                          ref
                              .read(studioFormProvider.notifier)
                              .updatePrompt(spotlight.samplePrompt);
                          ref
                              .read(melodySketchpadProvider.notifier)
                              .initializeFromRemixDna(
                                genre: spotlight.genre,
                                bpm: spotlight.bpm,
                                musicalKey: spotlight.musicalKey,
                              );
                          widget.onNavigateToStudio?.call();
                        },
                        child: const Text(
                          'Try Rhythm',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 6. Recommended African Beats & Drops ("Trending in Your Genres") (HOME-006)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 32 : 16,
                  20,
                  isDesktop ? 32 : 16,
                  12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Trending in Your Genres',
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      onboardingState.selectedGenres.isNotEmpty
                          ? onboardingState.selectedGenres.take(2).join(' • ')
                          : 'All Regional Genres',
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
                  itemCount: displayedGenreTracks.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final track = displayedGenreTracks[index];
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
                      const PhosphorIcon(
                        AppIcons.crown,
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
                        onPressed: () => SubscriptionUpgradeModal.show(context),
                        child: const Text(
                          'View Plans',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
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
        labelStyle: AppTypography.caption.copyWith(
          color: AppColors.textPrimary,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.pillBorder,
          side: BorderSide(color: AppColors.borderSubtle),
        ),
      ),
    );
  }

  /// Responsive 6-Tool Creation Hub (2x3 Grid on Mobile / 6x1 Row on Desktop)
  Widget _buildResponsiveCreationHub({
    required bool isDesktop,
    LibraryTrack? latestVaultTrack,
  }) {
    final tools = [
      (
        key: const Key('home_hub_ai_studio'),
        icon: AppIcons.magicWand,
        title: 'AI Studio',
        subtitle: 'Compose track',
        color: AppColors.brandPrimary,
        onTap: () => widget.onNavigateToStudio?.call(),
      ),
      (
        key: const Key('home_hub_voice_clone'),
        icon: AppIcons.voiceClone,
        title: 'Voice Clone',
        subtitle: '24 Voices & DNA',
        color: const Color(0xFFEC4899),
        onTap: () => VocalIdentityPickerSheet.show(context),
      ),
      (
        key: const Key('home_hub_melody_sketchpad'),
        icon: AppIcons.piano,
        title: 'Sketchpad',
        subtitle: 'Log-Drum & Keys',
        color: const Color(0xFF8B5CF6),
        onTap: () => MelodySketchpadModal.show(context),
      ),
      (
        key: const Key('home_hub_stem_master'),
        icon: AppIcons.mastering,
        title: 'Stem Lab',
        subtitle: 'Studio Master',
        color: const Color(0xFF10B981),
        onTap: () => _openMastering(
          context,
          trackId: latestVaultTrack?.id,
          trackTitle: latestVaultTrack?.title,
          genre: latestVaultTrack?.genre,
        ),
      ),
      (
        key: const Key('home_hub_beats_market'),
        icon: AppIcons.navMarket,
        title: 'Beats Market',
        subtitle: 'License beats',
        color: AppColors.coinGold,
        onTap: () => widget.onNavigateToMarket?.call(),
      ),
      (
        key: const Key('home_hub_asset_vault'),
        icon: AppIcons.songs,
        title: 'Asset Vault',
        subtitle: 'Tracks & Beats',
        color: const Color(0xFF3B82F6),
        onTap: () => widget.onNavigateToLibrary?.call(),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: tools
            .map(
              (t) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildActionTile(
                    key: t.key,
                    icon: t.icon,
                    title: t.title,
                    subtitle: t.subtitle,
                    color: t.color,
                    onTap: t.onTap,
                  ),
                ),
              ),
            )
            .toList(),
      );
    }

    // Mobile: 2 rows of 3 columns
    return Column(
      children: [
        Row(
          children: tools
              .sublist(0, 3)
              .map(
                (t) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _buildActionTile(
                      key: t.key,
                      icon: t.icon,
                      title: t.title,
                      subtitle: t.subtitle,
                      color: t.color,
                      onTap: t.onTap,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: tools
              .sublist(3, 6)
              .map(
                (t) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _buildActionTile(
                      key: t.key,
                      icon: t.icon,
                      title: t.title,
                      subtitle: t.subtitle,
                      color: t.color,
                      onTap: t.onTap,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
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
    LibraryTrack? rawVaultTrack,
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
              child: PhosphorIcon(
                AppIcons.songs,
                color: Colors.white,
                size: 28,
              ),
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
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${track.creatorName} • ${track.genre} • ${track.formattedDuration}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Action 1: Polish / Stems Button (HOME-002)
          IconButton(
            key: const Key('home_jump_back_master_btn'),
            tooltip: 'Polish Stems & Master',
            icon: const PhosphorIcon(
              AppIcons.beatstore,
              color: AppColors.textSecondary,
              size: 22,
            ),
            onPressed: () => _openMastering(
              context,
              trackId: rawVaultTrack?.id ?? track.id,
              trackTitle: rawVaultTrack?.title ?? track.title,
              genre: rawVaultTrack?.genre ?? track.genre,
            ),
          ),

          // Action 2: Playback Button (Pin #9)
          IconButton(
            iconSize: 40,
            icon: PhosphorIcon(
              isPlaying
                  ? AppIcons.pause
                  : AppIcons.play,
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
                  child: PhosphorIcon(
                    AppIcons.play,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              track.title,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${track.genre} • ${track.formattedDuration}',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
