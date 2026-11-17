# Phase 67 Design Specification: Notifications Center Two-Pass Overhaul

**Document ID:** `VHUNAMBI-SPEC-P67-DESIGN-V1`  
**Phase:** `Phase 67` (`phase_67_notifications_center_two_pass_overhaul`)  
**Companion Docs:** [`blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_67_notifications_center_two_pass_overhaul/blueprint.md) · [`requirements.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_67_notifications_center_two_pass_overhaul/requirements.md)

---

## 1. Domain Model & Onboarding Milestone Service (`M67.1` — Overhaul Pass 1)

### 1.1 Extended `NotificationEntity` (`apps/vhunambi_client/lib/features/notifications/domain/models/notification_entity.dart`)

Extends `NotificationEntity` with `subtype`, `targetRoute`, `targetEntityId`, and `ctaLabel` while preserving every existing constructor parameter, `generationReady` factory, and `JsonSafe`-compatible serialization.

```dart
import 'package:flutter/foundation.dart';
import 'notification_enums.dart';

@immutable
class NotificationEntity {
  final String id;
  final String title;
  final String message;

  /// Legacy track deep-link target (`/track/:id`).
  final String? targetTrackId;

  final DateTime createdAt;
  final bool isRead;
  final NotificationCategory category;
  final NotificationPriority priority;

  /// Semantic subtype driving the 5-color studio palette & pill label
  /// (e.g. `'welcome'`, `'dna_calibration'`, `'monthly_quota'`, `'studio_render'`,
  /// `'reel_love'`, `'repost'`, `'comment'`, `'gift'`, `'follow'`).
  final String? subtype;

  /// Canonical deep-link route (`/studio`, `/creator-dna`, `/wallet`,
  /// `/track/:id`, `/reel/:clipId`, `/creator/:id`).
  final String? targetRoute;

  /// Optional entity identifier for route parameters.
  final String? targetEntityId;

  /// Primary CTA button label inside [NotificationDetailBottomSheet].
  final String? ctaLabel;

  final Map<String, dynamic> metadata;
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
    final metaRoute = metadata['deepLinkRoute'] as String? ??
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

  /// Whether tapping this card should open [NotificationDetailBottomSheet] first
  /// so the creator can inspect the milestone/quota breakdown before jumping.
  bool get opensDetailSheetFirst {
    return switch (subtype) {
      'welcome' ||
      'dna_calibration' ||
      'monthly_quota' ||
      'credits' ||
      'reel_render' ||
      'social_share' =>
        true,
      _ => effectiveRoute == null,
    };
  }

  factory NotificationEntity.generationReady({
    required String trackId,
    required String trackTitle,
    required String message,
    DateTime? createdAt,
    NotificationPriority priority = NotificationPriority.high,
    Map<String, dynamic>? extraMetadata,
  }) {
    return NotificationEntity(
      id: trackId.startsWith('notif_') ? trackId : 'notif_gen_$trackId',
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

  factory NotificationEntity.fromJson(Map<String, dynamic> json) {
    final meta = Map<String, dynamic>.from(
      (json['metadata'] as Map?) ?? const <String, dynamic>{},
    );
    return NotificationEntity(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      targetTrackId: json['targetTrackId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      category: NotificationCategory.fromString(json['category'] as String?),
      priority: NotificationPriority.fromString(json['priority'] as String?),
      subtype: json['subtype'] as String? ?? meta['subtype'] as String?,
      targetRoute:
          json['targetRoute'] as String? ?? meta['targetRoute'] as String?,
      targetEntityId: json['targetEntityId'] as String? ??
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
  int get hashCode => Object.hash(
        id,
        isRead,
        category,
        subtype,
        title,
        message,
        targetRoute,
      );

  @override
  String toString() =>
      'NotificationEntity($id, category: ${category.name}, subtype: $subtype, isRead: $isRead)';
}
```

---

### 1.2 `OnboardingNotificationsService` (`apps/vhunambi_client/lib/features/notifications/domain/services/onboarding_notifications_service.dart`)

Computes dynamic starter DNA completeness ($C_{\text{starter}} \in [0.14, 0.26] \implies \text{strengthPercent} \in [6\%, 10\%]$) and idempotently builds & seeds the 3 authentic beginner notifications per `creatorId`.

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import 'package:vhunambi_client/features/creator_dna/presentation/providers/creator_dna_provider.dart';
import '../../presentation/providers/notifications_provider.dart';
import '../models/notification_entity.dart';
import '../models/notification_enums.dart';

/// Idempotent generator for the 3 authentic beginner onboarding notifications
/// (`Welcome`, `Creator DNA Calibrated at 6%–10%`, `10 Free Monthly Songs`).
abstract final class OnboardingNotificationsService {
  static const String _seededKeyPrefix = 'onboarding_notifs_seeded_v1_';
  static final Set<String> _inMemorySeededCreators = <String>{};

  /// Computes starter onboarding completeness in `[0.14, 0.26]` so a brand-new
  /// user's [CreatorDnaProfile.strengthPercent] evaluates naturally in `6%–10%`
  /// prior to vocal clone and reference track calibration (`REQ-P67-ONB-01`).
  static double computeStarterCompleteness({
    required int genreCount,
    required int languageCount,
    required int moodCount,
  }) {
    final g = genreCount.clamp(1, 3) * 0.02;
    final l = languageCount.clamp(1, 2) * 0.02;
    final m = moodCount.clamp(1, 2) * 0.02;
    return (0.10 + g + l + m).clamp(0.14, 0.26);
  }

  /// Resolves a bounded `6%–10%` starter calibration percentage from [dna].
  static int resolveStarterDnaPercent(CreatorDnaProfile dna) {
    final raw = dna.strengthPercent;
    if (dna.totalBehaviorEvents == 0) {
      return raw.clamp(6, 10);
    }
    return raw.clamp(6, 100);
  }

  /// Builds the 3 canonical beginner onboarding notifications for [creatorId].
  static List<NotificationEntity> buildBeginnerNotifications({
    required String creatorId,
    required String handle,
    required CreatorDnaProfile dnaProfile,
    int freeSongsTotal = 10,
    int freeSongsRemaining = 10,
    DateTime? now,
  }) {
    final baseTime = now ?? DateTime.now();
    final cleanCid = creatorId.trim().isEmpty ? 'creator_cern' : creatorId.trim();
    final cleanHandle = handle.trim().isEmpty
        ? '@creator'
        : (handle.trim().startsWith('@') ? handle.trim() : '@${handle.trim()}');
    final dnaPct = resolveStarterDnaPercent(dnaProfile);

    final genres = dnaProfile.topGenres(3);
    final recordedTraits = <String>[
      'Role: ${dnaProfile.creativeRole.label}',
      'Primary Language: ${dnaProfile.primaryLanguage}',
      if (genres.isNotEmpty) 'Starter Genres: ${genres.join(', ')}',
      'Tempo & Energy: ${dnaProfile.tempoPreference} / ${dnaProfile.vocalEnergyPreference}',
    ];
    const uncalibratedTraits = <String>[
      'Zero-Shot Vocal Clone Calibration (0/3 phrases)',
      'Reference Audio Track Dropzone Conditioning',
      'Studio Generation & Stem Mixing Telemetry',
    ];

    return <NotificationEntity>[
      // 1. Free Plan Monthly Song Allowance (Newest — top of inbox)
      NotificationEntity(
        id: 'notif_onboard_quota_$cleanCid',
        title: '$freeSongsTotal Free Monthly Song Generations Ready',
        message:
            'Your Free Creator account includes $freeSongsTotal AI song generations per month. Each full track uses 1 generation credit from your monthly allowance.',
        category: NotificationCategory.system,
        priority: NotificationPriority.high,
        subtype: 'monthly_quota',
        targetRoute: '/wallet',
        ctaLabel: 'View Balance & Usage',
        createdAt: baseTime,
        isRead: false,
        metadata: <String, dynamic>{
          'subtype': 'monthly_quota',
          'targetRoute': '/wallet',
          'ctaLabel': 'View Balance & Usage',
          'freeSongsTotal': freeSongsTotal,
          'freeSongsRemaining': freeSongsRemaining,
          'planTier': 'Free Creator',
        },
      ),

      // 2. Initial Creator DNA Calibration (6%–10% Emerald Teal)
      NotificationEntity(
        id: 'notif_onboard_dna_$cleanCid',
        title: 'Creator DNA Calibrated at $dnaPct%',
        message:
            'Your foundational sound identity is recorded. Complete vocal calibration and add reference tracks to unlock deeper personalization.',
        category: NotificationCategory.system,
        priority: NotificationPriority.high,
        subtype: 'dna_calibration',
        targetRoute: '/creator-dna',
        ctaLabel: 'Calibrate Creator DNA',
        createdAt: baseTime.subtract(const Duration(seconds: 15)),
        isRead: false,
        metadata: <String, dynamic>{
          'subtype': 'dna_calibration',
          'targetRoute': '/creator-dna',
          'ctaLabel': 'Calibrate Creator DNA',
          'dnaPercent': dnaPct,
          'recordedTraits': recordedTraits,
          'uncalibratedTraits': uncalibratedTraits,
        },
      ),

      // 3. System Welcome (Amber Gold)
      NotificationEntity(
        id: 'notif_onboard_welcome_$cleanCid',
        title: 'Welcome to Vhunambi, $cleanHandle',
        message:
            'Your sovereign African music studio is live. Compose original tracks, split stems, and publish kinetic reels.',
        category: NotificationCategory.system,
        priority: NotificationPriority.high,
        subtype: 'welcome',
        targetRoute: '/studio',
        ctaLabel: 'Open Studio Cockpit',
        createdAt: baseTime.subtract(const Duration(seconds: 30)),
        isRead: false,
        metadata: <String, dynamic>{
          'subtype': 'welcome',
          'targetRoute': '/studio',
          'ctaLabel': 'Open Studio Cockpit',
          'username': cleanHandle,
        },
      ),
    ];
  }

  static bool _hasSeededForCreator(String creatorId) {
    final key = '$_seededKeyPrefix$creatorId';
    if (_inMemorySeededCreators.contains(key)) return true;
    try {
      if (Hive.isBoxOpen(AppConstants.prefsBoxKey)) {
        final box = Hive.box<dynamic>(AppConstants.prefsBoxKey);
        return box.get(key) == true;
      }
    } catch (_) {}
    return false;
  }

  static void _markSeededForCreator(String creatorId) {
    final key = '$_seededKeyPrefix$creatorId';
    _inMemorySeededCreators.add(key);
    try {
      if (Hive.isBoxOpen(AppConstants.prefsBoxKey)) {
        Hive.box<dynamic>(AppConstants.prefsBoxKey).put(key, true);
      }
    } catch (_) {}
  }

  /// Clears in-memory seed flags for isolated test runs.
  static void clearForTesting() {
    _inMemorySeededCreators.clear();
  }

  /// Idempotently seeds the 3 beginner onboarding notifications if not yet
  /// seeded for the active creator (`REQ-P67-ONB-02`).
  static void ensureSeededForActiveCreator(
    WidgetRef ref, {
    bool force = false,
  }) {
    final session = ref.read(authSessionProvider);
    final creatorId = session.canonicalCreatorId;
    if (!force && _hasSeededForCreator(creatorId)) return;

    final dna = ref.read(creatorDnaProvider);
    final notifier = ref.read(notificationsProvider.notifier);
    final existingIds = ref.read(notificationsProvider).map((n) => n.id).toSet();

    final milestones = buildBeginnerNotifications(
      creatorId: creatorId,
      handle: session.handle,
      dnaProfile: dna,
    );

    for (final item in milestones.reversed) {
      if (!existingIds.contains(item.id)) {
        notifier.addNotification(item);
      } else if (force) {
        notifier.upsertNotification(item);
      }
    }
    _markSeededForCreator(creatorId);
  }
}
```

---

### 1.3 Clean `NotificationsNotifier` & Legacy Hive Disk Scrubber (`notification_repository.dart`, `notifications_provider.dart` & `main.dart`)

Purges `phase40SeededNotifications`, `seededNotifications`, `_autoSeedPending`, `shouldAutoSeedDemoAlerts`, and `seedDemoAlerts()`. Includes:
1. **One-Time Legacy Hive Disk Scrubber (`isLegacyDemoMockId`)**: Filters out and deletes any residual `notif_p40_*` or `notif_seed_*` records saved inside the device's `notifications_v1` Hive box from pre-Phase-67 builds so physical phones immediately boot with a clean inbox.
2. **Reactive `currentCreatorIdProvider` Binding & `RootShell.build` Listener**: Re-hydrates `NotificationsNotifier` and triggers `OnboardingNotificationsService.ensureSeededForActiveCreator(ref)` whenever a user registers a new account or switches accounts in `SovereignAuthSheet` without requiring an app restart.

#### `NotificationRepository` Legacy Demo Scrubber Addition (`apps/vhunambi_client/lib/features/notifications/data/repositories/notification_repository.dart`)

Add `isLegacyDemoMockId` and scrub legacy demo keys inside `_readAllDecoded()` and `getNotifications()`:

```dart
  /// Returns true if [id] belongs to the retired Phase 10 / Phase 40 demo seeds
  /// (`notif_p40_*` or `notif_seed_*`) that must be scrubbed from Hive on upgrade.
  static bool isLegacyDemoMockId(String id) {
    final trimmed = id.trim();
    return trimmed.startsWith('notif_p40_') || trimmed.startsWith('notif_seed_');
  }

  /// Deletes any persisted `notif_notif_p40_*` or `notif_notif_seed_*` keys
  /// from the open Hive box so upgraded physical devices never resurrect old mocks.
  Future<void> scrubLegacyDemoMocks() async {
    _resolveBoxSync();
    final box = _box;
    if (box == null || !box.isOpen) return;
    try {
      final staleKeys = <dynamic>[];
      for (final rawKey in box.keys) {
        final k = rawKey.toString();
        if (k.startsWith('${_entityPrefix}notif_p40_') ||
            k.startsWith('${_entityPrefix}notif_seed_')) {
          staleKeys.add(rawKey);
        }
      }
      if (staleKeys.isNotEmpty) {
        await box.deleteAll(staleKeys);
      }
    } catch (_) {}
  }
```
And inside `_readAllDecoded()` in `notification_repository.dart`, skip any entity where `isLegacyDemoMockId(entity.id)` is `true` (`if (entity.id.isNotEmpty && !isLegacyDemoMockId(entity.id)) { decodedById[entity.id] = entity; }`).

#### `NotificationsNotifier` (`apps/vhunambi_client/lib/features/notifications/presentation/providers/notifications_provider.dart`)

```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/resilience/safe_notifier_mixin.dart';
import 'package:vhunambi_client/core/storage/sovereign_domain_repositories.dart';
import '../../../creator_dna/presentation/providers/creator_dna_provider.dart';
import '../../data/repositories/notification_repository.dart';
import '../../domain/models/notification_entity.dart';
import '../../domain/models/notification_enums.dart';

/// StateNotifier that manages in-app notifications (newest first) with
/// Hive O(1) `notif_<id>` persistence and zero demo mock pollution.
class NotificationsNotifier extends StateNotifier<List<NotificationEntity>>
    with SafeNotifierMixin<List<NotificationEntity>> {
  final NotificationRepository _repo;

  NotificationsNotifier([
    List<NotificationEntity>? initial,
    NotificationRepository? repository,
  ]) : _repo = repository ?? NotificationRepository(),
       super(
         initial ??
             _hydrateInitialNotifications(
               repository ?? NotificationRepository(),
             ),
       ) {
    if (initial == null &&
        SovereignDomainStorageMode.canHydrateFromStorage(
          AppConstants.notificationsBoxKey,
        )) {
      Future<void>.microtask(hydrateFromStorage);
    }
  }

  static List<NotificationEntity> _hydrateInitialNotifications(
    NotificationRepository repo,
  ) {
    if (!SovereignDomainStorageMode.canHydrateFromStorage(
      AppConstants.notificationsBoxKey,
    )) {
      return const <NotificationEntity>[];
    }
    return repo
        .getNotificationsSync()
        .where((n) => !NotificationRepository.isLegacyDemoMockId(n.id))
        .toList();
  }

  /// Hydrates from persistent storage asynchronously, scrubbing legacy Phase 40
  /// demo mocks (`notif_p40_*`, `notif_seed_*`) and preserving in-memory read states.
  Future<void> hydrateFromStorage() async {
    await _repo.scrubLegacyDemoMocks();
    final loaded = (await _repo.getNotifications())
        .where((n) => !NotificationRepository.isLegacyDemoMockId(n.id))
        .toList();
    if (!mounted) return;
    final cleanCurrent = state
        .where((n) => !NotificationRepository.isLegacyDemoMockId(n.id))
        .toList();
    if (loaded.isEmpty) {
      if (cleanCurrent.length != state.length) {
        state = cleanCurrent;
      }
      return;
    }
    if (cleanCurrent.isEmpty) {
      state = loaded;
    } else {
      final byId = <String, NotificationEntity>{
        for (final n in loaded) n.id: n,
      };
      for (final current in cleanCurrent) {
        final stored = byId[current.id];
        if (stored == null) {
          byId[current.id] = current;
        } else {
          // Preserve read=true if either in-memory or storage marked it read.
          byId[current.id] = current.copyWith(
            isRead: current.isRead || stored.isRead,
          );
        }
      }
      final merged = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = merged;
    }
  }

  /// Prepends a new notification (deduplicated by `id`) and persists in O(1).
  void addNotification(NotificationEntity notification) {
    final withoutDup = state.where((n) => n.id != notification.id).toList();
    state = <NotificationEntity>[notification, ...withoutDup];
    unawaited(_repo.saveNotification(notification));
  }

  /// Upserts a notification while preserving its existing `isRead` flag if present.
  void upsertNotification(NotificationEntity notification) {
    final existingIdx = state.indexWhere((n) => n.id == notification.id);
    if (existingIdx < 0) {
      addNotification(notification);
      return;
    }
    final existing = state[existingIdx];
    final merged = notification.copyWith(isRead: existing.isRead);
    final next = <NotificationEntity>[...state];
    next[existingIdx] = merged;
    state = next;
    unawaited(_repo.saveNotification(merged));
  }

  /// Backward-compatible adapter for `.update()` callers.
  void update(
    List<NotificationEntity> Function(List<NotificationEntity>) updater,
  ) {
    final prevIds = state.map((e) => e.id).toSet();
    final next = updater(state);
    state = next;
    final nextIds = next.map((e) => e.id).toSet();
    for (final removedId in prevIds.difference(nextIds)) {
      unawaited(_repo.deleteNotification(removedId));
    }
    if (next.isNotEmpty) {
      unawaited(_repo.saveNotifications(next));
    }
  }

  /// Marks a single notification as read by [id] and writes through in O(1).
  void markAsRead(String id) {
    NotificationEntity? updatedItem;
    state = state.map((n) {
      if (n.id == id) {
        updatedItem = n.copyWith(isRead: true);
        return updatedItem!;
      }
      return n;
    }).toList();
    if (updatedItem != null) {
      unawaited(_repo.saveNotification(updatedItem!));
    }
  }

  /// Marks every existing notification as read and persists the update.
  void markAllAsRead() {
    final updated = state.map((n) => n.copyWith(isRead: true)).toList();
    state = updated;
    if (updated.isNotEmpty) {
      unawaited(_repo.saveNotifications(updated));
    }
  }

  /// Removes an individual notification by [id].
  void removeNotification(String id) {
    state = state.where((n) => n.id != id).toList();
    unawaited(_repo.deleteNotification(id));
  }

  void deleteNotification(String id) => removeNotification(id);

  /// Clears all notifications from state and persistent storage.
  void clearAll() {
    state = const <NotificationEntity>[];
    unawaited(_repo.clearAll());
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<NotificationEntity>>(
      (ref) {
        // Re-create / re-hydrate cleanly whenever the active tenant creator changes.
        ref.watch(currentCreatorIdProvider);
        return NotificationsNotifier();
      },
    );

/// Unread count per category — single partition source of truth (`REQ-P67-ONB-03`).
final unreadCountByCategoryProvider = Provider<Map<NotificationCategory, int>>((
  ref,
) {
  final list = ref.watch(notificationsProvider);
  final counts = <NotificationCategory, int>{
    for (final c in NotificationCategory.values) c: 0,
  };
  for (final n in list) {
    if (!n.isRead) {
      counts[n.category] = (counts[n.category] ?? 0) + 1;
    }
  }
  return counts;
});

/// Total unread count derived directly from [unreadCountByCategoryProvider]
/// so `All` and per-category badges can never disagree (`REQ-P67-ONB-03`).
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final byCategory = ref.watch(unreadCountByCategoryProvider);
  return byCategory.values.fold<int>(0, (sum, count) => sum + count);
});

final selectedCategoryProvider = StateProvider<NotificationCategory?>(
  (ref) => null,
);

final searchQueryProvider = StateProvider<String>((ref) => '');

final filteredNotificationsProvider = Provider<List<NotificationEntity>>((ref) {
  final list = ref.watch(notificationsProvider);
  final category = ref.watch(selectedCategoryProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  final dna = ref.watch(creatorDnaProvider);

  Iterable<NotificationEntity> filtered = list;

  if (category != null) {
    filtered = filtered.where((n) => n.category == category);
  }

  if (query.isNotEmpty) {
    filtered = filtered.where(
      (n) =>
          n.title.toLowerCase().contains(query) ||
          n.message.toLowerCase().contains(query),
    );
  }

  final result = filtered.toList();

  double dnaAffinity(NotificationEntity n) {
    if (n.category != NotificationCategory.algorithmic) return 0;
    if (!dna.onboardingCompleted) return 0;
    final genre = n.metadata['genre'] as String?;
    if (genre == null || genre.isEmpty) return 0;
    return dna.genreWeights[genre] ?? 0;
  }

  result.sort((a, b) {
    final affinityDelta = dnaAffinity(b).compareTo(dnaAffinity(a));
    if (affinityDelta != 0) return affinityDelta;

    final priorityDelta = b.priority.weight.compareTo(a.priority.weight);
    if (priorityDelta != 0) return priorityDelta;

    return b.createdAt.compareTo(a.createdAt);
  });

  return result;
});
```

#### Reactive Account-Switch & Signup Listener in `RootShell` (`apps/vhunambi_client/lib/main.dart`)

In `_RootShellState.initState()` (`main.dart#L145-L151`) and `_RootShellState.build()` (`main.dart`), replace `seedDemoAlerts()` with `OnboardingNotificationsService.ensureSeededForActiveCreator(ref)` and attach a `ref.listen<String>(currentCreatorIdProvider, ...)` listener so signing up or switching accounts while `RootShell` is already mounted immediately seeds the new creator's 3 beginner onboarding notifications:

```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      OnboardingNotificationsService.ensureSeededForActiveCreator(ref);
    });
  }
```
And inside `_RootShellState.build(BuildContext context)`:
```dart
    ref.listen<String>(currentCreatorIdProvider, (previous, next) {
      if (previous != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          OnboardingNotificationsService.ensureSeededForActiveCreator(ref);
        });
      }
    });
```

---

## 2. Refined LODA Visual Components & `STD-UIUX-001` Icons (`M67.2` — Overhaul Pass 1)

### 2.1 5-Color Semantic `NotificationCategoryStyle` (`apps/vhunambi_client/lib/features/notifications/presentation/utils/notification_category_style.dart`)

Replaces all stock `Icons.*` with Phosphor vector icons and implements subtype-aware semantic color & pill resolution (`System/Quota` Amber Gold, `Creator DNA` Emerald Teal, `Studio/Activity` Ember Orange, `Social` Amethyst Violet, `Discovery` Electric Cyan).

```dart
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/notification_entity.dart';
import '../../domain/models/notification_enums.dart';

/// Central mapping from [NotificationCategory] and optional `subtype` to its
/// design-token color, Phosphor glyph, rail label, and in-card category pill.
abstract final class NotificationCategoryStyle {
  /// Accent token for a category chip on the top filter rail.
  static Color color(NotificationCategory category) => switch (category) {
        NotificationCategory.social => AppColors.accentElectric, // #8B5CF6 Violet
        NotificationCategory.system => AppColors.coinGold, // #F59E0B Amber Gold
        NotificationCategory.creatorActivity =>
          AppColors.brandPrimary, // #F97316 Ember Orange
        NotificationCategory.algorithmic =>
          AppColors.badgeCyan, // #22D3EE Electric Cyan
      };

  /// Semantic accent for an individual [NotificationEntity], supporting
  /// Emerald Teal (`AppColors.success`) for Creator DNA calibration milestones.
  static Color entityColor(NotificationEntity notification) {
    final sub = notification.subtype?.trim().toLowerCase() ?? '';
    if (sub == 'dna_calibration' || sub == 'dna_milestone') {
      return AppColors.success; // #10B981 Emerald Teal
    }
    if (sub == 'monthly_quota' || sub == 'credits' || sub == 'welcome') {
      return AppColors.coinGold; // #F59E0B Warm Amber Gold
    }
    return color(notification.category);
  }

  /// Phosphor glyph for a category chip (`STD-UIUX-001`).
  static IconData icon(NotificationCategory category) => switch (category) {
        NotificationCategory.social => PhosphorIconsRegular.usersThree,
        NotificationCategory.system => PhosphorIconsRegular.shieldCheck,
        NotificationCategory.creatorActivity => AppIcons.sparkle,
        NotificationCategory.algorithmic => AppIcons.analytics,
      };

  /// Subtype-aware Phosphor glyph for an individual notification card.
  static IconData entityIcon(NotificationEntity notification) {
    final sub = notification.subtype?.trim().toLowerCase() ?? '';
    return switch (sub) {
      'dna_calibration' || 'dna_milestone' => AppIcons.dna,
      'monthly_quota' || 'credits' => AppIcons.coin,
      'welcome' => PhosphorIconsFill.shieldCheck,
      'reel_love' => AppIcons.heart,
      'repost' => AppIcons.remix,
      'comment' => AppIcons.chat,
      'gift' => AppIcons.coins,
      'studio_render' => AppIcons.songs,
      'reel_render' => AppIcons.reels,
      _ => icon(notification.category),
    };
  }

  /// Short label for the horizontal filter rail.
  static String label(NotificationCategory category) => switch (category) {
        NotificationCategory.social => 'Social',
        NotificationCategory.system => 'System',
        NotificationCategory.creatorActivity => 'Activity',
        NotificationCategory.algorithmic => 'Discovery',
      };

  /// Descriptive pill label rendered inside each notification card.
  static String pillLabel(NotificationEntity notification) {
    final sub = notification.subtype?.trim().toLowerCase() ?? '';
    return switch (sub) {
      'welcome' => 'System • Welcome',
      'dna_calibration' || 'dna_milestone' => 'Creator DNA',
      'monthly_quota' => 'Free Tier Quota',
      'credits' => 'Credits & Plan',
      'studio_render' => 'Studio Render',
      'reel_render' => 'Reel Export',
      'reel_love' => 'Social • Love',
      'repost' => 'Social • Repost',
      'comment' => 'Social • Comment',
      'gift' => 'Social • Cultural Gift',
      'follow' => 'Social • Follow',
      _ => switch (notification.category) {
          NotificationCategory.social => 'Social',
          NotificationCategory.system => 'System',
          NotificationCategory.creatorActivity => 'Studio Activity',
          NotificationCategory.algorithmic => 'Discovery',
        },
    };
  }
}
```

---

### 2.2 Refined Directional Glow `NotificationItemTile` (`apps/vhunambi_client/lib/features/notifications/presentation/widgets/notification_item_tile.dart`)

Implements the refined LODA directional left-edge glow (3px accent bar + 13% unread / 5% read horizontal wash), 28% unread category border, category-tinted inline timestamp dot, compact semantic category pill, trailing `›` chevron, Phosphor trash icon, and automatic keyboard unfocus on tap.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/notification_entity.dart';
import '../../domain/models/notification_enums.dart';
import '../providers/notifications_provider.dart';
import '../utils/notification_category_style.dart';
import '../utils/notifications_haptics.dart';
import '../utils/time_ago_utils.dart';

class NotificationItemTile extends ConsumerStatefulWidget {
  const NotificationItemTile({
    super.key,
    required this.notification,
    this.onTap,
    this.onAction,
  });

  final NotificationEntity notification;
  final VoidCallback? onTap;
  final void Function(NotificationAction action)? onAction;

  @override
  ConsumerState<NotificationItemTile> createState() =>
      _NotificationItemTileState();
}

class _NotificationItemTileState extends ConsumerState<NotificationItemTile> {
  final ValueNotifier<double> _dragProgress = ValueNotifier<double>(0);
  bool _snapFired = false;

  @override
  void dispose() {
    _dragProgress.dispose();
    super.dispose();
  }

  void _onMove(DismissUpdateDetails details) {
    final progress = (details.progress).clamp(0.0, 1.0);
    _dragProgress.value = progress;
    if (progress >= 0.5 && !_snapFired) {
      _snapFired = true;
      NotificationsHaptics.dismissSnap();
    } else if (progress < 0.5) {
      _snapFired = false;
    }
  }

  void _handleTap() {
    FocusManager.instance.primaryFocus?.unfocus();
    NotificationsHaptics.itemTap();
    ref.read(notificationsProvider.notifier).markAsRead(widget.notification.id);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final accent = NotificationCategoryStyle.entityColor(notification);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 5,
      ),
      child: Dismissible(
        key: Key('notif_tile_${notification.id}'),
        direction: DismissDirection.horizontal,
        onUpdate: _onMove,
        onDismissed: (_) {
          _dragProgress.value = 1;
          ref
              .read(notificationsProvider.notifier)
              .removeNotification(notification.id);
        },
        background: _SwipeDismissBackground(
          dragProgress: _dragProgress,
          alignment: Alignment.centerLeft,
        ),
        secondaryBackground: _SwipeDismissBackground(
          dragProgress: _dragProgress,
          alignment: Alignment.centerRight,
        ),
        child: _NotificationCardBody(
          notification: notification,
          accent: accent,
          onTap: _handleTap,
          onAction: widget.onAction,
        ),
      ),
    );
  }
}

class _SwipeDismissBackground extends StatelessWidget {
  const _SwipeDismissBackground({
    required this.dragProgress,
    required this.alignment,
  });

  final ValueNotifier<double> dragProgress;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.16),
        borderRadius: AppRadius.cardBorder,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ValueListenableBuilder<double>(
        valueListenable: dragProgress,
        builder: (context, progress, child) {
          final scale = 0.8 + (progress.clamp(0.0, 1.0) * 0.4);
          return Transform.scale(
            scale: scale,
            child: const PhosphorIcon(
              AppIcons.trash,
              color: AppColors.error,
              size: 24,
            ),
          );
        },
      ),
    );
  }
}

class _NotificationCardBody extends StatelessWidget {
  const _NotificationCardBody({
    required this.notification,
    required this.accent,
    required this.onTap,
    this.onAction,
  });

  final NotificationEntity notification;
  final Color accent;
  final VoidCallback onTap;
  final void Function(NotificationAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final baseSurface = isUnread
        ? AppColors.surfaceElevatedOf(context)
        : AppColors.surfaceCanvasOf(context);
    final borderColor = isUnread
        ? accent.withValues(alpha: 0.28)
        : AppColors.borderSubtleOf(context);
    final washAlpha = isUnread ? 0.13 : 0.05;

    return Container(
      decoration: BoxDecoration(
        color: baseSurface,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.cardBorder,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.cardBorder,
            child: Stack(
              children: <Widget>[
                // Subtle directional left-edge radial/linear color wash (8%–14% alpha)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: const <double>[0.0, 0.48, 1.0],
                          colors: <Color>[
                            accent.withValues(alpha: washAlpha),
                            accent.withValues(alpha: washAlpha * 0.22),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 3px vertical left-edge semantic category glow bar
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 3,
                  child: Container(
                    key: Key('notification_left_glow_bar_${notification.id}'),
                    decoration: BoxDecoration(
                      color: isUnread ? accent : accent.withValues(alpha: 0.45),
                      boxShadow: isUnread
                          ? <BoxShadow>[
                              BoxShadow(
                                color: accent.withValues(alpha: 0.45),
                                blurRadius: 8,
                                spreadRadius: 0.5,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      _CategoryGlyphBadge(
                        notification: notification,
                        accent: accent,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    notification.title,
                                    key: const Key('notification_tile_title'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodySmall.copyWith(
                                      fontWeight: isUnread
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: AppColors.textPrimaryOf(context),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  TimeAgoUtils.format(notification.createdAt),
                                  style: AppTypography.caption.copyWith(
                                    color: isUnread
                                        ? AppColors.textSecondaryOf(context)
                                        : AppColors.textTertiary,
                                    fontWeight: isUnread
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                                _UnreadDot(
                                  isRead: notification.isRead,
                                  accent: accent,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notification.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondaryOf(context),
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                _CategoryPillBadge(
                                  notification: notification,
                                  accent: accent,
                                ),
                                if (notification.ctaLabel != null &&
                                    notification.ctaLabel!.isNotEmpty) ...<Widget>[
                                  const SizedBox(width: AppSpacing.xs),
                                  Flexible(
                                    child: Text(
                                      notification.ctaLabel!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.badge.copyWith(
                                        color: accent,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (notification.actions.isNotEmpty) ...<Widget>[
                              const SizedBox(height: AppSpacing.xs),
                              _ActionRail(
                                actions: notification.actions,
                                accent: accent,
                                onAction: onAction,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      PhosphorIcon(
                        PhosphorIconsRegular.caretRight,
                        key: Key(
                          'notification_trailing_chevron_${notification.id}',
                        ),
                        size: 16,
                        color: isUnread
                            ? accent.withValues(alpha: 0.85)
                            : AppColors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryGlyphBadge extends StatelessWidget {
  const _CategoryGlyphBadge({required this.notification, required this.accent});

  final NotificationEntity notification;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.28), width: 1),
      ),
      child: Center(
        child: PhosphorIcon(
          NotificationCategoryStyle.entityIcon(notification),
          color: accent,
          size: 20,
        ),
      ),
    );
  }
}

class _CategoryPillBadge extends StatelessWidget {
  const _CategoryPillBadge({
    required this.notification,
    required this.accent,
  });

  final NotificationEntity notification;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('notification_category_pill_${notification.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: accent.withValues(alpha: 0.28), width: 0.8),
      ),
      child: Text(
        NotificationCategoryStyle.pillLabel(notification),
        style: AppTypography.badge.copyWith(
          color: accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.isRead, required this.accent});

  final bool isRead;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isRead ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Container(
        key: const Key('notification_unread_dot'),
        width: 7,
        height: 7,
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: 0.5),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.actions,
    required this.accent,
    this.onAction,
  });

  final List<NotificationAction> actions;
  final Color accent;
  final void Function(NotificationAction action)? onAction;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xxs,
      children: <Widget>[
        for (final action in actions)
          OutlinedButton(
            key: Key('notification_action_${action.actionId}'),
            onPressed: () => onAction?.call(action),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              minimumSize: const Size(44, 36),
              tapTargetSize: MaterialTapTargetSize.padded,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.pillBorder,
              ),
            ),
            child: Text(
              action.label,
              style: AppTypography.caption.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
```

---

### 2.3 Unclipped `NotificationCategoryRail` with `ShaderMask` & Auto-Unfocus (`apps/vhunambi_client/lib/features/notifications/presentation/widgets/notification_category_rail.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/notification_enums.dart';
import '../providers/notifications_provider.dart';
import '../utils/notification_category_style.dart';
import '../utils/notifications_haptics.dart';

class NotificationCategoryRail extends ConsumerStatefulWidget {
  const NotificationCategoryRail({super.key});

  @override
  ConsumerState<NotificationCategoryRail> createState() =>
      _NotificationCategoryRailState();
}

class _NotificationCategoryRailState
    extends ConsumerState<NotificationCategoryRail> {
  final Map<String, GlobalKey> _chipKeys = <String, GlobalKey>{
    'all': GlobalKey(),
    for (final c in NotificationCategory.values) c.name: GlobalKey(),
  };

  void _select(NotificationCategory? category) {
    FocusManager.instance.primaryFocus?.unfocus();
    NotificationsHaptics.categorySwitch();
    ref.read(selectedCategoryProvider.notifier).state = category;
    final key = _chipKeys[category?.name ?? 'all'];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: 0.5,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedCategoryProvider);
    final unreadByCategory = ref.watch(unreadCountByCategoryProvider);
    final totalUnread = ref.watch(unreadNotificationsCountProvider);

    return SizedBox(
      height: 52,
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: <double>[0.0, 0.92, 1.0],
            colors: <Color>[Colors.white, Colors.white, Colors.transparent],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          children: <Widget>[
            KeyedSubtree(
              key: _chipKeys['all'],
              child: _CategoryChip(
                key: const Key('category_chip_all'),
                label: 'All',
                icon: PhosphorIconsRegular.tray,
                accent: AppColors.brandPrimary,
                count: totalUnread,
                isSelected: selected == null,
                onTap: () => _select(null),
              ),
            ),
            for (final category in NotificationCategory.values)
              KeyedSubtree(
                key: _chipKeys[category.name],
                child: _CategoryChip(
                  key: Key('category_chip_${category.name}'),
                  label: NotificationCategoryStyle.label(category),
                  icon: NotificationCategoryStyle.icon(category),
                  accent: NotificationCategoryStyle.color(category),
                  count: unreadByCategory[category] ?? 0,
                  isSelected: selected == category,
                  onTap: () => _select(category),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Semantics(
        selected: isSelected,
        button: true,
        label: '$label${count > 0 ? ', $count unread' : ''}',
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.pillBorder,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? accent.withValues(alpha: 0.18)
                    : AppColors.surfaceSecondaryOf(context),
                borderRadius: AppRadius.pillBorder,
                border: Border.all(
                  color: isSelected ? accent : AppColors.borderSubtleOf(context),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  PhosphorIcon(
                    icon,
                    size: 16,
                    color: isSelected ? accent : AppColors.textSecondaryOf(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: AppTypography.caption.copyWith(
                      color: isSelected
                          ? AppColors.textPrimaryOf(context)
                          : AppColors.textSecondaryOf(context),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (count > 0) ...<Widget>[
                    const SizedBox(width: 6),
                    _CountBadge(count: count, accent: accent),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.accent});

  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(count),
      tween: Tween<double>(begin: 1.25, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        constraints: const BoxConstraints(minWidth: 18),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: AppRadius.pillBorder,
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          textAlign: TextAlign.center,
          style: AppTypography.badge.copyWith(color: AppColors.brandContrast),
        ),
      ),
    );
  }
}
```

---

### 2.4 Phosphor-Migrated `NotificationSearchBar`, `NotificationEmptyState` & `NotificationBellButton` (`STD-UIUX-001`)

#### `NotificationSearchBar` (`apps/vhunambi_client/lib/features/notifications/presentation/widgets/notification_search_bar.dart`)
Replace `Icon(Icons.search_rounded)` and `Icon(Icons.close_rounded)` with `PhosphorIcon(AppIcons.search, size: 18)` and `PhosphorIcon(AppIcons.close, size: 18)` plus `onSubmitted: (_) => _focusNode.unfocus()`.

#### `NotificationEmptyState` (`apps/vhunambi_client/lib/features/notifications/presentation/widgets/notification_empty_state.dart`)
Replace `Icon(Icons.notifications_off_outlined)` with `PhosphorIcon(PhosphorIconsRegular.bellSlash, size: 32, color: AppColors.textTertiary)`.

#### `NotificationBellButton` (`apps/vhunambi_client/lib/features/notifications/presentation/widgets/notification_bell_button.dart`)
Replace `Icon(Icons.notifications_none_rounded)` (`#L177`) with `PhosphorIcon(AppIcons.bell, size: iconSize, color: color)` and replace `shape: BoxShape.circle` on the unread badge (`#L124`) with `borderRadius: BorderRadius.circular(10)` so `'9+'` never stretches into a clipped oval.

---

## 3. Universal Detail Sheet, Deep-Link Router & Track Resolution (`M67.3` — Overhaul Pass 2)

### 3.1 `NotificationDetailBottomSheet` (`apps/vhunambi_client/lib/features/notifications/presentation/widgets/notification_detail_bottom_sheet.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/notification_entity.dart';
import '../utils/notification_category_style.dart';
import '../utils/notification_deep_link_router.dart';
import '../utils/time_ago_utils.dart';

class NotificationDetailBottomSheet extends ConsumerWidget {
  const NotificationDetailBottomSheet({
    super.key,
    required this.notification,
  });

  final NotificationEntity notification;

  static Future<void> show(
    BuildContext context,
    NotificationEntity notification,
  ) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NotificationDetailBottomSheet(notification: notification),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = NotificationCategoryStyle.entityColor(notification);
    final pill = NotificationCategoryStyle.pillLabel(notification);
    final ctaLabel = notification.ctaLabel ??
        _defaultCtaLabel(notification.effectiveRoute);

    return Container(
      key: const Key('notification_detail_bottom_sheet'),
      decoration: BoxDecoration(
        color: AppColors.surfaceModalOf(context),
        borderRadius: AppRadius.modalBorder,
        border: Border.all(color: accent.withValues(alpha: 0.30), width: 1),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtleOf(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.30)),
                    ),
                    child: Center(
                      child: PhosphorIcon(
                        NotificationCategoryStyle.entityIcon(notification),
                        color: accent,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    key: const Key('detail_sheet_category_pill'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(color: accent.withValues(alpha: 0.32)),
                    ),
                    child: Text(
                      pill,
                      style: AppTypography.badge.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    TimeAgoUtils.format(notification.createdAt),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                notification.title,
                key: const Key('detail_sheet_title'),
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.textPrimaryOf(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                notification.message,
                key: const Key('detail_sheet_message'),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondaryOf(context),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _MetadataBreakdownCard(
                notification: notification,
                accent: accent,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (notification.effectiveRoute != null) ...<Widget>[
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const Key('detail_sheet_primary_cta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: AppColors.brandContrast,
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.inputBorder,
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      NotificationDeepLinkRouter.navigateDirect(
                        context,
                        ref,
                        notification,
                      );
                    },
                    icon: const PhosphorIcon(
                      AppIcons.arrowRight,
                      size: 18,
                      color: AppColors.brandContrast,
                    ),
                    label: Text(
                      ctaLabel,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.brandContrast,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              SizedBox(
                height: 44,
                child: TextButton(
                  key: const Key('detail_sheet_close_btn'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _defaultCtaLabel(String? route) {
    if (route == null) return 'Done';
    if (route.startsWith('/studio')) return 'Open Studio Cockpit';
    if (route.startsWith('/creator-dna')) return 'Calibrate Creator DNA';
    if (route.startsWith('/wallet')) return 'View Balance & Usage';
    if (route.startsWith('/track/')) return 'Open Track Cockpit';
    if (route.startsWith('/reel/')) return 'Watch Kinetic Reel';
    if (route.startsWith('/creator/')) return 'View Creator Profile';
    return 'Continue';
  }
}

class _MetadataBreakdownCard extends StatelessWidget {
  const _MetadataBreakdownCard({
    required this.notification,
    required this.accent,
  });

  final NotificationEntity notification;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final sub = notification.subtype?.trim().toLowerCase() ?? '';
    final meta = notification.metadata;

    return Container(
      key: const Key('detail_sheet_breakdown_card'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondaryOf(context),
        borderRadius: AppRadius.inputBorder,
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: switch (sub) {
        'dna_calibration' || 'dna_milestone' => _buildDnaBreakdown(context, meta),
        'monthly_quota' => _buildQuotaBreakdown(context, meta),
        _ => _buildGenericBreakdown(context, meta),
      },
    );
  }

  Widget _buildDnaBreakdown(BuildContext context, Map<String, dynamic> meta) {
    final pct = (meta['dnaPercent'] as num?)?.toInt() ?? 8;
    final recorded = ((meta['recordedTraits'] as List?) ?? const <dynamic>[])
        .map((e) => e.toString())
        .toList();
    final uncalibrated =
        ((meta['uncalibratedTraits'] as List?) ?? const <dynamic>[])
            .map((e) => e.toString())
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'DNA CALIBRATION STRENGTH',
              style: AppTypography.badge.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '$pct / 100%',
              style: AppTypography.caption.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: (pct / 100.0).clamp(0.0, 1.0),
          minHeight: 6,
          backgroundColor: AppColors.borderSubtleOf(context),
          color: accent,
          borderRadius: BorderRadius.circular(3),
        ),
        if (recorded.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            'Recorded Traits:',
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final item in recorded)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: <Widget>[
                  PhosphorIcon(AppIcons.checkCircle, size: 13, color: accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (uncalibrated.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Pending Calibration (+90% Unlock):',
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final item in uncalibrated)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: <Widget>[
                  PhosphorIcon(
                    PhosphorIconsRegular.circleDashed,
                    size: 13,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildQuotaBreakdown(BuildContext context, Map<String, dynamic> meta) {
    final total = (meta['freeSongsTotal'] as num?)?.toInt() ?? 10;
    final remaining = (meta['freeSongsRemaining'] as num?)?.toInt() ?? 10;
    final plan = meta['planTier'] as String? ?? 'Free Creator';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'MONTHLY SONG ALLOWANCE ($plan)',
              style: AppTypography.badge.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '$remaining / $total Songs Left',
              style: AppTypography.caption.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: total > 0 ? (remaining / total).clamp(0.0, 1.0) : 0.0,
          minHeight: 6,
          backgroundColor: AppColors.borderSubtleOf(context),
          color: accent,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 8),
        Text(
          '• 1 Full AI Song + 4-Stem Demucs Separation = 1 Monthly Credit\n'
          '• Allowance resets automatically every 30-day billing cycle\n'
          '• Cultural Coins can be topped up anytime for tipping & beat licenses',
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondaryOf(context),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildGenericBreakdown(
    BuildContext context,
    Map<String, dynamic> meta,
  ) {
    final route = notification.effectiveRoute ?? 'In-App Alert';
    return Row(
      children: <Widget>[
        PhosphorIcon(AppIcons.sparkle, size: 16, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Category: ${NotificationCategoryStyle.pillLabel(notification)} • Destination: $route',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ),
      ],
    );
  }
}
```

---

### 3.2 `NotificationDeepLinkRouter` (`apps/vhunambi_client/lib/features/notifications/presentation/utils/notification_deep_link_router.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/navigation/navigation_providers.dart';
import '../../../home/presentation/widgets/subscription_upgrade_modal.dart';
import '../../../profile/presentation/views/artist_profile_view.dart';
import '../../../profile/presentation/widgets/creator_dna_helix_lab_sheet.dart';
import '../../../social/presentation/providers/social_feed_provider.dart';
import '../../../social/presentation/widgets/kinetic_reels_modal.dart';
import '../../../track/presentation/views/track_detail_view.dart';
import '../../domain/models/notification_entity.dart';
import '../widgets/notification_detail_bottom_sheet.dart';

abstract final class NotificationDeepLinkRouter {
  /// Primary entry point when a user taps a [NotificationItemTile].
  /// Opens [NotificationDetailBottomSheet] for milestone/informational alerts
  /// or routes directly when appropriate (`REQ-P67-ROUTE-01..02`).
  static Future<void> handleCardTap(
    BuildContext context,
    WidgetRef ref,
    NotificationEntity notification,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (notification.opensDetailSheetFirst) {
      await NotificationDetailBottomSheet.show(context, notification);
      return;
    }
    await navigateDirect(context, ref, notification);
  }

  /// Executes direct navigation for [notification.effectiveRoute], falling
  /// back to [NotificationDetailBottomSheet] if the route is unknown.
  static Future<void> navigateDirect(
    BuildContext context,
    WidgetRef ref,
    NotificationEntity notification,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final route = notification.effectiveRoute;
    if (route == null || route.isEmpty) {
      await NotificationDetailBottomSheet.show(context, notification);
      return;
    }

    if (route == '/studio') {
      ref.read(appNavigationTabProvider.notifier).state = 2;
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }

    if (route == '/creator-dna') {
      await CreatorDnaHelixLabSheet.show(context);
      return;
    }

    if (route == '/wallet') {
      await SubscriptionUpgradeModal.show(context);
      return;
    }

    if (route.startsWith('/track/')) {
      final trackId = route.substring('/track/'.length).trim();
      if (trackId.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TrackDetailView(trackId: trackId),
          ),
        );
        return;
      }
    }

    if (route.startsWith('/reel/')) {
      final clipId = route.substring('/reel/'.length).trim();
      final clips = ref.read(socialFeedProvider).clips;
      if (clips.isNotEmpty) {
        await KineticReelsModal.show(
          context,
          clips: clips,
          initialClipId: clipId.isEmpty ? null : clipId,
        );
        return;
      }
    }

    if (route.startsWith('/creator/')) {
      final creatorId = route.substring('/creator/'.length).trim();
      if (creatorId.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ArtistProfileView(creatorId: creatorId),
          ),
        );
        return;
      }
    }

    await NotificationDetailBottomSheet.show(context, notification);
  }
}
```

---

### 3.3 Eradicating `"Unknown Melody (@fifi)"` in `TrackDetailNotifier` (`apps/vhunambi_client/lib/features/track/presentation/providers/track_providers.dart`)

Upgrades `_lookupInitialTrack(trackId, {Ref? ref})` in `track_providers.dart` to check `libraryTracksProvider`, `exploreTracksProvider`, and `notificationsProvider` metadata before falling back to `seededTrackDetails`.

```dart
TrackDetailEntity _lookupInitialTrack(String trackId, {Ref? ref}) {
  if (ref != null) {
    // 1. Check User Library Vault (real generated & saved tracks)
    try {
      final libraryTracks = ref.read(libraryTracksProvider);
      for (final lt in libraryTracks) {
        if (lt.id == trackId) {
          final handleSlug = lt.creatorName
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
          return TrackDetailEntity(
            id: lt.id,
            title: lt.title,
            genre: lt.genre,
            language: lt.language,
            duration: Duration(seconds: lt.durationSeconds > 0 ? lt.durationSeconds : 180),
            creatorId: 'creator_$handleSlug',
            creatorName: lt.creatorName,
            creatorHandle: '@$handleSlug',
            lyrics: lt.lyrics ?? '[Instrumental / AI Studio Track]',
            prompt: 'Synthesized in Vhunambi Studio (${lt.genre} • ${lt.language})',
          );
        }
      }
    } catch (_) {}

    // 2. Check Explore Discovery Catalog
    try {
      final exploreTracks = ref.read(exploreTracksProvider);
      for (final et in exploreTracks) {
        if (et.id == trackId) {
          final handleSlug = et.creatorName
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
          return TrackDetailEntity(
            id: et.id,
            title: et.title,
            genre: et.genre,
            language: et.language,
            duration: et.duration,
            creatorId: 'creator_$handleSlug',
            creatorName: et.creatorName,
            creatorHandle: '@$handleSlug',
            playCount: et.playCount,
            lyrics: et.lyrics ?? '',
            prompt: 'Featured on Vhunambi Explore (${et.genre})',
          );
        }
      }
    } catch (_) {}
  }

  // 3. Check Seeded Catalog
  final match = seededTrackDetails.firstWhere(
    (t) => t.id == trackId,
    orElse: () => TrackDetailEntity(
      id: trackId,
      title: 'Studio Track',
      genre: 'Amapiano',
      language: 'Tshivenḓa',
      duration: const Duration(minutes: 3, seconds: 18),
      creatorId: 'creator_cern',
      creatorName: 'Vhunambi Studio',
      creatorHandle: '@vhunambi',
      prompt: 'African vocal rhythms with deep log drums',
      lyrics: '[Verse 1]\nMelodies from the north...\n[Chorus]\nVhutsila ha u imba...',
    ),
  );
  return match;
}
```

---

## 4. Backend Schema, 10-Song Quota Engine & `/api/notifications` Routes (`M67.4` — Overhaul Pass 2)

### 4.1 Supabase PostgreSQL Migration (`supabase/migrations/20261116000001_phase67_notifications_and_quotas.sql`)

```sql
BEGIN;

-- 20. Sovereign Notifications Table (Phase 67)
CREATE TABLE IF NOT EXISTS public.notifications (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'creatorActivity',
  subtype TEXT,
  priority TEXT NOT NULL DEFAULT 'normal',
  is_read BOOLEAN NOT NULL DEFAULT false,
  target_route TEXT,
  target_entity_id TEXT,
  cta_label TEXT,
  metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON public.notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications (user_id, is_read);

-- 21. Creator Monthly Song Quotas Table (10 Free Songs / Month)
CREATE TABLE IF NOT EXISTS public.creator_quotas (
  user_id TEXT PRIMARY KEY,
  plan_tier TEXT NOT NULL DEFAULT 'free',
  free_monthly_songs_limit INTEGER NOT NULL DEFAULT 10,
  free_monthly_songs_used INTEGER NOT NULL DEFAULT 0,
  cycle_reset_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '30 days'),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMIT;
```

---

### 4.2 Backend Notification & Quota Routes (`apps/vhunambi_api/src/routes/notification_routes.ts`)

```typescript
import { Hono } from 'hono';
import { z } from 'zod';
import { vhunambiDb } from '../db/vhunambi_db.js';
import {
  resolveEffectiveCreatorId,
  sovereignAuthMiddleware,
} from '../middleware/auth_middleware.js';
import type { VhunambiWorkerEnv } from '../types/cloudflare_worker_types.js';

export const notificationRoutes = new Hono<{ Bindings: VhunambiWorkerEnv }>();

notificationRoutes.use('*', sovereignAuthMiddleware);

const UpsertNotificationSchema = z.object({
  id: z.string().min(1),
  userId: z.string().optional(),
  title: z.string().min(1),
  message: z.string().default(''),
  body: z.string().optional(),
  category: z
    .enum(['social', 'system', 'creatorActivity', 'algorithmic'])
    .default('creatorActivity'),
  subtype: z.string().optional().nullable(),
  priority: z.enum(['low', 'normal', 'high', 'urgent']).default('normal'),
  isRead: z.boolean().default(false),
  targetRoute: z.string().optional().nullable(),
  targetEntityId: z.string().optional().nullable(),
  targetTrackId: z.string().optional().nullable(),
  ctaLabel: z.string().optional().nullable(),
  metadata: z.record(z.unknown()).default({}),
  createdAt: z.string().optional(),
});

// GET /api/notifications
notificationRoutes.get('/', (c) => {
  const queryUser = c.req.query('userId');
  const creatorId = resolveEffectiveCreatorId(c, queryUser, 'creator_cern');
  const notifications = vhunambiDb.listNotifications(creatorId);
  const quota = vhunambiDb.getCreatorQuota(creatorId);
  const unreadCount = notifications.filter((n) => !n.isRead).length;
  return c.json({
    success: true,
    creatorId,
    unreadCount,
    quota,
    notifications,
  });
});

// POST /api/notifications
notificationRoutes.post('/', async (c) => {
  const raw = await c.req.json().catch(() => ({}));
  const parsed = UpsertNotificationSchema.safeParse(raw);
  if (!parsed.success) {
    return c.json(
      { error: 'INVALID_NOTIFICATION', details: parsed.error.flatten() },
      400,
    );
  }
  const data = parsed.data;
  const creatorId = resolveEffectiveCreatorId(c, data.userId, 'creator_cern');
  const saved = vhunambiDb.upsertNotification({
    id: data.id,
    userId: creatorId,
    title: data.title,
    message: data.body ?? data.message,
    category: data.category,
    subtype: data.subtype ?? null,
    priority: data.priority,
    isRead: data.isRead,
    targetRoute: data.targetRoute ?? null,
    targetEntityId: data.targetEntityId ?? data.targetTrackId ?? null,
    ctaLabel: data.ctaLabel ?? null,
    metadata: data.metadata,
    createdAt: data.createdAt ?? new Date().toISOString(),
  });
  return c.json({ success: true, notification: saved }, 201);
});

// PATCH /api/notifications/:id/read
notificationRoutes.patch('/:id/read', (c) => {
  const id = c.req.param('id');
  const creatorId = resolveEffectiveCreatorId(c, undefined, 'creator_cern');
  const updated = vhunambiDb.markNotificationRead(creatorId, id);
  return c.json({ success: true, notification: updated });
});

// POST /api/notifications/mark-all-read
notificationRoutes.post('/mark-all-read', (c) => {
  const creatorId = resolveEffectiveCreatorId(c, undefined, 'creator_cern');
  const count = vhunambiDb.markAllNotificationsRead(creatorId);
  return c.json({ success: true, markedReadCount: count });
});

// DELETE /api/notifications/:id
notificationRoutes.delete('/:id', (c) => {
  const id = c.req.param('id');
  const creatorId = resolveEffectiveCreatorId(c, undefined, 'creator_cern');
  vhunambiDb.deleteNotification(creatorId, id);
  return c.json({ success: true, deletedId: id });
});
```

---

## 5. Live Event Producers & Unified Bell Badge (`M67.5` — Overhaul Pass 2)

1. **`HomeDashboardView` Bell Upgrade (`apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart#L310-L333`)**:
   Replace the raw `InkWell` + `PhosphorIcon(AppIcons.bell)` block with:
   ```dart
   NotificationBellButton(
     key: const Key('home_notifications_btn'),
     color: AppColors.textPrimaryOf(context),
     onPressed: () {
       Navigator.of(context).push(
         MaterialPageRoute<void>(
           builder: (_) => const NotificationsView(),
         ),
       );
     },
   ),
   ```
2. **Reel Love Notification (`KineticReelsModal._recordLove`)**:
   When `count == 1` or `count % 5 == 0`, emit:
   ```dart
   ref.read(notificationsProvider.notifier).addNotification(
     NotificationEntity(
       id: 'notif_love_${widget.clip.id}_$count',
       title: 'Loved ${widget.clip.creatorUsername}\'s Reel ($count×)',
       message: 'You sent $count× love reactions on "${widget.clip.title}".',
       category: NotificationCategory.social,
       priority: NotificationPriority.normal,
       subtype: 'reel_love',
       targetRoute: '/reel/${widget.clip.id}',
       targetEntityId: widget.clip.id,
       ctaLabel: 'Watch Kinetic Reel',
       createdAt: DateTime.now(),
     ),
   );
   ```
3. **Post Repost Notification (`RepostKineticPostSheet._submitRepost`)**:
   Emit:
   ```dart
   ref.read(notificationsProvider.notifier).addNotification(
     NotificationEntity(
       id: 'notif_repost_${repost.id}',
       title: 'Reposted ${widget.originalPost.creatorHandle}\'s Post',
       message: 'Syndicated "${widget.originalPost.track.title}" to your creator feed.',
       category: NotificationCategory.social,
       priority: NotificationPriority.normal,
       subtype: 'repost',
       targetRoute: '/creator/${widget.originalPost.creatorId}',
       targetEntityId: widget.originalPost.creatorId,
       ctaLabel: 'View Creator Profile',
       createdAt: now,
     ),
   );
   ```
4. **Comment & Cultural Gift Notifications (`ReelsCommentsNotifier.addComment` & `CreatorWalletNotifier.sendGift`)**:
   Emit `NotificationCategory.social` notifications with `subtype: 'comment'` / `'gift'` and `targetRoute: '/reel/$clipId'`.
