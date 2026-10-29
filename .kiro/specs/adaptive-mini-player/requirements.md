# Requirements Document

## Introduction

The Adaptive Mini Player is a comprehensive music player interface redesign that introduces three morphing player forms (Bar, Card, Pill) with intelligent auto-positioning, manual gesture control, and visual feedback through cover-art reactive glows. This feature addresses critical UX issues where the current docked player bar permanently consumes ~8% of screen real estate, blocks cockpit controls during music generation, and provides no mechanism for dismissal or repositioning.

The feature includes four phased delivery increments (A through D), fixes for Material theming bugs causing yellow underlines, implementation of 12 non-functional Now Playing controls, and resolution of layout defects including action row overflow and duplicate UI elements.

## Glossary

- **Mini_Player**: The persistent music playback interface that appears across all app screens
- **Now_Playing_Cockpit**: The full-screen music control interface opened by tapping the Mini_Player
- **Player_Form**: One of three visual representations: Bar, Card, or Pill
- **Bar_Form**: The default horizontal player docked above bottom navigation
- **Card_Form**: A 128dp square floating card with cover art
- **Pill_Form**: A minimal floating pill with cover-art reactive glow
- **Auto_Mode**: Default positioning mode where the Bar automatically avoids registered obstacles
- **Manual_Mode**: User-controlled positioning activated by hold-drag gesture
- **Player_Obstacle**: A page-declared UI element that the Bar must avoid in Auto_Mode
- **Extreme_Zone**: Screen regions (top or bottom) that trigger form morphs during drag
- **Bottom_Extreme_Zone**: The dock area plus bottom navigation, triggers return to Bar + Auto_Mode
- **Top_Extreme_Zone**: Safe area top + 72dp band, triggers morph to Pill_Form
- **Hold_Gesture**: Long press for 350ms that activates Manual_Mode drag
- **Dismiss_Gesture**: Horizontal fling at >250 px/s velocity that closes the player
- **Morph_Animation**: Animated transition between player forms (260-300ms duration)
- **Cover_Art_Glow**: Visual effect where colors extracted from cover art pulse with music amplitude
- **Waveform_Peaks**: Pre-computed audio amplitude data used to drive glow intensity
- **MiniPlayerHost**: Global Flutter widget that manages player lifecycle and rendering
- **MiniPlayerController**: State management class that coordinates form, mode, position, and obstacles
- **PlayerObstacle_Widget**: Flutter widget that registers bottom-anchored UI layers with the controller
- **Reserved_Bottom**: Dynamic padding value exposed by controller for page content layout
- **Material_Transparency_Bug**: Flutter theming issue causing yellow underlines on text without Material ancestor
- **Dead_Control**: A Now_Playing_Cockpit button that renders but has no implementation
- **Action_Row**: Horizontal control strip in Now_Playing_Cockpit (Share, Stems, Details, overflow)
- **Safe_Area**: Screen region excluding system UI (status bar, notches, navigation gestures)
- **Haptic_Feedback**: Physical vibration responses on gesture milestones
- **System_Haptics_Setting**: OS-level user preference for haptic feedback intensity
- **Reduce_Motion_Setting**: OS-level accessibility preference to minimize animations
- **SharedPreferences**: Flutter persistent storage for user settings and state
- **Screen_Fraction**: Position stored as 0.0-1.0 ratio of screen dimensions for rotation survival
- **Palette_Generator**: Flutter package that extracts dominant colors from images
- **RepaintBoundary**: Flutter optimization widget that isolates repaints to child subtree
- **Optimistic_UI**: Immediate UI feedback before server confirmation
- **Stem_Mixer**: Audio track decomposition interface (vocals, drums, bass, other)
- **DNA_Percentage**: User profile strength metric (25-100%)
- **Visibility_State**: Track privacy setting (Public or Private)
- **System_Share_Sheet**: Platform-native sharing interface

## Requirements

### Requirement 1: Global Player Architecture

**User Story:** As a developer, I want a single player instance managed globally, so that playback state persists across navigation and screen composition is predictable.

#### Acceptance Criteria

1. THE MiniPlayerHost SHALL be instantiated exactly once via MaterialApp.builder Stack overlay
2. WHEN any route is pushed or popped, THE MiniPlayerHost SHALL remain mounted and preserve playback state
3. THE MiniPlayerHost root widget SHALL be wrapped in Material with type MaterialType.transparency
4. THE MiniPlayerController SHALL extend ChangeNotifier and expose form, mode, position, and obstacles as observable state
5. WHEN the app launches, THE MiniPlayerController SHALL restore form, mode, and position from SharedPreferences
6. WHEN position is restored, THE MiniPlayerController SHALL clamp coordinates to the current Safe_Area bounds
7. THE MiniPlayerHost SHALL hide itself WHEN Now_Playing_Cockpit is open OR onboarding is active OR splash screen is visible OR authentication screen is visible

### Requirement 2: Auto Mode Obstacle Avoidance

**User Story:** As a user generating music, I want the player bar to move out of the way automatically, so that I can access all cockpit controls without manual repositioning.

#### Acceptance Criteria

1. WHEN Auto_Mode is active AND Bar_Form is displayed, THE MiniPlayerController SHALL position the Bar 8dp above the highest registered Player_Obstacle that intersects the dock area
2. WHEN a PlayerObstacle_Widget is mounted, THE PlayerObstacle_Widget SHALL register its on-screen Rect with the MiniPlayerController
3. WHEN a PlayerObstacle_Widget is disposed, THE PlayerObstacle_Widget SHALL unregister itself from the MiniPlayerController
4. WHEN obstacle registrations change, THE MiniPlayerController SHALL animate the Bar to its new target position over 200ms
5. WHEN the system keyboard opens (viewInsets.bottom > 0), THE MiniPlayerHost SHALL hide the Bar until the keyboard closes
6. THE MiniPlayerController SHALL expose Reserved_Bottom as zero WHEN Bar_Form is hidden OR Card_Form is active OR Pill_Form is active
7. THE MiniPlayerController SHALL expose Reserved_Bottom as Bar height plus 8dp WHEN Bar_Form is docked and visible
8. WHEN Reserved_Bottom changes, THE page scrollable widgets wrapped in PlayerReservedPadding SHALL adjust their bottom padding to match

### Requirement 3: Bar Form Default State

**User Story:** As a user listening to music, I want a compact bar showing essential controls, so that I can play/pause and skip tracks without opening the full cockpit.

#### Acceptance Criteria

1. THE Bar_Form SHALL display full-width spanning the screen minus Safe_Area horizontal insets
2. THE Bar_Form SHALL contain cover art, track title, genre chip, progress indicator, previous button, play/pause button, and next button
3. WHEN the user taps the Bar_Form body (excluding control buttons), THE MiniPlayerHost SHALL open the Now_Playing_Cockpit
4. WHEN the user taps the previous button, THE Bar_Form SHALL restart the current track IF playback position > 3 seconds ELSE skip to previous track
5. WHEN the user taps the previous button AND the current track is first in queue AND Repeat mode is off, THE previous button SHALL be visually disabled
6. WHEN the user taps the next button, THE Bar_Form SHALL skip to the next track respecting Repeat mode
7. WHEN the user taps the next button AND the current track is last in queue AND Repeat mode is off, THE next button SHALL be visually disabled
8. WHEN the user taps the play/pause button, THE Bar_Form SHALL toggle playback state and update the button icon within 100ms

### Requirement 4: Hold Gesture Activation

**User Story:** As a power user, I want to hold and drag the player bar vertically, so that I can manually position it when auto mode doesn't match my needs.

#### Acceptance Criteria

1. WHEN the user long-presses the Bar_Form body for 350ms, THE MiniPlayerHost SHALL activate Manual_Mode drag tracking
2. WHEN Manual_Mode activates, THE MiniPlayerHost SHALL fire a medium intensity haptic feedback respecting System_Haptics_Setting
3. WHEN Manual_Mode activates, THE Bar_Form SHALL scale to 1.03 and increase shadow elevation
4. WHEN the user's finger has traveled 24dp from press origin, THE MiniPlayerHost SHALL classify drag direction and lock it for the gesture duration
5. WHEN drag direction is classified as vertical (angle < 20 degrees from vertical axis), THE Bar_Form SHALL follow the user's finger vertically within Safe_Area bounds
6. WHEN drag direction is classified as diagonal-up (angle 20-70 degrees AND dy < 0), THE Bar_Form SHALL initiate morph to Card_Form (Phase C requirement)
7. WHEN drag direction angle exceeds 70 degrees from vertical, THE MiniPlayerHost SHALL ignore the gesture
8. WHEN the user releases during vertical drag outside extreme zones, THE Bar_Form SHALL remain at the released position in Manual_Mode
9. THE drag tracking SHALL maintain 60fps on a mid-range Android device (Snapdragon 662 or equivalent)

### Requirement 5: Bottom Extreme Zone Reset

**User Story:** As a user experimenting with player positioning, I want to drag the player to the bottom to reset it, so that I can quickly return to the default docked state.

#### Acceptance Criteria

1. WHEN the user drags the Bar_Form OR Card_Form OR Pill_Form into the Bottom_Extreme_Zone, THE MiniPlayerHost SHALL highlight the zone with a visual indicator
2. WHEN the player enters the Bottom_Extreme_Zone, THE MiniPlayerHost SHALL fire a selection tick haptic feedback respecting System_Haptics_Setting
3. WHEN the user releases inside the Bottom_Extreme_Zone, THE MiniPlayerHost SHALL morph the player to Bar_Form over 260ms
4. WHEN the Bottom_Extreme_Zone morph completes, THE MiniPlayerController SHALL set mode to Auto_Mode
5. WHEN the Bottom_Extreme_Zone morph completes, THE Bar_Form SHALL position itself according to Auto_Mode obstacle avoidance rules
6. WHEN the user drags back out of the Bottom_Extreme_Zone before releasing, THE zone highlight SHALL disappear and the morph SHALL be cancelled

### Requirement 6: Horizontal Fling Dismissal

**User Story:** As a user who wants to stop music, I want to fling the player off screen, so that I can dismiss it with a single gesture instead of hunting for a close button.

#### Acceptance Criteria

1. WHEN the user performs a horizontal fling gesture on any Player_Form with velocity > 250 px/s, THE MiniPlayerHost SHALL animate the player off screen in the fling direction over 180ms
2. WHEN the dismiss animation completes, THE MiniPlayerController SHALL stop playback immediately
3. WHEN the dismiss animation completes, THE MiniPlayerController SHALL clear current track state
4. WHEN the dismiss animation completes, THE MiniPlayerHost SHALL unmount the player widget
5. WHEN a new track starts playing after dismissal, THE MiniPlayerHost SHALL remount in Bar_Form at default docked position in Auto_Mode

### Requirement 7: State Persistence Across Sessions

**User Story:** As a user who customized player positioning, I want my preferences remembered, so that I don't have to reposition the player every time I open the app.

#### Acceptance Criteria

1. WHEN the MiniPlayerController form changes, THE MiniPlayerController SHALL persist the new form to SharedPreferences key "player_form"
2. WHEN the MiniPlayerController mode changes, THE MiniPlayerController SHALL persist the new mode to SharedPreferences key "player_mode"
3. WHEN the player position changes in Manual_Mode, THE MiniPlayerController SHALL persist position as Screen_Fraction to SharedPreferences keys "player_position_x" and "player_position_y"
4. WHEN the app launches, THE MiniPlayerController SHALL read persisted values and restore player state before first frame render
5. WHEN restored position falls outside Safe_Area bounds (device rotation or different screen size), THE MiniPlayerController SHALL clamp coordinates to valid range maintaining relative positioning

### Requirement 8: Card Form Morphing and Free Positioning

**User Story:** As a user watching video content while music plays, I want a compact card player I can position anywhere, so that it doesn't block important video regions.

#### Acceptance Criteria

1. WHEN the user performs a diagonal-up hold-drag from Bar_Form with angle 20-70 degrees, THE MiniPlayerHost SHALL morph to Card_Form over 280ms using Curves.easeOutCubic
2. WHEN the Card_Form morph begins, THE MiniPlayerHost SHALL attach the card to screen edge matching the drag direction's horizontal component (dx < 0 = left edge, dx > 0 = right edge)
3. THE Card_Form SHALL render as a 128dp square with rounded corners, displaying cover art and a progress percentage overlay
4. THE Card_Form SHALL maintain minimum 16dp clearance from all Safe_Area edges to avoid Android back gesture conflicts
5. WHEN the user taps the Card_Form body, THE MiniPlayerHost SHALL open the Now_Playing_Cockpit
6. WHEN the user performs a hold-drag on Card_Form, THE Card_Form SHALL follow the user's finger to any screen position within Safe_Area bounds
7. WHEN the user releases during Card_Form drag outside extreme zones, THE Card_Form SHALL remain at the released position in Manual_Mode
8. THE Card_Form morph animation SHALL maintain 60fps on a mid-range Android device

### Requirement 9: Pill Form and Top Extreme Zone

**User Story:** As a minimalist user, I want the player to shrink to a glowing pill, so that I have maximum screen space while still seeing visual feedback that music is playing.

#### Acceptance Criteria

1. WHEN the user drags any Player_Form into the Top_Extreme_Zone (Safe_Area top + 72dp band), THE MiniPlayerHost SHALL highlight the zone with a visual indicator
2. WHEN the player enters the Top_Extreme_Zone, THE MiniPlayerHost SHALL fire a selection tick haptic feedback respecting System_Haptics_Setting
3. WHEN the user releases inside the Top_Extreme_Zone, THE MiniPlayerHost SHALL morph the player to Pill_Form over 260ms
4. THE Pill_Form SHALL render as a small rounded pill displaying a pulsing Cover_Art_Glow effect
5. WHEN the user taps the Pill_Form body, THE MiniPlayerHost SHALL open the Now_Playing_Cockpit
6. WHEN the user performs a hold-drag on Pill_Form, THE Pill_Form SHALL follow the user's finger to any screen position within Safe_Area bounds
7. THE Pill_Form SHALL maintain minimum 16dp clearance from all Safe_Area edges

### Requirement 10: Cover Art Reactive Glow

**User Story:** As a music lover, I want the pill player to glow with colors from the album art that pulse with the music, so that the player feels alive and connected to what's playing.

#### Acceptance Criteria

1. WHEN a new track loads, THE MiniPlayerController SHALL extract dominant colors from the cover art using Palette_Generator within 200ms
2. THE MiniPlayerController SHALL cache extracted colors for the track duration to avoid redundant computation
3. WHEN Pill_Form is displayed AND playback is active, THE Pill_Form SHALL sample amplitude from Waveform_Peaks at current playback position
4. THE Pill_Form glow intensity SHALL interpolate between 0.3 (low amplitude) and 1.0 (high amplitude) using sampled values
5. THE Pill_Form glow SHALL paint using CustomPainter wrapped in RepaintBoundary to isolate repaints
6. THE glow animation SHALL throttle to 30fps (33ms frame budget) to conserve battery
7. WHEN playback is paused, THE Pill_Form glow SHALL display a static breathe animation at 0.5 intensity cycling over 2 seconds
8. WHEN the app is backgrounded, THE glow animation SHALL stop completely
9. WHEN Reduce_Motion_Setting is enabled, THE glow SHALL display static at 0.5 intensity with no animation

### Requirement 11: Accessibility for Gesture Alternatives

**User Story:** As a user with motor impairments, I want semantic actions to control player forms, so that I can reposition the player without precise hold-drag gestures.

#### Acceptance Criteria

1. THE Bar_Form SHALL expose Semantics.customSemanticsActions for "Dock player", "Move to top", and "Convert to card"
2. THE Card_Form SHALL expose Semantics.customSemanticsActions for "Dock player", "Move to top", and "Convert to pill"
3. THE Pill_Form SHALL expose Semantics.customSemanticsActions for "Dock player" and "Convert to card"
4. WHEN the user invokes "Dock player" action, THE MiniPlayerController SHALL morph to Bar_Form at docked position in Auto_Mode over 260ms
5. WHEN the user invokes "Move to top" action, THE MiniPlayerController SHALL morph to Pill_Form positioned at horizontal center and vertical Safe_Area top + 80dp
6. WHEN the user invokes "Convert to card" action, THE MiniPlayerController SHALL morph to Card_Form positioned at right edge and vertical center
7. WHEN the user invokes "Convert to pill" action, THE MiniPlayerController SHALL morph to Pill_Form positioned at horizontal center and vertical Safe_Area top + 80dp

### Requirement 12: Material Transparency Fix for Yellow Underlines

**User Story:** As a quality-focused user, I want clean text rendering in the Now Playing screen, so that the interface looks professional and polished.

#### Acceptance Criteria

1. THE Now_Playing_Cockpit root widget SHALL be wrapped in Material with type MaterialType.transparency
2. THE MiniPlayerHost root widget SHALL be wrapped in Material with type MaterialType.transparency
3. WHEN any OverlayEntry is built by MiniPlayerHost, THE OverlayEntry content SHALL have a Material ancestor with defined color or transparency type
4. WHEN the app runs in release build mode, THE Now_Playing_Cockpit SHALL display zero yellow underlines on any Text widget

### Requirement 13: Now Playing Chevron Close Action

**User Story:** As a user viewing the full cockpit, I want the back chevron to close it, so that I return to my previous screen with the player in its last form.

#### Acceptance Criteria

1. WHEN the user taps the chevron button in Now_Playing_Cockpit header, THE Now_Playing_Cockpit SHALL close with a slide-down animation over 300ms
2. WHEN the Now_Playing_Cockpit closes, THE MiniPlayerHost SHALL display the player in the form that was active before cockpit opened (Bar, Card, or Pill)
3. WHEN the Now_Playing_Cockpit closes AND the previous form was Card or Pill in Manual_Mode, THE player SHALL restore its pre-cockpit position

### Requirement 14: Now Playing Heart Like Action

**User Story:** As a user discovering great tracks, I want to like songs from the Now Playing screen, so that I can build my favorites collection.

#### Acceptance Criteria

1. THE Now_Playing_Cockpit SHALL display exactly one heart icon positioned next to the track title
2. WHEN the user taps the heart icon, THE Now_Playing_Cockpit SHALL immediately update the icon to filled state (Optimistic_UI)
3. WHEN the user taps the heart icon, THE MiniPlayerController SHALL persist the like to backend API within 2 seconds
4. IF the backend API returns an error, THE heart icon SHALL revert to outline state AND display a brief error toast
5. WHEN the user taps a filled heart icon, THE Now_Playing_Cockpit SHALL unlike the track with the same Optimistic_UI pattern

### Requirement 15: Now Playing Lyrics View

**User Story:** As a user enjoying a song, I want to read lyrics while listening, so that I can sing along or understand the story.

#### Acceptance Criteria

1. THE Now_Playing_Cockpit SHALL display exactly one Lyrics tab in the content area (no duplicate header icon)
2. WHEN the user taps the Lyrics tab, THE Now_Playing_Cockpit SHALL display lyrics content replacing the waveform view
3. WHEN synced lyrics are available for the track, THE lyrics view SHALL highlight the current line based on playback position with 100ms accuracy
4. WHEN synced lyrics are available, THE lyrics view SHALL auto-scroll to keep the current line vertically centered
5. WHEN only static lyrics are available, THE lyrics view SHALL display scrollable text with no highlighting
6. WHEN no lyrics are available, THE lyrics view SHALL display "Lyrics not available for this track" message

### Requirement 16: Now Playing Overflow Menu Actions

**User Story:** As a user managing my music library, I want overflow menu options, so that I can add tracks to playlists, download, share links, change visibility, and delete.

#### Acceptance Criteria

1. WHEN the user taps the overflow (three dots) button in Now_Playing_Cockpit Action_Row, THE Now_Playing_Cockpit SHALL display a bottom sheet menu
2. THE overflow menu SHALL contain options: "Add to playlist", "Download", "Copy link", "Change visibility", and "Delete"
3. WHEN the user selects "Add to playlist", THE Now_Playing_Cockpit SHALL display playlist selection modal
4. WHEN the user selects "Download", THE MiniPlayerController SHALL initiate track download and display progress notification
5. WHEN the user selects "Copy link", THE MiniPlayerController SHALL copy the track URL to system clipboard and display confirmation toast
6. WHEN the user selects "Change visibility", THE Now_Playing_Cockpit SHALL toggle between Public and Private AND persist to backend
7. WHEN the user selects "Delete", THE Now_Playing_Cockpit SHALL display confirmation dialog, and upon confirmation delete the track and close the cockpit

### Requirement 17: Now Playing Share Integration

**User Story:** As a creator wanting exposure, I want to share my tracks on social media, so that I can grow my audience.

#### Acceptance Criteria

1. WHEN the user taps the Share button in Now_Playing_Cockpit Action_Row, THE MiniPlayerController SHALL check the track's Visibility_State
2. WHEN the track Visibility_State is Private, THE Now_Playing_Cockpit SHALL display a confirmation dialog "This track is private. Make it public to share?"
3. WHEN the user confirms making the track public, THE MiniPlayerController SHALL update Visibility_State to Public AND persist to backend before opening share sheet
4. WHEN the track Visibility_State is Public OR after successful visibility change, THE MiniPlayerController SHALL open the System_Share_Sheet with track title, artist, and link
5. THE System_Share_Sheet SHALL include platform-native sharing options (Messages, Mail, social media apps installed on device)

### Requirement 18: Now Playing Waveform Seek

**User Story:** As a user navigating a long track, I want to tap or drag the waveform, so that I can jump to any position visually.

#### Acceptance Criteria

1. THE Now_Playing_Cockpit waveform SHALL display pre-computed Waveform_Peaks as vertical bars spanning the track duration
2. THE waveform SHALL highlight the played portion using brand accent color from theme
3. WHEN the user taps the waveform at position X, THE MiniPlayerController SHALL seek playback to (X / waveform_width) * track_duration within 100ms
4. WHEN the user holds and drags horizontally on the waveform, THE waveform SHALL display a seek preview scrubber and timestamp
5. WHEN the user releases during waveform drag, THE MiniPlayerController SHALL commit the seek to the scrubber position
6. THE waveform seek interaction SHALL maintain 60fps during drag

### Requirement 19: Now Playing Shuffle Toggle

**User Story:** As a user with a large queue, I want to shuffle playback order, so that I hear varied music instead of the same sequence.

#### Acceptance Criteria

1. THE Now_Playing_Cockpit SHALL display a shuffle button in the bottom control row
2. WHEN the user taps the shuffle button, THE MiniPlayerController SHALL toggle shuffle mode on/off
3. WHEN shuffle mode activates, THE shuffle button icon SHALL highlight with brand accent color
4. WHEN shuffle mode is on, THE MiniPlayerController SHALL randomize the upcoming queue order preserving the current track
5. WHEN shuffle mode is off, THE MiniPlayerController SHALL restore original queue order
6. THE MiniPlayerController SHALL persist shuffle preference to SharedPreferences key "playback_shuffle"
7. WHEN the app launches, THE MiniPlayerController SHALL restore shuffle mode from SharedPreferences

### Requirement 20: Now Playing Repeat Mode Cycle

**User Story:** As a user who loves a song, I want repeat controls, so that I can loop the current track or the entire queue.

#### Acceptance Criteria

1. THE Now_Playing_Cockpit SHALL display a repeat button in the bottom control row
2. WHEN the user taps the repeat button, THE MiniPlayerController SHALL cycle through repeat modes: off → all → one → off
3. WHEN repeat mode is off, THE repeat button SHALL display outline icon with no highlight
4. WHEN repeat mode is all, THE repeat button SHALL display filled icon with brand accent color and no badge
5. WHEN repeat mode is one, THE repeat button SHALL display filled icon with brand accent color and a "1" badge overlay
6. WHEN repeat mode is one AND the current track ends, THE MiniPlayerController SHALL restart the same track
7. WHEN repeat mode is all AND the last track ends, THE MiniPlayerController SHALL restart from the first track
8. WHEN repeat mode is off AND the last track ends, THE MiniPlayerController SHALL stop playback
9. THE MiniPlayerController SHALL persist repeat mode to SharedPreferences key "playback_repeat"
10. WHEN the app launches, THE MiniPlayerController SHALL restore repeat mode from SharedPreferences

### Requirement 21: Now Playing Stems Mixer Access

**User Story:** As a producer, I want to access isolated stems, so that I can adjust vocals, drums, bass, and other elements independently.

#### Acceptance Criteria

1. WHEN the user taps the Stems button in Now_Playing_Cockpit Action_Row, THE MiniPlayerController SHALL check if stems are available for the current track
2. WHEN stems are available, THE Now_Playing_Cockpit SHALL open the Stem_Mixer modal displaying four faders: vocals, drums, bass, other
3. WHEN stems are not available, THE Now_Playing_Cockpit SHALL display a prompt "Stems not generated. Generate now?" with confirm/cancel buttons
4. WHEN the user confirms stem generation, THE MiniPlayerController SHALL initiate background stem separation and display progress
5. WHEN stem separation completes, THE Now_Playing_Cockpit SHALL automatically open the Stem_Mixer modal
6. THE Stem_Mixer faders SHALL control volume from 0.0 (muted) to 1.0 (original level) with 0.05 step granularity
7. WHEN the user adjusts any stem fader, THE audio playback SHALL reflect the change within 50ms

### Requirement 22: Now Playing Details Modal

**User Story:** As a curious user, I want to view track metadata, so that I can understand the generation parameters and licensing.

#### Acceptance Criteria

1. WHEN the user taps the Details button in Now_Playing_Cockpit Action_Row, THE Now_Playing_Cockpit SHALL open a details modal bottom sheet
2. THE details modal SHALL display: original generation prompt, genre, mood, tempo feel, vocal energy, DNA_Percentage, creation date, Visibility_State, and licensing terms
3. THE details modal SHALL format the creation date as relative time for dates within 7 days (e.g., "3 days ago") ELSE absolute date (e.g., "Jan 15, 2026")
4. THE details modal SHALL display DNA_Percentage as a percentage value (e.g., "47%") with a brief explanation "Your profile influenced this generation"
5. THE details modal SHALL display licensing terms as "Vhunambi Standard License" with a "View full terms" link that opens the license document

### Requirement 23: Now Playing Action Row Layout Fix

**User Story:** As a user on a narrow phone, I want to access all Now Playing actions, so that I don't miss features due to overflow clipping.

#### Acceptance Criteria

1. THE Now_Playing_Cockpit Action_Row SHALL implement horizontal scrolling when more than 4 action buttons are present
2. WHEN the Action_Row is scrollable, THE Action_Row SHALL display gradient fade indicators at left and right edges
3. WHEN the Action_Row scrolls to the start, THE left fade indicator SHALL disappear
4. WHEN the Action_Row scrolls to the end, THE right fade indicator SHALL disappear
5. THE Action_Row SHALL display action buttons in order: Share, Stems, Details, overflow (three dots)
6. THE Action_Row horizontal scroll SHALL use momentum physics matching platform standards (iOS bounce, Android overscroll glow)

### Requirement 24: Now Playing Duplicate Element Removal

**User Story:** As a design-conscious user, I want a clean interface without redundant controls, so that the screen is easier to understand.

#### Acceptance Criteria

1. THE Now_Playing_Cockpit SHALL display exactly one heart icon positioned in the header next to the track title (no duplicate in Action_Row)
2. THE Now_Playing_Cockpit SHALL display exactly one lyrics access point via the Lyrics tab (no duplicate icon in header)
3. WHEN the Now_Playing_Cockpit renders, THE header SHALL contain only: chevron, track title, heart icon, genre chip
4. WHEN the Now_Playing_Cockpit renders, THE Action_Row SHALL contain only: Share, Stems, Details, overflow menu

### Requirement 25: Now Playing Duration Label Fix

**User Story:** As a user, I want to see complete track timestamps, so that I know how long the song is.

#### Acceptance Criteria

1. THE Now_Playing_Cockpit duration label SHALL have a minimum width of 48dp to accommodate "00:00" format without truncation
2. WHEN the track duration changes, THE duration label SHALL maintain its fixed width and not cause layout shift
3. THE track title text SHALL have flex-shrink enabled so it truncates before the duration label when space is constrained
4. THE current position and duration labels SHALL display in MM:SS format (e.g., "2:47" not "2:4")

### Requirement 26: Now Playing Title Overflow Handling

**User Story:** As a user with long track titles, I want to read the complete title, so that I know exactly what's playing.

#### Acceptance Criteria

1. WHEN the track title exceeds available width, THE Now_Playing_Cockpit title SHALL truncate with ellipsis
2. WHEN the user long-presses the truncated title, THE title SHALL expand to show 2 lines for 3 seconds then collapse
3. WHERE Reduce_Motion_Setting is disabled, WHILE the track is playing, THE truncated title SHALL display a marquee scroll animation at 20 dp/s
4. WHEN Reduce_Motion_Setting is enabled, THE title SHALL remain static with ellipsis truncation
5. WHEN the user taps the title (not long-press), THE tap SHALL not trigger any action

## Parser and Serializer Requirements

This feature does not include custom parsers or serializers. State persistence uses Flutter's built-in SharedPreferences JSON serialization.

## Non-Functional Requirements

### Performance Requirements

1. THE drag gesture tracking SHALL maintain 60fps (16.67ms frame budget) on Snapdragon 662 or equivalent mid-range processor
2. THE morph animations between forms SHALL maintain 60fps and complete within 260-300ms
3. THE Cover_Art_Glow animation SHALL throttle to 30fps (33.33ms frame budget) to conserve battery
4. WHEN palette extraction occurs, THE Palette_Generator SHALL complete within 200ms for images up to 1024x1024 pixels
5. WHEN obstacle registrations change, THE Auto_Mode repositioning animation SHALL complete within 200ms
6. THE waveform seek drag SHALL maintain 60fps response during user interaction

### Gesture Recognition Requirements

1. THE hold gesture activation threshold SHALL be 350ms from initial touch down
2. THE direction classification threshold SHALL be 24dp of travel from touch origin
3. THE horizontal fling dismiss velocity threshold SHALL be 250 px/s
4. THE extreme zone entry detection SHALL have 8dp hysteresis to prevent flickering on zone boundaries
5. THE Card_Form and Pill_Form minimum edge clearance SHALL be 16dp from Safe_Area bounds

### Haptic Feedback Requirements

1. THE Manual_Mode activation haptic SHALL use HapticFeedback.mediumImpact intensity
2. THE extreme zone entry haptic SHALL use HapticFeedback.selectionClick intensity
3. ALL haptic feedback SHALL respect the System_Haptics_Setting preference
4. WHEN System_Haptics_Setting is disabled, THE MiniPlayerHost SHALL suppress all haptic invocations

### State Persistence Requirements

1. THE form state SHALL persist to SharedPreferences key "player_form" as string enum value
2. THE mode state SHALL persist to SharedPreferences key "player_mode" as string enum value
3. THE position state SHALL persist to SharedPreferences keys "player_position_x" and "player_position_y" as Screen_Fraction float values (0.0-1.0)
4. THE shuffle preference SHALL persist to SharedPreferences key "playback_shuffle" as boolean
5. THE repeat mode SHALL persist to SharedPreferences key "playback_repeat" as string enum value
6. ALL SharedPreferences writes SHALL occur asynchronously to avoid blocking the UI thread

### Accessibility Requirements

1. ALL player forms SHALL provide Semantics labels describing current state ("Music player - Bar form - Auto mode")
2. ALL interactive controls SHALL have minimum touch target size of 48x48 dp per Material Design guidelines
3. WHEN Reduce_Motion_Setting is enabled, THE glow animation SHALL display static intensity
4. WHEN Reduce_Motion_Setting is enabled, THE morph animations SHALL reduce duration to 150ms and use linear curves
5. THE waveform seek scrubber SHALL have 48x48 dp touch target even when the visual indicator is smaller
6. ALL text SHALL maintain minimum 4.5:1 contrast ratio against background per WCAG AA standards

### Battery and Resource Requirements

1. THE Cover_Art_Glow animation SHALL stop when the app enters background state
2. THE Cover_Art_Glow CustomPainter SHALL use RepaintBoundary to isolate repaints
3. THE Palette_Generator color extraction SHALL cache results per track to avoid redundant computation
4. WHEN the device battery is in power-save mode, THE glow animation frame rate SHALL reduce to 15fps

### Network and Backend Requirements

1. THE heart like/unlike action SHALL implement exponential backoff retry (1s, 2s, 4s) on network failure before displaying error
2. THE visibility change action SHALL wait for backend confirmation before closing share prompt
3. THE stem generation request SHALL poll status every 2 seconds with 30 second timeout before displaying error
4. THE track deletion action SHALL require backend confirmation before removing track from local library

## Phased Delivery Acceptance Criteria

### Phase A Completion Criteria (P0 - Must Ship First)

1. MiniPlayerHost instantiated globally via MaterialApp.builder with Material transparency wrapper
2. Auto_Mode obstacle avoidance functional for cockpit generate card and keyboard
3. Horizontal fling dismissal stops playback and clears state
4. Form, mode, and position persist to SharedPreferences and restore on launch
5. Bar_Form displays all controls and opens Now_Playing on tap
6. Material transparency fix resolves all yellow underlines in release build
7. Integration with PlayerObstacle_Widget in at least one page (Create screen cockpit)

### Phase B Completion Criteria (P1)

1. Hold gesture activation at 350ms threshold with medium haptic
2. Vertical drag in Manual_Mode follows finger at 60fps
3. Bottom_Extreme_Zone highlights, fires selection haptic, and resets to Bar + Auto on release
4. Direction classification locks after 24dp travel
5. Manual_Mode persists position across app restarts

### Phase C Completion Criteria (P1)

1. Diagonal-up drag from Bar morphs to Card_Form with edge attachment
2. Card_Form renders as 128dp square with cover art and progress
3. Card_Form free drag repositions anywhere in Safe_Area with 16dp edge clearance
4. Card_Form morph animation maintains 60fps on mid-range device
5. Card_Form opens Now_Playing on tap

### Phase D Completion Criteria (P1)

1. Top_Extreme_Zone highlights and morphs to Pill_Form on release
2. Pill_Form displays Cover_Art_Glow effect with dominant colors extracted via Palette_Generator
3. Glow intensity driven by Waveform_Peaks sampling at playback position
4. Glow animation throttles to 30fps and stops when app is backgrounded
5. Static breathe animation displays when playback is paused
6. Glow respects Reduce_Motion_Setting with static display
7. Pill_Form free drag repositions anywhere in Safe_Area
8. Pill_Form opens Now_Playing on tap

### VH-015 Completion Criteria (P0)

1. Zero yellow underlines visible in Now_Playing_Cockpit in release build
2. All OverlayEntry widgets have proper Material ancestor
3. Text rendering matches Material Design specifications

### VH-016 Completion Criteria (P0 - Critical Controls, P1 - Enhanced Features)

**P0 Critical Controls:**
1. Chevron closes Now_Playing and returns to previous player form
2. Heart like/unlike with Optimistic_UI and backend persistence functional
3. Previous/next buttons respect playback position (3s threshold) and repeat mode
4. Previous/next buttons disable appropriately at queue boundaries

**P1 Enhanced Features:**
5. Lyrics tab displays synced or static lyrics with no duplicate header icon
6. Overflow menu provides playlist add, download, copy link, visibility toggle, delete actions
7. Share button checks visibility, prompts for public if private, opens System_Share_Sheet
8. Waveform seek via tap and drag functional at 60fps
9. Shuffle toggle functional with state persistence and visual indication
10. Repeat cycle (off → all → one) functional with state persistence and badge display
11. Stems button opens Stem_Mixer or prompts generation with progress tracking
12. Details button opens modal with all metadata fields formatted correctly

### VH-017 Completion Criteria (P1)

1. Action_Row scrolls horizontally with edge fade indicators when needed
2. Only one heart icon present (header, next to title)
3. Only one lyrics access point present (Lyrics tab)
4. Duration label has fixed 48dp min-width and displays MM:SS format without truncation
5. Track title implements long-press expansion OR marquee scroll (based on Reduce_Motion_Setting)
