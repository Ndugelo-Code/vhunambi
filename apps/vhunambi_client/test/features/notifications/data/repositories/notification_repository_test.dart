import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/features/notifications/data/repositories/notification_repository.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_entity.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_enums.dart';

/// M8 — NotificationRepository suite (Hive persistence + in-memory fallback).
void main() {
  group('NotificationRepository (Hive-backed)', () {
    late Directory tempDir;
    late Box hiveBox;
    late NotificationRepository repository;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vhunambi_notifications_');
      Hive.init(tempDir.path);
      hiveBox = await Hive.openBox(AppConstants.notificationsBoxKey);
      repository = NotificationRepository(hiveBox);
    });

    tearDown(() async {
      await hiveBox.close();
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('getNotifications returns an empty list when nothing is stored',
        () async {
      expect(await repository.getNotifications(), isEmpty);
    });

    test('saveNotification persists and returns newest-first', () async {
      await repository.saveNotification(_alert('a', minutesAgo: 30));
      await repository.saveNotification(_alert('b', minutesAgo: 5));

      final loaded = await repository.getNotifications();
      expect(loaded.map((n) => n.id), <String>['b', 'a']);
    });

    test('saveNotifications upserts by id (replace, not duplicate)', () async {
      await repository.saveNotification(_alert('a'));
      await repository.saveNotification(_alert('a', isRead: true));

      final loaded = await repository.getNotifications();
      expect(loaded, hasLength(1));
      expect(loaded.single.isRead, isTrue);
    });

    test('deleteNotification removes a single entry by id', () async {
      await repository.saveNotifications([_alert('a'), _alert('b')]);

      await repository.deleteNotification('a');

      final loaded = await repository.getNotifications();
      expect(loaded.map((n) => n.id), <String>['b']);
    });

    test('clearAll wipes the entire collection', () async {
      await repository.saveNotifications([_alert('a'), _alert('b')]);
      expect(await repository.getNotifications(), hasLength(2));

      await repository.clearAll();

      expect(await repository.getNotifications(), isEmpty);
    });

    test('JSON serialization round-trip preserves every field', () async {
      final original = NotificationEntity(
        id: 'round_trip',
        title: 'Stem separation complete',
        message: 'Vocals • Drums • Log Drum',
        targetTrackId: 'trk_rt',
        createdAt: DateTime(2026, 10, 14, 12, 0),
        isRead: true,
        category: NotificationCategory.creatorActivity,
        priority: NotificationPriority.urgent,
        metadata: const <String, dynamic>{'genre': 'Amapiano', 'n': 3},
        actions: const <NotificationAction>[
          NotificationAction(
            actionId: 'audition',
            label: 'Audition',
            actionType: NotificationActionType.navigate,
            actionData: <String, dynamic>{'route': '/track/trk_rt'},
          ),
        ],
      );

      await repository.saveNotification(original);
      final loaded = (await repository.getNotifications()).single;

      expect(loaded.id, original.id);
      expect(loaded.title, original.title);
      expect(loaded.message, original.message);
      expect(loaded.targetTrackId, original.targetTrackId);
      expect(loaded.isRead, original.isRead);
      expect(loaded.category, NotificationCategory.creatorActivity);
      expect(loaded.priority, NotificationPriority.urgent);
      expect(loaded.metadata['genre'], 'Amapiano');
      expect(loaded.metadata['n'], 3);
      expect(loaded.actions, hasLength(1));
      expect(loaded.actions.single.label, 'Audition');
      expect(loaded.actions.single.actionType, NotificationActionType.navigate);
      expect(loaded.createdAt, original.createdAt);
    });

    test('enforces the 500-notification ceiling', () async {
      final many = List<NotificationEntity>.generate(
        505,
        (i) => _alert('n_$i', minutesAgo: 1000 + i, isRead: true),
      );
      await repository.saveNotifications(many);

      expect((await repository.getNotifications()).length,
          lessThanOrEqualTo(NotificationRepository.maxNotifications));
    });
  });

  group('NotificationRepository (in-memory fallback)', () {
    test('operates cleanly with no Hive box injected', () async {
      final repository = NotificationRepository();

      await repository.saveNotification(_alert('mem_a'));
      await repository.saveNotification(_alert('mem_b'));

      final loaded = await repository.getNotifications();
      expect(loaded.map((n) => n.id), containsAll(<String>['mem_a', 'mem_b']));

      await repository.deleteNotification('mem_a');
      expect((await repository.getNotifications()).map((n) => n.id),
          <String>['mem_b']);

      await repository.clearAll();
      expect(await repository.getNotifications(), isEmpty);
    });

    test('getNotifications never throws and degrades to empty', () async {
      final repository = NotificationRepository();
      expect(await repository.getNotifications(), isEmpty);
    });
  });
}

NotificationEntity _alert(
  String id, {
  int minutesAgo = 5,
  bool isRead = false,
}) =>
    NotificationEntity(
      id: id,
      title: 'Alert $id',
      message: 'Amapiano • 3:20',
      targetTrackId: 'trk_$id',
      createdAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
      isRead: isRead,
    );
