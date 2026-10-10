import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/player/data/services/vhunambi_audio_handler.dart';
import 'package:vhunambi_client/features/player/presentation/providers/audio_bridge_providers.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/mobile_mini_player.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// Mission 13 — Mobile mini-player horizontal swipe gestures.
///
/// `PlayerNotifier` runs a 1-second position ticker, so each test disposes its
/// [ProviderContainer] *inside* the test body to satisfy `!timersPending`.
void main() {
  testWidgets('swiping left skips to the next track', (tester) async {
    final container = await _seedContainer(tester);
    await _pumpMiniPlayer(tester, container);

    expect(container.read(playerStateProvider).currentTrack?.id, 'trk_1');

    await tester.fling(
      find.byType(MobileMiniPlayer),
      const Offset(-400, 0),
      1000,
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(playerStateProvider).currentTrack?.id, 'trk_2');

    container.dispose();
  });

  testWidgets('swiping right skips to the previous track', (tester) async {
    final container = await _seedContainer(tester, startAt: 1);
    await _pumpMiniPlayer(tester, container);

    expect(container.read(playerStateProvider).currentTrack?.id, 'trk_2');

    await tester.fling(
      find.byType(MobileMiniPlayer),
      const Offset(400, 0),
      1000,
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(playerStateProvider).currentTrack?.id, 'trk_1');

    container.dispose();
  });

  testWidgets('a slow drag below the velocity threshold does not skip',
      (tester) async {
    final container = await _seedContainer(tester);
    await _pumpMiniPlayer(tester, container);

    // A gentle drag must not trigger a skip (velocity well under 250).
    await tester.drag(
      find.byType(MobileMiniPlayer),
      const Offset(-30, 0),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(container.read(playerStateProvider).currentTrack?.id, 'trk_1');

    container.dispose();
  });
}

Future<ProviderContainer> _seedContainer(
  WidgetTester tester, {
  Size size = const Size(400, 800),
  List<String> ids = const <String>['trk_1', 'trk_2', 'trk_3'],
  int startAt = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final handler = TestVhunambiAudioHandler();
  addTearDown(handler.dispose);

  final container = ProviderContainer(
    overrides: <Override>[
      audioHandlerProvider.overrideWithValue(handler),
    ],
  );

  final tracks = <Track>[for (final id in ids) _track(id)];
  container.read(playerStateProvider.notifier).playTrack(
        tracks[startAt],
        queue: tracks,
      );

  return container;
}

Future<void> _pumpMiniPlayer(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: MobileMiniPlayer()),
      ),
    ),
  );
}

Track _track(String id) => Track(
      id: id,
      title: 'Track $id',
      creatorName: 'Sigwa & Inaf',
      genre: 'Amapiano',
      duration: const Duration(minutes: 3, seconds: 20),
    );
