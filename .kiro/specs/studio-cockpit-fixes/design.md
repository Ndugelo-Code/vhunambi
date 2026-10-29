# Studio Cockpit Bugs & UX Fixes — Technical Design Document

## Overview

This document specifies the technical architecture for fixing 6 critical defects (VH-001 through VH-006) in the **Studio AI Cockpit** and **Persistent Audio Player**. These fixes address revenue blockers, usability crises, accessibility violations, and brand identity gaps identified during field testing on 19 October 2026.

**Feature Name:** `studio-cockpit-fixes`

**Spec ID:** `b93e9741-089f-4d15-8075-44d97ae47805`

**Workflow:** Bugfix Requirements-First

**Platform:** Flutter 3.44+ / Dart 3.x / Riverpod 2.x

**Business Impact:**
- **Revenue Blocker (P0):** Non-functional visibility toggle undermines trust in credit-based platform
- **Usability Crisis (P0):** Persistent mini player consumes 8% of screen with no dismiss
- **Accessibility Violation (P0):** CTA button overflow fails WCAG 2.5.5 at 360dp
- **Professional Brand Gap (P1):** Generic text title lacks brand identity

---

## Architecture

### System Overview

This bugfix implements 6 targeted fixes to the Studio Cockpit and Player subsystems without introducing new architectural layers. All changes integrate with existing Riverpod state management, Flutter widget tree, and design system tokens.

**Core Subsystems:**

1. **Player Subsystem**: Audio transport, playback state, OS integration via `audio_service`
2. **Studio Subsystem**: Form state management, parameter tracking, generation request assembly
3. **Onboarding Subsystem**: Multi-page flow, Creator DNA profile capture
4. **Design System**: Color tokens, spacing, typography, asset registry

**Integration Points:**

```
┌─────────────────────────────────────────────────────────────────┐
│                        MaterialApp                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┴─────────────┐
                │                           │
        ┌───────▼────────┐         ┌───────▼────────┐
        │  MainScaffold  │         │ OnboardingView │
        │   (Tab Host)   │         │   (VH-004)     │
        └───────┬────────┘         └────────────────┘
                │
    ┌───────────┼───────────┐
    │           │           │
┌───▼────┐  ┌───▼────┐  ┌──▼──────┐
│ Create │  │Explore │  │ Profile │
│  View  │  │  View  │  │  View   │
└───┬────┘  └────────┘  └─────────┘
    │
    ├─► VhunambiAppBar (VH-006)
    ├─► StudioProgressTracker (VH-005)
    ├─► StudioActionBar (VH-002, VH-003)
    └─► MobileMiniPlayer (VH-001)
```

### State Flow

```
User Action → Notifier Method → State Update → Widget Rebuild

Example (VH-002 Visibility Toggle):
1. User taps Switch
2. Switch.onChanged → notifier.setVisibility('private')
3. StudioFormNotifier updates state.visibility
4. StudioActionBar rebuilds with new subtitle
5. Analytics event fires
```

### Technology Stack

- **UI Framework**: Flutter 3.44+, Material Design 3
- **State Management**: Riverpod 2.x (`StateNotifier`, `Provider`, `StateNotifierProvider`)
- **Audio**: `audio_service` package (OS transport integration)
- **Vector Graphics**: `flutter_svg` package (logo assets)
- **Analytics**: Firebase Analytics (event tracking)
- **Storage**: `shared_preferences` (ToS acceptance, logo persistence)

---

## Data Models

### Player State Model (VH-001)

**No changes required.** Existing `PlayerState` and `PlayerNotifier.dismiss()` method provide necessary functionality.

**Existing Model:**

```dart
@immutable
class PlayerState {
  final Track? currentTrack;
  final PlaybackStatus playbackStatus;  // idle | playing | paused | buffering
  final Duration position;
  final Duration duration;
  final List<Track> queue;
  final int currentIndex;
  final bool isShuffle;
  final AudioRepeatMode repeatMode;
  final bool isExpanded;
  // ... other fields
  
  bool get hasActiveTrack => currentTrack != null;
  bool get isPlaying => playbackStatus == PlaybackStatus.playing;
}

enum PlaybackStatus { idle, playing, paused, buffering, error }
enum AudioRepeatMode { off, all, one }
```

**Dismiss Behavior:**

```dart
void dismiss() {
  _positionTimer?.cancel();
  state = state.copyWith(
    clearTrack: true,              // Sets currentTrack to null
    playbackStatus: PlaybackStatus.idle,
    position: Duration.zero,
  );
  unawaited(_dispatchSafely(_audioHandler.stop));
}
```

---

### Studio Form State Model (VH-002)

**Breaking Change:** Add `visibility: String` field, deprecate `isPublic: bool`.

**Migration Path:**

```dart
// Phase 1: Add visibility field
@immutable
class StudioFormState {
  @Deprecated('Use visibility field instead. Removed in v2.1.0')
  final bool isPublic;
  
  /// Track visibility: "public" (Explore + profile) or "private" (Library only).
  final String visibility;
  
  // ... other fields
  
  const StudioFormState({
    @Deprecated('Use visibility parameter')
    this.isPublic = true,
    this.visibility = 'public',
    // ...
  });
  
  StudioFormState copyWith({
    @Deprecated('Use visibility parameter')
    bool? isPublic,
    String? visibility,
    // ... other parameters
  }) {
    return StudioFormState(
      isPublic: isPublic ?? this.isPublic,
      visibility: visibility ?? this.visibility,
      // ...
    );
  }
}
```

**Phase 2 (Week 2-3):** Update all call sites to use `visibility`  
**Phase 3 (Week 4):** Remove `isPublic` field entirely

---

### Progress Tracker State Model (VH-005)

**New Model (Derived View):**

```dart
@immutable
class ProgressTrackerState {
  final int filledCount;
  final int totalCount;
  final List<ParameterSlot> slots;
  
  const ProgressTrackerState({
    required this.filledCount,
    required this.totalCount,
    required this.slots,
  });
  
  double get completenessRatio => totalCount > 0 ? filledCount / totalCount : 0.0;
  String get completenessLabel => '$filledCount/$totalCount';
  
  /// Factory: derives slot states from StudioFormState (REQ-STM-01)
  factory ProgressTrackerState.fromStudioForm(StudioFormState form) {
    // See implementation in Component Specifications section
  }
}

enum SlotState {
  empty,   // Not configured by user
  set,     // User-configured (non-default value)
  auto,    // DNA-suggested or default value
}

@immutable
class ParameterSlot {
  final String name;       // "Prompt" | "Genre" | "Mood" | ...
  final SlotState state;   // empty | set | auto
  final String? value;     // Display value (truncated if long)
  
  const ParameterSlot({
    required this.name,
    required this.state,
    this.value,
  });
}
```

**Provider (Computed View):**

```dart
final progressTrackerProvider = Provider<ProgressTrackerState>((ref) {
  final formState = ref.watch(studioFormProvider);
  return ProgressTrackerState.fromStudioForm(formState);
});

// Expansion state (local UI state, not form data)
final _isExpandedProvider = StateProvider<bool>((ref) => false);
```

---

### Generation Request Payload (VH-002)

**Updated API Request:**

```dart
class GenerationRequest {
  final String prompt;
  final String genre;
  final String mood;
  final TempoBracket tempo;
  final VocalEnergy vocalEnergy;
  final String language;
  final String? customLyrics;
  final bool isInstrumental;
  final int durationSeconds;
  
  // [NEW] Visibility field
  final String visibility;  // "public" | "private"
  
  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      'genre': genre,
      'mood': mood,
      'tempo_bpm': _tempoBpm(tempo),
      'vocal_energy': _vocalEnergyString(vocalEnergy),
      'language': language,
      'custom_lyrics': customLyrics,
      'is_instrumental': isInstrumental,
      'duration_seconds': durationSeconds,
      'visibility': visibility,  // ✅ Included in API payload
    };
  }
}
```

---

## Components and Interfaces

### VH-001: MobileMiniPlayer (Modified)

**Interface:**

```dart
class MobileMiniPlayer extends ConsumerWidget {
  /// Optional callback to expand to Now Playing cockpit
  final VoidCallback? onExpand;
  
  const MobileMiniPlayer({
    super.key,
    this.onExpand,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref);
}
```

**Dependencies:**
- `playerStateProvider` (read: current track, playback status, position)
- `playerStateProvider.notifier` (call: `dismiss()`, `skipNext()`, `skipPrevious()`, `togglePlayPause()`)

**Gestures:**
- **Tap close button**: `notifier.dismiss()`
- **Swipe down (velocity > 250)**: `notifier.dismiss()`
- **Swipe up (velocity < -250)**: `onExpand?.call()`
- **Swipe left (velocity < -250)**: `notifier.skipNext()`
- **Swipe right (velocity > 250)**: `notifier.skipPrevious()`
- **Tap album art or metadata**: `onExpand?.call()`

**Visibility Logic:**
- Hidden when `!playerState.hasActiveTrack`
- Hidden when `MediaQuery.viewInsets.bottom > 0` (keyboard open)

---

### VH-002: StudioActionBar (Modified)

**Interface:**

```dart
class StudioActionBar extends ConsumerWidget {
  const StudioActionBar({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref);
  
  Future<void> _handleGenerate(BuildContext context, WidgetRef ref);
}
```

**Dependencies:**
- `studioFormProvider` (read: visibility, lyricsMode, prompt, genre, etc.)
- `studioFormProvider.notifier` (call: `setVisibility(String)`, `triggerGeneration()`, `beginLyricsReview()`)
- `lyricsReviewProvider.notifier` (call: `loadGeneratedLyrics()`)

**Key Updates:**
- **Dynamic icon**: `Icons.public_rounded` (public) or `Icons.lock_outline_rounded` (private)
- **Dynamic title**: "Public" or "Private"
- **Dynamic subtitle**: "Visible on Explore & your profile" or "Only you can see this"
- **Switch binding**: Calls `notifier.setVisibility('public' | 'private')`
- **Removed**: Process description paragraph, ToS/licensing notice

---

### VH-003: ToS Acceptance Modal (New, Optional)

**Interface:**

```dart
class GenerationToSModal extends StatelessWidget {
  const GenerationToSModal({super.key});
  
  static Future<bool> show(BuildContext context);
  
  @override
  Widget build(BuildContext context);
}
```

**Usage:**

```dart
// Show modal on first generation only
final prefs = await SharedPreferences.getInstance();
final hasAccepted = prefs.getBool('has_accepted_generation_tos') ?? false;

if (!hasAccepted) {
  final accepted = await GenerationToSModal.show(context);
  if (!accepted) return;  // User declined
  await prefs.setBool('has_accepted_generation_tos', true);
}
```

---

### VH-004: OnboardingView Footer (Modified)

**Interface:**

```dart
class _OnboardingFooter extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback onActivateDna;
  
  const _OnboardingFooter({
    required this.currentPage,
    required this.totalPages,
    required this.onActivateDna,
  });
  
  @override
  Widget build(BuildContext context);
  
  double _calculateMaxButtonWidth(BuildContext context);
}
```

**Key Updates:**
- **Flexible button**: Wrapped in `Expanded + ConstrainedBox`
- **Max width calculation**: `screenWidth - dotsWidth - margins`
- **Text scaling**: `FittedBox(fit: BoxFit.scaleDown)` for large font scales
- **Emoji removed**: "Activate Creator DNA →" (saves width)

---

### VH-005: StudioProgressTracker (New)

**Interface:**

```dart
class StudioProgressTracker extends ConsumerWidget {
  /// Optional callback when slot is tapped (passes slot name)
  final void Function(String slotName)? onSlotTapped;
  
  const StudioProgressTracker({
    super.key,
    this.onSlotTapped,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref);
}

class _CollapsedBar extends StatelessWidget {
  final ProgressTrackerState progress;
  
  @override
  Widget build(BuildContext context);
}

class _ExpandedView extends StatelessWidget {
  final ProgressTrackerState progress;
  final void Function(String)? onSlotTapped;
  
  @override
  Widget build(BuildContext context);
}

class _SlotTile extends StatelessWidget {
  final ParameterSlot slot;
  final VoidCallback? onTap;
  
  @override
  Widget build(BuildContext context);
}
```

**Dependencies:**
- `progressTrackerProvider` (read: slot states, completeness)
- `_isExpandedProvider` (read/write: collapsed/expanded state)

**Gestures:**
- **Tap collapsed bar**: Toggle expansion
- **Tap slot tile**: Fire `onSlotTapped(slotName)` callback, scroll to control

---

### VH-006: VhunambiAppBar (Modified)

**Interface:**

```dart
class VhunambiAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const VhunambiAppBar({super.key});
  
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  
  @override
  Widget build(BuildContext context, WidgetRef ref);
}
```

**Key Updates:**
- Replace text "VHUNAMBI Studio" with `SvgPicture.asset(AppAssets.vhunambiCompactMark)`
- Width reduced from ~180px to ~90px
- Logo color: `AppColors.brandPrimary` (dark mode) or `AppColors.textPrimary` (light mode)

---

## Correctness Properties

### VH-001: Mini Player Dismissal

**Property 1: Dismiss Stops Playback**

_For any_ player state where `hasActiveTrack == true`, calling `dismiss()` SHALL set `playbackStatus` to `idle`, clear `currentTrack`, reset `position` to zero, and stop the audio handler within one frame.

**Validates: Requirements 2.1, 2.2, 2.3**

**Property 2: Dismiss Preserves Queue**

_For any_ player state with a non-empty queue, calling `dismiss()` SHALL NOT clear the queue. Re-playing any track SHALL restore the original queue order.

**Validates: Requirement 3.1**

**Property 3: Keyboard Hides Player**

_For any_ viewport state where `viewInsets.bottom > 0`, the mini player SHALL render as `SizedBox.shrink()` and return to visibility when `viewInsets.bottom == 0`.

**Validates: Requirement 2.4, REQ-RWD-03**

---

### VH-002: Visibility Toggle

**Property 1: Toggle Updates State**

_For any_ toggle action, calling `setVisibility('private')` SHALL update `state.visibility` to `"private"` and emit a state change to all listeners within one frame.

**Validates: Requirements 2.5, 2.6**

**Property 2: Visibility Persists Across Flows**

_For any_ lyrics review flow, setting `visibility` to `"private"` before entering `beginLyricsReview()` SHALL preserve the value through `approveLyrics()` without resetting to default.

**Validates: Requirements 2.9, REQ-STM-05**

**Property 3: Backend Enforcement**

_For any_ track with `visibility == "private"`, the backend API SHALL exclude the track from `GET /explore/tracks` and `GET /profiles/:userId/tracks` when `requesterId != userId`.

**Validates: Requirements 2.7, 2.8**

---

### VH-003: Description Text Removal

**Property 1: Reduced Height**

_For any_ `StudioActionBar` render, the column height SHALL NOT exceed 144px (toggle 56px + spacing 16px + button 52px + optional footer 24px).

**Validates: Requirements 2.14, 2.15**

**Property 2: No Scroll Required**

_For any_ viewport at 360×640dp with mini player dismissed, the prompt field, visibility toggle, and primary CTA button SHALL all be visible without vertical scroll.

**Validates: Requirement 2.14**

---

### VH-004: CTA Responsive Layout

**Property 1: No Overflow**

_For any_ viewport width from 360dp to 1920dp, the "Activate Creator DNA" button right edge SHALL be at least 16dp from the screen edge.

**Validates: Requirement 2.16**

**Property 2: Accessible at Large Font Scale**

_For any_ system font scale from 100% to 200%, the CTA button SHALL remain fully tappable with a minimum 44×44px touch target.

**Validates: Requirements 2.17, 2.19, REQ-A11Y-04**

---

### VH-005: Progress Tracker Accuracy

**Property 1: State Derived from Form**

_For any_ `StudioFormState` update, the `ProgressTrackerState` SHALL derive all slot states by inspecting form field values without maintaining duplicate state.

**Validates: REQ-STM-01**

**Property 2: Real-Time Update**

_For any_ parameter change in `StudioFormState`, the progress tracker SHALL update within one frame (<16ms at 60fps).

**Validates: Requirement 2.25, REQ-PF-01**

---

### VH-006: Logo Integration

**Property 1: Horizontal Clearance**

_For any_ viewport width, the compact brand mark SHALL consume ≤ 100px horizontal space, providing at least 60px clearance to the credits chip at 360dp.

**Validates: Requirements 2.29, 2.30**

**Property 2: Vector Scalability**

_For any_ screen density (1x, 2x, 3x), the SVG logo SHALL render without pixelation or aliasing.

**Validates: Requirement 2.30**

---

## Error Handling

### VH-001: Player Dismiss Failures

**Scenario:** Audio handler fails to stop playback (e.g., OS resource locked)

**Handling:**
```dart
void dismiss() {
  _positionTimer?.cancel();
  state = state.copyWith(
    clearTrack: true,
    playbackStatus: PlaybackStatus.idle,
    position: Duration.zero,
  );
  unawaited(_dispatchSafely(_audioHandler.stop));  // Never throws
}

Future<void> _dispatchSafely(Future<void> Function() action) async {
  try {
    await action();
  } catch (error) {
    debugPrint('Vhunambi audio handler dispatch failed: $error');
    // UI state already updated — failure is logged but not surfaced
  }
}
```

**User Impact:** Player disappears from UI immediately. Audio may continue briefly if handler fails, but state is correct for next playback.

---

### VH-002: Invalid Visibility Value

**Scenario:** Developer passes invalid visibility string (e.g., `"unlisted"`)

**Handling:**
```dart
void setVisibility(String visibility) {
  assert(
    visibility == 'public' || visibility == 'private',
    'Visibility must be "public" or "private", got: $visibility',
  );
  state = state.copyWith(visibility: visibility);
}
```

**Debug Mode:** Assertion error with clear message  
**Release Mode:** No assertion, invalid value accepted (API validation catches it)

---

### VH-003: ToS Modal Dismissed

**Scenario:** User declines ToS acceptance modal

**Handling:**
```dart
final accepted = await GenerationToSModal.show(context);
if (!accepted) {
  // Do not proceed with generation
  return;
}
```

**User Impact:** Generation does not trigger. No error message shown (user explicitly declined).

---

### VH-004: Button Width Overflow Detection

**Scenario:** Button text exceeds calculated max width at extreme font scale (200%+)

**Handling:**
```dart
FittedBox(
  fit: BoxFit.scaleDown,
  child: Text('Activate Creator DNA →'),
)
```

**Result:** Text scales down to fit container. Always tappable, may be slightly smaller than surrounding text at 200% scale.

**Analytics:** Fire `studio_cta_overflow_detected` event if overflow detected at build time.

---

### VH-005: Progress Tracker State Derivation Error

**Scenario:** `StudioFormState` contains unexpected null or malformed value

**Handling:**
```dart
factory ProgressTrackerState.fromStudioForm(StudioFormState form) {
  try {
    // Derive slot states with null-safe fallbacks
    final slots = <ParameterSlot>[
      ParameterSlot(
        name: 'Prompt',
        state: (form.prompt.trim().isEmpty) ? SlotState.empty : SlotState.set,
        value: form.prompt.isEmpty ? null : '${form.prompt.substring(0, min(20, form.prompt.length))}...',
      ),
      // ... other slots with safe navigation
    ];
    
    final filled = slots.where((s) => s.state != SlotState.empty).length;
    
    return ProgressTrackerState(
      filledCount: filled,
      totalCount: slots.length,
      slots: slots,
    );
  } catch (error) {
    debugPrint('Progress tracker derivation error: $error');
    // Return safe fallback state
    return const ProgressTrackerState(
      filledCount: 0,
      totalCount: 9,
      slots: [],
    );
  }
}
```

**User Impact:** Progress tracker shows 0/9 instead of crashing. Generation still works.

---

### VH-006: Logo Asset Missing

**Scenario:** SVG asset not found in bundle (build misconfiguration)

**Handling:**
```dart
try {
  SvgPicture.asset(
    AppAssets.vhunambiCompactMark,
    width: 90,
    height: 32,
  )
} catch (error) {
  // Fallback to text title
  Text(
    'VHUNAMBI Studio',
    style: AppTypography.titleLarge,
  )
}
```

**Or:** Use `flutter_svg`'s built-in error handling:

```dart
SvgPicture.asset(
  AppAssets.vhunambiCompactMark,
  width: 90,
  height: 32,
  placeholderBuilder: (_) => const Icon(Icons.music_note),  // Fallback icon
)
```

**User Impact:** Generic music icon or text title displayed instead of logo.

---

## Glossary

- **Bug_Condition (C)**: The condition that triggers the bug
- **Property (P)**: The desired behavior when the bug condition holds
- **Preservation**: Existing behavior that must remain unchanged by the fix
- **Mini Player**: The docked audio transport bar (`MobileMiniPlayer`)
- **Cockpit**: The Studio AI configuration interface for song generation
- **Visibility**: Public/Private toggle determining track discovery on Explore feeds
- **Progress Tracker**: Real-time completeness indicator showing configured vs. empty parameter slots
- **Creator DNA**: User profile driving auto-filled generation parameters

---

## Architecture Overview

### Component Hierarchy

```
MaterialApp
 └─ MainScaffold
     ├─ BottomNavigationBar
     └─ IndexedStack
         ├─ CreateView (Studio Cockpit)
         │   ├─ TabBar (Compose | Voice | Crate)
         │   ├─ [NEW] StudioProgressTracker
         │   ├─ StudioFormFields
         │   └─ StudioActionBar (VH-002, VH-003)
         └─ MobileMiniPlayer (VH-001)
             └─ GestureDetector (swipe-down dismiss)
```

### Affected Files

| File Path | Change Type | Bug ID |
|-----------|-------------|--------|
| `lib/features/player/presentation/widgets/mobile_mini_player.dart` | Modify | VH-001 |
| `lib/features/player/presentation/providers/player_provider.dart` | Modify | VH-001 |
| `lib/features/player/domain/models/player_state.dart` | Modify | VH-001 |
| `lib/features/studio/domain/models/studio_form_state.dart` | Modify | VH-002 |
| `lib/features/studio/presentation/providers/studio_form_provider.dart` | Modify | VH-002 |
| `lib/features/studio/presentation/widgets/studio_action_bar.dart` | Modify | VH-002, VH-003 |
| `lib/features/onboarding/presentation/views/onboarding_view.dart` | Modify | VH-004 |
| `lib/features/studio/presentation/widgets/studio_progress_tracker.dart` | **Create** | VH-005 |
| `lib/features/studio/presentation/providers/progress_tracker_provider.dart` | **Create** | VH-005 |
| `lib/core/widgets/vhunambi_app_bar.dart` | Modify | VH-006 |
| `lib/core/constants/app_assets.dart` | Modify | VH-006 |
| `assets/branding/vhunambi_compact_mark_light.svg` | **Create** | VH-006 |
| `assets/branding/vhunambi_compact_mark_dark.svg` | **Create** | VH-006 |
| `assets/branding/vhunambi_full_lockup.svg` | **Create** | VH-006 |
| `test/features/player/presentation/widgets/mobile_mini_player_test.dart` | Modify | VH-001 |
| `test/features/studio/presentation/widgets/studio_action_bar_test.dart` | Modify | VH-002, VH-003 |
| `test/features/onboarding/presentation/views/onboarding_view_test.dart` | Modify | VH-004 |
| `test/features/studio/presentation/widgets/studio_progress_tracker_test.dart` | **Create** | VH-005 |

---

## State Management Design

### VH-001: Player State Model

**Current State:**

```dart
@immutable
class PlayerState {
  final Track? currentTrack;
  final PlaybackStatus playbackStatus;
  final Duration position;
  final Duration duration;
  // ... other fields
}
```

**No Changes Required**: The existing `dismiss()` method in `PlayerNotifier` already provides the necessary state cleanup. We only need to wire it to UI controls.

**`PlayerNotifier.dismiss()` Implementation (Already Exists):**

```dart
void dismiss() {
  _positionTimer?.cancel();
  state = state.copyWith(
    clearTrack: true,
    playbackStatus: PlaybackStatus.idle,
    position: Duration.zero,
  );
  unawaited(_dispatchSafely(_audioHandler.stop));
}
```

---

### VH-002: Studio Form State Model Migration

**Current State (Defect):**

```dart
@immutable
class StudioFormState {
  final bool isPublic;  // ❌ Boolean does not map to API schema
  // ... other fields
  
  const StudioFormState({
    this.isPublic = true,  // Default: Public (privacy risk)
    // ...
  });
}
```

**Target State (Fixed):**

```dart
@immutable
class StudioFormState {
  @Deprecated('Use visibility field instead. Removed in v2.1.0')
  final bool isPublic;
  
  /// Track visibility: "public" (Explore + profile) or "private" (Library only).
  /// Defaults to "public" per product decision (subject to privacy review).
  final String visibility;
  
  // ... other fields
  
  const StudioFormState({
    @Deprecated('Use visibility parameter')
    this.isPublic = true,
    this.visibility = 'public',
    // ...
  });
  
  StudioFormState copyWith({
    @Deprecated('Use visibility parameter')
    bool? isPublic,
    String? visibility,
    // ... other parameters
  }) {
    return StudioFormState(
      isPublic: isPublic ?? this.isPublic,
      visibility: visibility ?? this.visibility,
      // ...
    );
  }
}
```

**Migration Strategy (3-Phase):**

**Phase 1 (Week 1):** Add `visibility` field alongside `isPublic`
- Add `visibility: String` field with default `"public"`
- Keep `isPublic` for backward compatibility
- Sync `isPublic` with `visibility` in constructor: `isPublic = (visibility == "public")`

**Phase 2 (Week 2-3):** Update all call sites to use `visibility`
- Replace `notifier.togglePublic(bool)` with `notifier.setVisibility(String)`
- Update UI to read `state.visibility` instead of `state.isPublic`
- Update generation request payload to send `visibility` field
- Mark `isPublic` as `@Deprecated`

**Phase 3 (Week 4):** Remove `isPublic` field
- Delete deprecated field after all call sites migrated
- Verify no usages with `flutter analyze` and grep search

---

### VH-002: Studio Form Notifier Updates

**New Method:**

```dart
class StudioFormNotifier extends StateNotifier<StudioFormState> {
  // Replace togglePublic(bool) with setVisibility(String)
  
  void setVisibility(String visibility) {
    assert(
      visibility == 'public' || visibility == 'private',
      'Visibility must be "public" or "private"',
    );
    state = state.copyWith(visibility: visibility);
  }
  
  @Deprecated('Use setVisibility(String) instead')
  void togglePublic(bool isPublic) {
    setVisibility(isPublic ? 'public' : 'private');
  }
  
  /// Preserves visibility when approving lyrics (REQ-STM-05)
  void approveLyrics(String lyrics) {
    state = state.copyWith(
      customLyrics: lyrics,
      phase: GenerationPhase.queued,
      generationProgress: 0.5,
      errorMessage: null,
      // visibility NOT reset to default
    );
  }
}
```

---

### VH-005: Progress Tracker State Model

**New Provider:**

```dart
/// Derives slot states from StudioFormState without duplicating data.
/// This provider is a computed view, not a separate source of truth.
final progressTrackerProvider = Provider<ProgressTrackerState>((ref) {
  final formState = ref.watch(studioFormProvider);
  return ProgressTrackerState.fromStudioForm(formState);
});

@immutable
class ProgressTrackerState {
  final int filledCount;
  final int totalCount;
  final List<ParameterSlot> slots;
  
  const ProgressTrackerState({
    required this.filledCount,
    required this.totalCount,
    required this.slots,
  });
  
  double get completenessRatio => totalCount > 0 ? filledCount / totalCount : 0.0;
  
  String get completenessLabel => '$filledCount/$totalCount';
  
  /// Factory: derives slot states from StudioFormState (REQ-STM-01)
  factory ProgressTrackerState.fromStudioForm(StudioFormState form) {
    final slots = <ParameterSlot>[
      ParameterSlot(
        name: 'Prompt',
        state: form.prompt.trim().isEmpty ? SlotState.empty : SlotState.set,
        value: form.prompt.isEmpty ? null : '${form.prompt.substring(0, min(20, form.prompt.length))}...',
      ),
      ParameterSlot(
        name: 'Genre',
        state: SlotState.set,  // Always set (has default "Amapiano")
        value: form.genre,
      ),
      ParameterSlot(
        name: 'Mood',
        state: form.mood == 'Uplifting' ? SlotState.auto : SlotState.set,
        value: form.mood,
      ),
      ParameterSlot(
        name: 'Tempo',
        state: form.tempo == TempoBracket.medium ? SlotState.auto : SlotState.set,
        value: _tempoLabel(form.tempo),
      ),
      ParameterSlot(
        name: 'Vocal Energy',
        state: form.vocalEnergy == VocalEnergy.mid ? SlotState.auto : SlotState.set,
        value: _vocalEnergyLabel(form.vocalEnergy),
      ),
      ParameterSlot(
        name: 'Language',
        state: form.language == 'English' ? SlotState.auto : SlotState.set,
        value: form.language,
      ),
      ParameterSlot(
        name: 'Lyrics',
        state: form.customLyrics != null ? SlotState.set : SlotState.empty,
        value: form.lyricsMode == LyricsMode.instrumental ? 'Instrumental' : null,
      ),
      ParameterSlot(
        name: 'DNA Usage',
        state: SlotState.auto,  // Always auto (calculated from profile)
        value: '25%',  // Placeholder: should read from DNA profile
      ),
      ParameterSlot(
        name: 'Visibility',
        state: form.visibility == 'public' ? SlotState.auto : SlotState.set,
        value: form.visibility == 'public' ? 'Public' : 'Private',
      ),
    ];
    
    final filled = slots.where((s) => s.state != SlotState.empty).length;
    
    return ProgressTrackerState(
      filledCount: filled,
      totalCount: slots.length,
      slots: slots,
    );
  }
  
  static String _tempoLabel(TempoBracket tempo) {
    return switch (tempo) {
      TempoBracket.slow => 'Slow',
      TempoBracket.medium => 'Medium',
      TempoBracket.fast => 'Fast',
      TempoBracket.veryFast => 'Hyperspeed',
    };
  }
  
  static String _vocalEnergyLabel(VocalEnergy energy) {
    return switch (energy) {
      VocalEnergy.soft => 'Soft',
      VocalEnergy.mid => 'Balanced',
      VocalEnergy.intense => 'Intense',
    };
  }
}

enum SlotState {
  empty,   // Not configured
  set,     // User-configured
  auto,    // DNA-suggested or default
}

@immutable
class ParameterSlot {
  final String name;
  final SlotState state;
  final String? value;
  
  const ParameterSlot({
    required this.name,
    required this.state,
    this.value,
  });
}
```

---

## Component Specifications

### VH-001: Mini Player Dismiss Control

**File:** `lib/features/player/presentation/widgets/mobile_mini_player.dart`

**Design Objective:** Add dismiss control (close button + swipe-down gesture) to stop playback, release audio session, and remove mini player.

**Current Implementation:** Mini player renders with play/pause, skip controls, and horizontal swipe-to-skip. No dismiss mechanism exists.

**Target Implementation:**

**Widget Structure:**

```dart
class MobileMiniPlayer extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerStateProvider);
    final notifier = ref.read(playerStateProvider.notifier);
    
    if (!playerState.hasActiveTrack) {
      return const SizedBox.shrink();
    }
    
    // Hide player when keyboard is visible (REQ-RWD-03)
    final viewInsets = MediaQuery.of(context).viewInsets;
    if (viewInsets.bottom > 0) {
      return const SizedBox.shrink();
    }
    
    return VhunambiFloatingTransportSurface(
      glow: AppGradients.forGenre(playerState.currentTrack!.genre).colors.first,
      child: Column(
        children: [
          // Progress line
          LinearProgressIndicator(
            value: playerState.progressRatio,
            minHeight: 2,
            backgroundColor: AppColors.borderSubtle,
            valueColor: const AlwaysStoppedAnimation(AppColors.brandPrimary),
          ),
          
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              
              // Horizontal swipe: skip previous/next (existing)
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -250) {
                  HapticFeedback.lightImpact();
                  notifier.skipNext();
                } else if (velocity > 250) {
                  HapticFeedback.lightImpact();
                  notifier.skipPrevious();
                }
              },
              
              // [NEW] Vertical swipe: expand (up) or dismiss (down)
              onVerticalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -250) {
                  // Swipe up: expand to Now Playing cockpit
                  HapticFeedback.lightImpact();
                  onExpand?.call();
                } else if (velocity > 250) {
                  // Swipe down: dismiss player (VH-001)
                  HapticFeedback.mediumImpact();
                  notifier.dismiss();
                }
              },
              
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Row(
                  children: [
                    // [NEW] Leading close button (44x44 touch target)
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      tooltip: 'Dismiss player',
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        notifier.dismiss();
                      },
                    ),
                    
                    const SizedBox(width: AppSpacing.xs),
                    
                    // Album art (44x44, tap to expand)
                    GestureDetector(
                      onTap: onExpand,
                      child: Hero(
                        tag: 'now_playing_art_${playerState.currentTrack!.id}',
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppGradients.forGenre(playerState.currentTrack!.genre),
                            borderRadius: BorderRadius.circular(AppRadius.thumb),
                          ),
                          child: const Icon(
                            Icons.piano_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: AppSpacing.xs),
                    
                    // Metadata (tap to expand)
                    Expanded(
                      child: GestureDetector(
                        onTap: onExpand,
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              playerState.currentTrack!.title,
                              style: AppTypography.bodyLarge.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${playerState.currentTrack!.genre} • ${playerState.formattedPosition} / ${playerState.formattedDuration}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Skip previous (44x44)
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        notifier.skipPrevious();
                      },
                    ),
                    
                    // Play/Pause orb (44x44)
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.brandPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          playerState.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: AppColors.brandContrast,
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          notifier.togglePlayPause();
                        },
                      ),
                    ),
                    
                    // Skip next (44x44)
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        notifier.skipNext();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

**Key Changes:**

1. **New Close Button**: Leading 44×44 IconButton with `Icons.close_rounded`, fires `notifier.dismiss()`
2. **Swipe-Down Gesture**: `onVerticalDragEnd` with velocity threshold `> 250` calls `dismiss()`
3. **Keyboard Avoidance**: Hide player when `viewInsets.bottom > 0` (REQ-RWD-03)
4. **Haptic Feedback**: `mediumImpact()` on dismiss, `lightImpact()` on swipe-up expand

**Design Tokens:**

- **Icon Color**: `AppColors.textSecondary` (muted close X)
- **Icon Size**: `20px` (slightly smaller than transport controls)
- **Spacing**: `AppSpacing.xs` (8dp) between close button and album art
- **Touch Target**: `44×44px` minimum per WCAG 2.5.5

**Animation:**

```dart
// In parent scaffold where MobileMiniPlayer is rendered:

AnimatedSwitcher(
  duration: const Duration(milliseconds: 200),
  switchInCurve: Curves.easeOut,
  switchOutCurve: Curves.easeIn,
  transitionBuilder: (child, animation) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    );
  },
  child: playerState.hasActiveTrack
      ? MobileMiniPlayer(key: const ValueKey('player'))
      : const SizedBox.shrink(key: ValueKey('empty')),
)
```

**Acceptance Criteria:**

- ✅ Tapping close button stops playback and removes player within 200ms
- ✅ Swipe-down gesture (velocity > 250) dismisses player
- ✅ Player hides when keyboard opens (`viewInsets.bottom > 0`)
- ✅ Player reappears when `playTrack()` called after dismissal
- ✅ No audio continues after dismiss
- ✅ Close button has 44×44px touch target
- ✅ Haptic feedback fires on dismiss action

---

### VH-002: Public/Private Visibility Toggle

**File:** `lib/features/studio/presentation/widgets/studio_action_bar.dart`

**Design Objective:** Bind visibility toggle to `visibility` field, persist across flows, update subtitle dynamically, and include in generation request.

**Current Implementation (Defect):**

```dart
// Toggle updates isPublic but does not persist to generation request
Switch(
  value: state.isPublic,
  onChanged: (val) {
    HapticFeedback.selectionClick();
    notifier.togglePublic(val);  // ❌ Only updates UI state
  },
)
```

**Target Implementation:**

```dart
class StudioActionBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studioFormProvider);
    final notifier = ref.read(studioFormProvider.notifier);
    
    final isAiLyrics =
        !state.isInstrumental && state.lyricsMode == LyricsMode.aiWrite;
    final ctaLabel = isAiLyrics ? 'Write Lyrics First' : 'Generate Song';
    final ctaIcon =
        isAiLyrics ? Icons.description_outlined : Icons.auto_awesome;
    
    // [NEW] Dynamic subtitle based on visibility
    final isPublic = state.visibility == 'public';
    final subtitle = isPublic
        ? 'Visible on Explore & your profile'
        : 'Only you can see this';
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Public Visibility Toggle Card
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Icon(
                isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                color: isPublic ? AppColors.brandPrimary : AppColors.textSecondary,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPublic ? 'Public' : 'Private',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    // [NEW] Dynamic subtitle
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // [UPDATED] Switch fires setVisibility(String)
              Switch(
                value: isPublic,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  notifier.setVisibility(val ? 'public' : 'private');
                },
                activeThumbColor: AppColors.brandPrimary,
                activeTrackColor: AppColors.brandPrimary.withAlpha(80),
                inactiveThumbColor: AppColors.textSecondary,
                inactiveTrackColor: AppColors.surfaceSecondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        
        // Primary Action CTA Button
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () => _handleGenerate(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.brandContrast,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.pillBorder,
              ),
              elevation: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(ctaIcon, size: 20, color: AppColors.brandContrast),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  ctaLabel,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.brandContrast,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // [REMOVED] Process description paragraph
        // [REMOVED] ToS/licensing notice (moved to Settings or one-time modal)
      ],
    );
  }
}
```

**Key Changes:**

1. **Dynamic Icon**: `Icons.public_rounded` when public, `Icons.lock_outline_rounded` when private
2. **Dynamic Title**: "Public" or "Private" based on `state.visibility`
3. **Dynamic Subtitle**: "Visible on Explore & your profile" or "Only you can see this"
4. **Switch Binding**: Calls `notifier.setVisibility('public' | 'private')`
5. **Color Mapping**: Orange when public, muted gray when private

**Generation Request Payload:**

```dart
// In generation trigger (e.g., API service)
Future<void> generateTrack(StudioFormState form) async {
  final payload = {
    'prompt': form.prompt,
    'genre': form.genre,
    'mood': form.mood,
    // ... other parameters
    'visibility': form.visibility,  // ✅ "public" or "private"
  };
  
  await api.post('/generations', body: payload);
}
```

**Backend API Requirements:**

```dart
// Pseudo-code for backend enforcement (not Flutter code)

// GET /explore/tracks
// Exclude tracks with visibility == "private"
SELECT * FROM tracks
WHERE visibility = 'public'
ORDER BY created_at DESC;

// GET /profiles/:userId/tracks
// If requesting user != profile owner, exclude private tracks
SELECT * FROM tracks
WHERE user_id = :userId
  AND (visibility = 'public' OR :requesterId = :userId);
```

**Acceptance Criteria:**

- ✅ Toggle updates `state.visibility` to "public" or "private"
- ✅ Subtitle text changes dynamically based on visibility
- ✅ Icon changes from `public_rounded` to `lock_outline_rounded`
- ✅ Generation request includes `visibility` field
- ✅ Visibility persists across "Write Lyrics First" flow (no reset in `approveLyrics()`)
- ✅ Private tracks excluded from Explore feed (backend enforcement)
- ✅ Haptic feedback fires on toggle

---

### VH-003: Description Text Removal

**File:** `lib/features/studio/presentation/widgets/studio_action_bar.dart`

**Design Objective:** Remove AI lyrics explanation paragraph and evaluate ToS/licensing notice. Reclaim vertical space to make cockpit usable on small devices.

**Current Layout (Defect):**

```
StudioActionBar Column:
  ├─ Public Toggle Card (~56px)
  ├─ Spacing (12px)
  ├─ Primary CTA Button (52px)
  ├─ Spacing (8px)
  ├─ Process Description Text (~40px) ❌ REMOVE
  ├─ Spacing (8px)
  ├─ ToS/Licensing Notice (~60px) ❌ EVALUATE

Total Height: ~236px (10% of 2310px screen)
Usable Cockpit: ~33% (with mini player docked)
```

**Target Layout (Fixed):**

```
StudioActionBar Column:
  ├─ Public Toggle Card (~56px)
  ├─ Spacing (12px)
  ├─ Primary CTA Button (52px)
  ├─ [OPTIONAL] Compact ToS Footer (24px if retained)

Total Height: ~120-144px (5-6% of screen)
Usable Cockpit: ~59% (with mini player dismissed)
```

**Implementation:**

```dart
return Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    // Public Toggle Card (56px)
    Container(/* ... */),
    
    const SizedBox(height: AppSpacing.md),  // 16px
    
    // Primary CTA Button (52px)
    SizedBox(
      height: 52,
      child: ElevatedButton(/* ... */),
    ),
    
    // [REMOVED] Process description:
    // "AI writes the lyrics → you review & edit → then the beat is produced"
    
    // [CONDITIONAL] Compact ToS footer (if legally required)
    if (_shouldShowToSFooter)
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text(
          'By generating, you agree to our Terms. See licensing →',
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ),
  ],
);
```

**Legal Decision Tree:**

**Option A (Recommended):** Move ToS/licensing notice to **one-time acceptance modal** on first generation:

```dart
// Show modal on first generation only
Future<void> _handleGenerate(BuildContext context, WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final hasAcceptedToS = prefs.getBool('has_accepted_generation_tos') ?? false;
  
  if (!hasAcceptedToS) {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generation Terms'),
        content: const Text(
          'By generating music, you agree to our Terms of Service. '
          'You own 100% of what you create on paid plans.\n\n'
          'See full licensing terms in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept & Generate'),
          ),
        ],
      ),
    );
    
    if (accepted == true) {
      await prefs.setBool('has_accepted_generation_tos', true);
    } else {
      return;  // User declined
    }
  }
  
  // Proceed with generation
  formNotifier.triggerGeneration();
}
```

**Option B:** Retain as single compact line (10sp, tertiary color, no line breaks)

**Option C:** Remove entirely and link from app footer or Settings > Legal

**Product Decision Required:** Confirm with legal/product whether ToS notice is required as consent mechanism before generation.

**Acceptance Criteria:**

- ✅ Process description paragraph removed
- ✅ ToS/licensing notice moved to one-time modal OR retained as compact footer OR removed
- ✅ `StudioActionBar` height reduced to ~120-144px
- ✅ At 360×640dp with mini player dismissed, prompt field + toggle + CTA button visible without scroll
- ✅ No legal/compliance risk introduced by removal

---

### VH-004: Creator DNA CTA Responsive Layout

**File:** `lib/features/onboarding/presentation/views/onboarding_view.dart`

**Design Objective:** Constrain "Activate Creator DNA ✨ →" button to prevent overflow at 360dp width and 130% font scale. Ensure 44×44px touch target and 16-24dp right margin.

**Current Layout (Defect):**

```dart
// Final onboarding page footer
Row(
  children: [
    // Page indicator dots (left side)
    _PageIndicator(currentPage: 5, totalPages: 6),  // ~48dp width
    
    const Spacer(),
    
    // CTA button (unbounded)
    ElevatedButton(
      onPressed: _activateDNA,
      child: Text('Activate Creator DNA ✨ →'),  // ❌ Overflows at 360dp
    ),
  ],
)
```

**Problem:** Button text exceeds available space (360dp - 48dp dots - 24dp margins = 288dp). At 130% font scale, text width ~320dp → clips right edge.

**Target Layout (Fixed):**

```dart
// Final onboarding page footer
Padding(
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
  child: Row(
    children: [
      // Page indicator dots (fixed width, left side)
      _PageIndicator(currentPage: 5, totalPages: 6),
      
      const SizedBox(width: AppSpacing.md),
      
      // [NEW] Flexible button with max width constraint
      Expanded(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: _calculateMaxButtonWidth(context),
            minHeight: 52,  // Ensure 44px content + padding
          ),
          child: ElevatedButton(
            onPressed: _activateDNA,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              foregroundColor: AppColors.brandContrast,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.pillBorder,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Activate Creator DNA →',  // Emoji removed for width savings
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.brandContrast,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
      
      // Right margin spacer (ensures 16-24dp from edge)
      const SizedBox(width: AppSpacing.md),
    ],
  ),
)

double _calculateMaxButtonWidth(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  const pageDotsWidth = 48.0;
  const horizontalMargins = AppSpacing.md * 3;  // Left + middle + right
  
  return max(screenWidth - pageDotsWidth - horizontalMargins, 240.0);
}
```

**Key Changes:**

1. **Expanded + ConstrainedBox**: Button grows to fill available space but never exceeds max width
2. **Max Width Calculation**: `screenWidth - dotsWidth - margins`, minimum 240dp
3. **FittedBox**: Scales text down if it exceeds container at large font scales
4. **Emoji Removed**: "Activate Creator DNA →" (no ✨) saves ~20dp width
5. **MinHeight**: 52dp ensures 44px minimum touch target with padding

**Responsive Breakpoints:**

| Viewport Width | Max Button Width | Right Margin |
|----------------|------------------|--------------|
| 360dp | 240dp | 16dp |
| 375dp | 255dp | 16dp |
| 414dp | 294dp | 24dp |
| 768dp+ | 600dp | 32dp |

**Accessibility:**

```dart
// Large font scale test (130%)
Text(
  'Activate Creator DNA →',
  style: AppTypography.titleMedium.copyWith(
    fontSize: 16 * 1.3,  // 20.8sp at 130% scale
  ),
)
// FittedBox scales down to fit 240dp container → prevents overflow
```

**Acceptance Criteria:**

- ✅ Button fully visible with 16-24dp right margin at 360dp, 375dp, 414dp
- ✅ At 130% font scale, button remains fully tappable (no clipping)
- ✅ Button has 44×44px minimum touch target (52dp height with padding)
- ✅ Text does not overflow at any system font scale (100%-200%)
- ✅ Max width responsive: adapts to screen width without hardcoded values

---

### VH-005: Real-Time Progress Tracker

**New Files:**
- `lib/features/studio/presentation/widgets/studio_progress_tracker.dart`
- `lib/features/studio/presentation/providers/progress_tracker_provider.dart`

**Design Objective:** Display compact, always-visible progress element showing 9/9 parameter slot completeness. Collapsed: slim bar (8-12dp). Expanded: scrollable slot list. Tap slot → scroll to control.

**Widget Structure:**

```dart
class StudioProgressTracker extends ConsumerWidget {
  final VoidCallback? onSlotTapped;
  
  const StudioProgressTracker({super.key, this.onSlotTapped});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressTrackerProvider);
    final isExpanded = ref.watch(_isExpandedProvider);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: isExpanded ? 320 : 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: isExpanded
          ? _ExpandedView(progress: progress, onSlotTapped: onSlotTapped)
          : _CollapsedBar(progress: progress),
    );
  }
}
```

**Collapsed Bar (Default State):**

```dart
class _CollapsedBar extends StatelessWidget {
  final ProgressTrackerState progress;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.read(_isExpandedProvider.notifier).toggle();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // Segmented progress bar
            Expanded(
              child: Row(
                children: List.generate(
                  progress.totalCount,
                  (index) {
                    final slot = progress.slots[index];
                    return Expanded(
                      child: Container(
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: _slotColor(slot.state),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            
            const SizedBox(width: AppSpacing.sm),
            
            // Completeness label
            Text(
              progress.completenessLabel,  // "6/9"
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            
            const SizedBox(width: AppSpacing.xs),
            
            // DNA percentage chip
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withAlpha(30),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 12,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '25%',  // Placeholder: read from DNA profile
                    style: AppTypography.caption.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: AppSpacing.xs),
            
            // Expand chevron
            Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
  
  Color _slotColor(SlotState state) {
    return switch (state) {
      SlotState.empty => AppColors.borderSubtle,
      SlotState.set => AppColors.brandPrimary,
      SlotState.auto => AppColors.brandPrimary.withAlpha(100),
    };
  }
}
```

**Expanded View (Slot List):**

```dart
class _ExpandedView extends StatelessWidget {
  final ProgressTrackerState progress;
  final VoidCallback? onSlotTapped;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Text(
                'Song Configuration',
                style: AppTypography.titleMedium,
              ),
              const Spacer(),
              Text(
                progress.completenessLabel,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                icon: const Icon(Icons.expand_less_rounded, size: 20),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.read(_isExpandedProvider.notifier).toggle();
                },
              ),
            ],
          ),
        ),
        
        Divider(height: 1, color: AppColors.borderSubtle),
        
        // Scrollable slot list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: progress.slots.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final slot = progress.slots[index];
              return _SlotTile(
                slot: slot,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onSlotTapped?.call();
                  // Scroll to corresponding control in cockpit
                  // Implementation: pass slot name to parent, parent scrolls
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
```

**Slot Tile:**

```dart
class _SlotTile extends StatelessWidget {
  final ParameterSlot slot;
  final VoidCallback? onTap;
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardBorder,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: AppRadius.cardBorder,
        ),
        child: Row(
          children: [
            // State indicator icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _stateColor(slot.state).withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _stateIcon(slot.state),
                size: 16,
                color: _stateColor(slot.state),
              ),
            ),
            
            const SizedBox(width: AppSpacing.sm),
            
            // Slot name and value
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.name,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (slot.value != null)
                    Text(
                      slot.value!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            
            // State badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: _stateColor(slot.state).withAlpha(30),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                _stateLabel(slot.state),
                style: AppTypography.badge.copyWith(
                  color: _stateColor(slot.state),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _stateColor(SlotState state) {
    return switch (state) {
      SlotState.empty => AppColors.textTertiary,
      SlotState.set => AppColors.brandPrimary,
      SlotState.auto => AppColors.accentGold,
    };
  }
  
  IconData _stateIcon(SlotState state) {
    return switch (state) {
      SlotState.empty => Icons.radio_button_unchecked_rounded,
      SlotState.set => Icons.check_circle_rounded,
      SlotState.auto => Icons.auto_awesome_rounded,
    };
  }
  
  String _stateLabel(SlotState state) {
    return switch (state) {
      SlotState.empty => 'EMPTY',
      SlotState.set => 'SET',
      SlotState.auto => 'AUTO',
    };
  }
}
```

**Placement in Cockpit:**

```dart
// In StudioView (Create screen)
Column(
  children: [
    // Tab bar (Compose | Voice | Crate)
    _StudioTabBar(),
    
    // [NEW] Progress tracker (pinned under tabs)
    const StudioProgressTracker(
      onSlotTapped: (slotName) {
        // Scroll to corresponding control
        _scrollController.animateTo(
          _getSlotOffset(slotName),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      },
    ),
    
    // Scrollable form fields
    Expanded(
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            PromptField(),
            GenreSelector(),
            MoodSelector(),
            // ... other controls
            StudioActionBar(),
          ],
        ),
      ),
    ),
  ],
)
```

**Haptic Feedback:**

```dart
// On slot state transition (e.g., user selects mood)
ref.listen(progressTrackerProvider, (previous, next) {
  if (previous != null && next.filledCount > previous.filledCount) {
    HapticFeedback.lightImpact();  // Tick on progress increase
  }
});
```

**Performance Optimization:**

```dart
// Wrap tracker in RepaintBoundary to isolate repaints
RepaintBoundary(
  child: StudioProgressTracker(),
)

// Use const constructors for static slot widgets
const _SlotTile(slot: slot, onTap: onTap)
```

**Acceptance Criteria:**

- ✅ Collapsed bar shows 9 segmented progress indicators (filled/empty)
- ✅ Completeness label updates in real-time ("6/9")
- ✅ DNA percentage chip displays current DNA usage
- ✅ Tapping collapsed bar expands to slot list
- ✅ Expanded view shows all 9 slots with name, value, and state badge
- ✅ Tapping slot scrolls to corresponding cockpit control
- ✅ Haptic tick fires on slot state transition
- ✅ Progress updates within one frame (<16ms at 60fps)
- ✅ State derived from `StudioFormState` (no duplicate state)
- ✅ Slot states correct: Empty (unconfigured), Set (user), Auto (DNA)

---

### VH-006: Professional Brand Identity

**Files Modified:**
- `lib/core/widgets/vhunambi_app_bar.dart`
- `lib/core/constants/app_assets.dart`

**Files Created:**
- `assets/branding/vhunambi_compact_mark_light.svg`
- `assets/branding/vhunambi_compact_mark_dark.svg`
- `assets/branding/vhunambi_full_lockup.svg`
- `android/app/src/main/res/mipmap-*/ic_launcher_foreground.png`

**Design Objective:** Replace "VHUNAMBI Studio" text title with compact brand mark (SVG logo). Provide 60-80px horizontal clearance for credits chip. Deliver light/dark variants and adaptive launcher icon.

**Current Header (Defect):**

```dart
// lib/core/widgets/vhunambi_app_bar.dart
Row(
  children: [
    const Icon(Icons.music_note, size: 24),  // ❌ Generic icon
    const SizedBox(width: 8),
    Text(
      'VHUNAMBI Studio',  // ❌ ~160-180px width
      style: AppTypography.titleLarge,
    ),
    const Spacer(),
    CreditsChip(),  // Collides at 360dp
  ],
)
```

**Target Header (Fixed):**

```dart
// lib/core/widgets/vhunambi_app_bar.dart
Row(
  children: [
    // [NEW] Compact brand mark (80-100px width)
    SvgPicture.asset(
      AppAssets.vhunambiCompactMark,
      width: 90,
      height: 32,
      colorFilter: ColorFilter.mode(
        _logoColor(context),
        BlendMode.srcIn,
      ),
    ),
    
    const Spacer(),
    
    // Credits chip (now has 70-90px clearance at 360dp)
    const CreditsChip(),
  ],
)

Color _logoColor(BuildContext context) {
  final brightness = Theme.of(context).brightness;
  return brightness == Brightness.dark
      ? AppColors.brandPrimary
      : AppColors.textPrimary;
}
```

**Asset Constants:**

```dart
// lib/core/constants/app_assets.dart
abstract final class AppAssets {
  // Branding
  static const String vhunambiCompactMark = 'assets/branding/vhunambi_compact_mark.svg';
  static const String vhunambiFullLockup = 'assets/branding/vhunambi_full_lockup.svg';
  
  // PNG fallbacks for legacy Android
  static const String vhunambiCompactMarkPng = 'assets/branding/vhunambi_compact_mark.png';
  
  // Existing assets...
}
```

**pubspec.yaml:**

```yaml
dependencies:
  flutter_svg: ^2.0.9  # Add if not already present

flutter:
  assets:
    - assets/branding/
    - assets/branding/vhunambi_compact_mark.svg
    - assets/branding/vhunambi_full_lockup.svg
```

---

### Logo Asset Specifications

**Compact Mark (Header Usage):**

- **Dimensions**: 90×32dp (optimized for app bar)
- **Safe Zone**: 8dp padding around glyph
- **Primary Color**: `AppColors.brandPrimary` (#F97316)
- **Dark Mode**: Full color (orange on dark surface)
- **Light Mode**: `AppColors.textPrimary` (white/black on light surface)
- **Export**: SVG with single path, no embedded rasters
- **File**: `assets/branding/vhunambi_compact_mark.svg`

**Full Lockup (Splash/Onboarding):**

- **Dimensions**: 240-320dp width, aspect ratio preserved
- **Components**: Wordmark + icon
- **Spacing**: 16dp between icon and wordmark
- **Usage**: Splash screen, onboarding welcome page
- **Export**: SVG, 2x/3x PNG fallbacks
- **File**: `assets/branding/vhunambi_full_lockup.svg`

**Adaptive Launcher Icon (Android):**

- **Foreground Layer**: 108×108dp canvas, 72×72dp safe zone
- **Icon Size**: 56-64dp centered in safe zone
- **Background Layer**: Solid `AppColors.surfaceCanvas` (#0A0A0C) OR gradient `AppGradients.amapiano`
- **Export**: `ic_launcher_foreground.png` at mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi
- **File**: `android/app/src/main/res/mipmap-*/ic_launcher_foreground.png`

**Color Variants:**

| Asset | Dark Mode | Light Mode |
|-------|-----------|------------|
| Compact Mark | `#F97316` (orange) | `#000000` (black) |
| Full Lockup | `#F97316` (orange) | `#000000` (black) |
| Launcher Icon | Full color (always) | Full color (always) |

**Trademark Clearance:**

- ✅ Search USPTO database for conflicts
- ✅ Search Google Images for similar marks
- ✅ Consult legal before finalizing design
- ✅ Document clearance in `docs/legal/trademark_search.md`

---

### Implementation Example

**Compact Mark SVG Template:**

```xml
<!-- assets/branding/vhunambi_compact_mark.svg -->
<svg width="90" height="32" viewBox="0 0 90 32" fill="none" xmlns="http://www.w3.org/2000/svg">
  <!-- Placeholder: Replace with actual logo path -->
  <path d="M10 8 L16 24 L22 8 M30 8 V24 M38 8 V24 L46 8 V24 M54 8 H62 M58 16 H62 M58 24 H62" 
        stroke="#F97316" 
        stroke-width="2.5" 
        stroke-linecap="round" 
        stroke-linejoin="round"/>
  <!-- Simplified "VH" monogram - actual design TBD -->
</svg>
```

**Usage in App Bar:**

```dart
class VhunambiAppBar extends ConsumerWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: AppColors.surfaceCanvas,
      elevation: 0,
      title: Row(
        children: [
          // Compact brand mark
          SvgPicture.asset(
            AppAssets.vhunambiCompactMark,
            width: 90,
            height: 32,
            colorFilter: ColorFilter.mode(
              Theme.of(context).brightness == Brightness.dark
                  ? AppColors.brandPrimary
                  : AppColors.textPrimary,
              BlendMode.srcIn,
            ),
          ),
          
          const Spacer(),
          
          // Credits chip
          const CreditsChip(),
        ],
      ),
    );
  }
}
```

**Acceptance Criteria:**

- ✅ Compact mark replaces "VHUNAMBI Studio" text
- ✅ Header width reduced from ~180px to ~90px
- ✅ Credits chip has 70-90px clearance at 360dp (no collision)
- ✅ Logo renders correctly in dark and light modes
- ✅ SVG scales without pixelation at 1x, 2x, 3x densities
- ✅ Full lockup appears on splash and onboarding screens
- ✅ Adaptive launcher icon exported at all densities
- ✅ Trademark search completed and documented

---

## Analytics Integration

### New Events

**VH-001: `studio_player_dismissed`**

```dart
void _trackPlayerDismiss(Track track, Duration position, String method) {
  analytics.logEvent(
    name: 'studio_player_dismissed',
    parameters: {
      'track_id': track.id,
      'playback_position_sec': position.inSeconds,
      'dismiss_method': method,  // "button" | "swipe_down"
    },
  );
}

// Fire on dismiss action
notifier.dismiss();
_trackPlayerDismiss(
  playerState.currentTrack!,
  playerState.position,
  'button',  // or 'swipe_down' if from gesture
);
```

**VH-002: `studio_visibility_toggled`**

```dart
void _trackVisibilityToggle(String visibility, String lyricsMode, String genre) {
  analytics.logEvent(
    name: 'studio_visibility_toggled',
    parameters: {
      'visibility': visibility,  // "public" | "private"
      'lyrics_mode': lyricsMode,  // "aiWrite" | "myOwn" | "instrumental"
      'genre': genre,
    },
  );
}

// Fire on toggle change
notifier.setVisibility(val ? 'public' : 'private');
_trackVisibilityToggle(
  val ? 'public' : 'private',
  state.lyricsMode.name,
  state.genre,
);
```

**VH-005: `studio_progress_slot_tapped`**

```dart
void _trackSlotTap(String slotName, SlotState slotState, String completeness) {
  analytics.logEvent(
    name: 'studio_progress_slot_tapped',
    parameters: {
      'slot_name': slotName,  // "Prompt" | "Genre" | "Mood" | ...
      'slot_state': slotState.name,  // "empty" | "set" | "auto"
      'completeness_ratio': completeness,  // "6/9"
    },
  );
}

// Fire on slot tile tap
onTap: () {
  _trackSlotTap(slot.name, slot.state, progress.completenessLabel);
  onSlotTapped?.call();
}
```

**VH-004: `studio_cta_overflow_detected`**

```dart
void _detectCtaOverflow(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final fontScale = MediaQuery.of(context).textScaleFactor;
  
  // Measure button width
  final buttonWidth = _measureButtonWidth(context);
  
  if (buttonWidth > screenWidth - 16) {
    analytics.logEvent(
      name: 'studio_cta_overflow_detected',
      parameters: {
        'viewport_width': screenWidth.toInt(),
        'button_width': buttonWidth.toInt(),
        'font_scale': fontScale,
      },
    );
  }
}

// Call on final onboarding page build
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _detectCtaOverflow(context);
  });
}
```

---

## Testing Strategy

### Unit Tests

**VH-001: Player Dismiss**

```dart
// test/features/player/presentation/providers/player_provider_test.dart

test('dismiss() stops playback and clears state', () {
  final notifier = PlayerNotifier();
  notifier.playTrack(mockTrack);
  
  expect(notifier.state.hasActiveTrack, true);
  expect(notifier.state.isPlaying, true);
  
  notifier.dismiss();
  
  expect(notifier.state.hasActiveTrack, false);
  expect(notifier.state.isPlaying, false);
  expect(notifier.state.currentTrack, null);
  expect(notifier.state.position, Duration.zero);
});
```

**VH-002: Visibility State**

```dart
// test/features/studio/presentation/providers/studio_form_provider_test.dart

test('setVisibility() updates state to "private"', () {
  final notifier = StudioFormNotifier();
  
  notifier.setVisibility('private');
  
  expect(notifier.state.visibility, 'private');
});

test('approveLyrics() preserves visibility', () {
  final notifier = StudioFormNotifier();
  
  notifier.setVisibility('private');
  notifier.approveLyrics('Custom lyrics here');
  
  expect(notifier.state.visibility, 'private');  // NOT reset to default
  expect(notifier.state.customLyrics, 'Custom lyrics here');
});
```

**VH-005: Progress Tracker State Derivation**

```dart
// test/features/studio/presentation/providers/progress_tracker_provider_test.dart

test('slot states derived from StudioFormState', () {
  final formState = StudioFormState(
    prompt: '',  // Empty
    genre: 'Amapiano',  // Set (non-default)
    mood: 'Uplifting',  // Auto (default)
    visibility: 'private',  // Set
  );
  
  final progress = ProgressTrackerState.fromStudioForm(formState);
  
  expect(progress.slots[0].state, SlotState.empty);  // Prompt
  expect(progress.slots[1].state, SlotState.set);     // Genre
  expect(progress.slots[2].state, SlotState.auto);    // Mood
  expect(progress.slots[8].state, SlotState.set);     // Visibility
  expect(progress.filledCount, 8);  // All except prompt
});
```

---

### Widget Tests

**VH-001: Mini Player Swipe Dismiss**

```dart
// test/features/player/presentation/widgets/mobile_mini_player_test.dart

testWidgets('swipe down dismisses player', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: MobileMiniPlayer(),
        ),
      ),
    ),
  );
  
  // Simulate swipe down with velocity > 250
  await tester.drag(
    find.byType(MobileMiniPlayer),
    const Offset(0, 300),
    warnIfMissed: false,
  );
  await tester.pumpAndSettle();
  
  // Verify dismiss() was called
  final container = ProviderScope.containerOf(tester.element(find.byType(MobileMiniPlayer)));
  final playerState = container.read(playerStateProvider);
  
  expect(playerState.hasActiveTrack, false);
});

testWidgets('keyboard hides player', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  viewInsets: const EdgeInsets.only(bottom: 300),  // Keyboard open
                ),
                child: MobileMiniPlayer(),
              );
            },
          ),
        ),
      ),
    ),
  );
  
  await tester.pump();
  
  // Player should be hidden (SizedBox.shrink)
  expect(find.byType(MobileMiniPlayer), findsNothing);
});
```

**VH-002: Visibility Toggle**

```dart
// test/features/studio/presentation/widgets/studio_action_bar_test.dart

testWidgets('toggle updates visibility and subtitle', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: StudioActionBar(),
        ),
      ),
    ),
  );
  
  // Initial state: Public
  expect(find.text('Public'), findsOneWidget);
  expect(find.text('Visible on Explore & your profile'), findsOneWidget);
  
  // Toggle to Private
  await tester.tap(find.byType(Switch));
  await tester.pump();
  
  // Verify state updated
  expect(find.text('Private'), findsOneWidget);
  expect(find.text('Only you can see this'), findsOneWidget);
  
  final container = ProviderScope.containerOf(tester.element(find.byType(StudioActionBar)));
  final formState = container.read(studioFormProvider);
  expect(formState.visibility, 'private');
});
```

**VH-003: Description Text Removed**

```dart
// test/features/studio/presentation/widgets/studio_action_bar_test.dart

testWidgets('description text not rendered', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: StudioActionBar(),
        ),
      ),
    ),
  );
  
  // Verify AI lyrics description removed
  expect(
    find.text('AI writes the lyrics → you review & edit → then the beat is produced'),
    findsNothing,
  );
  
  // Verify ToS notice removed or moved
  expect(
    find.textContaining('By generating, you agree to our Terms'),
    findsNothing,  // OR findsOneWidget if retained as compact footer
  );
});
```

**VH-004: CTA No Overflow**

```dart
// test/features/onboarding/presentation/views/onboarding_view_test.dart

testWidgets('DNA CTA button fits at 360dp', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(360, 640)),
        child: OnboardingView(),
      ),
    ),
  );
  
  // Navigate to final page
  for (int i = 0; i < 5; i++) {
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
  }
  
  // Find CTA button
  final buttonFinder = find.text('Activate Creator DNA →');
  expect(buttonFinder, findsOneWidget);
  
  // Verify button right edge within screen bounds (with 16dp margin)
  final buttonRect = tester.getRect(buttonFinder);
  expect(buttonRect.right, lessThanOrEqualTo(360 - 16));
});

testWidgets('DNA CTA accessible at 130% font scale', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 640),
          textScaleFactor: 1.3,
        ),
        child: OnboardingView(),
      ),
    ),
  );
  
  // Navigate to final page and verify button size
  // ... navigation code ...
  
  final buttonFinder = find.widgetWithText(ElevatedButton, 'Activate Creator DNA →');
  final buttonSize = tester.getSize(buttonFinder);
  
  // Verify minimum 44×44 touch target
  expect(buttonSize.width, greaterThanOrEqualTo(44));
  expect(buttonSize.height, greaterThanOrEqualTo(44));
});
```

**VH-005: Progress Tracker Slot Tap**

```dart
// test/features/studio/presentation/widgets/studio_progress_tracker_test.dart

testWidgets('tapping slot fires callback', (tester) async {
  String? tappedSlot;
  
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: StudioProgressTracker(
            onSlotTapped: (slotName) {
              tappedSlot = slotName;
            },
          ),
        ),
      ),
    ),
  );
  
  // Expand tracker
  await tester.tap(find.byType(StudioProgressTracker));
  await tester.pumpAndSettle();
  
  // Tap a slot (e.g., "Mood")
  await tester.tap(find.text('Mood'));
  await tester.pump();
  
  expect(tappedSlot, 'Mood');
});
```

---

### Integration Tests

**VH-001: Dismiss and Reflow**

```dart
// integration_test/studio_player_dismiss_test.dart

testWidgets('dismiss player, layout reflows, play again', (tester) async {
  app.main();
  await tester.pumpAndSettle();
  
  // Generate a track (triggers player)
  await tester.tap(find.text('Generate Song'));
  await tester.pumpAndSettle(const Duration(seconds: 3));
  
  // Player visible
  expect(find.byType(MobileMiniPlayer), findsOneWidget);
  
  // Dismiss player
  await tester.tap(find.byIcon(Icons.close_rounded));
  await tester.pumpAndSettle();
  
  // Player hidden
  expect(find.byType(MobileMiniPlayer), findsNothing);
  
  // Generate another track
  await tester.tap(find.text('Generate Song'));
  await tester.pumpAndSettle(const Duration(seconds: 3));
  
  // Player visible again
  expect(find.byType(MobileMiniPlayer), findsOneWidget);
});
```

**VH-002: Visibility Persists Across Flows**

```dart
// integration_test/lyrics_flow_visibility_test.dart

testWidgets('visibility preserved in lyrics review flow', (tester) async {
  app.main();
  await tester.pumpAndSettle();
  
  // Set visibility to Private
  await tester.tap(find.byType(Switch));
  await tester.pumpAndSettle();
  
  // Enter "Write Lyrics First" flow
  await tester.tap(find.text('Write Lyrics First'));
  await tester.pumpAndSettle(const Duration(seconds: 2));
  
  // Approve lyrics
  await tester.tap(find.text('Approve & Generate'));
  await tester.pumpAndSettle();
  
  // Verify visibility still Private
  final container = ProviderScope.containerOf(tester.element(find.byType(StudioActionBar)));
  final formState = container.read(studioFormProvider);
  expect(formState.visibility, 'private');
});
```

---

## Migration Timeline

### Phase 1: Add Visibility Field (Week 1)

**Tasks:**
1. Add `visibility: String` field to `StudioFormState`
2. Add `setVisibility(String)` method to `StudioFormNotifier`
3. Sync `isPublic` with `visibility` in constructor
4. Update `StudioActionBar` to use `visibility` instead of `isPublic`
5. Mark `isPublic` as `@Deprecated`
6. Write unit tests for `setVisibility()`

**Deliverables:**
- [ ] `StudioFormState` with dual fields
- [ ] `StudioFormNotifier.setVisibility()` method
- [ ] `StudioActionBar` reading `visibility`
- [ ] Unit tests passing

---

### Phase 2: Update Call Sites (Week 2-3)

**Tasks:**
1. Update generation request payload to send `visibility` field
2. Update API service to include `visibility` in POST body
3. Update backend (out of scope for this doc) to enforce visibility
4. Grep codebase for `isPublic` usages and migrate to `visibility`
5. Run `flutter analyze` to catch remaining usages
6. Update widget tests to use `visibility`

**Deliverables:**
- [ ] All call sites migrated to `visibility`
- [ ] Backend API enforcing visibility (Explore exclusion)
- [ ] Widget tests passing
- [ ] Zero `flutter analyze` warnings

---

### Phase 3: Remove isPublic (Week 4)

**Tasks:**
1. Delete `isPublic` field from `StudioFormState`
2. Delete `togglePublic()` method from `StudioFormNotifier`
3. Run full test suite (991 tests)
4. Verify no regressions with manual QA

**Deliverables:**
- [ ] `isPublic` removed from codebase
- [ ] 991 tests passing
- [ ] QA sign-off on visibility functionality

---

## Risk Assessment

### Breaking Changes

**RISK-BC-01:** Replacing `isPublic: bool` with `visibility: String` is a breaking change to state model.

**Mitigation:** Use 3-phase migration strategy (add, migrate, remove) to ensure zero downtime and backward compatibility.

---

### Privacy & Legal Compliance

**RISK-PL-01:** Visibility defaults to `"public"`, which may violate GDPR/CCPA if users expect private-by-default.

**Mitigation:** Conduct privacy impact assessment. Consider defaulting to `"private"` with explicit opt-in to Public visibility.

**RISK-PL-02:** Removing ToS/licensing notice (VH-003) may violate legal consent requirements.

**Mitigation:** Confirm with legal/product whether notice is required. If yes, retain as compact footer or move to one-time acceptance modal.

---

### Performance Impact

**RISK-PF-01:** Progress tracker updates on every parameter change, potentially triggering 9-slot UI rebuilds at 60fps.

**Mitigation:**
- Use `const` constructors for static slot widgets
- Wrap tracker in `RepaintBoundary`
- Throttle updates to 30fps if performance degrades on mid-range devices
- Profile with `flutter run --profile` on target device (e.g., Samsung A32)

**RISK-PF-02:** Swipe-down dismiss gesture introduces gesture arena conflict with page scroll.

**Mitigation:** Use `GestureDetector.onVerticalDragEnd` with velocity threshold (> 250) and direction locking after 24dp travel to prevent false positives.

---

### Accessibility Compliance

**RISK-AC-01:** Swipe-down gesture violates WCAG 2.1 SC 2.1.1 (Keyboard) and SC 2.5.1 (Pointer Gestures) for users who cannot perform gestures.

**Mitigation:** Provide alternative dismiss mechanism via visible close button (44×44px touch target). Gesture is supplementary, not exclusive.

**RISK-AC-02:** CTA button fails 44×44px touch target at 130% font scale.

**Mitigation:** Use `ConstrainedBox(minHeight: 52)` and `FittedBox` to ensure button scales correctly. Test at 200% font scale to guarantee compliance.

---

## Open Questions

**OQ-01:** Should default visibility be Public or Private?

**Recommendation:** Private-by-default with explicit opt-in to Public. Aligns with GDPR "privacy by design" principle.

---

**OQ-02:** Is ToS/licensing notice legally required before generation?

**Recommendation:** Confirm with legal. If required, move to one-time acceptance modal on first generation. If not required, remove entirely and link from Settings.

---

**OQ-03:** Should progress tracker show DNA % as dynamic or static?

**Current:** Static "25%" placeholder. **Recommendation:** Dynamic: read from `CreatorDnaProfile.strength` field and update as user trains DNA.

---

**OQ-04:** Should logo assets be AI-generated or commissioned from designer?

**Recommendation:** Generate concepts with AI (DALL-E, Midjourney) for speed, then vectorize and refine in Figma/Illustrator. Ensure trademark clearance before finalizing.

---

## Appendix A: Design Token Reference

### Colors

```dart
AppColors.surfaceCanvas       // #0A0A0C — Pitch black canvas
AppColors.surfaceElevated     // #141418 — Dark charcoal card
AppColors.surfaceSecondary    // #1B1B22 — Inset container
AppColors.surfaceModal        // #16161C — Modal sheet
AppColors.borderSubtle        // #2D2D38 — 1px border
AppColors.borderActive        // #4B4B5A — Focused outline
AppColors.brandPrimary        // #F97316 — Vibrant orange
AppColors.brandPrimaryDark    // #EA580C — Pressed state
AppColors.brandContrast       // #000000 — Black on orange
AppColors.textPrimary         // #FFFFFF — High-contrast headers
AppColors.textSecondary       // #9CA3AF — Muted metadata
AppColors.textTertiary        // #6B7280 — Placeholder hints
AppColors.accentGold          // #F59E0B — System / DNA gold
```

### Spacing

```dart
AppSpacing.xxs      // 4dp
AppSpacing.xs       // 8dp
AppSpacing.sm       // 12dp
AppSpacing.md       // 16dp
AppSpacing.lg       // 20dp
AppSpacing.xl       // 24dp
AppSpacing.xxl      // 32dp
AppSpacing.section  // 40dp
```

### Typography

```dart
AppTypography.displayLarge    // 32sp, 700 weight
AppTypography.displayMedium   // 28sp, 700 weight
AppTypography.titleLarge      // 20sp, 600 weight
AppTypography.titleMedium     // 16sp, 600 weight
AppTypography.bodyLarge       // 14sp, 500 weight
AppTypography.bodyMuted       // 14sp, 400 weight
AppTypography.bodySmall       // 12sp, 400 weight
AppTypography.caption         // 11sp, 400 weight
AppTypography.badge           // 10sp, 700 weight
```

### Radii

```dart
AppRadius.pill        // 9999dp — Fully rounded
AppRadius.modal       // 24dp — Bottom sheet
AppRadius.card        // 16dp — Card container
AppRadius.input       // 12dp — Text field
AppRadius.thumb       // 8dp — Small button
AppRadius.sm          // 6dp — Chip
```

---

## Appendix B: Component Hierarchy Diagram

```
MaterialApp
 └─ MainScaffold
     ├─ BottomNavigationBar
     │   └─ NavigationDestination × 4
     └─ IndexedStack
         ├─ CreateView (Studio Cockpit)
         │   ├─ VhunambiAppBar [VH-006]
         │   │   ├─ Logo (SvgPicture)
         │   │   └─ CreditsChip
         │   ├─ TabBar (Compose | Voice | Crate)
         │   ├─ StudioProgressTracker [VH-005]
         │   │   ├─ _CollapsedBar (default)
         │   │   └─ _ExpandedView (on tap)
         │   ├─ ScrollView
         │   │   ├─ PromptField
         │   │   ├─ GenreSelector
         │   │   ├─ MoodSelector
         │   │   ├─ TempoSelector
         │   │   ├─ VocalEnergySelector
         │   │   ├─ LanguageSelector
         │   │   └─ StudioActionBar [VH-002, VH-003]
         │   │       ├─ PublicToggleCard
         │   │       └─ PrimaryCTAButton
         │   └─ MobileMiniPlayer [VH-001]
         │       ├─ CloseButton (leading)
         │       ├─ AlbumArt
         │       ├─ Metadata
         │       ├─ SkipPrevious
         │       ├─ PlayPause
         │       └─ SkipNext
         ├─ ExploreView
         ├─ LibraryView
         └─ ProfileView

OnboardingView [VH-004]
 └─ PageView
     ├─ WelcomePage
     ├─ CreativeIdentityPage
     ├─ GenreHeritagePage
     ├─ SoundSignaturePage
     ├─ MoodPage
     └─ CreatorDnaPage
         └─ Footer
             ├─ PageIndicator
             └─ DNActaButton (Flexible + ConstrainedBox)
```

---

## Document Version

**Version:** 1.0.0  
**Last Updated:** 2026-10-20  
**Status:** Ready for Implementation  
**Next Phase:** Task Creation (tasks.md) — Break down components into atomic implementation tasks

