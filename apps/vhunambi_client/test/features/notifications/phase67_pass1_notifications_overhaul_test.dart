import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import 'package:vhunambi_client/features/notifications/data/repositories/notification_repository.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_entity.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_enums.dart';
import 'package:vhunambi_client/features/notifications/domain/services/onboarding_notifications_service.dart';
import 'package:vhunambi_client/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:vhunambi_client/features/notifications/presentation/utils/notification_category_style.dart';
import 'package:vhunambi_client/features/notifications/presentation/views/notifications_view.dart';

void main() {
  setUp(() {
    OnboardingNotificationsService.clearForTesting();
  });

  group('Phase 67 Pass 1: Mock Purge, Legacy Scrubber, 6%-10% DNA & Glow UI', () {
    test('REQ-P67-ONB-01: starter DNA completeness lands naturally in 6%–10%', () {
      for (final g in <int>[1, 2, 3]) {
        for (final l in <int>[1, 2]) {
          for (final m in <int>[1, 2]) {
            final completeness =
                OnboardingNotificationsService.computeStarterCompleteness(
                  genreCount: g,
                  languageCount: l,
                  moodCount: m,
                );
            final profile = CreatorDnaProfile(
              userId: 'creator_new',
              creativeRole: CreativeRole.producer,
              genreWeights: <String, double>{
                for (var i = 0; i < g; i++) 'genre_$i': 1.0,
              },
              languageWeights: <String, double>{
                for (var i = 0; i < l; i++) 'lang_$i': 1.0,
              },
              moodWeights: <String, double>{
                for (var i = 0; i < m; i++) 'mood_$i': 1.0,
              },
              onboardingCompleted: true,
              onboardingCompleteness: completeness,
              totalBehaviorEvents: 0,
              createdAt: DateTime(2026, 11, 16),
              lastUpdatedAt: DateTime(2026, 11, 16),
            );
            final pct =
                OnboardingNotificationsService.resolveStarterDnaPercent(profile);
            expect(pct, inInclusiveRange(6, 10));
          }
        }
      }
    });

    test('REQ-P67-MOCK-01: Hive disk scrubber removes legacy notif_p40_* & notif_seed_* keys', () async {
      final tempDir = Directory.systemTemp.createTempSync('vhunambi_p67_scrub_');
      Hive.init(tempDir.path);
      final box = await Hive.openBox<dynamic>(AppConstants.notificationsBoxKey);
      addTearDown(() async {
        if (box.isOpen) await box.close();
        await Hive.close();
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final repo = NotificationRepository(box);
      await box.put('notif_notif_p40_soc_1', {
        'id': 'notif_p40_soc_1',
        'title': 'Legacy Mock',
        'message': 'Fake',
        'createdAt': DateTime(2026, 11, 1).toIso8601String(),
        'isRead': false,
        'category': 'social',
      });
      await box.put('notif_notif_seed_1', {
        'id': 'notif_seed_1',
        'title': 'Legacy Seed',
        'message': 'Fake',
        'createdAt': DateTime(2026, 11, 1).toIso8601String(),
        'isRead': false,
        'category': 'creatorActivity',
      });
      await repo.saveNotification(
        NotificationEntity(
          id: 'notif_onboard_welcome_creator_test',
          title: 'Welcome to Vhunambi, @tester',
          message: 'Studio ready',
          category: NotificationCategory.system,
          subtype: 'welcome',
          createdAt: DateTime(2026, 11, 16),
        ),
      );

      final loaded = await repo.getNotifications();
      expect(loaded.map((n) => n.id), <String>['notif_onboard_welcome_creator_test']);
      expect(box.containsKey('notif_notif_p40_soc_1'), isFalse);
      expect(box.containsKey('notif_notif_seed_1'), isFalse);
    });

    test('REQ-P67-ONB-03: total unread count always equals sum of per-category counts', () {
      final container = ProviderContainer(
        overrides: [
          notificationsProvider.overrideWith(
            (ref) => NotificationsNotifier([
              NotificationEntity(
                id: 'sys_1',
                title: 'Welcome',
                message: 'Hi',
                category: NotificationCategory.system,
                subtype: 'welcome',
                createdAt: DateTime(2026, 11, 16),
                isRead: false,
              ),
              NotificationEntity(
                id: 'soc_1',
                title: 'Love',
                message: 'Reel loved',
                category: NotificationCategory.social,
                subtype: 'reel_love',
                createdAt: DateTime(2026, 11, 16),
                isRead: false,
              ),
              NotificationEntity(
                id: 'act_1',
                title: 'Render',
                message: 'Track done',
                category: NotificationCategory.creatorActivity,
                subtype: 'studio_render',
                createdAt: DateTime(2026, 11, 16),
                isRead: true,
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final byCat = container.read(unreadCountByCategoryProvider);
      final total = container.read(unreadNotificationsCountProvider);
      expect(total, 2);
      expect(
        total,
        byCat.values.fold<int>(0, (sum, c) => sum + c),
      );
    });

    test('REQ-P67-UI-01: 5 semantic accent colors resolve deterministically', () {
      final now = DateTime(2026, 11, 16);
      expect(
        NotificationCategoryStyle.entityColor(
          NotificationEntity(
            id: '1',
            title: 'W',
            message: 'M',
            category: NotificationCategory.system,
            subtype: 'welcome',
            createdAt: now,
          ),
        ),
        AppColors.coinGold,
      );
      expect(
        NotificationCategoryStyle.entityColor(
          NotificationEntity(
            id: '2',
            title: 'D',
            message: 'M',
            category: NotificationCategory.system,
            subtype: 'dna_calibration',
            createdAt: now,
          ),
        ),
        AppColors.success,
      );
      expect(
        NotificationCategoryStyle.entityColor(
          NotificationEntity(
            id: '3',
            title: 'S',
            message: 'M',
            category: NotificationCategory.creatorActivity,
            createdAt: now,
          ),
        ),
        AppColors.brandPrimary,
      );
      expect(
        NotificationCategoryStyle.entityColor(
          NotificationEntity(
            id: '4',
            title: 'Soc',
            message: 'M',
            category: NotificationCategory.social,
            createdAt: now,
          ),
        ),
        AppColors.accentElectric,
      );
      expect(
        NotificationCategoryStyle.entityColor(
          NotificationEntity(
            id: '5',
            title: 'Disc',
            message: 'M',
            category: NotificationCategory.algorithmic,
            createdAt: now,
          ),
        ),
        AppColors.badgeCyan,
      );
    });

    testWidgets('REQ-P67-UI-02 & 04: glow cards render pills/chevrons & tapping chip unfocuses search', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dna = CreatorDnaProfile(
        userId: 'creator_ndugelo',
        creativeRole: CreativeRole.producer,
        genreWeights: const {'Amapiano': 1.0, 'Afro House': 1.0},
        languageWeights: const {'Tshivenḓa': 1.5},
        primaryLanguage: 'Tshivenḓa',
        moodWeights: const {'Soulful': 1.0},
        onboardingCompleted: true,
        onboardingCompleteness: 0.18,
        createdAt: DateTime(2026, 11, 16),
        lastUpdatedAt: DateTime(2026, 11, 16),
      );
      final milestones =
          OnboardingNotificationsService.buildBeginnerNotifications(
            creatorId: 'creator_ndugelo',
            handle: '@ndugelo',
            dnaProfile: dna,
          );

      final container = ProviderContainer(
        overrides: [
          notificationsProvider.overrideWith(
            (ref) => NotificationsNotifier(milestones),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const NotificationsView(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Verify all 3 onboarding milestones render with glow bar, pill & chevron
      for (final n in milestones) {
        expect(find.byKey(Key('notification_left_glow_bar_${n.id}')), findsOneWidget);
        expect(find.byKey(Key('notification_category_pill_${n.id}')), findsOneWidget);
        expect(find.byKey(Key('notification_trailing_chevron_${n.id}')), findsOneWidget);
      }
      expect(find.text('System • Welcome'), findsOneWidget);
      expect(find.text('Creator DNA'), findsOneWidget);
      expect(find.text('Free Tier Quota'), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.caretRight), findsNWidgets(3));

      // Focus search bar, then tap System chip -> search field loses primary focus
      await tester.tap(find.byKey(const Key('notification_search_field')));
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);

      await tester.tap(find.byKey(const Key('category_chip_system')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>(),
        isNull,
      );
    });
  });
}
