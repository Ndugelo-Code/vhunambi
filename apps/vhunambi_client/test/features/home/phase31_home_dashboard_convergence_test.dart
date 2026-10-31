import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/home/presentation/views/home_dashboard_view.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/mastering/presentation/widgets/mobile_quick_master_sheet.dart';
import 'package:vhunambi_client/features/notifications/presentation/views/notifications_view.dart';
import 'package:vhunambi_client/features/onboarding/domain/models/onboarding_models.dart';
import 'package:vhunambi_client/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:vhunambi_client/features/profile/domain/models/profile_models.dart';
import 'package:vhunambi_client/features/profile/presentation/providers/profile_providers.dart';
import 'package:vhunambi_client/features/social/presentation/providers/creator_wallet_provider.dart';
import 'package:vhunambi_client/features/studio/domain/models/generation_pipeline_state.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/generation_pipeline_providers.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/melody_sketchpad_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_form_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/melody_sketchpad_modal.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/vocal_identity_picker_sheet.dart';

void main() {
  group('Phase 31: V4.1 Creator Home Dashboard Convergence Verification', () {
    testWidgets(
      'Finding HOME-001 & 008: Header wires live dayStreak, coinsBalance, and 1-step notifications',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ownerProfileProvider.overrideWith(
                (ref) => _CustomOwnerProfileNotifier(
                  const ArtistProfileEntity(
                    id: 'me',
                    username: 'ndugelo',
                    displayName: 'Ndugelo',
                    monogram: 'ND',
                    dayStreak: 7,
                    isVerified: true,
                  ),
                ),
              ),
              creatorWalletProvider.overrideWith(
                (ref) => _CustomCreatorWalletNotifier(
                  ref,
                  const CreatorWalletState(userCoinsBalance: 840),
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const HomeDashboardView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Live day streak check
        expect(find.byKey(const Key('home_streak_pill')), findsOneWidget);
        expect(find.text('7 Streak'), findsOneWidget);

        // 2. Live coin balance check
        expect(find.byKey(const Key('home_coins_pill')), findsOneWidget);
        expect(find.text('840 Coins'), findsOneWidget);

        // 3. Notification bell action navigation
        expect(find.byKey(const Key('home_notifications_btn')), findsOneWidget);
        await tester.tap(find.byKey(const Key('home_notifications_btn')));
        await tester.pumpAndSettle();

        expect(find.byType(NotificationsView), findsOneWidget);
      },
    );

    testWidgets(
      'Finding HOME-002: Jump Back In card watches libraryTracksProvider and mounts Polish button',
      (tester) async {
        final testCustomTrack = LibraryTrack(
          id: 'vault_session_99',
          title: 'Khomani Soul Anthem',
          creatorName: 'Ndugelo Producer',
          genre: 'Amapiano',
          language: 'Tshivenḓa',
          durationSeconds: 240,
          remoteAudioUrl: 'https://example.com/audio.mp3',
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              libraryTracksProvider.overrideWith(
                (ref) => _CustomLibraryTracksNotifier([testCustomTrack]),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const HomeDashboardView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Jump Back In'), findsOneWidget);
        expect(find.text('Khomani Soul Anthem'), findsOneWidget);
        expect(find.textContaining('Ndugelo Producer'), findsOneWidget);

        // Polish / Stems action button
        final polishBtn = find.byKey(const Key('home_jump_back_master_btn'));
        expect(polishBtn, findsOneWidget);

        await tester.ensureVisible(polishBtn);
        await tester.pumpAndSettle();
        await tester.tap(polishBtn);
        await tester.pumpAndSettle();

        // Opens MobileQuickMasterSheet initialized with the track
        expect(find.byType(MobileQuickMasterSheet), findsOneWidget);
      },
    );

    testWidgets(
      'Finding HOME-003 & 004: Responsive 6-Tool Creation Hub mounts all tools with working navigation',
      (tester) async {
        bool studioNavigated = false;
        bool marketNavigated = false;
        bool libraryNavigated = false;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: HomeDashboardView(
                onNavigateToStudio: () => studioNavigated = true,
                onNavigateToMarket: () => marketNavigated = true,
                onNavigateToLibrary: () => libraryNavigated = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check all 6 tool keys and labels
        expect(find.byKey(const Key('home_hub_ai_studio')), findsOneWidget);
        expect(find.text('AI Studio'), findsOneWidget);

        expect(find.byKey(const Key('home_hub_voice_clone')), findsOneWidget);
        expect(find.text('Voice Clone'), findsOneWidget);

        expect(
          find.byKey(const Key('home_hub_melody_sketchpad')),
          findsOneWidget,
        );
        expect(find.text('Sketchpad'), findsOneWidget);

        expect(find.byKey(const Key('home_hub_stem_master')), findsOneWidget);
        expect(find.text('Stem Lab'), findsOneWidget);

        expect(find.byKey(const Key('home_hub_beats_market')), findsOneWidget);
        expect(find.text('Beats Market'), findsOneWidget);

        expect(find.byKey(const Key('home_hub_asset_vault')), findsOneWidget);
        expect(find.text('Asset Vault'), findsOneWidget);

        // Tap AI Studio
        await tester.tap(find.byKey(const Key('home_hub_ai_studio')));
        expect(studioNavigated, isTrue);

        // Tap Beats Market
        await tester.tap(find.byKey(const Key('home_hub_beats_market')));
        expect(marketNavigated, isTrue);

        // Tap Asset Vault
        await tester.tap(find.byKey(const Key('home_hub_asset_vault')));
        expect(libraryNavigated, isTrue);

        // Tap Voice Clone -> opens VocalIdentityPickerSheet
        await tester.tap(find.byKey(const Key('home_hub_voice_clone')));
        await tester.pumpAndSettle();
        expect(find.byType(VocalIdentityPickerSheet), findsOneWidget);

        // Dismiss modal
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Tap Melody Sketchpad -> opens MelodySketchpadModal
        await tester.tap(find.byKey(const Key('home_hub_melody_sketchpad')));
        await tester.pumpAndSettle();
        expect(find.byType(MelodySketchpadModal), findsOneWidget);
      },
    );

    testWidgets(
      'Finding HOME-005: 7-Day Rhythm Spotlight rotates dynamically and preconfigures Studio presets',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        bool studioNavigated = false;
        late ProviderContainer container;

        await tester.pumpWidget(
          ProviderScope(
            child: Consumer(
              builder: (context, ref, child) {
                container = ProviderScope.containerOf(context);
                return MaterialApp(
                  theme: AppTheme.darkTheme,
                  // Injected weekday 2 = Durban Gqom Tuesday
                  home: HomeDashboardView(
                    injectedWeekday: 2,
                    onNavigateToStudio: () => studioNavigated = true,
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('DAILY RHYTHM SPOTLIGHT • TUESDAY'),
          findsOneWidget,
        );
        expect(find.textContaining('Durban Gqom Broken Beat'), findsOneWidget);

        final tryRhythmBtn = find.byKey(const Key('home_try_rhythm_btn'));
        expect(tryRhythmBtn, findsOneWidget);

        await tester.ensureVisible(tryRhythmBtn);
        await tester.pumpAndSettle();
        await tester.tap(tryRhythmBtn);
        await tester.pumpAndSettle();

        expect(studioNavigated, isTrue);
        // Verify genre and prompt were injected into studioFormProvider
        expect(container.read(studioFormProvider).genre, equals('Gqom'));
        expect(
          container.read(studioFormProvider).prompt,
          contains('Durban Gqom'),
        );
        // Verify sketchpad activePattern was configured
        expect(
          container.read(melodySketchpadProvider).activePattern.genre,
          equals('Gqom'),
        );
        expect(
          container.read(melodySketchpadProvider).activePattern.bpm,
          equals(127),
        );
      },
    );

    testWidgets(
      'Finding HOME-006: Trending in Your Genres properly filters by onboardingState.selectedGenres',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith(
                (ref) => _CustomOnboardingNotifier(
                  const OnboardingState(
                    selectedGenres: ['Gqom'],
                    selectedLanguages: ['isiZulu'],
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const HomeDashboardView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Trending in Your Genres'), findsOneWidget);
        expect(find.text('Gqom'), findsOneWidget);
      },
    );

    testWidgets(
      'Finding HOME-007: In-Flight generation banner renders conditionally and navigates to Studio',
      (tester) async {
        bool studioNavigated = false;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              generationProgressProvider.overrideWith(
                (ref) => _CustomPipelineNotifier(
                  ref,
                  const GenerationProgressState(
                    generationId: 'gen_active_123',
                    trackTitle: 'Venda Royal Rhythm',
                    genre: 'Amapiano',
                    currentStep: PipelineStep.producingBeat,
                    statusMessage: 'Generating 3D stem audio with Cloud GPU...',
                    progressPercent: 0.65,
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: HomeDashboardView(
                onNavigateToStudio: () => studioNavigated = true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final banner = find.byKey(const Key('home_inflight_generation_banner'));
        expect(banner, findsOneWidget);
        expect(find.textContaining('Venda Royal Rhythm'), findsOneWidget);
        expect(find.textContaining('65%'), findsOneWidget);

        await tester.tap(banner);
        expect(studioNavigated, isTrue);
      },
    );

    testWidgets(
      'Finding HOME-008: 360x800 compact mobile viewport renders without any RenderFlex overflows',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              onboardingStateProvider.overrideWith(
                (ref) => _CustomOnboardingNotifier(
                  const OnboardingState(selectedLanguages: ['Setswana']),
                ),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              home: const HomeDashboardView(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('home_greeting_text')), findsOneWidget);
        expect(find.byKey(const Key('home_streak_pill')), findsOneWidget);
        expect(find.byKey(const Key('home_coins_pill')), findsOneWidget);
        expect(find.byKey(const Key('home_notifications_btn')), findsOneWidget);
      },
    );
  });
}

class _CustomOwnerProfileNotifier extends ArtistProfileNotifier {
  _CustomOwnerProfileNotifier(ArtistProfileEntity initial) : super('me') {
    state = initial;
  }
}

class _CustomCreatorWalletNotifier extends CreatorWalletNotifier {
  _CustomCreatorWalletNotifier(super.ref, CreatorWalletState initial) {
    state = initial;
  }
}

class _CustomLibraryTracksNotifier extends LibraryTracksNotifier {
  _CustomLibraryTracksNotifier(List<LibraryTrack> initial) {
    state = initial;
  }
}

class _CustomOnboardingNotifier extends OnboardingNotifier {
  _CustomOnboardingNotifier(OnboardingState initial) {
    state = initial;
  }
}

class _CustomPipelineNotifier extends GenerationPipelineNotifier {
  _CustomPipelineNotifier(super.ref, GenerationProgressState initial) {
    state = initial;
  }
}
