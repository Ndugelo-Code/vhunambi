# Design: Creator DNA & Adaptive Intelligence

> **System:** M9 / `creator-dna-adaptive-intelligence`  
> **Status:** 🟡 SPECIFICATION  
> **Architecture Standard:** Vhunambi Dual-Agent Pair Programming Standard  
> **Persistence:** Untyped Hive Box — Zero `build_runner` / `@HiveType` Codegen  

---

## 1. High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     CREATOR DNA SYSTEM                          │
│                                                                 │
│  ┌─────────────────┐    ┌──────────────────┐                   │
│  │  OnboardingView  │───►│ OnboardingNotifier│                  │
│  │  (5-step seed)   │    │ (extended)        │                  │
│  └─────────────────┘    └────────┬─────────┘                   │
│                                   │ completeOnboarding          │
│                                   ▼                             │
│                         ┌──────────────────┐                   │
│  BehaviorEvents ────────►│ CreatorDnaNotifier│                  │
│  (play, like, skip,     │ StateNotifier     │                  │
│   generate, filter)     │ <CreatorDnaProfile>│                  │
│                         └────────┬─────────┘                   │
│                                   │                             │
│                         ┌────────▼─────────┐                   │
│                         │ CreatorDnaRepo    │                   │
│                         │ (Hive + memory)   │                   │
│                         └────────┬─────────┘                   │
│                                   │                             │
│         ┌─────────────────────────┼──────────────────────────┐ │
│         │                         │                          │ │
│         ▼                         ▼                          ▼ │
│  dnaStudioDefaults     DnaInsightCard (Home)      DnaExploreRanker│
│  Provider              strengthPercent             rank(tracks)│ │
│         │                                                     │ │
│         ▼                                                       │
│  StudioFormState initial defaults (pre-fill only)               │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Domain Models

### 2.1 `CreatorDnaProfile` Entity

**File:** `lib/features/creator_dna/domain/entities/creator_dna_profile.dart`

```dart
import 'package:flutter/foundation.dart';

enum DnaLifecycleState { uninitialized, seeded, learning, calibrated, attuned }

enum CreativeRole { producer, vocalist, songwriter, multiHyphenate, musicLover }

enum ExperienceLevel { newbie, growing, pro }

@immutable
class CreatorDnaProfile {
  final String userId;

  // Creative Identity (seeded at onboarding Step 1)
  final CreativeRole creativeRole;
  final ExperienceLevel experienceLevel;

  // Genre Affinity Map: genre name → accumulated signal weight (0.0–20.0)
  final Map<String, double> genreWeights;

  // Language Affinity Map: language name → signal weight
  final Map<String, double> languageWeights;

  // Primary language for AI vocal generation default
  final String primaryLanguage;

  // Mood Affinity Map: mood key → signal weight
  final Map<String, double> moodWeights;

  // Sound Signature Seed (Step 4)
  final String tempoPreference;      // 'slow' | 'medium' | 'fast' | 'hyperspeed'
  final String vocalEnergyPreference; // 'soft' | 'balanced' | 'intense'

  // Lifecycle & Metadata
  final DnaLifecycleState lifecycleState;
  final int totalBehaviorEvents;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;
  final bool onboardingCompleted;
  final double onboardingCompleteness; // 0.0–1.0

  // UI Preferences
  final bool dnaInsightCardDismissed;

  const CreatorDnaProfile({
    required this.userId,
    this.creativeRole = CreativeRole.musicLover,
    this.experienceLevel = ExperienceLevel.newbie,
    this.genreWeights = const {},
    this.languageWeights = const {},
    this.primaryLanguage = 'English',
    this.moodWeights = const {},
    this.tempoPreference = 'medium',
    this.vocalEnergyPreference = 'balanced',
    this.lifecycleState = DnaLifecycleState.uninitialized,
    this.totalBehaviorEvents = 0,
    required this.createdAt,
    required this.lastUpdatedAt,
    this.onboardingCompleted = false,
    this.onboardingCompleteness = 0.0,
    this.dnaInsightCardDismissed = false,
  });

  factory CreatorDnaProfile.initial() {
    final now = DateTime.now();
    return CreatorDnaProfile(
      userId: '',
      createdAt: now,
      lastUpdatedAt: now,
    );
  }

  /// DNA Strength: 0–100 whole number percentage
  int get strengthPercent {
    final eventScore = (totalBehaviorEvents / 200.0).clamp(0.0, 1.0) * 0.60;
    final allWeights = [...genreWeights.values, ...languageWeights.values, ...moodWeights.values];
    final diversity = allWeights.isEmpty
        ? 0.0
        : (allWeights.where((w) => w > 0.5).length / 30.0).clamp(0.0, 1.0) * 0.25;
    final onboarding = onboardingCompleteness * 0.15;
    return ((eventScore + diversity + onboarding) * 100).clamp(0, 100).round();
  }

  /// Top N genres by weight, descending
  List<String> topGenres(int n) {
    final sorted = genreWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).map((e) => e.key).toList();
  }

  CreatorDnaProfile copyWith({
    CreativeRole? creativeRole,
    ExperienceLevel? experienceLevel,
    Map<String, double>? genreWeights,
    Map<String, double>? languageWeights,
    String? primaryLanguage,
    Map<String, double>? moodWeights,
    String? tempoPreference,
    String? vocalEnergyPreference,
    DnaLifecycleState? lifecycleState,
    int? totalBehaviorEvents,
    DateTime? lastUpdatedAt,
    bool? onboardingCompleted,
    double? onboardingCompleteness,
    bool? dnaInsightCardDismissed,
  }) {
    return CreatorDnaProfile(
      userId: userId,
      creativeRole: creativeRole ?? this.creativeRole,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      genreWeights: genreWeights ?? this.genreWeights,
      languageWeights: languageWeights ?? this.languageWeights,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      moodWeights: moodWeights ?? this.moodWeights,
      tempoPreference: tempoPreference ?? this.tempoPreference,
      vocalEnergyPreference: vocalEnergyPreference ?? this.vocalEnergyPreference,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      totalBehaviorEvents: totalBehaviorEvents ?? this.totalBehaviorEvents,
      createdAt: createdAt,
      lastUpdatedAt: lastUpdatedAt ?? DateTime.now(),
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      onboardingCompleteness: onboardingCompleteness ?? this.onboardingCompleteness,
      dnaInsightCardDismissed: dnaInsightCardDismissed ?? this.dnaInsightCardDismissed,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'creativeRole': creativeRole.name,
    'experienceLevel': experienceLevel.name,
    'genreWeights': genreWeights,
    'languageWeights': languageWeights,
    'primaryLanguage': primaryLanguage,
    'moodWeights': moodWeights,
    'tempoPreference': tempoPreference,
    'vocalEnergyPreference': vocalEnergyPreference,
    'lifecycleState': lifecycleState.name,
    'totalBehaviorEvents': totalBehaviorEvents,
    'createdAt': createdAt.toIso8601String(),
    'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
    'onboardingCompleted': onboardingCompleted,
    'onboardingCompleteness': onboardingCompleteness,
    'dnaInsightCardDismissed': dnaInsightCardDismissed,
  };

  factory CreatorDnaProfile.fromJson(Map<String, dynamic> json) {
    return CreatorDnaProfile(
      userId: json['userId'] as String? ?? '',
      creativeRole: CreativeRole.values.firstWhere(
        (r) => r.name == json['creativeRole'],
        orElse: () => CreativeRole.musicLover,
      ),
      experienceLevel: ExperienceLevel.values.firstWhere(
        (e) => e.name == json['experienceLevel'],
        orElse: () => ExperienceLevel.newbie,
      ),
      genreWeights: Map<String, double>.from(
        (json['genreWeights'] as Map?)?.map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ) ?? {},
      ),
      languageWeights: Map<String, double>.from(
        (json['languageWeights'] as Map?)?.map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ) ?? {},
      ),
      primaryLanguage: json['primaryLanguage'] as String? ?? 'English',
      moodWeights: Map<String, double>.from(
        (json['moodWeights'] as Map?)?.map(
          (k, v) => MapEntry(k as String, (v as num).toDouble()),
        ) ?? {},
      ),
      tempoPreference: json['tempoPreference'] as String? ?? 'medium',
      vocalEnergyPreference: json['vocalEnergyPreference'] as String? ?? 'balanced',
      lifecycleState: DnaLifecycleState.values.firstWhere(
        (s) => s.name == json['lifecycleState'],
        orElse: () => DnaLifecycleState.uninitialized,
      ),
      totalBehaviorEvents: json['totalBehaviorEvents'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      lastUpdatedAt: DateTime.tryParse(json['lastUpdatedAt'] as String? ?? '') ?? DateTime.now(),
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      onboardingCompleteness: (json['onboardingCompleteness'] as num?)?.toDouble() ?? 0.0,
      dnaInsightCardDismissed: json['dnaInsightCardDismissed'] as bool? ?? false,
    );
  }
}
```

---

### 2.2 `BehaviorEvent` Model

**File:** `lib/features/creator_dna/domain/models/behavior_event.dart`

```dart
import 'package:flutter/foundation.dart';

enum BehaviorEventType {
  trackPlay,
  trackLike,
  trackSkip,
  generationSubmit,
  genreFilterTap,
  exploreScrollDepth,
  trackShare,
}

@immutable
class BehaviorEvent {
  final BehaviorEventType type;
  final DateTime timestamp;
  final Map<String, dynamic> payload;

  const BehaviorEvent({
    required this.type,
    required this.timestamp,
    required this.payload,
  });

  factory BehaviorEvent.trackPlay({
    required String trackId,
    String? genreHint,
    String? languageHint,
    required int listenRatioPercent,
  }) => BehaviorEvent(
    type: BehaviorEventType.trackPlay,
    timestamp: DateTime.now(),
    payload: {
      'trackId': trackId,
      if (genreHint != null) 'genreHint': genreHint,
      if (languageHint != null) 'languageHint': languageHint,
      'listenRatioPercent': listenRatioPercent,
    },
  );

  factory BehaviorEvent.trackLike({
    required String trackId,
    String? genreHint,
    String? languageHint,
    String? moodHint,
  }) => BehaviorEvent(
    type: BehaviorEventType.trackLike,
    timestamp: DateTime.now(),
    payload: {
      'trackId': trackId,
      if (genreHint != null) 'genreHint': genreHint,
      if (languageHint != null) 'languageHint': languageHint,
      if (moodHint != null) 'moodHint': moodHint,
    },
  );

  factory BehaviorEvent.trackSkip({
    required String trackId,
    String? genreHint,
    required int secondsBeforeSkip,
  }) => BehaviorEvent(
    type: BehaviorEventType.trackSkip,
    timestamp: DateTime.now(),
    payload: {
      'trackId': trackId,
      if (genreHint != null) 'genreHint': genreHint,
      'secondsBeforeSkip': secondsBeforeSkip,
    },
  );

  factory BehaviorEvent.generationSubmit({
    required String genre,
    required String language,
    String? tempo,
    String? vocalEnergy,
    String? mood,
  }) => BehaviorEvent(
    type: BehaviorEventType.generationSubmit,
    timestamp: DateTime.now(),
    payload: {
      'genre': genre,
      'language': language,
      if (tempo != null) 'tempo': tempo,
      if (vocalEnergy != null) 'vocalEnergy': vocalEnergy,
      if (mood != null) 'mood': mood,
    },
  );

  factory BehaviorEvent.genreFilterTap(String genre) => BehaviorEvent(
    type: BehaviorEventType.genreFilterTap,
    timestamp: DateTime.now(),
    payload: {'genre': genre},
  );

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'timestamp': timestamp.toIso8601String(),
    'payload': payload,
  };

  factory BehaviorEvent.fromJson(Map<String, dynamic> json) {
    return BehaviorEvent(
      type: BehaviorEventType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => BehaviorEventType.trackPlay,
      ),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
    );
  }
}
```

---

### 2.3 `StudioDnaDefaults` Model

**File:** `lib/features/creator_dna/domain/models/studio_dna_defaults.dart`

```dart
import 'package:flutter/foundation.dart';
import '../../studio/domain/models/studio_form_state.dart';

/// DNA-derived default values for the Studio form.
/// These are SUGGESTIONS, never forced values.
@immutable
class StudioDnaDefaults {
  final String genre;
  final String language;
  final TempoBracket tempo;
  final VocalEnergy vocalEnergy;
  final String mood;
  final bool hasDnaDefaults; // false when DNA is uninitialized

  const StudioDnaDefaults({
    this.genre = 'Amapiano',
    this.language = 'English',
    this.tempo = TempoBracket.medium,
    this.vocalEnergy = VocalEnergy.mid,
    this.mood = 'Uplifting',
    this.hasDnaDefaults = false,
  });

  const StudioDnaDefaults.empty() : this();
}
```

---

## 3. Repository Layer

### 3.1 `CreatorDnaRepository`

**File:** `lib/features/creator_dna/data/repositories/creator_dna_repository.dart`

```dart
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/creator_dna_profile.dart';
import '../../domain/models/behavior_event.dart';
import '../../../../core/constants/app_constants.dart';

class CreatorDnaRepository {
  static const _profileKey = 'dna_profile';
  static const _behaviorLogKey = 'behavior_log';
  static const _maxLogSize = 500;

  Box? _box;

  Future<void> _ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    try {
      _box = await Hive.openBox(AppConstants.creatorDnaBoxKey);
    } catch (_) {
      _box = null; // In-memory fallback
    }
  }

  Future<CreatorDnaProfile> loadProfile() async {
    await _ensureOpen();
    if (_box == null) return CreatorDnaProfile.initial();
    try {
      final raw = _box!.get(_profileKey);
      if (raw == null) return CreatorDnaProfile.initial();
      return CreatorDnaProfile.fromJson(Map<String, dynamic>.from(raw as Map));
    } catch (_) {
      return CreatorDnaProfile.initial();
    }
  }

  Future<void> saveProfile(CreatorDnaProfile profile) async {
    await _ensureOpen();
    if (_box == null) return;
    try {
      await _box!.put(_profileKey, profile.toJson());
    } catch (_) {}
  }

  Future<List<BehaviorEvent>> loadEventLog() async {
    await _ensureOpen();
    if (_box == null) return [];
    try {
      final raw = _box!.get(_behaviorLogKey);
      if (raw == null) return [];
      return (raw as List)
          .map((e) => BehaviorEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> appendEvent(BehaviorEvent event, List<BehaviorEvent> existingLog) async {
    await _ensureOpen();
    if (_box == null) return;
    final updatedLog = [...existingLog, event];
    final trimmed = updatedLog.length > _maxLogSize
        ? updatedLog.sublist(updatedLog.length - _maxLogSize)
        : updatedLog;
    try {
      await _box!.put(_behaviorLogKey, trimmed.map((e) => e.toJson()).toList());
    } catch (_) {}
  }

  Future<void> clearAll() async {
    await _ensureOpen();
    if (_box == null) return;
    try {
      await _box!.clear();
    } catch (_) {}
  }
}
```

---

## 4. State Management

### 4.1 `CreatorDnaNotifier`

**File:** `lib/features/creator_dna/presentation/providers/creator_dna_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/creator_dna_repository.dart';
import '../../domain/entities/creator_dna_profile.dart';
import '../../domain/models/behavior_event.dart';

class CreatorDnaNotifier extends StateNotifier<CreatorDnaProfile> {
  final CreatorDnaRepository _repo;
  List<BehaviorEvent> _eventLog = [];

  CreatorDnaNotifier(this._repo) : super(CreatorDnaProfile.initial()) {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final profile = await _repo.loadProfile();
    final log = await _repo.loadEventLog();
    _eventLog = log;
    if (mounted) state = profile;
  }

  /// Seed DNA from onboarding completion
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

  /// Record a passive behavior event and update DNA weights
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

  Future<void> dismissInsightCard() async {
    state = state.copyWith(dnaInsightCardDismissed: true);
    await _repo.saveProfile(state);
  }

  Future<void> resetDna() async {
    await _repo.clearAll();
    _eventLog = [];
    state = CreatorDnaProfile.initial();
  }
}

final creatorDnaRepositoryProvider = Provider<CreatorDnaRepository>((ref) {
  return CreatorDnaRepository();
});

final creatorDnaProvider = StateNotifierProvider<CreatorDnaNotifier, CreatorDnaProfile>((ref) {
  return CreatorDnaNotifier(ref.read(creatorDnaRepositoryProvider));
});
```

---

### 4.2 `dnaStudioDefaultsProvider`

**File:** `lib/features/creator_dna/presentation/providers/dna_studio_defaults_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/studio_dna_defaults.dart';
import '../../domain/entities/creator_dna_profile.dart';
import '../../../studio/domain/models/studio_form_state.dart';
import 'creator_dna_provider.dart';

final dnaStudioDefaultsProvider = Provider<StudioDnaDefaults>((ref) {
  final dna = ref.watch(creatorDnaProvider);

  if (!dna.onboardingCompleted || dna.genreWeights.isEmpty) {
    return const StudioDnaDefaults.empty();
  }

  final topGenre = dna.topGenres(1).firstOrNull ?? 'Amapiano';

  final tempo = _parseTempo(dna.tempoPreference);
  final energy = _parseEnergy(dna.vocalEnergyPreference);
  final topMood = dna.moodWeights.entries.isEmpty
      ? 'Uplifting'
      : (dna.moodWeights.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .first
          .key;

  return StudioDnaDefaults(
    genre: topGenre,
    language: dna.primaryLanguage,
    tempo: tempo,
    vocalEnergy: energy,
    mood: topMood,
    hasDnaDefaults: true,
  );
});

TempoBracket _parseTempo(String pref) => switch (pref) {
  'slow' => TempoBracket.slow,
  'fast' => TempoBracket.fast,
  'hyperspeed' => TempoBracket.veryFast,
  _ => TempoBracket.medium,
};

VocalEnergy _parseEnergy(String pref) => switch (pref) {
  'soft' => VocalEnergy.soft,
  'intense' => VocalEnergy.intense,
  _ => VocalEnergy.mid,
};
```

---

### 4.3 `DnaExploreRanker`

**File:** `lib/features/creator_dna/domain/services/dna_explore_ranker.dart`

```dart
import '../entities/creator_dna_profile.dart';

/// Pure Dart, synchronous client-side DNA affinity ranker.
/// No network calls. No async operations.
class DnaExploreRanker {
  const DnaExploreRanker._();

  /// Returns [tracks] sorted by DNA affinity score (descending).
  /// Tracks are assumed to carry [genre] and [language] metadata fields.
  static List<Map<String, dynamic>> rank(
    List<Map<String, dynamic>> tracks,
    CreatorDnaProfile dna,
  ) {
    if (!dna.onboardingCompleted) return tracks;
    final topGenres = dna.topGenres(2).toSet();
    final primaryLang = dna.primaryLanguage;

    double affinityScore(Map<String, dynamic> track) {
      double score = 0.0;
      final genre = track['genre'] as String?;
      final language = track['language'] as String?;
      if (genre != null && topGenres.contains(genre)) score += 0.30;
      if (language != null && language == primaryLang) score += 0.15;
      return score;
    }

    return [...tracks]..sort(
        (a, b) => affinityScore(b).compareTo(affinityScore(a)),
      );
  }
}
```

---

## 5. Presentation Layer

### 5.1 Widget: `DnaStrengthMeter`

**File:** `lib/features/creator_dna/presentation/widgets/dna_strength_meter.dart`

```dart
// Key: Key('dna_strength_meter')
// Parameters:
//   - int strengthPercent (0–100)
//   - bool animated (default true)
//   - double height (default 8.0)
//
// Renders an animated linear progress bar:
//   Track color: AppColors.surfaceSecondary
//   Fill color:  0–40%  → AppColors.accentElectric
//               40–70%  → AppColors.accentGold
//               70–100% → AppColors.accentSuccess
//
// AnimationController: duration 800ms, easeOut curve.
// Test bypass: animated = false disables AnimationController.
```

### 5.2 Widget: `DnaGenreBadge`

**File:** `lib/features/creator_dna/presentation/widgets/dna_genre_badge.dart`

```dart
// Key: Key('dna_genre_badge_$genre')
// Parameters:
//   - String genre
//   - int rank (1 or 2, determines token color)
//
// rank==1: AppColors.brandPrimary background
// rank==2: AppColors.accentElectric.withAlpha(30) background
// Typography: AppTypography.caption, bold
// Padding: AppSpacing.xs horizontal, AppSpacing.xxs vertical
// BorderRadius: AppRadius.pill
```

### 5.3 Widget: `CreativeRoleCard`

**File:** `lib/features/creator_dna/presentation/widgets/creative_role_card.dart`

```dart
// Key: Key('role_card_$roleKey')
// Parameters:
//   - String label  (e.g. 'Producer')
//   - String emoji  (e.g. '🎹')
//   - bool isSelected
//   - VoidCallback onTap
//
// Minimum size: BoxConstraints(minHeight: 56, minWidth: 200)
// Selected state:
//   border: Border.all(color: AppColors.brandPrimary, width: 2)
//   fill:   AppColors.brandPrimary.withAlpha(20)
// Unselected state:
//   border: Border.all(color: AppColors.borderSubtle)
//   fill:   AppColors.surfaceElevated
```

### 5.4 Widget: `DnaInsightCard`

**File:** `lib/features/creator_dna/presentation/widgets/dna_insight_card.dart`

```dart
// Key: Key('dna_insight_card')
// Displayed in: HomeDashboardView, inserted as first content card
// Dismissed via: Key('dna_insight_card_dismiss_button') × icon (44×44px hit target)
//
// Contents:
//   - Title: 'Your Creator DNA' with 🧬 icon
//   - DnaStrengthMeter (animated fill)
//   - Row of up to 2 DnaGenreBadge widgets
//   - Contextual tip string based on lifecycleState:
//       seeded:     'Keep exploring to grow your DNA'
//       learning:   'Play more ${topGenre} to strengthen your profile'
//       calibrated: 'Your DNA is shaping your studio defaults ✨'
//       attuned:    'Vhunambi knows your sound 🎯'
```

### 5.5 Updated `OnboardingView` (5-step)

**File:** `lib/features/onboarding/presentation/views/onboarding_view.dart` *(modify)*

```dart
// Existing 3 pages → Expand to 6 pages (Steps 0–5)
//
// Step 0: _buildWelcomeSlide()          ← existing, update copy only
// Step 1: _buildIdentitySlide()         ← NEW: role cards + experience level
// Step 2: _buildGenreSlide()            ← replaces old slide 1 genre section
//                                           (expanded to 18 genres in 3 groups)
// Step 3: _buildLanguageSlide()         ← replaces old slide 1 language section
//                                           (adds primaryLanguage designation)
// Step 4: _buildSoundSignatureSlide()   ← NEW: tempo + vocal energy + mood
// Step 5: _buildDnaActivationSlide()    ← replaces old slide 2 (ready screen)
//                                           Uses DnaActivationScreen widget
//
// OnboardingNotifier.completeOnboarding() call → replaced with:
//   ref.read(creatorDnaProvider.notifier).seedFromOnboarding(...)
//   then: ref.read(onboardingStateProvider.notifier).completeOnboarding()
//
// PageController: _pageController (6 pages, same pattern)
// Step indicator: 6 dots (expanded from 3)
```

---

## 6. Responsive Breakpoint Strategy

| Component | Mobile (<768px) | Desktop (>1024px) |
|---|---|---|
| `CreativeRoleCard` | Full-width cards, stacked | 2-column grid |
| `DnaGenreBadge` chips | Wrap layout, full chip width | Inline row, compact |
| `SoundSignaturePicker` | Stacked vertically per dimension | 3-column horizontal layout |
| `DnaInsightCard` | Full-width card | Max-width 480px centered card |
| Onboarding page padding | 24px all | 120px horizontal, centered |

---

## 7. Error Recovery & Offline Degradation

| Scenario | Behaviour |
|---|---|
| Hive box fails to open | `CreatorDnaRepository` silently falls back to `CreatorDnaProfile.initial()`. All surfaces degrade to defaults. No error shown to user. |
| `genreWeights` is empty on studio open | `dnaStudioDefaultsProvider.hasDnaDefaults == false`. Studio form uses existing hard-coded defaults. DNA chip banner NOT shown. |
| DNA reset during active session | `creatorDnaProvider` emits `CreatorDnaProfile.initial()`. All DNA-powered surfaces immediately revert to non-personalized state. |
| `BehaviorEvent` write fails | Silent no-op. DNA profile save is retried on next event. |
