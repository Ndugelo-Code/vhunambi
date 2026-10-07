import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_entity.dart';

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
