import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_entity.dart';
import 'package:vhunambi_client/features/notifications/domain/services/onboarding_notifications_service.dart';
import 'package:vhunambi_client/features/notifications/presentation/providers/notifications_provider.dart';

/// T11.2 — Notifications provider suite.
NotificationEntity _notification(
  String id, {
  bool isRead = false,
  DateTime? createdAt,
}) => NotificationEntity(
  id: id,
  title: 'Title $id',
  message: 'Message $id',
  createdAt: createdAt ?? DateTime(2026, 9, 26, 14, 0),
  isRead: isRead,
);

void main() {
  test(
    'beginner onboarding builder produces 3 authentic unread milestones',
    () {
      final dna = CreatorDnaProfile(
        userId: 'creator_ndugelo',
        creativeRole: CreativeRole.producer,
        genreWeights: const <String, double>{'Amapiano': 1.0},
        languageWeights: const <String, double>{'Tshivenḓa': 1.5},
        primaryLanguage: 'Tshivenḓa',
        moodWeights: const <String, double>{'Soulful': 1.0},
        onboardingCompleted: true,
        onboardingCompleteness: 0.16,
        createdAt: DateTime(2026, 11, 16),
        lastUpdatedAt: DateTime(2026, 11, 16),
      );
      final milestones =
          OnboardingNotificationsService.buildBeginnerNotifications(
            creatorId: 'creator_ndugelo',
            handle: '@ndugelo',
            dnaProfile: dna,
          );
      expect(milestones, hasLength(3));
      expect(milestones.every((n) => !n.isRead), isTrue);
      expect(milestones.map((n) => n.subtype).toList(), <String?>[
        'monthly_quota',
        'dna_calibration',
        'welcome',
      ]);
    },
  );

  test(
    'the provider starts empty so Phase 10 dispatch stays authoritative',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(notificationsProvider), isEmpty);
      expect(container.read(unreadNotificationsCountProvider), 0);
    },
  );

  test('addNotification prepends newest-first', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(notificationsProvider.notifier);
    notifier.addNotification(_notification('a'));
    notifier.addNotification(_notification('b'));

    expect(
      container.read(notificationsProvider).map((n) => n.id).toList(),
      <String>['b', 'a'],
    );
  });

  test('the update adapter mirrors the Phase 10 StateProvider contract', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(notificationsProvider.notifier);
    notifier.update(
      (list) => <NotificationEntity>[_notification('x'), ...list],
    );

    expect(container.read(notificationsProvider).single.id, 'x');
  });

  test('markAsRead flips a single entry', () {
    final container = ProviderContainer(
      overrides: <Override>[
        notificationsProvider.overrideWith(
          (ref) => NotificationsNotifier(<NotificationEntity>[
            _notification('a'),
            _notification('b'),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(notificationsProvider.notifier).markAsRead('a');

    final list = container.read(notificationsProvider);
    expect(list.firstWhere((n) => n.id == 'a').isRead, isTrue);
    expect(list.firstWhere((n) => n.id == 'b').isRead, isFalse);
  });

  test('markAllAsRead clears every unread flag', () {
    final container = ProviderContainer(
      overrides: <Override>[
        notificationsProvider.overrideWith(
          (ref) => NotificationsNotifier(<NotificationEntity>[
            _notification('a'),
            _notification('b'),
            _notification('c', isRead: true),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(notificationsProvider.notifier).markAllAsRead();

    expect(
      container.read(notificationsProvider).every((n) => n.isRead),
      isTrue,
    );
    expect(container.read(unreadNotificationsCountProvider), 0);
  });

  test('removeNotification drops a single entry', () {
    final container = ProviderContainer(
      overrides: <Override>[
        notificationsProvider.overrideWith(
          (ref) => NotificationsNotifier(<NotificationEntity>[
            _notification('a'),
            _notification('b'),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(notificationsProvider.notifier).removeNotification('a');

    expect(
      container.read(notificationsProvider).map((n) => n.id).toList(),
      <String>['b'],
    );
  });

  test('clearAll empties the list', () {
    final container = ProviderContainer(
      overrides: <Override>[
        notificationsProvider.overrideWith(
          (ref) => NotificationsNotifier(<NotificationEntity>[
            _notification('a'),
            _notification('b'),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(notificationsProvider.notifier).clearAll();

    expect(container.read(notificationsProvider), isEmpty);
    expect(container.read(unreadNotificationsCountProvider), 0);
  });

  test('unreadNotificationsCountProvider tracks unread entries reactively', () {
    final container = ProviderContainer(
      overrides: <Override>[
        notificationsProvider.overrideWith(
          (ref) => NotificationsNotifier(<NotificationEntity>[
            _notification('a'),
            _notification('b'),
            _notification('c', isRead: true),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(unreadNotificationsCountProvider), 2);

    container.read(notificationsProvider.notifier).markAsRead('a');
    expect(container.read(unreadNotificationsCountProvider), 1);

    container
        .read(notificationsProvider.notifier)
        .addNotification(_notification('d'));
    expect(container.read(unreadNotificationsCountProvider), 2);

    container.read(notificationsProvider.notifier).clearAll();
    expect(container.read(unreadNotificationsCountProvider), 0);
  });

  test('unreadNotificationsCountProvider ignores read entries', () {
    final container = ProviderContainer(
      overrides: <Override>[
        notificationsProvider.overrideWith(
          (ref) => NotificationsNotifier(<NotificationEntity>[
            _notification('a', isRead: true),
            _notification('b', isRead: true),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(unreadNotificationsCountProvider), 0);
  });
}
