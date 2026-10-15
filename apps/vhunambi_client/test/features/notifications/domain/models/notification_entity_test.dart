import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_entity.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_enums.dart';

/// T10.6 — In-app notification entity suite.
void main() {
  test('defaults to unread', () {
    final notification = _notification();

    expect(notification.isRead, isFalse);
    expect(notification.id, 'trk_pipeline_001');
    expect(notification.title, 'Your song "rave" is ready!');
    expect(notification.message, 'Gqom • 3:29');
    expect(notification.targetTrackId, 'trk_pipeline_001');
    expect(notification.createdAt, DateTime(2026, 9, 26, 14, 30));
  });

  test('copyWith marks the notification read', () {
    final read = _notification().copyWith(isRead: true);

    expect(read.isRead, isTrue);
    expect(read.id, 'trk_pipeline_001');
    expect(read, isNot(_notification()));
  });

  test('equality is keyed on id and read state', () {
    final notification = _notification();

    expect(notification, _notification());
    expect(notification.hashCode, _notification().hashCode);
    expect(notification, isNot(_notification(isRead: true)));
    expect(notification.toString(), contains('trk_pipeline_001'));
  });

  test('equality is false when only the read state differs', () {
    expect(_notification() == _notification(isRead: true), isFalse);
  });

  test('targetTrackId is nullable and settable through copyWith', () {
    final orphan = NotificationEntity(
      id: 'note_1',
      title: 'Vhunambi update',
      message: 'New genres available.',
      createdAt: DateTime(2026, 9, 26),
    );

    expect(orphan.targetTrackId, isNull);
    expect(orphan.copyWith(targetTrackId: 'trk_9').targetTrackId, 'trk_9');
    expect(orphan.copyWith().targetTrackId, isNull);
  });

  test('generationReady builds the pipeline completion copy', () {
    final notification = NotificationEntity.generationReady(
      trackId: 'trk_pipeline_001',
      trackTitle: 'rave',
      message: 'Gqom • 3:29',
      createdAt: DateTime(2026, 9, 26, 15),
    );

    expect(notification.title, 'Your song "rave" is ready!');
    expect(notification.targetTrackId, 'trk_pipeline_001');
    expect(notification.createdAt, DateTime(2026, 9, 26, 15));
    expect(notification.isRead, isFalse);
  });

  test('defaults category to creatorActivity and priority to normal', () {
    final notification = _notification();

    expect(notification.category, NotificationCategory.creatorActivity);
    expect(notification.priority, NotificationPriority.normal);
    expect(notification.metadata, isEmpty);
    expect(notification.actions, isEmpty);
  });

  test('copyWith carries the new schema fields', () {
    final updated = _notification().copyWith(
      category: NotificationCategory.social,
      priority: NotificationPriority.urgent,
      metadata: const <String, dynamic>{'genre': 'Amapiano'},
    );

    expect(updated.category, NotificationCategory.social);
    expect(updated.priority, NotificationPriority.urgent);
    expect(updated.metadata['genre'], 'Amapiano');
    // Legacy fields preserved.
    expect(updated.id, 'trk_pipeline_001');
    expect(updated.isRead, isFalse);
  });

  test('generationReady seeds category, priority and metadata', () {
    final notification = NotificationEntity.generationReady(
      trackId: 'trk_pipeline_001',
      trackTitle: 'rave',
      message: 'Gqom • 3:29',
    );

    expect(notification.category, NotificationCategory.creatorActivity);
    expect(notification.priority, NotificationPriority.high);
    expect(notification.metadata['trackId'], 'trk_pipeline_001');
    expect(notification.metadata['deepLinkRoute'], '/track/trk_pipeline_001');
  });

  test('toJson / fromJson round-trips every field', () {
    final original = NotificationEntity(
      id: 'json_1',
      title: 'Tip received',
      message: '@lerato tipped you 50 credits',
      targetTrackId: 'trk_json',
      createdAt: DateTime(2026, 10, 14, 9, 30),
      isRead: true,
      category: NotificationCategory.social,
      priority: NotificationPriority.high,
      metadata: const <String, dynamic>{'genre': 'Amapiano', 'amount': 50},
      actions: const <NotificationAction>[
        NotificationAction(
          actionId: 'reply',
          label: 'Reply',
          actionType: NotificationActionType.navigate,
        ),
      ],
    );

    final restored = NotificationEntity.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.title, original.title);
    expect(restored.message, original.message);
    expect(restored.targetTrackId, original.targetTrackId);
    expect(restored.createdAt, original.createdAt);
    expect(restored.isRead, original.isRead);
    expect(restored.category, NotificationCategory.social);
    expect(restored.priority, NotificationPriority.high);
    expect(restored.metadata['genre'], 'Amapiano');
    expect(restored.metadata['amount'], 50);
    expect(restored.actions, hasLength(1));
    expect(restored.actions.single.actionId, 'reply');
  });

  test('fromJson applies safe defaults for malformed payloads', () {
    final restored = NotificationEntity.fromJson(<String, dynamic>{});

    expect(restored.id, '');
    expect(restored.title, '');
    expect(restored.isRead, isFalse);
    expect(restored.category, NotificationCategory.creatorActivity);
    expect(restored.priority, NotificationPriority.normal);
    expect(restored.actions, isEmpty);
  });
}

/// Private top-level fixture (underscore-prefixed identifiers are only linted
/// for locals).
NotificationEntity _notification({bool isRead = false}) => NotificationEntity(
      id: 'trk_pipeline_001',
      title: 'Your song "rave" is ready!',
      message: 'Gqom • 3:29',
      targetTrackId: 'trk_pipeline_001',
      createdAt: DateTime(2026, 9, 26, 14, 30),
      isRead: isRead,
    );
