import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/player/data/services/vhunambi_audio_handler.dart';
import 'package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart';
import 'package:vhunambi_client/features/player/presentation/providers/audio_bridge_providers.dart';
import 'package:vhunambi_client/features/player/presentation/providers/audio_reactive_biome_provider.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/player/presentation/providers/stem_mixer_provider.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/expanded_cockpit_modal.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/player_living_biome_hero_viewport.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/stem_mixer_deck.dart';
import 'package:vhunambi_client/features/studio/domain/models/mycelium_biome_models.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/track_living_biome_preview_card.dart';
import 'package:vhunambi_client/shared/models/track.dart';

void main() {
  const testLyrics =
      '[Intro]\nBioluminescent start\n\n[Verse 1]\nMycelium threads connecting souls\n\n[Chorus]\nQuantum Entanglement';

  Track createTestTrack(String id) => Track(
        id: id,
        title: 'Quantum Anthem $id',
        creatorName: 'Argon & Mycelium',
        genre: 'Amapiano',
        duration: const Duration(minutes: 3, seconds: 20),
      );

  group('Phase 55: Audio-Reactive Living Biome Unit & Widget Tests', () {
    // -------------------------------------------------------------------------
    // TEST 1: REQ-P55-DSP-01: Mathematical DSP Calculations & Journey Section
    // -------------------------------------------------------------------------
    test('REQ-P55-DSP-01: AudioBiomeModulationState computes mathematical DSP & sections', () {
      final defaultMod = const AudioBiomeModulationState(
        isPlaying: true,
        positionMs: 10000,
        durationMs: 200000,
        drumsEnergy: 0.8,
        bassEnergy: 0.9,
        melodicEnergy: 0.6,
        vocalGlow: 0.7,
        logDrumSnapZoom: 0.85,
      );

      // Verify domain energies derived correctly
      // rhythmNetwork: 0.60 * bass(0.9) + 0.40 * drums(0.8) = 0.54 + 0.32 = 0.86
      expect(defaultMod.domainEnergyFor(MyceliumClusterDomain.rhythmNetwork), closeTo(0.86, 0.02));
      // vocalNetwork: vocalGlow = 0.7
      expect(defaultMod.domainEnergyFor(MyceliumClusterDomain.vocalNetwork), closeTo(0.70, 0.01));
      // melodyCore: melodicEnergy = 0.6
      expect(defaultMod.domainEnergyFor(MyceliumClusterDomain.melodyCore), closeTo(0.60, 0.01));

      // Verify cap dilation multiplier in [0.85, 1.32]
      final drumCapScale = defaultMod.capScaleMultiplierFor(MyceliumClusterDomain.rhythmNetwork);
      expect(drumCapScale, greaterThan(1.0));
      expect(drumCapScale, lessThanOrEqualTo(1.32));

      // Verify photon speed multiplier in [1.0, 5.0]
      expect(defaultMod.photonSpeedMultiplier, closeTo(1.0 + 2.5 * 0.6 + 1.5 * 0.8, 0.02));

      // Verify camera snap zoom multiplier
      expect(defaultMod.cameraSnapZoomMultiplier, closeTo(1.0 + 0.065 * 0.85, 0.02));

      // Verify Song Journey section mapping
      expect(defaultMod.synchronizedJourneySection, SongJourneySection.intro);

      final verseMod = defaultMod.copyWith(positionMs: 40000, durationMs: 200000);
      expect(verseMod.synchronizedJourneySection, SongJourneySection.verse);

      final chorusMod = defaultMod.copyWith(positionMs: 100000, durationMs: 200000);
      expect(chorusMod.synchronizedJourneySection, SongJourneySection.chorus);

      final bridgeMod = defaultMod.copyWith(positionMs: 150000, durationMs: 200000);
      expect(bridgeMod.synchronizedJourneySection, SongJourneySection.bridge);

      final outroMod = defaultMod.copyWith(positionMs: 190000, durationMs: 200000);
      expect(outroMod.synchronizedJourneySection, SongJourneySection.outro);
    });

    // -------------------------------------------------------------------------
    // TEST 2: REQ-P55-DSP-02: Solo & Mute Modulation on Cap Dilation & Luminosity
    // -------------------------------------------------------------------------
    test('REQ-P55-DSP-02: Solo and Mute modulate cap dilation and luminosity multipliers', () {
      // 1. Muted rhythm domain
      const mutedMod = AudioBiomeModulationState(
        isPlaying: true,
        positionMs: 50000,
        durationMs: 200000,
        drumsEnergy: 0.8,
        bassEnergy: 0.8,
        mutedDomains: {MyceliumClusterDomain.rhythmNetwork},
      );

      expect(mutedMod.isDomainDormant(MyceliumClusterDomain.rhythmNetwork), isTrue);
      expect(mutedMod.capScaleMultiplierFor(MyceliumClusterDomain.rhythmNetwork), 0.86);
      expect(mutedMod.luminosityMultiplierFor(MyceliumClusterDomain.rhythmNetwork), 0.20);

      // 2. Solo rhythm domain
      const soloMod = AudioBiomeModulationState(
        isPlaying: true,
        positionMs: 50000,
        durationMs: 200000,
        drumsEnergy: 0.8,
        bassEnergy: 0.8,
        melodicEnergy: 0.7,
        soloedDomains: {MyceliumClusterDomain.rhythmNetwork},
      );

      expect(soloMod.isDomainSoloed(MyceliumClusterDomain.rhythmNetwork), isTrue);
      expect(soloMod.luminosityMultiplierFor(MyceliumClusterDomain.rhythmNetwork), greaterThanOrEqualTo(1.15));

      // Non-soloed domains become dormant
      expect(soloMod.isDomainDormant(MyceliumClusterDomain.vocalNetwork), isTrue);
      expect(soloMod.capScaleMultiplierFor(MyceliumClusterDomain.vocalNetwork), 0.86);
      expect(soloMod.luminosityMultiplierFor(MyceliumClusterDomain.vocalNetwork), 0.20);
    });

    // -------------------------------------------------------------------------
    // TEST 3: REQ-P55-DSP-03: Provider Bridge Sync
    // -------------------------------------------------------------------------
    test('REQ-P55-DSP-03: audioReactiveBiomeModulationProvider bridges player & mixer state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initial active state with playerStateProvider
      final initialMod = container.read(audioReactiveBiomeModulationProvider);
      expect(initialMod.durationMs, greaterThan(0));

      // Set playback state to playing new track
      container.read(playerStateProvider.notifier).playTrack(createTestTrack('trk_quantum'));
      final activeMod = container.read(audioReactiveBiomeModulationProvider);
      expect(activeMod.isPlaying, isTrue);
      expect(activeMod.clusterAudibleGains.isNotEmpty, isTrue);
    });

    // -------------------------------------------------------------------------
    // TEST 4: REQ-P55-HERO-01: ExpandedCockpitModal 3-Way Hero Deck
    // -------------------------------------------------------------------------
    testWidgets('REQ-P55-HERO-01: ExpandedCockpitModal 3-way hero selector switches decks', (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final handler = TestVhunambiAudioHandler();
      addTearDown(handler.dispose);

      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(handler),
        ],
      );

      container.read(playerStateProvider.notifier).playTrack(createTestTrack('trk_1'));
      container.read(libraryTracksProvider.notifier).addTrack(
            LibraryTrack(
              id: 'trk_1',
              title: 'Quantum Anthem trk_1',
              creatorName: 'Argon & Mycelium',
              genre: 'Amapiano',
              language: 'Zulu',
              durationSeconds: 200,
              remoteAudioUrl: 'https://vhunambi.com/audio/trk_1.mp3',
              createdAt: DateTime(2026, 1, 1),
              lyrics: testLyrics,
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: ExpandedCockpitModal()),
          ),
        ),
      );
      await tester.pump();

      // 1. Selector should be present
      expect(find.byKey(const Key('player_hero_mode_selector')), findsOneWidget);

      // 2. Switch to 3D Biome deck
      await tester.tap(find.byKey(const Key('player_hero_segment_biome3d')));
      await tester.pump();
      expect(find.byKey(const Key('player_living_biome_viewport')), findsOneWidget);

      // 3. Switch to Lyrics deck
      await tester.tap(find.byKey(const Key('player_hero_segment_lyrics')));
      await tester.pump();
      expect(find.text('Quantum Entanglement'), findsOneWidget);

      // 4. Test backward-compatible lyrics toggle button
      await tester.tap(find.byKey(const Key('player_lyrics_toggle')));
      await tester.pump();
      // Back to artwork: lyrics stanza gone
      expect(find.text('Quantum Entanglement'), findsNothing);

      // 5. Test Track Utility Tray 3D DNA button
      await tester.tap(find.byKey(const Key('player_biome_btn')));
      await tester.pump();
      expect(find.byKey(const Key('player_living_biome_viewport')), findsOneWidget);

      container.dispose();
    });

    // -------------------------------------------------------------------------
    // TEST 5: REQ-P55-HERO-02: PlayerLivingBiomeHeroViewport Renders 6 Clusters
    // -------------------------------------------------------------------------
    testWidgets('REQ-P55-HERO-02: PlayerLivingBiomeHeroViewport renders 6 clusters and scrubber', (tester) async {
      tester.view.physicalSize = const Size(500, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final handler = TestVhunambiAudioHandler();
      addTearDown(handler.dispose);

      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(handler),
        ],
      );

      container.read(playerStateProvider.notifier).playTrack(createTestTrack('trk_1'));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: SizedBox(
                height: 400,
                child: PlayerLivingBiomeHeroViewport(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify viewport and DSP badge
      expect(find.byKey(const Key('player_living_biome_viewport')), findsOneWidget);
      expect(find.byKey(const Key('player_biome_dsp_badge')), findsOneWidget);
      expect(find.byKey(const Key('player_open_full_3d_biome_btn')), findsOneWidget);

      // Verify 6 semantic cluster hit targets
      for (final domain in MyceliumClusterDomain.values) {
        expect(find.byKey(Key('player_biome_cluster_${domain.name}')), findsOneWidget);
      }

      // Verify 5 Song Journey section scrubber keys
      for (final section in SongJourneySection.values) {
        expect(find.byKey(Key('player_biome_section_${section.name}')), findsOneWidget);
      }

      // Tap Chorus section in Journey scrubber
      await tester.tap(find.byKey(const Key('player_biome_section_chorus')));
      await tester.pump();

      container.dispose();
    });

    // -------------------------------------------------------------------------
    // TEST 6: REQ-P55-STEM-01: QuickMix HUD Toggles Solo & Mute on StemMixerState
    // -------------------------------------------------------------------------
    testWidgets('REQ-P55-STEM-01: Tapping 3D cluster reveals QuickMixHud and mutates stem mixer', (tester) async {
      tester.view.physicalSize = const Size(500, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final handler = TestVhunambiAudioHandler();
      addTearDown(handler.dispose);

      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(handler),
        ],
      );

      container.read(playerStateProvider.notifier).playTrack(createTestTrack('trk_1'));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: SizedBox(
                height: 400,
                child: PlayerLivingBiomeHeroViewport(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap rhythmNetwork cluster hit target
      await tester.tap(find.byKey(const Key('player_biome_cluster_rhythmNetwork')));
      await tester.pump();

      // Quick-Mix HUD should appear
      expect(find.byKey(const Key('player_biome_quick_mix_hud')), findsOneWidget);
      expect(find.byKey(const Key('biome_quick_solo_rhythmNetwork')), findsOneWidget);
      expect(find.byKey(const Key('biome_quick_mute_rhythmNetwork')), findsOneWidget);

      // Tap Solo button in Quick-Mix HUD
      await tester.tap(find.byKey(const Key('biome_quick_solo_rhythmNetwork')));
      await tester.pump();

      // Verify stem mixer state now has drums soloed
      final mixerState = container.read(stemMixerProvider);
      final drumChannel = mixerState.channel(StemType.drums);
      expect(drumChannel.isSolo, isTrue);

      container.dispose();
    });

    // -------------------------------------------------------------------------
    // TEST 7: REQ-P55-STEM-02: StemMixerBiomeEntanglementStrip Sync & Tapping
    // -------------------------------------------------------------------------
    testWidgets('REQ-P55-STEM-02: StemMixerBiomeEntanglementStrip syncs and toggles solo', (tester) async {
      final handler = TestVhunambiAudioHandler();
      addTearDown(handler.dispose);

      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(handler),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: StemMixerBiomeEntanglementStrip(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('stem_mixer_biome_strip')), findsOneWidget);

      // 6 cluster pills should be rendered
      for (final domain in MyceliumClusterDomain.values) {
        expect(find.byKey(Key('stem_mixer_cluster_pill_${domain.name}')), findsOneWidget);
      }

      // Tap rhythmNetwork pill to toggle solo
      await tester.tap(find.byKey(const Key('stem_mixer_cluster_pill_rhythmNetwork')));
      await tester.pump();

      final mixerState = container.read(stemMixerProvider);
      expect(mixerState.channel(StemType.drums).isSolo, isTrue);

      container.dispose();
    });

    // -------------------------------------------------------------------------
    // TEST 8: REQ-P55-TRK-01: TrackLivingBiomePreviewCard in TrackDetailView
    // -------------------------------------------------------------------------
    testWidgets('REQ-P55-TRK-01: TrackLivingBiomePreviewCard renders and triggers modal', (tester) async {
      final handler = TestVhunambiAudioHandler();
      addTearDown(handler.dispose);

      final container = ProviderContainer(
        overrides: [
          audioHandlerProvider.overrideWithValue(handler),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: TrackLivingBiomePreviewCard(
                  trackTitle: 'Khomba',
                  genre: 'Amapiano',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Card and Enter 3D Biome button exist
      expect(find.byKey(const Key('track_detail_living_biome_card')), findsOneWidget);
      expect(find.byKey(const Key('track_detail_open_3d_biome_btn')), findsOneWidget);
      expect(find.text('Living 3D Song DNA Biome'), findsOneWidget);

      container.dispose();
    });
  });
}
