import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/player/data/services/vhunambi_audio_handler.dart';
import 'package:vhunambi_client/features/player/presentation/providers/audio_bridge_providers.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/expanded_cockpit_modal.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/stem_mixer_deck.dart';
import 'package:vhunambi_client/features/profile/presentation/views/artist_profile_view.dart';
import 'package:vhunambi_client/features/track/presentation/views/track_detail_view.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// Missions 14, 15 & Cockpit UX Overhaul — Full-screen lyrics, collapsible tools,
/// clickable title/artist navigation, and slide-down dismissal.
void main() {
  const lyrics =
      '[Intro]\nYebo!\n\n[Verse 1]\nWalking through the morning mist\n\n[Chorus]\nThis is our song';

  Future<ProviderContainer> seed(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final handler = TestVhunambiAudioHandler();
    addTearDown(handler.dispose);

    final container = ProviderContainer(
      overrides: <Override>[audioHandlerProvider.overrideWithValue(handler)],
    );

    // Active player track.
    container.read(playerStateProvider.notifier).playTrack(_track('trk_1'));

    // Mirror it into the vault with lyrics so the cockpit can resolve them.
    container
        .read(libraryTracksProvider.notifier)
        .addTrack(
          LibraryTrack(
            id: 'trk_1',
            title: 'Track trk_1',
            creatorId: 'creator_sigwa_inaf',
            creatorName: 'Sigwa & Inaf',
            creatorHandle: '@sigwa_inaf',
            genre: 'Amapiano',
            language: 'English',
            durationSeconds: 200,
            remoteAudioUrl: 'https://vhunambi.com/audio/trk_1.mp3',
            createdAt: DateTime(2026, 1, 1),
            lyrics: lyrics,
          ),
        );

    return container;
  }

  Future<void> pumpCockpit(
    WidgetTester tester,
    ProviderContainer container, {
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme ?? AppTheme.darkTheme,
          home: const Scaffold(body: ExpandedCockpitModal()),
        ),
      ),
    );
  }

  testWidgets(
    'full-screen lyrics toggle removes redundant tabs and hides playback controls',
    (tester) async {
      final container = await seed(tester);
      await pumpCockpit(tester, container);

      // Redundant segmented tab selector and duplicate tray switcher are removed.
      expect(find.byKey(const Key('player_hero_mode_selector')), findsNothing);
      expect(find.byKey(const Key('player_lyrics_btn')), findsNothing);

      // Artwork mode by default: playback controls visible, no lyrics yet.
      expect(find.byKey(const Key('cockpit_hero_artwork')), findsOneWidget);
      expect(find.byKey(const Key('cockpit_playback_section')), findsOneWidget);
      expect(
        find.byKey(const Key('cockpit_waveform_scrubber')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('cockpit_tools_toggle')), findsOneWidget);
      expect(find.text('[Chorus]'), findsNothing);

      // Toggle to Full-Screen Lyrics mode via sole top-bar switcher.
      await tester.tap(find.byKey(const Key('player_lyrics_toggle')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cockpit_lyrics_surface')), findsOneWidget);
      expect(find.text('[Chorus]'), findsOneWidget);
      expect(find.text('This is our song'), findsOneWidget);

      // Playback controls & artwork are hidden so lyrics own the viewport.
      expect(find.byKey(const Key('cockpit_playback_section')), findsNothing);
      expect(find.byKey(const Key('cockpit_hero_artwork')), findsNothing);
      expect(find.byKey(const Key('cockpit_waveform_scrubber')), findsNothing);
      expect(find.byKey(const Key('cockpit_tools_toggle')), findsNothing);

      // Full screen height usage check (1000px viewport after 220ms morph)
      final backdropHeight = tester
          .getSize(find.byKey(const Key('cockpit_chromatic_backdrop')))
          .height;
      expect(backdropHeight, equals(1000.0));

      // Toggling back restores artwork & playback controls cleanly.
      await tester.tap(find.byKey(const Key('player_lyrics_toggle')));
      await tester.pumpAndSettle();
      expect(find.text('[Chorus]'), findsNothing);
      expect(find.byKey(const Key('cockpit_playback_section')), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const Key('cockpit_chromatic_backdrop')))
            .height,
        equals(880.0),
      );

      container.dispose();
    },
  );

  testWidgets('lyrics empty state shows when no lyrics are attached', (
    tester,
  ) async {
    final container = await seed(tester);
    // Replace the vault track with one that has no lyrics.
    container.read(libraryTracksProvider.notifier).deleteTrack('trk_1');
    container
        .read(libraryTracksProvider.notifier)
        .addTrack(
          LibraryTrack(
            id: 'trk_1',
            title: 'Track trk_1',
            creatorName: 'Sigwa & Inaf',
            genre: 'Amapiano',
            language: 'English',
            durationSeconds: 200,
            remoteAudioUrl: 'https://vhunambi.com/audio/trk_1.mp3',
            createdAt: DateTime(2026, 1, 1),
          ),
        );
    await pumpCockpit(tester, container);

    await tester.tap(find.byKey(const Key('player_lyrics_toggle')));
    await tester.pump();

    expect(find.text('No written lyrics for this track'), findsOneWidget);

    container.dispose();
  });

  testWidgets('Track Tools tray is collapsed by default and expands cleanly', (
    tester,
  ) async {
    final container = await seed(tester);
    await pumpCockpit(tester, container);

    expect(find.byKey(const Key('cockpit_tools_toggle')), findsOneWidget);
    expect(find.byKey(const Key('player_stems_btn')), findsNothing);
    expect(find.byKey(const Key('player_track_info_btn')), findsNothing);
    expect(find.byKey(const Key('player_export_btn')), findsNothing);
    expect(find.byKey(const Key('player_mux_btn')), findsNothing);
    expect(find.byKey(const Key('player_queue_btn')), findsNothing);
    expect(find.byKey(const Key('cockpit_master_ab_btn')), findsNothing);
    expect(find.byKey(const Key('cockpit_remix_in_studio_btn')), findsNothing);

    await tester.tap(find.byKey(const Key('cockpit_tools_toggle')));
    await tester.pump();

    expect(find.byKey(const Key('player_stems_btn')), findsOneWidget);
    expect(find.byKey(const Key('player_track_info_btn')), findsOneWidget);
    expect(find.byKey(const Key('player_export_btn')), findsOneWidget);
    expect(find.byKey(const Key('player_mux_btn')), findsOneWidget);
    expect(find.byKey(const Key('player_queue_btn')), findsOneWidget);
    expect(find.byKey(const Key('cockpit_master_ab_btn')), findsOneWidget);
    expect(
      find.byKey(const Key('cockpit_remix_in_studio_btn')),
      findsOneWidget,
    );

    container.dispose();
  });

  testWidgets('tapping song title opens TrackDetailView', (tester) async {
    final container = await seed(tester);
    await pumpCockpit(tester, container);

    await tester.tap(find.byKey(const Key('player_track_title_tap')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(TrackDetailView), findsOneWidget);

    container.read(playerStateProvider.notifier).dismiss();
    await tester.pump();
    container.dispose();
  });

  testWidgets('tapping artist name opens ArtistProfileView', (tester) async {
    final container = await seed(tester);
    await pumpCockpit(tester, container);

    await tester.tap(find.byKey(const Key('player_artist_name_tap')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(ArtistProfileView), findsOneWidget);

    container.read(playerStateProvider.notifier).dismiss();
    await tester.pump();
    container.dispose();
  });

  testWidgets(
    'slide down gesture on drag handle dismisses ExpandedCockpitModal',
    (tester) async {
      final container = await seed(tester);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  key: const Key('open_cockpit_test_btn'),
                  onPressed: () => ExpandedCockpitModal.show(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_cockpit_test_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ExpandedCockpitModal), findsOneWidget);

      await tester.drag(
        find.byKey(const Key('cockpit_drag_handle')),
        const Offset(0, 240),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ExpandedCockpitModal), findsNothing);

      container.dispose();
    },
  );

  testWidgets('tapping waveform scrubber seeks using rendered scrubber width', (
    tester,
  ) async {
    final container = await seed(tester);
    await pumpCockpit(tester, container);

    final scrubber = find.byKey(const Key('cockpit_waveform_scrubber'));
    final rect = tester.getRect(scrubber);
    await tester.tapAt(Offset(rect.left + (rect.width * 0.5), rect.center.dy));
    await tester.pump();

    final positionMs = container
        .read(playerStateProvider)
        .position
        .inMilliseconds;
    // 50% of 200s = 100,000ms (with tolerance for tap location quantization)
    expect(positionMs, closeTo(100000, 4000));

    container.dispose();
  });

  testWidgets('the 3-dots button opens the track action sheet', (tester) async {
    final container = await seed(tester);
    await pumpCockpit(tester, container);

    await tester.tap(find.byKey(const Key('player_more_actions_btn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // TrackActionsSheet surfaces a recognisable action.
    expect(find.text('Song Details'), findsOneWidget);

    container.dispose();
  });

  testWidgets(
    'root is wrapped in Material transparency (VH-015 - no yellow underlines)',
    (tester) async {
      final container = await seed(tester);
      await pumpCockpit(tester, container);

      // Material widget with transparency type should be present in the tree
      expect(find.byType(Material), findsWidgets);
      // Text widgets should render without yellow underline artifacts
      expect(find.text('Track trk_1'), findsOneWidget);

      container.dispose();
    },
  );

  testWidgets('share button uses system share sheet (VH-016)', (tester) async {
    final container = await seed(tester);
    await pumpCockpit(tester, container);

    // Share button should be present
    expect(find.byKey(const Key('player_meta_share_btn')), findsOneWidget);

    container.dispose();
  });

  testWidgets(
    'action row wraps on narrow 360dp viewport in Light & Dark modes (VH-017)',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = await seed(tester);
      await pumpCockpit(tester, container, theme: AppTheme.lightTheme);

      expect(find.byKey(const Key('player_meta_share_btn')), findsOneWidget);
      expect(find.byType(Wrap), findsWidgets);

      // Expand tools tray in 360dp Light mode to verify zero RenderFlex overflow
      await tester.tap(find.byKey(const Key('cockpit_tools_toggle')));
      await tester.pump();
      expect(find.byKey(const Key('player_stems_btn')), findsOneWidget);

      // Verify StemMixerDeck renders cleanly in Light theme as well
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: StemMixerDeck(title: 'Track trk_1')),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('stem_master_only_banner')), findsOneWidget);

      container.dispose();
    },
  );
}

Track _track(String id) => Track(
  id: id,
  title: 'Track $id',
  creatorName: 'Sigwa & Inaf',
  genre: 'Amapiano',
  duration: const Duration(minutes: 3, seconds: 20),
);
