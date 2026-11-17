import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/design_system/services/haptics_service.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/utils/responsive_utils.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_bottom_dock_kit.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/home/domain/models/african_rhythm_matrix.dart';
import 'package:vhunambi_client/features/home/presentation/widgets/creation_launch_strip.dart';
import 'package:vhunambi_client/features/home/presentation/widgets/editorial_rhythm_spotlight_card.dart';
import 'package:vhunambi_client/features/home/presentation/widgets/horizontal_genre_track_shelf.dart';
import 'package:vhunambi_client/features/home/presentation/widgets/main_room_header.dart';
import 'package:vhunambi_client/features/home/presentation/widgets/now_playing_home_card.dart';
import 'package:vhunambi_client/features/home/presentation/widgets/telemetry_and_dna_banner.dart';
import 'package:vhunambi_client/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/melody_sketchpad_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_form_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/melody_sketchpad_modal.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/vocal_identity_picker_sheet.dart';

/// Phase 68: Vhunambi Home Dashboard ("Main Room & Studio Utility").
///
/// Organizes Home into 5 high-clarity, overflow-free zones across both Light
/// ("Morning Mist") and Dark ("Night") modes:
/// 1. [MainRoomHeader] — Avatar, multilingual greeting, theme toggle, Streak, `10/10` quota, Coins, Notifications
/// 1.5. [TelemetryAndDnaBanner] — Live AI pipeline telemetry OR slim Creator DNA strip
/// 2. [NowPlayingHomeCard] — Zania-inspired inline playback + Jump Back In deck (suppresses Tab-0 floating MiniPlayerHost)
/// 3. [HorizontalGenreTrackShelf] — Square artwork rail (`Trending in Your Genres`)
/// 4. [CreationLaunchStrip] — Compact direct Studio CTA + 4 non-duplicated creation utilities
/// 5. [EditorialRhythmSpotlightCard] — Dark-scrimmed artwork card for Daily Rhythm Spotlight
class HomeDashboardView extends ConsumerWidget {
  final VoidCallback? onNavigateToStudio;
  final VoidCallback? onNavigateToExplore;
  final VoidCallback? onNavigateToMarket;
  final VoidCallback? onNavigateToLibrary;
  final int? injectedWeekday;

  const HomeDashboardView({
    super.key,
    this.onNavigateToStudio,
    this.onNavigateToExplore,
    this.onNavigateToMarket,
    this.onNavigateToLibrary,
    this.injectedWeekday,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final horizontalPad = isDesktop ? 32.0 : 16.0;
    final onboardingState = ref.watch(onboardingStateProvider);
    final exploreTracks = ref.watch(exploreTracksProvider);
    final spotlight = AfricanRhythmMatrix.forWeekday(injectedWeekday);

    final userGenres = onboardingState.selectedGenres
        .map((g) => g.toLowerCase().trim())
        .toSet();
    final scopedTracks = userGenres.isEmpty
        ? exploreTracks
        : exploreTracks
            .where((t) => userGenres.contains(t.genre.toLowerCase().trim()))
            .toList();
    final displayedGenreTracks =
        scopedTracks.isNotEmpty ? scopedTracks : exploreTracks;

    void openVoiceClone() {
      FocusManager.instance.primaryFocus?.unfocus();
      HapticsService().lightImpact();
      VocalIdentityPickerSheet.show(context);
    }

    void openSketchpad() {
      FocusManager.instance.primaryFocus?.unfocus();
      HapticsService().lightImpact();
      MelodySketchpadModal.show(context);
    }

    void tryRhythmSpotlight() {
      FocusManager.instance.primaryFocus?.unfocus();
      HapticsService().mediumImpact();
      ref.read(studioFormProvider.notifier).setGenre(spotlight.genre);
      ref.read(studioFormProvider.notifier).updatePrompt(spotlight.samplePrompt);
      ref.read(melodySketchpadProvider.notifier).initializeFromRemixDna(
            genre: spotlight.genre,
            bpm: spotlight.bpm,
            musicalKey: spotlight.musicalKey,
          );
      onNavigateToStudio?.call();
    }

    // MiniPlayerHost is suppressed on Tab 0 when NowPlayingHomeCard is mounted.
    final bottomInset = isDesktop
        ? 32.0
        : VhunambiBottomDockMetrics.scrollInset(hasActiveTrack: false);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvasOf(context),
      body: SafeArea(
        child: CustomScrollView(
          key: const Key('home_main_room_scroll'),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: MainRoomHeader(isDesktop: isDesktop),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPad,
                6,
                horizontalPad,
                bottomInset,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TelemetryAndDnaBanner(
                      onNavigateToStudio: onNavigateToStudio,
                    ),
                    const SizedBox(height: 14),
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            flex: 7,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                NowPlayingHomeCard(
                                  onNavigateToStudio: onNavigateToStudio,
                                ),
                                const SizedBox(height: 18),
                                HorizontalGenreTrackShelf(
                                  tracks: displayedGenreTracks,
                                  selectedGenres:
                                      onboardingState.selectedGenres,
                                  onViewAll: onNavigateToExplore,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                CreationLaunchStrip(
                                  isDesktop: true,
                                  onOpenStudio: onNavigateToStudio,
                                  onOpenVoiceClone: openVoiceClone,
                                  onOpenSketchpad: openSketchpad,
                                  onOpenMarket: onNavigateToMarket,
                                  onOpenLibrary: onNavigateToLibrary,
                                ),
                                const SizedBox(height: 16),
                                EditorialRhythmSpotlightCard(
                                  spotlight: spotlight,
                                  onTryRhythm: tryRhythmSpotlight,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...<Widget>[
                      NowPlayingHomeCard(
                        onNavigateToStudio: onNavigateToStudio,
                      ),
                      const SizedBox(height: 16),
                      HorizontalGenreTrackShelf(
                        tracks: displayedGenreTracks,
                        selectedGenres: onboardingState.selectedGenres,
                        onViewAll: onNavigateToExplore,
                      ),
                      const SizedBox(height: 16),
                      CreationLaunchStrip(
                        isDesktop: false,
                        onOpenStudio: onNavigateToStudio,
                        onOpenVoiceClone: openVoiceClone,
                        onOpenSketchpad: openSketchpad,
                        onOpenMarket: onNavigateToMarket,
                        onOpenLibrary: onNavigateToLibrary,
                      ),
                      const SizedBox(height: 16),
                      EditorialRhythmSpotlightCard(
                        spotlight: spotlight,
                        onTryRhythm: tryRhythmSpotlight,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
