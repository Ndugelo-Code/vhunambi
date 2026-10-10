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
import 'package:vhunambi_client/shared/models/track.dart';

/// Missions 14 & 15 — Expanded cockpit lyrics toggle + 3-dots action sheet.
///
/// The active player track id is mirrored into the vault (`libraryTracksProvider`)
/// so the cockpit can resolve its lyrics / action sheet.
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
      overrides: <Override>[
        audioHandlerProvider.overrideWithValue(handler),
      ],
    );

    // Active player track.
    container.read(playerStateProvider.notifier).playTrack(_track('trk_1'));

    // Mirror it into the vault with lyrics so the cockpit can resolve them.
    container.read(libraryTracksProvider.notifier).addTrack(
          LibraryTrack(
            id: 'trk_1',
            title: 'Track trk_1',
            creatorName: 'Sigwa & Inaf',
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
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: ExpandedCockpitModal()),
        ),
      ),
    );
  }

  testWidgets('lyrics toggle swaps artwork for the lyrics surface',
      (tester) async {
    final container = await seed(tester);
    await pumpCockpit(tester, container);

    // Artwork mode by default: the hero piano glyph is present, no lyrics yet.
    expect(find.text('[Chorus]'), findsNothing);

    await tester.tap(find.byKey(const Key('player_lyrics_toggle')));
    await tester.pump();

    // Lyrics surface now shows a stanza header; artwork glyph is gone.
    expect(find.text('[Chorus]'), findsOneWidget);
    expect(find.text('This is our song'), findsOneWidget);

    // Toggling back restores the artwork.
    await tester.tap(find.byKey(const Key('player_lyrics_toggle')));
    await tester.pump();
    expect(find.text('[Chorus]'), findsNothing);

    container.dispose();
  });

  testWidgets('lyrics empty state shows when no lyrics are attached',
      (tester) async {
    final container = await seed(tester);
    // Replace the vault track with one that has no lyrics.
    container.read(libraryTracksProvider.notifier).deleteTrack('trk_1');
    container.read(libraryTracksProvider.notifier).addTrack(
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

  testWidgets('the 3-dots button opens the track action sheet',
      (tester) async {
    final container = await seed(tester);
    await pumpCockpit(tester, container);

    await tester.tap(find.byKey(const Key('player_more_actions_btn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // TrackActionsSheet surfaces a recognisable action.
    expect(find.text('Song Details'), findsOneWidget);

    container.dispose();
  });
}

Track _track(String id) => Track(
      id: id,
      title: 'Track $id',
      creatorName: 'Sigwa & Inaf',
      genre: 'Amapiano',
      duration: const Duration(minutes: 3, seconds: 20),
    );
