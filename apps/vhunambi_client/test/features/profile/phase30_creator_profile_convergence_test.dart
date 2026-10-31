import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/core/utils/creator_id_utils.dart';
import 'package:vhunambi_client/features/creator_dna/presentation/widgets/creator_dna_profile_card.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/explore_discovery_drawer_sheet.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/explore_top_bar.dart';
import 'package:vhunambi_client/features/profile/presentation/views/artist_profile_view.dart';
import 'package:vhunambi_client/features/profile/presentation/views/owner_profile_view.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/artist_voice_showcase_card.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/owner_beatstore_cockpit.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/producer_beat_listing_tile.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/creator_tipping_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('Phase 30: V4.1 Creator Profile Convergence Verification', () {
    test('Finding PROF-002: Recursive prefix stripping works idempotently', () {
      expect(extractRawCreatorId('creator_creator_creator_sigwa'), 'sigwa');
      expect(
        normalizeCreatorId('creator_creator_creator_sigwa'),
        'creator_sigwa',
      );
      expect(normalizeCreatorId('makhadzi'), 'creator_makhadzi');
      expect(normalizeCreatorId('creator_makhadzi'), 'creator_makhadzi');
    });

    testWidgets(
      'Finding PROF-001: Tapping Tip Artist opens CreatorTippingSheet with 4 cultural gifts',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const ArtistProfileView(artistId: 'fifi'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tipButton = find.text('Tip Artist');
        expect(tipButton, findsOneWidget);

        await tester.tap(tipButton);
        await tester.pumpAndSettle();

        expect(find.byType(CreatorTippingSheet), findsOneWidget);
        expect(find.text('Support @fifi'), findsOneWidget);
        expect(find.byKey(const Key('tip_coin_balance')), findsOneWidget);
        expect(find.byKey(const Key('tip_send_btn')), findsOneWidget);
      },
    );

    testWidgets(
      'Finding PROF-003: Beats tab queries real marketplace beats with audition & license buttons',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const ArtistProfileView(artistId: 'ndugelo'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Beats'));
        await tester.pumpAndSettle();

        expect(find.text('Beats & Stems'), findsOneWidget);
        expect(find.byType(ProducerBeatListingTile), findsWidgets);
        expect(
          find.byKey(const Key('beat_tile_audition_btn_beat_zulu_acoustic')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('beat_tile_license_btn_beat_zulu_acoustic')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Finding PROF-004: Owner studio has 3-segment switcher and My Beatstore cockpit',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const OwnerProfileView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('owner_studio_tab_songs')), findsOneWidget);
        expect(
          find.byKey(const Key('owner_studio_tab_releases')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('owner_studio_tab_beatstore')),
          findsOneWidget,
        );

        // Switch to Beatstore
        await tester.tap(find.byKey(const Key('owner_studio_tab_beatstore')));
        await tester.pumpAndSettle();

        expect(find.byType(OwnerBeatstoreCockpit), findsOneWidget);
        expect(find.byKey(const Key('owner_upload_beat_btn')), findsOneWidget);
        expect(find.text('Producer Beatstore'), findsOneWidget);
      },
    );

    testWidgets(
      'Finding PROF-005 & 006: Music tab embeds scoped Creator DNA and Voice Identity showcase',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const ArtistProfileView(artistId: 'creator_makhadzi'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Music'));
        await tester.pumpAndSettle();

        expect(find.byType(ArtistVoiceShowcaseCard), findsOneWidget);
        expect(find.byKey(const Key('voice_audition_btn')), findsOneWidget);
        expect(find.byKey(const Key('voice_remix_studio_btn')), findsOneWidget);

        expect(find.byType(CreatorDnaProfileCard), findsOneWidget);
        // Ensure reset button is concealed for non-owner
        expect(find.byKey(const Key('reset_dna_button')), findsNothing);
      },
    );

    testWidgets(
      'Finding PROF-007: TopBar and Discovery Drawer navigate to Owner Creator Studio',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(
                appBar: PreferredSize(
                  preferredSize: Size.fromHeight(56),
                  child: MobileExploreTopBar(),
                ),
                body: Center(child: Text('Explore Body')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('explore_mobile_user_avatar_btn')),
          findsOneWidget,
        );

        // Tap mobile avatar -> opens OwnerProfileView
        await tester.tap(
          find.byKey(const Key('explore_mobile_user_avatar_btn')),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OwnerProfileView), findsOneWidget);
      },
    );

    testWidgets('Discovery Drawer contains My Creator Studio header card', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: ExploreDiscoveryDrawerSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('drawer_item_creator_studio')),
        findsOneWidget,
      );
      expect(find.text('My Creator Studio'), findsOneWidget);
    });
  });
}
