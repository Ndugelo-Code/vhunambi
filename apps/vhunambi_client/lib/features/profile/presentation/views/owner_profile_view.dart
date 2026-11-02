import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/widgets/vhunambi_bottom_dock_kit.dart';
import '../../../../core/widgets/vhunambi_top_bar_kit.dart';
import '../../../../shared/models/track.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../domain/models/profile_models.dart';
import '../providers/profile_providers.dart';
import '../providers/synchronized_analytics_provider.dart';
import '../widgets/artist_voice_showcase_card.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/pin_song_selector_sheet.dart';
import '../widgets/pinned_spotlight_card.dart';
import '../widgets/profile_referral_card.dart';
import '../widgets/profile_settings_drawer.dart';
import '../widgets/releases_manager_card.dart';
import '../widgets/studio_analytics_console_sheet.dart';
import '../widgets/tip_history_ledger.dart';
import '../widgets/creator_wallet_deck.dart';
import '../widgets/owner_beatstore_cockpit.dart';
import '../../../social/presentation/providers/creator_clips_provider.dart';
import '../../../social/presentation/widgets/creator_reel_thumbnail_card.dart';
import '../../../social/presentation/widgets/kinetic_reels_modal.dart';
import '../../../studio/presentation/providers/melody_sketchpad_provider.dart';
import '../../../studio/presentation/widgets/melody_sketchpad_modal.dart';
import '../widgets/avatar_customization_modal.dart';
import '../widgets/creator_avatar.dart';
import '../../domain/models/profile_operation_type.dart';
import '../../domain/models/profile_operation_state.dart';
import '../widgets/error/error_boundary.dart';
import '../widgets/loading/loading_overlay.dart';
import '../widgets/loading/profile_skeleton_screen.dart';
import '../widgets/offline/offline_indicator.dart';
import '../../../creator_dna/presentation/widgets/creator_dna_profile_card.dart';

/// Account Owner Creator Studio Profile View (`/profile/me`) (REQ-TRK-15, REQ-TRK-16).
class OwnerProfileView extends ConsumerStatefulWidget {
  const OwnerProfileView({super.key});

  @override
  ConsumerState<OwnerProfileView> createState() => _OwnerProfileViewState();
}

class _OwnerProfileViewState extends ConsumerState<OwnerProfileView> {
  OwnerStudioTab _activeTab = OwnerStudioTab.songs;

  // Track visibility map (trackId -> isPublic)
  final Map<String, bool> _trackVisibility = {
    'track_own_01': true,
    'track_own_02': true,
  };

  void _showNewReleaseDialog() {
    final titleController = TextEditingController();
    ReleaseType selectedType = ReleaseType.single;
    String selectedGenre = 'House';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceModal,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
              title: Text(
                'Create New Release',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    style: AppTypography.bodySmall,
                    decoration: InputDecoration(
                      labelText: 'Release Title',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.borderSubtle),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Release Type',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: ReleaseType.values.map((type) {
                      final isSelected = type == selectedType;
                      final label = switch (type) {
                        ReleaseType.single => 'Single',
                        ReleaseType.ep => 'EP',
                        ReleaseType.album => 'Album',
                      };
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          selectedColor: AppColors.brandPrimary,
                          backgroundColor: AppColors.surfaceElevated,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.brandContrast
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) setDialogState(() => selectedType = type);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isNotEmpty) {
                      ref
                          .read(ownerProfileOperationProvider.notifier)
                          .addRelease(
                            MusicReleaseEntity(
                              id: 'rel_${DateTime.now().millisecondsSinceEpoch}',
                              title: title,
                              releaseType: selectedType,
                              trackCount: selectedType == ReleaseType.single
                                  ? 1
                                  : 4,
                              releaseDate: DateTime.now(),
                              genre: selectedGenre,
                            ),
                          );
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Release "$title" created! 💿')),
                      );
                    }
                  },
                  child: const Text('Create Release'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final profile = ref.watch(ownerProfileProvider);
    final opState = ref.watch(ownerProfileOperationProvider);
    final syncAnalytics = ref.watch(synchronizedAnalyticsProvider);
    final hasActiveTrack = ref.watch(
      playerStateProvider.select((s) => s.hasActiveTrack),
    );
    final bottomInset =
        VhunambiBottomDockMetrics.scrollInset(hasActiveTrack: hasActiveTrack) +
        36;

    // Listen for mutation error notifications
    ref.listen<ProfileOperationState>(ownerProfileOperationProvider, (
      prev,
      curr,
    ) {
      for (final type in [
        ProfileOperationType.avatarUpdate,
        ProfileOperationType.createRelease,
        ProfileOperationType.visibilityToggle,
      ]) {
        final err = curr.errorFor(type);
        if (err != null && prev?.errorFor(type) != err) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    });

    if (opState.isLoading(ProfileOperationType.fetch) &&
        opState.cachedProfile == null) {
      return const ProfileSkeletonScreen();
    }

    final fetchError = opState.errorFor(ProfileOperationType.fetch);
    if (fetchError != null && opState.cachedProfile == null) {
      return Scaffold(
        backgroundColor: AppColors.surfaceCanvas,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const VhunambiBackButton(color: Colors.white),
        ),
        body: ErrorBoundary(
          message: fetchError.message,
          onRetry: () =>
              ref.read(ownerProfileOperationProvider.notifier).fetchProfile(),
        ),
      );
    }

    final isMutating =
        opState.isLoading(ProfileOperationType.createRelease) ||
        opState.isLoading(ProfileOperationType.avatarUpdate) ||
        opState.isLoading(ProfileOperationType.visibilityToggle);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const VhunambiBackButton(color: Colors.white),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                AppIcons.studio,
                color: AppColors.brandPrimary,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'CREATOR STUDIO',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            key: const Key('owner_header_settings_btn'),
            icon: const PhosphorIcon(
              AppIcons.settings,
              color: Colors.white,
              size: 20,
            ),
            tooltip: 'Studio Settings',
            onPressed: () => ProfileSettingsDrawer.show(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LoadingOverlay(
        isLoading: isMutating,
        message: 'Updating studio...',
        child: RefreshIndicator(
          color: AppColors.brandPrimary,
          backgroundColor: AppColors.surfaceModal,
          onRefresh: () =>
              ref.read(ownerProfileOperationProvider.notifier).fetchProfile(),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 32 : 16,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (opState.isOffline) ...[
                        OfflineIndicator(
                          cacheTimestamp: opState.cachedProfile?.timestamp,
                          onRefresh: () => ref
                              .read(ownerProfileOperationProvider.notifier)
                              .fetchProfile(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // 1. Owner Profile Scaffolding Row
                      Row(
                        children: [
                          // Creator Profile Avatar with AI Edit Badge
                          CreatorAvatar(
                            avatarKey: const Key('owner_avatar_button'),
                            avatarUrl: profile.avatarUrl,
                            monogram: profile.monogram,
                            size: 68,
                            borderWidth: 2,
                            showEditBadge: true,
                            onTap: () {
                              AvatarCustomizationModal.show(context);
                            },
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.displayName,
                                  style: AppTypography.titleLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '@${profile.username} • Verified Creator',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 2. Management Action Strip
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildActionPill(
                            key: const Key('owner_change_avatar_btn'),
                            icon: AppIcons.sparkle,
                            label: 'Change Avatar',
                            onTap: () {
                              AvatarCustomizationModal.show(context);
                            },
                          ),
                          _buildActionPill(
                            key: const Key('owner_edit_profile_btn'),
                            icon: AppIcons.edit,
                            label: 'Edit Profile',
                            onTap: () {
                              EditProfileSheet.show(context);
                            },
                          ),
                          _buildActionPill(
                            key: const Key('owner_pin_song_btn'),
                            icon: AppIcons.pin,
                            label: 'Pin Song',
                            onTap: () {
                              PinSongSelectorSheet.show(context);
                            },
                          ),
                          _buildActionPill(
                            key: const Key('owner_analytics_btn'),
                            icon: AppIcons.analytics,
                            label: 'Studio Analytics',
                            onTap: () {
                              StudioAnalyticsConsoleSheet.show(context);
                            },
                          ),
                          _buildActionPill(
                            key: const Key('owner_theme_settings_btn'),
                            icon: AppIcons.settings,
                            label: 'Settings',
                            onTap: () {
                              ProfileSettingsDrawer.show(context);
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // 3. Top Genres Analytics Chips
                      Text(
                        'TOP GENRES',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildGenreChip('🎵 House', '1'),
                          _buildGenreChip('🎹 Amapiano', '4'),
                          _buildGenreChip('🎸 Maskandi', '2'),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // 3b. Pinned Spotlight Card (if pinned)
                      if (profile.pinnedTrackId != null &&
                          profile.pinnedTrackId!.isNotEmpty) ...[
                        PinnedSpotlightCard(
                          pinnedTrackId: profile.pinnedTrackId,
                          fallbackCreatorName: profile.displayName,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 3c. Creator DNA Profile Card (Phase 2 — REQ-DNA-HOME-01)
                      const CreatorDnaProfileCard(isOwner: true),

                      const SizedBox(height: 24),

                      // 4. Tri-Segment Studio Switcher (Phase 30 REQ-PROF-STUDIO-01)
                      _buildStudioSegmentedSelector(),

                      const SizedBox(height: 12),

                      if (_activeTab == OwnerStudioTab.songs) ...[
                        Row(
                          children: [
                            Text(
                              'Your Songs',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${profile.songCount} total',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildOwnerTrackTile(
                          trackId: 'track_own_01',
                          rank: 1,
                          title: 'ZaYN',
                          genre: 'House',
                          duration: '3:20',
                          plays: 4,
                          likes: 0,
                        ),
                        const SizedBox(height: 10),
                        _buildOwnerTrackTile(
                          trackId: 'track_own_02',
                          rank: 2,
                          title: 'Ndo Mufuna Matibe',
                          genre: 'Amapiano',
                          duration: '3:18',
                          plays: 12,
                          likes: 3,
                        ),
                        const SizedBox(height: 14),
                        const _OwnerReelsShelf(),
                      ] else if (_activeTab == OwnerStudioTab.reels) ...[
                        const _OwnerReelsShelf(),
                      ] else if (_activeTab == OwnerStudioTab.beatstore) ...[
                        const OwnerBeatstoreCockpit(),
                      ] else if (_activeTab ==
                          OwnerStudioTab.voicesAndMelodies) ...[
                        _buildVoicesAndMelodiesTab(context, ref, profile, syncAnalytics),
                      ] else if (_activeTab == OwnerStudioTab.releases) ...[
                        ReleasesManagerCard(
                          releases: profile.releases,
                          onNewRelease: _showNewReleaseDialog,
                        ),
                      ],

                      const SizedBox(height: 14),

                      // 4c. Creator Wallet & Cultural Gifting (Phase 20)
                      const CreatorWalletDeck(),

                      const SizedBox(height: 14),

                      // 6. Tip History Ledger
                      TipHistoryLedger(
                        tipHistory: profile.tipHistory,
                        tipsEnabled: profile.tipsEnabled,
                        onToggleTips: (val) {
                          ref
                              .read(ownerProfileOperationProvider.notifier)
                              .toggleTipsEnabled();
                        },
                      ),

                      // 7. Profile Referral Link Card
                      ProfileReferralCard(username: profile.username),

                      SizedBox(height: bottomInset),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudioSegmentedSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          children: OwnerStudioTab.values.map((tab) {
            final isSelected = _activeTab == tab;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: InkWell(
                  key: Key('owner_studio_tab_${tab.name}'),
                  onTap: () => setState(() => _activeTab = tab),
                  borderRadius: AppRadius.pillBorder,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.brandPrimary
                          : Colors.transparent,
                      borderRadius: AppRadius.pillBorder,
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PhosphorIcon(
                          switch (tab) {
                            OwnerStudioTab.songs => AppIcons.songs,
                            OwnerStudioTab.reels => AppIcons.reels,
                            OwnerStudioTab.beatstore => AppIcons.beatstore,
                            OwnerStudioTab.voicesAndMelodies =>
                              AppIcons.soundPack,
                            OwnerStudioTab.releases => AppIcons.releases,
                          },
                          size: 14,
                          color: isSelected
                              ? AppColors.brandContrast
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tab.label,
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppColors.brandContrast
                                : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActionPill({
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: AppRadius.pillBorder,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: AppRadius.pillBorder,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(icon, size: 16, color: AppColors.brandPrimary),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoicesAndMelodiesTab(
    BuildContext context,
    WidgetRef ref,
    ArtistProfileEntity profile,
    SynchronizedPlatformAnalytics syncAnalytics,
  ) {
    final sketchpad = ref.watch(melodySketchpadProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Sovereign Bantu Vocal Identity Card
        ArtistVoiceShowcaseCard(
          artistName: profile.displayName,
          vocalArchetypeTitle: profile.vocalArchetypeTitle,
          vocalArchetypeLanguage: profile.vocalArchetypeLanguage,
          vocalSampleUrl: profile.vocalSampleUrl,
        ),
        const SizedBox(height: 20),

        // 2. Saved Multi-Track Grooves & Melodies Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  AppIcons.studio,
                  color: AppColors.brandPrimary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Multi-Track Grooves & Melodies',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: AppRadius.pillBorder,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Text(
                '${syncAnalytics.totalSavedMelodiesCount} Saved',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (sketchpad.savedPatterns.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.cardBorder,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Column(
              children: [
                Icon(
                  AppIcons.soundPack,
                  size: 36,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Compose African Grooves in the Sketchpad',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Build 5-channel harmonies combining log drums, nylon guitars, bowed violins, and brass riffs.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  key: const Key('owner_launch_sketchpad_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                  icon: const Icon(AppIcons.studio, size: 16),
                  label: const Text('Launch Sketchpad'),
                  onPressed: () => MelodySketchpadModal.show(context),
                ),
              ],
            ),
          ),
        ] else ...[
          ...sketchpad.savedPatterns.map((pattern) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: AppRadius.cardBorder,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppGradients.forGenre(pattern.genre),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      AppIcons.soundPack,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pattern.name,
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${pattern.genre} • ${pattern.bpm} BPM • ${pattern.notes.length} notes',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Audition Groove',
                    icon: const Icon(
                      AppIcons.play,
                      color: AppColors.brandPrimary,
                      size: 20,
                    ),
                    onPressed: () {
                      ref
                          .read(melodySketchpadProvider.notifier)
                          .previewPattern(pattern);
                    },
                  ),
                  IconButton(
                    tooltip: 'Open in Studio',
                    icon: const Icon(
                      AppIcons.edit,
                      color: Colors.white70,
                      size: 18,
                    ),
                    onPressed: () {
                      ref
                          .read(melodySketchpadProvider.notifier)
                          .loadPattern(pattern);
                      MelodySketchpadModal.show(context);
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildGenreChip(String label, String count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        '$label ($count)',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildOwnerTrackTile({
    required String trackId,
    required int rank,
    required String title,
    required String genre,
    required String duration,
    required int plays,
    required int likes,
  }) {
    final isPublic = _trackVisibility[trackId] ?? true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Text(
            '[$rank]',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppGradients.forGenre(genre),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.music_note_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '$genre • $duration • ▶ $plays • ❤️ $likes',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Inline Public / Private Visibility Switch
          InkWell(
            onTap: () {
              setState(() {
                _trackVisibility[trackId] = !isPublic;
              });
            },
            borderRadius: AppRadius.pillBorder,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isPublic
                    ? const Color(0xFF10B981).withAlpha(20)
                    : AppColors.surfaceSecondary,
                borderRadius: AppRadius.pillBorder,
                border: Border.all(
                  color: isPublic
                      ? const Color(0xFF10B981)
                      : AppColors.borderSubtle,
                ),
              ),
              child: Text(
                isPublic ? '🌐 Public' : '🔒 Private',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isPublic
                      ? const Color(0xFF34D399)
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            iconSize: 24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.play_circle_fill_rounded,
              color: AppColors.brandPrimary,
            ),
            onPressed: () {
              ref
                  .read(playerStateProvider.notifier)
                  .playTrack(
                    Track(
                      id: trackId,
                      title: title,
                      creatorName: 'cern',
                      genre: genre,
                      duration: const Duration(minutes: 3, seconds: 20),
                    ),
                  );
            },
          ),
        ],
      ),
    );
  }
}

/// Horizontal shelf of the owner's published clips & reels (Phase 18).
class _OwnerReelsShelf extends ConsumerWidget {
  const _OwnerReelsShelf();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clips = ref.watch(creatorClipsFamilyProvider('creator_me'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.movie_filter_rounded,
              color: AppColors.brandPrimary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'My Clips & Reels',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${clips.length}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (clips.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.cardBorder,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Text(
              'Publish a reel from the Content Studio to feature it here.',
              style: AppTypography.bodyMuted,
            ),
          )
        else
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: clips.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final clip = clips[i];
                return SizedBox(
                  width: 96,
                  child: CreatorReelThumbnailCard(
                    clip: clip,
                    onTap: () => KineticReelsModal.show(
                      context,
                      clips: clips,
                      initialClipId: clip.id,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
