import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/studio/domain/models/heritage_crate_models.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/heritage_crate_provider.dart';

void main() {
  group('HeritageCrateNotifier & heritageCrateProvider', () {
    test('initial state loads seeded authentic indigenous samples', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(heritageCrateProvider);
      expect(state.allSamples.length, greaterThanOrEqualTo(6));
      expect(state.activeCategory, equals(HeritageCrateCategory.all));
      expect(state.filteredSamples.length, equals(state.allSamples.length));
    });

    test('filtering by category filters relevant indigenous samples', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(heritageCrateProvider.notifier);

      // Filter percussion
      notifier.setCategory(HeritageCrateCategory.percussion);
      var state = container.read(heritageCrateProvider);
      expect(state.filteredSamples.any((s) => s.id == 'sample_talkingdrum_01'), isTrue);
      expect(state.filteredSamples.any((s) => s.id == 'sample_kora_01'), isFalse);

      // Filter plucked strings
      notifier.setCategory(HeritageCrateCategory.pluckedStrings);
      state = container.read(heritageCrateProvider);
      expect(state.filteredSamples.any((s) => s.id == 'sample_kora_01'), isTrue);

      // Filter melodic idiophones (Mbira & Marimba)
      notifier.setCategory(HeritageCrateCategory.melodicIdiophones);
      state = container.read(heritageCrateProvider);
      expect(state.filteredSamples.any((s) => s.id == 'sample_mbira_01'), isTrue);
      expect(state.filteredSamples.any((s) => s.id == 'sample_marimba_01'), isTrue);
    });

    test('search query matches sample names, instruments and culture regions', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(heritageCrateProvider.notifier);
      notifier.setSearchQuery('Venda');

      final state = container.read(heritageCrateProvider);
      expect(state.filteredSamples.length, equals(1));
      expect(state.filteredSamples.first.id, equals('sample_chants_01'));
    });

    test('toggling favorite flips isFavorite state on sample', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(heritageCrateProvider.notifier);
      notifier.toggleFavorite('sample_mbira_01');

      var sample = container
          .read(heritageCrateProvider)
          .allSamples
          .firstWhere((s) => s.id == 'sample_mbira_01');
      expect(sample.isFavorite, isTrue);

      notifier.toggleFavorite('sample_mbira_01');
      sample = container
          .read(heritageCrateProvider)
          .allSamples
          .firstWhere((s) => s.id == 'sample_mbira_01');
      expect(sample.isFavorite, isFalse);
    });

    test('startAudition and stopAudition manage active vinyl playback', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(heritageCrateProvider.notifier);
      notifier.startAudition('sample_kora_01');
      expect(container.read(heritageCrateProvider).auditioningSampleId, 'sample_kora_01');

      notifier.stopAudition();
      expect(container.read(heritageCrateProvider).auditioningSampleId, isNull);
    });
  });

  group('MpcSlicerNotifier & mpcSlicerProvider', () {
    test('initial state contains 8 default MPC pads', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(mpcSlicerProvider);
      expect(state.pads.length, equals(8));
      expect(state.selectedPadIndex, equals(0));
      expect(state.timeStretchRatio, equals(1.0));
    });

    test('sliceSample auto-chops sample into 8 contiguous temporal pads', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sample = kSeededHeritageSamples.first; // 16.0s duration
      final notifier = container.read(mpcSlicerProvider.notifier);
      notifier.sliceSample(sample);

      final state = container.read(mpcSlicerProvider);
      expect(state.pads.length, equals(8));
      expect(state.sourceTitle, equals(sample.name));
      expect(state.bpm, equals(sample.bpm));

      // Each slice should be 16.0 / 8 = 2.0s
      expect(state.pads[0].startSec, equals(0.0));
      expect(state.pads[0].endSec, equals(2.0));
      expect(state.pads[7].startSec, equals(14.0));
      expect(state.pads[7].endSec, equals(16.0));
    });

    test('triggerPad and releasePad toggle tactile activation state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mpcSlicerProvider.notifier);
      notifier.triggerPad(2);

      var state = container.read(mpcSlicerProvider);
      expect(state.pads[2].isTriggered, isTrue);
      expect(state.selectedPadIndex, equals(2));

      notifier.releasePad(2);
      state = container.read(mpcSlicerProvider);
      expect(state.pads[2].isTriggered, isFalse);
    });

    test('pitch shifting modulates semitones clamped to -12..+12', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mpcSlicerProvider.notifier);
      notifier.setPitchShift(0, 5);
      expect(container.read(mpcSlicerProvider).pads[0].pitchShiftSemitones, equals(5));

      notifier.setPitchShift(0, 20); // Clamped
      expect(container.read(mpcSlicerProvider).pads[0].pitchShiftSemitones, equals(12));

      notifier.setPitchShift(0, -30); // Clamped
      expect(container.read(mpcSlicerProvider).pads[0].pitchShiftSemitones, equals(-12));
    });

    test('toggleReverse flips reverse flag on targeted pad', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mpcSlicerProvider.notifier);
      expect(container.read(mpcSlicerProvider).pads[1].isReversed, isFalse);

      notifier.toggleReverse(1);
      expect(container.read(mpcSlicerProvider).pads[1].isReversed, isTrue);

      notifier.toggleReverse(1);
      expect(container.read(mpcSlicerProvider).pads[1].isReversed, isFalse);
    });

    test('setPadVolume and setTimeStretch enforce boundaries', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mpcSlicerProvider.notifier);
      notifier.setPadVolume(3, 1.4);
      expect(container.read(mpcSlicerProvider).pads[3].volume, closeTo(1.4, 0.001));

      notifier.setTimeStretch(1.5);
      expect(container.read(mpcSlicerProvider).timeStretchRatio, equals(1.5));
    });

    test('bounceChops renders and records a local chop kit audio path', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(mpcSlicerProvider.notifier);
      final path = await notifier.bounceChops();

      expect(path, contains('/vault/chops/mpc_kit_'));
      expect(container.read(mpcSlicerProvider).lastBouncedChopPath, equals(path));
    });
  });
}
