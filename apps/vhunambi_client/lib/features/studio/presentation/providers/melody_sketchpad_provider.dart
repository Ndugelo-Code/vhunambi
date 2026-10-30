import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../mastering/presentation/providers/mastering_session_provider.dart';
import '../../data/services/sketchpad_audio_player_service.dart';
import '../../domain/models/melody_sketchpad_models.dart';
import '../../domain/services/melody_wav_synthesizer.dart';
import 'studio_form_provider.dart';

/// Immutable state for the Phase 27 Device-Adaptive Melody, Chord & Log-Drum Sketchpad.
@immutable
class MelodySketchpadState {
  const MelodySketchpadState({
    required this.activePattern,
    this.attachedPattern,
    this.savedPatterns = const [],
    this.starterPresets = kStarterMelodyPatterns,
    this.isGlideModeEnabled = false,
    this.chordStampMode = ChordStampMode.single,
    this.activeMobileBarPage = 0,
    this.isMobileLivePadMode = false,
    this.isPlayingPreview = false,
    this.currentPlayheadStep = 0,
    this.euclideanPulses = 5,
    this.lastSynthesizedWavBytes,
  });

  final MelodyPatternEntity activePattern;
  final MelodyPatternEntity? attachedPattern;
  final List<MelodyPatternEntity> savedPatterns;
  final List<MelodyPatternEntity> starterPresets;
  final bool isGlideModeEnabled;
  final ChordStampMode chordStampMode;
  final int activeMobileBarPage; // 0..3 (Steps 0..3, 4..7, 8..11, 12..15)
  final bool isMobileLivePadMode;
  final bool isPlayingPreview;
  final int currentPlayheadStep; // 0..15
  final int euclideanPulses; // 3..12
  final Uint8List? lastSynthesizedWavBytes;

  bool get hasAttachedReference => attachedPattern != null;

  MelodySketchpadState copyWith({
    MelodyPatternEntity? activePattern,
    MelodyPatternEntity? attachedPattern,
    bool clearAttachedPattern = false,
    List<MelodyPatternEntity>? savedPatterns,
    List<MelodyPatternEntity>? starterPresets,
    bool? isGlideModeEnabled,
    ChordStampMode? chordStampMode,
    int? activeMobileBarPage,
    bool? isMobileLivePadMode,
    bool? isPlayingPreview,
    int? currentPlayheadStep,
    int? euclideanPulses,
    Uint8List? lastSynthesizedWavBytes,
  }) {
    return MelodySketchpadState(
      activePattern: activePattern ?? this.activePattern,
      attachedPattern: clearAttachedPattern
          ? null
          : (attachedPattern ?? this.attachedPattern),
      savedPatterns: savedPatterns ?? this.savedPatterns,
      starterPresets: starterPresets ?? this.starterPresets,
      isGlideModeEnabled: isGlideModeEnabled ?? this.isGlideModeEnabled,
      chordStampMode: chordStampMode ?? this.chordStampMode,
      activeMobileBarPage: activeMobileBarPage ?? this.activeMobileBarPage,
      isMobileLivePadMode: isMobileLivePadMode ?? this.isMobileLivePadMode,
      isPlayingPreview: isPlayingPreview ?? this.isPlayingPreview,
      currentPlayheadStep: currentPlayheadStep ?? this.currentPlayheadStep,
      euclideanPulses: euclideanPulses ?? this.euclideanPulses,
      lastSynthesizedWavBytes:
          lastSynthesizedWavBytes ?? this.lastSynthesizedWavBytes,
    );
  }
}

/// Manages the 8×16 scale-locked sequencer, Local Hive Pattern Vault (`melodySketchesBoxKey`),
/// Ephemeral In-Memory 16-bit PCM WAV synthesis, and Phase 3/23/25 synergy (REQ-SKP-01..15).
class MelodySketchpadNotifier extends StateNotifier<MelodySketchpadState> {
  MelodySketchpadNotifier(this._ref)
    : super(MelodySketchpadState(activePattern: kStarterMelodyPatterns.first)) {
    _loadSavedPatternsFromHive();
  }

  final Ref _ref;
  static const String _savedListKey = 'saved_melody_patterns_json';

  ISketchpadAudioPlayerService get _audioService =>
      _ref.read(sketchpadAudioPlayerServiceProvider);

  void _auditionSingleScaleRow(int scaleRow, {bool? hasGlide}) {
    final pattern = state.activePattern;
    final freqHz = resolveScaleFrequencyHz(
      pattern.musicalKey,
      pattern.scaleMode,
      scaleRow,
      instrument: pattern.instrument,
    );
    final hitWav = MelodyWavSynthesizer.synthesizeSingleNoteWavBytes(
      instrument: pattern.instrument,
      freqHz: freqHz,
      hasGlide: hasGlide ?? state.isGlideModeEnabled,
    );
    unawaited(_audioService.playSingleNoteHit(hitWav));
  }

  void _refreshLoopIfPlaying() {
    if (!state.isPlayingPreview) return;
    final wavBytes = MelodyWavSynthesizer.synthesizePatternToWavBytes(
      state.activePattern,
    );
    state = state.copyWith(lastSynthesizedWavBytes: wavBytes);
    unawaited(
      _audioService.updateLoopBuffer(wavBytes, bpm: state.activePattern.bpm),
    );
  }

  void _loadSavedPatternsFromHive() {
    try {
      if (!Hive.isBoxOpen(AppConstants.melodySketchesBoxKey)) return;
      final box = Hive.box<dynamic>(AppConstants.melodySketchesBoxKey);
      final rawJson = box.get(_savedListKey) as String?;
      if (rawJson == null || rawJson.isEmpty) return;

      final decoded = jsonDecode(rawJson) as List<dynamic>;
      final loaded = decoded
          .map(
            (e) => MelodyPatternEntity.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();

      if (loaded.isNotEmpty) {
        state = state.copyWith(savedPatterns: loaded);
      }
    } catch (_) {
      // Safe fallback in headless flutter test when Hive is not open
    }
  }

  Future<void> _persistSavedPatterns(List<MelodyPatternEntity> patterns) async {
    try {
      if (!Hive.isBoxOpen(AppConstants.melodySketchesBoxKey)) return;
      final box = Hive.box<dynamic>(AppConstants.melodySketchesBoxKey);
      final encoded = jsonEncode(patterns.map((p) => p.toJson()).toList());
      await box.put(_savedListKey, encoded);
    } catch (_) {
      // Safe fallback in headless tests
    }
  }

  /// Loads a starter preset or saved vault pattern into the active sequencer.
  void loadPattern(MelodyPatternEntity pattern) {
    state = state.copyWith(activePattern: pattern, currentPlayheadStep: 0);
    _refreshLoopIfPlaying();
  }

  /// Changes the active African instrument (non-destructively re-voicing existing steps).
  void setInstrument(SketchpadInstrument instrument) {
    state = state.copyWith(
      activePattern: state.activePattern.copyWith(instrument: instrument),
    );
    _auditionSingleScaleRow(0, hasGlide: false);
    _refreshLoopIfPlaying();
  }

  /// Changes the root musical key (e.g., `F#m`, `Am`, `Cm`, `G`).
  void setMusicalKey(String musicalKey) {
    state = state.copyWith(
      activePattern: state.activePattern.copyWith(musicalKey: musicalKey),
    );
    _auditionSingleScaleRow(0, hasGlide: false);
    _refreshLoopIfPlaying();
  }

  /// Changes the scale mode ladder (`minorPentatonic`, `naturalMinor`, `maskandiHexatonic`, `gqomPhrygianDark`).
  void setScaleMode(AfricanScaleMode scaleMode) {
    state = state.copyWith(
      activePattern: state.activePattern.copyWith(scaleMode: scaleMode),
    );
    _refreshLoopIfPlaying();
  }

  /// Updates pattern BPM (`60..180`).
  void setBpm(int bpm) {
    state = state.copyWith(
      activePattern: state.activePattern.copyWith(bpm: bpm.clamp(60, 180)),
    );
  }

  /// Updates the ACE-Step 1.5 audio conditioning strength (`0.15..0.95`).
  void setConditioningStrength(double strength) {
    state = state.copyWith(
      activePattern: state.activePattern.copyWith(
        conditioningStrength: strength.clamp(0.15, 0.95),
      ),
    );
  }

  /// Toggles Log-Drum Pitch Glide mode (`-5 semitone` slide on newly placed or tapped notes).
  void toggleGlideMode() {
    state = state.copyWith(isGlideModeEnabled: !state.isGlideModeEnabled);
  }

  /// Sets the Desktop Chord Voicing Stamp mode (`single`, `triad`, `seventh`).
  void setChordStampMode(ChordStampMode mode) {
    state = state.copyWith(chordStampMode: mode);
  }

  /// Selects the active 4-step bar page (`0..3`) on Mobile (`< 768px`).
  void setMobileBarPage(int pageIndex) {
    state = state.copyWith(activeMobileBarPage: pageIndex.clamp(0, 3));
  }

  /// Switches Mobile between the 4-Step Bar Grid and the 8-Pad Live Scale Performance Deck.
  void toggleMobileInputMode() {
    state = state.copyWith(isMobileLivePadMode: !state.isMobileLivePadMode);
  }

  /// Toggles a cell at (`scaleRow`, `stepIndex`), respecting `isGlideModeEnabled` and `chordStampMode`.
  void toggleCell(int scaleRow, int stepIndex, {bool? forceGlide}) {
    final r = scaleRow.clamp(0, 7);
    final s = stepIndex.clamp(0, 15);
    final currentNotes = List<MelodyStepNote>.from(state.activePattern.notes);
    final existingIdx = currentNotes.indexWhere(
      (n) => n.scaleRow == r && n.stepIndex == s,
    );

    final useGlide = forceGlide ?? state.isGlideModeEnabled;

    if (existingIdx >= 0) {
      final existing = currentNotes[existingIdx];
      // If Glide mode is active and note didn't have glide yet, upgrade it to Glide instead of deleting
      if (useGlide && !existing.hasGlide) {
        currentNotes[existingIdx] = existing.copyWith(
          hasGlide: true,
          durationSteps: 2,
        );
        _auditionSingleScaleRow(r, hasGlide: true);
      } else {
        currentNotes.removeAt(existingIdx);
      }
    } else {
      // Determine rows to stamp based on ChordStampMode
      final targetRows = switch (state.chordStampMode) {
        ChordStampMode.single => <int>[r],
        ChordStampMode.triad => <int>{
          r,
          (r + 2).clamp(0, 7),
          (r + 4).clamp(0, 7),
        }.toList(),
        ChordStampMode.seventh => <int>{
          r,
          (r + 2).clamp(0, 7),
          (r + 4).clamp(0, 7),
          (r + 6).clamp(0, 7),
        }.toList(),
      };

      for (final targetRow in targetRows) {
        final alreadyHas = currentNotes.any(
          (n) => n.scaleRow == targetRow && n.stepIndex == s,
        );
        if (!alreadyHas) {
          currentNotes.add(
            MelodyStepNote(
              stepIndex: s,
              scaleRow: targetRow,
              velocity: (s % 4 == 0) ? 0.95 : 0.85,
              hasGlide: useGlide,
              durationSteps: useGlide ? 2 : 1,
            ),
          );
        }
      }
      _auditionSingleScaleRow(r, hasGlide: useGlide);
    }

    state = state.copyWith(
      activePattern: state.activePattern.copyWith(notes: currentNotes),
    );
    _refreshLoopIfPlaying();
  }

  /// Triggers a scale pad (0..7) from the Mobile 8-Pad Deck or Desktop QWERTY keyboard (`A..K`).
  void triggerLiveScalePad(int scaleRow) {
    final clampedRow = scaleRow.clamp(0, 7);
    final step = state.currentPlayheadStep;
    _auditionSingleScaleRow(clampedRow);
    toggleCell(clampedRow, step);
    final nextStep = (step + 1) % 16;
    state = state.copyWith(
      currentPlayheadStep: nextStep,
      activeMobileBarPage: nextStep ~/ 4,
    );
  }

  /// Toggles `hasGlide` on all notes in column `stepIndex` (Desktop Velocity & Glide Stalk Lane).
  void toggleStepColumnGlide(int stepIndex) {
    final s = stepIndex.clamp(0, 15);
    final currentNotes = state.activePattern.notes.map((n) {
      if (n.stepIndex != s) return n;
      final nextGlide = !n.hasGlide;
      return n.copyWith(hasGlide: nextGlide, durationSteps: nextGlide ? 2 : 1);
    }).toList();

    state = state.copyWith(
      activePattern: state.activePattern.copyWith(notes: currentNotes),
    );
  }

  /// Updates velocity (`0.1..1.0`) for all notes in column `stepIndex` (Desktop Velocity Stalk Lane).
  void setStepColumnVelocity(int stepIndex, double velocity) {
    final s = stepIndex.clamp(0, 15);
    final v = velocity.clamp(0.1, 1.0);
    final currentNotes = state.activePattern.notes.map((n) {
      if (n.stepIndex != s) return n;
      return n.copyWith(velocity: v);
    }).toList();

    state = state.copyWith(
      activePattern: state.activePattern.copyWith(notes: currentNotes),
    );
  }

  /// Generates an in-key syncopated Euclidean groove across the 16 steps (REQ-SKP-07).
  void applyEuclideanGroove({int? pulses}) {
    final k = (pulses ?? state.euclideanPulses).clamp(3, 12);
    final generated = MelodyWavSynthesizer.generateEuclideanGrooveNotes(
      pulses: k,
      instrument: state.activePattern.instrument,
    );
    state = state.copyWith(
      euclideanPulses: k,
      activePattern: state.activePattern.copyWith(notes: generated),
    );
    _auditionSingleScaleRow(0, hasGlide: true);
    _refreshLoopIfPlaying();
  }

  /// Clears all active notes from the 16-step grid.
  void clearGrid() {
    state = state.copyWith(
      activePattern: state.activePattern.copyWith(notes: const []),
    );
    if (state.isPlayingPreview) {
      stopPreviewPlayback();
    }
  }

  /// Stops loop audition preview and halts the hardware audio player.
  void stopPreviewPlayback() {
    unawaited(_audioService.stopLoopPlayback());
    if (mounted) {
      state = state.copyWith(isPlayingPreview: false, currentPlayheadStep: 0);
    }
  }

  /// Toggles loop audition preview, synthesizes the 16-bit PCM WAV buffer in RAM,
  /// and plays it in a continuous loop via `ISketchpadAudioPlayerService`.
  void togglePreviewPlayback() {
    if (state.isPlayingPreview) {
      stopPreviewPlayback();
    } else {
      final wavBytes = MelodyWavSynthesizer.synthesizePatternToWavBytes(
        state.activePattern,
      );
      state = state.copyWith(
        isPlayingPreview: true,
        currentPlayheadStep: (state.currentPlayheadStep + 1) % 16,
        lastSynthesizedWavBytes: wavBytes,
      );
      unawaited(
        _audioService.startLoopPlayback(
          wavBytes,
          bpm: state.activePattern.bpm,
          onStepTick: (stepIndex) {
            if (!mounted || !state.isPlayingPreview) return;
            state = state.copyWith(
              currentPlayheadStep: stepIndex,
              activeMobileBarPage: stepIndex ~/ 4,
            );
          },
        ),
      );
    }
  }

  /// Saves the active pattern to the local Hive Melody Vault (< 2 KB JSON blueprint) (REQ-SKP-05).
  Future<MelodyPatternEntity> saveCurrentToVault({String? customName}) async {
    final cleanName = (customName != null && customName.trim().isNotEmpty)
        ? customName.trim()
        : state.activePattern.name;

    final savedPattern = state.activePattern.copyWith(
      id: 'skp_${DateTime.now().millisecondsSinceEpoch}',
      name: cleanName,
    );

    final updatedVault = [
      savedPattern,
      ...state.savedPatterns.where((p) => p.id != savedPattern.id),
    ];

    state = state.copyWith(
      activePattern: savedPattern,
      savedPatterns: updatedVault,
    );

    await _persistSavedPatterns(updatedVault);
    return savedPattern;
  }

  /// Deletes a saved melody blueprint from the local Hive vault.
  Future<void> deleteSavedPattern(String patternId) async {
    final updated = state.savedPatterns
        .where((p) => p.id != patternId)
        .toList();
    state = state.copyWith(savedPatterns: updated);
    await _persistSavedPatterns(updated);
  }

  /// Renders the pattern to an ephemeral RAM WAV buffer, attaches it to `studioFormProvider`
  /// (`ReferenceAudioDropzone`), and sets `sketchpadLayerMix = 0.35` in `masteringSessionProvider` (REQ-SKP-12..14).
  Uint8List attachAsSongReferenceAndMasterLayer() {
    final wavBytes = MelodyWavSynthesizer.synthesizePatternToWavBytes(
      state.activePattern,
    );

    state = state.copyWith(
      attachedPattern: state.activePattern,
      lastSynthesizedWavBytes: wavBytes,
    );

    Future.microtask(() {
      if (!mounted) return;
      _ref
          .read(studioFormProvider.notifier)
          .setReferenceAudio('sketchpad://${state.activePattern.id}.wav');
      _ref.read(masteringSessionProvider.notifier).setSketchpadLayerMix(0.35);
    });

    return wavBytes;
  }

  /// Detaches the active sketchpad reference from the studio form and resets `sketchpadLayerMix` to 0.0.
  void detachSongReference() {
    state = state.copyWith(clearAttachedPattern: true);
    Future.microtask(() {
      if (!mounted) return;
      _ref.read(studioFormProvider.notifier).setReferenceAudio(null);
      _ref.read(masteringSessionProvider.notifier).setSketchpadLayerMix(0.0);
    });
  }

  /// Seeds and aligns the sketchpad from parent reel DNA for viral remixing (Phase D).
  void initializeFromRemixDna({
    String? musicalKey,
    int? bpm,
    String? genre,
  }) {
    final key = (musicalKey != null && musicalKey.trim().isNotEmpty)
        ? musicalKey.trim()
        : state.activePattern.musicalKey;
    final tempo = (bpm != null && bpm > 40 && bpm < 220)
        ? bpm
        : state.activePattern.bpm;
    final scale = (genre != null && genre.toLowerCase().contains('gqom'))
        ? AfricanScaleMode.gqomPhrygianDark
        : AfricanScaleMode.naturalMinor;

    final matchingPreset = state.starterPresets.firstWhere(
      (p) =>
          genre != null &&
          p.genre.toLowerCase().contains(genre.toLowerCase()),
      orElse: () => state.starterPresets.first,
    );

    final remixedPattern = matchingPreset.copyWith(
      id: 'remix_skp_${DateTime.now().millisecondsSinceEpoch}',
      name: '${matchingPreset.name} (Remix Stems)',
      musicalKey: key,
      bpm: tempo,
      scaleMode: scale,
    );

    state = state.copyWith(activePattern: remixedPattern);
  }
}

/// Global Riverpod provider for the Phase 27 Melody, Chord & Log-Drum Sketchpad.
final melodySketchpadProvider =
    StateNotifierProvider<MelodySketchpadNotifier, MelodySketchpadState>((ref) {
      return MelodySketchpadNotifier(ref);
    });
