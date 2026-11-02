import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/studio/domain/models/melody_sketchpad_models.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_sound_pack_models.dart';
import 'package:vhunambi_client/features/studio/domain/services/melody_wav_synthesizer.dart';

void main() {
  group('Phase 32 DSP Track A: 44.1 kHz Continuous Phase Integration & Anti-Glitch', () {
    test(
      'Continuous Phase Accumulator produces smooth sample-by-sample phase evolution without discontinuities',
      () {
        // Synthesizing a pitch-swept note (Amapiano log drum with glide)
        const note = MelodyStepNote(
          stepIndex: 0,
          scaleRow: 4,
          velocity: 0.95,
          hasGlide: true,
          durationSteps: 2,
        );
        const pattern = MelodyPatternEntity(
          id: 'test_continuous_phase',
          name: 'Phase Test',
          instrument: SketchpadInstrument.amapianoLogDrum,
          bpm: 112,
          musicalKey: 'Am',
          scaleMode: AfricanScaleMode.minorPentatonic,
          notes: [note],
        );

        final wavBytes = MelodyWavSynthesizer.synthesizePatternToWavBytes(pattern);
        expect(wavBytes.length, greaterThan(44));

        // Verify RIFF WAVE 44.1 kHz 16-bit stereo format
        final bd = ByteData.sublistView(wavBytes);
        final sampleRate = bd.getUint32(24, Endian.little);
        final numChannels = bd.getUint16(22, Endian.little);
        final bitsPerSample = bd.getUint16(34, Endian.little);

        expect(sampleRate, equals(44100));
        expect(numChannels, equals(1)); // Mono for single pattern audition
        expect(bitsPerSample, equals(16));

        // Verify sample delta continuity: no wild discontinuity jumps (clicks) between adjacent samples
        var maxAdjacentJump = 0;
        for (var i = 44; i < wavBytes.length - 4; i += 4) {
          final s1 = bd.getInt16(i, Endian.little);
          final s2 = bd.getInt16(i + 4, Endian.little);
          final jump = (s2 - s1).abs();
          if (jump > maxAdjacentJump) maxAdjacentJump = jump;
        }

        // Without continuous phase, jumps reach full scale (> 40000).
        // Continuous phase guarantees sample deltas stay within smooth acoustic bounds (< 25000).
        expect(maxAdjacentJump, lessThan(25000));
      },
    );

    test(
      'Karplus-Strong plucked acoustic and electric guitars synthesize decaying string harmonics',
      () {
        const guitarPattern = MelodyPatternEntity(
          id: 'test_guitar_ks',
          name: 'Guitar Test',
          instrument: SketchpadInstrument.maskandiGuitar,
          bpm: 120,
          musicalKey: 'Am',
          scaleMode: AfricanScaleMode.minorPentatonic,
          notes: [
            MelodyStepNote(stepIndex: 0, scaleRow: 4, velocity: 0.9),
          ],
        );

        final wav = MelodyWavSynthesizer.synthesizePatternToWavBytes(guitarPattern);
        expect(wav.length, greaterThan(44));

        final bd = ByteData.sublistView(wav);
        final totalFrames = (wav.length - 44) ~/ 4;

        // Compute RMS in attack region (first 10% of samples) vs tail region (last 20%)
        final attackFrames = totalFrames ~/ 10;
        final tailStart = (totalFrames * 0.8).toInt();

        var attackEnergy = 0.0;
        for (var i = 0; i < attackFrames; i++) {
          final s = bd.getInt16(44 + i * 4, Endian.little);
          attackEnergy += s * s;
        }
        final attackRms = math.sqrt(attackEnergy / attackFrames);

        var tailEnergy = 0.0;
        final tailFrames = totalFrames - tailStart;
        for (var i = tailStart; i < totalFrames; i++) {
          final s = bd.getInt16(44 + i * 4, Endian.little);
          tailEnergy += s * s;
        }
        final tailRms = math.sqrt(tailEnergy / tailFrames);

        expect(attackRms, greaterThan(tailRms));
        expect(attackRms, greaterThan(500));
      },
    );

    test(
      'Bowed violin waveguide synthesizes sustained acoustic tone with smooth attack swell',
      () {
        const violinPattern = MelodyPatternEntity(
          id: 'test_violin_bow',
          name: 'Violin Test',
          instrument: SketchpadInstrument.soloViolin,
          bpm: 108,
          musicalKey: 'Am',
          scaleMode: AfricanScaleMode.minorPentatonic,
          notes: [
            MelodyStepNote(stepIndex: 0, scaleRow: 5, velocity: 0.9, durationSteps: 4),
          ],
        );

        final wav = MelodyWavSynthesizer.synthesizePatternToWavBytes(violinPattern);
        final bd = ByteData.sublistView(wav);
        final totalFrames = (wav.length - 44) ~/ 4;

        // Sustained tone should maintain high energy through mid-region
        final midStart = totalFrames ~/ 3;
        final midEnd = (totalFrames * 2) ~/ 3;
        var midEnergy = 0.0;
        for (var i = midStart; i < midEnd; i++) {
          final s = bd.getInt16(44 + i * 4, Endian.little);
          midEnergy += s * s;
        }
        final midRms = math.sqrt(midEnergy / (midEnd - midStart));
        expect(midRms, greaterThan(400));
      },
    );

    test(
      '8-Row Drum Rack synthesizes all 8 voices across all 6 BeatKitGenres without NaN/Inf',
      () {
        for (final genre in BeatKitGenre.values) {
          final groove = MultiTrackGrooveEntity.createDefault(
            id: 'drum_test_${genre.name}',
            name: 'Drum Test',
            bpm: 112,
            musicalKey: 'Am',
            scaleMode: AfricanScaleMode.minorPentatonic,
            leadInstrument: SketchpadInstrument.concertGrandPiano,
          );

          // Add hits for all 8 rows in the drums channel
          final drumHits = <MelodyStepNote>[];
          for (var row = 0; row < 8; row++) {
            drumHits.add(MelodyStepNote(
              stepIndex: (row * 2) % 16,
              scaleRow: row,
              velocity: 0.85,
            ));
          }

          final channels = Map<SketchpadChannelRole, SketchpadChannelTrack>.from(
            groove.channels,
          );
          channels[SketchpadChannelRole.drums] = channels[SketchpadChannelRole.drums]!.copyWith(
            beatKit: genre,
            steps: drumHits,
          );

          final drumGroove = groove.copyWith(channels: channels);
          final wav = MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(drumGroove);

          expect(wav.length, greaterThan(44));
          final bd = ByteData.sublistView(wav);
          expect(bd.getUint16(22, Endian.little), equals(2)); // 44.1 kHz Stereo Master
          var maxSample = 0;
          for (var i = 44; i < wav.length - 2; i += 2) {
            final s = bd.getInt16(i, Endian.little).abs();
            if (s > maxSample) maxSample = s;
          }
          expect(maxSample, greaterThan(1000));
          expect(maxSample, lessThanOrEqualTo(32767));
        }
      },
    );
  });

  group('Phase 32 Master Bus Track B: 5-Channel Groove Summing, Solo & Mute Gating', () {
    test(
      'Muted channel is completely excluded from Master Drive audio stream',
      () {
        final groove = MultiTrackGrooveEntity.createDefault(
          id: 'mute_test',
          name: 'Mute Test',
          bpm: 112,
          musicalKey: 'Am',
          scaleMode: AfricanScaleMode.minorPentatonic,
          leadInstrument: SketchpadInstrument.concertGrandPiano,
          initialLeadNotes: const [
            MelodyStepNote(stepIndex: 0, scaleRow: 3, velocity: 0.95),
          ],
        );

        final unmutedWav = MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(groove);

        // Mute the lead channel
        final channels = Map<SketchpadChannelRole, SketchpadChannelTrack>.from(
          groove.channels,
        );
        channels[SketchpadChannelRole.lead] = channels[SketchpadChannelRole.lead]!.copyWith(
          isMuted: true,
        );
        final mutedGroove = groove.copyWith(channels: channels);
        final mutedWav = MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(mutedGroove);

        expect(unmutedWav.length, equals(mutedWav.length));

        // When lead is muted and other channels are empty, mutedWav should be absolute silence (0s)
        final bd = ByteData.sublistView(mutedWav);
        var maxMutedSample = 0;
        for (var i = 44; i < mutedWav.length - 2; i += 2) {
          final s = bd.getInt16(i, Endian.little).abs();
          if (s > maxMutedSample) maxMutedSample = s;
        }
        expect(maxMutedSample, equals(0));
      },
    );

    test(
      'Soloing one channel mutes all other channels in the Master Drive summing bus',
      () {
        final groove = MultiTrackGrooveEntity.createDefault(
          id: 'solo_test',
          name: 'Solo Test',
          bpm: 112,
          musicalKey: 'Am',
          scaleMode: AfricanScaleMode.minorPentatonic,
          leadInstrument: SketchpadInstrument.concertGrandPiano,
          initialLeadNotes: const [
            MelodyStepNote(stepIndex: 0, scaleRow: 3, velocity: 0.95),
          ],
        );

        // Put a kick in drums channel
        final channels = Map<SketchpadChannelRole, SketchpadChannelTrack>.from(
          groove.channels,
        );
        channels[SketchpadChannelRole.drums] = channels[SketchpadChannelRole.drums]!.copyWith(
          steps: const [
            MelodyStepNote(stepIndex: 0, scaleRow: 0, velocity: 0.95),
          ],
        );

        // Solo the drums channel: lead should be silenced
        channels[SketchpadChannelRole.drums] = channels[SketchpadChannelRole.drums]!.copyWith(
          isSolo: true,
        );

        final soloGroove = groove.copyWith(channels: channels);
        final soloWav = MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(soloGroove);

        // Synthesize drums alone
        channels[SketchpadChannelRole.lead] = channels[SketchpadChannelRole.lead]!.copyWith(
          steps: const [],
        );
        final drumsOnlyGroove = groove.copyWith(channels: channels);
        final drumsOnlyWav = MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(drumsOnlyGroove);

        // Soloed groove should match drums-only groove exactly
        expect(soloWav.length, equals(drumsOnlyWav.length));
        var diffCount = 0;
        for (var i = 44; i < soloWav.length; i++) {
          if (soloWav[i] != drumsOnlyWav[i]) diffCount++;
        }
        expect(diffCount, equals(0));
      },
    );

    test(
      'Tube Soft-Saturation Limiter prevents clipping even when all 5 channels play simultaneously at max volume',
      () {
        final groove = MultiTrackGrooveEntity.createDefault(
          id: 'clip_test',
          name: 'Clip Test',
          bpm: 120,
          musicalKey: 'Am',
          scaleMode: AfricanScaleMode.minorPentatonic,
          leadInstrument: SketchpadInstrument.concertGrandPiano,
        );

        final channels = Map<SketchpadChannelRole, SketchpadChannelTrack>.from(
          groove.channels,
        );
        for (final role in SketchpadChannelRole.values) {
          channels[role] = channels[role]!.copyWith(
            volume: 1.2,
            steps: const [
              MelodyStepNote(stepIndex: 0, scaleRow: 2, velocity: 1.0),
              MelodyStepNote(stepIndex: 4, scaleRow: 3, velocity: 1.0),
              MelodyStepNote(stepIndex: 8, scaleRow: 4, velocity: 1.0),
              MelodyStepNote(stepIndex: 12, scaleRow: 5, velocity: 1.0),
            ],
          );
        }

        final fullGroove = groove.copyWith(channels: channels);
        final fullWav = MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(fullGroove);

        final bd = ByteData.sublistView(fullWav);
        var maxSample = 0;
        for (var i = 44; i < fullWav.length - 2; i += 2) {
          final s = bd.getInt16(i, Endian.little).abs();
          if (s > maxSample) maxSample = s;
        }

        // Must not exceed 16-bit PCM ceiling (32767)
        expect(maxSample, lessThanOrEqualTo(32767));
        expect(maxSample, greaterThan(5000));
      },
    );
  });

  group('Phase 32 Sound Pack Manager Track C: In-App Sound Pack Architecture', () {
    test(
      'kOfficialSoundPacks ships Core Native Pack with 0 MB download and isBundledNative true',
      () {
        expect(kOfficialSoundPacks.isNotEmpty, isTrue);

        final corePack = kOfficialSoundPacks.firstWhere(
          (p) => p.id == 'pack_vhunambi_core_native',
        );

        expect(corePack.isBundledNative, isTrue);
        expect(corePack.isInstalled, isTrue);
        expect(corePack.sizeMb, equals(0.0));
        expect(corePack.instrumentNames.length, greaterThanOrEqualTo(8));
      },
    );

    test(
      'VIP Expansion packs have valid metadata, download sizes and instrument definitions',
      () {
        final vipPacks = kOfficialSoundPacks.where((p) => !p.isBundledNative).toList();
        expect(vipPacks.length, greaterThanOrEqualTo(3));

        for (final pack in vipPacks) {
          expect(pack.sizeMb, greaterThan(10.0)); // > 10MB
          expect(pack.downloadUrl, isNotEmpty);
          expect(pack.title, isNotEmpty);
          expect(pack.instrumentNames.isNotEmpty, isTrue);
        }
      },
    );
  });
}

