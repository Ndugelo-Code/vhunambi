import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/hive_compaction_scheduler.dart';
import '../../../creator_dna/domain/entities/creator_dna_profile.dart';
import '../../../creator_dna/presentation/providers/creator_dna_provider.dart';
import '../../../mastering/presentation/providers/mastering_session_provider.dart';
import '../../data/services/pre_gen_r2_upload_service.dart';
import '../../data/services/sketchpad_audio_player_service.dart';
import '../../domain/models/melody_sketchpad_models.dart';
import '../../domain/services/melody_wav_synthesizer.dart';
import '../../domain/services/sketchpad_dna_resynthesizer.dart';
import 'studio_form_provider.dart';

/// Immutable state for the FL Studio-Style Multi-Track Master Groove Sketchpad (Phase 32).
@immutable
class MelodySketchpadState {
  const MelodySketchpadState({
    required this.activePattern,
    required this.multiTrackGroove,
    this.activeChannelRole = SketchpadChannelRole.lead,
    this.isFullscreen = false,
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
    this.lastRenderedR2Url,
    this.lastRenderedReferenceId,
    this.dnaUndoStack = const [],
    this.lastDnaReport,
  });

  final MelodyPatternEntity activePattern;
  final MultiTrackGrooveEntity multiTrackGroove;
  final SketchpadChannelRole activeChannelRole;
  final bool isFullscreen;
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
  final String? lastRenderedR2Url;
  final String? lastRenderedReferenceId;
  final List<MultiTrackGrooveEntity> dnaUndoStack;
  final DnaResynthesisReport? lastDnaReport;

  bool get hasAttachedReference => attachedPattern != null;

  bool get isDrumOrHatChannel =>
      activeChannelRole == SketchpadChannelRole.drums ||
      activeChannelRole == SketchpadChannelRole.hats;

  bool get isHatsChannel => activeChannelRole == SketchpadChannelRole.hats;

  bool get canUndoDna => dnaUndoStack.isNotEmpty;

  SketchpadChannelTrack get currentChannelTrack =>
      multiTrackGroove.channels[activeChannelRole] ??
      multiTrackGroove.channels[SketchpadChannelRole.lead]!;

  MelodySketchpadState copyWith({
    MelodyPatternEntity? activePattern,
    MultiTrackGrooveEntity? multiTrackGroove,
    SketchpadChannelRole? activeChannelRole,
    bool? isFullscreen,
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
    String? lastRenderedR2Url,
    String? lastRenderedReferenceId,
    bool clearLastRenderedR2Url = false,
    List<MultiTrackGrooveEntity>? dnaUndoStack,
    DnaResynthesisReport? lastDnaReport,
    bool clearLastDnaReport = false,
  }) {
    return MelodySketchpadState(
      activePattern: activePattern ?? this.activePattern,
      multiTrackGroove: multiTrackGroove ?? this.multiTrackGroove,
      activeChannelRole: activeChannelRole ?? this.activeChannelRole,
      isFullscreen: isFullscreen ?? this.isFullscreen,
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
      lastRenderedR2Url: clearLastRenderedR2Url
          ? null
          : (lastRenderedR2Url ?? this.lastRenderedR2Url),
      lastRenderedReferenceId: clearLastRenderedR2Url
          ? null
          : (lastRenderedReferenceId ?? this.lastRenderedReferenceId),
      dnaUndoStack: dnaUndoStack ?? this.dnaUndoStack,
      lastDnaReport: clearLastDnaReport
          ? null
          : (lastDnaReport ?? this.lastDnaReport),
    );
  }
}

/// Manages the 5-channel FL Studio-style multi-track sequencer, Local Hive Vault,
/// and 44.1 kHz stereo Master Drive summing (REQ-SKP2-TRACK-01..04).
class MelodySketchpadNotifier extends StateNotifier<MelodySketchpadState> {
  MelodySketchpadNotifier(this._ref)
    : super(
        MelodySketchpadState(
          activePattern: kStarterMelodyPatterns.first,
          multiTrackGroove: MultiTrackGrooveEntity.createDefault(
            id: kStarterMelodyPatterns.first.id,
            name: kStarterMelodyPatterns.first.name,
            bpm: kStarterMelodyPatterns.first.bpm,
            musicalKey: kStarterMelodyPatterns.first.musicalKey,
            scaleMode: kStarterMelodyPatterns.first.scaleMode,
            leadInstrument: kStarterMelodyPatterns.first.instrument,
            initialLeadNotes: kStarterMelodyPatterns.first.notes,
          ),
        ),
      ) {
    _loadSavedPatternsFromHive();
  }

  final Ref _ref;
  static const String _savedListKey = 'saved_melody_patterns_json';
  static const String _sketchKeyPrefix = 'sketch_';

  ISketchpadAudioPlayerService get _audioService =>
      _ref.read(sketchpadAudioPlayerServiceProvider);

  void _auditionSingleScaleRow(int scaleRow, {bool? hasGlide}) {
    final pattern = state.activePattern;
    final activeChannel = state.currentChannelTrack;
    if (state.isDrumOrHatChannel) {
      final voiceWav = MelodyWavSynthesizer.synthesizeSingleDrumOrHatWavBytes(
        role: state.activeChannelRole,
        kit: activeChannel.beatKit,
        row: scaleRow,
      );
      state = state.copyWith(lastSynthesizedWavBytes: voiceWav);
      unawaited(_audioService.playSingleNoteHit(voiceWav));
    } else {
      final freqHz = resolveScaleFrequencyHz(
        pattern.musicalKey,
        pattern.scaleMode,
        scaleRow,
        instrument: pattern.instrument,
        role: state.activeChannelRole,
      );
      final hitWav = MelodyWavSynthesizer.synthesizeSingleNoteWavBytes(
        instrument: pattern.instrument,
        freqHz: freqHz,
        hasGlide: hasGlide ?? state.isGlideModeEnabled,
        role: state.activeChannelRole,
      );
      state = state.copyWith(lastSynthesizedWavBytes: hitWav);
      unawaited(_audioService.playSingleNoteHit(hitWav));
    }
  }

  /// Phase 57 (`REQ-P57-DNA-01..05`, `REQ-P57-UNDO-01`):
  /// Applies System-1 Calibrated "Jev" DNA Resynthesis strictly to the active (non-empty)
  /// channels in `state.multiTrackGroove`, pushes the prior groove snapshot onto
  /// `state.dnaUndoStack` (bounded at 10 snapshots), cleanly replaces the active channel
  /// steps in-place, and re-synthesizes the 44.1 kHz master WAV preview.
  void applyDnaResynthesis({CreatorDnaProfile? dnaOverride}) {
    final CreatorDnaProfile dnaProfile =
        dnaOverride ??
        _ref.read(creatorDnaProvider) ??
        CreatorDnaProfile.initial();
    final priorSnapshot = state.multiTrackGroove;

    final updatedUndoStack = <MultiTrackGrooveEntity>[
      ...state.dnaUndoStack,
      priorSnapshot,
    ];
    while (updatedUndoStack.length > 10) {
      updatedUndoStack.removeAt(0);
    }

    final result = SketchpadDnaResynthesizer.resynthesize(
      groove: priorSnapshot,
      dnaProfile: dnaProfile,
      fallbackActiveRole: state.activeChannelRole,
    );

    final newGroove = result.groove;
    final activeRole = state.activeChannelRole;
    final updatedActiveChannel =
        newGroove.channels[activeRole] ??
        newGroove.channels[SketchpadChannelRole.lead]!;

    final syncedPattern = state.activePattern.copyWith(
      instrument: updatedActiveChannel.instrument,
      notes: updatedActiveChannel.steps,
    );

    final masterWav = MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(
      newGroove,
    );

    state = state.copyWith(
      multiTrackGroove: newGroove,
      activePattern: syncedPattern,
      dnaUndoStack: updatedUndoStack,
      lastDnaReport: result.report,
      lastSynthesizedWavBytes: masterWav,
    );

    if (state.isPlayingPreview) {
      unawaited(_audioService.updateLoopBuffer(masterWav, bpm: newGroove.bpm));
    }
  }

  /// Phase 57 (`REQ-P57-UNDO-02`):
  /// Pops the most recent groove snapshot from `state.dnaUndoStack` and restores
  /// `state.multiTrackGroove` and `state.activePattern` to their exact prior state.
  void undoDnaResynthesis() {
    if (state.dnaUndoStack.isEmpty) return;

    final stackCopy = List<MultiTrackGrooveEntity>.from(state.dnaUndoStack);
    final restoredGroove = stackCopy.removeLast();
    final activeRole = state.activeChannelRole;
    final restoredChannel =
        restoredGroove.channels[activeRole] ??
        restoredGroove.channels[SketchpadChannelRole.lead]!;

    final syncedPattern = state.activePattern.copyWith(
      instrument: restoredChannel.instrument,
      notes: restoredChannel.steps,
    );

    final masterWav = MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(
      restoredGroove,
    );

    state = state.copyWith(
      multiTrackGroove: restoredGroove,
      activePattern: syncedPattern,
      dnaUndoStack: stackCopy,
      clearLastDnaReport: stackCopy.isEmpty,
      lastSynthesizedWavBytes: masterWav,
    );

    if (state.isPlayingPreview) {
      unawaited(
        _audioService.updateLoopBuffer(masterWav, bpm: restoredGroove.bpm),
      );
    }
  }

  /// Dismisses the Jev DNA telemetry report banner.
  void dismissDnaReport() {
    state = state.copyWith(clearLastDnaReport: true);
  }

  void _refreshLoopIfPlaying() {
    if (!state.isPlayingPreview) return;
    final wavBytes = MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(
      state.multiTrackGroove,
    );
    state = state.copyWith(lastSynthesizedWavBytes: wavBytes);
    unawaited(
      _audioService.updateLoopBuffer(wavBytes, bpm: state.multiTrackGroove.bpm),
    );
  }

  void _loadSavedPatternsFromHive() {
    try {
      if (!Hive.isBoxOpen(AppConstants.melodySketchesBoxKey)) return;
      final box = Hive.box<dynamic>(AppConstants.melodySketchesBoxKey);

      // Auto-migrate legacy monolithic list key to O(1) 'sketch_<id>' keys.
      final legacyRaw = box.get(_savedListKey) as String?;
      if (legacyRaw != null && legacyRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(legacyRaw) as List<dynamic>;
          for (final item in decoded) {
            final parsed = MelodyPatternEntity.fromJson(
              Map<String, dynamic>.from(item as Map),
            );
            unawaited(
              box.put(
                '$_sketchKeyPrefix${parsed.id}',
                jsonEncode(parsed.toJson()),
              ),
            );
          }
          unawaited(box.delete(_savedListKey));
        } catch (_) {}
      }

      final loaded = <MelodyPatternEntity>[];
      for (final rawKey in box.keys) {
        final key = rawKey.toString();
        if (!key.startsWith(_sketchKeyPrefix)) continue;
        final rawVal = box.get(rawKey);
        if (rawVal is String && rawVal.isNotEmpty) {
          try {
            loaded.add(
              MelodyPatternEntity.fromJson(
                Map<String, dynamic>.from(jsonDecode(rawVal) as Map),
              ),
            );
          } catch (_) {}
        } else if (rawVal is Map) {
          try {
            loaded.add(
              MelodyPatternEntity.fromJson(Map<String, dynamic>.from(rawVal)),
            );
          } catch (_) {}
        }
      }

      if (loaded.isNotEmpty) {
        state = state.copyWith(savedPatterns: loaded.reversed.toList());
      }
    } catch (_) {
      // Safe fallback in headless flutter test when Hive is not open
    }
  }

  Future<void> _persistSinglePattern(MelodyPatternEntity pattern) async {
    try {
      if (!Hive.isBoxOpen(AppConstants.melodySketchesBoxKey)) return;
      final box = Hive.box<dynamic>(AppConstants.melodySketchesBoxKey);
      await box.put(
        '$_sketchKeyPrefix${pattern.id}',
        jsonEncode(pattern.toJson()),
      );
      await HiveCompactionScheduler.recordMutation(
        AppConstants.melodySketchesBoxKey,
      );
    } catch (_) {
      // Safe fallback in headless tests
    }
  }

  Future<void> _deleteSinglePattern(String patternId) async {
    try {
      if (!Hive.isBoxOpen(AppConstants.melodySketchesBoxKey)) return;
      final box = Hive.box<dynamic>(AppConstants.melodySketchesBoxKey);
      await box.delete('$_sketchKeyPrefix$patternId');
      await HiveCompactionScheduler.recordMutation(
        AppConstants.melodySketchesBoxKey,
      );
    } catch (_) {
      // Safe fallback in headless tests
    }
  }

  // ---------------------------------------------------------------------------
  // Multi-Track Channel Controls (Phase 32)
  // ---------------------------------------------------------------------------

  /// Switches the active channel track being viewed and edited on the 16-step matrix.
  void switchChannel(SketchpadChannelRole role) {
    if (state.activeChannelRole == role) return;
    final channel =
        state.multiTrackGroove.channels[role] ??
        state.multiTrackGroove.channels[SketchpadChannelRole.lead]!;

    final patternForChannel = state.multiTrackGroove.toLegacyPattern(role);
    state = state.copyWith(
      activeChannelRole: role,
      activePattern: patternForChannel.copyWith(instrument: channel.instrument),
    );
  }

  /// Sets volume for a specific channel track (`0.0..1.2`).
  void setChannelVolume(SketchpadChannelRole role, double volume) {
    final channel = state.multiTrackGroove.channels[role];
    if (channel == null) return;
    final updatedChannels =
        Map<SketchpadChannelRole, SketchpadChannelTrack>.from(
          state.multiTrackGroove.channels,
        );
    updatedChannels[role] = channel.copyWith(volume: volume.clamp(0.0, 1.2));
    state = state.copyWith(
      multiTrackGroove: state.multiTrackGroove.copyWith(
        channels: updatedChannels,
      ),
    );
    _refreshLoopIfPlaying();
  }

  /// Toggles mute on a channel track.
  void toggleChannelMute(SketchpadChannelRole role) {
    final channel = state.multiTrackGroove.channels[role];
    if (channel == null) return;
    final updatedChannels =
        Map<SketchpadChannelRole, SketchpadChannelTrack>.from(
          state.multiTrackGroove.channels,
        );
    updatedChannels[role] = channel.copyWith(isMuted: !channel.isMuted);
    state = state.copyWith(
      multiTrackGroove: state.multiTrackGroove.copyWith(
        channels: updatedChannels,
      ),
    );
    _refreshLoopIfPlaying();
  }

  /// Toggles solo on a channel track.
  void toggleChannelSolo(SketchpadChannelRole role) {
    final channel = state.multiTrackGroove.channels[role];
    if (channel == null) return;
    final updatedChannels =
        Map<SketchpadChannelRole, SketchpadChannelTrack>.from(
          state.multiTrackGroove.channels,
        );
    updatedChannels[role] = channel.copyWith(isSolo: !channel.isSolo);
    state = state.copyWith(
      multiTrackGroove: state.multiTrackGroove.copyWith(
        channels: updatedChannels,
      ),
    );
    _refreshLoopIfPlaying();
  }

  /// Clears notes from a specific channel track.
  void clearChannel(SketchpadChannelRole role) {
    final channel = state.multiTrackGroove.channels[role];
    if (channel == null) return;
    final updatedChannels =
        Map<SketchpadChannelRole, SketchpadChannelTrack>.from(
          state.multiTrackGroove.channels,
        );
    updatedChannels[role] = channel.copyWith(steps: const []);

    final updatedGroove = state.multiTrackGroove.copyWith(
      channels: updatedChannels,
    );
    state = state.copyWith(
      multiTrackGroove: updatedGroove,
      activePattern: state.activeChannelRole == role
          ? state.activePattern.copyWith(notes: const [])
          : state.activePattern,
    );
    _refreshLoopIfPlaying();
  }

  /// Sets the BeatKitGenre for the drums channel.
  void setBeatKitGenre(BeatKitGenre kit) {
    final drumsChan =
        state.multiTrackGroove.channels[SketchpadChannelRole.drums];
    final hatsChan = state.multiTrackGroove.channels[SketchpadChannelRole.hats];
    final updatedChannels =
        Map<SketchpadChannelRole, SketchpadChannelTrack>.from(
          state.multiTrackGroove.channels,
        );
    if (drumsChan != null) {
      updatedChannels[SketchpadChannelRole.drums] = drumsChan.copyWith(
        beatKit: kit,
      );
    }
    if (hatsChan != null) {
      updatedChannels[SketchpadChannelRole.hats] = hatsChan.copyWith(
        beatKit: kit,
      );
    }
    state = state.copyWith(
      multiTrackGroove: state.multiTrackGroove.copyWith(
        channels: updatedChannels,
      ),
    );
    _refreshLoopIfPlaying();
  }

  /// Toggles modal full-screen expansion mode.
  void toggleFullscreen() {
    state = state.copyWith(isFullscreen: !state.isFullscreen);
  }

  // ---------------------------------------------------------------------------
  // Single-Channel & Sequencer Editing (Preserves Phase 27 backward compatibility)
  // ---------------------------------------------------------------------------

  /// Loads a starter preset or saved vault pattern into the active sequencer.
  void loadPattern(MelodyPatternEntity pattern) {
    final updatedChannels =
        Map<SketchpadChannelRole, SketchpadChannelTrack>.from(
          state.multiTrackGroove.channels,
        );
    final currentRole = state.activeChannelRole;
    final currentChannel =
        updatedChannels[currentRole] ??
        updatedChannels[SketchpadChannelRole.lead]!;

    updatedChannels[currentRole] = currentChannel.copyWith(
      instrument: pattern.instrument,
      steps: pattern.notes,
    );

    final updatedGroove = state.multiTrackGroove.copyWith(
      id: pattern.id,
      name: pattern.name,
      bpm: pattern.bpm,
      musicalKey: pattern.musicalKey,
      scaleMode: pattern.scaleMode,
      channels: updatedChannels,
    );

    state = state.copyWith(
      activePattern: pattern,
      multiTrackGroove: updatedGroove,
      currentPlayheadStep: 0,
    );
    _refreshLoopIfPlaying();
  }

  /// Loads and immediately triggers loop playback audition for [pattern].
  void previewPattern(MelodyPatternEntity pattern) {
    loadPattern(pattern);
    togglePreviewPlayback();
  }

  /// Changes the active instrument of the current channel.
  void setInstrument(SketchpadInstrument instrument) {
    final updatedChannels =
        Map<SketchpadChannelRole, SketchpadChannelTrack>.from(
          state.multiTrackGroove.channels,
        );
    final currentRole = state.activeChannelRole;
    final currentChannel = updatedChannels[currentRole];
    if (currentChannel != null) {
      updatedChannels[currentRole] = currentChannel.copyWith(
        instrument: instrument,
      );
    }

    state = state.copyWith(
      activePattern: state.activePattern.copyWith(instrument: instrument),
      multiTrackGroove: state.multiTrackGroove.copyWith(
        channels: updatedChannels,
      ),
    );
    _auditionSingleScaleRow(0, hasGlide: false);
    _refreshLoopIfPlaying();
  }

  /// Changes the root musical key (e.g., `F#m`, `Am`, `Cm`, `G`).
  void setMusicalKey(String musicalKey) {
    state = state.copyWith(
      activePattern: state.activePattern.copyWith(musicalKey: musicalKey),
      multiTrackGroove: state.multiTrackGroove.copyWith(musicalKey: musicalKey),
    );
    _auditionSingleScaleRow(0, hasGlide: false);
    _refreshLoopIfPlaying();
  }

  /// Changes the scale mode ladder.
  void setScaleMode(AfricanScaleMode scaleMode) {
    state = state.copyWith(
      activePattern: state.activePattern.copyWith(scaleMode: scaleMode),
      multiTrackGroove: state.multiTrackGroove.copyWith(scaleMode: scaleMode),
    );
    _refreshLoopIfPlaying();
  }

  /// Updates pattern BPM (`60..180`).
  void setBpm(int bpm) {
    final clampedBpm = bpm.clamp(60, 180);
    state = state.copyWith(
      activePattern: state.activePattern.copyWith(bpm: clampedBpm),
      multiTrackGroove: state.multiTrackGroove.copyWith(bpm: clampedBpm),
    );
    _refreshLoopIfPlaying();
  }

  /// Updates the ACE-Step 1.5 audio conditioning strength (`0.15..0.95`).
  void setConditioningStrength(double strength) {
    state = state.copyWith(
      activePattern: state.activePattern.copyWith(
        conditioningStrength: strength.clamp(0.15, 0.95),
      ),
    );
  }

  /// Toggles Log-Drum Pitch Glide mode.
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

  /// Toggles a cell at (`scaleRow`, `stepIndex`), synchronizing both activePattern & multiTrackGroove.
  void toggleCell(
    int scaleRow,
    int stepIndex, {
    bool? forceGlide,
    double? velocity,
    int? durationSteps,
  }) {
    final r = scaleRow.clamp(0, 7);
    final s = stepIndex.clamp(0, 15);
    final currentNotes = List<MelodyStepNote>.from(state.activePattern.notes);
    final existingIdx = currentNotes.indexWhere(
      (n) => n.scaleRow == r && n.stepIndex == s,
    );

    final useGlide = forceGlide ?? state.isGlideModeEnabled;

    if (existingIdx >= 0) {
      final existing = currentNotes[existingIdx];
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
              velocity: velocity ?? ((s % 4 == 0) ? 0.95 : 0.85),
              hasGlide: useGlide,
              durationSteps: durationSteps ?? (useGlide ? 2 : 1),
            ),
          );
        }
      }
      _auditionSingleScaleRow(r, hasGlide: useGlide);
    }

    final updatedChannels =
        Map<SketchpadChannelRole, SketchpadChannelTrack>.from(
          state.multiTrackGroove.channels,
        );
    final currentRole = state.activeChannelRole;
    final currentChannel = updatedChannels[currentRole];
    if (currentChannel != null) {
      updatedChannels[currentRole] = currentChannel.copyWith(
        steps: currentNotes,
      );
    }

    state = state.copyWith(
      activePattern: state.activePattern.copyWith(notes: currentNotes),
      multiTrackGroove: state.multiTrackGroove.copyWith(
        channels: updatedChannels,
      ),
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

  /// Toggles `hasGlide` on all notes in column `stepIndex`.
  void toggleStepColumnGlide(int stepIndex) {
    final s = stepIndex.clamp(0, 15);
    final currentNotes = state.activePattern.notes.map((n) {
      if (n.stepIndex != s) return n;
      final nextGlide = !n.hasGlide;
      return n.copyWith(hasGlide: nextGlide, durationSteps: nextGlide ? 2 : 1);
    }).toList();

    _syncCurrentChannelNotes(currentNotes);
  }

  /// Updates velocity (`0.1..1.0`) for all notes in column `stepIndex`.
  void setStepColumnVelocity(int stepIndex, double velocity) {
    final s = stepIndex.clamp(0, 15);
    final v = velocity.clamp(0.1, 1.0);
    final currentNotes = state.activePattern.notes.map((n) {
      if (n.stepIndex != s) return n;
      return n.copyWith(velocity: v);
    }).toList();

    _syncCurrentChannelNotes(currentNotes);
  }

  void _syncCurrentChannelNotes(List<MelodyStepNote> currentNotes) {
    final updatedChannels =
        Map<SketchpadChannelRole, SketchpadChannelTrack>.from(
          state.multiTrackGroove.channels,
        );
    final currentRole = state.activeChannelRole;
    final currentChannel = updatedChannels[currentRole];
    if (currentChannel != null) {
      updatedChannels[currentRole] = currentChannel.copyWith(
        steps: currentNotes,
      );
    }

    state = state.copyWith(
      activePattern: state.activePattern.copyWith(notes: currentNotes),
      multiTrackGroove: state.multiTrackGroove.copyWith(
        channels: updatedChannels,
      ),
    );
    _refreshLoopIfPlaying();
  }

  /// Generates an in-key syncopated Euclidean groove across the 16 steps (REQ-SKP-07).
  void applyEuclideanGroove({int? pulses}) {
    final k = (pulses ?? state.euclideanPulses).clamp(3, 12);
    final generated = MelodyWavSynthesizer.generateEuclideanGrooveNotes(
      pulses: k,
      instrument: state.activePattern.instrument,
    );
    _syncCurrentChannelNotes(generated);
    state = state.copyWith(euclideanPulses: k);
    _auditionSingleScaleRow(0, hasGlide: true);
  }

  /// Clears all active notes from the active channel's 16-step grid.
  void clearGrid() {
    clearChannel(state.activeChannelRole);
  }

  /// Stops loop audition preview and halts the hardware audio player.
  void stopPreviewPlayback() {
    unawaited(_audioService.stopLoopPlayback());
    if (mounted) {
      state = state.copyWith(isPlayingPreview: false, currentPlayheadStep: 0);
    }
  }

  /// Toggles loop audition preview, synthesizes the 44.1 kHz master groove in RAM,
  /// and plays it in a continuous loop via `ISketchpadAudioPlayerService`.
  void togglePreviewPlayback() {
    if (state.isPlayingPreview) {
      stopPreviewPlayback();
    } else {
      final wavBytes = MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(
        state.multiTrackGroove,
      );
      state = state.copyWith(
        isPlayingPreview: true,
        currentPlayheadStep: (state.currentPlayheadStep + 1) % 16,
        lastSynthesizedWavBytes: wavBytes,
      );
      unawaited(
        _audioService.startLoopPlayback(
          wavBytes,
          bpm: state.multiTrackGroove.bpm,
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

  /// Saves the active pattern to the local Hive Melody Vault (< 2 KB JSON blueprint).
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

    await _persistSinglePattern(savedPattern);
    return savedPattern;
  }

  /// Deletes a saved melody blueprint from the local Hive vault.
  Future<void> deleteSavedPattern(String patternId) async {
    final updated = state.savedPatterns
        .where((p) => p.id != patternId)
        .toList();
    state = state.copyWith(savedPatterns: updated);
    await _deleteSinglePattern(patternId);
  }

  /// Renders the multi-track master groove to an ephemeral RAM WAV buffer,
  /// attaches it to `studioFormProvider`, and sets `sketchpadLayerMix = 0.35`.
  Uint8List attachAsSongReferenceAndMasterLayer() {
    final wavBytes = MelodyWavSynthesizer.synthesizeMasterGrooveToWavBytes(
      state.multiTrackGroove,
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

    unawaited(_uploadAttachedSketchpadToR2(state.activePattern, wavBytes));

    return wavBytes;
  }

  Future<void> _uploadAttachedSketchpadToR2(
    MelodyPatternEntity pattern,
    Uint8List wavBytes,
  ) async {
    try {
      final result = await _ref
          .read(preGenR2UploadServiceProvider)
          .uploadMelodyReference(pattern: pattern, wavBytes: wavBytes);
      if (!mounted) return;
      if ((result.r2ReferenceUrl != null && result.r2ReferenceUrl!.isNotEmpty) ||
          (result.referenceId != null && result.referenceId!.isNotEmpty)) {
        state = state.copyWith(
          lastRenderedR2Url: result.r2ReferenceUrl,
          lastRenderedReferenceId: result.referenceId,
        );
      }
    } catch (_) {
      // Best-effort cloud conditioning upload; local sketchpad remains active.
    }
  }

  /// Detaches the active sketchpad reference from the studio form and resets `sketchpadLayerMix` to 0.0.
  void detachSongReference() {
    state = state.copyWith(
      clearAttachedPattern: true,
      clearLastRenderedR2Url: true,
    );
    Future.microtask(() {
      if (!mounted) return;
      _ref.read(studioFormProvider.notifier).setReferenceAudio(null);
      _ref.read(masteringSessionProvider.notifier).setSketchpadLayerMix(0.0);
    });
  }

  /// Seeds and aligns the sketchpad from parent reel DNA for viral remixing.
  void initializeFromRemixDna({String? musicalKey, int? bpm, String? genre}) {
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
          genre != null && p.genre.toLowerCase().contains(genre.toLowerCase()),
      orElse: () => state.starterPresets.first,
    );

    final remixedPattern = matchingPreset.copyWith(
      id: 'remix_skp_${DateTime.now().millisecondsSinceEpoch}',
      name: '${matchingPreset.name} (Remix Stems)',
      musicalKey: key,
      bpm: tempo,
      scaleMode: scale,
    );

    loadPattern(remixedPattern);
  }
}

/// Global Riverpod provider for the Phase 32 Melody, Chord & Log-Drum Sketchpad.
final melodySketchpadProvider =
    StateNotifierProvider<MelodySketchpadNotifier, MelodySketchpadState>((ref) {
      return MelodySketchpadNotifier(ref);
    });
