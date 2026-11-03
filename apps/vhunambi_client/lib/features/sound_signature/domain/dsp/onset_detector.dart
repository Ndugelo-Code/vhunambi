import 'dart:math' as math;
import 'dart:typed_data';
import '../../../../features/studio/domain/models/melody_sketchpad_models.dart';
import '../models/rhythmic_transient_grid.dart';
import 'fft.dart';
import 'note_segmenter.dart';

/// Transient and rhythmic onset detector with 16-step grid alignment (REQ-SIG-ANALYSIS-01 / Design 4.7).
class OnsetDetector {
  const OnsetDetector({
    this.windowSize = 512,
    this.hopSize = 160, // 10ms at 16kHz
    this.refractoryMs = 50,
    this.localMedianWindowMs = 200,
    this.fluxThresholdFactor = 0.35,
  });

  final int windowSize;
  final int hopSize;
  final int refractoryMs;
  final int localMedianWindowMs;
  final double fluxThresholdFactor;

  /// Detects note/percussive onsets from [audio] (sampled at [sampleRate]),
  /// calculates signed deviations from [bpm] 16th-note grid, and produces [RhythmicTransientGrid].
  RhythmicTransientGrid detectTransients(
    Float32List audio, {
    int sampleRate = 16000,
    double bpm = 113.0,
    List<SegmentedNote> notes = const [],
    AfricanScaleMode scaleMode = AfricanScaleMode.minorPentatonic,
    int rootPitchClass = 0,
  }) {
    if (audio.length < windowSize) {
      return const RhythmicTransientGrid(
        onsetMs: [],
        offsetFromGridMs: [],
        quantizedNotes: [],
      );
    }

    final frameCount = (audio.length - windowSize) ~/ hopSize + 1;
    if (frameCount <= 1) {
      return const RhythmicTransientGrid(
        onsetMs: [],
        offsetFromGridMs: [],
        quantizedNotes: [],
      );
    }

    final halfN = windowSize ~/ 2;
    final logSpectra = List<Float32List>.generate(
      frameCount,
      (_) => Float32List(halfN + 1),
    );

    // 1. Log-magnitude STFT
    final real = Float64List(windowSize);
    final imag = Float64List(windowSize);
    const gamma = 10.0;

    for (var f = 0; f < frameCount; f++) {
      final start = f * hopSize;
      for (var i = 0; i < windowSize; i++) {
        // Hann window
        final w = 0.5 * (1.0 - math.cos((2.0 * math.pi * i) / (windowSize - 1)));
        real[i] = audio[start + i] * w;
        imag[i] = 0.0;
      }

      Fft.fft(real, imag);

      final spectrum = logSpectra[f];
      for (var k = 0; k <= halfN; k++) {
        final mag = math.sqrt(real[k] * real[k] + imag[k] * imag[k]);
        spectrum[k] = math.log(1.0 + gamma * mag);
      }
    }

    // 2. Half-wave rectified spectral flux
    final spectralFlux = Float64List(frameCount);
    var totalFlux = 0.0;

    for (var f = 1; f < frameCount; f++) {
      final curr = logSpectra[f];
      final prev = logSpectra[f - 1];
      var diffSum = 0.0;

      for (var k = 0; k <= halfN; k++) {
        final diff = curr[k] - prev[k];
        if (diff > 0.0) {
          diffSum += diff;
        }
      }
      spectralFlux[f] = diffSum;
      totalFlux += diffSum;
    }

    final meanFlux = frameCount > 1 ? totalFlux / (frameCount - 1) : 0.0;
    final delta = meanFlux * fluxThresholdFactor;

    // 3. Adaptive threshold (local median in 200 ms window)
    final msPerFrame = (hopSize * 1000.0) / sampleRate;
    final medianRadiusFrames = math.max(1, ((localMedianWindowMs / msPerFrame) / 2.0).round());
    final refractoryFrames = math.max(1, (refractoryMs / msPerFrame).round());

    final detectedOnsetFrames = <int>[];
    var lastOnsetFrame = -refractoryFrames;

    for (var f = 1; f < frameCount - 1; f++) {
      final currentFlux = spectralFlux[f];
      if (currentFlux <= spectralFlux[f - 1] || currentFlux < spectralFlux[f + 1]) {
        continue;
      }

      // Compute local median
      final winStart = math.max(0, f - medianRadiusFrames);
      final winEnd = math.min(frameCount - 1, f + medianRadiusFrames);
      final winValues = <double>[];
      for (var w = winStart; w <= winEnd; w++) {
        winValues.add(spectralFlux[w]);
      }
      winValues.sort();
      final localMedian = winValues[winValues.length ~/ 2];
      final threshold = localMedian + delta;

      if (currentFlux > threshold && (f - lastOnsetFrame) >= refractoryFrames) {
        detectedOnsetFrames.add(f);
        lastOnsetFrame = f;
      }
    }

    // 4. Calculate grid offsets (16th note step = (60/BPM)*1000/4 ms)
    final stepDurationMs = (60.0 / bpm) * 250.0; // 15000 / BPM
    final onsetMsList = <int>[];
    final offsetList = <int>[];

    for (final frame in detectedOnsetFrames) {
      final tMs = (frame * msPerFrame).round();
      final nearestStepNumber = (tMs / stepDurationMs).round();
      final nearestGridMs = (nearestStepNumber * stepDurationMs).round();
      final offset = (tMs - nearestGridMs).clamp(-128, 127);

      onsetMsList.add(tMs);
      offsetList.add(offset);
    }

    // 5. Build quantized MelodyStepNotes for sketchpad
    final quantized = _buildQuantizedNotes(
      notes: notes,
      onsetMsList: onsetMsList,
      stepDurationMs: stepDurationMs,
      scaleMode: scaleMode,
      rootPitchClass: rootPitchClass,
    );

    return RhythmicTransientGrid(
      onsetMs: onsetMsList,
      offsetFromGridMs: offsetList,
      quantizedNotes: quantized,
    );
  }

  List<MelodyStepNote> _buildQuantizedNotes({
    required List<SegmentedNote> notes,
    required List<int> onsetMsList,
    required double stepDurationMs,
    required AfricanScaleMode scaleMode,
    required int rootPitchClass,
  }) {
    final quantized = <MelodyStepNote>[];
    final occupiedSteps = <int>{};

    if (notes.isNotEmpty) {
      // Map segmented musical notes directly to 16-step grid
      for (final note in notes) {
        final step = ((note.startMs / stepDurationMs).round()) % 16;
        if (occupiedSteps.contains(step)) continue;
        occupiedSteps.add(step);

        final durSteps = ((note.durationMs / stepDurationMs).round()).clamp(1, 4);

        // Find closest scale row 0..7
        var closestRow = 0;
        var minDiff = double.infinity;
        final noteSemitone = note.medianSemitones;

        for (var row = 0; row < scaleMode.semitoneOffsets.length; row++) {
          final scalePitch = rootPitchClass + scaleMode.semitoneOffsets[row];
          final diff = ((noteSemitone - scalePitch) % 12).abs();
          final wrappedDiff = math.min(diff, 12 - diff);
          if (wrappedDiff < minDiff) {
            minDiff = wrappedDiff;
            closestRow = row.clamp(0, 7);
          }
        }

        quantized.add(
          MelodyStepNote(
            stepIndex: step,
            scaleRow: closestRow,
            velocity: math.min(1.0, math.max(0.5, note.stabilityScore)),
            durationSteps: durSteps,
          ),
        );
      }
    } else {
      // Fallback: build steps from transient onsets alone
      for (final onset in onsetMsList) {
        final step = ((onset / stepDurationMs).round()) % 16;
        if (occupiedSteps.contains(step)) continue;
        occupiedSteps.add(step);

        quantized.add(
          MelodyStepNote(
            stepIndex: step,
            scaleRow: 0,
            velocity: 0.85,
            durationSteps: 1,
          ),
        );
      }
    }

    return quantized;
  }
}

