import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_entity.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_enums.dart';
import 'package:vhunambi_client/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:vhunambi_client/features/notifications/presentation/widgets/notification_category_rail.dart';

/// M8 — NotificationCategoryRail suite.
void main() {
  Future<ProviderContainer> pumpRail(
    WidgetTester tester, {
    List<NotificationEntity> seed = const <NotificationEntity>[],
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
          home: const Scaffold(
            body: Column(
              children: <Widget>[NotificationCategoryRail()],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('renders an All chip plus one chip per category',
      (tester) async {
    await pumpRail(tester);

    expect(find.text('All'), findsOneWidget);
    for (final label in <String>['Social', 'System', 'Activity', 'Discovery']) {
      expect(find.text(label), findsOneWidget, reason: 'missing $label chip');
    }
  });

  testWidgets('tapping a category chip updates selectedCategoryProvider',
      (tester) async {
    final container = await pumpRail(tester);
    expect(container.read(selectedCategoryProvider), isNull);

    await tester.tap(find.text('Social'));
    await tester.pumpAndSettle();

    expect(container.read(selectedCategoryProvider),
        NotificationCategory.social);
  });

  testWidgets('tapping All resets the filter to null', (tester) async {
    final container = await pumpRail(tester);

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(container.read(selectedCategoryProvider),
        NotificationCategory.system);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(container.read(selectedCategoryProvider), isNull);
  });

  testWidgets('each chip satisfies a 44x44px minimum touch target',
      (tester) async {
    await pumpRail(tester);

    for (final key in <Key>[
      const Key('category_chip_all'),
      const Key('category_chip_social'),
      const Key('category_chip_system'),
      const Key('category_chip_creatorActivity'),
      const Key('category_chip_algorithmic'),
    ]) {
      final chip = find.byKey(key);
      expect(chip, findsOneWidget);
      final size = tester.getSize(chip);
      expect(size.height, greaterThanOrEqualTo(44), reason: '$key height');
      expect(size.width, greaterThanOrEqualTo(44), reason: '$key width');
    }
  });

  testWidgets('unread count badge reflects the per-category unread total',
      (tester) async {
    await pumpRail(
      tester,
      seed: <NotificationEntity>[
        _alert('s1', NotificationCategory.social),
        _alert('s2', NotificationCategory.social),
        _alert('sys1', NotificationCategory.system, isRead: true),
      ],
    );

    // Social has 2 unread → badge shows "2"; System is fully read → no badge.
    final socialChip = find.ancestor(
      of: find.text('2'),
      matching: find.byKey(const Key('category_chip_social')),
    );
    expect(socialChip, findsOneWidget);
  });
}

NotificationEntity _alert(
  String id,
  NotificationCategory category, {
  bool isRead = false,
}) =>
    NotificationEntity(
      id: id,
      title: 'Alert $id',
      message: 'msg',
      category: category,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      isRead: isRead,
    );
