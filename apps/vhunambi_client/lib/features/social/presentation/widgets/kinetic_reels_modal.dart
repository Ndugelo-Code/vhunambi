import '../../../../core/constants/app_assets.dart';
import '../../../player/domain/models/stem_mixer_state.dart';
import '../../../player/presentation/providers/stem_mixer_provider.dart';
import 'dart:async';
import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../../core/navigation/profile_navigation_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../../../core/widgets/vhunambi_track_artwork.dart';
import '../../domain/models/kinetic_reaction.dart';
import '../../domain/models/published_clip.dart';
import '../../domain/models/sovereign_sticker_pack.dart';
import '../providers/reel_audio_pool_provider.dart';
import '../providers/social_feed_provider.dart';
import '../providers/stem_remix_provider.dart';
import '../../../content_studio/presentation/providers/master_media_object_provider.dart';
import '../../../content_studio/presentation/widgets/kinetic_preview_canvas.dart';
import '../../../studio/presentation/providers/melody_sketchpad_provider.dart';
import '../../../studio/presentation/providers/studio_form_provider.dart';
import '../../../studio/presentation/providers/vocal_identity_provider.dart';
import 'reaction_tray_overlay.dart';
import 'reels_comment_sheet.dart';
import 'creator_tipping_sheet.dart';
import 'open_verse_remix_cockpit_sheet.dart';
import 'remix_lineage_tree_sheet.dart';
import 'remix_attribution_badge.dart';
import '../../../studio/domain/services/bantu_lyric_translation_service.dart';
import '../../../explore/domain/models/explore_models.dart';
import '../../../explore/presentation/providers/explore_providers.dart';
import '../../../explore/presentation/views/explore_search_view.dart';
import '../../../notifications/domain/models/notification_entity.dart';
import '../../../notifications/domain/models/notification_enums.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';

/// Full-screen vertical "Kinetic Reels" feed (REQ-SOC-11, REQ-SOC-26, Phase A).
///
/// Zero-video: each page renders the clip's Song DNA via the 60 FPS
/// [KineticPreviewCanvas] synchronized with the 3-slot recycled
/// [ReelAudioPoolNotifier] (`Index - 1` pre-buffered, `Index` playing,
/// `Index + 1` pre-loaded) and Phase 23 MMO modulation curves.
class KineticReelsModal extends ConsumerStatefulWidget {
  final List<PublishedClip> clips;
  final int initialIndex;

  const KineticReelsModal({
    super.key,
    required this.clips,
    this.initialIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required List<PublishedClip> clips,
    String? initialClipId,
  }) {
    var idx = 0;
    if (initialClipId != null) {
      final found = clips.indexWhere((c) => c.id == initialClipId);
      if (found >= 0) idx = found;
    }
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => KineticReelsModal(clips: clips, initialIndex: idx),
      ),
    );
  }

  @override
  ConsumerState<KineticReelsModal> createState() => _KineticReelsModalState();
}

class _KineticReelsModalState extends ConsumerState<KineticReelsModal> {
  late final PageController _pageController;
  late int _currentIndex;
  ReelAudioPoolNotifier? _poolNotifier;
  StateController<int>? _overlayCountController;
  bool _incrementedOverlay = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _overlayCountController = ref.read(
        pushedFullScreenOverlayCountProvider.notifier,
      );
      _overlayCountController!.state++;
      _incrementedOverlay = true;
      if (widget.clips.isEmpty) return;
      _poolNotifier = ref.read(reelAudioPoolProvider.notifier);
      unawaited(
        _poolNotifier!.enterReelsSession(
          widget.clips,
          initialIndex: widget.initialIndex,
        ),
      );
    });
  }

  @override
  void dispose() {
    ReactionTrayOverlay.dismiss();
    if (_incrementedOverlay && _overlayCountController != null) {
      final ctrl = _overlayCountController!;
      _incrementedOverlay = false;
      Future<void>.microtask(() {
        if (ctrl.mounted && ctrl.state > 0) {
          ctrl.state = (ctrl.state - 1).clamp(0, 99);
        }
      });
    }
    final notifier = _poolNotifier;
    if (notifier != null) {
      unawaited(notifier.exitReelsSession());
    }
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    setState(() => _currentIndex = i);
    unawaited(
      ref.read(reelAudioPoolProvider.notifier).onPageChanged(i, widget.clips),
    );
  }

  void _share(PublishedClip clip) {
    Clipboard.setData(ClipboardData(text: clip.shareUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Share link copied: ${clip.shareUrl}'),
        backgroundColor: AppColors.brandPrimary,
      ),
    );
  }

  List<PublishedClip> _resolveClipsForTab(
    ReelFeedTab tab,
    Set<String> followingIds,
  ) {
    final source = widget.clips;
    switch (tab) {
      case ReelFeedTab.trending:
        return [...source]..sort((a, b) => b.likeCount.compareTo(a.likeCount));
      case ReelFeedTab.forYou:
        return source;
      case ReelFeedTab.following:
        final filtered = source
            .where((c) => followingIds.contains(c.creatorId))
            .toList();
        return filtered.isNotEmpty ? filtered : source;
      case ReelFeedTab.newest:
        return [...source]
          ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    }
  }

  void _handleTabSelected(ReelFeedTab tab) {
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    final followingIds = ref.read(followingCreatorIdsProvider);
    final nextClips = _resolveClipsForTab(tab, followingIds);
    _onPageChanged(0);
    if (nextClips.isNotEmpty) {
      unawaited(
        ref.read(reelAudioPoolProvider.notifier).onPageChanged(0, nextClips),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(activeReelTabProvider);
    final followingIds = ref.watch(followingCreatorIdsProvider);
    final displayClips = _resolveClipsForTab(activeTab, followingIds);

    if (displayClips.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.surfaceCanvas,
        body: Center(child: Text('No clips to show yet')),
      );
    }
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          onPageChanged: (i) {
            _onPageChanged(i);
            unawaited(
              ref
                  .read(reelAudioPoolProvider.notifier)
                  .onPageChanged(i, displayClips),
            );
          },
          itemCount: displayClips.length,
          itemBuilder: (context, i) {
            final clip = displayClips[i];
            return _ReelPage(
              clip: clip,
              isActive: i == _currentIndex,
              onShare: () => _share(clip),
              onSelectTab: _handleTabSelected,
            );
          },
        ),
      ),
    );
  }
}

class _ReelPage extends ConsumerStatefulWidget {
  final PublishedClip clip;
  final bool isActive;
  final VoidCallback onShare;
  final void Function(ReelFeedTab)? onSelectTab;

  const _ReelPage({
    required this.clip,
    required this.isActive,
    required this.onShare,
    this.onSelectTab,
  });

  @override
  ConsumerState<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends ConsumerState<_ReelPage>
    with SingleTickerProviderStateMixin {
  bool _localPlayingFallback = true;
  late final AnimationController _heartAnimController;
  late final Animation<double> _heartScale;
  late final Animation<double> _heartOpacity;
  bool _showBurstHeart = false;
  KineticReactionType _burstReaction = KineticReactionType.love;

  @override
  void initState() {
    super.initState();
    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.2,
          end: 1.35,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.35,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_heartAnimController);

    _heartOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 45),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_heartAnimController);

    _heartAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) setState(() => _showBurstHeart = false);
      }
    });
  }

  @override
  void dispose() {
    _heartAnimController.dispose();
    super.dispose();
  }

  void _triggerBurst({
    KineticReactionType reaction = KineticReactionType.love,
  }) {
    HapticFeedback.mediumImpact();
    setState(() {
      _showBurstHeart = true;
      _burstReaction = reaction;
    });
    _heartAnimController.forward(from: 0.0);
  }

  void _handleDoubleTap(PublishedClip clip) {
    _triggerBurst(reaction: KineticReactionType.love);
    final count = ref.read(socialFeedProvider.notifier).recordLove(clip.id);
    _emitReelLoveNotification(ref, clip, count);
  }

  void _togglePlay() {
    setState(() => _localPlayingFallback = !_localPlayingFallback);
    unawaited(ref.read(reelAudioPoolProvider.notifier).togglePlayPause());
  }

  void _remixInStudio(PublishedClip clip) {
    HapticFeedback.mediumImpact();
    ref.read(stemRemixProvider.notifier).initiateRemix(clip);
    ref.read(studioFormProvider.notifier).setGenre(clip.genre);
    ref
        .read(studioFormProvider.notifier)
        .updatePrompt(
          'Remix inspired by ${clip.title} by @${clip.creatorUsername}',
        );
    ref
        .read(melodySketchpadProvider.notifier)
        .initializeFromRemixDna(
          musicalKey: clip.dna.musical.key,
          bpm: clip.dna.musical.bpm,
          genre: clip.genre,
        );
    ref
        .read(vocalIdentityProvider.notifier)
        .initializeFromRemixDna(
          deliveryMode: clip.dna.vocals.deliveryMode,
          genre: clip.genre,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded sound into Studio: ${clip.title}'),
        backgroundColor: AppColors.brandPrimary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2500),
      ),
    );
  }

  Widget _buildVisionAnimatedStage(
    PublishedClip clip,
    FrameModulationSnapshot snapshot,
  ) {
    final bassPulse = (snapshot.effectiveBassEnergy * 0.4).clamp(0.0, 0.6);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Ambient Heritage Crate Texture at 24% opacity (REQ-P46-REEL-02)
        Opacity(
          opacity: 0.24,
          child: Image.asset(
            AppAssets.heritageCrateCover,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
        // Bass-Reactive Radial Pulse Ring (REQ-P46-REEL-03)
        Center(
          child: Container(
            width: 260 + (bassPulse * 160),
            height: 260 + (bassPulse * 160),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.brandPrimary.withValues(
                    alpha: 0.18 + (bassPulse * 0.25),
                  ),
                  AppColors.badgeCyan.withValues(
                    alpha: 0.08 + (bassPulse * 0.15),
                  ),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        // Subtle Cinema Vignette Edge Gradient
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.15,
              colors: [Colors.transparent, Colors.black54],
              stops: [0.65, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reactively resolve the live clip so like counts update instantly.
    final clip = ref
        .watch(socialFeedProvider)
        .clips
        .firstWhere((c) => c.id == widget.clip.id, orElse: () => widget.clip);

    final poolState = ref.watch(reelAudioPoolProvider);
    final isCurrentClipInPool = poolState.activeClipId == clip.id;
    final isPlaying = widget.isActive
        ? (isCurrentClipInPool ? poolState.isPlaying : _localPlayingFallback)
        : false;
    final playbackPos = (widget.isActive && isCurrentClipInPool)
        ? poolState.playbackPositionSec
        : 0.0;
    final cycleDuration = poolState.cycleDurationSec > 0
        ? poolState.cycleDurationSec
        : 15.0;

    final modulationSnapshot = ref.watch(
      frameModulationSnapshotProvider((
        dna: clip.dna,
        positionMs: (playbackPos * 1000).round(),
      )),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Genre Backdrop Gradient
        Container(
          decoration: BoxDecoration(
            gradient: AppGradients.forGenre(clip.genre),
          ),
        ),

        // 1.5. Vhunambi Vision Animated Stage (REQ-P46-REEL-01..03) OR Native Video Backing Layer
        if ((clip.videoUrl != null && clip.videoUrl!.isNotEmpty) ||
            (clip.localVideoPath != null && clip.localVideoPath!.isNotEmpty))
          _ReelVideoBackingLayer(
            key: Key('reel_video_backing_layer_${clip.id}'),
            videoUrl: clip.videoUrl ?? '',
            localVideoPath: clip.localVideoPath,
            isActive: widget.isActive && isPlaying,
            fallbackArtwork: VhunambiTrackArtwork(
              coverUrl: clip.coverUrl.isNotEmpty ? clip.coverUrl : null,
              genre: clip.genre,
              trackId: clip.trackId,
              borderRadius: BorderRadius.zero,
              showSubtleBorder: false,
            ),
          )
        else
          _buildVisionAnimatedStage(clip, modulationSnapshot),

        // 2. Live 60 FPS KineticPreviewCanvas (Karaoke Lyrics, Shaders & Waveform)
        KineticPreviewCanvas(
          key: ValueKey('reel_kinetic_canvas_${clip.id}'),
          coverArtUrl: clip.coverUrl.isNotEmpty ? clip.coverUrl : null,
          genre: clip.genre,
          trackId: clip.trackId,
          transparentBackground:
              (clip.videoUrl != null && clip.videoUrl!.isNotEmpty) ||
              (clip.localVideoPath != null && clip.localVideoPath!.isNotEmpty),
          words: clip.effectiveLyrics,
          preset: clip.effectiveTypographyPreset,
          effects: clip.effectiveAtmosphericEffects,
          playbackPositionSec: playbackPos,
          isPlaying: isPlaying,
          modulationSnapshot: modulationSnapshot,
          fullScreen: true,
          showInternalPlayOverlay: false,
        ),

        if (SovereignStickerPack.findById(clip.stickerId) != null)
          Positioned(
            top: 108,
            right: 16,
            child: IgnorePointer(
              child: SovereignStickerGraphic(
                key: Key('reel_canvas_sticker_${clip.id}'),
                sticker: SovereignStickerPack.findById(clip.stickerId)!,
                width: 96,
                height: 74,
              ),
            ),
          ),

        // 3. Bottom Readability Scrim
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black87],
              stops: [0.45, 1.0],
            ),
          ),
        ),

        // 4. Single-Tap Play/Pause & Double-Tap Love Burst Hit Zone
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePlay,
          onDoubleTap: () => _handleDoubleTap(clip),
          child: Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isPlaying ? 0.0 : 1.0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCanvas,
                  shape: BoxShape.circle,
                ),
                child: const PhosphorIcon(
                  AppIcons.play,
                  color: AppColors.brandPrimary,
                  size: 44,
                ),
              ),
            ),
          ),
        ),

        // 5. Top Progress Scrubber & Live Song DNA Telemetry Header
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  key: ValueKey('reel_progress_${clip.id}'),
                  value: (playbackPos / cycleDuration).clamp(0.0, 1.0),
                  minHeight: 2.5,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.brandPrimary,
                  ),
                ),
                Container(
                  key: const Key('reels_modal_top_bar'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                  ),
                  child: Row(
                    children: [
                      if (Navigator.of(context).canPop())
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: IconButton(
                            key: const Key('reel_close_btn'),
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const PhosphorIcon(
                              AppIcons.arrowLeft,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      const Spacer(),
                      _ReelTopFilterTab(
                        tab: ReelFeedTab.trending,
                        label: 'Trending',
                        key: const Key('reels_modal_tab_trending'),
                        onSelect: widget.onSelectTab,
                      ),
                      _ReelTopFilterTab(
                        tab: ReelFeedTab.forYou,
                        label: 'For You',
                        key: const Key('reels_modal_tab_for_you'),
                        onSelect: widget.onSelectTab,
                      ),
                      _ReelTopFilterTab(
                        tab: ReelFeedTab.following,
                        label: 'Following',
                        key: const Key('reels_modal_tab_following'),
                        onSelect: widget.onSelectTab,
                      ),
                      _ReelTopFilterTab(
                        tab: ReelFeedTab.newest,
                        label: 'Newest',
                        key: const Key('reels_modal_tab_newest'),
                        onSelect: widget.onSelectTab,
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          key: const Key('reels_modal_search_btn'),
                          icon: const PhosphorIcon(
                            AppIcons.search,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ExploreSearchView(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      const Spacer(),
                      Container(
                        key: const Key('reel_dna_badge'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceModal.withAlpha(200),
                          borderRadius: AppRadius.pillBorder,
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PhosphorIcon(
                              isPlaying
                                  ? AppIcons.waveform
                                  : AppIcons.pauseOutline,
                              size: 14,
                              color: AppColors.brandPrimary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${clip.genre.toUpperCase()} • ${clip.dna.musical.bpm} BPM • ${clip.dna.musical.key}',
                              style: AppTypography.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // 5.5 Split-Screen Open-Verse Duet Header (REQ-P46-REEL-04..06)
                if (clip.isRemix ||
                    clip.parentCreatorHandle != null ||
                    clip.remixGenerationDepth > 0)
                  ReelDuetSplitStage(
                    clip: clip,
                    pulseScale: (modulationSnapshot.effectiveBassEnergy * 0.5)
                        .clamp(0.0, 1.0),
                  ),
              ],
            ),
          ),
        ),

        // 6. Multi-Tap Floating Vector Reaction Burst (STD-UIUX-001)
        if (_showBurstHeart)
          IgnorePointer(
            child: Center(
              child: AnimatedBuilder(
                animation: _heartAnimController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _heartOpacity.value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: _heartScale.value,
                      child: _burstReaction == KineticReactionType.love
                          ? const PhosphorIcon(
                              AppIcons.heart,
                              color: AppColors.brandPrimary,
                              size: 110,
                            )
                          : KineticReactionBadge(
                              type: _burstReaction,
                              size: 78,
                            ),
                    ),
                  );
                },
              ),
            ),
          ),

        // 7. Right Social Action Rail
        Positioned(
          right: 12,
          bottom: 120,
          child: _ActionRail(
            clip: clip,
            onShare: widget.onShare,
            onBurst: (reaction) => _triggerBurst(reaction: reaction),
          ),
        ),

        // 8. Creator Identity, Remix Lineage, Caption & Sound Pill
        Positioned(
          left: 16,
          right: 76,
          bottom: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // On-Reel Interactive 4-Stem Toggle Bar (REQ-P46-REEL-07..10)
              const ReelStemToggleBar(),
              const SizedBox(height: 10),

              GestureDetector(
                key: ValueKey('reels_modal_creator_link_${clip.id}'),
                onTap: () {
                  navigateToCreatorProfile(
                    context,
                    ref,
                    creatorId: clip.creatorId,
                    creatorHandle: clip.creatorUsername,
                  );
                },
                child: Row(
                  children: [
                    Text(
                      '@${clip.creatorUsername}',
                      style: AppTypography.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (clip.isCreatorVerified) ...[
                      const SizedBox(width: 4),
                      const PhosphorIcon(
                        AppIcons.verified,
                        color: AppColors.brandPrimary,
                        size: 16,
                      ),
                    ],
                  ],
                ),
              ),
              if (clip.isRemix) ...[
                const SizedBox(height: 6),
                RemixAttributionBadge(clip: clip),
              ],
              const SizedBox(height: 6),
              if (clip.caption.isNotEmpty)
                Text(
                  clip.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall,
                ),
              const SizedBox(height: 10),
              _SoundPill(
                title: clip.title,
                artist: clip.creatorDisplayName,
                onRemix: () => _remixInStudio(clip),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionRail extends StatefulWidget {
  final PublishedClip clip;
  final VoidCallback onShare;
  final ValueChanged<KineticReactionType> onBurst;

  const _ActionRail({
    required this.clip,
    required this.onShare,
    required this.onBurst,
  });

  @override
  State<_ActionRail> createState() => _ActionRailState();
}

class _ActionRailState extends State<_ActionRail> {
  bool _translateActive = false;
  int _ephemeralLoveCount = 0;
  bool _showLovePill = false;
  Timer? _lovePillTimer;

  @override
  void dispose() {
    _lovePillTimer?.cancel();
    super.dispose();
  }

  void _showTranslationSheet(BuildContext context, PublishedClip clip) {
    final String rawLyrics;
    if (clip.dna.alignment.isNotEmpty) {
      final buffer = StringBuffer();
      int currentStanza = clip.dna.alignment.first.stanzaIndex;
      for (final word in clip.dna.alignment) {
        if (word.stanzaIndex != currentStanza) {
          buffer.write('\n');
          currentStanza = word.stanzaIndex;
        } else if (buffer.isNotEmpty) {
          buffer.write(' ');
        }
        buffer.write(word.word);
      }
      rawLyrics = buffer.toString();
    } else {
      rawLyrics = clip.caption;
    }

    final lines = BantuLyricTranslationService.processLyrics(
      lyricsText: rawLyrics,
      baseLanguageCode: clip.dna.language,
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceModal,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.modalBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PhosphorIcon(
                    PhosphorIcons.translate(PhosphorIconsStyle.regular),
                    size: 18,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Bantu Sing-Along & Meaning',
                    style: AppTypography.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: PhosphorIcon(
                      AppIcons.close,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: lines.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          'No lyrics available to translate',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: lines.length,
                        separatorBuilder: (_, _) => const Divider(height: 12),
                        itemBuilder: (_, i) {
                          final item = lines[i];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.originalLine,
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              BantuLyricTranslationService.buildStyledPhoneticGuide(
                                item.phoneticSingAlongGuide,
                                baseStyle: AppTypography.caption.copyWith(
                                  color: AppColors.brandPrimary.withAlpha(200),
                                ),
                                accentColor: AppColors.brandPrimary,
                              ),
                              if (item.hasMeaning)
                                Text(
                                  item.translatedMeaning,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              if (item.cognateMatches.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.brandPrimary.withAlpha(
                                        20,
                                      ),
                                      borderRadius: AppRadius.pillBorder,
                                      border: Border.all(
                                        color: AppColors.brandPrimary.withAlpha(
                                          50,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'Cognate: ${item.cognateMatches.first.target.displayName} (${item.cognateMatches.first.score}%) • indicative',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.brandPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _recordLove(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    widget.onBurst(KineticReactionType.love);
    final count = ref
        .read(socialFeedProvider.notifier)
        .recordLove(widget.clip.id);
    _emitReelLoveNotification(ref, widget.clip, count);
    if (!mounted) return;
    setState(() {
      _ephemeralLoveCount = count;
      _showLovePill = true;
    });
    _lovePillTimer?.cancel();
    _lovePillTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _showLovePill = false);
      }
    });
  }

  void _handleMultiReactionSelect(WidgetRef ref, KineticReactionType reaction) {
    widget.onBurst(reaction);
    unawaited(
      ref
          .read(socialFeedProvider.notifier)
          .reactToClip(widget.clip.id, reaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final clip = widget.clip;
        final myReaction = clip.myReaction;
        final showCustomReactionBadge =
            myReaction != null && myReaction != KineticReactionType.love;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showLovePill) ...[
              VhunambiGlassSurface(
                key: const Key('reel_ephemeral_love_pill'),
                variant: VhunambiGlassVariant.pill,
                enableLiveBlur: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                borderColorOverride: AppColors.brandPrimary.withValues(
                  alpha: 0.65,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PhosphorIcon(
                      AppIcons.heart,
                      size: 12,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Loved ${_ephemeralLoveCount}x',
                      style: AppTypography.badge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            GestureDetector(
              onLongPressStart: (details) {
                ReactionTrayOverlay.show(
                  context: context,
                  anchorGlobalPosition: details.globalPosition,
                  activeReaction: clip.myReaction,
                  onSelected: (rx) => _handleMultiReactionSelect(ref, rx),
                );
              },
              child: _RailButton(
                key: const Key('reel_like_btn'),
                icon: clip.isLikedByMe ? AppIcons.heart : AppIcons.heartOutline,
                customIconWidget: showCustomReactionBadge
                    ? KineticReactionBadge(type: myReaction, size: 30)
                    : null,
                color: clip.isLikedByMe ? AppColors.brandPrimary : Colors.white,
                label: formatLikes(clip.totalReactionCount),
                onTap: () => _recordLove(context, ref),
              ),
            ),
            const SizedBox(height: 18),
            _RailButton(
              key: const Key('reel_comment_btn'),
              icon: AppIcons.chat,
              color: Colors.white,
              label: '${clip.commentCount}',
              onTap: () {
                HapticFeedback.selectionClick();
                ReelsCommentSheet.show(context, clip: clip);
              },
            ),
            const SizedBox(height: 18),
            _RailButton(
              key: const Key('reel_tip_btn'),
              icon: AppIcons.coin,
              color: AppColors.coinGold,
              label: 'Tip',
              onTap: () {
                HapticFeedback.selectionClick();
                CreatorTippingSheet.show(context, clip: clip);
              },
            ),
            const SizedBox(height: 18),
            _RailButton(
              key: const Key('reel_share_btn'),
              icon: AppIcons.share,
              color: Colors.white,
              label: 'Share',
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onShare();
              },
            ),
            const SizedBox(height: 18),
            _RailButton(
              key: const Key('reel_translate_lyrics_toggle'),
              icon: PhosphorIcons.translate(PhosphorIconsStyle.regular),
              color: _translateActive ? AppColors.brandPrimary : Colors.white,
              label: 'Translate',
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _translateActive = !_translateActive);
                _showTranslationSheet(context, widget.clip);
              },
            ),
            const SizedBox(height: 18),
            _RailButton(
              key: const Key('reel_remix_tree_btn'),
              icon: PhosphorIconsRegular.gitFork,
              color: AppColors.brandPrimary,
              label: '${clip.remixCount}',
              onTap: () {
                HapticFeedback.selectionClick();
                RemixLineageTreeSheet.show(
                  context,
                  trackOrClipId: clip.id,
                  clip: clip,
                );
              },
            ),
            const SizedBox(height: 18),
            _RailButton(
              key: const Key('reel_remix_btn'),
              icon: AppIcons.remix,
              color: AppColors.badgeCyan,
              label: 'Remix',
              onTap: () {
                HapticFeedback.mediumImpact();
                OpenVerseRemixCockpitSheet.show(context, clip: clip);
              },
            ),
          ],
        );
      },
    );
  }
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final Widget? customIconWidget;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _RailButton({
    super.key,
    required this.icon,
    this.customIconWidget,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: const BoxDecoration(
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 4)],
              ),
              child:
                  customIconWidget ??
                  PhosphorIcon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoundPill extends StatelessWidget {
  final String title;
  final String artist;
  final VoidCallback? onRemix;
  const _SoundPill({required this.title, required this.artist, this.onRemix});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('reel_sound_pill'),
      onTap: onRemix,
      borderRadius: AppRadius.pillBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceModal.withAlpha(200),
          borderRadius: AppRadius.pillBorder,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PhosphorIcon(
              AppIcons.songs,
              size: 14,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '$title • $artist',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            const PhosphorIcon(
              AppIcons.disc,
              size: 14,
              color: AppColors.brandPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

String formatLikes(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return '$count';
}

class _ReelTopFilterTab extends ConsumerWidget {
  final ReelFeedTab tab;
  final String label;
  final void Function(ReelFeedTab)? onSelect;

  const _ReelTopFilterTab({
    super.key,
    required this.tab,
    required this.label,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(activeReelTabProvider);
    final isActive = activeTab == tab;

    return InkWell(
      onTap: () {
        ref.read(activeReelTabProvider.notifier).state = tab;
        onSelect?.call(tab);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: isActive ? Colors.white : Colors.white70,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                shadows: const <Shadow>[
                  Shadow(color: Colors.black87, blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Container(
              height: 2,
              width: 18,
              decoration: BoxDecoration(
                color: isActive ? AppColors.brandPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Split-Screen Open-Verse Duet Stage displaying Originator x Remixer (REQ-P46-REEL-04..06).
class ReelDuetSplitStage extends StatelessWidget {
  final PublishedClip clip;
  final double pulseScale;

  const ReelDuetSplitStage({
    super.key,
    required this.clip,
    this.pulseScale = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final parentHandle = clip.parentCreatorHandle ?? '@makhadzi';
    final remixerHandle = '@${clip.creatorUsername}';

    return Container(
      key: Key('reel_duet_split_stage_${clip.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // Originator Avatar & Handle
          Expanded(
            child: Row(
              children: [
                _buildPulsingAvatar(
                  label: parentHandle.replaceFirst('@', '').toUpperCase(),
                  borderColor: AppColors.brandPrimary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ORIGINATOR',
                        style: AppTypography.caption.copyWith(
                          fontSize: 9.0,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandPrimary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        parentHandle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Co-Creation Split Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceCanvas.withValues(alpha: 0.8),
              borderRadius: AppRadius.pillBorder,
              border: Border.all(color: AppColors.coinGold, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PhosphorIcon(
                  PhosphorIconsFill.handshake,
                  size: 12,
                  color: AppColors.coinGold,
                ),
                const SizedBox(width: 4),
                Text(
                  '70/30 Split',
                  style: AppTypography.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.coinGold,
                  ),
                ),
              ],
            ),
          ),

          // Remixer Avatar & Handle
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'CO-CREATOR',
                        style: AppTypography.caption.copyWith(
                          fontSize: 9.0,
                          fontWeight: FontWeight.bold,
                          color: AppColors.badgeCyan,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        remixerHandle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildPulsingAvatar(
                  label: remixerHandle.replaceFirst('@', '').toUpperCase(),
                  borderColor: AppColors.badgeCyan,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingAvatar({
    required String label,
    required Color borderColor,
  }) {
    final ringWidth = 2.0 + (pulseScale * 2.0);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: ringWidth),
        color: AppColors.surfaceElevated,
      ),
      child: Center(
        child: Text(
          label.isNotEmpty ? label[0] : '?',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// On-Reel Interactive 4-Stem Toggle Bar (REQ-P46-REEL-07..10).
class ReelStemToggleBar extends ConsumerWidget {
  const ReelStemToggleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mixerState = ref.watch(stemMixerProvider);

    return Container(
      key: const Key('reel_stem_toggle_bar'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPill(
            context,
            ref,
            mixerState,
            type: StemType.vocals,
            label: 'Vocals',
            icon: PhosphorIconsRegular.microphone,
            keyName: 'reel_stem_pill_vocals',
          ),
          _buildPill(
            context,
            ref,
            mixerState,
            type: StemType.bass,
            label: 'Log-Drum',
            icon: PhosphorIconsRegular.waveSine,
            keyName: 'reel_stem_pill_bass',
          ),
          _buildPill(
            context,
            ref,
            mixerState,
            type: StemType.drums,
            label: 'Drums',
            icon: PhosphorIconsRegular.disc,
            keyName: 'reel_stem_pill_drums',
          ),
          _buildPill(
            context,
            ref,
            mixerState,
            type: StemType.melody,
            label: 'Chords',
            icon: PhosphorIconsRegular.pianoKeys,
            keyName: 'reel_stem_pill_melodic',
          ),
        ],
      ),
    );
  }

  Widget _buildPill(
    BuildContext context,
    WidgetRef ref,
    StemMixerState state, {
    required StemType type,
    required String label,
    required PhosphorIconData icon,
    required String keyName,
  }) {
    final channel = state.channel(type);
    final isMuted = channel.isMuted;

    return Semantics(
      button: true,
      label: isMuted ? 'Unmute $label' : 'Mute $label',
      child: InkWell(
        key: Key(keyName),
        onTap: () {
          ref.read(stemMixerProvider.notifier).toggleMute(type);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 32, minWidth: 40),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isMuted
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.brandPrimary.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isMuted ? Colors.white24 : AppColors.brandPrimary,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(
                icon,
                size: 12,
                color: isMuted ? Colors.white54 : AppColors.brandPrimary,
              ),
              const SizedBox(width: 3),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: isMuted ? Colors.white54 : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _emitReelLoveNotification(WidgetRef ref, PublishedClip clip, int count) {
  if (count != 1 && count % 5 != 0) return;
  try {
    ref
        .read(notificationsProvider.notifier)
        .addNotification(
          NotificationEntity(
            id: 'notif_love_${clip.id}_$count',
            title: 'Loved ${clip.creatorUsername}\'s Reel ($count×)',
            message: 'You sent $count× love reactions on "${clip.title}".',
            category: NotificationCategory.social,
            priority: NotificationPriority.normal,
            subtype: 'reel_love',
            targetRoute: '/reel/${clip.id}',
            targetEntityId: clip.id,
            ctaLabel: 'Watch Kinetic Reel',
            createdAt: DateTime.now(),
          ),
        );
  } catch (_) {}
}

class _ReelVideoBackingLayer extends StatefulWidget {
  final String videoUrl;
  final String? localVideoPath;
  final bool isActive;
  final Widget fallbackArtwork;

  const _ReelVideoBackingLayer({
    super.key,
    required this.videoUrl,
    this.localVideoPath,
    required this.isActive,
    required this.fallbackArtwork,
  });

  @override
  State<_ReelVideoBackingLayer> createState() => _ReelVideoBackingLayerState();
}

class _ReelVideoBackingLayerState extends State<_ReelVideoBackingLayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  static bool get _isTestEnv {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  void initState() {
    super.initState();
    _initControllerIfAllowed();
  }

  Future<void> _initControllerIfAllowed() async {
    if (_isTestEnv || kIsWeb) return;
    VideoPlayerController? ctrl;
    try {
      final localPath = widget.localVideoPath;
      if (localPath != null &&
          localPath.trim().isNotEmpty &&
          File(localPath).existsSync()) {
        ctrl = VideoPlayerController.file(File(localPath));
      } else {
        final uri = Uri.tryParse(widget.videoUrl);
        if (uri != null &&
            uri.hasScheme &&
            (uri.scheme == 'http' || uri.scheme == 'https')) {
          ctrl = VideoPlayerController.networkUrl(uri);
        }
      }
      if (ctrl == null) return;
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(0.0);
      if (widget.isActive) {
        await ctrl.play();
      }
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _controller = ctrl;
        _initialized = true;
      });
    } catch (_) {
      await ctrl?.dispose();
    }
  }

  @override
  void didUpdateWidget(covariant _ReelVideoBackingLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ctrl = _controller;
    if (ctrl == null || !_initialized) return;
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        unawaited(ctrl.play());
      } else {
        unawaited(ctrl.pause());
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialized && _controller != null) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller!.value.size.width > 0
                ? _controller!.value.size.width
                : 720,
            height: _controller!.value.size.height > 0
                ? _controller!.value.size.height
                : 1280,
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    }
    return widget.fallbackArtwork;
  }
}
