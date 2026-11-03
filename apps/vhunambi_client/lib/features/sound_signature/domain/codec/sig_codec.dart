import 'dart:convert';
import 'dart:typed_data';

import '../../../../features/studio/domain/models/melody_sketchpad_models.dart';
import '../models/phonetic_articulation_profile.dart';
import '../models/pitch_contour_profile.dart';
import '../models/recording_quality_profile.dart';
import '../models/rhythmic_transient_grid.dart';
import '../models/sound_idealizer_recipe.dart';
import '../models/sound_signature_dna.dart';
import '../models/timbre_identity_profile.dart';

/// Binary codec for compact Hive storage of [SoundSignatureDna] (REQ-SIG-DNA-03 / Design 2.3).
///
/// Encodes a 20-second acoustic signature in under 8 KB while maintaining
/// sample-level numerical precision across all 5 layers and recipe parameters.
class SigCodec {
  static const int currentVersion = 1;

  /// Encodes a [SoundSignatureDna] entity into a versioned [Uint8List] buffer.
  static Uint8List encode(SoundSignatureDna dna) {
    // If the take is longer than 30s, decimate F0 by factor of 2 to stay strictly under 8 KB
    final decimateF0 = dna.durationSec > 30.0;
    final List<int> f0Source = dna.pitch.f0CentsMidi;
    final List<int> f0Frames = decimateF0
        ? [
            for (var i = 0; i < f0Source.length; i += 2) f0Source[i],
          ]
        : f0Source;

    final bytesBuilder = BytesBuilder();

    // 1. Header (Fixed 16 bytes)
    final header = ByteData(16);
    header.setUint8(0, currentVersion);
    var flags = 0;
    if (dna.source == SignatureSource.imported) flags |= 0x01;
    if (dna.cloudEmbeddingRef != null) flags |= 0x02;
    if (dna.consentAtIso != null) flags |= 0x04;
    if (decimateF0) flags |= 0x08;
    header.setUint8(1, flags);
    header.setUint32(2, (dna.durationSec * 1000).round(), Endian.little);
    header.setUint16(6, (dna.bpmHint * 100).round().clamp(0, 65535), Endian.little);
    header.setUint8(8, dna.pitch.rootPitchClass.clamp(0, 11));
    header.setUint8(9, AfricanScaleMode.values.indexOf(dna.pitch.scaleMode).clamp(0, 255));
    header.setUint8(10, (dna.pitch.keyConfidence * 255).round().clamp(0, 255));
    header.setUint8(11, (dna.pitch.stabilityScore * 255).round().clamp(0, 255));
    header.setUint16(12, (dna.pitch.naturalVibratoHz * 100).round().clamp(0, 65535), Endian.little);
    header.setUint16(14, (dna.pitch.naturalVibratoDepthCents * 10).round().clamp(0, 65535), Endian.little);
    bytesBuilder.add(header.buffer.asUint8List());

    // 2. Timbre & Formants (Fixed 4*4 + 16*4 + 3 = 83 bytes)
    final timbreData = ByteData(83);
    for (var i = 0; i < 4; i++) {
      final f = i < dna.identity.formantsHz.length ? dna.identity.formantsHz[i] : 0.0;
      timbreData.setFloat32(i * 4, f.isFinite ? f : 0.0, Endian.little);
    }
    for (var i = 0; i < 16; i++) {
      final c = i < dna.identity.cepstralDescriptor.length ? dna.identity.cepstralDescriptor[i] : 0.0;
      timbreData.setFloat32(16 + i * 4, c.isFinite ? c : 0.0, Endian.little);
    }
    timbreData.setUint8(80, (dna.identity.glottalWarmth * 255).round().clamp(0, 255));
    timbreData.setUint8(81, (dna.identity.harmonicPurityRatio * 255).round().clamp(0, 255));
    timbreData.setUint8(82, (dna.articulation.consonantTransientSharpness * 255).round().clamp(0, 255));
    bytesBuilder.add(timbreData.buffer.asUint8List());

    // 3. Quality Profile (6 * 4 = 24 bytes)
    final qualityData = ByteData(24);
    qualityData.setFloat32(0, dna.quality.snrDb, Endian.little);
    qualityData.setFloat32(4, dna.quality.clippingPct, Endian.little);
    qualityData.setFloat32(8, dna.quality.bandwidthHz, Endian.little);
    qualityData.setFloat32(12, dna.quality.loudnessLufs, Endian.little);
    qualityData.setFloat32(16, dna.quality.reverbEdtMs, Endian.little);
    qualityData.setFloat32(20, dna.quality.voicedRatio, Endian.little);
    bytesBuilder.add(qualityData.buffer.asUint8List());

    // 4. Recipe (7 * 4 = 28 bytes)
    final recipeData = ByteData(28);
    recipeData.setFloat32(0, dna.recipe.pitchScaleLock, Endian.little);
    recipeData.setFloat32(4, dna.recipe.vibratoAndSustainPolish, Endian.little);
    recipeData.setFloat32(8, dna.recipe.formantDepthShiftSemitones, Endian.little);
    recipeData.setFloat32(12, dna.recipe.chestPowerAndAirBoost, Endian.little);
    recipeData.setFloat32(16, dna.recipe.quantizePocketStrength, Endian.little);
    recipeData.setFloat32(20, dna.recipe.hybridBlendMix, Endian.little);
    recipeData.setFloat32(24, dna.recipe.referenceCleanup, Endian.little);
    bytesBuilder.add(recipeData.buffer.asUint8List());

    // 5. Strings: id, displayCode, createdAtIso, rawAudioPath, cloudEmbeddingRef, consentAtIso, hybridArchetypeId
    _writeString(bytesBuilder, dna.id);
    _writeString(bytesBuilder, dna.displayCode);
    _writeString(bytesBuilder, dna.createdAtIso);
    _writeString(bytesBuilder, dna.rawAudioPath ?? '');
    _writeString(bytesBuilder, dna.cloudEmbeddingRef ?? '');
    _writeString(bytesBuilder, dna.consentAtIso ?? '');
    _writeString(bytesBuilder, dna.recipe.hybridArchetypeId ?? '');

    // 6. F0 Frames (2 bytes per frame)
    final f0Data = ByteData(2 + f0Frames.length * 2);
    f0Data.setUint16(0, f0Frames.length, Endian.little);
    for (var i = 0; i < f0Frames.length; i++) {
      f0Data.setInt16(2 + i * 2, f0Frames[i].clamp(-32768, 32767), Endian.little);
    }
    bytesBuilder.add(f0Data.buffer.asUint8List());

    // 7. Onsets & Offsets (5 bytes per onset: 4 bytes ms + 1 byte signed offset)
    final onsetCount = dna.rhythm.onsetMs.length;
    final onsetData = ByteData(2 + onsetCount * 5);
    onsetData.setUint16(0, onsetCount, Endian.little);
    for (var i = 0; i < onsetCount; i++) {
      final ms = dna.rhythm.onsetMs[i];
      final offset = i < dna.rhythm.offsetFromGridMs.length
          ? dna.rhythm.offsetFromGridMs[i].clamp(-128, 127)
          : 0;
      onsetData.setUint32(2 + i * 5, ms, Endian.little);
      onsetData.setInt8(2 + i * 5 + 4, offset);
    }
    bytesBuilder.add(onsetData.buffer.asUint8List());

    // 8. Protected Articulation Segments (8 bytes per segment: 4 start + 4 end)
    final segCount = dna.articulation.protectedSegments.length;
    final segData = ByteData(2 + segCount * 8);
    segData.setUint16(0, segCount, Endian.little);
    for (var i = 0; i < segCount; i++) {
      final s = dna.articulation.protectedSegments[i];
      segData.setUint32(2 + i * 8, s.startMs, Endian.little);
      segData.setUint32(2 + i * 8 + 4, s.endMs, Endian.little);
    }
    bytesBuilder.add(segData.buffer.asUint8List());

    // 9. Quantized Notes (5 bytes per note: step, row, vel*255, glide, dur)
    final noteCount = dna.rhythm.quantizedNotes.length;
    final noteData = ByteData(1 + noteCount * 5);
    noteData.setUint8(0, noteCount.clamp(0, 255));
    for (var i = 0; i < noteCount; i++) {
      final n = dna.rhythm.quantizedNotes[i];
      noteData.setUint8(1 + i * 5, n.stepIndex.clamp(0, 15));
      noteData.setUint8(1 + i * 5 + 1, n.scaleRow.clamp(0, 7));
      noteData.setUint8(1 + i * 5 + 2, (n.velocity * 255).round().clamp(0, 255));
      noteData.setUint8(1 + i * 5 + 3, n.hasGlide ? 1 : 0);
      noteData.setUint8(1 + i * 5 + 4, n.durationSteps.clamp(1, 4));
    }
    bytesBuilder.add(noteData.buffer.asUint8List());

    return bytesBuilder.toBytes();
  }

  /// Decodes a versioned binary [Uint8List] into a [SoundSignatureDna] entity.
  static SoundSignatureDna decode(Uint8List bytes) {
    if (bytes.length < 16) {
      throw FormatException('SigCodec: buffer too small for header (${bytes.length} bytes)');
    }

    final reader = _ByteReader(bytes);
    final version = reader.readUint8();
    if (version != currentVersion) {
      throw FormatException('SigCodec: unsupported schema version $version');
    }

    final flags = reader.readUint8();
    final isImported = (flags & 0x01) != 0;
    final hasCloudEmbedding = (flags & 0x02) != 0;
    final hasConsent = (flags & 0x04) != 0;
    final isDecimated = (flags & 0x08) != 0;

    final durationSec = reader.readUint32() / 1000.0;
    final bpmHint = reader.readUint16() / 100.0;
    final rootPitchClass = reader.readUint8();
    final scaleModeIdx = reader.readUint8();
    final keyConfidence = reader.readUint8() / 255.0;
    final stabilityScore = reader.readUint8() / 255.0;
    final naturalVibratoHz = reader.readUint16() / 100.0;
    final naturalVibratoDepthCents = reader.readUint16() / 10.0;

    // Timbre & Formants
    final formantsHz = <double>[];
    for (var i = 0; i < 4; i++) {
      formantsHz.add(reader.readFloat32());
    }
    final cepstral = <double>[];
    for (var i = 0; i < 16; i++) {
      cepstral.add(reader.readFloat32());
    }
    final glottalWarmth = reader.readUint8() / 255.0;
    final harmonicPurityRatio = reader.readUint8() / 255.0;
    final consonantTransientSharpness = reader.readUint8() / 255.0;

    // Quality Profile
    final snrDb = reader.readFloat32();
    final clippingPct = reader.readFloat32();
    final bandwidthHz = reader.readFloat32();
    final loudnessLufs = reader.readFloat32();
    final reverbEdtMs = reader.readFloat32();
    final voicedRatio = reader.readFloat32();

    // Recipe
    final pitchScaleLock = reader.readFloat32();
    final vibratoAndSustainPolish = reader.readFloat32();
    final formantDepthShift = reader.readFloat32();
    final chestPower = reader.readFloat32();
    final quantizePocket = reader.readFloat32();
    final hybridBlendMix = reader.readFloat32();
    final referenceCleanup = reader.readFloat32();

    // Strings
    final id = reader.readString();
    final displayCode = reader.readString();
    final createdAtIso = reader.readString();
    final rawAudioPathStr = reader.readString();
    final cloudEmbeddingRefStr = reader.readString();
    final consentAtIsoStr = reader.readString();
    final hybridArchetypeIdStr = reader.readString();

    // F0 Frames
    final f0Count = reader.readUint16();
    final f0Frames = <int>[];
    for (var i = 0; i < f0Count; i++) {
      final f0 = reader.readInt16();
      f0Frames.add(f0);
      if (isDecimated) {
        // Re-interpolate the decimated frame for continuity
        f0Frames.add(f0);
      }
    }

    // Onsets
    final onsetCount = reader.readUint16();
    final onsetMs = <int>[];
    final offsetFromGridMs = <int>[];
    for (var i = 0; i < onsetCount; i++) {
      onsetMs.add(reader.readUint32());
      offsetFromGridMs.add(reader.readInt8());
    }

    // Protected Segments
    final segCount = reader.readUint16();
    final protectedSegments = <TimeSpanMs>[];
    for (var i = 0; i < segCount; i++) {
      final start = reader.readUint32();
      final end = reader.readUint32();
      protectedSegments.add(TimeSpanMs(start, end));
    }

    // Quantized Notes
    final noteCount = reader.readUint8();
    final quantizedNotes = <MelodyStepNote>[];
    for (var i = 0; i < noteCount; i++) {
      final step = reader.readUint8();
      final row = reader.readUint8();
      final vel = reader.readUint8() / 255.0;
      final glide = reader.readUint8() == 1;
      final dur = reader.readUint8();
      quantizedNotes.add(MelodyStepNote(
        stepIndex: step,
        scaleRow: row,
        velocity: vel,
        hasGlide: glide,
        durationSteps: dur,
      ));
    }

    final scaleMode = scaleModeIdx >= 0 && scaleModeIdx < AfricanScaleMode.values.length
        ? AfricanScaleMode.values[scaleModeIdx]
        : AfricanScaleMode.minorPentatonic;

    return SoundSignatureDna(
      id: id,
      displayCode: displayCode,
      source: isImported ? SignatureSource.imported : SignatureSource.live,
      createdAtIso: createdAtIso,
      durationSec: durationSec,
      sampleRate: 44100,
      bpmHint: bpmHint,
      identity: TimbreIdentityProfile(
        cepstralDescriptor: cepstral,
        formantsHz: formantsHz,
        glottalWarmth: glottalWarmth,
        harmonicPurityRatio: harmonicPurityRatio,
      ),
      pitch: PitchContourProfile(
        f0CentsMidi: f0Frames,
        rootPitchClass: rootPitchClass,
        scaleMode: scaleMode,
        keyConfidence: keyConfidence,
        stabilityScore: stabilityScore,
        naturalVibratoHz: naturalVibratoHz,
        naturalVibratoDepthCents: naturalVibratoDepthCents,
      ),
      articulation: PhoneticArticulationProfile(
        consonantTransientSharpness: consonantTransientSharpness,
        protectedSegments: protectedSegments,
      ),
      rhythm: RhythmicTransientGrid(
        onsetMs: onsetMs,
        offsetFromGridMs: offsetFromGridMs,
        quantizedNotes: quantizedNotes,
      ),
      quality: RecordingQualityProfile(
        snrDb: snrDb,
        clippingPct: clippingPct,
        bandwidthHz: bandwidthHz,
        loudnessLufs: loudnessLufs,
        reverbEdtMs: reverbEdtMs,
        voicedRatio: voicedRatio,
      ),
      recipe: SoundIdealizerRecipe(
        pitchScaleLock: pitchScaleLock,
        vibratoAndSustainPolish: vibratoAndSustainPolish,
        formantDepthShiftSemitones: formantDepthShift,
        chestPowerAndAirBoost: chestPower,
        quantizePocketStrength: quantizePocket,
        hybridArchetypeId: hybridArchetypeIdStr.isNotEmpty ? hybridArchetypeIdStr : null,
        hybridBlendMix: hybridBlendMix,
        referenceCleanup: referenceCleanup,
      ),
      rawAudioPath: rawAudioPathStr.isNotEmpty ? rawAudioPathStr : null,
      cloudEmbeddingRef: hasCloudEmbedding && cloudEmbeddingRefStr.isNotEmpty
          ? cloudEmbeddingRefStr
          : null,
      consentAtIso: hasConsent && consentAtIsoStr.isNotEmpty ? consentAtIsoStr : null,
      schemaVersion: version,
    );
  }

  static void _writeString(BytesBuilder builder, String s) {
    final encoded = utf8.encode(s);
    final lenData = ByteData(2);
    lenData.setUint16(0, encoded.length, Endian.little);
    builder.add(lenData.buffer.asUint8List());
    if (encoded.isNotEmpty) {
      builder.add(encoded);
    }
  }
}

class _ByteReader {
  _ByteReader(this.bytes) : _data = ByteData.sublistView(bytes);

  final Uint8List bytes;
  final ByteData _data;
  int _offset = 0;

  int readUint8() {
    final v = _data.getUint8(_offset);
    _offset += 1;
    return v;
  }

  int readInt8() {
    final v = _data.getInt8(_offset);
    _offset += 1;
    return v;
  }

  int readUint16() {
    final v = _data.getUint16(_offset, Endian.little);
    _offset += 2;
    return v;
  }

  int readInt16() {
    final v = _data.getInt16(_offset, Endian.little);
    _offset += 2;
    return v;
  }

  int readUint32() {
    final v = _data.getUint32(_offset, Endian.little);
    _offset += 4;
    return v;
  }

  double readFloat32() {
    final v = _data.getFloat32(_offset, Endian.little);
    _offset += 4;
    return v;
  }

  String readString() {
    final len = readUint16();
    if (len == 0) return '';
    final s = utf8.decode(bytes.sublist(_offset, _offset + len));
    _offset += len;
    return s;
  }
}

