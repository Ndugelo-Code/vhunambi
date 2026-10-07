import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_entity.dart';
import 'package:vhunambi_client/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:vhunambi_client/features/notifications/presentation/widgets/notifications_popover.dart';
import 'package:vhunambi_client/features/track/presentation/views/track_detail_view.dart';

/// T11.3 — Live notifications drawer suite.
///
/// The deep-link assertions render [TrackDetailView], which is a tall desktop
/// surface, so the suite pins a large viewport (mirrors the Phase 7 harness).
void _useDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 2800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

NotificationEntity _alert(
  String id, {
  bool isRead = false,
  String? targetTrackId,
}) =>
    NotificationEntity(
      id: id,
      title: 'Your song "$id" is ready!',
      message: 'Amapiano • 3:20',
      targetTrackId: targetTrackId,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      isRead: isRead,
    );

List<NotificationEntity> _seed() => <NotificationEntity>[
      _alert('notif_a', targetTrackId: 'seed-01'),
      _alert('notif_b'),
      _alert('notif_c', isRead: true),
    ];

/// Opens the notifications drawer.
///
/// When [autoDispose] is false the caller is responsible for calling
/// [ProviderContainer.dispose()] before the test exits so that any periodic
/// timers (e.g. PlayerNotifier's position ticker) are cancelled before the
/// framework's `!timersPending` assertion runs.
Future<ProviderContainer> _openDrawer(
  WidgetTester tester, {
  List<NotificationEntity>? seed,
  bool autoDispose = true,
}) async {
  _useDesktopViewport(tester);

  final container = ProviderContainer(
    overrides: <Override>[
      notificationsProvider.overrideWith(
        (ref) => NotificationsNotifier(seed ?? _seed()),
      ),
    ],
  );
  if (autoDispose) addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => NotificationsPopover.show(context),
                child: const Text('open alerts'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open alerts'));
  // Two pumps: first starts the dialog route animation, second settles it.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return container;
}

void main() {
  testWidgets('renders every alert with its relative timestamp',
      (tester) async {
    await _openDrawer(tester);

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Your song "notif_a" is ready!'), findsOneWidget);
    expect(find.text('Your song "notif_b" is ready!'), findsOneWidget);
    expect(find.text('Your song "notif_c" is ready!'), findsOneWidget);
    expect(
      find.textContaining('Amapiano • 3:20 • 5 minutes ago'),
      findsNWidgets(3),
    );
  });

  testWidgets('header badge counts unread alerts', (tester) async {
    final container = await _openDrawer(tester);

    expect(container.read(unreadNotificationsCountProvider), 2);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);
  });

  testWidgets('the empty state renders when the drawer has no alerts',
      (tester) async {
    await _openDrawer(tester, seed: const <NotificationEntity>[]);

    expect(find.text('No notifications yet'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);
  });

  testWidgets('Mark all read clears the badge and marks every alert',
      (tester) async {
    final container = await _openDrawer(tester);

    await tester.tap(find.text('Mark all read'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(container.read(unreadNotificationsCountProvider), 0);
    expect(find.text('2'), findsNothing);
  });

  testWidgets('Clear all empties the drawer', (tester) async {
    final container = await _openDrawer(tester);

    await tester.tap(find.text('Clear all'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(container.read(notificationsProvider), isEmpty);
    expect(find.text('No notifications yet'), findsOneWidget);
  });

  testWidgets('tapping an alert marks it read and deep-links to the track',
      (tester) async {
    // autoDispose:false — we manually dispose the container at the end so
    // PlayerNotifier's periodic 1-second ticker is cancelled BEFORE the
    // framework's !timersPending check fires on widget-tree teardown.
    final container = await _openDrawer(tester, autoDispose: false);

    await tester.tap(find.text('Your song "notif_a" is ready!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(container.read(unreadNotificationsCountProvider), 1);
    expect(find.byType(NotificationsPopover), findsNothing);
    expect(find.byType(TrackDetailView), findsOneWidget);

    // Cancel timers before the widget tree is disposed.
    container.dispose();
  });

  testWidgets('an alert without a target track only marks read and dismisses',
      (tester) async {
    final container = await _openDrawer(tester, autoDispose: false);

    await tester.tap(find.text('Your song "notif_b" is ready!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(container.read(unreadNotificationsCountProvider), 1);
    expect(find.byType(NotificationsPopover), findsNothing);
    expect(find.byType(TrackDetailView), findsNothing);

    container.dispose();
  });

  testWidgets('the per-alert dismiss control removes a single alert',
      (tester) async {
    final container = await _openDrawer(tester);

    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(container.read(notificationsProvider), hasLength(2));
    expect(find.text('Your song "notif_a" is ready!'), findsNothing);
  });

  testWidgets('the footer Close action dismisses the drawer', (tester) async {
    await _openDrawer(tester);

    await tester.tap(find.text('Close'));
    // pump once to process the Navigator.pop() call, then let the route
    // finish its exit animation before asserting.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(NotificationsPopover), findsNothing);
  });
}
