import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/lyric_word_timestamp.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/master_media_object.dart';
import 'package:vhunambi_client/features/content_studio/presentation/providers/master_media_object_provider.dart';
import 'package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart';
import 'package:vhunambi_client/features/player/presentation/providers/stem_mixer_provider.dart';

void main() {
  group('MasterMediaObject Domain & Telemetry Tests', () {
    late SongMetadataDna sampleDna;

    setUp(() {
      sampleDna = const SongMetadataDna(
        id: 'dna_mmo_test_01',
        title: 'Amapiano Pulse',
        genre: 'Amapiano',
        language: 'Tshivenḓa',
        musical: MusicalDna(
          bpm: 112,
          key: 'E Minor',
          energyBracket: 'mid',
          durationSec: 180,
        ),
        vocals: VocalsDna(
          deliveryMode: 'melodic',
          gender: 'female',
          energy: 'mid',
        ),
        visualTheme: VisualThemeDna(
          mood: 'Energetic twilight',
          comfyPrompt: 'Amapiano pulse visual',
          seed: 12345,
          aspectRatio: '9:16',
        ),
        alignment: [
          LyricWordTimestamp(
            word: 'Woza',
            start: 5.0,
            end: 5.4,
            phoneticStress: 0.9,
            isCulturalIdiom: true,
          ),
          LyricWordTimestamp(
            word: 'Vhunambi',
            start: 5.5,
            end: 6.2,
            phoneticStress: 0.6,
          ),
        ],
      );
    });

    test('MasterMediaObject.fromSongMetadataDna creates authentic 60 Hz curves', () {
      final mmo = MasterMediaObject.fromSongMetadataDna(sampleDna);

      expect(mmo.schemaVersion, equals('2.0'));
      expect(mmo.provenance, equals(ManifestProvenance.synthesized));
      expect(mmo.dna.id, equals('dna_mmo_test_01'));

      final bus = mmo.modulationBus;
      expect(bus.sampleRateHz, equals(60));
      expect(bus.durationMs, equals(180000));
      expect(bus.frameCount, equals(10800));

      expect(bus.masterRmsBytes.length, equals(10800));
      expect(bus.vocalsBytes.length, equals(10800));
      expect(bus.drumsBytes.length, equals(10800));
      expect(bus.bassBytes.length, equals(10800));
      expect(bus.melodicBytes.length, equals(10800));

      // Test O(1) sampling with gain and mute
      final sampledDrums = bus.sampleStemCurve(bus.drumsBytes, 1000, gain: 1.0);
      expect(sampledDrums, inInclusiveRange(0.0, 1.0));

      final mutedDrums = bus.sampleStemCurve(bus.drumsBytes, 1000, gain: 1.0, isMuted: true);
      expect(mutedDrums, equals(0.0));

      final halfGainDrums = bus.sampleStemCurve(bus.drumsBytes, 1000, gain: 0.5);
      expect(halfGainDrums, inInclusiveRange(0.0, 0.5));
    });

    test('Stratified 8-pad MPC kit enforces correct stem roles and bounds', () {
      final mmo = MasterMediaObject.fromSongMetadataDna(sampleDna);
      final pads = mmo.mpcKitPads;

      expect(pads.length, equals(8));

      // Check roles
      expect(pads[0].sourceStem, equals(StemType.drums));
      expect(pads[1].sourceStem, equals(StemType.drums));
      expect(pads[2].sourceStem, equals(StemType.bass));
      expect(pads[3].sourceStem, equals(StemType.bass));
      expect(pads[4].sourceStem, equals(StemType.melody));
      expect(pads[5].sourceStem, equals(StemType.melody));
      expect(pads[6].sourceStem, equals(StemType.vocals));
      expect(pads[7].sourceStem, equals(StemType.vocals));

      for (var i = 0; i < 8; i++) {
        expect(pads[i].padIndex, equals(i));
        expect(pads[i].startSec, greaterThanOrEqualTo(0.0));
        expect(pads[i].endSec, greaterThan(pads[i].startSec));
        expect(pads[i].endSec, lessThanOrEqualTo(180.0));
      }
    });

    test('Transient impulse decay computes exponential drop properly', () {
      final mmo = MasterMediaObject.fromSongMetadataDna(sampleDna);
      final bus = mmo.modulationBus;

      // Find first log drum drop
      final dropEvent = bus.transientEvents.firstWhere(
        (e) => e.type == TransientEventType.logDrumDrop,
      );

      final onsetMs = dropEvent.timestampMs;

      // At onset, impulse is peak intensity
      final peakImpulse = bus.computeTransientImpulse(
        TransientEventType.logDrumDrop,
        onsetMs,
      );
      expect(peakImpulse, inInclusiveRange(0.9, 1.0));

      // After 100ms, impulse has decayed
      final decayedImpulse = bus.computeTransientImpulse(
        TransientEventType.logDrumDrop,
        onsetMs + 100,
      );
      expect(decayedImpulse, lessThan(peakImpulse));

      // When muted, impulse is 0.0
      final mutedImpulse = bus.computeTransientImpulse(
        TransientEventType.logDrumDrop,
        onsetMs,
        isMuted: true,
      );
      expect(mutedImpulse, equals(0.0));
    });

    test('Bidirectional wire format mappers translate correctly', () {
      expect(stemTypeFromWireString('melodic'), equals(StemType.melody));
      expect(stemTypeFromWireString('melody'), equals(StemType.melody));
      expect(stemTypeToWireString(StemType.melody), equals('melodic'));

      expect(stemTypeFromWireString('vocals'), equals(StemType.vocals));
      expect(stemTypeFromWireString('drums'), equals(StemType.drums));
      expect(stemTypeFromWireString('bass'), equals(StemType.bass));

      expect(transientTypeFromWireString('log_drum_drop'),
          equals(TransientEventType.logDrumDrop));
      expect(transientTypeToWireString(TransientEventType.logDrumDrop),
          equals('log_drum_drop'));
    });

    test('Lossless JSON serialization and revival', () {
      final mmo = MasterMediaObject.fromSongMetadataDna(sampleDna);
      final json = mmo.toJson();

      final revived = MasterMediaObject.fromJson(json);

      expect(revived.schemaVersion, equals('2.0'));
      expect(revived.provenance, equals(ManifestProvenance.synthesized));
      expect(revived.dna.id, equals(sampleDna.id));
      expect(revived.dna.musical.bpm, equals(sampleDna.musical.bpm));
      expect(revived.mpcKitPads.length, equals(8));
      expect(revived.sections.length, equals(mmo.sections.length));
      expect(revived.modulationBus.frameCount, equals(mmo.modulationBus.frameCount));
      expect(revived.modulationBus.transientEvents.length,
          equals(mmo.modulationBus.transientEvents.length));
    });

    test('frameModulationSnapshotProvider combines MMO curves with StemMixerState', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Default state: all stems unity gain (1.0)
      final snapshot = container.read(frameModulationSnapshotProvider((
        dna: sampleDna,
        positionMs: 5000,
      )));

      expect(snapshot.effectiveBassEnergy, inInclusiveRange(0.0, 1.0));
      expect(snapshot.effectiveDrumsEnergy, inInclusiveRange(0.0, 1.0));
      expect(snapshot.effectiveVocalGlow, inInclusiveRange(0.0, 1.0));

      // Mute the bass channel in stemMixerProvider
      final mixerNotifier = container.read(stemMixerProvider.notifier);
      mixerNotifier.toggleMute(StemType.bass);

      final mutedSnapshot = container.read(frameModulationSnapshotProvider((
        dna: sampleDna,
        positionMs: 5000,
      )));

      expect(mutedSnapshot.effectiveBassEnergy, equals(0.0));
      expect(mutedSnapshot.logDrumSnapZoom, equals(0.0));
      // Drums and vocals still active
      expect(mutedSnapshot.effectiveDrumsEnergy, equals(snapshot.effectiveDrumsEnergy));
    });
  });
}
