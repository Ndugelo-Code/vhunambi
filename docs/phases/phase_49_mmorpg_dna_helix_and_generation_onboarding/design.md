# Phase 49 Technical Design: MMORPG Creator DNA Helix & Generation-Aware Onboarding V2

## 1. Domain Models & State Architecture

### 1.1 `SonicGenerationEra` Enum & Mapping

```dart
enum SonicGenerationEra {
  era80sGolden,
  era90sKwaitoHouse,
  era2000sPianoGqom,
  era2011NextGenKinetic;

  String get label {
    switch (this) {
      case SonicGenerationEra.era80sGolden:
        return '80s Heritage & Golden Era';
      case SonicGenerationEra.era90sKwaitoHouse:
        return '90s Kwaito & House Era';
      case SonicGenerationEra.era2000sPianoGqom:
        return '2000s Piano & Gqom Wave';
      case SonicGenerationEra.era2011NextGenKinetic:
        return 'Next-Gen Kinetic & Sgija Era';
    }
  }

  String get description {
    switch (this) {
      case SonicGenerationEra.era80sGolden:
        return 'Mbaqanga brass, Bubblegum synths, and classic Maskandi finger-picking';
      case SonicGenerationEra.era90sKwaitoHouse:
        return '110 BPM township house, Kwaito kicks, and pioneering Afro-House';
      case SonicGenerationEra.era2000sPianoGqom:
        return 'Soulful Rhodes keys, deep house chords, and Durban broken-beat Gqom';
      case SonicGenerationEra.era2011NextGenKinetic:
        return 'Amapiano log drums, private school horns, and 3-step kinetic polyrhythms';
    }
  }

  List<String> get recommendedGenres {
    switch (this) {
      case SonicGenerationEra.era80sGolden:
        return const ['Mbaqanga', 'Maskandi', 'African Gospel', 'Kwaito'];
      case SonicGenerationEra.era90sKwaitoHouse:
        return const ['Kwaito', 'Afro House', 'Maskandi', 'SA Hip-Hop'];
      case SonicGenerationEra.era2000sPianoGqom:
        return const ['Amapiano', 'Private School Piano', 'Gqom', 'Afrobeats'];
      case SonicGenerationEra.era2011NextGenKinetic:
        return const ['Amapiano', 'Shangaan Electro', 'Gqom', 'Afrobeats'];
    }
  }

  static SonicGenerationEra fromBirthYear(int year) {
    if (year <= 1989) return SonicGenerationEra.era80sGolden;
    if (year <= 1999) return SonicGenerationEra.era90sKwaitoHouse;
    if (year <= 2010) return SonicGenerationEra.era2000sPianoGqom;
    return SonicGenerationEra.era2011NextGenKinetic;
  }
}
```

---

### 1.2 `CreatorDnaNode` & 8-Node MMORPG Genomic Loci

```dart
enum GenomicStatus {
  sequenced,
  lockedQuest,
}

enum DnaNodeType {
  craftPersona,
  generationEra,
  linguisticRoots,
  sonicGenres,
  voiceSignature,
  grooveArchitect,
  coCreationLineage,
  arTastemaker,
}

class CreatorDnaNode {
  final int index;
  final DnaNodeType type;
  final String title;
  final String traitLabel;
  final String description;
  final String? questInstruction;
  final String? questActionRoute;
  final Color accentColor;
  final PhosphorIconData icon;
  final GenomicStatus status;
  final int dnaPowerBonus;

  const CreatorDnaNode({
    required this.index,
    required this.type,
    required this.title,
    required this.traitLabel,
    required this.description,
    this.questInstruction,
    this.questActionRoute,
    required this.accentColor,
    required this.icon,
    required this.status,
    this.dnaPowerBonus = 15,
  });

  bool get isSequenced => status == GenomicStatus.sequenced;
}
```

---

### 1.3 `OnboardingState` & Model Extensions

```dart
class OnboardingState {
  final CreativeRole creativeRole;
  final ExperienceLevel experienceLevel;
  final List<String> selectedGenres;
  final List<String> selectedLanguages;
  final String primaryLanguage;
  final String tempoPreference;
  final int birthYear;
  final SonicGenerationEra generationEra;
  final String culturalHeritage;
  final bool hasCompletedOnboarding;
  final double onboardingCompleteness;

  const OnboardingState({
    this.creativeRole = CreativeRole.producer,
    this.experienceLevel = ExperienceLevel.intermediate,
    this.selectedGenres = const ['Amapiano'],
    this.selectedLanguages = const ['Tshivenḓa', 'isiZulu'],
    this.primaryLanguage = 'Tshivenḓa',
    this.tempoPreference = 'medium',
    this.birthYear = 2002,
    this.generationEra = SonicGenerationEra.era2000sPianoGqom,
    this.culturalHeritage = 'Vhavenda & Zulu Roots',
    this.hasCompletedOnboarding = false,
    this.onboardingCompleteness = 0.25,
  });

  OnboardingState copyWith({
    CreativeRole? creativeRole,
    ExperienceLevel? experienceLevel,
    List<String>? selectedGenres,
    List<String>? selectedLanguages,
    String? primaryLanguage,
    String? tempoPreference,
    int? birthYear,
    SonicGenerationEra? generationEra,
    String? culturalHeritage,
    bool? hasCompletedOnboarding,
    double? onboardingCompleteness,
  }) {
    return OnboardingState(
      creativeRole: creativeRole ?? this.creativeRole,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      selectedGenres: selectedGenres ?? this.selectedGenres,
      selectedLanguages: selectedLanguages ?? this.selectedLanguages,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      tempoPreference: tempoPreference ?? this.tempoPreference,
      birthYear: birthYear ?? this.birthYear,
      generationEra: generationEra ?? this.generationEra,
      culturalHeritage: culturalHeritage ?? this.culturalHeritage,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      onboardingCompleteness: onboardingCompleteness ?? this.onboardingCompleteness,
    );
  }
}
```

---

## 2. 3D Matrix & Touch Hit-Testing Algorithm

### 2.1 3D Double-Helix Node Coordinate Computation
For each node $i \in [0..7]$ along strand length $H$:

$$\theta_i = \left(\frac{i}{8}\right) \cdot 2\pi + \text{angleOffset}$$

$$y_i = \text{startY} + i \cdot \Delta y$$

For Strand A (Right Rail):
$$x_{A, i} = \text{centerX} + R \cdot \cos(\theta_i)$$
$$z_{A, i} = R \cdot \sin(\theta_i)$$

Node sphere radius projected by depth:
$$\text{scale}_i = \frac{D}{D - z_{A, i}} \quad (D = 400.0)$$
$$\text{projectedRadius}_i = 10.0 \cdot \text{scale}_i$$

### 2.2 Screen-Space Hit-Testing Proximity Formula
When touch event occurs at position $(x_t, y_t)$:

$$\text{dist}(t, i) = \sqrt{(x_t - x_{A, i})^2 + (y_t - y_i)^2}$$

If $\min_{i} \text{dist}(t, i) \le 28.0\text{dp}$, select node $i$, smoothly rotate helix so $\theta_i \approx 0$ (facing viewer), and emit `onNodeSelected(node)`.

---

## 3. Component Architecture & Main App Integration

```
[ OnboardingAct4DnaFinale ]
  ├── CreatorDnaHelixPainter (CustomPainter)
  │     ├── Renders 8 Chromatic / Wireframe Nodes
  │     └── Renders Pulsing Target Halo on Selected Node
  ├── Hit-Test GestureDetector (onTapUp -> Proximity Check)
  ├── dna_helix_node_pills (Horizontal Node Carousel)
  └── dna_node_inspector_card (MMORPG Level & Quest Card)

[ Main App Integration ]
  ├── CreatorDnaProfileCard (HomeDashboardView, OwnerProfileView, ArtistProfileView)
  │     ├── 3D Mini-Helix Stage (Embedded 140dp rotating preview)
  │     └── open_3d_dna_lab_btn (Key: 'open_3d_dna_lab_btn')
  └── CreatorDnaHelixLabSheet (Full-Screen Modal Bottom Sheet)
        ├── 3D Double-Helix Sandbox (Free Drag & Auto-Spin)
        ├── Node Inspector Card
        └── [ Complete Quest in Studio -> ] Action Launcher
```

---

## 4. Deterministic Widget Keys Table

| Widget Component | Target File | Key Value |
|---|---|---|
| Card Fan Previous Arrow | `interactive_identity_card_stack.dart` | `const Key('identity_stack_prev_btn')` |
| Card Fan Next Arrow | `interactive_identity_card_stack.dart` | `const Key('identity_stack_next_btn')` |
| Birth Year Selector / Dial | `onboarding_act3_roots_deck.dart` | `const Key('onboarding_birth_year_selector')` |
| Cultural / Language Orbs Deck | `onboarding_act3_roots_deck.dart` | `const Key('onboarding_culture_language_orbs')` |
| Era-Recommended Genre Rail | `onboarding_act3_roots_deck.dart` | `const Key('onboarding_era_genre_deck')` |
| Auto-Tune Era Genres Button | `onboarding_act3_roots_deck.dart` | `const Key('onboarding_autotune_era_btn')` |
| DNA Node Carousel Pill | `creator_dna_helix_finale.dart` | `Key('dna_helix_node_$index')` |
| MMORPG Node Inspector Card | `creator_dna_helix_finale.dart` | `const Key('dna_node_inspector_card')` |
| Open 3D DNA Lab Button | `creator_dna_profile_card.dart` | `const Key('open_3d_dna_lab_btn')` |
| Complete Quest Action Button | `creator_dna_helix_lab_sheet.dart` | `const Key('dna_lab_complete_quest_btn')` |

---

## 5. Responsive Breakpoint & Constraints Matrix

| Screen Width | Card Fan Width | Helix Height | Birth Year Dial Format | Node Inspector Layout |
|---|---|---|---|---|
| **$< 360\text{dp}$** | 260dp | 220dp | 5-item pill scrubber | Compact single column |
| **$360\text{--}420\text{dp}$** | 290dp | 260dp | 7-item pill scrubber | Full badge + description |
| **$\ge 420\text{dp}$ (Desktop/Tablet)** | 340dp | 320dp | Expanded drum slider | Dual-column side-by-side |

