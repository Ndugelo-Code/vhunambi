import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/mastering/presentation/providers/mastering_session_provider.dart';
import 'package:vhunambi_client/features/mastering/presentation/widgets/mobile_quick_master_sheet.dart';
import 'package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart';
import 'package:vhunambi_client/features/player/domain/services/i_multi_stem_audio_engine.dart';
import 'package:vhunambi_client/features/player/presentation/providers/multi_stem_audio_provider.dart';

class _FakeMultiStemEngine extends Fake implements IMultiStemAudioEngine {
  @override
  final bool hasRealStems;

  _FakeMultiStemEngine({this.hasRealStems = false});

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

  group('MobileQuickMasterSheet Widget Tests (REQ-MST-UI-01..03)', () {
    testWidgets(
        'Renders all required controls and Master-Only notice when hasRealStems=false',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
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
            home: Scaffold(
              body: MobileQuickMasterSheet(
                trackId: 'trk_test_01',
                trackTitle: 'Mnike Vocal Cut',
                genre: 'Amapiano',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sheet root
      expect(find.byKey(const Key('mobile_quick_master_sheet')), findsOneWidget);

      // Honest Master-Only Notice
      expect(find.byKey(const Key('mastering_master_only_notice')), findsOneWidget);

      // A/B Audition Toggle
      expect(find.byKey(const Key('mastering_ab_toggle')), findsOneWidget);

      // Preset index 0
      expect(find.byKey(const Key('mastering_preset_amapiano_club_knock')), findsOneWidget);

      // Flavors
      expect(find.byKey(const Key('vocal_flavor_studioClean')), findsOneWidget);
      expect(find.byKey(const Key('bass_flavor_heavyWoodenKnock')), findsOneWidget);
      expect(find.byKey(const Key('drum_flavor_crispShakers')), findsOneWidget);
      expect(find.byKey(const Key('melodic_flavor_wideStereoPocket')), findsOneWidget);

      // Loudness targets
      expect(find.byKey(const Key('mastering_lufs_club')), findsOneWidget);
      expect(find.byKey(const Key('mastering_lufs_stream')), findsOneWidget);

      // Bake button
      expect(find.byKey(const Key('mastering_bake_btn')), findsOneWidget);
    });

    testWidgets('Honest Master-Only notice is hidden when hasRealStems=true',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
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
            home: Scaffold(
              body: MobileQuickMasterSheet(
                trackId: 'trk_test_stems',
                trackTitle: 'Full 4-Stem Track',
                genre: 'Gqom',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mastering_master_only_notice')), findsNothing);
    });

    testWidgets('Tapping A/B toggle toggles preview state', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeEngine = _FakeMultiStemEngine(hasRealStems: false);
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
            home: Scaffold(
              body: MobileQuickMasterSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(masteringSessionProvider).isMasteredPreviewActive, isTrue);

      await tester.tap(find.byKey(const Key('mastering_ab_toggle')));
      await tester.pumpAndSettle();

      expect(container.read(masteringSessionProvider).isMasteredPreviewActive, isFalse);
    });

    testWidgets('Tapping preset applies recipe to session', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeEngine = _FakeMultiStemEngine(hasRealStems: false);
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
            home: Scaffold(
              body: MobileQuickMasterSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mastering_preset_private_school_warmth')));
      await tester.pumpAndSettle();

      expect(
        container.read(masteringSessionProvider).recipe.presetId,
        'private_school_warmth',
      );
    });

    testWidgets('Tapping LUFS stream selector updates recipe target', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeEngine = _FakeMultiStemEngine(hasRealStems: false);
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
            home: Scaffold(
              body: MobileQuickMasterSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('mastering_lufs_stream')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mastering_lufs_stream')));
      await tester.pumpAndSettle();

      expect(container.read(masteringSessionProvider).recipe.targetLufs, -14.0);
    });
  });
}
