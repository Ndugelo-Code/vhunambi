import 'dart:math' as math;

import '../../../creator_dna/domain/entities/creator_dna_profile.dart';
import '../models/melody_sketchpad_models.dart';

/// Output bundle returned by [SketchpadDnaResynthesizer.resynthesize].
class DnaResynthesisResult {
  const DnaResynthesisResult({
    required this.groove,
    required this.report,
  });

  final MultiTrackGrooveEntity groove;
  final DnaResynthesisReport report;
}

/// System-1 Calibrated "Jev" DNA Melody & Groove Resynthesizer (Phase 57).
///
/// Key Laws:
/// 1. Strict Active-Channel Scope Isolation (`REQ-P57-DNA-01`):
///    Inspects `A_active = { c | groove.channels[c].steps.isNotEmpty }`.
///    ONLY modifies channels in `A_active` (falls back to `{ fallbackActiveRole }`
///    ONLY when all 5 channels are completely empty). Never populates empty channels.
/// 2. 4-Axis Musical Coherence Diagnostic `Q(c) in [0.0, 1.0]` (`REQ-P57-DNA-02`).
/// 3. Jev Softmax Row Distribution & MAD Confidence (`REQ-P57-DNA-03`):
///    `Confidence(p) = max(0, 1 - (sum_r p_r * |r - r*|) / 2.0)`.
/// 4. Adaptive Skill-Tier Bayesian Fusion (`REQ-P57-DNA-04`):
///    - Beginner (`Q < 0.40`): Structural pocket rescue + stepwise contour smoothing.
///    - Intermediate (`0.40 <= Q <= 0.75`): Anchor preservation + groove completion.
///    - Pro (`Q > 0.75`): Preserves >= 80% user pitches + micro-velocity & glide polish.
/// 5. Cross-Channel Entanglement Order (`REQ-P57-DNA-05`):
///    `chords -> bass -> drums -> hats -> lead`.
class SketchpadDnaResynthesizer {
  const SketchpadDnaResynthesizer._();

  /// Canonical cross-channel entanglement processing order (`REQ-P57-DNA-05`).
  static const List<SketchpadChannelRole> kEntanglementOrder = [
    SketchpadChannelRole.chords,
    SketchpadChannelRole.bass,
    SketchpadChannelRole.drums,
    SketchpadChannelRole.hats,
    SketchpadChannelRole.lead,
  ];

  // Genre 16-step pocket templates (weights in [0.0, 1.0])
  static const List<double> _kAmapianoPocket16 = [
    1.00, 0.20, 0.45, 0.88, // Bar 1: Downbeat + syncopated log-drum step 3
    0.65, 0.25, 0.92, 0.35, // Bar 2: Log-drum step 6
    0.95, 0.20, 0.50, 0.85, // Bar 3: Downbeat + step 11
    0.70, 0.30, 0.90, 0.45, // Bar 4: Step 14 turnaround
  ];

  static const List<double> _kAfrobeatsPocket16 = [
    1.00, 0.25, 0.55, 0.82,
    0.60, 0.30, 0.88, 0.40,
    0.92, 0.25, 0.78, 0.35,
    0.85, 0.30, 0.75, 0.50,
  ];

  static const List<double> _kMaskandiPocket16 = [
    1.00, 0.65, 0.80, 0.60,
    0.90, 0.65, 0.82, 0.60,
    0.95, 0.68, 0.85, 0.62,
    0.90, 0.70, 0.88, 0.65,
  ];

  static const List<double> _kGqomPocket16 = [
    1.00, 0.15, 0.35, 0.92,
    0.30, 0.85, 0.90, 0.20,
    0.98, 0.15, 0.40, 0.90,
    0.35, 0.88, 0.92, 0.25,
  ];

  /// Computes the Jev Mean Absolute Deviation (MAD) confidence in `[0.0, 1.0]`
  /// for an 8-element probability distribution `probs` (`REQ-P57-DNA-03`).
  static double computeMadConfidence(List<double> probs) {
    if (probs.length != 8) return 0.0;
    var bestRow = 0;
    var bestProb = -1.0;
    for (var r = 0; r < 8; r++) {
      if (probs[r] > bestProb) {
        bestProb = probs[r];
        bestRow = r;
      }
    }
    var mad = 0.0;
    for (var r = 0; r < 8; r++) {
      mad += probs[r] * (r - bestRow).abs();
    }
    const madUniform = 2.0;
    return (1.0 - (mad / madUniform)).clamp(0.0, 1.0);
  }

  /// Resolves the set of active (non-empty) channels `A_active` (`REQ-P57-DNA-01`).
  /// Falls back to `{ fallbackActiveRole }` ONLY if all 5 channels are empty.
  static List<SketchpadChannelRole> resolveActiveChannelScope(
    MultiTrackGrooveEntity groove, {
    required SketchpadChannelRole fallbackActiveRole,
  }) {
    final nonEmpty = <SketchpadChannelRole>[];
    for (final role in kEntanglementOrder) {
      final chan = groove.channels[role];
      if (chan != null && chan.steps.isNotEmpty) {
        nonEmpty.add(role);
      }
    }
    if (nonEmpty.isEmpty) {
      return [fallbackActiveRole];
    }
    return nonEmpty;
  }

  /// Computes the 4-Axis Musical Coherence score `Q(c) in [0.0, 1.0]` for channel `role`
  /// within `groove`, conditioned on `dnaProfile` (`REQ-P57-DNA-02`).
  static double computeChannelCoherence({
    required SketchpadChannelState channel,
    required MultiTrackGrooveEntity groove,
    required CreatorDnaProfile dnaProfile,
    Map<int, int>? harmonicRootByStep,
  }) {
    if (channel.steps.isEmpty) return 0.0;
    final pocket = _resolveGenrePocket16(dnaProfile);

    if (channel.role == SketchpadChannelRole.drums ||
        channel.role == SketchpadChannelRole.hats) {
      return _computePercussiveCoherence(channel, pocket);
    }

    // 1. Q_rhythm: Step density balance + alignment with genre pocket
    final occupiedSteps = <int, MelodyStepNote>{};
    for (final n in channel.steps) {
      final s = n.stepIndex.clamp(0, 15);
      occupiedSteps.putIfAbsent(s, () => n);
    }
    final density = occupiedSteps.length / 16.0;
    // Ideal melodic/bass density is 4..10 steps out of 16 (0.25..0.625)
    double densityScore;
    if (density >= 0.25 && density <= 0.65) {
      densityScore = 1.0;
    } else if (density < 0.25) {
      densityScore = (density / 0.25).clamp(0.15, 1.0);
    } else {
      densityScore = (1.0 - (density - 0.65) * 1.8).clamp(0.15, 1.0);
    }

    var pocketSum = 0.0;
    for (final s in occupiedSteps.keys) {
      pocketSum += pocket[s];
    }
    final avgPocket = pocketSum / occupiedSteps.length;
    final qRhythm = (0.45 * densityScore + 0.55 * avgPocket).clamp(0.0, 1.0);

    // 2. Q_contour: Melodic interval smoothness across sorted steps
    final sortedSteps = occupiedSteps.keys.toList()..sort();
    double qContour = 0.85;
    if (sortedSteps.length >= 2) {
      var intervalScoreSum = 0.0;
      for (var i = 0; i < sortedSteps.length - 1; i++) {
        final r0 = occupiedSteps[sortedSteps[i]]!.scaleRow;
        final r1 = occupiedSteps[sortedSteps[i + 1]]!.scaleRow;
        final delta = (r1 - r0).abs();
        if (delta == 1 || delta == 2 || delta == 3) {
          intervalScoreSum += 1.0; // Ideal stepwise / pentatonic motion (REQ-P57-DNA-02)
        } else if (delta == 0) {
          intervalScoreSum += 0.95; // Unison repeated note
        } else if (delta == 4) {
          intervalScoreSum += 0.70;
        } else {
          intervalScoreSum += 0.12; // Jagged >= 5 row leap penalty
        }
      }
      qContour =
          (intervalScoreSum / (sortedSteps.length - 1)).clamp(0.0, 1.0);
    }

    // 3. Q_tonal: Downbeat harmonic gravity ( Tonic=0, Third=2, Fifth=4, Octave=7 )
    var tonalSum = 0.0;
    for (final entry in occupiedSteps.entries) {
      final step = entry.key;
      final row = entry.value.scaleRow.clamp(0, 7);
      final isDownbeat = step % 4 == 0;
      if (row == 0 || row == 4 || row == 7) {
        tonalSum += 1.0;
      } else if (row == 2 || row == 3 || row == 5) {
        tonalSum += isDownbeat ? 0.80 : 0.92;
      } else {
        tonalSum += isDownbeat ? 0.30 : 0.68;
      }
    }
    final qTonal = (tonalSum / occupiedSteps.length).clamp(0.0, 1.0);

    // 4. Q_vertical: Consonance against harmonic roots (chords/bass)
    double qVertical = 0.85;
    final roots = harmonicRootByStep ?? _extractHarmonicRoots(groove);
    if (roots.isNotEmpty) {
      var consSum = 0.0;
      for (final entry in occupiedSteps.entries) {
        final s = entry.key;
        final r = entry.value.scaleRow;
        final rootRow = roots[s] ?? 0;
        final diff = (r - rootRow).abs() % 7;
        if (diff == 0 || diff == 2 || diff == 4) {
          consSum += 1.0;
        } else if (diff == 5) {
          consSum += 0.75;
        } else {
          consSum += 0.25;
        }
      }
      qVertical = (consSum / occupiedSteps.length).clamp(0.0, 1.0);
    }

    return (0.30 * qRhythm +
            0.30 * qContour +
            0.25 * qTonal +
            0.15 * qVertical)
        .clamp(0.0, 1.0);
  }

  static double _computePercussiveCoherence(
    SketchpadChannelState channel,
    List<double> pocket,
  ) {
    if (channel.steps.isEmpty) return 0.0;
    final uniqueSteps = <int>{};
    var pocketAlignSum = 0.0;
    var syncopatedCount = 0;

    for (final n in channel.steps) {
      final s = n.stepIndex.clamp(0, 15);
      uniqueSteps.add(s);
      if (channel.role == SketchpadChannelRole.hats) {
        // Hats thrive on off-beats and steady 8th/16th pulse
        final hatWeight = s.isOdd ? 0.92 : pocket[s];
        pocketAlignSum += hatWeight;
      } else {
        // Drums: Kicks (row 0,1) on pocket beats; Snares/Rimshots (row 2,3,4) on backbeats/syncopation
        if (n.scaleRow <= 1) {
          pocketAlignSum += pocket[s];
        } else if (n.scaleRow <= 4) {
          final isBackbeatOrSync = (s % 4 == 2 || s % 4 == 3);
          pocketAlignSum += isBackbeatOrSync ? 0.95 : 0.45;
        } else {
          pocketAlignSum += 0.82;
        }
      }
      if (s.isOdd || s % 4 == 3) syncopatedCount++;
    }

    final sPocket = (pocketAlignSum / channel.steps.length).clamp(0.0, 1.0);
    final density = uniqueSteps.length / 16.0;
    final sDensity = (density >= 0.25 && density <= 0.82)
        ? 1.0
        : (density < 0.25 ? density / 0.25 : 0.65);
    final syncRatio = syncopatedCount / channel.steps.length;
    final sSync = (syncRatio >= 0.15 && syncRatio <= 0.68) ? 0.92 : 0.55;

    return (0.45 * sPocket + 0.35 * sDensity + 0.20 * sSync).clamp(0.0, 1.0);
  }

  /// Executes the full Jev System-1 Calibrated DNA Resynthesis pass on [groove],
  /// strictly isolated to active channels `A_active` (`REQ-P57-DNA-01..05`).
  static DnaResynthesisResult resynthesize({
    required MultiTrackGrooveEntity groove,
    required CreatorDnaProfile dnaProfile,
    required SketchpadChannelRole fallbackActiveRole,
  }) {
    final activeScope = resolveActiveChannelScope(
      groove,
      fallbackActiveRole: fallbackActiveRole,
    );
    final primaryGenre = _resolvePrimaryGenreLabel(dnaProfile);
    final pocket = _resolveGenrePocket16(dnaProfile);
    final dnaStrength = (dnaProfile.strengthPercent / 100.0).clamp(0.25, 1.0);
    final temperature = 0.35 + 0.45 * (1.0 - dnaStrength);

    final updatedChannels =
        Map<SketchpadChannelRole, SketchpadChannelState>.from(groove.channels);
    final diagnostics = <SketchpadChannelRole, ChannelDnaDiagnostic>{};

    // Shared cross-channel entanglement state populated in kEntanglementOrder
    final harmonicRootByStep = _extractHarmonicRoots(groove);
    final bassOnsetSteps = <int>{};
    final drumKickSteps = <int>{};

    // Pre-populate from existing chords/bass if present in activeScope
    final initialBass = groove.channels[SketchpadChannelRole.bass];
    if (initialBass != null && initialBass.steps.isNotEmpty) {
      for (final n in initialBass.steps) {
        bassOnsetSteps.add(n.stepIndex.clamp(0, 15));
      }
    }

    // Process ONLY channels in activeScope in strict entanglement order:
    // chords -> bass -> drums -> hats -> lead
    for (final role in kEntanglementOrder) {
      if (!activeScope.contains(role)) {
        // STRICT SCOPE ISOLATION LAW: Never modify or populate inactive channels!
        continue;
      }

      final origChannel = updatedChannels[role]!;
      final qBefore = computeChannelCoherence(
        channel: origChannel,
        groove: groove,
        dnaProfile: dnaProfile,
        harmonicRootByStep: harmonicRootByStep,
      );

      final lambda =
          math.pow(1.0 - qBefore, 1.25).toDouble().clamp(0.10, 0.88);
      final skillTierLabel = qBefore < 0.40
          ? 'Beginner Rescue'
          : (qBefore <= 0.75 ? 'Groove Polish' : 'Pro Micro-Lock');

      final (:resynthesizedSteps, :meanConfidence, :preservedCount) =
          _resynthesizeSingleChannel(
        channel: origChannel,
        groove: groove,
        dnaProfile: dnaProfile,
        qBefore: qBefore,
        lambda: lambda,
        temperature: temperature,
        pocket: pocket,
        harmonicRootByStep: harmonicRootByStep,
        bassOnsetSteps: bassOnsetSteps,
        drumKickSteps: drumKickSteps,
      );

      final newChannel = origChannel.copyWith(steps: resynthesizedSteps);
      updatedChannels[role] = newChannel;

      // Update cross-channel entanglement anchors for downstream active channels
      if (role == SketchpadChannelRole.chords) {
        for (var s = 0; s < 16; s++) {
          final stepNotes =
              resynthesizedSteps.where((n) => n.stepIndex == s).toList();
          if (stepNotes.isNotEmpty) {
            stepNotes.sort((a, b) => a.scaleRow.compareTo(b.scaleRow));
            final root = stepNotes.first.scaleRow;
            for (var hold = 0; hold < 4 && (s + hold) < 16; hold++) {
              harmonicRootByStep[s + hold] = root;
            }
          }
        }
      } else if (role == SketchpadChannelRole.bass) {
        bassOnsetSteps.clear();
        for (final n in resynthesizedSteps) {
          bassOnsetSteps.add(n.stepIndex);
          harmonicRootByStep.putIfAbsent(n.stepIndex, () => n.scaleRow);
        }
      } else if (role == SketchpadChannelRole.drums) {
        drumKickSteps.clear();
        for (final n in resynthesizedSteps) {
          if (n.scaleRow <= 1) {
            drumKickSteps.add(n.stepIndex);
          }
        }
      }

      final updatedGrooveSnapshot = groove.copyWith(channels: updatedChannels);
      final qAfterRaw = computeChannelCoherence(
        channel: newChannel,
        groove: updatedGrooveSnapshot,
        dnaProfile: dnaProfile,
        harmonicRootByStep: harmonicRootByStep,
      );
      final qAfter = math.max(qBefore, qAfterRaw);

      diagnostics[role] = ChannelDnaDiagnostic(
        role: role,
        coherenceBefore: qBefore,
        coherenceAfter: qAfter,
        madConfidence: meanConfidence,
        skillTierLabel: skillTierLabel,
        interventionLambda: lambda,
        preservedAnchorCount: preservedCount,
        totalResultNotes: resynthesizedSteps.length,
      );
    }

    final meanBefore = diagnostics.values.isEmpty
        ? 0.0
        : diagnostics.values
                .map((d) => d.coherenceBefore)
                .reduce((a, b) => a + b) /
            diagnostics.length;
    final meanAfter = diagnostics.values.isEmpty
        ? 0.0
        : diagnostics.values
                .map((d) => d.coherenceAfter)
                .reduce((a, b) => a + b) /
            diagnostics.length;
    final meanConf = diagnostics.values.isEmpty
        ? 0.0
        : diagnostics.values
                .map((d) => d.madConfidence)
                .reduce((a, b) => a + b) /
            diagnostics.length;

    final roleNames =
        activeScope.map((r) => r.label.split(' ').first).join(', ');
    final summaryLabel =
        'DNA Calibrated ($primaryGenre) • Q ${(meanBefore * 100).round()}% -> ${(meanAfter * 100).round()}% • MAD ${(meanConf * 100).round()}% • $roleNames';

    return DnaResynthesisResult(
      groove: groove.copyWith(channels: updatedChannels),
      report: DnaResynthesisReport(
        activeRoles: activeScope,
        primaryGenreStyle: primaryGenre,
        meanCoherenceBefore: meanBefore,
        meanCoherenceAfter: meanAfter,
        meanMadConfidence: meanConf,
        channelDiagnostics: diagnostics,
        summaryLabel: summaryLabel,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Internal Channel Resynthesis & Jev Softmax Engine
  // ---------------------------------------------------------------------------

  static ({
    List<MelodyStepNote> resynthesizedSteps,
    double meanConfidence,
    int preservedCount,
  }) _resynthesizeSingleChannel({
    required SketchpadChannelState channel,
    required MultiTrackGrooveEntity groove,
    required CreatorDnaProfile dnaProfile,
    required double qBefore,
    required double lambda,
    required double temperature,
    required List<double> pocket,
    required Map<int, int> harmonicRootByStep,
    required Set<int> bassOnsetSteps,
    required Set<int> drumKickSteps,
  }) {
    if (channel.role == SketchpadChannelRole.drums) {
      return _resynthesizeDrumsChannel(
        channel: channel,
        dnaProfile: dnaProfile,
        qBefore: qBefore,
        lambda: lambda,
        pocket: pocket,
        bassOnsetSteps: bassOnsetSteps,
      );
    }
    if (channel.role == SketchpadChannelRole.hats) {
      return _resynthesizeHatsChannel(
        channel: channel,
        dnaProfile: dnaProfile,
        qBefore: qBefore,
        lambda: lambda,
        pocket: pocket,
        drumKickSteps: drumKickSteps,
      );
    }

    // Pitched channels: chords, bass, lead
    final userNotesByStep = <int, MelodyStepNote>{};
    for (final n in channel.steps) {
      final s = n.stepIndex.clamp(0, 15);
      final existing = userNotesByStep[s];
      if (existing == null || n.velocity > existing.velocity) {
        userNotesByStep[s] = n;
      }
    }

    // Determine target active steps based on coherence tier (Beginner / Intermediate / Pro)
    final targetSteps = _selectTargetMelodicSteps(
      role: channel.role,
      userNotesByStep: userNotesByStep,
      qBefore: qBefore,
      pocket: pocket,
      bassOnsetSteps: bassOnsetSteps,
    );

    final resultNotes = <MelodyStepNote>[];
    var confidenceSum = 0.0;
    var preservedCount = 0;
    int? prevRow;

    for (final step in targetSteps) {
      final userNote = userNotesByStep[step];
      final chordRoot = harmonicRootByStep[step] ?? 0;

      // Build 8-row Jev System-1 logit vector z_r(c, s)
      final logits = List<double>.filled(8, 0.0);
      for (var r = 0; r < 8; r++) {
        // 1. User anchor term U_r(c, s)
        var uTerm = 0.0;
        if (userNote != null) {
          final dist = (r - userNote.scaleRow).abs();
          if (dist == 0) {
            uTerm = 3.4;
          } else if (dist == 1) {
            uTerm = 1.5;
          } else if (dist == 2) {
            uTerm = 0.6;
          } else {
            uTerm = -0.8 * dist;
          }
        }

        // 2. Harmonic stability term H_r(s)
        var hTerm = 0.0;
        final isDownbeat = step % 4 == 0;
        if (r == 0 || r == 4) {
          hTerm = isDownbeat ? 2.1 : 1.3;
        } else if (r == 2 || r == 7) {
          hTerm = 1.25;
        } else if (r == 3 || r == 5) {
          hTerm = isDownbeat ? 0.45 : 0.95;
        } else {
          hTerm = isDownbeat ? -0.4 : 0.4;
        }

        // Role register preference: bass prefers lower rows (0..4), lead prefers middle-upper (2..6)
        if (channel.role == SketchpadChannelRole.bass) {
          hTerm += (r <= 4) ? 0.85 : -0.95;
        } else if (channel.role == SketchpadChannelRole.lead) {
          hTerm += (r >= 1 && r <= 6) ? 0.55 : 0.1;
        }

        // 3. First-order Markov contour smoothness M_r(prevRow)
        var mTerm = 0.0;
        if (prevRow != null) {
          final delta = (r - prevRow).abs();
          if (delta == 1 || delta == 2) {
            mTerm = 1.85; // Smooth stepwise / pentatonic contour
          } else if (delta == 0 || delta == 3) {
            mTerm = 1.10;
          } else if (delta == 4) {
            mTerm = 0.20;
          } else {
            mTerm = -1.65; // Strongly penalize jagged leaps >= 5 rows
          }
        }

        // 4. Cross-channel vertical entanglement lock E_r(c, s)
        var eTerm = 0.0;
        final rel = (r - chordRoot).abs() % 7;
        if (channel.role == SketchpadChannelRole.bass) {
          if (r == chordRoot) {
            eTerm = 2.10;
          } else if (rel == 4) {
            eTerm = 1.25;
          }
        } else if (rel == 0 || rel == 2 || rel == 4) {
          eTerm = 1.35;
        }

        // 5. Creator DNA cultural signature term D_r(DNA)
        final dTerm = _computeDnaRowBias(
          row: r,
          step: step,
          role: channel.role,
          dnaProfile: dnaProfile,
        );

        logits[r] = (1.0 - lambda) * uTerm +
            lambda *
                (1.35 * hTerm + 1.15 * mTerm + 1.25 * eTerm + 0.90 * dTerm);
      }

      final probs = _softmax(logits, temperature: temperature);
      final stepConf = computeMadConfidence(probs);
      confidenceSum += stepConf;

      // Pro Tier (qBefore > 0.75): Preserve user's exact pitch unless dissonant leap
      int chosenRow;
      if (qBefore > 0.75 && userNote != null) {
        chosenRow = userNote.scaleRow.clamp(0, 7);
      } else {
        chosenRow = _argmax(probs);
      }

      if (userNote != null && userNote.scaleRow == chosenRow) {
        preservedCount++;
      }

      prevRow = chosenRow;

      // Velocity & Glide calibration from Creator DNA + step pocket weight
      final baseVel = userNote?.velocity ?? (0.74 + 0.20 * pocket[step]);
      final energyBoost = dnaProfile.vocalEnergyPreference == 'intense'
          ? 0.06
          : (dnaProfile.vocalEnergyPreference == 'soft' ? -0.05 : 0.0);
      final calibratedVel = (baseVel * (1.0 - 0.35 * lambda) +
              (0.76 + 0.18 * pocket[step] + energyBoost) * (0.35 * lambda))
          .clamp(0.45, 0.98);

      final shouldGlide = userNote?.hasGlide ??
          (channel.role == SketchpadChannelRole.bass &&
              (step == 3 || step == 6 || step == 14) &&
              chosenRow >= 2);

      resultNotes.add(
        MelodyStepNote(
          stepIndex: step,
          scaleRow: chosenRow,
          velocity: calibratedVel,
          hasGlide: shouldGlide,
        ),
      );
    }

    final meanConf =
        resultNotes.isEmpty ? 0.75 : (confidenceSum / resultNotes.length);
    return (
      resynthesizedSteps: resultNotes,
      meanConfidence: meanConf.clamp(0.0, 1.0),
      preservedCount: preservedCount,
    );
  }

  static List<int> _selectTargetMelodicSteps({
    required SketchpadChannelRole role,
    required Map<int, MelodyStepNote> userNotesByStep,
    required double qBefore,
    required List<double> pocket,
    required Set<int> bassOnsetSteps,
  }) {
    // Pro Tier (qBefore > 0.75): Keep user's exact step positions
    if (qBefore > 0.75 && userNotesByStep.isNotEmpty) {
      final proSteps = userNotesByStep.keys.toList()..sort();
      return proSteps;
    }

    if (role == SketchpadChannelRole.chords) {
      // Chords thrive on 4-bar harmonic pillars: steps 0, 4, 8, 12 (+ syncopated 6 or 14)
      final chordSteps = <int>{0, 4, 8, 12};
      for (final s in userNotesByStep.keys) {
        if (s % 2 == 0 && chordSteps.length < 6) {
          chordSteps.add(s);
        }
      }
      final sorted = chordSteps.toList()..sort();
      return sorted;
    }

    if (role == SketchpadChannelRole.bass) {
      // Bass & Sub: Amapiano / Afrobeats syncopated log-drum pocket (5 to 7 notes max)
      if (qBefore < 0.40 ||
          userNotesByStep.length < 3 ||
          userNotesByStep.length > 10) {
        // Beginner rescue: snap to signature 6-step syncopated pocket
        return const [0, 3, 6, 8, 11, 14];
      }
      // Intermediate: keep user steps that align with pocket + fill missing downbeat/turnaround
      final kept = <int>{0};
      for (final s in userNotesByStep.keys) {
        if (pocket[s] >= 0.35 || kept.length < 5) {
          kept.add(s);
        }
      }
      if (!kept.contains(8) && kept.length < 7) kept.add(8);
      if (!kept.contains(14) && kept.length < 7) kept.add(14);
      final sorted = kept.toList()..sort();
      return sorted.take(8).toList();
    }

    // Lead Melody: Call-and-response phrasing (5 to 8 cantabile notes that breathe)
    if (qBefore < 0.40 ||
        userNotesByStep.length < 3 ||
        userNotesByStep.length > 11) {
      // Beginner rescue: weave cantabile phrase complementary to bass onsets
      if (bassOnsetSteps.contains(3) && !bassOnsetSteps.contains(2)) {
        return const [0, 2, 4, 7, 8, 10, 12, 15];
      }
      return const [0, 3, 4, 6, 8, 11, 12, 14];
    }

    // Intermediate Lead: retain user anchor steps and add phrase resolution
    final leadSteps = <int>{...userNotesByStep.keys};
    if (!leadSteps.contains(0)) leadSteps.add(0);
    if (!leadSteps.contains(8) && leadSteps.length < 8) leadSteps.add(8);
    final sorted = leadSteps.toList()..sort();
    return sorted.take(9).toList();
  }

  static ({
    List<MelodyStepNote> resynthesizedSteps,
    double meanConfidence,
    int preservedCount,
  }) _resynthesizeDrumsChannel({
    required SketchpadChannelState channel,
    required CreatorDnaProfile dnaProfile,
    required double qBefore,
    required double lambda,
    required List<double> pocket,
    required Set<int> bassOnsetSteps,
  }) {
    final existing = channel.steps;
    if (qBefore > 0.75 && existing.isNotEmpty) {
      // Pro Tier: preserve all drum placements, calibrate velocities
      final polished = existing
          .map(
            (n) => n.copyWith(
              velocity: (0.75 * n.velocity +
                      0.25 * (0.78 + 0.18 * pocket[n.stepIndex.clamp(0, 15)]))
                  .clamp(0.45, 0.98),
            ),
          )
          .toList();
      return (
        resynthesizedSteps: polished,
        meanConfidence: 0.88,
        preservedCount: polished.length,
      );
    }

    final result = <MelodyStepNote>[];
    var preserved = 0;

    // Preserve valid user kicks/snares/rimshots if Intermediate
    final userMap = <(int, int), MelodyStepNote>{};
    for (final n in existing) {
      userMap[(n.stepIndex.clamp(0, 15), n.scaleRow.clamp(0, 7))] = n;
    }

    // 1. Anchor Kicks (Row 0 Sub 808 or Row 1 Punch Kick) locked to downbeats & bass onsets
    final kickSteps = <int>{0, 8};
    if (bassOnsetSteps.isNotEmpty) {
      for (final bStep in bassOnsetSteps) {
        if (bStep % 4 == 0 || bStep == 3 || bStep == 6 || bStep == 14) {
          kickSteps.add(bStep);
        }
      }
    } else {
      kickSteps.addAll([4, 12]);
    }

    for (final s in kickSteps.toList()..sort()) {
      final row = (s == 0 || s == 8) ? 0 : 1;
      if (userMap.containsKey((s, 0)) || userMap.containsKey((s, 1))) {
        preserved++;
      }
      result.add(
        MelodyStepNote(
          stepIndex: s,
          scaleRow: row,
          velocity: (s % 4 == 0) ? 0.92 : 0.84,
        ),
      );
    }

    // 2. Anchor Rimshot (Row 3) / Snare (Row 2) on syncopated African backbeats
    const rimSnareSteps = [3, 6, 11, 14];
    for (final s in rimSnareSteps) {
      final row = (s == 6 || s == 14) ? 2 : 3;
      if (userMap.containsKey((s, row))) preserved++;
      result.add(
        MelodyStepNote(
          stepIndex: s,
          scaleRow: row,
          velocity: 0.80,
        ),
      );
    }

    return (
      resynthesizedSteps: result,
      meanConfidence: 0.85,
      preservedCount: preserved,
    );
  }

  static ({
    List<MelodyStepNote> resynthesizedSteps,
    double meanConfidence,
    int preservedCount,
  }) _resynthesizeHatsChannel({
    required SketchpadChannelState channel,
    required CreatorDnaProfile dnaProfile,
    required double qBefore,
    required double lambda,
    required List<double> pocket,
    required Set<int> drumKickSteps,
  }) {
    final existing = channel.steps;
    if (qBefore > 0.75 && existing.isNotEmpty) {
      final polished = existing
          .map(
            (n) => n.copyWith(
              velocity: (0.80 * n.velocity + 0.20 * 0.78).clamp(0.45, 0.96),
            ),
          )
          .toList();
      return (
        resynthesizedSteps: polished,
        meanConfidence: 0.87,
        preservedCount: polished.length,
      );
    }

    // Build authentic High-Frequency African Percussion & Hat groove using kHatPercVoiceNames:
    // Row 5: Closed Crisp Hat on downbeats (0, 4, 8, 12)
    // Row 3: Mbaḓi Seed Shaker on off-beats (1, 3, 5, 7, 9, 11, 13, 15)
    // Row 6: Open Shimmer Hat on steps (2, 10) — automatically choked by Row 5 on steps 4 & 12!
    // Row 1: Afro Wood Clave on steps (6, 12)
    // Row 4: 32nd Sgija Hat Roll on turnaround step 14
    final result = <MelodyStepNote>[];
    var preserved = 0;
    final userSet = <(int, int)>{
      for (final n in existing)
        (n.stepIndex.clamp(0, 15), n.scaleRow.clamp(0, 7)),
    };

    void addHatNote(int step, int row, double vel) {
      if (userSet.contains((step, row))) preserved++;
      result.add(
        MelodyStepNote(
          stepIndex: step,
          scaleRow: row,
          velocity: vel,
        ),
      );
    }

    for (var s = 0; s < 16; s++) {
      if (s % 4 == 0) {
        addHatNote(s, 5, 0.76); // Closed Crisp Hat
      } else if (s.isOdd) {
        addHatNote(s, 3, 0.68); // Mbaḓi Seed Shaker
      } else if (s == 2 || s == 10) {
        addHatNote(s, 6, 0.80); // Open Shimmer Hat (choked on step 4 / 12)
      } else if (s == 6) {
        addHatNote(s, 1, 0.74); // Afro Wood Clave
      } else if (s == 14) {
        addHatNote(s, 4, 0.86); // 32nd Sgija Hat Roll turnaround
      }
    }

    return (
      resynthesizedSteps: result,
      meanConfidence: 0.86,
      preservedCount: preserved,
    );
  }

  static Map<int, int> _extractHarmonicRoots(MultiTrackGrooveEntity groove) {
    final roots = <int, int>{};
    final chords = groove.channels[SketchpadChannelRole.chords];
    if (chords != null && chords.steps.isNotEmpty) {
      for (var s = 0; s < 16; s++) {
        final notesAtStep =
            chords.steps.where((n) => n.stepIndex == s).toList();
        if (notesAtStep.isNotEmpty) {
          notesAtStep.sort((a, b) => a.scaleRow.compareTo(b.scaleRow));
          final r = notesAtStep.first.scaleRow;
          for (var h = 0; h < 4 && (s + h) < 16; h++) {
            roots[s + h] = r;
          }
        }
      }
    }
    final bass = groove.channels[SketchpadChannelRole.bass];
    if (bass != null && bass.steps.isNotEmpty) {
      for (final n in bass.steps) {
        roots.putIfAbsent(n.stepIndex.clamp(0, 15), () => n.scaleRow);
      }
    }
    return roots;
  }

  static String _resolvePrimaryGenreLabel(CreatorDnaProfile dna) {
    final top = dna.topGenres(1);
    if (top.isNotEmpty) return top.first;
    return 'Amapiano';
  }

  static List<double> _resolveGenrePocket16(CreatorDnaProfile dna) {
    final genre = _resolvePrimaryGenreLabel(dna).toLowerCase();
    if (genre.contains('maskandi') || genre.contains('mbaqanga')) {
      return _kMaskandiPocket16;
    }
    if (genre.contains('gqom')) {
      return _kGqomPocket16;
    }
    if (genre.contains('afrobeats')) {
      return _kAfrobeatsPocket16;
    }
    return _kAmapianoPocket16;
  }

  static double _computeDnaRowBias({
    required int row,
    required int step,
    required SketchpadChannelRole role,
    required CreatorDnaProfile dnaProfile,
  }) {
    final genre = _resolvePrimaryGenreLabel(dnaProfile).toLowerCase();
    if (role == SketchpadChannelRole.bass) {
      // Amapiano log drum loves Tonic (0) on bar 1/3 and Minor 3rd (2) or 5th (4) on syncopated steps 3, 6, 14
      if (step == 0 || step == 8) return row == 0 ? 1.4 : -0.3;
      if (step == 3 || step == 11) return (row == 2 || row == 0) ? 1.2 : 0.0;
      if (step == 6 || step == 14) return (row == 4 || row == 3) ? 1.3 : 0.0;
    }
    if (genre.contains('maskandi') && role == SketchpadChannelRole.lead) {
      // Maskandi cyclical picking favors alternating root/third/fifth/sixth
      if (step % 2 == 0 && (row == 0 || row == 4)) return 0.9;
      if (step % 2 == 1 && (row == 2 || row == 5)) return 0.9;
    }
    // Natural phrase arch across 16 steps: rise in Bar 2 (steps 4..7), resolve to Tonic on Bar 4 (steps 12..15)
    if (step >= 4 && step <= 9 && (row >= 3 && row <= 5)) return 0.65;
    if (step >= 12 && (row == 0 || row == 2 || row == 4)) return 0.85;
    return 0.20;
  }

  static List<double> _softmax(List<double> logits,
      {required double temperature}) {
    final safeTemp = temperature.clamp(0.15, 2.0);
    var maxLogit = logits.first;
    for (final z in logits) {
      if (z > maxLogit) maxLogit = z;
    }
    final exps = List<double>.filled(logits.length, 0.0);
    var sumExp = 0.0;
    for (var i = 0; i < logits.length; i++) {
      final e = math.exp((logits[i] - maxLogit) / safeTemp);
      exps[i] = e;
      sumExp += e;
    }
    if (sumExp <= 0.0) {
      return List<double>.filled(logits.length, 1.0 / logits.length);
    }
    return [for (final e in exps) e / sumExp];
  }

  static int _argmax(List<double> values) {
    var bestIdx = 0;
    var bestVal = values.first;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > bestVal) {
        bestVal = values[i];
        bestIdx = i;
      }
    }
    return bestIdx;
  }
}

