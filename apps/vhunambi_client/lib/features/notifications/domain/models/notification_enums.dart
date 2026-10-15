/// Notification taxonomy for the Accessible Notifications Center (M8).
///
/// Hand-rolled (zero `build_runner` / `@HiveType`) domain primitives that
/// extend the legacy [NotificationEntity] surface with category-driven
/// classification, priority ranking and contextual actions.
library;

/// Four canonical notification categories driving the filter rail and badges.
///
/// Each maps to a distinct `AppColors` accent token:
/// - `social` → `AppColors.accentElectric`
/// - `system` → `AppColors.accentGold`
/// - `creatorActivity` → `AppColors.brandPrimary`
/// - `algorithmic` → `AppColors.accentSuccess`
enum NotificationCategory {
  /// Follows, tips, comments, mentions, remixes, collaborations.
  social,

  /// Credits, terms, app updates, security, subscription, quota.
  system,

  /// Generation ready, stem separation, export complete.
  creatorActivity,

  /// DNA-ranked recommendations, trending packs, weekly recaps.
  algorithmic;

  /// Parses a serialized category [name], defaulting to [creatorActivity].
  static NotificationCategory fromString(String? value) {
    return NotificationCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => NotificationCategory.creatorActivity,
    );
  }
}

/// Relative urgency used for sorting, badges and haptic choreography.
enum NotificationPriority {
  low,
  normal,
  high,
  urgent;

  /// Parses a serialized priority [name], defaulting to [normal].
  static NotificationPriority fromString(String? value) {
    return NotificationPriority.values.firstWhere(
      (p) => p.name == value,
      orElse: () => NotificationPriority.normal,
    );
  }

  /// Numeric weight (higher = more urgent) for stable priority sorting.
  int get weight => switch (this) {
        NotificationPriority.low => 0,
        NotificationPriority.normal => 1,
        NotificationPriority.high => 2,
        NotificationPriority.urgent => 3,
      };

  /// Whether this priority should trigger the ringing bell wobble on arrival.
  bool get isEscalated =>
      this == NotificationPriority.high || this == NotificationPriority.urgent;
}

/// Semantic kind of a contextual [NotificationAction].
enum NotificationActionType {
  /// Navigate to an in-app route (deep link).
  navigate,

  /// Invoke a backend / side-effecting API call.
  apiCall,

  /// Open the native share sheet.
  shareSheet,

  /// Present an in-app dialog / bottom sheet.
  dialog;

  static NotificationActionType fromString(String? value) {
    return NotificationActionType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => NotificationActionType.navigate,
    );
  }
}

/// A contextual, tappable affordance attached to a notification card
/// (e.g. `"Audition ▶"`, `"Export 9:16"`, `"Reply"`).
class NotificationAction {
  final String actionId;
  final String label;
  final NotificationActionType actionType;

  /// Arbitrary payload (e.g. `{'route': '/track/123'}`).
  final Map<String, dynamic> actionData;

  const NotificationAction({
    required this.actionId,
    required this.label,
    this.actionType = NotificationActionType.navigate,
    this.actionData = const <String, dynamic>{},
  });

  /// Hand-rolled JSON mapping (zero codegen).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'actionId': actionId,
        'label': label,
        'actionType': actionType.name,
        'actionData': actionData,
      };

  factory NotificationAction.fromJson(Map<String, dynamic> json) {
    return NotificationAction(
      actionId: json['actionId'] as String? ?? '',
      label: json['label'] as String? ?? '',
      actionType: NotificationActionType.fromString(
        json['actionType'] as String?,
      ),
      actionData: Map<String, dynamic>.from(
        (json['actionData'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationAction &&
          runtimeType == other.runtimeType &&
          actionId == other.actionId &&
          label == other.label &&
          actionType == other.actionType;

  @override
  int get hashCode => Object.hash(actionId, label, actionType);
}
