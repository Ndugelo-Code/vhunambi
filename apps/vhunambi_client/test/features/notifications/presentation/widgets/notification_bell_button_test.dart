import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_entity.dart';
import 'package:vhunambi_client/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:vhunambi_client/features/notifications/presentation/widgets/notification_bell_button.dart';
import 'package:vhunambi_client/features/notifications/presentation/widgets/notifications_popover.dart';

/// T11.4 — Header bell button suite.
List<NotificationEntity> _alerts(int unread) => List<NotificationEntity>.generate(
      unread,
      (index) => NotificationEntity(
        id: 'notif_$index',
        title: 'Alert $index',
        message: 'Amapiano • 3:20',
        createdAt: DateTime.now().subtract(Duration(minutes: index + 1)),
      ),
    );

Future<ProviderContainer> _pumpBell(
  WidgetTester tester, {
  List<NotificationEntity> seed = const <NotificationEntity>[],
  VoidCallback? onPressed,
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final container = ProviderContainer(
    overrides: <Override>[
      notificationsProvider.overrideWith(
        (ref) => NotificationsNotifier(seed),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(child: NotificationBellButton(onPressed: onPressed)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Finder _badgeText() => find.descendant(
      of: find.byType(NotificationBellButton),
      matching: find.byType(Text),
    );

void main() {
  testWidgets('renders a clean bell when nothing is unread', (tester) async {
    await _pumpBell(tester);

    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(_badgeText(), findsNothing);
  });

  testWidgets('renders the unread count badge', (tester) async {
    await _pumpBell(tester, seed: _alerts(2));

    expect(_badgeText(), findsOneWidget);
    expect(tester.widget<Text>(_badgeText()).data, '2');
  });

  testWidgets('caps the badge counter at 9+', (tester) async {
    await _pumpBell(tester, seed: _alerts(12));

    expect(tester.widget<Text>(_badgeText()).data, '9+');
  });

  testWidgets('the badge reacts to list mutations', (tester) async {
    final container = await _pumpBell(tester, seed: _alerts(1));
    expect(tester.widget<Text>(_badgeText()).data, '1');

    container.read(notificationsProvider.notifier).markAllAsRead();
    await tester.pumpAndSettle();

    expect(_badgeText(), findsNothing);
  });

  testWidgets('exposes the legacy Notifications tooltip', (tester) async {
    await _pumpBell(tester);

    expect(find.byTooltip(NotificationBellButton.tooltip), findsOneWidget);
  });

  testWidgets('tapping opens the alerts drawer', (tester) async {
    await _pumpBell(tester, seed: _alerts(1));

    await tester.tap(find.byType(NotificationBellButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(NotificationsPopover), findsOneWidget);
    expect(find.text('Alert 0'), findsOneWidget);
  });

  testWidgets('a custom onPressed overrides the default drawer behaviour',
      (tester) async {
    var taps = 0;
    await _pumpBell(tester, onPressed: () => taps++);

    await tester.tap(find.byType(NotificationBellButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(taps, 1);
    expect(find.byType(NotificationsPopover), findsNothing);
  });
}
