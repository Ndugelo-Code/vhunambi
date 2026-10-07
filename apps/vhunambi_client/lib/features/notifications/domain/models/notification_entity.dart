import 'package:flutter/foundation.dart';

/// In-app notification entry (T10.6).
///
/// Prepended to `notificationsProvider` when a generation pipeline completes.
@immutable
class NotificationEntity {
  final String id;
  final String title;
  final String message;

  /// Deep-link target for the notification tap (`/track/:id`).
  final String? targetTrackId;

  final DateTime createdAt;
  final bool isRead;

  const NotificationEntity({
    required this.id,
    required this.title,
    required this.message,
    this.targetTrackId,
    required this.createdAt,
    this.isRead = false,
  });

  /// Title pattern used when a render finishes: `Your song "<title>" is ready!`
  factory NotificationEntity.generationReady({
    required String trackId,
    required String trackTitle,
    required String message,
    DateTime? createdAt,
  }) {
    return NotificationEntity(
      id: trackId,
      title: 'Your song "$trackTitle" is ready!',
      message: message,
      targetTrackId: trackId,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  NotificationEntity copyWith({
    String? id,
    String? title,
    String? message,
    String? targetTrackId,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      targetTrackId: targetTrackId ?? this.targetTrackId,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isRead == other.isRead;

  @override
  int get hashCode => Object.hash(id, isRead);

  @override
  String toString() => 'NotificationEntity($id, isRead: $isRead)';
}
