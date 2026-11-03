import 'dart:math' as math;
import 'dart:typed_data';
import '../models/pitch_contour_profile.dart';

/// Segmented musical note parsed from continuous fundamental pitch contour.
class SegmentedNote {
  const SegmentedNote({
    required this.startMs,
    required this.endMs,
    required this.medianSemitones,
    required this.stabilityScore,
    required this.rawF0Frames,
    this.vibratoHz = 0.0,
    this.vibratoDepthCents = 0.0,
  });

  final int startMs;
  final int endMs;
  final double medianSemitones;
  final double stabilityScore;
  final List<int> rawF0Frames;
  final double vibratoHz;
  final double vibratoDepthCents;

  int get durationMs => endMs - startMs;
}

/// Segments voiced F0 contour into distinct musical notes (REQ-SIG-ANALYSIS-01 / Design 4.3).
class NoteSegmenter {
  const NoteSegmenter({
    this.frameDurationMs = 20, // 50 Hz = 20ms per frame
    this.pitchThresholdSemitones = 0.5,
    this.minDurationMs = 60,
    this.minGapMergeMs = 30,
  });

  final int frameDurationMs;
  final double pitchThresholdSemitones;
  final int minDurationMs;
  final int minGapMergeMs;

  /// Segments [f0CentsMidi] (where unvoiced = -32768) into [SegmentedNote]s.
  List<SegmentedNote> segmentNotes(List<int> f0CentsMidi) {
    if (f0CentsMidi.isEmpty) return const [];

    final rawNotes = <SegmentedNote>[];
    var inNote = false;
    var noteStartFrame = 0;
    final currentNoteCents = <int>[];

    for (var i = 0; i < f0CentsMidi.length; i++) {
      final cents = f0CentsMidi[i];
      final isVoiced = cents != PitchContourProfile.unvoicedSentinel;

      if (isVoiced) {
        if (!inNote) {
          inNote = true;
          noteStartFrame = i;
          currentNoteCents.clear();
          currentNoteCents.add(cents);
        } else {
          // Check pitch jump from running median
          final runningMedian = _median(currentNoteCents);
          final diffSemitones = (cents - runningMedian).abs() / 100.0;

          if (diffSemitones > pitchThresholdSemitones) {
            // End current note and start new note
            _addNoteIfValid(rawNotes, noteStartFrame, i, currentNoteCents);
            noteStartFrame = i;
            currentNoteCents.clear();
          }
          currentNoteCents.add(cents);
        }
      } else {
        if (inNote) {
          _addNoteIfValid(rawNotes, noteStartFrame, i, currentNoteCents);
          inNote = false;
          currentNoteCents.clear();
        }
      }
    }

    if (inNote && currentNoteCents.isNotEmpty) {
      _addNoteIfValid(
        rawNotes,
        noteStartFrame,
        f0CentsMidi.length,
        currentNoteCents,
      );
    }

    // Merge notes with tiny gaps (< 30ms) and same pitch class
    return _mergeAdjacentNotes(rawNotes);
  }

  void _addNoteIfValid(
    List<SegmentedNote> notes,
    int startFrame,
    int endFrame,
    List<int> centsList,
  ) {
    final durationMs = (endFrame - startFrame) * frameDurationMs;
    if (durationMs < minDurationMs || centsList.isEmpty) return;

    final medianCents = _median(centsList);
    final medianSemitones = medianCents / 100.0;

    // Variance calculation for stability score
    var variance = 0.0;
    for (final c in centsList) {
      final diff = (c - medianCents) / 100.0;
      variance += diff * diff;
    }
    final stdDev = math.sqrt(variance / centsList.length);
    final stability = 1.0 / (1.0 + stdDev);

    // Natural vibrato measurement on sustained notes (>= 300ms)
    var vibHz = 0.0;
    var vibDepth = 0.0;
    if (durationMs >= 300 && centsList.length >= 15) {
      final vibMetrics = _measureVibrato(centsList);
      vibHz = vibMetrics.$1;
      vibDepth = vibMetrics.$2;
    }

    notes.add(
      SegmentedNote(
        startMs: startFrame * frameDurationMs,
        endMs: endFrame * frameDurationMs,
        medianSemitones: medianSemitones,
        stabilityScore: stability.clamp(0.0, 1.0),
        rawF0Frames: List<int>.from(centsList),
        vibratoHz: vibHz,
        vibratoDepthCents: vibDepth,
      ),
    );
  }

  (double, double) _measureVibrato(List<int> centsList) {
    // Subtract linear trend
    final n = centsList.length;
    final detrended = Float64List(n);
    final mean = centsList.reduce((a, b) => a + b) / n;
    for (var i = 0; i < n; i++) {
      detrended[i] = (centsList[i] - mean).toDouble();
    }

    // Zero crossings to estimate vibrato frequency
    var zcCount = 0;
    for (var i = 1; i < n; i++) {
      if ((detrended[i] >= 0 && detrended[i - 1] < 0) ||
          (detrended[i] < 0 && detrended[i - 1] >= 0)) {
        zcCount++;
      }
    }

    final durationSec = (n * frameDurationMs) / 1000.0;
    final rateHz = (zcCount / 2.0) / durationSec;

    // Vibrato typically falls in 4.0 .. 8.0 Hz band
    if (rateHz >= 3.8 && rateHz <= 8.5) {
      // Peak-to-peak amplitude
      var minVal = double.infinity;
      var maxVal = -double.infinity;
      for (final v in detrended) {
        if (v < minVal) minVal = v;
        if (v > maxVal) maxVal = v;
      }
      final depthCents = (maxVal - minVal).clamp(0.0, 150.0);
      return (rateHz, depthCents);
    }

    return (0.0, 0.0);
  }

  List<SegmentedNote> _mergeAdjacentNotes(List<SegmentedNote> notes) {
    if (notes.length <= 1) return notes;
    final merged = <SegmentedNote>[notes.first];

    for (var i = 1; i < notes.length; i++) {
      final prev = merged.last;
      final curr = notes[i];
      final gapMs = curr.startMs - prev.endMs;

      final semitoneDiff = (curr.medianSemitones - prev.medianSemitones).abs();
      if (gapMs <= minGapMergeMs && semitoneDiff < 0.4) {
        // Merge into prev
        final combinedFrames = [...prev.rawF0Frames, ...curr.rawF0Frames];
        final combinedMedian = _median(combinedFrames) / 100.0;
        merged[merged.length - 1] = SegmentedNote(
          startMs: prev.startMs,
          endMs: curr.endMs,
          medianSemitones: combinedMedian,
          stabilityScore: (prev.stabilityScore + curr.stabilityScore) / 2.0,
          rawF0Frames: combinedFrames,
          vibratoHz: curr.vibratoHz > 0 ? curr.vibratoHz : prev.vibratoHz,
          vibratoDepthCents: math.max(
            prev.vibratoDepthCents,
            curr.vibratoDepthCents,
          ),
        );
      } else {
        merged.add(curr);
      }
    }

    return merged;
  }

  int _median(List<int> list) {
    if (list.isEmpty) return 0;
    final sorted = List<int>.from(list)..sort();
    return sorted[sorted.length ~/ 2];
  }
}
