# Phase 3 Design Specification: Studio Creation Cockpit (`/create`)

> **Package:** `apps/vhunambi_client`  
> **Feature Directory:** `lib/features/studio/`  
> **State Engine:** Riverpod 2.x+ (`StateNotifierProvider`)

---

## 1. Domain Models & Enums

### 1.1 Enums (`lib/features/studio/domain/models/studio_form_state.dart`)
```dart
enum LyricsMode { aiWrite, myOwn, fromPhoto, instrumental }
enum TempoBracket { slow, medium, fast, veryFast }
enum VocalVoices { solo, duet, choir }
enum VocalGender { male, female, mixed }
enum VocalMode { auto, melodic, rap, spokenWord, choir }
enum VocalEnergy { soft, mid, intense }
enum SongStructure { standard, extended, freestyle, loop }
enum GenerationPhase { idle, generatingLyrics, reviewingLyrics, queued, processing, ready, failed }
```

### 1.2 `StudioFormState` Class
```dart
@immutable
class StudioFormState {
  final String prompt;
  final String? referenceAudioPath;
  final String genre;
  final String region;
  final String language;
  final bool isInstrumental;
  final int durationSeconds;
  final LyricsMode lyricsMode;
  final String? customLyrics;
  final String mood;
  final TempoBracket tempo;
  final VocalVoices vocalVoices;
  final VocalGender vocalGender;
  final VocalMode vocalMode;
  final VocalEnergy vocalEnergy;
  final SongStructure songStructure;
  final bool isAutoTitle;
  final String? customTitle;
  final bool isPublic;
  final GenerationPhase phase;
  final double generationProgress;
  final String? errorMessage;

  const StudioFormState({
    this.prompt = '',
    this.referenceAudioPath,
    this.genre = 'Amapiano',
    this.region = 'South Africa',
    this.language = 'English',
    this.isInstrumental = false,
    this.durationSeconds = 30,
    this.lyricsMode = LyricsMode.aiWrite,
    this.customLyrics,
    this.mood = 'Uplifting',
    this.tempo = TempoBracket.medium,
    this.vocalVoices = VocalVoices.solo,
    this.vocalGender = VocalGender.male,
    this.vocalMode = VocalMode.auto,
    this.vocalEnergy = VocalEnergy.mid,
    this.songStructure = SongStructure.standard,
    this.isAutoTitle = true,
    this.customTitle,
    this.isPublic = true,
    this.phase = GenerationPhase.idle,
    this.generationProgress = 0.0,
    this.errorMessage,
  });

  StudioFormState copyWith({ ... });
}
```

---

## 2. State Management & Notifier Design

### 2.1 `StudioFormNotifier` (`lib/features/studio/presentation/providers/studio_form_provider.dart`)
```dart
final studioFormProvider =
    StateNotifierProvider<StudioFormNotifier, StudioFormState>((ref) {
  return StudioFormNotifier();
});

class StudioFormNotifier extends StateNotifier<StudioFormState> {
  StudioFormNotifier() : super(const StudioFormState());

  void updatePrompt(String prompt);
  void setGenre(String genre);
  void setRegion(String region);
  void setLanguage(String language);
  void toggleInstrumental(bool value);
  void setDurationSeconds(int seconds);
  void setLyricsMode(LyricsMode mode);
  void setCustomLyrics(String lyrics);
  void setMood(String mood);
  void setTempo(TempoBracket tempo);
  void setVocalVoices(VocalVoices voices);
  void setVocalGender(VocalGender gender);
  void setVocalMode(VocalMode mode);
  void setVocalEnergy(VocalEnergy energy);
  void setSongStructure(SongStructure structure);
  void toggleAutoTitle(bool auto);
  void setCustomTitle(String title);
  void togglePublic(bool isPublic);
  void setReferenceAudio(String? path);
  void applyPromptPreset(String preset);
  void inspireMe();
  void triggerGeneration();
  void reset();
}
```

---

## 3. UI Component Specifications

### 3.1 Component Hierarchy
```
StudioView
├── StudioAppBar (Sticky top bar)
└── SingleChildScrollView
    └── Center (ConstrainedBox max-width 840px)
        └── Column
            ├── PromptInputBox
            ├── ReferenceAudioDropzone
            ├── RegionalGenreSelector
            ├── MultilingualLanguageSelector
            ├── AdvancedOptionsAccordion
            └── StudioActionBar (Sticky bottom container)
```

### 3.2 Design Token Mappings
| Widget Element | Token Variable | Fallback Value |
|---|---|---|
| View Canvas Background | `AppColors.surfaceCanvas` | `#0A0A0C` |
| Form Card Surfaces | `AppColors.surfaceElevated` | `#141418` |
| Secondary Tile Surfaces | `AppColors.surfaceSecondary` | `#1B1B22` |
| Input Borders | `AppColors.borderSubtle` | `#2D2D38` |
| Brand Focus / Active Glow | `AppColors.brandPrimary` | `#F97316` |
| Text Primary | `AppColors.textPrimary` | `#FFFFFF` |
| Text Secondary / Muted | `AppColors.textSecondary` | `#9CA3AF` |
| Text Caption / Disabled | `AppColors.textDisabled` | `#6B7280` |
| Input Border Radius | `AppRadius.inputBorder` | `12px` |
| Button Border Radius | `AppRadius.pillBorder` | `9999px` |
| Card Border Radius | `AppRadius.cardBorder` | `12px` |

---

## 4. Integration into RootShell

In `apps/vhunambi_client/lib/main.dart`:
```dart
// Replace tab index 2 in _pages:
_pages = [
  const ExploreView(),
  const Center(child: Text('Search')),
  const StudioView(), // <-- Phase 3 integration
  const Center(child: Text('Library')),
  const Center(child: Text('Profile')),
];
```
