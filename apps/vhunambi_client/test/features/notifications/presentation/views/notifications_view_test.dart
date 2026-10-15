import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import 'package:vhunambi_client/features/creator_dna/presentation/providers/creator_dna_provider.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_entity.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_enums.dart';
import 'package:vhunambi_client/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:vhunambi_client/features/notifications/presentation/views/notifications_view.dart';
import 'package:vhunambi_client/features/track/presentation/views/track_detail_view.dart';

/// M8 — NotificationsView suite.
void main() {
  void useDesktopViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  Future<ProviderContainer> pumpView(
    WidgetTester tester, {
    List<NotificationEntity>? seed,
    CreatorDnaProfile? dna,
    bool autoDispose = true,
  }) async {
    useDesktopViewport(tester);

    final container = ProviderContainer(
      overrides: <Override>[
        notificationsProvider.overrideWith(
          (ref) => NotificationsNotifier(seed ?? <NotificationEntity>[]),
        ),
        if (dna != null)
          creatorDnaProvider.overrideWith(
            (ref) => CreatorDnaNotifier.withInitial(dna),
          ),
      ],
    );
    if (autoDispose) addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const NotificationsView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('renders the app bar title and category rail', (tester) async {
    await pumpView(tester, seed: <NotificationEntity>[_alert('a')]);

    expect(find.text('Notifications'), findsWidgets);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Social'), findsOneWidget);
  });

  testWidgets('renders each seeded notification tile', (tester) async {
    await pumpView(
      tester,
      seed: <NotificationEntity>[_alert('view_a'), _alert('view_b')],
    );

    expect(find.text('Alert view_a'), findsOneWidget);
    expect(find.text('Alert view_b'), findsOneWidget);
  });

  testWidgets('shows the empty state when no alerts match', (tester) async {
    await pumpView(tester, seed: const <NotificationEntity>[]);

    expect(find.byKey(const Key('notification_empty_title')), findsOneWidget);
    expect(find.text('Nothing here yet'), findsOneWidget);
  });

  testWidgets('search filters the visible list', (tester) async {
    await pumpView(
      tester,
      seed: <NotificationEntity>[
        _alert('alpha', title: 'Amapiano drop'),
        _alert('beta', title: 'Gqom release'),
      ],
    );

    expect(find.text('Amapiano drop'), findsOneWidget);
    expect(find.text('Gqom release'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('notification_search_field')),
      'gqom',
    );
    await tester.pumpAndSettle();

    expect(find.text('Gqom release'), findsOneWidget);
    expect(find.text('Amapiano drop'), findsNothing);
  });

  testWidgets('category filter narrows the list to one category',
      (tester) async {
    await pumpView(
      tester,
      seed: <NotificationEntity>[
        _alert('social1', category: NotificationCategory.social),
        _alert('system1', category: NotificationCategory.system),
      ],
    );

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();

    expect(find.text('Alert system1'), findsOneWidget);
    expect(find.text('Alert social1'), findsNothing);
  });

  testWidgets('Mark all read clears every unread flag', (tester) async {
    final container = await pumpView(
      tester,
      seed: <NotificationEntity>[
        _alert('m_a', isRead: false),
        _alert('m_b', isRead: false),
      ],
    );

    expect(container.read(unreadNotificationsCountProvider), 2);

    await tester.tap(find.byKey(const Key('notifications_mark_all_read')));
    await tester.pumpAndSettle();

    expect(container.read(unreadNotificationsCountProvider), 0);
  });

  testWidgets('algorithmic alerts matching DNA top genres rank first',
      (tester) async {
    final dna = CreatorDnaProfile(
      userId: 'u1',
      genreWeights: const <String, double>{'Amapiano': 9.0, 'Gqom': 1.0},
      onboardingCompleted: true,
      createdAt: DateTime(2026, 10, 1),
      lastUpdatedAt: DateTime(2026, 10, 1),
    );

    final container = await pumpView(
      tester,
      dna: dna,
      seed: <NotificationEntity>[
        _alert(
          'algo_gqom',
          category: NotificationCategory.algorithmic,
          metadata: const <String, dynamic>{'genre': 'Gqom'},
          minutesAgo: 1,
        ),
        _alert(
          'algo_amapiano',
          category: NotificationCategory.algorithmic,
          metadata: const <String, dynamic>{'genre': 'Amapiano'},
          minutesAgo: 30,
        ),
      ],
    );

    // DNA affinity dominates the sort, so Amapiano surfaces first even though
    // it is the older alert.
    final filtered = container.read(filteredNotificationsProvider);
    expect(filtered.first.id, 'algo_amapiano');
    expect(filtered.last.id, 'algo_gqom');
  });

  testWidgets('tapping a track alert deep-links to TrackDetailView',
      (tester) async {
    // autoDispose:false — dispose the container at the end to cancel the
    // TrackDetailView tickers before the framework teardown check fires.
    final container = await pumpView(
      tester,
      autoDispose: false,
      seed: <NotificationEntity>[
        NotificationEntity.generationReady(
          trackId: 'trk_deep',
          trackTitle: 'Deep',
          message: 'House • 3:20',
        ),
      ],
    );

    await tester.tap(find.textContaining('Your song "Deep" is ready!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TrackDetailView), findsOneWidget);

    container.dispose();
  });
}

NotificationEntity _alert(
  String id, {
  String? title,
  NotificationCategory category = NotificationCategory.social,
  bool isRead = false,
  int minutesAgo = 5,
  Map<String, dynamic> metadata = const <String, dynamic>{},
}) =>
    NotificationEntity(
      id: id,
      title: title ?? 'Alert $id',
      message: 'Amapiano • 3:20',
      category: category,
      metadata: metadata,
      createdAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
      isRead: isRead,
    );
