import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/auth/sovereign_auth_repository.dart';
import 'package:vhunambi_client/core/design_system/design_system.dart';
import 'package:vhunambi_client/core/navigation/navigation_providers.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/features/auth/presentation/widgets/sovereign_auth_sheet.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import 'package:vhunambi_client/features/marketplace/domain/models/licensing_models.dart';
import 'package:vhunambi_client/features/marketplace/domain/services/license_agreement_engine.dart';
import 'package:vhunambi_client/features/marketplace/domain/services/sovereign_certificate_signer.dart';
import 'package:vhunambi_client/features/marketplace/presentation/providers/beat_checkout_provider.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_entity.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_enums.dart';
import 'package:vhunambi_client/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:vhunambi_client/features/notifications/presentation/utils/notification_deep_link_router.dart';
import 'package:vhunambi_client/features/notifications/presentation/widgets/notifications_popover.dart';
import 'package:vhunambi_client/features/onboarding/presentation/widgets/app_tour_overlay.dart';
import 'package:vhunambi_client/features/onboarding/presentation/widgets/genre_color_chip.dart';
import 'package:vhunambi_client/features/onboarding/presentation/widgets/role_carousel_widget.dart';
import 'package:vhunambi_client/features/profile/presentation/views/artist_profile_view.dart';
import 'package:vhunambi_client/features/profile/presentation/views/owner_profile_view.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/profile_settings_drawer.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_feed_provider.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/kinetic_reels_modal.dart';
import 'package:vhunambi_client/main.dart';

class _TestLicenseCertificatesNotifier extends LicenseCertificatesNotifier {
  _TestLicenseCertificatesNotifier(
    super.repo,
    List<SovereignLicenseCertificate> initial,
  ) {
    state = initial;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    if (!DesignTokenRegistry.isSealed) {
      TokenRegistration.registerAllTokens();
      DesignTokenRegistry.seal();
    }
  });

  group('Phase 76 — Theme Stability, Auth Gate, Deep-Link Coverage & Polish', () {
    testWidgets(
      'REQ-P76-CORE-01: toggling Light/Dark/System preserves Navigator & ProfileSettingsDrawer',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: VhunambiApp(
              initialHome: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const Key('open_settings_host_btn'),
                      onPressed: () => ProfileSettingsDrawer.show(context),
                      child: const Text('Settings'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        await tester.tap(find.byKey(const Key('open_settings_host_btn')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(ProfileSettingsDrawer), findsOneWidget);

        // Toggle Light -> Dark -> System and verify Drawer never unmounts!
        await tester.tap(find.byKey(const Key('theme_mode_light')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byType(ProfileSettingsDrawer), findsOneWidget);

        await tester.tap(find.byKey(const Key('theme_mode_dark')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byType(ProfileSettingsDrawer), findsOneWidget);

        await tester.tap(find.byKey(const Key('theme_mode_system')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byType(ProfileSettingsDrawer), findsOneWidget);
      },
    );

    testWidgets(
      'REQ-P76-CORE-02/03: SovereignAuthSheet hides demo quick-switch in release & uses Glass',
      (tester) async {
        // 1. Release mode simulation (`enableDemoQuickSwitchOverride: false`)
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SovereignAuthSheet(enableDemoQuickSwitchOverride: false),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('sovereign_auth_glass_surface')),
          findsOneWidget,
        );
        expect(find.byType(VhunambiGlassSurface), findsWidgets);
        expect(find.text('QUICK STUDIO CREATORS'), findsNothing);
        expect(
          find.byKey(const Key('auth_quick_chip_makhadzi')),
          findsNothing,
        );
        expect(
          tester.getSize(find.byKey(const Key('auth_close_btn'))).height,
          greaterThanOrEqualTo(44.0),
        );

        // 2. Unit assertion: fail-closed when allowDemoSwitch is false
        final notifier = AuthSessionNotifier(SovereignAuthRepository());
        await expectLater(
          () => notifier.switchToSeededCreator(
            handle: '@makhadzi',
            allowDemoSwitch: false,
          ),
          throwsA(
            isA<SovereignAuthException>()
                .having((e) => e.statusCode, 'statusCode', 403)
                .having(
                  (e) => e.code,
                  'code',
                  'DEMO_SWITCH_DISABLED_IN_RELEASE',
                ),
          ),
        );
      },
    );

    testWidgets(
      'REQ-P76-CORE-04: ProfileSettingsDrawer Light Mode Glass & >= 44dp touch targets',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Scaffold(
                body: SingleChildScrollView(child: ProfileSettingsDrawer()),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          find.byKey(const Key('profile_settings_glass_surface')),
          findsOneWidget,
        );
        expect(
          tester.getSize(find.byKey(const Key('settings_sync_now_btn'))).height,
          greaterThanOrEqualTo(44.0),
        );
        expect(
          tester.getSize(find.byKey(const Key('hive_compact_now_btn'))).height,
          greaterThanOrEqualTo(44.0),
        );
        expect(
          tester.getSize(find.byKey(const Key('hive_sync_now_btn'))).height,
          greaterThanOrEqualTo(44.0),
        );
        expect(
          tester
              .getSize(find.byKey(const Key('account_switch_signin_btn')))
              .height,
          greaterThanOrEqualTo(44.0),
        );
      },
    );

    testWidgets(
      'REQ-P76-DL-02/03: DeepLinkRouter handles cold /reel, /license, /profile, /@handle & shell tabs',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const signer = SovereignCertificateSigner();
        const engine = LicenseAgreementEngine();
        final pricing = engine.calculateTierPricing(
          baseCredits: 5,
          tier: BeatCheckoutTier.premiumWav,
        );
        final cert = signer.signCertificate(
          certificateId: 'CERT-VHB-20261122-P76001',
          beatId: 'beat_p76_1',
          beatTitle: 'Limpopo Log Anthem',
          producerId: 'creator_makhadzi',
          producerHandle: '@makhadzi',
          producerName: 'Makhadzi',
          buyerId: 'creator_cern',
          buyerHandle: '@cern',
          genre: 'Amapiano',
          bpm: 114,
          musicalKey: 'F# Minor',
          pricing: pricing,
          issuedAtIso8601: '2026-11-22T12:00:00Z',
          commercialTerms: 'Standard Vhunambi Commercial Deed',
          vaultTrackId: 'market_beat_p76_1',
          masterAudioFilePath: 'vault/limpopo.wav',
          stemPaths: const <String, String>{},
          masterFileSha256: SovereignCertificateSigner.sha256HexUtf8('p76'),
        );

        late BuildContext capturedCtx;
        late WidgetRef capturedRef;
        final container = ProviderContainer(
          overrides: [
            socialFeedProvider.overrideWith((ref) {
              final n = SocialFeedNotifier(null);
              n.state = const SocialFeedState(clips: []);
              return n;
            }),
            licenseCertificatesProvider.overrideWith(
              (ref) => _TestLicenseCertificatesNotifier(
                ref.watch(licenseCertificateRepositoryProvider),
                [cert],
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Consumer(
                builder: (context, ref, _) {
                  capturedCtx = context;
                  capturedRef = ref;
                  return const Scaffold(body: SizedBox.shrink());
                },
              ),
            ),
          ),
        );
        await tester.pump();

        // 1. Shell tabs
        final tabRoutes = <String, int>{
          '/home': 0,
          '/explore': 1,
          '/studio': 2,
          '/vault': 3,
          '/licenses': 3,
          '/marketplace': 4,
        };
        for (final entry in tabRoutes.entries) {
          await NotificationDeepLinkRouter.navigateDirect(
            capturedCtx,
            capturedRef,
            NotificationEntity(
              id: 'tab_${entry.value}_${entry.key}',
              title: 'Tab jump',
              message: entry.key,
              targetRoute: entry.key,
              createdAt: DateTime.now(),
            ),
          );
          expect(container.read(appNavigationTabProvider), entry.value);
        }

        // 2. License Certificate Sheet (/license/:id)
        NotificationDeepLinkRouter.navigateDirect(
          capturedCtx,
          capturedRef,
          NotificationEntity(
            id: 'notif_lic_1',
            title: 'License Ready',
            message: 'Deed issued',
            subtype: 'license_acquired',
            targetRoute: '/license/CERT-VHB-20261122-P76001',
            createdAt: DateTime.now(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Sovereign License Deed'), findsOneWidget);
        expect(find.text('CERT-VHB-20261122-P76001'), findsOneWidget);
        Navigator.of(capturedCtx).pop();
        await tester.pump(const Duration(milliseconds: 300));

        // 3. Profiles (/profile -> OwnerProfileView, /@makhadzi -> ArtistProfileView)
        NotificationDeepLinkRouter.navigateDirect(
          capturedCtx,
          capturedRef,
          NotificationEntity(
            id: 'notif_prof_self',
            title: 'Your Profile',
            message: 'Check stats',
            targetRoute: '/profile',
            createdAt: DateTime.now(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(OwnerProfileView), findsOneWidget);
        Navigator.of(capturedCtx).pop();
        await tester.pump(const Duration(milliseconds: 300));

        NotificationDeepLinkRouter.navigateDirect(
          capturedCtx,
          capturedRef,
          NotificationEntity(
            id: 'notif_prof_handle',
            title: 'Makhadzi followed you',
            message: 'Tap to inspect profile',
            targetRoute: '/@makhadzi',
            createdAt: DateTime.now(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(ArtistProfileView), findsOneWidget);
        Navigator.of(capturedCtx).pop();
        await tester.pump(const Duration(milliseconds: 300));

        // 4. Cold-start Reel (/reel/:clipId) when clips == []
        NotificationDeepLinkRouter.navigateDirect(
          capturedCtx,
          capturedRef,
          NotificationEntity(
            id: 'notif_reel_cold',
            title: 'Your Reel went viral',
            message: 'Tap to watch',
            targetRoute: '/reel/clip_cold_99',
            metadata: const <String, dynamic>{
              'title': 'Venda Horizon',
              'genre': 'Amapiano',
              'creatorName': 'Makhadzi',
            },
            createdAt: DateTime.now(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(KineticReelsModal), findsOneWidget);
        Navigator.of(capturedCtx).pop();
        await tester.pump(const Duration(milliseconds: 300));
      },
    );

    testWidgets(
      'REQ-P76-DL-01/04: Bell Popover uses Glass + delegates /studio tap through DeepLinkRouter',
      (tester) async {
        final studioNotif = NotificationEntity(
          id: 'notif_pop_studio',
          title: 'Open Studio Beat Engine',
          message: 'New log drum pack ready',
          category: NotificationCategory.creatorActivity,
          subtype: 'studio_pack',
          targetRoute: '/studio',
          createdAt: DateTime.now(),
        );

        final container = ProviderContainer(
          overrides: [
            notificationsProvider.overrideWith(
              (ref) => NotificationsNotifier(<NotificationEntity>[studioNotif]),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const Key('open_popover_host'),
                      onPressed: () => NotificationsPopover.show(context),
                      child: const Text('Bell'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('open_popover_host')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(const Key('notifications_popover_glass')),
          findsOneWidget,
        );
        expect(find.text('View All Alerts in Center'), findsOneWidget);
        expect(find.textContaining('➔'), findsNothing);

        await tester.tap(find.text('Open Studio Beat Engine'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(NotificationsPopover), findsNothing);
        expect(container.read(appNavigationTabProvider), 2);
      },
    );

    testWidgets(
      'REQ-P76-ONB-01/02: Onboarding widgets pass STD-UIUX-001 (0 Material Icons, 0 emojis, Glass)',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 460,
                        child: AppTourOverlay(onTourComplete: () {}),
                      ),
                      RoleCarouselWidget(
                        roles: const [
                          RoleOption(
                            role: CreativeRole.producer,
                            label: 'Producer',
                            emoji: '🎹',
                            description: 'Log drum pioneer',
                          ),
                        ],
                        selectedRole: CreativeRole.producer,
                        onRoleSelected: (_) {},
                      ),
                      GenreColorChip(
                        genre: Genre.amapiano,
                        isSelected: true,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Zero raw emoji string rendered despite legacy RoleOption.emoji arg
        expect(find.text('🎹'), findsNothing);
        // Glass surfaces & PhosphorIcon vectors present
        expect(find.byType(VhunambiGlassSurface), findsWidgets);
        expect(find.byType(PhosphorIcon), findsWidgets);

        // Zero stock MaterialIcons font Icon widgets
        final materialIcons = tester.widgetList<Icon>(find.byType(Icon)).where(
          (icon) => icon.icon?.fontFamily == 'MaterialIcons',
        );
        expect(materialIcons, isEmpty);
      },
    );
  });
}
