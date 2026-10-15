import 'package:flutter/foundation.dart';
import 'notification_enums.dart';

/// In-app notification entry (T10.6).
///
/// Prepended to `notificationsProvider` when a generation pipeline completes.
///
/// Phase 3 (M8) extends the legacy surface with [category], [priority],
/// [metadata] and contextual [actions] while preserving every existing field,
/// factory and the `id`+`isRead` equality contract so downstream code and the
/// 911-test baseline remain untouched.
@immutable
class NotificationEntity {
  final String id;
  final String title;
  final String message;

  /// Deep-link target for the notification tap (`/track/:id`).
  final String? targetTrackId;

  final DateTime createdAt;
  final bool isRead;

  /// Category driving the filter rail, badge glyph and accent color.
  /// Defaults to [NotificationCategory.creatorActivity] for backward compat.
  final NotificationCategory category;

  /// Relative urgency used for sorting and haptic escalation.
  final NotificationPriority priority;

  /// Optional structured payload, e.g.
  /// `{'genre': 'Amapiano', 'deepLinkRoute': '/track/123'}`.
  final Map<String, dynamic> metadata;

  /// Optional contextual action rail (label + route/api/share/dialog).
  final List<NotificationAction> actions;

  const NotificationEntity({
    required this.id,
    required this.title,
    required this.message,
    this.targetTrackId,
    required this.createdAt,
    this.isRead = false,
    this.category = NotificationCategory.creatorActivity,
    this.priority = NotificationPriority.normal,
    this.metadata = const <String, dynamic>{},
    this.actions = const <NotificationAction>[],
  });

  /// Title pattern used when a render finishes: `Your song "<title>" is ready!`
  ///
  /// Phase 3 wires the new schema: [NotificationCategory.creatorActivity],
  /// [NotificationPriority.high], and a `deepLinkRoute` metadata entry while
  /// preserving the legacy `targetTrackId`.
  factory NotificationEntity.generationReady({
    required String trackId,
    required String trackTitle,
    required String message,
    DateTime? createdAt,
    NotificationPriority priority = NotificationPriority.high,
  }) {
    return NotificationEntity(
      id: trackId,
      title: 'Your song "$trackTitle" is ready!',
      message: message,
      targetTrackId: trackId,
      createdAt: createdAt ?? DateTime.now(),
      category: NotificationCategory.creatorActivity,
      priority: priority,
      metadata: <String, dynamic>{
        'trackId': trackId,
        'trackTitle': trackTitle,
        'deepLinkRoute': '/track/$trackId',
      },
    );
  }

  NotificationEntity copyWith({
    String? id,
    String? title,
    String? message,
    String? targetTrackId,
    DateTime? createdAt,
    bool? isRead,
    NotificationCategory? category,
    NotificationPriority? priority,
    Map<String, dynamic>? metadata,
    List<NotificationAction>? actions,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      targetTrackId: targetTrackId ?? this.targetTrackId,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      metadata: metadata ?? this.metadata,
      actions: actions ?? this.actions,
    );
  }

  /// Hand-rolled JSON serialization (zero build_runner / hive_generator).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'message': message,
        'targetTrackId': targetTrackId,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
        'category': category.name,
        'priority': priority.name,
        'metadata': metadata,
        'actions': actions.map((a) => a.toJson()).toList(),
      };

  /// Restores an entity from [toJson] output with defensive defaults so a
  /// malformed persisted record never crashes the read path.
  factory NotificationEntity.fromJson(Map<String, dynamic> json) {
    return NotificationEntity(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      targetTrackId: json['targetTrackId'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      category: NotificationCategory.fromString(json['category'] as String?),
      priority: NotificationPriority.fromString(json['priority'] as String?),
      metadata: Map<String, dynamic>.from(
        (json['metadata'] as Map?) ?? const <String, dynamic>{},
      ),
      actions: ((json['actions'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map(
            (a) => NotificationAction.fromJson(Map<String, dynamic>.from(a)),
          )
          .toList(),
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

