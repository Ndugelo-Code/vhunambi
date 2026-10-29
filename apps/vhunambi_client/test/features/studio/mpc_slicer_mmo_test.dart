import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/master_media_object.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/heritage_crate_provider.dart';

void main() {
  group('MpcSlicerNotifier MMO Role-Stratified Kit Tests (REQ-MMO-05)', () {
    test('loadFromManifestPads hydrates 8-pad state from MasterMediaObject manifest', () {
      final notifier = MpcSlicerNotifier();

      const sampleDna = SongMetadataDna(
        id: 'dna_mmo_slicer_01',
        title: 'Stratified Groove',
        genre: 'Amapiano',
        language: 've',
        musical: MusicalDna(
          bpm: 112,
          key: 'C Major',
          energyBracket: 'mid',
          durationSec: 180,
        ),
        vocals: VocalsDna(
          deliveryMode: 'melodic',
          gender: 'male',
          energy: 'mid',
        ),
        visualTheme: VisualThemeDna(
          mood: 'Township Sunset',
          comfyPrompt: 'Stratified groove visual',
          seed: 12345,
          aspectRatio: '9:16',
        ),
      );

      final mmo = MasterMediaObject.fromSongMetadataDna(
        sampleDna,
        stemUrls: {
          StemType.vocals: 'https://r2.vhunambi.com/audio/vox.mp3',
          StemType.drums: 'https://r2.vhunambi.com/audio/drums.mp3',
          StemType.bass: 'https://r2.vhunambi.com/audio/bass.mp3',
          StemType.melody: 'https://r2.vhunambi.com/audio/melody.mp3',
        },
      );

      notifier.loadFromManifestPads(
        mmo.mpcKitPads,
        sourceTitle: mmo.dna.title,
        bpm: mmo.dna.musical.bpm,
        stemUrls: mmo.stemUrls,
      );

      final state = notifier.state;

      expect(state.pads.length, equals(8));
      expect(state.sourceTitle, equals('Stratified Groove'));
      expect(state.bpm, equals(112));
      expect(state.selectedPadIndex, equals(0));

      // Check Drum pads
      expect(state.pads[0].label, equals('Kick Downbeat'));
      expect(state.pads[0].sourceAudioUrl, equals('https://r2.vhunambi.com/audio/drums.mp3'));
      expect(state.pads[1].label, equals('Syncopated Clap'));
      expect(state.pads[1].sourceAudioUrl, equals('https://r2.vhunambi.com/audio/drums.mp3'));

      // Check Bass pads
      expect(state.pads[2].label, equals('Log Drum Drop'));
      expect(state.pads[2].sourceAudioUrl, equals('https://r2.vhunambi.com/audio/bass.mp3'));
      expect(state.pads[3].label, equals('Sub-Bass Glide'));
      expect(state.pads[3].sourceAudioUrl, equals('https://r2.vhunambi.com/audio/bass.mp3'));
      expect(state.pads[3].pitchShiftSemitones, equals(-2));

      // Check Melodic pads
      expect(state.pads[4].label, equals('Guitar Turnaround'));
      expect(state.pads[4].sourceAudioUrl, equals('https://r2.vhunambi.com/audio/melody.mp3'));
      expect(state.pads[5].label, equals('Harmonic Stab'));
      expect(state.pads[5].sourceAudioUrl, equals('https://r2.vhunambi.com/audio/melody.mp3'));

      // Check Vocal pads
      expect(state.pads[6].label, equals('Vocal Chant Hook'));
      expect(state.pads[6].sourceAudioUrl, equals('https://r2.vhunambi.com/audio/vox.mp3'));
      expect(state.pads[7].label, equals('Bantu Idiom Ad-Lib'));
      expect(state.pads[7].sourceAudioUrl, equals('https://r2.vhunambi.com/audio/vox.mp3'));

      // Check pad triggering and pitch shifting
      notifier.triggerPad(2);
      expect(notifier.state.pads[2].isTriggered, isTrue);
      expect(notifier.state.selectedPadIndex, equals(2));

      notifier.releasePad(2);
      expect(notifier.state.pads[2].isTriggered, isFalse);

      notifier.setPitchShift(3, 5);
      expect(notifier.state.pads[3].pitchShiftSemitones, equals(5));
    });
  });
}
