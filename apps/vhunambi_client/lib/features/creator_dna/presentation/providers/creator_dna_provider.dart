import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/creator_dna_repository.dart';
import '../../domain/entities/creator_dna_profile.dart';
import '../../domain/models/behavior_event.dart';

/// StateNotifier managing on-device Creator DNA profile evolution, telemetry updates,
/// and identity reset.
class CreatorDnaNotifier extends StateNotifier<CreatorDnaProfile> {
  final CreatorDnaRepository _repo;
  List<BehaviorEvent> _eventLog = [];

  CreatorDnaNotifier(this._repo) : super(CreatorDnaProfile.initial()) {
    _loadFromStorage();
  }

  /// Test-only: initialise with a pre-built profile, skipping storage load.
  /// Use via `creatorDnaProvider.overrideWith((ref) => CreatorDnaNotifier.withInitial(profile))`.
  CreatorDnaNotifier.withInitial(super.initial)
      : _repo = _NoOpRepository();

  Future<void> _loadFromStorage() async {
    final profile = await _repo.loadProfile();
    final log = await _repo.loadEventLog();
    _eventLog = log;
    if (mounted && profile.onboardingCompleted && !state.onboardingCompleted) {
      state = profile;
    }
  }

  /// Seeds DNA from the multi-step onboarding completion.
  Future<void> seedFromOnboarding({
    required CreativeRole role,
    required ExperienceLevel experienceLevel,
    required List<String> selectedGenres,
    required String primaryLanguage,
    required List<String> secondaryLanguages,
    required String tempoPreference,
    required String vocalEnergyPreference,
    required List<String> selectedMoods,
    required double completeness,
  }) async {
    final genreWeights = {for (final g in selectedGenres) g: 1.0};
    final languageWeights = {
      primaryLanguage: 1.5,
      for (final l in secondaryLanguages) l: 0.8,
    };
    final moodWeights = {for (final m in selectedMoods) m: 1.0};

    final seeded = state.copyWith(
      creativeRole: role,
      experienceLevel: experienceLevel,
      genreWeights: genreWeights,
      languageWeights: languageWeights,
      primaryLanguage: primaryLanguage,
      moodWeights: moodWeights,
      tempoPreference: tempoPreference,
      vocalEnergyPreference: vocalEnergyPreference,
      onboardingCompleted: true,
      onboardingCompleteness: completeness,
      lifecycleState: DnaLifecycleState.seeded,
    );

    state = seeded;
    await _repo.saveProfile(seeded);
  }

  /// Records a passive or active behavioral telemetry event and recalculates weights.
  Future<void> recordEvent(BehaviorEvent event) async {
    final updated = _applyEventToWeights(state, event);
    final evolved = _computeLifecycle(updated);
    _eventLog = [..._eventLog, event];
    if (_eventLog.length > 500) _eventLog = _eventLog.sublist(_eventLog.length - 500);

    state = evolved;
    await _repo.saveProfile(evolved);
    await _repo.appendEvent(event, _eventLog);
  }

  CreatorDnaProfile _applyEventToWeights(CreatorDnaProfile profile, BehaviorEvent event) {
    final genres = Map<String, double>.from(profile.genreWeights);
    final languages = Map<String, double>.from(profile.languageWeights);
    final moods = Map<String, double>.from(profile.moodWeights);

    void bumpGenre(String? g, double delta) {
      if (g == null || g.isEmpty) return;
      genres[g] = ((genres[g] ?? 0.0) + delta).clamp(0.0, 20.0);
    }

    void bumpLanguage(String? l, double delta) {
      if (l == null || l.isEmpty) return;
      languages[l] = ((languages[l] ?? 0.0) + delta).clamp(0.0, 20.0);
    }

    void bumpMood(String? m, double delta) {
      if (m == null || m.isEmpty) return;
      moods[m] = ((moods[m] ?? 0.0) + delta).clamp(0.0, 20.0);
    }

    switch (event.type) {
      case BehaviorEventType.trackPlay:
        final ratio = event.payload['listenRatioPercent'] as int? ?? 0;
        final genreDelta = ratio > 80 ? 0.15 : (ratio < 30 ? -0.05 : 0.05);
        bumpGenre(event.payload['genreHint'] as String?, genreDelta);
        if (ratio > 80) bumpLanguage(event.payload['languageHint'] as String?, 0.10);
      case BehaviorEventType.trackLike:
        bumpGenre(event.payload['genreHint'] as String?, 0.30);
        bumpLanguage(event.payload['languageHint'] as String?, 0.20);
        bumpMood(event.payload['moodHint'] as String?, 0.25);
      case BehaviorEventType.trackSkip:
        final secs = event.payload['secondsBeforeSkip'] as int? ?? 10;
        if (secs < 5) bumpGenre(event.payload['genreHint'] as String?, -0.10);
      case BehaviorEventType.generationSubmit:
        bumpGenre(event.payload['genre'] as String?, 0.40);
        bumpLanguage(event.payload['language'] as String?, 0.35);
        bumpMood(event.payload['mood'] as String?, 0.20);
      case BehaviorEventType.genreFilterTap:
        bumpGenre(event.payload['genre'] as String?, 0.20);
      case BehaviorEventType.exploreScrollDepth:
        bumpGenre(event.payload['genre'] as String?, 0.08);
      case BehaviorEventType.trackShare:
        bumpGenre(event.payload['genreHint'] as String?, 0.20);
        bumpMood(event.payload['moodHint'] as String?, 0.15);
    }

    return profile.copyWith(
      genreWeights: genres,
      languageWeights: languages,
      moodWeights: moods,
      totalBehaviorEvents: profile.totalBehaviorEvents + 1,
    );
  }

  DnaLifecycleState _computeNewLifecycle(CreatorDnaProfile p) {
    if (!p.onboardingCompleted) return DnaLifecycleState.uninitialized;
    if (p.totalBehaviorEvents == 0) return DnaLifecycleState.seeded;
    if (p.strengthPercent >= 80) return DnaLifecycleState.attuned;
    if (p.strengthPercent >= 60) return DnaLifecycleState.calibrated;
    return DnaLifecycleState.learning;
  }

  CreatorDnaProfile _computeLifecycle(CreatorDnaProfile p) {
    return p.copyWith(lifecycleState: _computeNewLifecycle(p));
  }

  /// Marks the DNA insight card as dismissed by user.
  Future<void> dismissInsightCard() async {
    state = state.copyWith(dnaInsightCardDismissed: true);
    await _repo.saveProfile(state);
  }

  /// Erases on-device taste memory and resets profile to initial unseeded baseline.
  Future<void> resetDna() async {
    await _repo.clearAll();
    _eventLog = [];
    state = CreatorDnaProfile.initial();
  }
}

/// Global repository provider for Creator DNA.
final creatorDnaRepositoryProvider = Provider<CreatorDnaRepository>((ref) {
  return CreatorDnaRepository();
});

/// Global state provider for Creator DNA profile.
final creatorDnaProvider = StateNotifierProvider<CreatorDnaNotifier, CreatorDnaProfile>((ref) {
  return CreatorDnaNotifier(ref.watch(creatorDnaRepositoryProvider));
});

/// No-op repository used by [CreatorDnaNotifier.withInitial] in tests.
/// Every operation is a silent no-op so tests never touch Hive.
class _NoOpRepository extends CreatorDnaRepository {
  _NoOpRepository() : super(null);

  @override
  Future<CreatorDnaProfile> loadProfile() async => CreatorDnaProfile.initial();

  @override
  Future<void> saveProfile(CreatorDnaProfile profile) async {}

  @override
  Future<List<BehaviorEvent>> loadEventLog() async => [];

  @override
  Future<void> appendEvent(BehaviorEvent event, List<BehaviorEvent> existingLog) async {}

  @override
  Future<void> clearAll() async {}
}
