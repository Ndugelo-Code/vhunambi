import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/mastering/presentation/providers/mastering_session_provider.dart';
import 'package:vhunambi_client/features/mastering/presentation/views/desktop_mastering_studio_view.dart';
import 'package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart';
import 'package:vhunambi_client/features/player/domain/services/i_multi_stem_audio_engine.dart';
import 'package:vhunambi_client/features/player/presentation/providers/multi_stem_audio_provider.dart';

class _FakeMultiStemEngine extends Fake implements IMultiStemAudioEngine {
  @override
  final bool hasRealStems;

  _FakeMultiStemEngine({this.hasRealStems = true});

  @override
  bool get isPlaying => false;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  Duration get totalDuration => Duration.zero;

  @override
  Stream<Duration> get positionStream => Stream.value(Duration.zero);

  @override
  Stream<bool> get isPlayingStream => Stream.value(false);

  @override
  Duration? get measuredDrift => Duration.zero;

  @override
  void applyMixerState(StemMixerState state) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DesktopMasteringStudioView Widget Tests (REQ-MST-UI-02..03)', () {
    testWidgets('Renders desktop rack with 4 channel strips, EQ graphs, and DSP sliders',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeEngine = _FakeMultiStemEngine(hasRealStems: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            multiStemAudioEngineProvider.overrideWithValue(fakeEngine),
          ],
          child: const MaterialApp(
            home: DesktopMasteringStudioView(
              trackId: 'trk_desktop_master',
              trackTitle: 'Private School Sunrise',
              genre: 'Amapiano',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Console Root
      expect(find.byKey(const Key('desktop_mastering_studio_view')), findsOneWidget);

      // Top bar controls
      expect(find.byKey(const Key('desktop_mastering_ab_toggle')), findsOneWidget);
      expect(find.byKey(const Key('desktop_lufs_toggle')), findsOneWidget);
      expect(find.byKey(const Key('desktop_mastering_bake_btn')), findsOneWidget);

      // 4-Band Parametric EQ Curve Graphs
      expect(find.byKey(const Key('eq_curve_vocals')), findsOneWidget);
      expect(find.byKey(const Key('eq_curve_bass')), findsOneWidget);
      expect(find.byKey(const Key('eq_curve_drums')), findsOneWidget);
      expect(find.byKey(const Key('eq_curve_melodic')), findsOneWidget);

      // Granular DSP Sliders
      expect(find.byKey(const Key('slider_vocal_denoise')), findsOneWidget);
      expect(find.byKey(const Key('slider_bass_sub_harmonic')), findsOneWidget);
      expect(find.byKey(const Key('slider_bass_knock_drive')), findsOneWidget);
      expect(find.byKey(const Key('slider_bass_sidechain_duck')), findsOneWidget);
    });

    testWidgets('Honest Master-Only notice is displayed on desktop when stems are unavailable',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeEngine = _FakeMultiStemEngine(hasRealStems: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            multiStemAudioEngineProvider.overrideWithValue(fakeEngine),
          ],
          child: const MaterialApp(
            home: DesktopMasteringStudioView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mastering_master_only_notice')), findsOneWidget);
    });

    testWidgets('Toggling desktop A/B switch toggles preview state', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeEngine = _FakeMultiStemEngine(hasRealStems: true);
      final container = ProviderContainer(
        overrides: [
          multiStemAudioEngineProvider.overrideWithValue(fakeEngine),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DesktopMasteringStudioView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(masteringSessionProvider).isMasteredPreviewActive, isTrue);

      await tester.tap(find.byKey(const Key('desktop_mastering_ab_toggle')));
      await tester.pumpAndSettle();

      expect(container.read(masteringSessionProvider).isMasteredPreviewActive, isFalse);
    });

    testWidgets('Tapping desktop LUFS toggle alternates target loudness', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeEngine = _FakeMultiStemEngine(hasRealStems: true);
      final container = ProviderContainer(
        overrides: [
          multiStemAudioEngineProvider.overrideWithValue(fakeEngine),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DesktopMasteringStudioView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(masteringSessionProvider).recipe.targetLufs, -9.5);

      await tester.tap(find.byKey(const Key('desktop_lufs_toggle')));
      await tester.pumpAndSettle();

      expect(container.read(masteringSessionProvider).recipe.targetLufs, -14.0);
    });
  });
}
