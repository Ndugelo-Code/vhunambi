import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/creator_id_utils.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/widgets/vhunambi_ambient_mesh_backdrop.dart';
import '../../../../core/widgets/vhunambi_bottom_dock_kit.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../../../core/widgets/vhunambi_top_bar_kit.dart';
import '../../../../core/widgets/vhunambi_track_artwork.dart';
import '../../../creator_dna/presentation/widgets/creator_dna_profile_card.dart';
import '../../../explore/domain/models/social_music_post.dart';
import '../../../explore/presentation/providers/explore_providers.dart';
import '../../../explore/presentation/views/kinetic_post_focus_view.dart';
import '../../../home/presentation/providers/cross_module_synergy_provider.dart';
import '../../../home/presentation/widgets/cross_module_synergy_deck.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../social/domain/models/published_clip.dart';
import '../../../social/presentation/providers/creator_clips_provider.dart';
import '../../../social/presentation/widgets/creator_reel_thumbnail_card.dart';
import '../../../social/presentation/widgets/kinetic_reels_modal.dart';
import '../../../studio/presentation/providers/melody_sketchpad_provider.dart';
import '../../../studio/presentation/widgets/direct_daw_vocal_upload_sheet.dart';
import '../../../studio/presentation/widgets/melody_sketchpad_modal.dart';
import '../../../track/presentation/views/track_detail_view.dart';
import '../../domain/models/profile_models.dart';
import '../../domain/models/profile_operation_state.dart';
import '../../domain/models/profile_operation_type.dart';
import '../providers/profile_providers.dart';
import '../providers/synchronized_analytics_provider.dart';
import '../widgets/artist_voice_showcase_card.dart';
import '../widgets/avatar_customization_modal.dart';
import '../widgets/creator_avatar.dart';
import '../widgets/creator_wallet_deck.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/error/error_boundary.dart';
import '../widgets/loading/loading_overlay.dart';
import '../widgets/loading/profile_skeleton_screen.dart';
import '../widgets/offline/offline_indicator.dart';
import '../widgets/owner_beatstore_cockpit.dart';
import '../widgets/pin_song_selector_sheet.dart';
import '../widgets/pinned_spotlight_card.dart';
import '../widgets/profile_referral_card.dart';
import '../widgets/profile_settings_drawer.dart';
import '../widgets/releases_manager_card.dart';
import '../widgets/studio_analytics_console_sheet.dart';
import '../widgets/tip_history_ledger.dart';

/// Account Owner Creator Studio Profile View (`/profile/me`) (REQ-TRK-15, REQ-TRK-16, REQ-P72-OP-01..07).
class OwnerProfileView extends ConsumerStatefulWidget {
  const OwnerProfileView({super.key});

  @override
  ConsumerState<OwnerProfileView> createState() => _OwnerProfileViewState();
}

class _OwnerProfileViewState extends ConsumerState<OwnerProfileView> {
  OwnerStudioTab _activeTab = OwnerStudioTab.songs;
  StateController<int>? _pushedOverlayCounter;
  bool _didIncrementPushedOverlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final counter = ref.read(pushedFullScreenOverlayCountProvider.notifier);
      _pushedOverlayCounter = counter;
      _didIncrementPushedOverlay = true;
      counter.state++;
    });
  }

  @override
  void dispose() {
    final counter = _pushedOverlayCounter;
    if (_didIncrementPushedOverlay && counter != null) {
      _didIncrementPushedOverlay = false;
      Future<void>.microtask(() {
        if (counter.mounted && counter.state > 0) {
          counter.state = (counter.state - 1).clamp(0, 99);
        }
      });
    }
    super.dispose();
  }

  void _showNewReleaseDialog() {
    final titleController = TextEditingController();
    ReleaseType selectedType = ReleaseType.single;
    String selectedGenre = 'House';

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceModalOf(dialogContext),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.cardBorder,
                side: BorderSide(
                  color: AppColors.borderSubtleOf(dialogContext),
                ),
              ),
              title: Text(
                'Create New Release',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textPrimaryOf(dialogContext),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimaryOf(dialogContext),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Release Title',
                      labelStyle: TextStyle(
                        color: AppColors.textSecondaryOf(dialogContext),
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.borderSubtleOf(dialogContext),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Release Type',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryOf(dialogContext),
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
                          backgroundColor: AppColors.surfaceElevatedOf(
                            dialogContext,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.brandPrimary
                                : AppColors.borderSubtleOf(dialogContext),
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.brandContrast
                                : AppColors.textPrimaryOf(dialogContext),
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
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.textSecondaryOf(dialogContext),
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                    shape: const RoundedRectangleBorder(
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
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Release "$title" created!')),
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

  List<LibraryTrack> _resolveOwnerSongs(
    List<LibraryTrack> allTracks,
    String rawCreatorId,
    ArtistProfileEntity profile,
  ) {
    final canonicalOwner = canonicalizeCreatorId(rawCreatorId);
    final profileName = profile.displayName.trim().toLowerCase();
    return allTracks
        .where((t) {
          if (t.isDeleted || t.isInstrumental) return false;
          final trackCreator = canonicalizeCreatorId(t.creatorId);
          if (trackCreator == canonicalOwner) return true;
          if ((canonicalOwner == 'creator_guest' ||
                  canonicalOwner == 'creator_me') &&
              trackCreator == 'creator_cern') {
            return true;
          }
          final normalizedName = t.creatorName.trim().toLowerCase();
          if (normalizedName == profileName || normalizedName == 'ai studio') {
            return true;
          }
          return false;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final profile = ref.watch(ownerProfileProvider);
    final opState = ref.watch(ownerProfileOperationProvider);
    final syncAnalytics = ref.watch(synchronizedAnalyticsProvider);
    final allLibraryTracks = ref.watch(libraryTracksProvider);
    final rawCreatorId = ref.watch(currentCreatorIdProvider);
    final ownerSongs = _resolveOwnerSongs(
      allLibraryTracks,
      rawCreatorId,
      profile,
    );
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
        backgroundColor: AppColors.surfaceCanvasOf(context),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const VhunambiBackButton(),
        ),
        body: VhunambiAmbientMeshBackdrop(
          child: ErrorBoundary(
            message: fetchError.message,
            onRetry: () =>
                ref.read(ownerProfileOperationProvider.notifier).fetchProfile(),
          ),
        ),
      );
    }

    final isMutating =
        opState.isLoading(ProfileOperationType.createRelease) ||
        opState.isLoading(ProfileOperationType.avatarUpdate) ||
        opState.isLoading(ProfileOperationType.visibilityToggle);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvasOf(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const VhunambiBackButton(),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PhosphorIcon(
                AppIcons.studio,
                color: AppColors.brandPrimary,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'CREATOR STUDIO',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textPrimaryOf(context),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: IconButton(
              key: const Key('owner_header_settings_btn'),
              icon: PhosphorIcon(
                AppIcons.settings,
                color: AppColors.textPrimaryOf(context),
                size: 20,
              ),
              tooltip: 'Studio Settings',
              onPressed: () => ProfileSettingsDrawer.show(context),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: VhunambiAmbientMeshBackdrop(
        child: LoadingOverlay(
          isLoading: isMutating,
          message: 'Updating studio...',
          child: RefreshIndicator(
            color: AppColors.brandPrimary,
            backgroundColor: AppColors.surfaceModalOf(context),
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
                        VhunambiGlassSurface(
                          variant: VhunambiGlassVariant.card,
                          enableLiveBlur: false,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            children: [
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
                                        color: AppColors.textPrimaryOf(context),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '@${profile.username} • Verified Creator',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondaryOf(
                                          context,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        Container(
                                          key: const Key(
                                            'creator_archetype_badge',
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceSecondaryOf(
                                              context,
                                            ),
                                            borderRadius: AppRadius.pillBorder,
                                            border: Border.all(
                                              color: AppColors.brandPrimary
                                                  .withValues(alpha: 0.4),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              PhosphorIcon(
                                                profile.archetype.icon,
                                                size: 12,
                                                color: AppColors.brandPrimary,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  profile.archetype.displayName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: AppTypography.caption
                                                      .copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 10.5,
                                                        color:
                                                            AppColors.textPrimaryOf(
                                                              context,
                                                            ),
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          key: const Key(
                                            'creator_monthly_listeners_pill',
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceSecondaryOf(
                                              context,
                                            ),
                                            borderRadius: AppRadius.pillBorder,
                                            border: Border.all(
                                              color: AppColors.borderSubtleOf(
                                                context,
                                              ),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const PhosphorIcon(
                                                PhosphorIconsRegular.headphones,
                                                size: 12,
                                                color: AppColors.badgeCyan,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${(profile.monthlyListenersCount / 1000).toStringAsFixed(1)}K Monthly',
                                                style: AppTypography.caption
                                                    .copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 10.5,
                                                      color:
                                                          AppColors.textPrimaryOf(
                                                            context,
                                                          ),
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 2. Management Action Strip
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildActionPill(
                              key: const Key('open_daw_vocal_uploader_btn'),
                              icon: PhosphorIconsRegular.uploadSimple,
                              label: 'DAW / Vocal Upload',
                              onTap: () {
                                DirectDawVocalUploadSheet.show(context);
                              },
                            ),
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
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildGenreChip(
                              context,
                              PhosphorIconsRegular.musicNotes,
                              'House',
                              '1',
                            ),
                            _buildGenreChip(
                              context,
                              PhosphorIconsRegular.pianoKeys,
                              'Amapiano',
                              '4',
                            ),
                            _buildGenreChip(
                              context,
                              PhosphorIconsRegular.guitar,
                              'Maskandi',
                              '2',
                            ),
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

                        // 3c. Creator DNA Profile Card
                        const CreatorDnaProfileCard(isOwner: true),

                        const SizedBox(height: 24),

                        // 4. Tri-Segment Studio Switcher
                        _buildStudioSegmentedSelector(context),

                        const SizedBox(height: 12),

                        if (_activeTab == OwnerStudioTab.songs) ...[
                          Row(
                            children: [
                              Text(
                                'Your Songs',
                                style: AppTypography.titleMedium.copyWith(
                                  color: AppColors.textPrimaryOf(context),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${ownerSongs.length} total',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondaryOf(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (ownerSongs.isEmpty)
                            VhunambiGlassSurface(
                              variant: VhunambiGlassVariant.card,
                              enableLiveBlur: false,
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Text(
                                'Create or publish a song in the Studio to see it here.',
                                style: AppTypography.bodyMuted.copyWith(
                                  color: AppColors.textSecondaryOf(context),
                                ),
                              ),
                            )
                          else
                            for (int i = 0; i < ownerSongs.length; i++) ...[
                              _buildOwnerTrackTile(
                                context: context,
                                track: ownerSongs[i],
                                rank: i + 1,
                              ),
                              if (i < ownerSongs.length - 1)
                                const SizedBox(height: 10),
                            ],
                          const SizedBox(height: 16),
                          const _OwnerKineticPostsShelf(),
                        ] else if (_activeTab == OwnerStudioTab.reels) ...[
                          const _OwnerReelsShelf(),
                        ] else if (_activeTab == OwnerStudioTab.beatstore) ...[
                          const OwnerBeatstoreCockpit(),
                        ] else if (_activeTab ==
                            OwnerStudioTab.voicesAndMelodies) ...[
                          _buildVoicesAndMelodiesTab(
                            context,
                            ref,
                            profile,
                            syncAnalytics,
                          ),
                        ] else if (_activeTab == OwnerStudioTab.releases) ...[
                          ReleasesManagerCard(
                            releases: profile.releases,
                            onNewRelease: _showNewReleaseDialog,
                          ),
                        ],

                        const SizedBox(height: 14),

                        // 4c. Creator Wallet, Monthly Allowance & Cultural Gifting
                        const CreatorWalletDeck(),

                        const SizedBox(height: 14),

                        // Studio Synergy Deck & Mastery Badges
                        const CrossModuleSynergyDeck(compact: true),

                        const SizedBox(height: 14),

                        const _CreatorMasteryBadgesSection(),

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
      ),
    );
  }

  Widget _buildStudioSegmentedSelector(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: VhunambiGlassSurface(
        variant: VhunambiGlassVariant.pill,
        enableLiveBlur: false,
        padding: const EdgeInsets.all(4),
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
                              : AppColors.textSecondaryOf(context),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tab.label,
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppColors.brandContrast
                                : AppColors.textSecondaryOf(context),
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
      child: VhunambiGlassSurface(
        variant: VhunambiGlassVariant.pill,
        enableLiveBlur: false,
        child: InkWell(
          key: key,
          onTap: onTap,
          borderRadius: AppRadius.pillBorder,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(icon, size: 16, color: AppColors.brandPrimary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
              ],
            ),
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
        ArtistVoiceShowcaseCard(
          artistName: profile.displayName,
          vocalArchetypeTitle: profile.vocalArchetypeTitle,
          vocalArchetypeLanguage: profile.vocalArchetypeLanguage,
          vocalSampleUrl: profile.vocalSampleUrl,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const PhosphorIcon(
                    AppIcons.studio,
                    color: AppColors.brandPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Multi-Track Grooves & Melodies',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondaryOf(context),
                borderRadius: AppRadius.pillBorder,
                border: Border.all(color: AppColors.borderSubtleOf(context)),
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
          VhunambiGlassSurface(
            variant: VhunambiGlassVariant.card,
            enableLiveBlur: false,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                PhosphorIcon(
                  AppIcons.soundPack,
                  size: 36,
                  color: AppColors.textSecondaryOf(context),
                ),
                const SizedBox(height: 12),
                Text(
                  'Compose African Grooves in the Sketchpad',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Build 5-channel harmonies combining log drums, nylon guitars, bowed violins, and brass riffs.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  key: const Key('owner_launch_sketchpad_btn'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                    minimumSize: const Size(0, 44),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                  icon: const PhosphorIcon(AppIcons.studio, size: 16),
                  label: const Text('Launch Sketchpad'),
                  onPressed: () => MelodySketchpadModal.show(context),
                ),
              ],
            ),
          ),
        ] else ...[
          ...sketchpad.savedPatterns.map((pattern) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VhunambiGlassSurface(
                variant: VhunambiGlassVariant.card,
                enableLiveBlur: false,
                padding: const EdgeInsets.all(12),
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
                      child: const PhosphorIcon(
                        AppIcons.soundPack,
                        color: AppColors.brandContrast,
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
                              color: AppColors.textPrimaryOf(context),
                            ),
                          ),
                          Text(
                            '${pattern.genre} • ${pattern.bpm} BPM • ${pattern.notes.length} notes',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      child: IconButton(
                        tooltip: 'Audition Groove',
                        icon: const PhosphorIcon(
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
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      child: IconButton(
                        tooltip: 'Open in Studio',
                        icon: PhosphorIcon(
                          AppIcons.edit,
                          color: AppColors.textSecondaryOf(context),
                          size: 18,
                        ),
                        onPressed: () {
                          ref
                              .read(melodySketchpadProvider.notifier)
                              .loadPattern(pattern);
                          MelodySketchpadModal.show(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildGenreChip(
    BuildContext context,
    IconData icon,
    String label,
    String count,
  ) {
    return VhunambiGlassSurface(
      variant: VhunambiGlassVariant.pill,
      enableLiveBlur: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(icon, size: 13, color: AppColors.brandPrimary),
          const SizedBox(width: 6),
          Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerTrackTile({
    required BuildContext context,
    required LibraryTrack track,
    required int rank,
  }) {
    final isPublic = track.isPublic;

    return VhunambiGlassSurface(
      key: Key('owner_song_tile_${track.id}'),
      variant: VhunambiGlassVariant.card,
      enableLiveBlur: false,
      child: InkWell(
        borderRadius: AppRadius.cardBorder,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TrackDetailView(trackId: track.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
              VhunambiTrackArtwork(
                coverUrl: track.coverImageUrl,
                genre: track.genre,
                trackId: track.id,
                width: 40,
                height: 40,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    Text(
                      '${track.genre} • ${track.formattedDuration} • ${track.playCount} plays',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Center(
                  child: InkWell(
                    key: Key('owner_song_visibility_${track.id}'),
                    onTap: () {
                      ref
                          .read(libraryTracksProvider.notifier)
                          .toggleTrackVisibility(track.id);
                    },
                    borderRadius: AppRadius.pillBorder,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isPublic
                            ? AppColors.success.withAlpha(24)
                            : AppColors.surfaceSecondaryOf(context),
                        borderRadius: AppRadius.pillBorder,
                        border: Border.all(
                          color: isPublic
                              ? AppColors.success
                              : AppColors.borderSubtleOf(context),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PhosphorIcon(
                            isPublic
                                ? PhosphorIconsRegular.globe
                                : PhosphorIconsRegular.lock,
                            size: 12,
                            color: isPublic
                                ? AppColors.success
                                : AppColors.textSecondaryOf(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPublic ? 'Public' : 'Private',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isPublic
                                  ? AppColors.success
                                  : AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: IconButton(
                  iconSize: 26,
                  tooltip: 'Play song',
                  icon: const PhosphorIcon(
                    PhosphorIconsFill.playCircle,
                    color: AppColors.brandPrimary,
                    size: 26,
                  ),
                  onPressed: () {
                    ref
                        .read(playerStateProvider.notifier)
                        .playTrack(track.toTrack());
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal shelf of the owner's Kinetic Posts linking into [KineticPostFocusView].
class _OwnerKineticPostsShelf extends ConsumerWidget {
  const _OwnerKineticPostsShelf();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allPosts = ref.watch(socialFeedPostsProvider);
    final rawCreatorId = ref.watch(currentCreatorIdProvider);
    final profile = ref.watch(ownerProfileProvider);
    final canonicalOwner = canonicalizeCreatorId(rawCreatorId);
    final ownerHandle = '@${profile.username.toLowerCase()}';
    final ownerName = profile.displayName.toLowerCase();

    final ownerPosts = allPosts
        .where((post) {
          final postCreator = canonicalizeCreatorId(post.creatorId);
          if (postCreator == canonicalOwner) return true;
          if ((canonicalOwner == 'creator_guest' ||
                  canonicalOwner == 'creator_me') &&
              (postCreator == 'creator_cern' ||
                  post.creatorId == 'creator_me')) {
            return true;
          }
          if (post.creatorHandle.toLowerCase() == ownerHandle ||
              post.creatorName.toLowerCase() == ownerName) {
            return true;
          }
          return false;
        })
        .toList(growable: false);

    return Column(
      key: const Key('owner_kinetic_posts_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const PhosphorIcon(
              PhosphorIconsRegular.sparkle,
              color: AppColors.brandPrimary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'My Kinetic Posts',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${ownerPosts.length}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (ownerPosts.isEmpty)
          VhunambiGlassSurface(
            variant: VhunambiGlassVariant.card,
            enableLiveBlur: false,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Share a Kinetic Post from Explore or Track Cockpit to feature it here.',
              style: AppTypography.bodyMuted.copyWith(
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          )
        else
          SizedBox(
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ownerPosts.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final SocialMusicPost post = ownerPosts[index];
                return SizedBox(
                  width: 240,
                  child: VhunambiGlassSurface(
                    key: Key('owner_kinetic_post_card_${post.id}'),
                    variant: VhunambiGlassVariant.card,
                    enableLiveBlur: false,
                    child: InkWell(
                      borderRadius: AppRadius.cardBorder,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => KineticPostFocusView(
                            postId: post.id,
                            initialPost: post,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Row(
                          children: [
                            VhunambiTrackArtwork(
                              coverUrl:
                                  post.imageAttachment?.imageUrl ??
                                  post.track.coverUrl,
                              genre: post.track.genre,
                              trackId: post.track.id.isNotEmpty
                                  ? post.track.id
                                  : post.id,
                              width: 56,
                              height: 56,
                              borderRadius: AppRadius.thumbBorder,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    post.track.title.isNotEmpty
                                        ? post.track.title
                                        : 'Kinetic Post',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textPrimaryOf(context),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    post.caption,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondaryOf(context),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${post.cosignCount} Co-Signs • ${post.commentCount} replies',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.brandPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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

/// Horizontal shelf of the owner's published clips & reels (Phase 18).
class _OwnerReelsShelf extends ConsumerWidget {
  const _OwnerReelsShelf();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canonicalOwner = canonicalizeCreatorId(
      ref.watch(currentCreatorIdProvider),
    );
    final primaryClips = ref.watch(creatorClipsFamilyProvider(canonicalOwner));
    final legacyClips = canonicalOwner == 'creator_me'
        ? const <PublishedClip>[]
        : ref.watch(creatorClipsFamilyProvider('creator_me'));
    final seenIds = <String>{};
    final clips = <PublishedClip>[
      for (final clip in [...primaryClips, ...legacyClips])
        if (seenIds.add(clip.id)) clip,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const PhosphorIcon(
              PhosphorIconsRegular.filmStrip,
              color: AppColors.brandPrimary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'My Clips & Reels',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${clips.length}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (clips.isEmpty)
          VhunambiGlassSurface(
            variant: VhunambiGlassVariant.card,
            enableLiveBlur: false,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Publish a reel from the Content Studio to feature it here.',
              style: AppTypography.bodyMuted.copyWith(
                color: AppColors.textSecondaryOf(context),
              ),
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

class _CreatorMasteryBadgesSection extends ConsumerWidget {
  const _CreatorMasteryBadgesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(creatorMasteryBadgesProvider);

    return VhunambiGlassSurface(
      variant: VhunambiGlassVariant.card,
      enableLiveBlur: false,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PhosphorIcon(
                PhosphorIconsRegular.medal,
                size: 16,
                color: AppColors.coinGold,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'CREATOR MASTERY BADGES',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: badges.map((badge) {
              final isUnlocked = badge.isUnlocked;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? AppColors.coinGold.withAlpha(20)
                      : AppColors.surfaceSecondaryOf(context),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(
                    color: isUnlocked
                        ? AppColors.coinGold.withAlpha(80)
                        : AppColors.borderSubtleOf(context),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(
                      isUnlocked
                          ? PhosphorIconsFill.checkCircle
                          : PhosphorIconsRegular.lock,
                      size: 14,
                      color: isUnlocked
                          ? AppColors.coinGold
                          : AppColors.textSecondaryOf(context),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      badge.name,
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isUnlocked
                            ? AppColors.textPrimaryOf(context)
                            : AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
