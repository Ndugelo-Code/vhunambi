import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/studio_session_repository.dart';
import '../../domain/models/studio_session_draft.dart';
import '../../domain/models/studio_form_state.dart';
import 'studio_form_provider.dart';

/// Lifecycle of the Ghost Session recovery prompt (M10 / REQ-SES-03/04).
enum SessionRecoveryState {
  /// No draft found (or session already consumed).
  none,

  /// A recoverable draft exists — the recovery banner is shown.
  available,

  /// The creator dismissed the banner without restoring.
  dismissed,

  /// The creator restored the draft into the form.
  resumed,
}

/// Immutable view of the Ghost Session state (M10).
class StudioSessionState {
  final SessionRecoveryState recoveryState;
  final StudioSessionDraft? savedDraft;

  /// Timestamp of the most recent successful debounced auto-save.
  final DateTime? lastSavedAt;

  const StudioSessionState({
    this.recoveryState = SessionRecoveryState.none,
    this.savedDraft,
    this.lastSavedAt,
  });

  StudioSessionState copyWith({
    SessionRecoveryState? recoveryState,
    StudioSessionDraft? savedDraft,
    DateTime? lastSavedAt,
  }) {
    return StudioSessionState(
      recoveryState: recoveryState ?? this.recoveryState,
      savedDraft: savedDraft ?? this.savedDraft,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
    );
  }
}

/// Owns the Studio Ghost Session auto-save & recovery loop (M10 /
/// REQ-SES-01 → REQ-SES-07).
///
/// - Listens to `studioFormProvider` via `ref.listen` (never `ref.watch` —
///   a watch would create a circular rebuild loop) and debounce-saves every
///   change after 800ms of quiet.
/// - On construction, checks the persisted store and flags
///   [SessionRecoveryState.available] when a recoverable draft exists.
/// - The draft is cleared the moment a generation is successfully submitted
///   (`GenerationPipelineNotifier.submitAndStartGeneration`).
class StudioSessionNotifier extends StateNotifier<StudioSessionState> {
  StudioSessionNotifier(this._repo, this._ref)
      : super(const StudioSessionState()) {
    _checkForSavedSession();
  }

  static const Duration debounceWindow = Duration(milliseconds: 800);

  final StudioSessionRepository _repo;
  final Ref _ref;
  Timer? _debounceTimer;

  Future<void> _checkForSavedSession() async {
    final hasSaved = await _repo.hasSavedSession();
    if (!hasSaved || !mounted) return;
    final draft = await _repo.loadSession();
    if (draft != null && mounted) {
      state = StudioSessionState(
        recoveryState: SessionRecoveryState.available,
        savedDraft: draft,
      );
    }
  }

  /// Debounced auto-save — wired to `studioFormProvider` changes.
  void scheduleAutoSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceWindow, _performSave);
  }

  /// Immediate save — bypasses the debounce window.
  void immediateSave() {
    _debounceTimer?.cancel();
    _performSave();
  }

  void _performSave() {
    final formState = _ref.read(studioFormProvider);
    final draft = StudioSessionDraft.fromFormState(formState);
    state = state.copyWith(lastSavedAt: draft.savedAt);
    _repo.saveSession(draft); // unawaited — fire and forget
  }

  /// Applies every persisted field of [draft] back onto the studio form and
  /// flags the session as resumed (REQ-SES-04).
  void resumeSession(StudioSessionDraft draft) {
    _debounceTimer?.cancel();
    final notifier = _ref.read(studioFormProvider.notifier);

    notifier.updatePrompt(draft.prompt);
    notifier.setGenre(draft.genre);
    notifier.setRegion(draft.region);
    notifier.setLanguage(draft.language);
    notifier.setMood(draft.mood);
    notifier.toggleInstrumental(draft.isInstrumental);
    notifier.setDurationSeconds(draft.durationSeconds);
    notifier.setCustomLyrics(draft.customLyrics ?? '');
    notifier.setLyricsMode(
      LyricsMode.values.firstWhere(
        (m) => m.name == draft.lyricsMode,
        orElse: () => LyricsMode.aiWrite,
      ),
    );
    notifier.setTempo(
      TempoBracket.values.firstWhere(
        (t) => t.name == draft.tempo,
        orElse: () => TempoBracket.medium,
      ),
    );
    notifier.setVocalVoices(
      VocalVoices.values.firstWhere(
        (v) => v.name == draft.vocalVoices,
        orElse: () => VocalVoices.solo,
      ),
    );
    notifier.setVocalGender(
      VocalGender.values.firstWhere(
        (g) => g.name == draft.vocalGender,
        orElse: () => VocalGender.male,
      ),
    );
    notifier.setVocalMode(
      VocalMode.values.firstWhere(
        (m) => m.name == draft.vocalMode,
        orElse: () => VocalMode.auto,
      ),
    );
    notifier.setVocalEnergy(
      VocalEnergy.values.firstWhere(
        (e) => e.name == draft.vocalEnergy,
        orElse: () => VocalEnergy.mid,
      ),
    );
    notifier.setSongStructure(
      SongStructure.values.firstWhere(
        (s) => s.name == draft.songStructure,
        orElse: () => SongStructure.standard,
      ),
    );
    notifier.toggleAutoTitle(draft.isAutoTitle);
    notifier.setCustomTitle(draft.customTitle ?? '');
    notifier.togglePublic(draft.isPublic);
    notifier.setReferenceAudio(draft.referenceAudioPath);

    state = state.copyWith(recoveryState: SessionRecoveryState.resumed);
  }

  /// Hides the recovery banner without restoring (REQ-SES-04).
  void dismissRecovery() {
    state = state.copyWith(recoveryState: SessionRecoveryState.dismissed);
  }

  /// Wipes the persisted draft and resets the session state — called on
  /// generation submit (REQ-SES-05) and on "Start Fresh" (REQ-SES-04).
  void clearSession() {
    _debounceTimer?.cancel();
    _repo.clearSession();
    state = const StudioSessionState();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    super.dispose();
  }
}

/// Repository provider for the Ghost Session drafts.
final studioSessionRepositoryProvider = Provider<StudioSessionRepository>(
  (ref) => StudioSessionRepository(),
);

/// State provider for the Ghost Session auto-save & recovery loop.
///
/// Wires `ref.listen` on `studioFormProvider` so every form mutation
/// schedules a debounced draft save (T2.2 — never `ref.watch`, which would
/// create a circular dependency).
final studioSessionProvider =
    StateNotifierProvider<StudioSessionNotifier, StudioSessionState>((ref) {
  final notifier = StudioSessionNotifier(
    ref.read(studioSessionRepositoryProvider),
    ref,
  );
  ref.listen<StudioFormState>(
    studioFormProvider,
    (previous, next) => notifier.scheduleAutoSave(),
  );
  return notifier;
});
