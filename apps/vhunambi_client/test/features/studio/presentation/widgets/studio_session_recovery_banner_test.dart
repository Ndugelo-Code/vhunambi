import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_session_draft.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_form_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_session_provider.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/studio_session_recovery_banner.dart';

void main() {
  testWidgets('StudioSessionRecoveryBanner does not render when no saved session', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: StudioSessionRecoveryBanner(),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('studio_session_recovery_banner')), findsNothing);
  });

  testWidgets('renders banner when a recoverable draft is available', (tester) async {
    final draft = StudioSessionDraft(
      sessionId: 'sess_1',
      savedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      prompt: 'Soulful Maskandi vibes',
      genre: 'Maskandi',
      region: 'KwaZulu-Natal',
      language: 'isiZulu',
      isInstrumental: false,
      durationSeconds: 120,
      lyricsMode: 'myOwn',
      mood: 'Nostalgic',
      tempo: 'medium',
      vocalVoices: 'solo',
      vocalGender: 'male',
      vocalMode: 'melodic',
      vocalEnergy: 'soft',
      songStructure: 'standard',
      isAutoTitle: true,
      isPublic: true,
    );

    final container = ProviderContainer(
      overrides: [
        studioSessionProvider.overrideWith(
          (ref) => StudioSessionNotifier(
            ref.read(studioSessionRepositoryProvider),
            ref,
          )..state = StudioSessionState(
              recoveryState: SessionRecoveryState.available,
              savedDraft: draft,
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
          home: const Scaffold(
            body: StudioSessionRecoveryBanner(),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('studio_session_recovery_banner')), findsOneWidget);
    expect(find.textContaining('Soulful Maskandi vibes'), findsOneWidget);
    expect(find.byKey(const Key('session_restore_btn')), findsOneWidget);
    expect(find.byKey(const Key('session_discard_btn')), findsOneWidget);
  });

  testWidgets('tapping Restore applies draft to studioFormProvider', (tester) async {
    final draft = StudioSessionDraft(
      sessionId: 'sess_restore',
      savedAt: DateTime.now(),
      prompt: 'Amapiano Piano Roll',
      genre: 'Amapiano',
      region: 'Pretoria',
      language: 'Sepedi',
      isInstrumental: true,
      durationSeconds: 180,
      lyricsMode: 'instrumental',
      mood: 'Joyful',
      tempo: 'medium',
      vocalVoices: 'solo',
      vocalGender: 'male',
      vocalMode: 'auto',
      vocalEnergy: 'mid',
      songStructure: 'standard',
      isAutoTitle: true,
      isPublic: true,
    );

    final container = ProviderContainer(
      overrides: [
        studioSessionProvider.overrideWith(
          (ref) => StudioSessionNotifier(
            ref.read(studioSessionRepositoryProvider),
            ref,
          )..state = StudioSessionState(
              recoveryState: SessionRecoveryState.available,
              savedDraft: draft,
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
          home: const Scaffold(
            body: StudioSessionRecoveryBanner(),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('session_restore_btn')));
    await tester.pump(const Duration(milliseconds: 150));

    final formState = container.read(studioFormProvider);
    expect(formState.prompt, 'Amapiano Piano Roll');
    expect(formState.language, 'Sepedi');
    expect(formState.isInstrumental, isTrue);
  });

  testWidgets('tapping Discard dismisses the banner and clears draft', (tester) async {
    final draft = StudioSessionDraft(
      sessionId: 'sess_discard',
      savedAt: DateTime.now(),
      prompt: 'Discard me',
      genre: 'Gqom',
      region: 'Durban',
      language: 'isiZulu',
      isInstrumental: false,
      durationSeconds: 60,
      lyricsMode: 'aiWrite',
      mood: 'Dark',
      tempo: 'fast',
      vocalVoices: 'solo',
      vocalGender: 'male',
      vocalMode: 'auto',
      vocalEnergy: 'mid',
      songStructure: 'standard',
      isAutoTitle: true,
      isPublic: true,
    );

    final container = ProviderContainer(
      overrides: [
        studioSessionProvider.overrideWith(
          (ref) => StudioSessionNotifier(
            ref.read(studioSessionRepositoryProvider),
            ref,
          )..state = StudioSessionState(
              recoveryState: SessionRecoveryState.available,
              savedDraft: draft,
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
          home: const Scaffold(
            body: StudioSessionRecoveryBanner(),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('session_discard_btn')));
    await tester.pump();

    final session = container.read(studioSessionProvider);
    expect(session.recoveryState, SessionRecoveryState.none);
  });
}
