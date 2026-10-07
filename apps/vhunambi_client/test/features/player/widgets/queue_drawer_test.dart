import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/player/data/services/vhunambi_audio_handler.dart';
import 'package:vhunambi_client/features/player/presentation/providers/audio_bridge_providers.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/desktop_transport_bar.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/queue_drawer.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// T12.6 — Playback queue drawer widget suite.
///
/// `PlayerNotifier` runs a 1-second position ticker, so each test disposes its
/// [ProviderContainer] *inside* the test body: the ticker must be cancelled
/// before the framework's `!timersPending` assertion fires.
void main() {
  testWidgets('renders the header, counter pill and now playing card',
      (tester) async {
    final container = await _seedContainer(tester);
    await _pumpDrawerHost(tester, container);

    expect(find.text('Playback Queue'), findsOneWidget);
    expect(find.text('3 Tracks'), findsOneWidget);
    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.text('Track trk_1'), findsOneWidget);
    expect(find.text('Track trk_2'), findsOneWidget);
    expect(find.text('Track trk_3'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(2));

    container.dispose();
  });

  testWidgets('shows the empty state when nothing is queued up',
      (tester) async {
    final container = await _seedContainer(
      tester,
      ids: const <String>['trk_1'],
    );
    await _pumpDrawerHost(tester, container);

    expect(find.text('1 Track'), findsOneWidget);
    expect(find.text('Nothing queued up'), findsOneWidget);

    container.dispose();
  });

  testWidgets('removing a row drops it from the playback queue',
      (tester) async {
    final container = await _seedContainer(tester);
    await _pumpDrawerHost(tester, container);

    await tester.tap(find.byKey(const Key('queue_remove_trk_3')));
    await tester.pump();

    final queue = container.read(playerStateProvider).queue;

    expect(queue.map((track) => track.id), <String>['trk_1', 'trk_2']);
    expect(find.text('Track trk_3'), findsNothing);

    container.dispose();
  });

  testWidgets('the Clear action keeps only the active track', (tester) async {
    final container = await _seedContainer(tester);
    await _pumpDrawerHost(tester, container);

    await tester.tap(find.byKey(const Key('queue_clear')));
    await tester.pump();

    final player = container.read(playerStateProvider);

    expect(player.queue, hasLength(1));
    expect(player.queue.single.id, 'trk_1');
    expect(player.currentTrack?.id, 'trk_1');
    expect(find.text('Nothing queued up'), findsOneWidget);
    expect(find.text('1 Track'), findsOneWidget);

    container.dispose();
  });

  testWidgets('tapping a row jumps playback to that track', (tester) async {
    final container = await _seedContainer(tester);
    await _pumpDrawerHost(tester, container);

    await tester.tap(find.text('Track trk_3'));
    await tester.pump();

    final player = container.read(playerStateProvider);

    expect(player.currentTrack?.id, 'trk_3');
    expect(player.currentIndex, 2);

    container.dispose();
  });

  testWidgets('dragging a handle reorders the upcoming rows', (tester) async {
    final container = await _seedContainer(tester);
    await _pumpDrawerHost(tester, container);

    final handle = find.byIcon(Icons.drag_handle_rounded).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final queue = container.read(playerStateProvider).queue;

    expect(queue.map((track) => track.id), <String>['trk_1', 'trk_3', 'trk_2']);
    expect(container.read(playerStateProvider).currentTrack?.id, 'trk_1');

    container.dispose();
  });

  testWidgets('the close control dismisses the drawer', (tester) async {
    final container = await _seedContainer(tester);
    await _pumpDrawerHost(tester, container);

    await tester.tap(find.byKey(const Key('queue_close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Playback Queue'), findsNothing);

    container.dispose();
  });

  testWidgets('mobile viewports present the queue as a bottom sheet',
      (tester) async {
    final container = await _seedContainer(
      tester,
      size: const Size(520, 900),
    );
    await _pumpDrawerHost(tester, container);

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Playback Queue'), findsOneWidget);

    container.dispose();
  });

  testWidgets('the transport bar queue button opens the drawer',
      (tester) async {
    final container = await _seedContainer(tester);
    await _pumpHost(
      tester,
      container,
      home: const Scaffold(body: DesktopTransportBar()),
    );

    await tester.tap(find.byKey(const Key('transport_queue_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Playback Queue'), findsOneWidget);
    expect(find.text('3 Tracks'), findsOneWidget);

    container.dispose();
  });
}

/// Seeds a live 3-track queue on a tracked audio handler.
Future<ProviderContainer> _seedContainer(
  WidgetTester tester, {
  Size size = const Size(1280, 900),
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

/// Pumps a host whose button opens the queue drawer.
Future<void> _pumpDrawerHost(
  WidgetTester tester,
  ProviderContainer container,
) {
  return _pumpHost(
    tester,
    container,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => QueueDrawer.show(context),
            child: const Text('open queue'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpHost(
  WidgetTester tester,
  ProviderContainer container, {
  required Widget home,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.darkTheme, home: home),
    ),
  );

  final opener = find.text('open queue');
  if (opener.evaluate().isEmpty) return;

  await tester.tap(opener);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Track _track(String id) => Track(
      id: id,
      title: 'Track $id',
      creatorName: 'Sigwa & Inaf',
      genre: 'Amapiano',
      duration: const Duration(minutes: 3, seconds: 20),
    );
