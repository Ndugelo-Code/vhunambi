import 'dart:math' as math;
import 'dart:typed_data';

import '../models/melody_sketchpad_models.dart';
import '../models/vocal_identity_models.dart';

/// Deterministic, dependency-free 44.1 kHz 16-bit PCM RIFF/WAVE synthesizer
/// for the Vhunambi Studio Melody & Beat Sketchpad and Regional Voice Previewer.
///
/// Phase 57 Overhaul:
/// 1. Bounded Padé [3/2] tanh soft-knee master limiter + Int16 clamp (zero wrap-around bleeps).
/// 2. Kick-triggered Bass sidechain envelope ducking (-4.5 dB, 4 ms attack, 55 ms release).
/// 3. Analytical phase-integrated pitch envelopes (zero phase-inversion FM chirps).
/// 4. Dedicated 8-Row High-Frequency Percussion Matrix (`synthesizeHatPercVoice`) for
///    `SketchpadChannelRole.hats` with Open-to-Closed Hat Choke Group.
/// 5. Role-aware octave anchoring, Mono-Legato Bass sustain + 195 Hz 2-pole Butterworth LPF,
///    Multi-Step Cantabile Lead sustain + 3.8 kHz LPF, and automatic diatonic Chord stacks.
class MelodyWavSynthesizer {
  const MelodyWavSynthesizer._();

  static const int kSampleRate = 44100;
  static const int kMasterSampleRate = kSampleRate;

  /// Per-channel pre-summing headroom gain weights (Phase 57 REQ-P57-DSP-01).
  static double resolveRoleHeadroomGain(SketchpadChannelRole role) {
    switch (role) {
      case SketchpadChannelRole.bass:
        return 0.52;
      case SketchpadChannelRole.drums:
        return 0.55;
      case SketchpadChannelRole.chords:
        return 0.42;
      case SketchpadChannelRole.lead:
        return 0.48;
      case SketchpadChannelRole.hats:
        return 0.38;
    }
  }

  /// Bounded Padé [3/2] rational approximant to tanh(x) with hard saturation outside [-3, 3].
  /// Guaranteed strictly within [-1.0, 1.0] for all real inputs (REQ-P57-DSP-01).
  static double padeTanhLimiter(double x) {
    if (x.isNaN) return 0.0;
    if (x <= -3.0) return -1.0;
    if (x >= 3.0) return 1.0;
    final x2 = x * x;
    return (x * (27.0 + x2)) / (27.0 + 9.0 * x2);
  }

  /// Synthesizes a 5-channel [MultiTrackGrooveEntity] into a stereo 16-bit PCM
  /// RIFF/WAVE byte buffer with per-channel pan, multi-step overlap-add sustain,
  /// Kick-triggered Bass sidechain ducking, 2-pole Butterworth filtering,
  /// and Padé [3/2] master soft-knee limiting.
  static Uint8List synthesizeMasterGrooveToWavBytes(
    MultiTrackGrooveEntity groove, {
    int sampleRate = kSampleRate,
  }) {
    final safeBpm = groove.bpm.clamp(60, 200);
    final stepDurationSec = 60.0 / (safeBpm * 4.0);
    final totalDurationSec = stepDurationSec * 16.0;
    final totalSamples = (totalDurationSec * sampleRate).round();

    final leftBuffer = Float64List(totalSamples);
    final rightBuffer = Float64List(totalSamples);

    final activeChannels = groove.effectiveAudibleChannels;
    if (activeChannels.isEmpty) {
      return _encodePcm16WavStereo(leftBuffer, rightBuffer, sampleRate);
    }

    // Collect Kick onset samples from the drums channel for Bass sidechain ducking (REQ-P57-DSP-02)
    final kickOnsetSamples = <int>[];
    final drumsChannel = activeChannels
        .where((c) => c.role == SketchpadChannelRole.drums)
        .firstOrNull;
    if (drumsChannel != null) {
      for (final note in drumsChannel.steps) {
        if (note.scaleRow == 0 || note.scaleRow == 1) {
          final onsetSample = _computeGrooveNoteStartSample(
            stepIndex: note.stepIndex,
            isPercussion: true,
            scaleRow: note.scaleRow,
            stepDurationSec: stepDurationSec,
            swingAmount: groove.swingAmount,
            sampleRate: sampleRate,
          );
          kickOnsetSamples.add(onsetSample);
        }
      }
    }

    for (final channel in activeChannels) {
      final chanLeft = Float64List(totalSamples);
      final chanRight = Float64List(totalSamples);

      final panAngle =
          (channel.pan.clamp(-1.0, 1.0) + 1.0) * (math.pi / 4.0);
      final panLeft = math.cos(panAngle);
      final panRight = math.sin(panAngle);
      final channelGain =
          channel.volume.clamp(0.0, 1.2) * resolveRoleHeadroomGain(channel.role);

      switch (channel.role) {
        case SketchpadChannelRole.drums:
          _renderDrumsChannel(
            channel: channel,
            groove: groove,
            stepDurationSec: stepDurationSec,
            sampleRate: sampleRate,
            totalSamples: totalSamples,
            channelGain: channelGain,
            panLeft: panLeft,
            panRight: panRight,
            outLeft: chanLeft,
            outRight: chanRight,
          );
        case SketchpadChannelRole.hats:
          _renderHatsPercChannel(
            channel: channel,
            groove: groove,
            stepDurationSec: stepDurationSec,
            sampleRate: sampleRate,
            totalSamples: totalSamples,
            channelGain: channelGain,
            panLeft: panLeft,
            panRight: panRight,
            outLeft: chanLeft,
            outRight: chanRight,
          );
        case SketchpadChannelRole.bass:
          _renderBassMonoLegatoChannel(
            channel: channel,
            groove: groove,
            stepDurationSec: stepDurationSec,
            sampleRate: sampleRate,
            totalSamples: totalSamples,
            channelGain: channelGain,
            panLeft: panLeft,
            panRight: panRight,
            kickOnsetSamples: kickOnsetSamples,
            outLeft: chanLeft,
            outRight: chanRight,
          );
        case SketchpadChannelRole.chords:
          _renderChordsPolyphonicChannel(
            channel: channel,
            groove: groove,
            stepDurationSec: stepDurationSec,
            sampleRate: sampleRate,
            totalSamples: totalSamples,
            channelGain: channelGain,
            panLeft: panLeft,
            panRight: panRight,
            outLeft: chanLeft,
            outRight: chanRight,
          );
        case SketchpadChannelRole.lead:
          _renderLeadCantabileChannel(
            channel: channel,
            groove: groove,
            stepDurationSec: stepDurationSec,
            sampleRate: sampleRate,
            totalSamples: totalSamples,
            channelGain: channelGain,
            panLeft: panLeft,
            panRight: panRight,
            outLeft: chanLeft,
            outRight: chanRight,
          );
      }

      for (var i = 0; i < totalSamples; i++) {
        leftBuffer[i] += chanLeft[i];
        rightBuffer[i] += chanRight[i];
      }
    }

    return _encodePcm16WavStereo(
      leftBuffer,
      rightBuffer,
      sampleRate,
      drive: groove.masterDrive,
    );
  }

  static int _computeGrooveNoteStartSample({
    required int stepIndex,
    required bool isPercussion,
    required int scaleRow,
    required double stepDurationSec,
    required double swingAmount,
    required int sampleRate,
  }) {
    final isOffbeatStep = stepIndex.isOdd;
    final swingShiftSec = isOffbeatStep
        ? (swingAmount - 0.5).clamp(0.0, 0.25) * stepDurationSec * 0.65
        : 0.0;
    final microDelaySec =
        (isPercussion && scaleRow >= 5 && isOffbeatStep) ? 0.006 : 0.0;
    final startSec =
        (stepIndex * stepDurationSec) + swingShiftSec + microDelaySec;
    return (startSec * sampleRate).round().clamp(0, sampleRate * 60);
  }

  // ---------------------------------------------------------------------------
  // Channel 1: Drums Rack Renderer (8-Row Studio & African Drum Kit)
  // ---------------------------------------------------------------------------
  static void _renderDrumsChannel({
    required SketchpadChannelState channel,
    required MultiTrackGrooveEntity groove,
    required double stepDurationSec,
    required int sampleRate,
    required int totalSamples,
    required double channelGain,
    required double panLeft,
    required double panRight,
    required Float64List outLeft,
    required Float64List outRight,
  }) {
    final hitRenderWindowSec = math.max(stepDurationSec * 2.6, 0.34);
    final hitSampleCount = (hitRenderWindowSec * sampleRate).round();

    for (final note in channel.steps) {
      final startSample = _computeGrooveNoteStartSample(
        stepIndex: note.stepIndex,
        isPercussion: true,
        scaleRow: note.scaleRow,
        stepDurationSec: stepDurationSec,
        swingAmount: groove.swingAmount,
        sampleRate: sampleRate,
      );
      final noteGain = note.velocity.clamp(0.05, 1.0) * channelGain;

      for (var i = 0; i < hitSampleCount; i++) {
        final targetIdx = startSample + i;
        if (targetIdx >= totalSamples) break;
        final localSec = i / sampleRate;
        final raw = synthesizeDrumRackVoice(
          kit: channel.beatKit,
          row: note.scaleRow,
          t: localSec,
        );
        final sample = raw * noteGain;
        outLeft[targetIdx] += sample * panLeft;
        outRight[targetIdx] += sample * panRight;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Channel 2: Dedicated Hi-Hats & Percs Renderer with Open->Closed Choke Group
  // ---------------------------------------------------------------------------
  static void _renderHatsPercChannel({
    required SketchpadChannelState channel,
    required MultiTrackGrooveEntity groove,
    required double stepDurationSec,
    required int sampleRate,
    required int totalSamples,
    required double channelGain,
    required double panLeft,
    required double panRight,
    required Float64List outLeft,
    required Float64List outRight,
  }) {
    // Identify all Closed Hat (Row 5) and 32nd Sgija Roll (Row 4) onset samples
    // so Open Shimmer Hat (Row 6) is acoustically choked when a closed hat hits (REQ-P57-HATS-02).
    final closedChokeOnsets = <int>[];
    for (final note in channel.steps) {
      if (note.scaleRow == 5 || note.scaleRow == 4) {
        closedChokeOnsets.add(
          _computeGrooveNoteStartSample(
            stepIndex: note.stepIndex,
            isPercussion: true,
            scaleRow: note.scaleRow,
            stepDurationSec: stepDurationSec,
            swingAmount: groove.swingAmount,
            sampleRate: sampleRate,
          ),
        );
      }
    }
    closedChokeOnsets.sort();

    for (final note in channel.steps) {
      final startSample = _computeGrooveNoteStartSample(
        stepIndex: note.stepIndex,
        isPercussion: true,
        scaleRow: note.scaleRow,
        stepDurationSec: stepDurationSec,
        swingAmount: groove.swingAmount,
        sampleRate: sampleRate,
      );

      final maxVoiceSec = note.scaleRow == 7
          ? 0.45
          : (note.scaleRow == 6 ? 0.32 : math.max(stepDurationSec * 1.35, 0.16));
      final hitSampleCount = (maxVoiceSec * sampleRate).round();

      // Determine choke sample for Open Hat (Row 6)
      int? chokeAtSample;
      if (note.scaleRow == 6) {
        for (final closedSample in closedChokeOnsets) {
          if (closedSample > startSample) {
            chokeAtSample = closedSample;
            break;
          }
        }
      }

      final noteGain = note.velocity.clamp(0.05, 1.0) * channelGain;
      // Subtle per-row stereo spread for natural percussion imaging
      final rowPanOffset = ((note.scaleRow - 3.5) * 0.04).clamp(-0.18, 0.18);
      final effLeft = (panLeft - rowPanOffset).clamp(0.15, 1.0);
      final effRight = (panRight + rowPanOffset).clamp(0.15, 1.0);

      for (var i = 0; i < hitSampleCount; i++) {
        final targetIdx = startSample + i;
        if (targetIdx >= totalSamples) break;

        double chokeGain = 1.0;
        if (chokeAtSample != null && targetIdx >= chokeAtSample) {
          final chokeElapsedSec = (targetIdx - chokeAtSample) / sampleRate;
          if (chokeElapsedSec >= 0.008) break; // Completely choked after 8 ms
          chokeGain = 0.5 * (1.0 + math.cos(math.pi * (chokeElapsedSec / 0.008)));
        }

        final localSec = i / sampleRate;
        final raw = synthesizeHatPercVoice(
          kit: channel.beatKit,
          row: note.scaleRow,
          t: localSec,
          stepDurationSec: stepDurationSec,
        );
        final sample = raw * noteGain * chokeGain;
        outLeft[targetIdx] += sample * effLeft;
        outRight[targetIdx] += sample * effRight;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Channel 3: Mono-Legato Sub-Bass Renderer + 195 Hz LPF + Kick Sidechain Duck
  // ---------------------------------------------------------------------------
  static void _renderBassMonoLegatoChannel({
    required SketchpadChannelState channel,
    required MultiTrackGrooveEntity groove,
    required double stepDurationSec,
    required int sampleRate,
    required int totalSamples,
    required double channelGain,
    required double panLeft,
    required double panRight,
    required List<int> kickOnsetSamples,
    required Float64List outLeft,
    required Float64List outRight,
  }) {
    // Mono-legato voice allocation: at most 1 note per step (lowest scaleRow wins)
    final stepNotes = <int, MelodyStepNote>{};
    for (final note in channel.steps) {
      final step = note.stepIndex.clamp(0, 15);
      final existing = stepNotes[step];
      if (existing == null || note.scaleRow < existing.scaleRow) {
        stepNotes[step] = note;
      }
    }
    if (stepNotes.isEmpty) return;

    final sortedSteps = stepNotes.keys.toList()..sort();
    final monoBuffer = Float64List(totalSamples);

    // If user selected a high-register instrument on the bass tab, render with warm sub-bass physics
    final effectiveBassInstrument = channel.instrument.isSubBass
        ? channel.instrument
        : SketchpadInstrument.amapianoLogDrum;

    for (var idx = 0; idx < sortedSteps.length; idx++) {
      final step = sortedSteps[idx];
      final note = stepNotes[step]!;
      final nextOccupiedStep =
          idx + 1 < sortedSteps.length ? sortedSteps[idx + 1] : 16;

      // Sustain across empty steps up to 4 steps (REQ-P57-DSP-05)
      final holdSteps = (nextOccupiedStep - step).clamp(1, 4);
      final gateDurationSec = holdSteps * stepDurationSec;
      final totalNoteSec = gateDurationSec + 0.035; // 35 ms smooth release tail

      final startSample = _computeGrooveNoteStartSample(
        stepIndex: step,
        isPercussion: false,
        scaleRow: note.scaleRow,
        stepDurationSec: stepDurationSec,
        swingAmount: groove.swingAmount,
        sampleRate: sampleRate,
      );
      final noteSamples = (totalNoteSec * sampleRate).round();

      final targetFreqHz = resolveScaleFrequencyHz(
        groove.musicalKey,
        groove.scaleMode,
        note.scaleRow,
        instrument: effectiveBassInstrument,
        role: SketchpadChannelRole.bass,
      );
      final startFreqHz =
          note.hasGlide ? (targetFreqHz * 0.7937) : targetFreqHz;
      final noteGain = note.velocity.clamp(0.05, 1.0) * channelGain;

      for (var i = 0; i < noteSamples; i++) {
        final targetIdx = startSample + i;
        if (targetIdx >= totalSamples) break;
        final localSec = i / sampleRate;

        final instantFreq = _computeInstantFrequency(
          localSec: localSec,
          stepDurationSec: gateDurationSec,
          startFreqHz: startFreqHz,
          targetFreqHz: targetFreqHz,
          hasGlide: note.hasGlide,
        );

        final env = _computeLegatoEnvelope(
          localSec: localSec,
          gateDurationSec: gateDurationSec,
          totalNoteSec: totalNoteSec,
          attackSec: 0.006,
          sustainDecayTau: 0.42,
        );

        final raw = _synthesizeVoiceSample(
          instrument: effectiveBassInstrument,
          freq: instantFreq,
          t: localSec,
        );

        // 8 ms cosine retrigger crossfade if overlapping previous bass tail
        double crossfadeWeight = 1.0;
        if (localSec < 0.008 && monoBuffer[targetIdx].abs() > 1e-6) {
          crossfadeWeight =
              0.5 * (1.0 - math.cos(math.pi * (localSec / 0.008)));
          monoBuffer[targetIdx] *= (1.0 - crossfadeWeight);
        }

        monoBuffer[targetIdx] += raw * env * noteGain * crossfadeWeight;
      }
    }

    // Apply 2-pole Butterworth Low-Pass Filter at fc = 195 Hz (REQ-P57-DSP-05)
    _applyButterworthLowPassInPlace(
      monoBuffer,
      cutoffHz: 195.0,
      sampleRate: sampleRate,
    );

    // Apply Kick-triggered Sidechain Envelope Ducking (-4.5 dB, 4 ms attack, 55 ms release)
    for (var n = 0; n < totalSamples; n++) {
      var duckAtten = 0.0;
      for (final kickSample in kickOnsetSamples) {
        final dt = (n - kickSample) / sampleRate;
        if (dt >= 0.0 && dt < 0.25) {
          final env = dt < 0.004
              ? (dt / 0.004)
              : math.exp(-(dt - 0.004) / 0.055);
          if (env > duckAtten) duckAtten = env;
        }
      }
      final sidechainGain = (1.0 - 0.41 * duckAtten).clamp(0.59, 1.0);
      final sample = monoBuffer[n] * sidechainGain;
      outLeft[n] += sample * panLeft;
      outRight[n] += sample * panRight;
    }
  }

  // ---------------------------------------------------------------------------
  // Channel 4: Polyphonic Chords & Pads Renderer + Diatonic Voicing + Chorus
  // ---------------------------------------------------------------------------
  static void _renderChordsPolyphonicChannel({
    required SketchpadChannelState channel,
    required MultiTrackGrooveEntity groove,
    required double stepDurationSec,
    required int sampleRate,
    required int totalSamples,
    required double channelGain,
    required double panLeft,
    required double panRight,
    required Float64List outLeft,
    required Float64List outRight,
  }) {
    // Group notes by stepIndex so single root notes automatically expand into warm diatonic triads
    final notesByStep = <int, List<MelodyStepNote>>{};
    for (final note in channel.steps) {
      final s = note.stepIndex.clamp(0, 15);
      notesByStep.putIfAbsent(s, () => []).add(note);
    }
    if (notesByStep.isEmpty) return;

    final sortedSteps = notesByStep.keys.toList()..sort();

    for (var idx = 0; idx < sortedSteps.length; idx++) {
      final step = sortedSteps[idx];
      final stepChordNotes = notesByStep[step]!;
      final nextStep =
          idx + 1 < sortedSteps.length ? sortedSteps[idx + 1] : 16;

      // Sustain chords across empty steps up to 4 steps (REQ-P57-DSP-06)
      final holdSteps = (nextStep - step).clamp(1, 4);
      final gateDurationSec = holdSteps * stepDurationSec;
      final totalNoteSec = gateDurationSec + 0.14;
      final noteSamples = (totalNoteSec * sampleRate).round();

      final startSample = _computeGrooveNoteStartSample(
        stepIndex: step,
        isPercussion: false,
        scaleRow: stepChordNotes.first.scaleRow,
        stepDurationSec: stepDurationSec,
        swingAmount: groove.swingAmount,
        sampleRate: sampleRate,
      );

      // If user placed a single root pad on the chords channel, voice it as a warm diatonic triad
      final expandedRowsAndWeights = <(int row, double vel, bool glide)>[];
      if (stepChordNotes.length == 1) {
        final root = stepChordNotes.first;
        expandedRowsAndWeights.add((root.scaleRow, root.velocity, root.hasGlide));
        expandedRowsAndWeights.add((
          (root.scaleRow + 2).clamp(0, 7),
          root.velocity * 0.72,
          root.hasGlide,
        ));
        expandedRowsAndWeights.add((
          (root.scaleRow + 4).clamp(0, 7),
          root.velocity * 0.68,
          root.hasGlide,
        ));
      } else {
        final polyNorm = 1.0 / math.sqrt(stepChordNotes.length);
        for (final n in stepChordNotes) {
          expandedRowsAndWeights.add((
            n.scaleRow,
            n.velocity * polyNorm,
            n.hasGlide,
          ));
        }
      }

      for (final (row, vel, hasGlide) in expandedRowsAndWeights) {
        final targetFreqHz = resolveScaleFrequencyHz(
          groove.musicalKey,
          groove.scaleMode,
          row,
          instrument: channel.instrument,
          role: SketchpadChannelRole.chords,
        );
        final startFreqHz = hasGlide ? (targetFreqHz * 0.9438) : targetFreqHz;
        final voiceGain = vel.clamp(0.05, 1.0) * channelGain * 0.62;

        // Stereo chorus detuning (+/- 6 cents = 2^(+/-6/1200) ~= 1.00347 / 0.99654)
        for (var i = 0; i < noteSamples; i++) {
          final targetIdx = startSample + i;
          if (targetIdx >= totalSamples) break;
          final localSec = i / sampleRate;

          final instantFreq = _computeInstantFrequency(
            localSec: localSec,
            stepDurationSec: gateDurationSec,
            startFreqHz: startFreqHz,
            targetFreqHz: targetFreqHz,
            hasGlide: hasGlide,
          );
          final env = _computeLegatoEnvelope(
            localSec: localSec,
            gateDurationSec: gateDurationSec,
            totalNoteSec: totalNoteSec,
            attackSec: 0.016,
            sustainDecayTau: 0.65,
          );

          final sampleL = _synthesizeVoiceSample(
            instrument: channel.instrument,
            freq: instantFreq * 0.9965,
            t: localSec,
          );
          final sampleR = _synthesizeVoiceSample(
            instrument: channel.instrument,
            freq: instantFreq * 1.0035,
            t: localSec,
          );

          outLeft[targetIdx] += sampleL * env * voiceGain * panLeft;
          outRight[targetIdx] += sampleR * env * voiceGain * panRight;
        }
      }
    }

    // Warm 2,800 Hz LPF polish on Chords channel
    _applyButterworthLowPassInPlace(
      outLeft,
      cutoffHz: 2800.0,
      sampleRate: sampleRate,
    );
    _applyButterworthLowPassInPlace(
      outRight,
      cutoffHz: 2800.0,
      sampleRate: sampleRate,
    );
  }

  // ---------------------------------------------------------------------------
  // Channel 5: Cantabile Lead Melody Renderer + Multi-Step Sustain + 3.8 kHz LPF
  // ---------------------------------------------------------------------------
  static void _renderLeadCantabileChannel({
    required SketchpadChannelState channel,
    required MultiTrackGrooveEntity groove,
    required double stepDurationSec,
    required int sampleRate,
    required int totalSamples,
    required double channelGain,
    required double panLeft,
    required double panRight,
    required Float64List outLeft,
    required Float64List outRight,
  }) {
    if (channel.steps.isEmpty) return;
    final sortedNotes = List<MelodyStepNote>.from(channel.steps)
      ..sort((a, b) => a.stepIndex.compareTo(b.stepIndex));

    for (var idx = 0; idx < sortedNotes.length; idx++) {
      final note = sortedNotes[idx];
      // Find next step onset on lead channel to determine phrase sustain
      var nextStep = 16;
      for (var j = idx + 1; j < sortedNotes.length; j++) {
        if (sortedNotes[j].stepIndex > note.stepIndex) {
          nextStep = sortedNotes[j].stepIndex;
          break;
        }
      }

      // Sustain lead notes across empty steps (min 2.2 steps, up to 3.5 steps) + 180 ms release tail
      final emptyStepSpan = (nextStep - note.stepIndex).clamp(1, 3);
      final holdMultiplier = math.max(2.2, emptyStepSpan.toDouble());
      final gateDurationSec = holdMultiplier * stepDurationSec;
      final totalNoteSec = gateDurationSec + 0.18;
      final noteSamples = (totalNoteSec * sampleRate).round();

      final startSample = _computeGrooveNoteStartSample(
        stepIndex: note.stepIndex,
        isPercussion: false,
        scaleRow: note.scaleRow,
        stepDurationSec: stepDurationSec,
        swingAmount: groove.swingAmount,
        sampleRate: sampleRate,
      );

      final targetFreqHz = resolveScaleFrequencyHz(
        groove.musicalKey,
        groove.scaleMode,
        note.scaleRow,
        instrument: channel.instrument,
        role: SketchpadChannelRole.lead,
      );
      final startFreqHz =
          note.hasGlide ? (targetFreqHz * 0.8909) : targetFreqHz;
      final noteGain = note.velocity.clamp(0.05, 1.0) * channelGain;

      for (var i = 0; i < noteSamples; i++) {
        final targetIdx = startSample + i;
        if (targetIdx >= totalSamples) break;
        final localSec = i / sampleRate;

        final baseFreq = _computeInstantFrequency(
          localSec: localSec,
          stepDurationSec: gateDurationSec,
          startFreqHz: startFreqHz,
          targetFreqHz: targetFreqHz,
          hasGlide: note.hasGlide,
        );

        // Expressive cantabile vibrato after 90 ms (5.5 Hz, +/- 0.35%)
        final vibratoDepth = localSec > 0.09
            ? ((localSec - 0.09) / 0.12).clamp(0.0, 1.0) * 0.0035
            : 0.0;
        final instantFreq =
            baseFreq * (1.0 + vibratoDepth * math.sin(2.0 * math.pi * 5.5 * localSec));

        final env = _computeLegatoEnvelope(
          localSec: localSec,
          gateDurationSec: gateDurationSec,
          totalNoteSec: totalNoteSec,
          attackSec: 0.012,
          sustainDecayTau: 0.55,
        );

        final raw = _synthesizeVoiceSample(
          instrument: channel.instrument,
          freq: instantFreq,
          t: localSec,
        );

        final sample = raw * env * noteGain;
        outLeft[targetIdx] += sample * panLeft;
        outRight[targetIdx] += sample * panRight;
      }
    }

    // Apply 3,800 Hz 2-pole Butterworth Low-Pass Filter to remove metallic high-frequency harshness
    _applyButterworthLowPassInPlace(
      outLeft,
      cutoffHz: 3800.0,
      sampleRate: sampleRate,
    );
    _applyButterworthLowPassInPlace(
      outRight,
      cutoffHz: 3800.0,
      sampleRate: sampleRate,
    );
  }

  /// Synthesizes a single-channel [MelodyPatternEntity] into a 16-bit PCM RIFF/WAVE byte buffer.
  static Uint8List synthesizePatternToWavBytes(
    MelodyPatternEntity pattern, {
    int sampleRate = kSampleRate,
    SketchpadChannelRole? role,
  }) {
    final safeBpm = pattern.bpm.clamp(60, 200);
    final stepDurationSec = 60.0 / (safeBpm * 4.0);
    final totalDurationSec = stepDurationSec * 16.0;
    final totalSamples = (totalDurationSec * sampleRate).round();

    final mixBuffer = Float64List(totalSamples);
    final effectiveRole = role ??
        (pattern.instrument.isSubBass
            ? SketchpadChannelRole.bass
            : SketchpadChannelRole.lead);

    for (final note in pattern.notes) {
      final startSample =
          (note.stepIndex * stepDurationSec * sampleRate).round();
      final holdSec = stepDurationSec * 2.2;
      final stepSamples = (holdSec * sampleRate).round();

      final targetFreqHz = resolveScaleFrequencyHz(
        pattern.musicalKey,
        pattern.scaleMode,
        note.scaleRow,
        instrument: pattern.instrument,
        role: effectiveRole,
      );

      final startFreqHz =
          note.hasGlide ? (targetFreqHz * 0.8909) : targetFreqHz;
      final velocityGain = note.velocity.clamp(0.05, 1.0) * 0.45;

      for (var i = 0; i < stepSamples; i++) {
        final sampleIdx = startSample + i;
        if (sampleIdx >= totalSamples) break;

        final localSec = i / sampleRate;
        final instantFreq = _computeInstantFrequency(
          localSec: localSec,
          stepDurationSec: holdSec,
          startFreqHz: startFreqHz,
          targetFreqHz: targetFreqHz,
          hasGlide: note.hasGlide,
        );

        final env = _computeLegatoEnvelope(
          localSec: localSec,
          gateDurationSec: stepDurationSec * 1.8,
          totalNoteSec: holdSec,
          attackSec: 0.010,
          sustainDecayTau: 0.45,
        );

        final rawSample = _synthesizeVoiceSample(
          instrument: pattern.instrument,
          freq: instantFreq,
          t: localSec,
        );

        mixBuffer[sampleIdx] += rawSample * env * velocityGain;
      }
    }

    if (effectiveRole == SketchpadChannelRole.bass) {
      _applyButterworthLowPassInPlace(
        mixBuffer,
        cutoffHz: 195.0,
        sampleRate: sampleRate,
      );
    } else {
      _applyButterworthLowPassInPlace(
        mixBuffer,
        cutoffHz: 3800.0,
        sampleRate: sampleRate,
      );
    }

    return _encodePcm16WavMono(mixBuffer, sampleRate);
  }

  /// Synthesizes a single pitched note audition when a user taps a cell or live scale pad.
  static Uint8List synthesizeSingleNoteWavBytes({
    required SketchpadInstrument instrument,
    required double freqHz,
    double velocity = 0.85,
    bool hasGlide = false,
    double durationSec = 0.36,
    int sampleRate = kSampleRate,
    SketchpadChannelRole? role,
  }) {
    final totalSamples = (durationSec * sampleRate).round();
    final mixBuffer = Float64List(totalSamples);
    final effectiveInst = (role == SketchpadChannelRole.bass && !instrument.isSubBass)
        ? SketchpadInstrument.amapianoLogDrum
        : instrument;
    final startFreqHz = hasGlide ? (freqHz * 0.8909) : freqHz;
    final gain = velocity.clamp(0.05, 1.0) * 0.52;

    for (var i = 0; i < totalSamples; i++) {
      final localSec = i / sampleRate;
      final instantFreq = _computeInstantFrequency(
        localSec: localSec,
        stepDurationSec: durationSec,
        startFreqHz: startFreqHz,
        targetFreqHz: freqHz,
        hasGlide: hasGlide,
      );
      final env = _computeLegatoEnvelope(
        localSec: localSec,
        gateDurationSec: durationSec * 0.78,
        totalNoteSec: durationSec,
        attackSec: 0.008,
        sustainDecayTau: 0.42,
      );
      final rawSample = _synthesizeVoiceSample(
        instrument: effectiveInst,
        freq: instantFreq,
        t: localSec,
      );
      mixBuffer[i] = rawSample * env * gain;
    }

    if (role == SketchpadChannelRole.bass || effectiveInst.isSubBass) {
      _applyButterworthLowPassInPlace(
        mixBuffer,
        cutoffHz: 195.0,
        sampleRate: sampleRate,
      );
    } else {
      _applyButterworthLowPassInPlace(
        mixBuffer,
        cutoffHz: 3800.0,
        sampleRate: sampleRate,
      );
    }

    return _encodePcm16WavMono(mixBuffer, sampleRate);
  }

  /// Synthesizes a single drum or hat-percussion hit for immediate pad auditioning
  /// on [SketchpadChannelRole.drums] or [SketchpadChannelRole.hats] (REQ-P57-HATS-03).
  static Uint8List synthesizeSingleDrumOrHatWavBytes({
    required SketchpadChannelRole role,
    required BeatKitGenre kit,
    required int row,
    double velocity = 0.88,
    double durationSec = 0.28,
    int sampleRate = kSampleRate,
  }) {
    final totalSamples = (durationSec * sampleRate).round();
    final mixBuffer = Float64List(totalSamples);
    final gain = velocity.clamp(0.05, 1.0) * 0.62;
    final clampedRow = row.clamp(0, 7);

    for (var i = 0; i < totalSamples; i++) {
      final localSec = i / sampleRate;
      final raw = role == SketchpadChannelRole.hats
          ? synthesizeHatPercVoice(
              kit: kit,
              row: clampedRow,
              t: localSec,
              stepDurationSec: 0.132,
            )
          : synthesizeDrumRackVoice(
              kit: kit,
              row: clampedRow,
              t: localSec,
            );
      mixBuffer[i] = raw * gain;
    }

    return _encodePcm16WavMono(mixBuffer, sampleRate);
  }

  /// Synthesizes a 2.5-second Regional Voice Archetype preview clip.
  static Uint8List synthesizeVoiceArchetypePreviewWavBytes(
    RegionalVoiceArchetype archetype, {
    int sampleRate = kSampleRate,
  }) {
    const durationSec = 2.5;
    final totalSamples = (durationSec * sampleRate).round();
    final mixBuffer = Float64List(totalSamples);

    final baseFreq = _resolveArchetypeBaseFrequencyHz(archetype);
    final phraseSemitones = [0, 3, 5, 7, 10, 7, 5, 0];
    final noteDuration = durationSec / phraseSemitones.length;

    for (var n = 0; n < phraseSemitones.length; n++) {
      final semitone = phraseSemitones[n];
      final noteFreq = baseFreq * math.pow(2.0, semitone / 12.0);
      final startSample = (n * noteDuration * sampleRate).round();
      final noteSamples = (noteDuration * sampleRate).round();

      for (var i = 0; i < noteSamples; i++) {
        final idx = startSample + i;
        if (idx >= totalSamples) break;
        final t = i / sampleRate;

        final vibrato = 1.0 + 0.009 * math.sin(2.0 * math.pi * 5.8 * t);
        final f = noteFreq * vibrato;

        final f1 = math.sin(2.0 * math.pi * f * t);
        final f2 = 0.52 * math.sin(2.0 * math.pi * (f * 2.0) * t);
        final f3 = 0.28 * math.sin(2.0 * math.pi * (f * 3.0) * t);
        final f4 = 0.14 * math.sin(2.0 * math.pi * (f * 4.0) * t);

        final attack = (t / 0.035).clamp(0.0, 1.0);
        final release = ((noteDuration - t) / 0.06).clamp(0.0, 1.0);
        final env = attack * release;

        mixBuffer[idx] += (f1 + f2 + f3 + f4) * env * 0.34;
      }
    }

    return _encodePcm16WavMono(mixBuffer, sampleRate);
  }

  /// Synthesizes a vocal archetype melody preview.
  static Uint8List synthesizeVocalPreviewWavBytes(
    RegionalVoiceArchetype archetype, {
    int sampleRate = kSampleRate,
  }) {
    final baseFreq = _resolveArchetypeBaseFrequencyHz(archetype);
    final semitones = switch (archetype.deliveryStyle) {
      VocalDeliveryStyle.amapianoChant => [0, 3, 7, 5],
      VocalDeliveryStyle.afroSoulMelodic => [0, 3, 5, 7],
      VocalDeliveryStyle.maskandiPraise => [0, 4, 7, 2],
      VocalDeliveryStyle.gqomHype => [0, 1, 0, 5],
      VocalDeliveryStyle.afrobeatsBounce => [0, 3, 7, 10],
      VocalDeliveryStyle.zionChoir => [0, 3, 7, 12],
    };

    const totalSec = 1.75;
    final totalSamples = (totalSec * sampleRate).round();
    final mixBuffer = Float64List(totalSamples);
    final noteDurSec = totalSec / semitones.length;
    final noteSamples = (noteDurSec * sampleRate).round();

    final f1 = archetype.gender == VocalGender.female ? 720.0 : 580.0;
    final f2 = archetype.gender == VocalGender.female ? 1240.0 : 1080.0;

    for (var nIdx = 0; nIdx < semitones.length; nIdx++) {
      final startSample = nIdx * noteSamples;
      final f0 = baseFreq * math.pow(2.0, semitones[nIdx] / 12.0);
      for (var i = 0;
          i < noteSamples && (startSample + i) < totalSamples;
          i++) {
        final t = i / sampleRate;
        final vibrato = 1.0 + 0.008 * math.sin(2.0 * math.pi * 5.5 * t);
        final instF0 = f0 * vibrato;

        var glottal = 0.0;
        for (var h = 1; h <= 8; h++) {
          final hFreq = instF0 * h;
          final d1 = (hFreq - f1) / 220.0;
          final d2 = (hFreq - f2) / 340.0;
          final formantGain = 0.35 +
              0.85 * math.exp(-0.5 * d1 * d1) +
              0.55 * math.exp(-0.5 * d2 * d2);
          glottal += (formantGain / h) * math.sin(2.0 * math.pi * hFreq * t);
        }

        final attack = (t / 0.035).clamp(0.0, 1.0);
        final release = math.exp(-t / 0.36);
        mixBuffer[startSample + i] += glottal * attack * release * 0.48;
      }
    }

    return _encodePcm16WavMono(mixBuffer, sampleRate);
  }

  /// Synthesizes a multi-layered African reel groove for instant preview.
  static Uint8List synthesizeReelGrooveWavBytes({
    required String genre,
    required int bpm,
    String musicalKey = 'Am',
    int seed = 1,
    int sampleRate = kSampleRate,
  }) {
    final safeBpm = bpm.clamp(85, 160);
    final stepSec = 60.0 / safeBpm / 4.0;
    final totalSec = (stepSec * 16.0).clamp(1.5, 5.0);
    final totalSamples = (totalSec * sampleRate).round();
    final mixBuffer = Float64List(totalSamples);

    final lowerGenre = genre.toLowerCase();
    final isGqom = lowerGenre.contains('gqom');
    final isMaskandi = lowerGenre.contains('maskandi');
    final isAfroHouse =
        lowerGenre.contains('house') || lowerGenre.contains('afro');

    final scaleMode = isMaskandi
        ? AfricanScaleMode.maskandiHexatonic
        : (isAfroHouse
            ? AfricanScaleMode.naturalMinor
            : AfricanScaleMode.minorPentatonic);

    for (var step = 0; step < 16; step++) {
      final startSample = (step * stepSec * sampleRate).round().clamp(
            0,
            totalSamples - 1,
          );
      final shakerDur = math.min(
        (0.04 * sampleRate).round(),
        totalSamples - startSample,
      );
      final isFourOnFloor = step % 4 == 0;
      final isGqomKick = isGqom &&
          (step == 0 || step == 3 || step == 6 || step == 10 || step == 12);
      final hasKick = isGqom ? isGqomKick : isFourOnFloor;

      for (var i = 0; i < shakerDur; i++) {
        final t = i / sampleRate;
        final noise = math.sin(i * 12.9898 + step * 78.233) *
            math.cos(i * 4.1414 + 1.7);
        final shakerEnv = math.exp(-t / 0.013) * 0.05;
        mixBuffer[startSample + i] += noise * shakerEnv;
      }

      if (hasKick) {
        final kickSamples = math.min(
          (0.18 * sampleRate).round(),
          totalSamples - startSample,
        );
        double kickPhase = 0.0;
        for (var i = 0; i < kickSamples; i++) {
          final t = i / sampleRate;
          final kickFreq = 52.0 + 110.0 * math.exp(-t / 0.018);
          kickPhase += (2.0 * math.pi * kickFreq) / sampleRate;
          final kickEnv = math.exp(-t / 0.09);
          mixBuffer[startSample + i] += math.sin(kickPhase) * kickEnv * 0.72;
        }
      }
    }

    final leadRowSeq = [0, 2, 4, 3, 5, 2, 6, 1, 4, 7, 3, 0];
    for (var s = 0; s < 12; s++) {
      final step = (s * 4 ~/ 3).clamp(0, 15);
      final start = (step * stepSec * sampleRate).round().clamp(
            0,
            totalSamples - 1,
          );
      final f0 = resolveScaleFrequencyHz(
        musicalKey,
        scaleMode,
        leadRowSeq[s % leadRowSeq.length],
        instrument: SketchpadInstrument.privateSchoolRhodes,
      );
      final durSamples = math.min(
        (0.24 * sampleRate).round(),
        totalSamples - start,
      );

      for (var i = 0; i < durSamples; i++) {
        final t = i / sampleRate;
        final env = math.exp(-t / 0.16);
        final tone = math.sin(2.0 * math.pi * f0 * t) +
            0.4 * math.sin(2.0 * math.pi * (f0 * 1.5) * t);
        mixBuffer[start + i] += tone * env * 0.35;
      }
    }

    return _encodePcm16WavMono(mixBuffer, sampleRate);
  }

  /// Generates in-key syncopated African rhythm pattern using Bjorklund's Euclidean spacing.
  static List<MelodyStepNote> generateEuclideanGrooveNotes({
    required int pulses,
    required SketchpadInstrument instrument,
    int totalSteps = 16,
  }) {
    final k = pulses.clamp(3, 12);
    final notes = <MelodyStepNote>[];
    const melodicContour = [0, 2, 4, 3, 5, 2, 6, 1, 4, 7, 3, 0];

    var pulseIdx = 0;
    for (var step = 0; step < totalSteps; step++) {
      if (((step * k) % totalSteps) < k) {
        final row = melodicContour[pulseIdx % melodicContour.length];
        final isSub = instrument.isSubBass;
        final hasGlide = isSub && (pulseIdx % 3 == 1);
        notes.add(
          MelodyStepNote(
            stepIndex: step,
            scaleRow: row,
            velocity: (step % 4 == 0) ? 0.96 : 0.84,
            hasGlide: hasGlide,
            durationSteps: hasGlide ? 2 : 1,
          ),
        );
        pulseIdx++;
      }
    }
    return notes;
  }

  // ---------------------------------------------------------------------------
  // Internal Synthesis & Filtering Helpers
  // ---------------------------------------------------------------------------

  /// In-place 2-pole Butterworth Low-Pass Filter (Q = 0.7071).
  static void _applyButterworthLowPassInPlace(
    Float64List buffer, {
    required double cutoffHz,
    required int sampleRate,
  }) {
    if (buffer.isEmpty) return;
    final nyquist = sampleRate * 0.48;
    final fc = cutoffHz.clamp(20.0, nyquist);
    final w0 = 2.0 * math.pi * fc / sampleRate;
    final cosW0 = math.cos(w0);
    final sinW0 = math.sin(w0);
    final alpha = sinW0 / math.sqrt2;

    final a0 = 1.0 + alpha;
    final b0 = ((1.0 - cosW0) * 0.5) / a0;
    final b1 = (1.0 - cosW0) / a0;
    final b2 = ((1.0 - cosW0) * 0.5) / a0;
    final a1 = (-2.0 * cosW0) / a0;
    final a2 = (1.0 - alpha) / a0;

    var x1 = 0.0;
    var x2 = 0.0;
    var y1 = 0.0;
    var y2 = 0.0;

    for (var i = 0; i < buffer.length; i++) {
      final x0 = buffer[i];
      final y0 = (b0 * x0) + (b1 * x1) + (b2 * x2) - (a1 * y1) - (a2 * y2);
      buffer[i] = y0;
      x2 = x1;
      x1 = x0;
      y2 = y1;
      y1 = y0;
    }
  }

  static double _computeInstantFrequency({
    required double localSec,
    required double stepDurationSec,
    required double startFreqHz,
    required double targetFreqHz,
    required bool hasGlide,
  }) {
    if (!hasGlide) return targetFreqHz;
    final glideWindow = stepDurationSec * 0.55;
    if (localSec >= glideWindow || glideWindow <= 0.0) return targetFreqHz;
    final progress = (localSec / glideWindow).clamp(0.0, 1.0);
    final smoothProgress = 0.5 - 0.5 * math.cos(math.pi * progress);
    return startFreqHz + (targetFreqHz - startFreqHz) * smoothProgress;
  }

  static double _computeLegatoEnvelope({
    required double localSec,
    required double gateDurationSec,
    required double totalNoteSec,
    required double attackSec,
    required double sustainDecayTau,
  }) {
    if (localSec < 0.0 || localSec >= totalNoteSec) return 0.0;
    if (localSec < attackSec) {
      return 0.5 * (1.0 - math.cos(math.pi * (localSec / attackSec)));
    }
    final sustainLevel =
        0.35 + 0.65 * math.exp(-(localSec - attackSec) / sustainDecayTau);
    if (localSec <= gateDurationSec) {
      return sustainLevel;
    }
    final releaseDuration = math.max(0.015, totalNoteSec - gateDurationSec);
    final releaseProgress =
        ((localSec - gateDurationSec) / releaseDuration).clamp(0.0, 1.0);
    final releaseCurve = 0.5 * (1.0 + math.cos(math.pi * releaseProgress));
    return sustainLevel * releaseCurve;
  }

  /// Exact analytical phase integral for an exponential pitch-drop envelope:
  /// f(tau) = f0 + df * exp(-tau / tauP)
  /// Phi(t) = 2*pi * [ f0 * t + df * tauP * (1 - exp(-t / tauP)) ]
  static double _integratedPitchDropPhase({
    required double f0,
    required double deltaFreq,
    required double tauSec,
    required double t,
  }) {
    return 2.0 *
        math.pi *
        (f0 * t + deltaFreq * tauSec * (1.0 - math.exp(-t / tauSec)));
  }

  static double _synthesizeVoiceSample({
    required SketchpadInstrument instrument,
    required double freq,
    required double t,
  }) {
    final twoPiF = 2.0 * math.pi * freq;

    switch (instrument) {
      case SketchpadInstrument.amapianoLogDrum:
        // Phase 57 True Phase-Integrated Amapiano Log Drum:
        // Warm wooden mallet transient (deltaF = +65 Hz over tau = 14 ms) +
        // phase-locked 2nd harmonic (0.42x) and fast-decaying 3rd harmonic (0.16x).
        // Zero 380 Hz sine beep!
        final phi1 = _integratedPitchDropPhase(
          f0: freq,
          deltaFreq: 65.0,
          tauSec: 0.014,
          t: t,
        );
        final sub1 = math.sin(phi1);
        final sub2 = 0.42 * math.sin(2.0 * phi1) * math.exp(-t / 0.14);
        final wood3 = 0.16 * math.sin(3.0 * phi1) * math.exp(-t / 0.025);
        return padeTanhLimiter((sub1 + sub2 + wood3) * 1.35);

      case SketchpadInstrument.hipHop808Sub:
        // Phase-integrated 808 Sub: tight 18 ms punch glide (+55 Hz -> f0) + warm 2nd harmonic
        final phi = _integratedPitchDropPhase(
          f0: freq,
          deltaFreq: 55.0,
          tauSec: 0.018,
          t: t,
        );
        final sub = math.sin(phi);
        final drive2 = 0.34 * math.sin(2.0 * phi) * math.exp(-t / 0.20);
        return padeTanhLimiter((sub + drive2) * 1.40);

      case SketchpadInstrument.gqomDarkSub:
        // Phase-integrated Gqom Dark Sub: deep hollow sub + low-mid body (zero 620 Hz beep)
        final phi = _integratedPitchDropPhase(
          f0: freq,
          deltaFreq: 48.0,
          tauSec: 0.015,
          t: t,
        );
        final sub = math.sin(phi);
        final fifth = 0.25 * math.sin(1.5 * phi) * math.exp(-t / 0.09);
        final octave = 0.35 * math.sin(2.0 * phi) * math.exp(-t / 0.12);
        return padeTanhLimiter((sub + fifth + octave) * 1.35);

      case SketchpadInstrument.concertGrandPiano:
      case SketchpadInstrument.classicPiano:
        final b = 0.00035;
        final h1 = math.sin(twoPiF * t);
        final h2 =
            0.52 * math.sin(2.0 * twoPiF * math.sqrt(1.0 + 4.0 * b) * t) * math.exp(-t / 0.35);
        final h3 =
            0.26 * math.sin(3.0 * twoPiF * math.sqrt(1.0 + 9.0 * b) * t) * math.exp(-t / 0.22);
        final h4 =
            0.12 * math.sin(4.0 * twoPiF * math.sqrt(1.0 + 16.0 * b) * t) * math.exp(-t / 0.14);
        return (h1 + h2 + h3 + h4) * 0.62;

      case SketchpadInstrument.privateSchoolRhodes:
        final modIndex = 1.45 * math.exp(-t / 0.18);
        final modulator = math.sin(twoPiF * 2.0 * t);
        final carrier = math.sin(twoPiF * t + modIndex * modulator);
        final warmOctave =
            0.28 * math.sin(twoPiF * 0.5 * t) * (1.0 - math.exp(-t / 0.02));
        final tremolo = 1.0 - 0.12 * (1.0 - math.cos(2.0 * math.pi * 4.5 * t));
        return (carrier * 0.76 + warmOctave) * tremolo * 0.72;

      case SketchpadInstrument.maskandiGuitar:
      case SketchpadInstrument.nylonGuitar:
        final brightness =
            instrument == SketchpadInstrument.maskandiGuitar ? 1.0 : 0.65;
        final h1 = math.sin(twoPiF * t);
        final h2 =
            0.58 * brightness * math.sin(twoPiF * 2.0 * t) * math.exp(-t / 0.18);
        final h3 =
            0.34 * brightness * math.sin(twoPiF * 3.0 * t) * math.exp(-t / 0.11);
        final h4 =
            0.18 * brightness * math.sin(twoPiF * 4.0 * t) * math.exp(-t / 0.06);
        return (h1 + h2 + h3 + h4) * 0.60;

      case SketchpadInstrument.electricGuitar:
        final clean = math.sin(twoPiF * t) +
            0.48 * math.sin(twoPiF * 2.0 * t) * math.exp(-t / 0.24) +
            0.22 * math.sin(twoPiF * 3.0 * t) * math.exp(-t / 0.14);
        return padeTanhLimiter(clean * 1.25) * 0.68;

      case SketchpadInstrument.soloViolin:
        final bowAttack = (1.0 - math.exp(-t / 0.045));
        final vib = 1.0 + 0.005 * math.sin(2.0 * math.pi * 5.8 * t);
        final vf = twoPiF * vib;
        final s1 = math.sin(vf * t);
        final s2 = 0.45 * math.sin(vf * 2.0 * t);
        final s3 = 0.28 * math.sin(vf * 3.0 * t);
        final s4 = 0.15 * math.sin(vf * 4.0 * t);
        return (s1 + s2 + s3 + s4) * bowAttack * 0.56;

      case SketchpadInstrument.vendaMbira:
        final fundamental = math.sin(twoPiF * t);
        final overtone =
            0.38 * math.sin(twoPiF * 2.92 * t) * math.exp(-t / 0.09);
        final warmSub = 0.25 * math.sin(twoPiF * 0.5 * t);
        return (fundamental + overtone + warmSub) * 0.64;

      case SketchpadInstrument.marimbaWood:
        final fundamental = math.sin(twoPiF * t);
        final fourthHarm =
            0.32 * math.sin(twoPiF * 3.98 * t) * math.exp(-t / 0.032);
        return (fundamental + fourthHarm) * 0.72;

      case SketchpadInstrument.bambooFlute:
        final vib = 1.0 + 0.004 * math.sin(2.0 * math.pi * 5.0 * t);
        final vf = twoPiF * vib;
        final pure = math.sin(vf * t) + 0.22 * math.sin(vf * 2.0 * t);
        return pure * 0.68;

      case SketchpadInstrument.sopranoSax:
        final vib = 1.0 + 0.005 * math.sin(2.0 * math.pi * 5.4 * t);
        final vf = twoPiF * vib;
        final reed = math.sin(vf * t) +
            0.52 * math.sin(vf * 2.0 * t) +
            0.30 * math.sin(vf * 3.0 * t) +
            0.14 * math.sin(vf * 4.0 * t);
        return padeTanhLimiter(reed * 0.95) * 0.62;

      case SketchpadInstrument.neoSoulPad:
        final d1 = math.sin(twoPiF * 0.997 * t);
        final d2 = math.sin(twoPiF * 1.003 * t);
        final fifth = 0.36 * math.sin(twoPiF * 1.498 * t);
        final octave = 0.22 * math.sin(twoPiF * 2.002 * t);
        return (d1 + d2 + fifth + octave) * 0.36;

      case SketchpadInstrument.mbaqangaOrgan:
        final sub = 0.50 * math.sin(twoPiF * 0.5 * t);
        final fund = 0.80 * math.sin(twoPiF * t);
        final fifth = 0.42 * math.sin(twoPiF * 1.498 * t);
        final oct = 0.46 * math.sin(twoPiF * 2.0 * t);
        final third = 0.24 * math.sin(twoPiF * 2.52 * t);
        final rotary = 1.0 + 0.08 * math.sin(2.0 * math.pi * 6.2 * t);
        return (sub + fund + fifth + oct + third) * rotary * 0.40;
    }
  }

  /// Deterministic pseudo-random white noise generator in [-1.0, 1.0] using integer bit-mixing.
  static double _whiteNoiseAtSample(int sampleIdx, int seedSalt) {
    var n = (sampleIdx * 374761393) + (seedSalt * 668265263);
    n = (n ^ (n >> 13)) * 1274126177;
    n = n ^ (n >> 16);
    return ((n & 0x7FFFFFFF) / 1073741823.5) - 1.0;
  }

  // ---------------------------------------------------------------------------
  // 8-Row Studio Drum Rack Synthesizer (SketchpadChannelRole.drums)
  // ---------------------------------------------------------------------------
  static double synthesizeDrumRackVoice({
    required BeatKitGenre kit,
    required int row,
    required double t,
  }) {
    final sampleIdx = (t * kSampleRate).round();

    switch (row.clamp(0, 7)) {
      // Row 0: Sub 808 / Log Kick (Phase-Integrated, Zero 420 Hz Beep)
      case 0:
        final baseFreq = kit == BeatKitGenre.gqom
            ? 46.0
            : (kit == BeatKitGenre.amapiano ? 52.0 : 48.0);
        final decayTau = kit == BeatKitGenre.hipHop ? 0.34 : 0.26;
        final phi = _integratedPitchDropPhase(
          f0: baseFreq,
          deltaFreq: 95.0,
          tauSec: 0.016,
          t: t,
        );
        final sub = math.sin(phi) * math.exp(-t / decayTau);
        final harm2 = 0.28 * math.sin(2.0 * phi) * math.exp(-t / 0.08);
        return padeTanhLimiter((sub + harm2) * 1.45) * 0.86;

      // Row 1: Punch Kick (Phase-Integrated Tight Chest Thump)
      case 1:
        final phi = _integratedPitchDropPhase(
          f0: 56.0,
          deltaFreq: 130.0,
          tauSec: 0.012,
          t: t,
        );
        final body = math.sin(phi) * math.exp(-t / 0.14);
        final beater =
            0.22 * _whiteNoiseAtSample(sampleIdx, 101) * math.exp(-t / 0.005);
        return padeTanhLimiter((body + beater) * 1.35) * 0.84;

      // Row 2: Crisp Acoustic / Trap Snare
      case 2:
        final phi = _integratedPitchDropPhase(
          f0: 185.0,
          deltaFreq: 65.0,
          tauSec: 0.010,
          t: t,
        );
        final body = 0.52 * math.sin(phi) * math.exp(-t / 0.055);
        final n0 = _whiteNoiseAtSample(sampleIdx, 202);
        final n1 = _whiteNoiseAtSample(sampleIdx - 1, 202);
        final snareWires = (n0 - 0.45 * n1) * math.exp(-t / 0.115);
        return (body + snareWires * 0.65) * 0.78;

      // Row 3: Afro-Wood Rimshot
      case 3:
        final mode1 = math.sin(2.0 * math.pi * 490.0 * t);
        final mode2 = 0.68 * math.sin(2.0 * math.pi * 1340.0 * t);
        final click = 0.30 * _whiteNoiseAtSample(sampleIdx, 303) * math.exp(-t / 0.004);
        return ((mode1 + mode2) * math.exp(-t / 0.022) + click) * 0.76;

      // Row 4: Club Handclap (4 Micro-Diffused Noise Bursts)
      case 4:
        final b1 = math.exp(-t / 0.007);
        final b2 = t >= 0.010 ? math.exp(-(t - 0.010) / 0.007) : 0.0;
        final b3 = t >= 0.020 ? math.exp(-(t - 0.020) / 0.008) : 0.0;
        final b4 = t >= 0.030 ? math.exp(-(t - 0.030) / 0.065) : 0.0;
        final n0 = _whiteNoiseAtSample(sampleIdx, 404);
        final n1 = _whiteNoiseAtSample(sampleIdx - 1, 404);
        final hpNoise = n0 - 0.65 * n1;
        return hpNoise * (b1 + b2 + b3 + b4) * 0.52;

      // Row 5: Closed Hi-Hat
      case 5:
        return synthesizeHatPercVoice(
          kit: kit,
          row: 5,
          t: t,
          stepDurationSec: 0.132,
        );

      // Row 6: Open Shimmer Hat
      case 6:
        return synthesizeHatPercVoice(
          kit: kit,
          row: 6,
          t: t,
          stepDurationSec: 0.132,
        );

      // Row 7: Mbaḓi Shaker
      case 7:
        return synthesizeHatPercVoice(
          kit: kit,
          row: 3,
          t: t,
          stepDurationSec: 0.132,
        );

      default:
        return 0.0;
    }
  }

  // ---------------------------------------------------------------------------
  // Dedicated 8-Row High-Frequency Percussion Matrix (SketchpadChannelRole.hats)
  // Phase 57 REQ-P57-HATS-01..03
  // ---------------------------------------------------------------------------
  static double synthesizeHatPercVoice({
    required BeatKitGenre kit,
    required int row,
    required double t,
    double stepDurationSec = 0.132,
  }) {
    if (t < 0.0) return 0.0;
    final sampleIdx = (t * kSampleRate).round();

    switch (row.clamp(0, 7)) {
      // Row 0: Talking Conga Slap (Phase-integrated 460 Hz -> 380 Hz membrane slap)
      case 0:
        final phi = _integratedPitchDropPhase(
          f0: 380.0,
          deltaFreq: 80.0,
          tauSec: 0.010,
          t: t,
        );
        final membrane = math.sin(phi) * math.exp(-t / 0.065);
        final overtone =
            0.38 * math.sin(1.58 * phi) * math.exp(-t / 0.024);
        final palmSlap = 0.35 *
            (_whiteNoiseAtSample(sampleIdx, 700) -
                _whiteNoiseAtSample(sampleIdx - 1, 700)) *
            math.exp(-t / 0.008);
        return (membrane + overtone + palmSlap) * 0.74;

      // Row 1: Afro Wood Clave (Dual-mode hollow rosewood resonator 1,420 Hz + 2,180 Hz)
      case 1:
        final mode1 = math.sin(2.0 * math.pi * 1420.0 * t);
        final mode2 = 0.58 * math.sin(2.0 * math.pi * 2180.0 * t);
        final woodClick = 0.22 *
            (_whiteNoiseAtSample(sampleIdx, 701) -
                _whiteNoiseAtSample(sampleIdx - 1, 701)) *
            math.exp(-t / 0.003);
        return ((mode1 + mode2) * math.exp(-t / 0.018) + woodClick) * 0.72;

      // Row 2: Shekere Bead Groove (Triple-grain woven gourd friction envelope at 4.6 kHz)
      case 2:
        final n0 = _whiteNoiseAtSample(sampleIdx, 702);
        final n2 = _whiteNoiseAtSample(sampleIdx - 2, 702);
        final bandNoise = (n0 - n2) * 0.55;
        final carrier = math.sin(2.0 * math.pi * 4600.0 * t);
        final grain1 = math.exp(-math.pow((t - 0.010) / 0.011, 2));
        final grain2 = 0.75 * math.exp(-math.pow((t - 0.032) / 0.014, 2));
        final grain3 = 0.55 * math.exp(-math.pow((t - 0.056) / 0.016, 2));
        final gourdBody =
            0.22 * math.sin(2.0 * math.pi * 310.0 * t) * math.exp(-t / 0.026);
        return ((bandNoise * (0.65 + 0.35 * carrier) * (grain1 + grain2 + grain3)) +
                gourdBody) *
            0.76;

      // Row 3: Mbaḓi Seed Shaker (Dual-grain band-passed seed rattle at 5.8 kHz)
      case 3:
        final n0 = _whiteNoiseAtSample(sampleIdx, 703);
        final n1 = _whiteNoiseAtSample(sampleIdx - 1, 703);
        final hpNoise = (n0 - 0.82 * n1) * 0.65;
        final bandMod = 0.6 + 0.4 * math.sin(2.0 * math.pi * 5800.0 * t);
        final attackScrape = (t / 0.016).clamp(0.0, 1.0);
        final decay = math.exp(-t / 0.034);
        final secondGrain =
            t > 0.024 ? 0.48 * math.exp(-(t - 0.024) / 0.022) : 0.0;
        return hpNoise * bandMod * (attackScrape * decay + secondGrain) * 0.78;

      // Row 4: 32nd Sgija Hat Roll (3-hit micro-ratchet closed hat roll across step)
      case 4:
        final subStepSec = (stepDurationSec / 3.0).clamp(0.028, 0.065);
        final hitIndex = (t / subStepSec).floor();
        if (hitIndex < 0 || hitIndex >= 3) return 0.0;
        final localHitSec = t - (hitIndex * subStepSec);
        const crescendoVelocities = [0.55, 0.78, 1.00];
        final hitVel = crescendoVelocities[hitIndex];
        return _synthesizeMetallicHatCore(
              t: localHitSec,
              sampleIdx: sampleIdx + hitIndex * 97,
              decayTau: 0.018,
              highPassAlpha: 0.88,
            ) *
            hitVel;

      // Row 5: Closed Crisp Hat (High-passed at 8.2 kHz, tight 22 ms chick envelope)
      case 5:
        final decay = kit == BeatKitGenre.hipHop ? 0.020 : 0.024;
        return _synthesizeMetallicHatCore(
          t: t,
          sampleIdx: sampleIdx,
          decayTau: decay,
          highPassAlpha: 0.90,
        );

      // Row 6: Open Shimmer Hat (6-oscillator metallic ring matrix, tau = 240 ms)
      case 6:
        return _synthesizeMetallicHatCore(
          t: t,
          sampleIdx: sampleIdx,
          decayTau: 0.240,
          highPassAlpha: 0.84,
        ) *
            0.88;

      // Row 7: Crash / Ride Shimmer (Inharmonic bronze cluster + air sheen, tau = 380 ms)
      case 7:
        final c1 = math.sin(2.0 * math.pi * 3420.0 * t);
        final c2 = 0.82 * math.sin(2.0 * math.pi * 4870.0 * t);
        final c3 = 0.70 * math.sin(2.0 * math.pi * 6310.0 * t);
        final c4 = 0.58 * math.sin(2.0 * math.pi * 7840.0 * t);
        final c5 = 0.45 * math.sin(2.0 * math.pi * 9190.0 * t);
        final n0 = _whiteNoiseAtSample(sampleIdx, 707);
        final n1 = _whiteNoiseAtSample(sampleIdx - 1, 707);
        final hpSizzle = (n0 - 0.85 * n1) * 0.65;
        final shimmerCluster = (c1 + c2 + c3 + c4 + c5) * 0.22 + hpSizzle;
        return shimmerCluster * math.exp(-t / 0.380) * 0.76;

      default:
        return 0.0;
    }
  }

  /// 6-oscillator non-harmonic metallic cymbal/hi-hat matrix combined with
  /// first-difference high-passed sizzle noise (zero low-frequency energy).
  static double _synthesizeMetallicHatCore({
    required double t,
    required int sampleIdx,
    required double decayTau,
    required double highPassAlpha,
  }) {
    // Classic 6-ratio inharmonic metallic frequencies (all > 3.1 kHz)
    final m1 = math.sin(2.0 * math.pi * 3240.0 * t);
    final m2 = math.sin(2.0 * math.pi * 4580.0 * t);
    final m3 = math.sin(2.0 * math.pi * 5960.0 * t);
    final m4 = math.sin(2.0 * math.pi * 7410.0 * t);
    final m5 = math.sin(2.0 * math.pi * 8890.0 * t);
    final m6 = math.sin(2.0 * math.pi * 10420.0 * t);
    final metalRing = (m1 + m2 + m3 + m4 + m5 + m6) * 0.14;

    final n0 = _whiteNoiseAtSample(sampleIdx, 505);
    final n1 = _whiteNoiseAtSample(sampleIdx - 1, 505);
    final hpCrispNoise = (n0 - highPassAlpha * n1) * 0.55;

    final env = math.exp(-t / decayTau);
    return (metalRing + hpCrispNoise) * env * 0.78;
  }

  // ---------------------------------------------------------------------------
  // RIFF/WAVE Encoding (Mono & Stereo) with Bounded Padé [3/2] Soft-Knee Limiter
  // ---------------------------------------------------------------------------

  static Uint8List _encodePcm16WavMono(Float64List mixBuffer, int sampleRate) {
    final totalSamples = mixBuffer.length;
    final dataSize = totalSamples * 2;
    final wav = ByteData(44 + dataSize);

    // RIFF header
    wav.setUint8(0, 0x52);
    wav.setUint8(1, 0x49);
    wav.setUint8(2, 0x46);
    wav.setUint8(3, 0x46);
    wav.setUint32(4, 36 + dataSize, Endian.little);
    // WAVEfmt
    wav.setUint8(8, 0x57);
    wav.setUint8(9, 0x41);
    wav.setUint8(10, 0x56);
    wav.setUint8(11, 0x45);
    wav.setUint8(12, 0x66);
    wav.setUint8(13, 0x6D);
    wav.setUint8(14, 0x74);
    wav.setUint8(15, 0x20);
    wav.setUint32(16, 16, Endian.little);
    wav.setUint16(20, 1, Endian.little); // PCM
    wav.setUint16(22, 1, Endian.little); // Mono
    wav.setUint32(24, sampleRate, Endian.little);
    wav.setUint32(28, sampleRate * 2, Endian.little);
    wav.setUint16(32, 2, Endian.little);
    wav.setUint16(34, 16, Endian.little);
    // data
    wav.setUint8(36, 0x64);
    wav.setUint8(37, 0x61);
    wav.setUint8(38, 0x74);
    wav.setUint8(39, 0x61);
    wav.setUint32(40, dataSize, Endian.little);

    for (var i = 0; i < totalSamples; i++) {
      final saturated = padeTanhLimiter(mixBuffer[i] * 1.12);
      final pcm16 = (saturated * 31800.0).round().clamp(-32767, 32767);
      wav.setInt16(44 + i * 2, pcm16, Endian.little);
    }

    return wav.buffer.asUint8List();
  }

  static Uint8List _encodePcm16WavStereo(
    Float64List leftBuffer,
    Float64List rightBuffer,
    int sampleRate, {
    double drive = 0.20,
  }) {
    final totalSamples = leftBuffer.length;
    const numChannels = 2;
    final dataSize = totalSamples * numChannels * 2;
    final wav = ByteData(44 + dataSize);

    // RIFF header
    wav.setUint8(0, 0x52);
    wav.setUint8(1, 0x49);
    wav.setUint8(2, 0x46);
    wav.setUint8(3, 0x46);
    wav.setUint32(4, 36 + dataSize, Endian.little);
    // WAVEfmt
    wav.setUint8(8, 0x57);
    wav.setUint8(9, 0x41);
    wav.setUint8(10, 0x56);
    wav.setUint8(11, 0x45);
    wav.setUint8(12, 0x66);
    wav.setUint8(13, 0x6D);
    wav.setUint8(14, 0x74);
    wav.setUint8(15, 0x20);
    wav.setUint32(16, 16, Endian.little);
    wav.setUint16(20, 1, Endian.little); // PCM
    wav.setUint16(22, numChannels, Endian.little); // Stereo
    wav.setUint32(24, sampleRate, Endian.little);
    wav.setUint32(28, sampleRate * numChannels * 2, Endian.little);
    wav.setUint16(32, numChannels * 2, Endian.little);
    wav.setUint16(34, 16, Endian.little);
    // data
    wav.setUint8(36, 0x64);
    wav.setUint8(37, 0x61);
    wav.setUint8(38, 0x74);
    wav.setUint8(39, 0x61);
    wav.setUint32(40, dataSize, Endian.little);

    final driveMult = 1.0 + 0.45 * drive.clamp(0.0, 1.0);
    for (var i = 0; i < totalSamples; i++) {
      final leftSat = padeTanhLimiter(leftBuffer[i] * driveMult);
      final rightSat = padeTanhLimiter(rightBuffer[i] * driveMult);

      final leftPcm = (leftSat * 31800.0).round().clamp(-32767, 32767);
      final rightPcm = (rightSat * 31800.0).round().clamp(-32767, 32767);

      wav.setInt16(44 + (i * 4), leftPcm, Endian.little);
      wav.setInt16(44 + (i * 4) + 2, rightPcm, Endian.little);
    }

    return wav.buffer.asUint8List();
  }

  static double _resolveArchetypeBaseFrequencyHz(
    RegionalVoiceArchetype archetype,
  ) {
    final range = archetype.vocalRange.toUpperCase();
    if (range.startsWith('E2') || range.startsWith('F2')) return 87.31;
    if (range.startsWith('G2') || range.startsWith('A2')) return 110.00;
    if (range.startsWith('B2') || range.startsWith('C3')) return 130.81;
    if (range.startsWith('F3') || range.startsWith('G3')) return 196.00;
    if (range.startsWith('A3') || range.startsWith('C4')) return 220.00;
    return archetype.gender == VocalGender.female ? 220.00 : 110.00;
  }
}
