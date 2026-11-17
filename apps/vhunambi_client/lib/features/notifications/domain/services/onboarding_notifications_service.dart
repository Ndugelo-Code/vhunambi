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
