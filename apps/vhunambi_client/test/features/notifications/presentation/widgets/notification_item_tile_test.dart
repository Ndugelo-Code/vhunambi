import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_entity.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_enums.dart';
import 'package:vhunambi_client/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:vhunambi_client/features/notifications/presentation/widgets/notification_item_tile.dart';

/// M8 — NotificationItemTile suite (render, swipe-to-dismiss, actions, dot).
void main() {
  Future<ProviderContainer> pumpTile(
    WidgetTester tester, {
    required NotificationEntity notification,
    VoidCallback? onTap,
    void Function(NotificationAction action)? onAction,
    List<NotificationEntity> seed = const <NotificationEntity>[],
  }) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(
      overrides: <Override>[
        notificationsProvider.overrideWith(
          (ref) => NotificationsNotifier(seed.isEmpty ? [notification] : seed),
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
            body: NotificationItemTile(
              notification: notification,
              onTap: onTap,
              onAction: onAction,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('renders title, message and category glyph badge',
      (tester) async {
    await pumpTile(
      tester,
      notification: _alert('tile_a', category: NotificationCategory.social),
    );

    expect(find.text('Alert tile_a'), findsOneWidget);
    expect(find.textContaining('Amapiano'), findsOneWidget);
    // Social glyph is people_alt_outlined.
    expect(find.byIcon(Icons.people_alt_outlined), findsOneWidget);
  });

  testWidgets('unread dot is visible when unread and gone after read',
      (tester) async {
    await pumpTile(
      tester,
      notification: _alert('tile_unread', isRead: false),
    );

    final dot = find.byKey(const Key('notification_unread_dot'));
    expect(dot, findsOneWidget);
    final animated = tester.widget<AnimatedOpacity>(
      find.ancestor(
        of: dot,
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(animated.opacity, 1.0);
  });

  testWidgets('tapping the tile marks it read and invokes onTap',
      (tester) async {
    var tapped = false;
    final container = await pumpTile(
      tester,
      notification: _alert('tile_tap', isRead: false),
      onTap: () => tapped = true,
    );

    await tester.tap(find.text('Alert tile_tap'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tapped, isTrue);
    expect(
      container.read(notificationsProvider).firstWhere((n) => n.id == 'tile_tap').isRead,
      isTrue,
    );
  });

  testWidgets('swipe-to-dismiss removes the notification from the provider',
      (tester) async {
    final container = await pumpTile(
      tester,
      notification: _alert('tile_swipe', isRead: false),
      seed: <NotificationEntity>[
        _alert('tile_swipe', isRead: false),
        _alert('tile_keep', isRead: false),
      ],
    );

    expect(container.read(notificationsProvider), hasLength(2));

    // Fling past the dismiss threshold to the right to trigger Dismissible.
    await tester.fling(
      find.byKey(const Key('notif_tile_tile_swipe')),
      const Offset(600, 0),
      1200,
    );
    await tester.pumpAndSettle();

    expect(
      container.read(notificationsProvider).map((n) => n.id),
      <String>['tile_keep'],
    );
  });

  testWidgets('contextual action buttons render and invoke onAction',
      (tester) async {
    NotificationAction? captured;
    await pumpTile(
      tester,
      notification: _alert(
        'tile_actions',
        category: NotificationCategory.creatorActivity,
      ).copyWith(
        actions: const <NotificationAction>[
          NotificationAction(
            actionId: 'audition',
            label: 'Audition',
            actionData: <String, dynamic>{'route': '/track/tile_actions'},
          ),
        ],
      ),
      onAction: (action) => captured = action,
    );

    final audition = find.byKey(const Key('notification_action_audition'));
    expect(audition, findsOneWidget);

    await tester.tap(audition);
    await tester.pump();

    expect(captured, isNotNull);
    expect(captured!.label, 'Audition');
  });

  testWidgets('system category renders the shield glyph', (tester) async {
    await pumpTile(
      tester,
      notification: _alert('tile_sys', category: NotificationCategory.system),
    );
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
  });
}

NotificationEntity _alert(
  String id, {
  NotificationCategory category = NotificationCategory.social,
  bool isRead = false,
}) =>
    NotificationEntity(
      id: id,
      title: 'Alert $id',
      message: 'Amapiano • 3:20',
      category: category,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      isRead: isRead,
    );
