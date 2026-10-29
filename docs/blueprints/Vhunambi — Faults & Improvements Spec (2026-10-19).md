# Vhunambi — Faults & Improvements Spec

**Date:** 19 Oct 2026  |  **Owner:** Marcel (NMS-02 Technologies)  |  **Scope:** Studio cockpit + onboarding  |  **Status:** Ready for implementation

Source: field testing on device plus the four screenshots captured at 00:10–00:11 (Creative Identity, Sound Signature, Studio cockpit, Creator DNA).

## 1. Summary and priority order

The cockpit is the revenue surface (credits are spent here), so cockpit friction comes first. Onboarding is the activation surface, so it comes second. Within each, ship bugs before redesigns.

| ID | Item | Type | Priority |
| --- | --- | --- | --- |
| VH-001 | Bottom player cannot be closed | Bug | P0 |
| VH-002 | Public/Private toggle does nothing | Bug | P0 |
| VH-003 | Cockpit description text wastes vertical space | UX fix | P0 |
| VH-004 | Creator DNA page CTA overflows screen edge | Bug | P0 |
| VH-005 | Real-time song progress tracker in cockpit | Feature | P1 |
| VH-006 | Studio branding: logo asset replaces text title | Design | P1 |
| VH-007 | Creative Identity: horizontal card carousel | Redesign | P1 |
| VH-008 | Genre Heritage: per-genre colours | Redesign | P2 |
| VH-009 | Sound Signature: plain-language, genre-referenced copy | Copy/UX | P1 |
| VH-010 | Mood: per-mood colours | Redesign | P2 |
| VH-011 | Creator DNA page: visualisation and explanation | Redesign | P1 |
| VH-012 | Onboarding app tour (feature awareness) | Feature | P1 |
| VH-013 | Verify privacy claim on DNA page | Compliance | P0 |

---

## 2. Studio cockpit

### VH-001 — Bottom player has no close action

**Problem:** The mini player docked above the bottom nav ("Grateful in the Li… / Amapiano / 0:18") cannot be dismissed. It permanently consumes roughly 90px of vertical space on the Create screen.

**Requirements**

- Add a close (X) control to the mini player.
- Closing stops playback, releases the audio session/player instance, and clears the current-track state.
- Optional: swipe-down or swipe-away gesture to dismiss.
- Player re-appears when the user starts playback of any track.

**Acceptance criteria**

- Tapping close stops audio and removes the player within one frame; the cockpit layout reflows to use the freed space.
- No audio continues in the background after close.
- Close state does not persist across a new playback action.

### VH-002 — Public toggle is non-functional

**Problem:** The "Public — Visible on Explore & your profile" switch does not affect the song being produced.

**Requirements**

- Bind the toggle to a `visibility` field (`public` | `private`) in the generation request state.
- Send `visibility` with the generation request and persist it on the track record.
- Server/back end must enforce it: private tracks are excluded from Explore feeds and from the public profile endpoint.
- Subtitle text reflects state: Public = "Visible on Explore & your profile"; Private = "Only you can see this".
- Default value to be decided as a product call (current default is Public; confirm this is intentional, since it is a privacy-sensitive default).

**Acceptance criteria**

- Generate with toggle off, then confirm the track appears only in the user's Library and never in Explore or the profile view of another account.
- Generate with toggle on, then confirm the track appears in both.
- State survives the "Write Lyrics First" flow, so lyrics review does not reset the toggle.
- Visibility can be changed later from the track's detail screen (follow-up, not blocking).

### VH-003 — Remove the description block under "Write Lyrics First"

**Problem:** The lower card holds the Public toggle, the "Write Lyrics First" button, and two description paragraphs. The paragraphs ("AI writes the lyrics → you review & edit → then the beat is produced" and the Terms of Service/licensing line) push the cockpit content down and make it hard to use.

**Requirements**

- Remove the lyrics-flow explanation paragraph. The button label is self-explanatory; if explanation is still needed, move it to a one-time tooltip or the app tour (VH-012).
- **Legal check before removing the ToS/licensing line:** this is the consent notice for generation. Either keep it as a single compact footer line (small, one line) or move it to a one-time acceptance at first generation. Do not delete it without a replacement.
- Component height shrinks to toggle + button only; confirm the layout reclaims the space on small devices (test at 360×640dp).

**Acceptance criteria**

- The card contains only the toggle row and the button.
- The prompt field, toggle, and primary button are all visible without scrolling on a 360×640dp viewport with the mini player closed.

### VH-004 — Creator DNA page CTA overflows screen edge

**Problem:** On the final onboarding page, the "Activate Creator DNA ✨ →" button extends past the right edge of the screen and is clipped. The page-indicator dots on the left consume width, and the button does not constrain itself.

**Requirements**

- Wrap the button in a flexible/expanded container with a bounded max width; shorten the label or allow it to scale on narrow screens.
- Test across small, medium, large phones and with large system font settings.

**Acceptance criteria**

- Button fully visible with 16–24dp right margin on every tested device and at 130% font scale.

### VH-005 — Real-time song progress tracker ("build completeness")

**Problem:** Users miss options by oversight and have no signal telling them what they have configured versus left blank.

**Concept:** A compact, always-visible progress element in the cockpit that fills as the user makes choices, like a character-build or quest tracker.

**Tracked items** (each is a named "slot")

- Description/prompt
- Genre / heritage
- Mood
- Tempo feel
- Vocal energy
- Language/dialect
- Lyrics (written or skipped)
- DNA usage (percentage of Creator DNA applied)
- Visibility (set)

**Behaviour**

- Each slot has three states: **Empty**, **Set**, **Auto** (filled by DNA suggestion rather than by the user).
- Overall ring or bar shows `filled / total`, plus a DNA % chip.
- Tapping a slot scrolls to or opens that control.
- Light animation and haptic tick when a slot flips to Set (reuse the haptics layer from VH-007).
- Generate is never blocked by empty slots (they are optional), but if slots are empty, the button shows a soft hint such as "3 options still open".

**Placement options for decision**

1. Slim segmented bar pinned under the Compose/Voice/Crate tabs (recommended: always visible, \~8–12dp tall, expands on tap into the slot list).
2. Collapsible bottom sheet.

**Acceptance criteria**

- State is derived from a single source of truth (the generation request model), not duplicated UI state.
- Updates within one frame of any option change.
- Slot list expanded view shows each slot's current value.

### VH-006 — Studio branding: replace text title with a logo asset

**Problem:** The header shows the text "VHUNAMBI Studio" next to a generic music-note icon. It crowds the header (the credits chip is nearly colliding with it) and does not read as a brand.

**Deliverables**

- Vhunambi wordmark/logo (primary lockup), plus a compact mark for the app bar.
- Formats: SVG (vector, for in-app), PNG @1x/2x/3x, adaptive launcher icon.
- Light and dark variants; the app is dark-first, orange (#F97316-range) is the current brand accent.
- Generation note: logo can be generated by an AI image tool as concepts, but the final must be vectorised and checked for trademark conflicts before shipping.

**Acceptance criteria**

- Header uses the compact mark only; the full lockup appears on splash and onboarding.
- Credits chip no longer collides with branding at 360dp width.

---

## 3. Onboarding

**Screen index note:** the page dots show six screens. Screenshots confirm Creative Identity is screen 2 and Sound Signature is screen 5, so numbering below uses screen titles, not positions. Confirm the final order in the flow file.

### VH-007 — Creative Identity: horizontal card carousel

**Problem:** The vertical list of five roles is flat, and the screen is long enough that "Experience Level" sits below the fold, partly hidden behind the footer.

**Requirements**

- Replace the vertical list with a horizontal card carousel (large cards, centre card emphasised, neighbours scaled and dimmed).
- Each card: illustration or animated icon, title, one-line description.
- Selection: tap the card; check mark animates in, card scales slightly, **haptic feedback** on select (light impact) and on snap between cards (selection tick).
- **Gesture conflict:** the carousel must not trigger the onboarding page transition. The onboarding PageView swipe is disabled while the carousel is in use. Page navigation happens only through the Continue button (or a drag that begins outside the carousel bounds).
- Keep Experience Level below the carousel and make sure the whole screen fits without hidden content.

**Acceptance criteria**

- Horizontal swipes inside the carousel never change the onboarding page.
- Haptics fire on select and snap on both Android and iOS; respect the system haptics setting.
- Selected state persists on back-navigation.

### VH-008 — Genre Heritage: distinct colour per genre

**Requirements**

- Define a colour token per genre (a theme map: `genre → {accent, surface-tint, glow}`), for example Amapiano, Afro House, Gqom, Kwaito, Afro Pop, Maskandi, Hip-Hop, Gospel.
- Selected state uses that genre's accent for border, text, and check mark, and a tinted surface, replacing the single orange highlight.
- The same map is reused in the cockpit, the progress tracker (VH-005), and track cards on Explore/Library so a genre looks the same everywhere.
- Ensure contrast ratio ≥ 4.5:1 for text on the tinted surface, and do not rely on colour alone (check mark remains).

### VH-009 — Sound Signature: natural language, genre-referenced

**Problem:** Tempo is expressed as BPM ranges ("Slow (70–95 BPM)"). Most users do not know what BPM means.

**Tempo Feel — new copy (BPM kept internally, hidden or shown only as secondary small text)**

| Current | New label | Reference |
| --- | --- | --- |
| Slow (70–95 BPM) | Laid back | Feels like Deep House and Kizomba: slow, smooth, swaying |
| Medium (100–118 BPM) | Easy groove | Feels like Amapiano and Afro Pop: relaxed but danceable |
| Fast (120–135 BPM) | Driving | Feels like Afro Tech and Gqom: heads nod, floor fills |
| Hyperspeed (140+ BPM) | Full speed | Feels like Singeli and Shangaan: fast, frantic, high energy |

**Vocal Energy — genre-referenced replacements**

| Current | New label | Reference |
| --- | --- | --- |
| Soft & Intimate | Smooth and tender | Like a love song: soft, close, warm voice |
| Balanced & Melodic | Easy and melodic | Like Afro Pop and R&B: natural, singable |
| (high energy option) | Raw and aggressive | Like Rap and Drill: punchy, hard-hitting delivery |
| (high energy option) | Loud and gritty | Like Rock: raw, strained, big voice |

Support additional options as needed (for example Gospel: powerful and uplifting). The two screenshots show only the first two vocal energy options; confirm the full option set in code and map each.

**Requirements**

- Internal enum values and the BPM/vocal-parameter mapping stay unchanged; this is a presentation-layer change only (backwards compatible with saved profiles).
- Cards show a tiny genre-colour chip (from VH-008) next to the reference genres.
- Localisation: copy is stored in the string resource files so that the same wording can be translated for native-language support later.

### VH-010 — Mood: distinct colour per mood

**Requirements**

- The mood copy stays as is. Add a colour token per mood (for example Joyful = warm yellow, Melancholic = deep blue, Energetic = red-orange, Calm = teal, Romantic = pink) with the same selected-state treatment as VH-008.
- Keep the mood palette visually distinct from the genre palette (genre = card accent, mood = chip/glow) to avoid confusion when both appear together in the cockpit.

### VH-011 — Creator DNA page: visualisation and explanation

**Problem:** The feature is the product's differentiator but the page is two chips, a 25% bar, and two lines of text. It does not show what the user just built or what the DNA does.

**Requirements**

- **Visualise the user's DNA:** an animated double-helix (or radial/orbital graphic) whose strands or nodes are coloured by the choices the user made (genre colours from VH-008, mood colours from VH-010, role from VH-007). Build-up animation on entry: nodes light up one by one as the profile is "synthesised".
- **Explain what it is, in three short beats:**
  1. "Built from your choices": your roles, genres, tempo, vocal feel, mood.
  2. "Shapes every song": pre-fills the cockpit and steers generation toward your sound.
  3. "Grows with you": every song you make, keep, or edit sharpens it; the model strength moves from 25% towards 100%.
- **Show the growth path:** a simple 25% → 50% → 75% → 100% track with what unlocks at each stage (to be defined by product).
- Replace the "Initial Model Strength" bar with something more meaningful (strength ring plus the visual).
- Keep the CTA (see VH-004 for the overflow fix).

**Acceptance criteria**

- DNA visual reflects the user's actual selections (not a static image).
- Animation runs at 60fps on a mid-range device and respects the reduce-motion setting.
- Each strength milestone is explained in plain language.

### VH-012 — Onboarding app tour (feature awareness)

**Problem:** The user answers questions but is never told what the app can do. After onboarding, discoverability depends on guessing.

**Requirements**

- Add a short tour (3–5 cards) **before** the final Creator DNA screen or immediately after activation: skippable, one idea per card, with a visual.
- Suggested coverage, in order of value: **Compose** (describe a song and generate it); **Write Lyrics First** (AI drafts, you edit, then the beat); **Voice** (vocal synthesis); **Crate & MPC** (sample crate and pad production); **Library, Explore, Market** (store, discover, publish); **Credits** (what the 10 free credits do and what a generation costs).
- Contextual coach marks on first entry to the Studio cockpit for the top 2–3 controls, shown once.
- Track tour completion and skip rate (analytics event) so the tour can be tuned.

**Acceptance criteria**

- Tour can be skipped at any point, and replayed from Settings.
- Shows once per account.

### VH-013 — Verify privacy claim on Creator DNA page

**Problem:** The DNA page states "100% on-device sovereignty (zero cloud tracking)". Music is generated by AI, the Public toggle publishes to Explore, and the app has analytics and credits, so this claim is very likely inaccurate as written.

**Action:** Audit what is stored on-device versus sent to the server (DNA profile, prompts, generated audio, analytics). Reword to exactly what is true (for example "Your DNA profile is stored on your device") or change the architecture to match. Misleading privacy claims are a legal and store-review risk.

---

## 4. Cross-cutting engineering notes

- **Single design-token source** for genre and mood colours so cockpit, onboarding, Explore, and tracker do not drift apart.
- **Haptics service wrapper** used by VH-005, VH-007, VH-008, VH-010 so intensity and the system setting are handled in one place.
- **Generation request model** is the single source of truth for VH-002 (visibility), VH-005 (progress), and VH-009 (tempo/vocal mapping).
- **Accessibility:** colour is never the only indicator, support reduce-motion, test at large font scale.
- **Analytics events to add:** onboarding step completed/skipped, tour completed/skipped, progress tracker slot interactions, visibility selected at generation.

## 5. Suggested delivery order

1. **Sprint 1 (bugs + space):** VH-001, VH-002, VH-003, VH-004, VH-013
2. **Sprint 2 (cockpit value):** VH-005, VH-006
3. **Sprint 3 (onboarding activation):** VH-007, VH-009, VH-012, VH-011, with VH-008 and VH-010 delivered together as the shared colour system

## 6. Open questions

- Default visibility for new tracks: Public or Private?
- Final onboarding screen order and the complete option lists for vocal energy and mood (only partly visible in screenshots).
- Legal wording for the ToS/licensing notice once the description block is removed.
- What each DNA strength milestone unlocks.

---

## 7. Addendum A: Adaptive mini player and Now Playing cockpit

**Added:** 19 Oct 2026 | **Stack:** Flutter / Dart

This addendum replaces the solution in VH-001 (a bare close button) with a full adaptive player design. VH-001's core requirement, that the player can be dismissed, carries over as an acceptance criterion in VH-014.

| ID | Item | Type | Priority |
| --- | --- | --- | --- |
| VH-014 | Adaptive mini player: Auto mode, manual gestures, three forms | Feature | P0 (phase A), P1 (phases B to D) |
| VH-015 | Yellow underlines across the Now Playing cockpit | Bug | P0 |
| VH-016 | Dead controls in the Now Playing cockpit | Bug | P0 |
| VH-017 | Now Playing layout defects | Bug | P1 |

### Evidence from screenshots

- **Create screen with the bar docked:** the scrollable cockpit area runs from about y=465 to y=1225 on a 2310px screen, roughly **33% of the screen**. The language list is clipped at both edges. The bar itself costs about 185px (\~8%) and the description text under Write Lyrics First about 190px (\~8%). Removing the text (VH-003) and getting the bar out of the way (VH-014) returns roughly 16% of the screen to the user.
- **Now Playing:** yellow underlines on the header, title, artist, genre chip, timestamps and tab labels. The bottom action row is clipped at the fourth item (label reads E...). Heart and Lyrics each appear twice.
- **Bar:** the duration label is truncated (3:...).

---

### VH-014: Adaptive mini player

**Principle (no over-engineering):** one player widget, one controller, one state machine. Pages do not know about the player's gestures. They only declare which layers they occupy.

**Modes**

- **Auto (default):** the player docks above the bottom nav and moves out of the way of page-declared layers.
- **Manual:** once the user drags the bar vertically, it stays where they put it. Manual ends when the user drags into the bottom extreme zone (dock + Auto again).

**Forms**

| Form | Appearance | Tap on body | Hold + drag |
| --- | --- | --- | --- |
| Bar | Full width, cover art, title, genre, progress, prev/play/next. Original state. | Opens Now Playing | Vertical: moves up and down (enters Manual). Diagonal up: morphs to Card |
| Card | Small card (about 128dp square): cover art, progress percentage, visualisation embedded in the card background. | Opens Now Playing | Free drag anywhere on screen, stays where released |
| Pill | Small floating pill with a glow. Glow colours come from the cover art, intensity follows the music, so it reads like a disco light painted by the song. | Opens Now Playing | Free drag anywhere on screen, stays where released |

Tap always opens the Now Playing cockpit in every form. The bar's own buttons (prev, play/pause, next) keep their own taps.

**Transitions**

| From | Action | To |
| --- | --- | --- |
| Bar | Hold, then drag diagonally up | Card, attached to the side the diagonal pointed toward |
| Bar or Card | Drag into the top extreme zone, release | Pill |
| Any form | Drag into the bottom extreme zone, release | Bar, docked, Auto mode |
| Card or Pill | Drag anywhere else | Same form, new position |

**Gesture rules**

- Activation: long press (350ms) on the player body. On activation: medium haptic, scale to 1.03, stronger shadow.
- Direction is decided once the finger has travelled 24dp, then locked for the rest of that gesture. Angle is measured from the vertical axis: under 20 degrees is vertical, 20 to 70 degrees upward is diagonal, a downward diagonal is treated as vertical, and anything beyond 70 degrees is ignored on the Bar.
- Extreme zones are visible only while dragging: a top band (safe-area top + 72dp) and a bottom band (dock area including the nav bar). Entering a band highlights it and fires a selection haptic. The morph commits on release, and dragging back out before release cancels it.
- Keep Card and Pill at least 16dp from the side edges so they do not fight the Android back gesture.

**Auto mode: layer avoidance**

- Pages wrap bottom-anchored layers (for example the cockpit generate card, sticky CTAs, bottom sheets) in a `PlayerObstacle` widget. It registers its on-screen Rect with the controller and unregisters on dispose.
- Target position of the Bar in Auto: 8dp above the top of the highest obstacle that intersects the dock band. Animate 200ms.
- Keyboard open (`viewInsets.bottom > 0`): hide the Bar until it closes. The cockpit has a text field, so this case is guaranteed to happen.
- The reverse direction: the controller exposes `reservedBottom` (Bar height while docked and visible, otherwise 0). Scrollables use a `PlayerReservedPadding` so pages stop hard-coding space for the player. Card and Pill reserve nothing.
- The player hides on: Now Playing open, onboarding, splash and auth.

**Dismissal (carried over from VH-001)**

The gesture design has no close action yet. Recommendation: a horizontal fling off screen dismisses the player in any form. It stops playback and clears the player state. See open question 1.

**Flutter implementation**

- **Host:** `MaterialApp.builder` returns `Stack(children: [child!, const MiniPlayerHost()])`, so one instance lives above every route. Wrap the host root in `Material(type: MaterialType.transparency)`, otherwise its text gets the yellow underline from VH-015.
- **State:** one `MiniPlayerController extends ChangeNotifier` (use whichever state management the app already uses). Holds form, mode, position, obstacles. Position is stored as fractions of the screen so it survives other screen sizes and rotation.
- **Morph:** one `AnimationController` (260 to 300ms, `Curves.easeOutCubic`) interpolating the shell's Rect, border radius and shadow. Content cross-fades inside the shell. Do not build three separate overlay widgets.
- **Gestures:** `RawGestureDetector` with `LongPressGestureRecognizer(duration: Duration(milliseconds: 350))`, move updates from `onLongPressMoveUpdate`. Taps via `GestureDetector.onTap`.
- **Persistence:** form, mode and position in `shared_preferences`. Clamp to the safe area on restore.
- **Glow:** dominant colours from the cover art with `palette_generator`, computed once per track and cached. Amplitude comes from the pre-computed waveform peaks already drawn in the cockpit, sampled by playback position. No real-time FFT in v1. Paint with `CustomPainter` inside a `RepaintBoundary`, throttle to 30fps, and stop animating when paused (static glow with a slow breathe) or when the app is backgrounded.
- **Accessibility:** expose `Semantics.customSemanticsActions` (Dock, Convert to card, Move to top) as alternatives to the hold gestures. Respect reduce-motion (no pulsing, no spring).

Proposed files (confirm against your tree):

- `lib/features/player/mini_player/mini_player_host.dart`
- `lib/features/player/mini_player/mini_player_controller.dart`
- `lib/features/player/mini_player/mini_player_gestures.dart`
- `lib/features/player/mini_player/forms/bar_form.dart`, `card_form.dart`, `pill_form.dart`
- `lib/features/player/mini_player/player_obstacle.dart`
- `lib/features/player/mini_player/glow_painter.dart`

```dart
enum MiniForm { bar, card, pill }
enum MiniMode { auto, manual }
enum DragIntent { none, vertical, diagonalUp }

DragIntent classify(Offset total) {
  if (total.distance < 24) return DragIntent.none;
  // 0 degrees = straight vertical
  final angle = math.atan2(total.dx.abs(), total.dy.abs()) * 180 / math.pi;
  if (angle < 20) return DragIntent.vertical;
  if (angle <= 70) {
    return total.dy < 0 ? DragIntent.diagonalUp : DragIntent.vertical;
  }
  return DragIntent.none;
}
// Side to attach on morph: total.dx < 0 ? left edge : right edge
```

**Delivery phases (each one shippable on its own)**

1. **Phase A (P0):** global host, Auto mode, obstacle registry, dismissal. Ship together with VH-003 so removing the description does not create a layering clash.
2. **Phase B:** hold + vertical drag, Manual mode, bottom extreme reset.
3. **Phase C:** Card form and the diagonal morph.
4. **Phase D:** Pill form, top extreme zone, cover-art glow.

**Acceptance criteria**

- One player instance across every route. Switching tabs never restarts or duplicates it.
- In Auto, the Bar never overlaps a registered page layer on the Create screen, at 360x640dp and on a tall device.
- Hold + vertical drag follows the finger with no visible lag (60fps on a mid-range device). Direction is locked once decided.
- Every form opens Now Playing on tap, and the Bar's buttons still work.
- Dragging into the bottom extreme returns any form to the docked Bar in Auto.
- Form, mode and position survive an app restart.
- Card and Pill stay inside the safe area and at least 16dp from the side edges.
- The glow animation stops when playback is paused or the app is backgrounded.
- No audio plays after a dismiss.

---

### VH-015: Yellow underlines across the Now Playing cockpit

**Problem:** Text in the Now Playing view renders with a yellow double underline (header, title, artist, genre chip, timestamps, tab labels).

**Likely cause:** text rendered without a `Material` ancestor falls back to Flutter's error text style, which is exactly the yellow double underline. This happens in release builds too. The cockpit view is most likely being built in an overlay or custom route that has no `Scaffold` or `Material` above it.

**Fix**

- Wrap the root of the Now Playing view once in `Material(type: MaterialType.transparency)`, or build it as a `Scaffold`-based page. Do not patch individual `Text` widgets with `decoration: TextDecoration.none`.
- Apply the same wrapper to `MiniPlayerHost` (VH-014) and to any other overlay.
- Audit every place that builds UI outside a `Scaffold`: search the codebase for `OverlayEntry`, `showGeneralDialog`, `PageRouteBuilder` and `MaterialApp.builder`.

**Acceptance criteria:** no yellow underlines anywhere in a release build: Now Playing, mini player in all forms, dialogs, sheets, onboarding.

---

### VH-016: Dead controls in the Now Playing cockpit

**Problem:** several controls render but do nothing. A control that does nothing is a trust problem in a product that charges credits.

**Rule:** every visible control either works or is removed. Search the codebase for `onPressed: () {}`, `onTap: () {}` and `onPressed: null` to find the dead ones, then implement against this table.

| Control | Required behaviour |
| --- | --- |
| Chevron (collapse) and drag handle | Close the cockpit and return to the player's previous form |
| Heart (shown twice) | Like or unlike the track, optimistic UI, persisted. Keep one (next to the title) and remove the header duplicate |
| Lyrics (header icon and bottom tab, duplicates) | Keep the bottom tab. Opens the lyrics view: synced lines if timing exists, otherwise a static scrolling view. Remove the header duplicate or reuse the slot for another action |
| Clapperboard (header, and the clipped tab at the end of the action row) | Intent not confirmed. Define it or remove it. See open question 5 |
| Overflow (three dots) | Menu: add to playlist, download, copy link, change visibility (links to VH-002), delete |
| Share | System share sheet with a deep link. Private tracks cannot produce a public link: prompt to make the track public first |
| Waveform | Tap and drag to seek, with the played portion highlighted |
| Shuffle | Toggle, active state visible, persisted |
| Repeat | Cycles off, all, one. State visible, persisted |
| Previous | Restarts the track if more than 3s in, otherwise previous in queue. Disabled when there is nothing before |
| Next | Next in queue. Behaviour at end of queue follows Repeat. Disabled when the queue is empty |
| Stems | Stem mixer (vocals, drums, bass, other): mute, solo, volume per stem. If a track has no stems, show how to generate them and the credit cost. See open question 6 |
| Details | Prompt, genre, mood, tempo feel, DNA percentage used, created date, visibility, licensing |

**Acceptance criteria**

- Zero controls with an empty handler anywhere in the player code.
- A widget test per control: tap leads to the expected state change.
- Disabled controls look disabled (reduced opacity, no ripple).

---

### VH-017: Now Playing layout defects

- The bottom action row is clipped at the fourth item. Make it horizontally scrollable with an edge fade, or cap it at four actions.
- Remove the duplicates listed in VH-016 (heart, lyrics) so the header has room.
- Bar: the duration label is truncated (3:...). Give it a fixed minimum width and shrink the title area instead.
- Title is truncated with an ellipsis and there is no way to read the full title. Long-press to expand, or marquee only while playing.

---

### Open questions for this addendum

1. **Dismissal:** confirm horizontal fling in any form, or specify another mechanism.
2. **Manual mode:** it persists until the bottom extreme reset. Confirm, or specify whether Auto should resume on navigation.
3. **Card placement:** the design says the Card attaches to the side the diagonal pointed toward, then can be dragged and stays wherever it is released. Confirm there is no further edge snapping after the first attach.
4. **Play/pause on Card and Pill:** tap always opens the cockpit, so there is no way to play or pause without opening it. Options: double-tap, or a small control on the Card.
5. **Clapperboard icon:** what should it do (video, visualiser, export)?
6. **Stems:** do all tracks have stems, or are they a paid generation?
7. **Extreme zones:** the morph commits on release in this spec, not on entry. Confirm.
