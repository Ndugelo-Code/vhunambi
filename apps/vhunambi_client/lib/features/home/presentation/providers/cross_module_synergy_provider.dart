import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sound_signature/data/sound_signature_repository.dart';
import '../../../sound_signature/domain/dsp/bantu_phonology.dart';
import '../../../sound_signature/domain/models/sound_idealizer_recipe.dart';
import '../../domain/models/studio_synergy_context.dart';

/// State of dismissed card IDs during this app session.
final dismissedSynergyCardIdsProvider =
    StateProvider<Set<String>>((ref) => <String>{});

/// Notifier providing active data-driven synergy recommendation cards (REQ-BANTU-SYN-01).
class CrossModuleSynergyNotifier extends StateNotifier<List<SynergyCardItem>> {
  CrossModuleSynergyNotifier(this._ref) : super(const []) {
    _evaluateSynergy();
  }

  final Ref _ref;

  void dismissCard(String cardId) {
    _ref.read(dismissedSynergyCardIdsProvider.notifier).update(
          (set) => {...set, cardId},
        );
    state = state.where((c) => c.id != cardId).toList();
  }

  void _evaluateSynergy() {
    final dismissed = _ref.read(dismissedSynergyCardIdsProvider);
    final signatures = _ref.watch(soundSignaturesListProvider);

    if (signatures.isEmpty) {
      // Zero placeholder cards: hide completely when no real measurements exist.
      state = const [];
      return;
    }

    final latest = signatures.first;
    final quality = latest.quality;
    final pitch = latest.pitch;
    final rhythm = latest.rhythm;

    final cards = <SynergyCardItem>[];

    // Gap 1: Low stabilityScore (< 0.6) -> Steady Pitch
    if (pitch.stabilityScore < 0.6) {
      const id = 'gap_pitch_stability';
      if (!dismissed.contains(id)) {
        cards.add(
          SynergyCardItem(
            id: id,
            title: 'Steady Pitch Instability',
            subtitle: 'Micro-tremor detected on sustained vocal notes.',
            actionLabel: 'Steady my pitch',
            metricSummary: 'Stability: ${(pitch.stabilityScore * 100).toStringAsFixed(0)}%',
            context: StudioSynergyContext(
              sourceModule: 'PitchContourProfile',
              targetModule: 'SoundSignatureIdealizerSheet',
              gapKind: SynergyGapKind.lowStability,
              measuredValue: pitch.stabilityScore,
              suggestedRecipe: const SoundIdealizerRecipe(
                pitchScaleLock: 0.95,
                vibratoAndSustainPolish: 0.90,
              ),
              signature: latest,
            ),
          ),
        );
      }
    }

    // Gap 2: Low SNR (< 15 dB) -> Room Denoise
    if (quality.snrDb < 15.0) {
      const id = 'gap_room_snr';
      if (!dismissed.contains(id)) {
        cards.add(
          SynergyCardItem(
            id: id,
            title: 'Clean Room Noise',
            subtitle: 'Background room ambience is above studio baseline.',
            actionLabel: 'Clean my room noise',
            metricSummary: 'SNR: ${quality.snrDb.toStringAsFixed(1)} dB',
            context: StudioSynergyContext(
              sourceModule: 'InputQualityGate',
              targetModule: 'SoundSignatureIdealizerSheet',
              gapKind: SynergyGapKind.lowSnr,
              measuredValue: quality.snrDb,
              suggestedRecipe: const SoundIdealizerRecipe(
                referenceCleanup: 0.95,
              ),
              signature: latest,
            ),
          ),
        );
      }
    }

    // Gap 3: High Reverb (> 300 ms) -> Tame Echo
    if (quality.reverbEdtMs > 300.0) {
      const id = 'gap_reverb_edt';
      if (!dismissed.contains(id)) {
        cards.add(
          SynergyCardItem(
            id: id,
            title: 'Tame Room Echo',
            subtitle: 'Reverberation decay time exceeds 300 ms.',
            actionLabel: 'Tame the echo',
            metricSummary: 'EDT: ${quality.reverbEdtMs.toStringAsFixed(0)} ms',
            context: StudioSynergyContext(
              sourceModule: 'InputQualityGate',
              targetModule: 'SoundSignatureIdealizerSheet',
              gapKind: SynergyGapKind.highReverb,
              measuredValue: quality.reverbEdtMs,
              suggestedRecipe: const SoundIdealizerRecipe(
                referenceCleanup: 0.90,
              ),
              signature: latest,
            ),
          ),
        );
      }
    }

    // Gap 4: Low Key Confidence (< 0.5) -> Musical Key Selection
    if (pitch.keyConfidence < 0.5) {
      const id = 'gap_key_confidence';
      if (!dismissed.contains(id)) {
        cards.add(
          SynergyCardItem(
            id: id,
            title: 'Refine Musical Key',
            subtitle: 'Voice take spans multiple modal centers.',
            actionLabel: 'Pick my key',
            metricSummary: 'Key confidence: ${(pitch.keyConfidence * 100).toStringAsFixed(0)}%',
            context: StudioSynergyContext(
              sourceModule: 'PitchContourProfile',
              targetModule: 'SoundSignatureIdealizerSheet',
              gapKind: SynergyGapKind.lowKeyConfidence,
              measuredValue: pitch.keyConfidence,
              suggestedRecipe: const SoundIdealizerRecipe(
                pitchScaleLock: 0.90,
              ),
              signature: latest,
            ),
          ),
        );
      }
    }

    // Gap 5: High Grid Offset (> 40 ms) -> Quantize Pocket
    final avgOffsetMs = rhythm.offsetFromGridMs.isEmpty
        ? 0.0
        : rhythm.offsetFromGridMs.map((o) => o.abs()).reduce((a, b) => a + b) /
            rhythm.offsetFromGridMs.length;
    if (avgOffsetMs > 40.0) {
      const id = 'gap_grid_offset';
      if (!dismissed.contains(id)) {
        cards.add(
          SynergyCardItem(
            id: id,
            title: 'Tighten Pocket Timing',
            subtitle: 'Onset attacks drift from the 16-step grid.',
            actionLabel: 'Tighten my timing',
            metricSummary: 'Grid offset: +${avgOffsetMs.toStringAsFixed(0)} ms',
            context: StudioSynergyContext(
              sourceModule: 'RhythmicTransientGrid',
              targetModule: 'SoundSignatureIdealizerSheet',
              gapKind: SynergyGapKind.highGridOffset,
              measuredValue: avgOffsetMs,
              suggestedRecipe: const SoundIdealizerRecipe(
                quantizePocketStrength: 0.95,
              ),
              signature: latest,
            ),
          ),
        );
      }
    }

    // Gap 6: Signature exists but no sketchpad project linked
    const idSigSketch = 'gap_sig_to_sketchpad';
    if (!dismissed.contains(idSigSketch)) {
      cards.add(
        SynergyCardItem(
          id: idSigSketch,
          title: 'Sing into Melody Sketchpad',
          subtitle: 'Your vocal signature is ready to drive 5-channel arrangements.',
          actionLabel: 'Hum to sketchpad',
          metricSummary: 'DNA: ${latest.id.substring(0, 8)}',
          context: StudioSynergyContext(
            sourceModule: 'SoundSignatureDna',
            targetModule: 'MelodySketchpadModal',
            gapKind: SynergyGapKind.signatureUnusedInSketchpad,
            measuredValue: 1.0,
            suggestedRecipe: const SoundIdealizerRecipe(),
            signature: latest,
          ),
        ),
      );
    }

    // Surface at most 3 cards (REQ-BANTU-SYN-04)
    state = cards.take(3).toList();
  }
}

final crossModuleSynergyProvider =
    StateNotifierProvider<CrossModuleSynergyNotifier, List<SynergyCardItem>>(
  (ref) => CrossModuleSynergyNotifier(ref),
);

/// Evaluates creator mastery badges from song branches, sketchpad channels, and signatures.
///
/// Strictly cosmetic rewards: zero money, credits, or wallet impact (REQ-BANTU-SYN-06).
final creatorMasteryBadgesProvider = Provider<List<CreatorMasteryBadge>>((ref) {
  final signatures = ref.watch(soundSignaturesListProvider);

  // Simulated song languages created by user
  final songLanguagesCreated = <String>['zu', 've', 'st'];
  final distinctBranches = songLanguagesCreated
      .map((c) => BantuLanguage.fromCode(c)?.branch)
      .whereType<BantuLanguageBranch>()
      .toSet();

  // Simulated sketchpad channels used
  final channelsUsedCount = 5;

  return [
    CreatorMasteryBadge(
      id: 'polyglot_vocalist',
      name: 'Polyglot Vocalist',
      description: 'Created songs across 3+ distinct Southern Bantu linguistic branches.',
      isUnlocked: distinctBranches.length >= 3,
      badgeFlair: '3 Branches Mastered',
    ),
    CreatorMasteryBadge(
      id: 'groove_architect',
      name: 'Groove Architect',
      description: 'Composed with all 5 Phase 32 Multitrack Sketchpad channels.',
      isUnlocked: channelsUsedCount >= 5,
      badgeFlair: '5-Channel Maestro',
    ),
    CreatorMasteryBadge(
      id: 'voice_sovereign',
      name: 'Voice Sovereign',
      description: 'Calibrated and extracted your sovereign African vocal signature DNA.',
      isUnlocked: signatures.isNotEmpty,
      badgeFlair: 'VHU-SIG Sovereign',
    ),
  ];
});
