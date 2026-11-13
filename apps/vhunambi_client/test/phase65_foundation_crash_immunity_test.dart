import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/network/error_handler.dart';
import 'package:vhunambi_client/core/resilience/safe_audio_orchestrator.dart';
import 'package:vhunambi_client/core/resilience/safe_notifier_mixin.dart';
import 'package:vhunambi_client/core/resilience/vhunambi_crash_shield.dart';
import 'package:vhunambi_client/core/utils/json_safe.dart';
import 'package:vhunambi_client/core/widgets/safe_network_avatar.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import 'package:vhunambi_client/features/player/domain/models/player_state.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_form_state.dart';
import 'package:vhunambi_client/features/studio/domain/services/studio_prompt_intelligence.dart';

class _TestAsyncNotifier extends StateNotifier<int>
    with SafeNotifierMixin<int> {
  _TestAsyncNotifier() : super(0);

  Future<bool> mutateAfterDelay(Duration delay, int nextVal) async {
    await Future<void>.delayed(delay);
    return setStateIfMounted(nextVal);
  }
}

void main() {
  setUp(() {
    VhunambiCrashShield.breadcrumbs.clear();
    SafeAudioOrchestrator.instance.resetForTesting();
  });

  test(
    'T1 (REQ-P65-L1-01): ic_stat_music.xml exists and is valid vector drawable',
    () {
      final iconFile = File(
        'android/app/src/main/res/drawable/ic_stat_music.xml',
      );
      expect(iconFile.existsSync(), isTrue);
      final xml = iconFile.readAsStringSync();
      expect(xml, contains('<vector'));
      expect(xml, contains('android:width="24dp"'));
      expect(xml, contains('android:height="24dp"'));
      expect(xml, contains('#FFFFFF'));

      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);
      expect(
        manifestFile.readAsStringSync(),
        contains('@drawable/ic_stat_music'),
      );
    },
  );

  test(
    'T2 & T4 (REQ-P65-L1-02/04): VhunambiCrashShield contains platform errors & startup timeouts',
    () async {
      VhunambiCrashShield.installFrameworkHandlers();
      final handled = VhunambiCrashShield.recordPlatformError(
        StateError('Simulated native plugin failure'),
        StackTrace.current,
      );
      expect(handled, isTrue);
      expect(VhunambiCrashShield.breadcrumbs.length, greaterThanOrEqualTo(1));

      final fallbackVal = await VhunambiCrashShield.guardStartup<String>(
        stepName: 'hung_box',
        timeout: const Duration(milliseconds: 30),
        action: () async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return 'never_reached';
        },
        fallback: () => 'degraded_ok',
      );
      expect(fallbackVal, equals('degraded_ok'));
    },
  );

  testWidgets(
    'T3 (REQ-P65-L1-03): VhunambiSafeErrorCard renders with retry button',
    (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VhunambiSafeErrorCard(onRetry: () => retried = true),
          ),
        ),
      );
      expect(find.byKey(const Key('vhunambi_safe_error_card')), findsOneWidget);
      await tester.tap(find.byKey(const Key('vhunambi_safe_error_retry_btn')));
      expect(retried, isTrue);
    },
  );

  test(
    'T5 & T6 (REQ-P65-L2-01/04): SafeAudioOrchestrator preempts slots and contains timeouts',
    () async {
      var masterPaused = false;
      var stemPaused = false;

      await SafeAudioOrchestrator.instance.acquireSlot(
        AudioEngineSlot.masterPlayer,
        onPreemptPause: () async {
          masterPaused = true;
        },
      );
      expect(
        SafeAudioOrchestrator.instance.activeSlot,
        AudioEngineSlot.masterPlayer,
      );

      await SafeAudioOrchestrator.instance.acquireSlot(
        AudioEngineSlot.stemMixer,
        onPreemptPause: () async {
          stemPaused = true;
        },
      );
      expect(masterPaused, isTrue);
      expect(
        SafeAudioOrchestrator.instance.activeSlot,
        AudioEngineSlot.stemMixer,
      );

      await SafeAudioOrchestrator.instance.acquireSlot(AudioEngineSlot.reelPool);
      expect(stemPaused, isTrue);
      expect(
        SafeAudioOrchestrator.instance.activeSlot,
        AudioEngineSlot.reelPool,
      );

      final guardedFallback = await SafeAudioOrchestrator.guardAudioOp<String>(
        source: 'test_timeout_op',
        timeout: const Duration(milliseconds: 25),
        action: () async {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          return 'late';
        },
        fallbackValue: 'safe_fallback',
      );
      expect(guardedFallback, 'safe_fallback');
    },
  );

  test(
    'T7 & T8 (REQ-P65-L2-02/04): PlayerNotifier boots paused at 0:00 and normalizes vhunambi.com URLs',
    () {
      final notifier = PlayerNotifier();
      addTearDown(notifier.dispose);
      expect(notifier.state.playbackStatus, PlaybackStatus.paused);
      expect(notifier.state.position, Duration.zero);
      expect(notifier.state.currentTrack?.audioUrl, isNotNull);

      final normalized = AppConstants.normalizeCloudMediaUrl(
        'https://vhunambi.com/audio/track_default_1.mp3',
        overrideOrigin: 'https://api.vhunambi.co.za',
      );
      expect(
        normalized,
        'https://api.vhunambi.co.za/r2/audio/track_default_1.mp3',
      );
    },
  );

  test(
    'T11 & T12 (REQ-P65-L3-02/03): SafeNotifierMixin prevents post-dispose state mutation',
    () async {
      final notifier = _TestAsyncNotifier();
      final future = notifier.mutateAfterDelay(
        const Duration(milliseconds: 40),
        99,
      );
      notifier.dispose();
      final updated = await future;
      expect(updated, isFalse);
    },
  );

  testWidgets(
    'T13 (REQ-P65-L3-04): SafeNetworkAvatar renders fallback initial when URL is empty',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeNetworkAvatar(imageUrl: '', fallbackLabel: 'Makhadzi'),
          ),
        ),
      );
      expect(
        find.byKey(const Key('safe_network_avatar_fallback')),
        findsOneWidget,
      );
      expect(find.text('M'), findsOneWidget);
    },
  );

  test(
    'T14 & T16 (REQ-P65-L4-01/04): JsonSafe & NetworkErrorHandler classify DioException',
    () {
      expect(JsonSafe.decodeMap('{corrupt_json'), isNull);
      expect(JsonSafe.asInt('42'), 42);
      expect(JsonSafe.asDouble(null, 3.5), 3.5);

      const handler = NetworkErrorHandler();
      final dioTimeout = DioException(
        requestOptions: RequestOptions(path: '/v1/generations'),
        type: DioExceptionType.connectionTimeout,
      );
      expect(handler.classify(dioTimeout), ErrorType.timeout);

      final dioOffline = DioException(
        requestOptions: RequestOptions(path: '/v1/generations'),
        type: DioExceptionType.connectionError,
      );
      expect(handler.classify(dioOffline), ErrorType.noConnection);
    },
  );

  test(
    'T18 (REQ-P65-L5-03): StudioPromptIntelligence prioritizes active Tshivenḓa + 90s Kwaito form over DNA defaults',
    () {
      final dna = CreatorDnaProfile.initial().copyWith(
        onboardingCompleted: true,
        genreWeights: const <String, double>{'Afro Soul': 5.0},
        primaryLanguage: 'English',
      );
      const activeForm = StudioFormState(
        genre: 'Kwaito',
        language: 'Tshivenḓa',
        era: ProductionEra.vintage90s,
        mood: 'Energetic',
      );

      final res = StudioPromptIntelligence.enhance(
        'Street party anthem in the township',
        dna: dna,
        currentForm: activeForm,
      );

      expect(res.suggestedOverrides['genre'], '90s Kwaito');
      expect(res.suggestedOverrides['language'], 'Tshivenḓa');
      expect(res.enhancedPrompt, contains('with Tshivenḓa vocal delivery'));
      expect(
        res.enhancedPrompt,
        contains('crafted in the 90s Kwaito tradition'),
      );
      expect(res.enhancedPrompt, isNot(contains('Afro Soul')));
      expect(res.enhancedPrompt, isNot(contains('English')));
    },
  );
}
