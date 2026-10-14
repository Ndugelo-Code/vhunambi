# Design: Studio AI Cockpit v2

> **System:** M10 / `studio-ai-cockpit-v2`  
> **Status:** 🟡 SPECIFICATION

---

## 1. New Domain Models

### 1.1 `StudioSessionDraft`

**File:** `lib/features/studio/domain/models/studio_session_draft.dart`

```dart
import 'package:flutter/foundation.dart';

/// Persisted snapshot of in-progress StudioFormState (non-ephemeral fields only).
@immutable
class StudioSessionDraft {
  final String sessionId;
  final DateTime savedAt;
  final String prompt;
  final String genre;
  final String region;
  final String language;
  final bool isInstrumental;
  final int durationSeconds;
  final String lyricsMode;      // LyricsMode.name
  final String? customLyrics;
  final String mood;
  final String tempo;            // TempoBracket.name
  final String vocalVoices;     // VocalVoices.name
  final String vocalGender;     // VocalGender.name
  final String vocalMode;       // VocalMode.name
  final String vocalEnergy;     // VocalEnergy.name
  final String songStructure;   // SongStructure.name
  final bool isAutoTitle;
  final String? customTitle;
  final bool isPublic;
  final String? referenceAudioPath;
  final Map<String, dynamic> voiceProfileJson;
  final Map<String, dynamic> dialectInflectionJson;

  const StudioSessionDraft({
    required this.sessionId,
    required this.savedAt,
    required this.prompt,
    required this.genre,
    required this.region,
    required this.language,
    required this.isInstrumental,
    required this.durationSeconds,
    required this.lyricsMode,
    this.customLyrics,
    required this.mood,
    required this.tempo,
    required this.vocalVoices,
    required this.vocalGender,
    required this.vocalMode,
    required this.vocalEnergy,
    required this.songStructure,
    required this.isAutoTitle,
    this.customTitle,
    required this.isPublic,
    this.referenceAudioPath,
    required this.voiceProfileJson,
    required this.dialectInflectionJson,
  });

  /// Whether the session has meaningful content worth recovering.
  bool get hasContent =>
      prompt.isNotEmpty ||
      customLyrics != null ||
      genre != 'Amapiano'; // non-default state

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'savedAt': savedAt.toIso8601String(),
    'prompt': prompt,
    'genre': genre,
    'region': region,
    'language': language,
    'isInstrumental': isInstrumental,
    'durationSeconds': durationSeconds,
    'lyricsMode': lyricsMode,
    if (customLyrics != null) 'customLyrics': customLyrics,
    'mood': mood,
    'tempo': tempo,
    'vocalVoices': vocalVoices,
    'vocalGender': vocalGender,
    'vocalMode': vocalMode,
    'vocalEnergy': vocalEnergy,
    'songStructure': songStructure,
    'isAutoTitle': isAutoTitle,
    if (customTitle != null) 'customTitle': customTitle,
    'isPublic': isPublic,
    if (referenceAudioPath != null) 'referenceAudioPath': referenceAudioPath,
    'voiceProfileJson': voiceProfileJson,
    'dialectInflectionJson': dialectInflectionJson,
  };

  factory StudioSessionDraft.fromJson(Map<String, dynamic> json) {
    return StudioSessionDraft(
      sessionId: json['sessionId'] as String? ?? '',
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
      prompt: json['prompt'] as String? ?? '',
      genre: json['genre'] as String? ?? 'Amapiano',
      region: json['region'] as String? ?? 'South Africa',
      language: json['language'] as String? ?? 'English',
      isInstrumental: json['isInstrumental'] as bool? ?? false,
      durationSeconds: json['durationSeconds'] as int? ?? 30,
      lyricsMode: json['lyricsMode'] as String? ?? 'aiWrite',
      customLyrics: json['customLyrics'] as String?,
      mood: json['mood'] as String? ?? 'Uplifting',
      tempo: json['tempo'] as String? ?? 'medium',
      vocalVoices: json['vocalVoices'] as String? ?? 'solo',
      vocalGender: json['vocalGender'] as String? ?? 'male',
      vocalMode: json['vocalMode'] as String? ?? 'auto',
      vocalEnergy: json['vocalEnergy'] as String? ?? 'mid',
      songStructure: json['songStructure'] as String? ?? 'standard',
      isAutoTitle: json['isAutoTitle'] as bool? ?? true,
      customTitle: json['customTitle'] as String?,
      isPublic: json['isPublic'] as bool? ?? true,
      referenceAudioPath: json['referenceAudioPath'] as String?,
      voiceProfileJson: Map<String, dynamic>.from(
        json['voiceProfileJson'] as Map? ?? {},
      ),
      dialectInflectionJson: Map<String, dynamic>.from(
        json['dialectInflectionJson'] as Map? ?? {},
      ),
    );
  }
}
```

---

### 1.2 `OptionPreviewDescriptor`

**File:** `lib/features/studio/domain/models/option_preview_descriptor.dart`

```dart
import 'package:flutter/foundation.dart';

@immutable
class OptionPreviewDescriptor {
  final String emoji;
  final String title;
  final String description;        // Max 2 sentences
  final List<String> bestForGenres; // 2-3 genres

  const OptionPreviewDescriptor({
    required this.emoji,
    required this.title,
    required this.description,
    required this.bestForGenres,
  });
}

/// Compile-time constant library of all studio option previews.
const Map<String, OptionPreviewDescriptor> kStudioOptionPreviews = {
  // ── TempoBracket ────────────────────────────────────────────
  'tempo_slow': OptionPreviewDescriptor(
    emoji: '🌊',
    title: 'Slow (60–80 BPM)',
    description: 'Relaxed, introspective pace giving vocals space to breathe. '
        'Ideal for soulful ballads and spiritual reflection.',
    bestForGenres: ['Maskandi', 'Afro Soul', 'Gospel'],
  ),
  'tempo_medium': OptionPreviewDescriptor(
    emoji: '🎵',
    title: 'Medium (80–120 BPM)',
    description: 'The sweet spot for most African popular music. '
        'Energetic yet comfortable for melodic phrasing and hook delivery.',
    bestForGenres: ['Amapiano', 'Afrobeats', 'R&B'],
  ),
  'tempo_fast': OptionPreviewDescriptor(
    emoji: '⚡',
    title: 'Fast (120–145 BPM)',
    description: 'High-energy club tempo driving dancefloor movement. '
        'Vocals need tight delivery with minimal breath pauses.',
    bestForGenres: ['Afro House', 'Kwaito', 'Dancehall'],
  ),
  'tempo_veryFast': OptionPreviewDescriptor(
    emoji: '🔥',
    title: 'Hyperspeed (145+ BPM)',
    description: 'Extreme BPM for percussion-heavy electronic club bangers. '
        'Vocals are often chanted, not sung.',
    bestForGenres: ['Gqom', 'Electronic', 'Hip Hop'],
  ),

  // ── VocalMode ────────────────────────────────────────────────
  'vocalMode_auto': OptionPreviewDescriptor(
    emoji: '✦',
    title: 'Auto',
    description: 'The AI selects the most genre-appropriate vocal delivery style. '
        'Best for beginners or when you want the system to decide.',
    bestForGenres: ['Any'],
  ),
  'vocalMode_melodic': OptionPreviewDescriptor(
    emoji: '🎤',
    title: 'Melodic Singing',
    description: 'Traditional sustained notes and melodic phrasing with vibrato and runs. '
        'The most expressive and emotionally resonant delivery mode.',
    bestForGenres: ['Amapiano', 'Afro Soul', 'Gospel'],
  ),
  'vocalMode_rap': OptionPreviewDescriptor(
    emoji: '🎙️',
    title: 'Rap / Flow',
    description: 'Rhythmic syllabic delivery emphasizing timing, rhyme, and lyrical density. '
        'Sits in the pocket of the beat rather than over it.',
    bestForGenres: ['Hip Hop', 'Gqom', 'Afrobeats'],
  ),
  'vocalMode_spokenWord': OptionPreviewDescriptor(
    emoji: '📢',
    title: 'Spoken Word',
    description: 'Rhythmic non-melodic delivery close to traditional oral storytelling (izibongo). '
        'Powerful for narrative, poetry, and praise singing.',
    bestForGenres: ['Maskandi', 'Afro Soul', 'Any'],
  ),
  'vocalMode_choir': OptionPreviewDescriptor(
    emoji: '🎵',
    title: 'Choir / Harmonies',
    description: 'Multi-part harmonic vocal stacking simulating a full gospel or traditional choir. '
        'Rich, layered, and deeply communal.',
    bestForGenres: ['Gospel', 'Afro Soul', 'Maskandi'],
  ),

  // ── VocalEnergy ──────────────────────────────────────────────
  'vocalEnergy_soft': OptionPreviewDescriptor(
    emoji: '🌙',
    title: 'Soft / Intimate',
    description: 'Breathy, close-mic delivery evoking vulnerability and intimacy. '
        'Perfect for late-night reflective tracks.',
    bestForGenres: ['Afro Soul', 'R&B', 'Amapiano'],
  ),
  'vocalEnergy_mid': OptionPreviewDescriptor(
    emoji: '🎤',
    title: 'Balanced',
    description: 'Versatile mid-energy delivery that works across most genres and moods. '
        'Neither too restrained nor too intense.',
    bestForGenres: ['Amapiano', 'Afrobeats', 'Any'],
  ),
  'vocalEnergy_intense': OptionPreviewDescriptor(
    emoji: '🔥',
    title: 'High Intensity',
    description: 'Full-projection powerful delivery with grit and urgency. '
        'Best for anthems, hype tracks, and praise songs.',
    bestForGenres: ['Gqom', 'Gospel', 'Hip Hop'],
  ),

  // ── SongStructure ────────────────────────────────────────────
  'structure_standard': OptionPreviewDescriptor(
    emoji: '📋',
    title: 'Standard',
    description: 'Classic Intro → Verse → Chorus → Verse → Chorus → Outro structure. '
        'The most familiar and radio-friendly format.',
    bestForGenres: ['Amapiano', 'Afrobeats', 'R&B'],
  ),
  'structure_extended': OptionPreviewDescriptor(
    emoji: '⏱️',
    title: 'Extended',
    description: 'Adds a Bridge and additional verse to create a longer, more developed narrative arc. '
        'Good for concept songs and storytelling.',
    bestForGenres: ['Maskandi', 'Gospel', 'Afro Soul'],
  ),
  'structure_freestyle': OptionPreviewDescriptor(
    emoji: '🌊',
    title: 'Freestyle',
    description: 'Unstructured flow — the AI generates sections dynamically based on lyrical energy. '
        'Unpredictable and experimental.',
    bestForGenres: ['Hip Hop', 'Electronic', 'Any'],
  ),
  'structure_loop': OptionPreviewDescriptor(
    emoji: '🔁',
    title: 'Loop',
    description: 'Single repeated section with variation — great for DJ tools, hooklines, and interludes. '
        'Typically 30–60 seconds.',
    bestForGenres: ['Gqom', 'Afro House', 'Electronic'],
  ),

  // ── LyricsMode ───────────────────────────────────────────────
  'lyricsMode_aiWrite': OptionPreviewDescriptor(
    emoji: '✨',
    title: 'AI Writes',
    description: 'The AI generates culturally relevant lyrics from your prompt and genre. '
        'You review and edit before generation.',
    bestForGenres: ['Any'],
  ),
  'lyricsMode_myOwn': OptionPreviewDescriptor(
    emoji: '✍️',
    title: 'My Own Lyrics',
    description: 'You write every lyric line — either freeform or with the step-by-step Guided Composer. '
        'Full creative control.',
    bestForGenres: ['Any'],
  ),
  'lyricsMode_fromPhoto': OptionPreviewDescriptor(
    emoji: '📷',
    title: 'From Photo',
    description: 'Import lyrics from a handwritten page or printed sheet via camera capture. '
        'OCR extracts the text automatically.',
    bestForGenres: ['Any'],
  ),
  'lyricsMode_instrumental': OptionPreviewDescriptor(
    emoji: '🎹',
    title: 'Instrumental',
    description: 'No vocals — pure instrumental arrangement based on genre, tempo, and mood. '
        'Perfect for beats, background music, and production stems.',
    bestForGenres: ['Amapiano', 'Gqom', 'Afro House'],
  ),
};
```

---

### 1.3 `PromptEnhancementResult`

**File:** `lib/features/studio/domain/models/prompt_enhancement_result.dart`

```dart
import 'package:flutter/foundation.dart';

@immutable
class PromptEnhancementResult {
  final String enhancedPrompt;
  final Map<String, dynamic> suggestedOverrides; // field name → suggested value

  const PromptEnhancementResult({
    required this.enhancedPrompt,
    this.suggestedOverrides = const {},
  });

  bool get hasOverrides => suggestedOverrides.isNotEmpty;
}
```

---

### 1.4 `LyricsSectionScaffold`

**File:** `lib/features/studio/domain/models/lyrics_section_scaffold.dart`

```dart
import 'package:flutter/foundation.dart';
import 'lyrics_review_models.dart';

/// Atmosphere descriptor for a specific genre + section type combination.
@immutable
class AtmosphereDescriptor {
  final String label;
  final String emoji;

  const AtmosphereDescriptor({required this.label, required this.emoji});
}

/// Guided composer section configuration: section type, title, prompt copy.
@immutable
class LyricsSectionScaffold {
  final LyricsSectionType type;
  final String title;
  final String guidanceText;  // "Set the scene. Introduce the mood."
  final bool isOptional;

  const LyricsSectionScaffold({
    required this.type,
    required this.title,
    required this.guidanceText,
    this.isOptional = false,
  });
}

/// Fixed sequence of guided composer sections (6 total).
const List<LyricsSectionScaffold> kGuidedComposerScaffold = [
  LyricsSectionScaffold(
    type: LyricsSectionType.intro,
    title: 'Intro',
    guidanceText: 'Set the scene. Introduce the mood and atmosphere.',
  ),
  LyricsSectionScaffold(
    type: LyricsSectionType.verse,
    title: 'Verse 1',
    guidanceText: 'Tell your story. Develop the narrative.',
  ),
  LyricsSectionScaffold(
    type: LyricsSectionType.chorus,
    title: 'Chorus',
    guidanceText: 'Your hook. The part everyone will remember.',
  ),
  LyricsSectionScaffold(
    type: LyricsSectionType.verse,
    title: 'Verse 2',
    guidanceText: 'Deepen the story. Reveal something new.',
    isOptional: true,
  ),
  LyricsSectionScaffold(
    type: LyricsSectionType.bridge,
    title: 'Bridge',
    guidanceText: 'The emotional turning point. Contrast with the chorus.',
    isOptional: true,
  ),
  LyricsSectionScaffold(
    type: LyricsSectionType.outro,
    title: 'Outro',
    guidanceText: 'Bring it home. Close the song with intention.',
  ),
];
```

---

## 2. Domain Services

### 2.1 `StudioPromptIntelligence`

**File:** `lib/features/studio/domain/services/studio_prompt_intelligence.dart`

```dart
import '../models/prompt_enhancement_result.dart';
// import from creator_dna feature:
// import '../../../creator_dna/domain/entities/creator_dna_profile.dart';

/// Pure Dart, synchronous prompt intelligence service.
/// Zero async. Zero network calls. Pure text processing + DNA merge.
class StudioPromptIntelligence {
  const StudioPromptIntelligence._();

  // Genre keyword → canonical genre name
  static const _genreKeywords = {
    'amapiano': 'Amapiano', 'piano': 'Amapiano',
    'gqom': 'Gqom', 'gqom': 'Gqom',
    'kwaito': 'Kwaito', 'maskandi': 'Maskandi',
    'afrobeats': 'Afrobeats', 'afro beats': 'Afrobeats',
    'gospel': 'Gospel', 'highlife': 'Highlife',
    'hip hop': 'Hip Hop', 'hiphop': 'Hip Hop', 'rap': 'Hip Hop',
    'r&b': 'R&B', 'rnb': 'R&B', 'soul': 'Afro Soul',
    'afro house': 'Afro House', 'house': 'Afro House',
  };

  // Language keyword → canonical language name
  static const _languageKeywords = {
    'zulu': 'isiZulu', 'isizulu': 'isiZulu',
    'venda': 'Tshivenḓa', 'tshivenda': 'Tshivenḓa', 'tshivenḓa': 'Tshivenḓa',
    'xhosa': 'isiXhosa', 'isixhosa': 'isiXhosa',
    'sotho': 'Sepedi', 'sepedi': 'Sepedi', 'pedi': 'Sepedi',
    'setswana': 'Setswana', 'tswana': 'Setswana',
    'xitsonga': 'Xitsonga', 'tsonga': 'Xitsonga',
    'english': 'English',
  };

  static const _femaleKeywords = ['female', 'woman', 'girl', 'lady', 'she'];
  static const _maleKeywords   = ['male', 'man', 'guy', 'he', 'boy'];
  static const _moodUplifting  = ['happy', 'uplifting', 'joy', 'celebration', 'vibrant'];
  static const _moodDark       = ['dark', 'sad', 'melancholy', 'pain', 'hurt'];
  static const _moodSpiritual  = ['spiritual', 'prayer', 'church', 'god', 'ancestors'];

  static PromptEnhancementResult enhance(
    String rawPrompt,
    // CreatorDnaProfile? dna,
  ) {
    final lower = rawPrompt.toLowerCase();
    final overrides = <String, dynamic>{};

    // Genre detection
    for (final entry in _genreKeywords.entries) {
      if (lower.contains(entry.key)) {
        overrides['genre'] = entry.value;
        break;
      }
    }

    // Language detection
    for (final entry in _languageKeywords.entries) {
      if (lower.contains(entry.key)) {
        overrides['language'] = entry.value;
        break;
      }
    }

    // Gender detection
    if (_femaleKeywords.any(lower.contains)) {
      overrides['vocalGender'] = 'female';
    } else if (_maleKeywords.any(lower.contains)) {
      overrides['vocalGender'] = 'male';
    }

    // Mood detection
    if (_moodUplifting.any(lower.contains)) {
      overrides['mood'] = 'Uplifting';
    } else if (_moodDark.any(lower.contains)) {
      overrides['mood'] = 'Melancholic';
    } else if (_moodSpiritual.any(lower.contains)) {
      overrides['mood'] = 'Peaceful';
    }

    // Merge DNA overrides for blanks (when DNA is connected in M10 implementation)
    // if (dna != null && dna.onboardingCompleted) {
    //   overrides.putIfAbsent('genre', () => dna.topGenres(1).firstOrNull ?? 'Amapiano');
    //   overrides.putIfAbsent('language', () => dna.primaryLanguage);
    // }

    // Build enhanced prompt
    final genre = overrides['genre'] as String? ?? 'music';
    final lang = overrides['language'] as String?;
    final gender = overrides['vocalGender'] as String?;

    final enhanced = _buildEnhancedPrompt(rawPrompt, genre, lang, gender);

    return PromptEnhancementResult(
      enhancedPrompt: enhanced,
      suggestedOverrides: overrides,
    );
  }

  static String _buildEnhancedPrompt(
    String original, String genre, String? lang, String? gender,
  ) {
    final parts = <String>[];
    parts.add(original.trim());
    if (lang != null) parts.add('with $lang vocal delivery');
    if (gender != null) parts.add('performed by a $gender vocalist');
    return parts.join(', ') + '.';
  }
}
```

---

### 2.2 `IBantuTranslationService`

**File:** `lib/features/studio/domain/services/i_bantu_translation_service.dart`

```dart
abstract interface class IBantuTranslationService {
  Future<String> translate({
    required String text,
    required String fromLanguage,
    required String toLanguage,
  });
}
```

**Implementation stub:** `lib/features/studio/data/services/fake_bantu_translation_service.dart`
```dart
class FakeBantuTranslationService implements IBantuTranslationService {
  @override
  Future<String> translate({
    required String text,
    required String fromLanguage,
    required String toLanguage,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return '[Translated to $toLanguage]: $text';
  }
}
```

---

## 3. Repository

### 3.1 `StudioSessionRepository`

**File:** `lib/features/studio/data/services/studio_session_repository.dart`

```dart
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/models/studio_session_draft.dart';
import '../../../../core/constants/app_constants.dart';

class StudioSessionRepository {
  static const _draftKey = 'current_draft';
  Box? _box;

  Future<void> _ensureOpen() async {
    if (_box != null && _box!.isOpen) return;
    try {
      _box = await Hive.openBox(AppConstants.studioSessionBoxKey);
    } catch (_) { _box = null; }
  }

  Future<bool> hasSavedSession() async {
    await _ensureOpen();
    if (_box == null) return false;
    try {
      final raw = _box!.get(_draftKey);
      if (raw == null) return false;
      final draft = StudioSessionDraft.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      return draft.hasContent;
    } catch (_) { return false; }
  }

  Future<StudioSessionDraft?> loadSession() async {
    await _ensureOpen();
    if (_box == null) return null;
    try {
      final raw = _box!.get(_draftKey);
      if (raw == null) return null;
      return StudioSessionDraft.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
    } catch (_) { return null; }
  }

  Future<void> saveSession(StudioSessionDraft draft) async {
    await _ensureOpen();
    if (_box == null) return;
    try { await _box!.put(_draftKey, draft.toJson()); } catch (_) {}
  }

  Future<void> clearSession() async {
    await _ensureOpen();
    if (_box == null) return;
    try { await _box!.delete(_draftKey); } catch (_) {}
  }
}
```

---

## 4. Provider Layer

### 4.1 `StudioSessionNotifier`

**File:** `lib/features/studio/presentation/providers/studio_session_provider.dart`

```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/studio_session_repository.dart';
import '../../domain/models/studio_session_draft.dart';
import 'studio_form_provider.dart';

enum SessionRecoveryState { none, available, dismissed, resumed }

class StudioSessionState {
  final SessionRecoveryState recoveryState;
  final StudioSessionDraft? savedDraft;

  const StudioSessionState({
    this.recoveryState = SessionRecoveryState.none,
    this.savedDraft,
  });
}

class StudioSessionNotifier extends StateNotifier<StudioSessionState> {
  final StudioSessionRepository _repo;
  final Ref _ref;
  Timer? _debounceTimer;

  StudioSessionNotifier(this._repo, this._ref)
      : super(const StudioSessionState()) {
    _checkForSavedSession();
  }

  Future<void> _checkForSavedSession() async {
    final hasSaved = await _repo.hasSavedSession();
    if (!hasSaved) return;
    final draft = await _repo.loadSession();
    if (draft != null && mounted) {
      state = StudioSessionState(
        recoveryState: SessionRecoveryState.available,
        savedDraft: draft,
      );
    }
  }

  /// Debounced auto-save — called from studioFormProvider listener.
  void scheduleAutoSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), _performSave);
  }

  /// Immediate save — called for lyrics changes.
  void immediateSave() {
    _debounceTimer?.cancel();
    _performSave();
  }

  void _performSave() {
    final formState = _ref.read(studioFormProvider);
    // Build draft from current form state
    final draft = StudioSessionDraft(
      sessionId: 'session_${DateTime.now().millisecondsSinceEpoch}',
      savedAt: DateTime.now(),
      prompt: formState.prompt,
      genre: formState.genre,
      region: formState.region,
      language: formState.language,
      isInstrumental: formState.isInstrumental,
      durationSeconds: formState.durationSeconds,
      lyricsMode: formState.lyricsMode.name,
      customLyrics: formState.customLyrics,
      mood: formState.mood,
      tempo: formState.tempo.name,
      vocalVoices: formState.vocalVoices.name,
      vocalGender: formState.vocalGender.name,
      vocalMode: formState.vocalMode.name,
      vocalEnergy: formState.vocalEnergy.name,
      songStructure: formState.songStructure.name,
      isAutoTitle: formState.isAutoTitle,
      customTitle: formState.customTitle,
      isPublic: formState.isPublic,
      referenceAudioPath: formState.referenceAudioPath,
      voiceProfileJson: formState.selectedVoiceProfile.toJson(),
      dialectInflectionJson: formState.dialectInflection.toJson(),
    );
    _repo.saveSession(draft); // unawaited — fire and forget
  }

  void resumeSession(StudioSessionDraft draft) {
    // Apply draft back to studioFormProvider
    final notifier = _ref.read(studioFormProvider.notifier);
    notifier.updatePrompt(draft.prompt);
    notifier.setGenre(draft.genre);
    notifier.setRegion(draft.region);
    notifier.setLanguage(draft.language);
    if (draft.customLyrics != null) {
      notifier.setCustomLyrics(draft.customLyrics!);
    }
    state = state.copyWith(recoveryState: SessionRecoveryState.resumed);
  }

  void dismissRecovery() {
    state = state.copyWith(recoveryState: SessionRecoveryState.dismissed);
  }

  void clearSession() {
    _repo.clearSession();
    state = const StudioSessionState();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

extension on StudioSessionState {
  StudioSessionState copyWith({
    SessionRecoveryState? recoveryState,
    StudioSessionDraft? savedDraft,
  }) => StudioSessionState(
    recoveryState: recoveryState ?? this.recoveryState,
    savedDraft: savedDraft ?? this.savedDraft,
  );
}

final studioSessionRepositoryProvider = Provider<StudioSessionRepository>(
  (ref) => StudioSessionRepository(),
);

final studioSessionProvider =
    StateNotifierProvider<StudioSessionNotifier, StudioSessionState>((ref) {
  return StudioSessionNotifier(
    ref.read(studioSessionRepositoryProvider),
    ref,
  );
});
```

---

## 5. Presentation Widgets

### 5.1 `StudioSessionRecoveryBanner`
```dart
// Key: Key('studio_session_recovery_banner')
// Placement: Top of Compose tab ScrollView content, above PromptInputBox
// Shown when: studioSessionProvider.recoveryState == SessionRecoveryState.available
//
// Layout:
//   ┌──────────────────────────────────────────────────────┐
//   │ ↩ Unfinished session: "Amapiano anthem..." (2h ago)  │
//   │                     [Resume]  [Start Fresh]    [×]  │
//   └──────────────────────────────────────────────────────┘
//
// Colors: AppColors.accentGold.withAlpha(15) background
//         AppColors.accentGold border
// Resume: Key('studio_session_resume_btn')
// Fresh: Key('studio_session_start_fresh_btn')
// Dismiss: Key('studio_session_dismiss_banner')
```

### 5.2 `PromptIntelligenceOverlay`
```dart
// Key: Key('prompt_intelligence_overlay')
// Placement: AnimatedSize container below PromptInputBox text field
// Shown when: typing pause ≥1500ms AND prompt.length ≥10
//
// Contents:
//   - Enhanced prompt text in AppColors.surfaceSecondary container
//   - Wrap row of AutoFillChip per detected override
//   - [Apply All] Key('prompt_intelligence_apply_all')
//   - Dismiss × Key('prompt_intelligence_dismiss')
//
// AutoFillChip keys: Key('autofill_chip_$fieldName')
// AutoFillChip dismiss: Key('autofill_chip_dismiss_$fieldName')
```

### 5.3 `OptionPreviewChip`
```dart
// Key: Key('option_preview_chip_$optionKey')
// Usage: Replaces plain chip widgets in AdvancedOptionsAccordion
//
// Parameters:
//   - String optionKey     (e.g. 'tempo_fast')
//   - String label         (e.g. 'Fast')
//   - bool isSelected
//   - VoidCallback onTap   (main chip tap)
//
// Layout: [Label]  [ⓘ]
//   ⓘ button: Key('option_preview_info_$optionKey'), 44×44px hit target
//
// On ⓘ tap: shows OptionPreviewCard overlay
//   Card key: Key('option_preview_card_$optionKey')
//   Got It key: Key('option_preview_got_it_$optionKey')
```

### 5.4 `GuidedLyricsComposer`
```dart
// Routing: showModalBottomSheet (mobile, 95% height) / showDialog (desktop)
// Key: Key('guided_lyrics_composer')
//
// State: List<LyricsSectionScaffold> scaffolds = kGuidedComposerScaffold
//        int currentIndex = 0
//        Map<String, List<String>> sectionLines = {}
//
// Per-section layout:
//   - Section title + guidance text
//   - TextArea for lyrics lines
//   - Atmosphere descriptor chips from kGenreAtmosphereLibrary
//   - AI hint panel (shows after 2000ms typing pause, max 1 hint)
//   - BantuLanguageSwitcher chip row
//   - Navigation: [← Back] [Skip Section] [Next →]
//
// Step indicator: Key('guided_composer_step_indicator')
// Current step: Key('guided_composer_section_$sectionType')
// Next button: Key('guided_composer_next_btn')
// Done button: Key('guided_composer_done_btn')  (on last section)
```

### 5.5 `BantuLanguageSwitcher`
```dart
// Key: Key('bantu_language_switcher')
// Placement: GuidedLyricsComposer header AND LyricsReviewModal header
//
// Renders horizontal scrollable chip row of 8 languages
// Active language chip uses AppColors.brandPrimary selected state
// On language change: shows AlertDialog confirmation
// During translation: shows blurred overlay with CircularProgressIndicator
// After translation: shows 🌐 badge on translated section card
//
// Chip key: Key('bantu_lang_chip_$language')
// Translate confirm: Key('bantu_translate_confirm_btn')
```

### 5.6 `GenreAtmosphereSampleDeck`
```dart
// Key: Key('genre_atmosphere_sample_deck')
// Placement: Compose tab, between RegionalGenreSelector and AdvancedOptionsAccordion
// Default state: collapsed (accordion pattern, same as RegionalGenreSelector)
//
// Responds to: studioFormProvider.select((s) => s.genre)
// On genre change: animates to new genre's sample set
//
// Sample button key: Key('sample_play_btn_$sampleId')
// Add to palette key: Key('sample_add_palette_$sampleId')
// Palette row key: Key('generation_palette_row')
```

---

## 6. Genre Atmosphere Library (Constant Map Extract)

```dart
// Full constant in: lib/features/studio/domain/models/lyrics_section_scaffold.dart

const Map<String, Map<String, List<AtmosphereDescriptor>>> kGenreAtmosphereLibrary = {
  'Amapiano': {
    'intro': [
      AtmosphereDescriptor(label: 'Deep log drum opening', emoji: '🥁'),
      AtmosphereDescriptor(label: 'Soft piano arpeggios', emoji: '🎹'),
      AtmosphereDescriptor(label: 'Township ambient sound bed', emoji: '🏙️'),
      AtmosphereDescriptor(label: 'Gentle fade-in bass pulse', emoji: '🎵'),
    ],
    'verse': [
      AtmosphereDescriptor(label: 'Rhythmic log drum groove', emoji: '🥁'),
      AtmosphereDescriptor(label: 'Jazz chord stabs', emoji: '🎷'),
      AtmosphereDescriptor(label: 'Steady 4-on-the-floor kick', emoji: '👟'),
    ],
    'chorus': [
      AtmosphereDescriptor(label: 'Full choir call-and-response', emoji: '🎵'),
      AtmosphereDescriptor(label: 'Log drum build with brass stab', emoji: '🎺'),
      AtmosphereDescriptor(label: 'Melodic vocal hook repeat', emoji: '🎤'),
    ],
    'outro': [
      AtmosphereDescriptor(label: 'Fade-out log drum roll', emoji: '🥁'),
      AtmosphereDescriptor(label: 'Piano resolution chord', emoji: '🎹'),
    ],
  },
  'Gqom': {
    'intro': [
      AtmosphereDescriptor(label: '808 sub bass build', emoji: '💥'),
      AtmosphereDescriptor(label: 'Dark synth swell', emoji: '🌑'),
      AtmosphereDescriptor(label: 'Metallic clap pattern', emoji: '⚡'),
    ],
    // ... all other genres follow same pattern
  },
  // Maskandi, Afrobeats, Kwaito, Gospel, R&B, Hip Hop — all 18 genres
};
```

---

## 7. Kinetic Physics & Haptic Architecture

### 7.1 `StudioHaptics` Service

**File:** `lib/features/studio/presentation/utils/studio_haptics.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Centralized, platform-safe haptic dispatcher for Studio micro-interactions.
///
/// Automatically no-ops on Web and unsupported platforms to prevent crashes.
class StudioHaptics {
  StudioHaptics._();

  static bool _enabled = true;

  /// Globally toggle haptics (e.g., from settings or reduced motion preferences).
  static void setEnabled(bool enabled) => _enabled = enabled;

  /// Heavy impact: Triggered when firing generative models, stem splitting, or MPC slicing.
  static void ignitionThump() {
    if (!_enabled || kIsWeb) return;
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Medium crisp impact: Triggered on deck/tab changes, accordion toggles, or stanza additions.
  static void deckSwitch() {
    if (!_enabled || kIsWeb) return;
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Light crisp impact: Triggered on option chip selection, language toggle, or card tap.
  static void chipSnap() {
    if (!_enabled || kIsWeb) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Selection click: Triggered on slider scrubbing, detent snaps, and fine value increments.
  static void sliderTick() {
    if (!_enabled || kIsWeb) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Success pulse: Triggered on ghost session restore or prompt auto-refinement.
  static void successPulse() {
    if (!_enabled || kIsWeb) return;
    try {
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          HapticFeedback.lightImpact();
        } catch (_) {}
      });
    } catch (_) {}
  }
}
```

### 7.2 `TactilePressable` Widget

**File:** `lib/features/studio/presentation/widgets/tactile_pressable.dart`

```dart
import 'package:flutter/material.dart';
import '../utils/studio_haptics.dart';

enum TactileHapticType { none, light, medium, heavy, selection }

/// Drop-in micro-interaction wrapper providing spring-down scale and haptic feedback.
class TactilePressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final TactileHapticType hapticType;
  final double pressedScale;
  final Duration pressDuration;
  final Duration releaseDuration;

  const TactilePressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.hapticType = TactileHapticType.light,
    this.pressedScale = 0.96,
    this.pressDuration = const Duration(milliseconds: 80),
    this.releaseDuration = const Duration(milliseconds: 220),
  });

  @override
  State<TactilePressable> createState() => _TactilePressableState();
}

class _TactilePressableState extends State<TactilePressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.pressDuration,
      reverseDuration: widget.releaseDuration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    switch (widget.hapticType) {
      case TactileHapticType.light:
        StudioHaptics.chipSnap();
        break;
      case TactileHapticType.medium:
        StudioHaptics.deckSwitch();
        break;
      case TactileHapticType.heavy:
        StudioHaptics.ignitionThump();
        break;
      case TactileHapticType.selection:
        StudioHaptics.sliderTick();
        break;
      case TactileHapticType.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (disableAnimations) {
      return GestureDetector(
        onTap: () {
          _triggerHaptic();
          widget.onTap?.call();
        },
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: widget.child,
      );
    }

    return GestureDetector(
      onTapDown: (_) {
        _triggerHaptic();
        _controller.forward();
      },
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
```

### 7.3 `FluidDeckSwitcher` (Elastic Tab Bar)

**File:** `lib/features/studio/presentation/widgets/fluid_deck_switcher.dart`

```dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../utils/studio_haptics.dart';

/// Kinetic tab navigation with sliding pill and tactile feedback.
class FluidDeckSwitcher extends StatelessWidget {
  final int activeIndex;
  final List<String> tabLabels;
  final ValueChanged<int> onTabSelected;

  const FluidDeckSwitcher({
    super.key,
    required this.activeIndex,
    required this.tabLabels,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = (constraints.maxWidth - 8) / tabLabels.length;
          return Stack(
            children: [
              // Sliding active pill
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: activeIndex * tabWidth,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary,
                    borderRadius: AppRadius.pillBorder,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandPrimary.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // Tab labels
              Row(
                children: List.generate(tabLabels.length, (index) {
                  final isSelected = index == activeIndex;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (index != activeIndex) {
                          StudioHaptics.deckSwitch();
                          onTabSelected(index);
                        }
                      },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: AppTypography.labelLarge.copyWith(
                            color: isSelected
                                ? AppColors.brandContrast
                                : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          child: Text(
                            tabLabels[index],
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

### 7.4 `PulsingAuraContainer`

**File:** `lib/features/studio/presentation/widgets/pulsing_aura_container.dart`

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Animated container with breathing glow aura for AI refinement or generation.
class PulsingAuraContainer extends StatefulWidget {
  final Widget child;
  final bool isPulsing;
  final BorderRadius borderRadius;

  const PulsingAuraContainer({
    super.key,
    required this.child,
    this.isPulsing = false,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<PulsingAuraContainer> createState() => _PulsingAuraContainerState();
}

class _PulsingAuraContainerState extends State<PulsingAuraContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.isPulsing) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulsingAuraContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing && !oldWidget.isPulsing) {
      _controller.repeat(reverse: true);
    } else if (!widget.isPulsing && oldWidget.isPulsing) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPulsing) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glowOpacity = 0.15 + 0.25 * math.sin(_controller.value * math.pi);
        return Container(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: [
              BoxShadow(
                color: AppColors.brandPrimary.withOpacity(glowOpacity),
                blurRadius: 16 + 8 * _controller.value,
                spreadRadius: 2 + 2 * _controller.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
```

