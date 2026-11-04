# Phase 47: Motion-Graphics Onboarding Engine, 3D Stacked Vector Cards & Double-Helix DNA Genesis

> **Document Type:** Technical Architecture & Design (Revision 2.1 — Zero-Summarization Law)  
> **Status:** APPROVED FOR IMPLEMENTATION  
> **Target Package:** `apps/vhunambi_client`  
> **Target Release:** Vhunambi V4.7 (Phase 47)  

---

## 1. Component Hierarchy & Architectural Structure

```text
OnboardingView (ConsumerStatefulWidget)
│
├── OnboardingProceduralBackdropCanvas (60 FPS CustomPainter)
│   ├── ConstellationOrbiter (4 chromatic nodes: Amber, Cyan, Emerald, Gold)
│   ├── PillCapsuleMorphEngine (velocity-based RRect stretching)
│   ├── ParallaxVectorGlyphLayer (6 drifting Phosphor vector glyphs)
│   └── ConcentricAcousticRibbon (touch-reactive ripple physics)
│
└── PageView (4 Acts, physics: BouncingScrollPhysics)
    │
    ├── Act 1: Living Sonic Showcase (Key('onboarding_act_1_showcase'))
    │   ├── Pulsing Vhunambi Core Emblem
    │   ├── 4 Orbiting World Satellites (Studio, Voice DNA, 5-Ch Groove, Kinetic Market)
    │   └── Expanded Glass Feature Info Card
    │
    ├── Act 2: 3D Stacked Identity Deck (Key('onboarding_act_2_identity_deck'))
    │   ├── StackedCardPhysicsEngine (GestureDetector horizontal/vertical swipe)
    │   └── 5× StackedIdentityCard (Matrix4 3D transform, CustomPainter vector artwork)
    │       ├── ProducerCard (Step Sequencer Grid vector)
    │       ├── VocalistCard (Studio Condenser Mic vector)
    │       ├── DawMasterCard (Multi-Fader Console vector)
    │       ├── InstrumentalistCard (Acoustic Guitar Strings vector)
    │       └── CuratorCard (Vinyl Turntable & Tonearm vector)
    │
    ├── Act 3: Tactile Roots & Vibe Playground (Key('onboarding_act_3_roots_deck'))
    │   ├── Top Section: 12× TactileGenreCard (CustomPainter patterns + Dancing EQ Bars)
    │   │   ├── Amapiano (Log drum waveforms)
    │   │   ├── Private School Piano (Jazz piano keys)
    │   │   ├── Gqom (Heavy kick grid)
    │   │   ├── Maskandi (Fingerpicked acoustic waves)
    │   │   └── ... (8 other distinct African genres)
    │   ├── Middle Section: TactileVibeEnergySlider (Key('onboarding_vibe_slider'))
    │   └── Bottom Section: 10× IndigenousLanguageOrb (Tshivenḓa, isiZulu, etc.)
    │
    └── Act 4: Double-Helix DNA Genesis Finale (Key('onboarding_act_4_dna_finale'))
        ├── CreatorDnaHelixPainter (3D projected rotating double-helix strand)
        ├── Dynamic Trait Nodes (selected genres, languages, and identity mapped onto rungs)
        ├── Touch Rotation Gesture Handler (spin speed & particle emit)
        └── Full-Width Reveal CTA Button (Key('onboarding_launch_studio_btn'))
            └── 400ms Particle Vortex -> Navigator.pushReplacement(RootShell())
```

---

## 2. Compilable Dart Class & Provider Signatures

### 2.1 Splash & Onboarding Suppression Provider (`mini_player_host.dart`)

```dart
/// Tracks whether the application is currently presenting the splash sequence.
final isSplashActiveProvider = StateProvider<bool>((ref) => true);
```

In `MiniPlayerHost._shouldHide`:
```dart
// Suppress during splash or when onboarding is incomplete (REQ-P47-BUG-01)
if (ref.watch(isSplashActiveProvider)) return true;
final onboarding = ref.watch(onboardingStateProvider);
if (!onboarding.hasCompletedOnboarding) return true;
```

---

### 2.2 12-Genre African Heritage Catalog (`onboarding_models.dart`)

```dart
/// The 12 distinct African genres curated for the Vhunambi onboarding deck (REQ-P47-BUG-02).
class AfricanGenreModel {
  final String id;
  final String name;
  final String region;
  final Color accentColor;
  final String description;

  const AfricanGenreModel({
    required this.id,
    required this.name,
    required this.region,
    required this.accentColor,
    required this.description,
  });
}

const List<AfricanGenreModel> kAfricanOnboardingGenres = [
  AfricanGenreModel(
    id: 'amapiano',
    name: 'Amapiano',
    region: 'South Africa',
    accentColor: Color(0xFFF97316),
    description: 'Deep house, jazz chords, and resonant sub-bass log drums',
  ),
  AfricanGenreModel(
    id: 'private_school_piano',
    name: 'Private School Piano',
    region: 'South Africa',
    accentColor: Color(0xFFF59E0B),
    description: 'Sophisticated soulful keys and warm horn arrangements',
  ),
  AfricanGenreModel(
    id: 'gqom',
    name: 'Gqom',
    region: 'Durban, South Africa',
    accentColor: Color(0xFF06B6D4),
    description: 'Raw, minimalistic, broken-beat club energy',
  ),
  AfricanGenreModel(
    id: 'maskandi',
    name: 'Maskandi',
    region: 'KwaZulu-Natal',
    accentColor: Color(0xFF10B981),
    description: 'Acoustic Zulu guitar picking and praise-poetry',
  ),
  AfricanGenreModel(
    id: 'afro_house',
    name: 'Afro House',
    region: 'South Africa / Angola',
    accentColor: Color(0xFF8B5CF6),
    description: 'Deep tribal percussion and spiritual vocal chants',
  ),
  AfricanGenreModel(
    id: 'kwaito',
    name: 'Kwaito',
    region: 'Soweto, South Africa',
    accentColor: Color(0xFFEC4899),
    description: 'Slow-tempo house with township chants and 90s swagger',
  ),
  AfricanGenreModel(
    id: 'afrobeats',
    name: 'Afrobeats',
    region: 'West Africa (Nigeria / Ghana)',
    accentColor: Color(0xFF3B82F6),
    description: 'Infectious pop grooves, syncopated polyrhythms, and brass',
  ),
  AfricanGenreModel(
    id: 'sa_hip_hop',
    name: 'SA Hip-Hop',
    region: 'South Africa',
    accentColor: Color(0xFFEF4444),
    description: 'Boom-bap and trap laced with vernacular punchlines',
  ),
  AfricanGenreModel(
    id: 'african_gospel',
    name: 'African Gospel',
    region: 'Pan-African',
    accentColor: Color(0xFFEAB308),
    description: 'Uplifting choral harmonies, brass, and organ grooves',
  ),
  AfricanGenreModel(
    id: 'mbaqanga',
    name: 'Mbaqanga',
    region: 'South Africa',
    accentColor: Color(0xFF14B8A6),
    description: 'Township jive, groaning basslines, and brass riffs',
  ),
  AfricanGenreModel(
    id: 'shangaan_electro',
    name: 'Shangaan Electro',
    region: 'Limpopo, South Africa',
    accentColor: Color(0xFFD946EF),
    description: 'High-speed 180 BPM electronic marimba grooves',
  ),
  AfricanGenreModel(
    id: 'bongo_flava',
    name: 'Bongo Flava',
    region: 'Tanzania / East Africa',
    accentColor: Color(0xFF6366F1),
    description: 'Swahili melodies blending R&B, Taarab, and Afro-pop',
  ),
];
```

---

### 2.3 OnboardingProceduralBackdropCanvas (`onboarding_procedural_canvas.dart`)

```dart
/// 60 FPS Procedural backdrop canvas inspired by reference motion graphics (REQ-P47-CANVAS-01..05).
class OnboardingProceduralBackdropCanvas extends StatelessWidget {
  final AnimationController animation;
  final double pageOffset;
  final List<Offset> touchRipples;

  const OnboardingProceduralBackdropCanvas({
    super.key,
    required this.animation,
    required this.pageOffset,
    this.touchRipples = const [],
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ConstellationBackdropPainter(
            time: animation.value,
            pageOffset: pageOffset,
            isDark: Theme.of(context).brightness == Brightness.dark,
            ripples: touchRipples,
          ),
        );
      },
    );
  }
}
```

---

### 2.4 InteractiveIdentityCardStack (`interactive_identity_card_stack.dart`)

```dart
/// 3D Stacked & Fanned Tarot Deck for Creator Identity (REQ-P47-ACT2-01..03).
class InteractiveIdentityCardStack extends ConsumerStatefulWidget {
  final CreativeRole selectedRole;
  final ValueChanged<CreativeRole> onRoleChanged;

  const InteractiveIdentityCardStack({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
  });

  @override
  ConsumerState<InteractiveIdentityCardStack> createState() =>
      _InteractiveIdentityCardStackState();
}
```

---

### 2.5 CreatorDnaHelixFinale (`creator_dna_helix_finale.dart`)

```dart
/// Act 4 Double-Helix DNA Genesis finale with 3D rotating strand (REQ-P47-ACT4-01..04).
class CreatorDnaHelixFinale extends ConsumerStatefulWidget {
  final VoidCallback onLaunchStudio;

  const CreatorDnaHelixFinale({
    super.key,
    required this.onLaunchStudio,
  });

  @override
  ConsumerState<CreatorDnaHelixFinale> createState() =>
      _CreatorDnaHelixFinaleState();
}
```

---

## 3. Responsive Breakpoint & Matrix Layout Specifications

| Viewport Category | Width Range | 3D Card Stack Scale | DNA Helix Radius | Genre Cards Grid |
| :--- | :--- | :--- | :--- | :--- |
| **Mobile Compact** | `< 380px` (e.g. 360dp) | Scale: 0.90, Perspective: 0.0012 | Radius: 85dp, Rungs: 12 | 2 Columns, 72dp Card Height |
| **Mobile Standard** | `380px – 768px` | Scale: 1.00, Perspective: 0.0010 | Radius: 105dp, Rungs: 14 | 2 Columns, 80dp Card Height |
| **Tablet / Foldable** | `768px – 1024px` | Scale: 1.15, Perspective: 0.0008 | Radius: 130dp, Rungs: 16 | 3 Columns, 88dp Card Height |
| **Desktop / Web** | `> 1024px` | Dual-pane split layout | Radius: 160dp, Rungs: 18 | 4 Columns, 96dp Card Height |

---

## 4. Deterministic Widget Test Key Registry

| Widget / Control | Deterministic Key | Purpose |
| :--- | :--- | :--- |
| **Act 1 Stage** | `Key('onboarding_act_1_showcase')` | Act 1 Showcase Container |
| **Act 2 Deck** | `Key('onboarding_act_2_identity_deck')` | Act 2 3D Card Fan |
| **Act 2 Card: Producer** | `Key('identity_card_producer')` | Select Producer craft |
| **Act 2 Card: Vocalist** | `Key('identity_card_vocalist')` | Select Vocalist craft |
| **Act 2 Card: DAW Master** | `Key('identity_card_multiHyphenate')` | Select DAW Master craft |
| **Act 2 Card: Instrumentalist** | `Key('identity_card_songwriter')` | Select Instrumentalist craft |
| **Act 2 Card: Curator** | `Key('identity_card_musicLover')` | Select Curator craft |
| **Act 3 Stage** | `Key('onboarding_act_3_roots_deck')` | Act 3 Genre & Tongue Deck |
| **Act 3 Genre Card** | `Key('genre_card_\${genre.id}')` | Selects specific genre |
| **Act 3 Vibe Slider** | `Key('onboarding_vibe_slider')` | Drag tempo/vibe intensity |
| **Act 3 Language Orb** | `Key('language_orb_\${language}')` | Selects specific tongue |
| **Act 4 Finale** | `Key('onboarding_act_4_dna_finale')` | Act 4 DNA Helix Stage |
| **Launch Studio CTA** | `Key('onboarding_launch_studio_btn')` | Final Activation Button |
| **Replay Onboarding** | `Key('settings_replay_onboarding_btn')` | Trigger onboarding from settings |

