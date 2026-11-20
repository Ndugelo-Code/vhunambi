import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/auth/viewer_role.dart';
import 'package:vhunambi_client/core/design_system/tokens/design_enums.dart';
import 'package:vhunambi_client/core/design_system/tokens/vhunambi_mood.dart';
import 'package:vhunambi_client/core/navigation/navigation_providers.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_ambient_mesh_backdrop.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/player/presentation/widgets/mini_player_host.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/threaded_comments_section.dart';
import 'package:vhunambi_client/features/track/presentation/views/track_detail_view.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/prompt_attribution_card.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/stem_separation_lab.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/track_hero_section.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/track_living_biome_preview_card.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/track_sonic_telemetry_card.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/utility_tool_dock.dart';
import 'package:vhunambi_client/shared/models/track.dart';

void main() {
  group('Phase 70 Pass 1 Core Primitives', () {
    test('VhunambiMood normalizes all legacy strings & enums losslessly', () {
      expect(VhunambiMood.normalize('Joyful'), VhunambiMood.uplifting);
      expect(VhunambiMood.normalize('Vibrant'), VhunambiMood.uplifting);
      expect(VhunambiMood.normalize('Soulful & Nostalgic'), VhunambiMood.soulful);
      expect(VhunambiMood.normalize('Melancholic'), VhunambiMood.soulful);
      expect(VhunambiMood.normalize('Warm'), VhunambiMood.soulful);
      expect(VhunambiMood.normalize('Party'), VhunambiMood.energetic);
      expect(VhunambiMood.normalize('Electrifying'), VhunambiMood.energetic);
      expect(VhunambiMood.normalize('Peaceful'), VhunambiMood.chill);
      expect(VhunambiMood.normalize('Calm'), VhunambiMood.chill);
      expect(VhunambiMood.normalize('Deep'), VhunambiMood.hypnotic);
      expect(VhunambiMood.normalize('Dark'), VhunambiMood.hypnotic);
      expect(VhunambiMood.normalize('Atmospheric'), VhunambiMood.hypnotic);
      expect(VhunambiMood.normalize('Romantic'), VhunambiMood.romantic);
      expect(
        VhunambiMood.fromLegacyMood(Mood.melancholic),
        VhunambiMood.soulful,
      );
      expect(VhunambiMood.hypnotic.toLegacyMood(), Mood.calm);
    });

    test('resolveViewerRole isolates outside creators and fails closed', () {
      expect(
        resolveViewerRole(
          ownerCreatorId: 'lerato_prod',
          ownerHandle: '@lerato_prod',
          activeCreatorId: 'creator_cern',
          activeHandle: '@cern',
        ),
        ViewerRole.visitor,
      );

      expect(
        resolveViewerRole(
          ownerCreatorId: '',
          ownerHandle: null,
          activeCreatorId: 'creator_cern',
        ),
        ViewerRole.visitor,
      );

      expect(
        resolveViewerRole(
          ownerCreatorId: 'creator_lerato_prod',
          ownerHandle: '@lerato_prod',
          activeCreatorId: 'creator_lerato_prod',
          activeHandle: '@lerato_prod',
        ),
        ViewerRole.owner,
      );

      expect(
        resolveViewerRole(
          ownerCreatorId: 'creator_cern',
          activeCreatorId: 'creator_cern',
        ),
        ViewerRole.owner,
      );
    });

    testWidgets(
      'VhunambiGlassSurface defaults to zero BackdropFilter and supports opt-in blur',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: VhunambiAmbientMeshBackdrop(
                child: Column(
                  children: [
                    VhunambiGlassSurface(
                      key: Key('glass_no_blur'),
                      child: Text('Static Glass'),
                    ),
                    VhunambiGlassSurface(
                      key: Key('glass_live_blur'),
                      enableLiveBlur: true,
                      blurSigma: 28.0, // clamped to <= 16.0
                      child: Text('Blurred Glass'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.byType(BackdropFilter), findsOneWidget);
        final backdrop = tester.widget<BackdropFilter>(
          find.byType(BackdropFilter),
        );
        expect(
          backdrop.filter.toString(),
          ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0).toString(),
        );
      },
    );
  });

  group('Phase 70 Pass 1 Role-Aware Song Cockpit (`TrackDetailView`)', () {
    testWidgets(
      'Visitor mode on @lerato_prod track hides studio tools, fixes Light-Mode contrast & renders threaded comments',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentCreatorIdProvider.overrideWithValue('creator_cern'),
              currentCreatorHandleProvider.overrideWithValue('@cern'),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const TrackDetailView(trackId: 'seed-04'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        // 1. Visitor provenance & artwork shown; false "owned by you" deed hidden
        expect(find.byType(TrackHeroSection), findsOneWidget);
        expect(find.byKey(const Key('track_hero_artwork')), findsOneWidget);
        expect(
          find.byKey(const Key('track_visitor_provenance_pill')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('track_owner_deed_card')), findsNothing);
        expect(find.textContaining('owned by you'), findsNothing);
        expect(find.textContaining('All Rights Reserved'), findsOneWidget);

        // 2. Telemetry & canonical VhunambiMood card shown
        expect(find.byType(TrackSonicTelemetryCard), findsOneWidget);
        expect(find.byKey(const Key('track_mood_chip')), findsOneWidget);
        expect(find.text('Soulful'), findsOneWidget);
        expect(find.textContaining('122 BPM'), findsOneWidget);

        // 3. Light-mode Like count inside TrackActionsBar uses readable dark charcoal (NOT white!)
        final likeText = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const Key('track_like_pill')),
            matching: find.text('620'),
          ),
        );
        expect(likeText.style?.color, isNot(Colors.white));
        expect(likeText.style?.color, AppColors.lightTextPrimary);

        // 4. Paid studio machinery strictly hidden from visitors
        expect(find.byType(UtilityToolDock), findsNothing);
        expect(find.byType(StemSeparationLab), findsNothing);
        expect(find.byType(TrackLivingBiomePreviewCard), findsNothing);
        expect(find.byKey(const Key('track_open_mixer_btn')), findsNothing);
        expect(
          find.byKey(const Key('track_detail_open_mastering_btn')),
          findsNothing,
        );
        expect(find.byType(PromptAttributionCard), findsNothing);

        // 5. Phase 69 threaded discussion & sticky composer mounted
        expect(find.byType(ThreadedCommentsSection), findsOneWidget);
        expect(find.byType(StudioReactionComposerBar), findsOneWidget);
      },
    );

    testWidgets(
      'Owner mode on @lerato_prod track unlocks full Studio Cockpit',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentCreatorIdProvider.overrideWithValue('creator_lerato_prod'),
              currentCreatorHandleProvider.overrideWithValue('@lerato_prod'),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const TrackDetailView(trackId: 'seed-04'),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.byKey(const Key('track_owner_deed_card')), findsOneWidget);
        expect(
          find.byKey(const Key('track_visitor_provenance_pill')),
          findsNothing,
        );
        expect(find.byType(UtilityToolDock), findsOneWidget);
        expect(find.byType(StemSeparationLab), findsOneWidget);
        expect(find.byType(TrackLivingBiomePreviewCard), findsOneWidget);
        expect(find.byKey(const Key('track_open_mixer_btn')), findsOneWidget);
        expect(
          find.byKey(const Key('track_detail_open_mastering_btn')),
          findsOneWidget,
        );
        expect(find.byType(PromptAttributionCard), findsOneWidget);
      },
    );

    testWidgets(
      'Mounting TrackDetailView suppresses MiniPlayerHost cleanly via inline player counter',
      (tester) async {
        final container = ProviderContainer(
          overrides: [appNavigationTabProvider.overrideWith((ref) => 1)],
        );
        addTearDown(container.dispose);

        container.read(playerStateProvider.notifier).playTrack(
              const Track(
                id: 'seed-04',
                title: 'Soweto Sunset Groove',
                creatorName: 'Lerato',
                genre: 'Afro House',
                duration: Duration(minutes: 5, seconds: 12),
              ),
            );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: Stack(
                children: const [
                  TrackDetailView(trackId: 'seed-04'),
                  MiniPlayerHost(),
                ],
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(
          container.read(trackDetailInlinePlayerMountedProvider),
          greaterThan(0),
        );
        // MiniPlayerHost suppresses itself while TrackDetailView is active.
        expect(
          find.descendant(
            of: find.byType(MiniPlayerHost),
            matching: find.text('Soweto Sunset Groove'),
          ),
          findsNothing,
        );
      },
    );
  });
}
