import 'package:flutter/foundation.dart';
import 'notification_enums.dart';

/// In-app notification entry (T10.6 / Phase 67).
@immutable
class NotificationEntity {
  final String id;
  final String title;
  final String message;

  /// Legacy deep-link track target (`/track/:id`).
  final String? targetTrackId;

  final DateTime createdAt;
  final bool isRead;

  /// Category driving the filter rail, badge glyph, and accent color.
  final NotificationCategory category;

  /// Relative urgency used for sorting and haptic escalation.
  final NotificationPriority priority;

  /// Semantic subtype driving the 5-color studio palette & pill label
  /// (e.g. `'welcome'`, `'dna_calibration'`, `'monthly_quota'`,
  /// `'studio_render'`, `'reel_love'`, `'repost'`, `'comment'`, `'gift'`).
  final String? subtype;

  /// Canonical deep-link route (`/studio`, `/creator-dna`, `/wallet`,
  /// `/track/:id`, `/reel/:clipId`, `/creator/:id`).
  final String? targetRoute;

  /// Optional entity identifier for route parameters.
  final String? targetEntityId;

  /// Primary CTA button label rendered inside detail views / cards.
  final String? ctaLabel;

  /// Optional structured payload.
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
    this.subtype,
    this.targetRoute,
    this.targetEntityId,
    this.ctaLabel,
    this.metadata = const <String, dynamic>{},
    this.actions = const <NotificationAction>[],
  });

  /// Effective route resolved from explicit [targetRoute], [metadata], or [targetTrackId].
  String? get effectiveRoute {
    if (targetRoute != null && targetRoute!.trim().isNotEmpty) {
      return targetRoute!.trim();
    }
    final metaRoute =
        metadata['deepLinkRoute'] as String? ??
        metadata['targetRoute'] as String?;
    if (metaRoute != null && metaRoute.trim().isNotEmpty) {
      return metaRoute.trim();
    }
    final trackId = targetTrackId ?? metadata['trackId'] as String?;
    if (trackId != null && trackId.trim().isNotEmpty) {
      return '/track/${trackId.trim()}';
    }
    return null;
  }

  /// Whether tapping this card should open `NotificationDetailBottomSheet` first
  /// so the creator can inspect the milestone/quota breakdown before jumping.
  bool get opensDetailSheetFirst {
    return switch (subtype) {
      'welcome' ||
      'dna_calibration' ||
      'monthly_quota' ||
      'credits' ||
      'reel_render' ||
      'social_share' => true,
      _ => effectiveRoute == null,
    };
  }

  /// Title pattern used when a render finishes: `Your song "<title>" is ready!`
  factory NotificationEntity.generationReady({
    required String trackId,
    required String trackTitle,
    required String message,
    DateTime? createdAt,
    NotificationPriority priority = NotificationPriority.high,
    Map<String, dynamic>? extraMetadata,
  }) {
    return NotificationEntity(
      id: trackId,
      title: 'Your song "$trackTitle" is ready!',
      message: message,
      targetTrackId: trackId,
      targetEntityId: trackId,
      targetRoute: '/track/$trackId',
      subtype: 'studio_render',
      ctaLabel: 'Open Track Cockpit',
      createdAt: createdAt ?? DateTime.now(),
      category: NotificationCategory.creatorActivity,
      priority: priority,
      metadata: <String, dynamic>{
        'trackId': trackId,
        'trackTitle': trackTitle,
        'deepLinkRoute': '/track/$trackId',
        ...?extraMetadata,
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
    String? subtype,
    String? targetRoute,
    String? targetEntityId,
    String? ctaLabel,
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
      subtype: subtype ?? this.subtype,
      targetRoute: targetRoute ?? this.targetRoute,
      targetEntityId: targetEntityId ?? this.targetEntityId,
      ctaLabel: ctaLabel ?? this.ctaLabel,
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
    'subtype': subtype,
    'targetRoute': targetRoute,
    'targetEntityId': targetEntityId,
    'ctaLabel': ctaLabel,
    'metadata': metadata,
    'actions': actions.map((a) => a.toJson()).toList(),
  };

  /// Restores an entity from [toJson] output with defensive defaults so a
  /// malformed persisted record never crashes the read path.
  factory NotificationEntity.fromJson(Map<String, dynamic> json) {
    final meta = Map<String, dynamic>.from(
      (json['metadata'] as Map?) ?? const <String, dynamic>{},
    );
    return NotificationEntity(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      targetTrackId: json['targetTrackId'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      category: NotificationCategory.fromString(json['category'] as String?),
      priority: NotificationPriority.fromString(json['priority'] as String?),
      subtype: json['subtype'] as String? ?? meta['subtype'] as String?,
      targetRoute:
          json['targetRoute'] as String? ?? meta['targetRoute'] as String?,
      targetEntityId:
          json['targetEntityId'] as String? ??
          meta['targetEntityId'] as String?,
      ctaLabel: json['ctaLabel'] as String? ?? meta['ctaLabel'] as String?,
      metadata: meta,
      actions: ((json['actions'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((a) => NotificationAction.fromJson(Map<String, dynamic>.from(a)))
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isRead == other.isRead &&
          category == other.category &&
          subtype == other.subtype &&
          title == other.title &&
          message == other.message &&
          targetRoute == other.targetRoute;

  @override
  int get hashCode =>
      Object.hash(id, isRead, category, subtype, title, message, targetRoute);

  @override
  String toString() =>
      'NotificationEntity($id, category: ${category.name}, subtype: $subtype, isRead: $isRead)';
}
