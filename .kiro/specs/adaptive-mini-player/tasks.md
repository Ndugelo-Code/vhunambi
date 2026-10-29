# Implementation Plan: Adaptive Mini Player & Now Playing Cockpit

## Overview

This implementation plan covers the complete Adaptive Mini Player redesign, introducing three morphing player forms (Bar, Card, Pill) with intelligent auto-positioning, manual gesture control, and visual feedback through cover-art reactive glows. The feature is structured in 4 phased deliveries (VH-014 through VH-017) to ensure incremental progress with testable milestones.

## Tasks

### Phase 1: Foundation & Core Infrastructure (VH-014)

- [x] 1. Set up MiniPlayerController state management
  - Create `lib/features/player/presentation/providers/mini_player_controller.dart`
  - Implement `PlayerForm` enum (bar, card, pill)
  - Implement `PlayerMode` enum (auto, manual)
  - Add state fields: form, mode, position, obstacles Map, isDragging, isNowPlayingOpen
  - Add `reservedBottom` getter that returns bar height + 8dp in auto mode, else 0
  - Implement ChangeNotifier pattern for state updates
  - _Requirements: 1.4, 2.6, 2.7_

- [x] 2. Implement state persistence with SharedPreferences
  - Add `loadState()` method to restore form, mode, position from SharedPreferences
  - Add `_persistState()` method to save state changes
  - Implement `_positionToScreenFraction()` helper for rotation-safe persistence
  - Implement `_restorePosition()` with safe area clamping
  - Add persistence keys: "player_form", "player_mode", "player_position_x", "player_position_y"
  - Call `loadState()` in controller constructor
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 3. Create MiniPlayerHost global overlay widget
  - Create `lib/features/player/presentation/widgets/mini_player_host.dart`
  - Implement ConsumerStatefulWidget with TickerProviderStateMixin
  - Add AnimationControllers: _morphController (280ms), _positionController (200ms), _dismissController (180ms)
  - Wrap root in Material(type: MaterialType.transparency)
  - Watch playerStateProvider for active track check
  - Implement `_shouldHide()` checking onboarding, splash, auth, Now Playing state
  - Hide when keyboard is open (viewInsets.bottom > 0)
  - Render appropriate player form based on controller.form
  - _Requirements: 1.1, 1.2, 1.3, 1.7, 12.3_

- [x] 4. Install MiniPlayerHost in MaterialApp.builder
  - Modify `lib/main.dart` VhunambiApp widget
  - Add builder parameter returning Stack with child and MiniPlayerHost overlay
  - Ensure MiniPlayerHost is above all routes
  - Test that player persists across route navigation
  - _Requirements: 1.1, 1.2_

- [x] 5. Enhance existing MobileMiniPlayer to BarForm
  - Create `lib/features/player/presentation/widgets/bar_form.dart`
  - Port existing MobileMiniPlayer widget
  - Add genre chip display below track title
  - Add progress line overlay at top (2dp height)
  - Implement `isScaled` prop for hold gesture feedback (scale 1.03)
  - Add Hero widget for cover art with tag 'player_cover_${track.id}'
  - Add onExpand callback for Now Playing navigation
  - Display 44x44dp cover art, title, genre, time, previous/play-pause/next buttons
  - _Requirements: 3.1, 3.2, 3.3_

- [x] 6. Implement BarForm playback controls
  - Wire previous button to skipPrevious() with 3-second position check
  - Wire play/pause button to togglePlayPause() with HapticFeedback.mediumImpact
  - Wire next button to skipNext()
  - Implement visual disable states when at queue boundaries and repeat mode is off
  - Add HapticFeedback.lightImpact on skip button taps
  - Ensure control responses within 100ms
  - _Requirements: 3.4, 3.5, 3.6, 3.7, 3.8_

- [x] 7. Create PlayerObstacle widget for obstacle registration
  - Create `lib/features/player/presentation/widgets/player_obstacle.dart`
  - Implement StatefulWidget with GlobalKey for layout measurement
  - Add `id` and `child` parameters
  - Use addPostFrameCallback to register Rect with MiniPlayerController
  - Implement disposal cleanup calling unregisterObstacle
  - Handle re-registration on didUpdateWidget
  - _Requirements: 2.2, 2.3_

- [x] 8. Implement obstacle registry in MiniPlayerController
  - Add `registerObstacle(String id, Rect rect)` method
  - Add `unregisterObstacle(String id)` method
  - Add `_recalculateAutoPosition()` method finding highest obstacle in dock area
  - Trigger position recalculation when obstacles change in auto mode
  - Implement `_getDockRect()` helper (bottom 120dp zone)
  - Ensure 8dp padding above obstacles
  - _Requirements: 2.1, 2.4_

- [x] 9. Implement auto-mode positioning logic
  - Add position calculation in `_recalculateAutoPosition()`
  - Find highest obstacle Y coordinate that overlaps dock rect
  - Position bar at (0, highestY - 8dp)
  - Animate position changes using _positionController
  - Update reservedBottom value when bar position changes
  - Only run when mode is auto AND form is bar
  - _Requirements: 2.1, 2.4, 2.5_

- [x] 10. Integrate PlayerObstacle in ContentStudioDock
  - Wrap ContentStudioDock widget with PlayerObstacle
  - Pass id 'content_studio_dock'
  - Test that bar moves up when cockpit appears
  - Test that bar returns to bottom when cockpit is dismissed
  - _Requirements: 2.1, 2.2, 2.3_

- [x] 11. Fix Now Playing Material transparency wrapper
  - Open `lib/features/player/presentation/widgets/expanded_cockpit_modal.dart`
  - Wrap root widget in Material(type: MaterialType.transparency)
  - Test that no yellow underlines appear on text widgets
  - Test in release build mode for final verification
  - _Requirements: 12.1, 12.2, 12.4_

- [x] 12. Implement horizontal fling dismiss gesture
  - Add HorizontalDragGestureRecognizer to MiniPlayerHost
  - Track horizontal velocity on drag end
  - If abs(velocity) > 250 px/s, trigger dismiss animation
  - Animate player off-screen in fling direction over 180ms
  - Call playerStateProvider.notifier.stop() to stop playback
  - Call playerStateProvider.notifier.clearTrack() to clear state
  - Unmount player widget after animation completes
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [x] 13. Phase 1 checkpoint - Basic infrastructure validation
  - Verify player persists across all route navigation
  - Verify bar avoids content studio dock automatically
  - Verify player dismisses with horizontal fling
  - Verify state persists across app restarts
  - Verify no yellow underlines in Now Playing
  - Ensure all tests pass, ask the user if questions arise.

### Phase 2: Gestures & Manual Mode (VH-015)

- [x] 14. Implement hold gesture recognition
  - Add LongPressGestureRecognizer to MiniPlayerHost with 350ms duration
  - Add `_handleLongPressStart()` method firing HapticFeedback.mediumImpact
  - Call controller.startDrag(globalPosition) on long press
  - Set isDragging to true in controller
  - Store _dragStartPosition
  - Scale BarForm to 1.03 when isDragging is true
  - _Requirements: 4.1, 4.2, 4.3_

- [x] 15. Implement drag direction classification
  - Add `_classifyDirection(Offset delta)` method to MiniPlayerController
  - Calculate angle from vertical axis using atan2
  - Return DragDirection.vertical if angle < 20°
  - Return DragDirection.diagonalUpLeft or diagonalUpRight if 20° ≤ angle ≤ 70° and dy < 0
  - Return DragDirection.ignored if angle > 70° or diagonal downward
  - Only classify after 24dp travel distance from start
  - _Requirements: 4.4, 4.6, 4.7_

- [x] 16. Implement vertical drag tracking in manual mode
  - Add `updateDrag(Offset globalPosition)` method to MiniPlayerController
  - Wait for 24dp travel before classifying direction
  - On vertical drag, update position.dy following finger
  - Clamp position to safe area bounds
  - Notify listeners for UI updates
  - Maintain 60fps during drag (use throttling if needed)
  - _Requirements: 4.5, 4.8, 4.9_

- [x] 17. Create ExtremeZoneDetector utility class
  - Create `lib/features/player/presentation/utils/extreme_zone_detector.dart`
  - Add static constants: topZoneHeight (72dp), bottomZoneHeight (120dp)
  - Implement `detectZone(Offset position, Size screenSize, EdgeInsets safeArea)` returning ExtremeZone? enum
  - Implement `buildZoneHighlight()` returning visual indicator widget
  - Add 8dp hysteresis to prevent flicker at boundaries
  - _Requirements: 5.1, 9.1_

- [x] 18. Implement bottom extreme zone detection and reset
  - Add `_isInBottomExtremeZone()` method checking position.dy > screenHeight - 120
  - Display zone highlight when player enters bottom zone
  - Fire HapticFeedback.selectionClick on zone entry
  - On drag release in bottom zone, call `_morphToBarAndDock()`
  - Set form to bar, mode to auto, and recalculate position
  - Animate morph over 260ms
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

- [x] 19. Implement drag end handling
  - Add `endDrag(Velocity velocity)` method to MiniPlayerController
  - Check for horizontal fling dismiss first (velocity > 250 px/s)
  - Check if position is in bottom extreme zone
  - Check if position is in top extreme zone
  - If outside zones, keep player in manual mode at current position
  - Persist state after drag completes
  - Reset isDragging, dragStartPosition, dragDirection
  - _Requirements: 4.8, 5.3, 5.4_

- [x] 20. Add manual mode state persistence
  - Ensure `_persistState()` is called on drag end
  - Save mode as "manual" or "auto" string
  - Save position as screen fraction
  - Test that manual position survives app restart
  - Test that position survives device rotation
  - _Requirements: 7.1, 7.2, 7.3, 7.5_

- [x] 21. Phase 2 checkpoint - Manual mode validation
  - Verify 350ms hold activates manual mode with haptic
  - Verify vertical drag repositions player smoothly at 60fps
  - Verify bottom zone resets to bar + auto mode
  - Verify manual position persists across sessions
  - Verify device rotation preserves relative position
  - Ensure all tests pass, ask the user if questions arise.

### Phase 3: Card & Pill Forms (VH-016)

- [x] 22. Create CardForm widget
  - Create `lib/features/player/presentation/widgets/card_form.dart`
  - Implement ConsumerWidget rendering 128x128dp square
  - Display cover art gradient background with genre colors
  - Add centered piano icon (48dp) with 90% white opacity
  - Add progress overlay at bottom showing percentage and play/pause icon
  - Add border (2dp, brand primary with 30% opacity)
  - Add shadow (blur 24dp, brand primary with 40% opacity)
  - Add rounded corners (16dp)
  - Add onExpand callback for Now Playing navigation
  - _Requirements: 8.3, 8.5_

- [x] 23. Implement diagonal drag detection from Bar to Card
  - Enhance direction classification to detect diagonal-up
  - On diagonal-up release, morph to CardForm
  - Determine edge attachment based on dx sign (negative = left, positive = right)
  - Snap card to appropriate edge with 16dp margin
  - Animate morph over 280ms using Curves.easeOutCubic
  - Maintain 60fps during morph animation
  - _Requirements: 8.1, 8.2, 8.8_

- [x] 24. Implement card form free positioning
  - Allow hold-drag on CardForm to reposition
  - Enforce minimum 16dp clearance from all safe area edges
  - Allow placement anywhere within safe bounds
  - Persist position when released outside extreme zones
  - Maintain manual mode when card is freely positioned
  - _Requirements: 8.4, 8.6, 8.7_

- [x] 25. Create morph animation system
  - Create `lib/features/player/presentation/utils/morph_animator.dart`
  - Implement RectTween, BorderRadiusTween, ElevationTween generators
  - Define rect dimensions for each form (Bar: full width x 64, Card: 128x128, Pill: 160x48)
  - Define border radius for each form (Bar: 16, Card: 16, Pill: 24)
  - Define shadow elevation for each form (Bar: 8, Card: 12, Pill: 16)
  - Ensure smooth interpolation during morph
  - _Requirements: 8.8_

- [x] 26. Create PillForm widget structure
  - Create `lib/features/player/presentation/widgets/pill_form.dart`
  - Implement ConsumerStatefulWidget with SingleTickerProviderStateMixin
  - Define 160x48dp pill dimensions
  - Add 24dp border radius
  - Display minimal UI: circular cover art (32dp) and play/pause icon (18dp)
  - Add border (2dp, brand primary with 60% opacity)
  - Add onExpand callback for Now Playing navigation
  - _Requirements: 9.4, 9.5_

- [x] 27. Implement top extreme zone detection
  - Add `_isInTopExtremeZone()` method checking position.dy < 72
  - Display zone highlight when player enters top zone
  - Fire HapticFeedback.selectionClick on zone entry
  - On drag release in top zone, call `_morphToPill()`
  - Position pill at horizontal center, vertical top + 80dp
  - Set mode to manual
  - _Requirements: 9.1, 9.2, 9.3_

- [x] 28. Implement pill form free positioning
  - Allow hold-drag on PillForm to reposition
  - Enforce minimum 16dp clearance from all safe area edges
  - Allow placement anywhere within safe bounds
  - Persist position when released outside extreme zones
  - Maintain manual mode when pill is freely positioned
  - _Requirements: 9.6, 9.7_

- [x] 29. Integrate palette_generator for color extraction
  - Add `palette_generator: ^0.3.3+2` to pubspec.yaml
  - Import package in MiniPlayerController
  - Implement `extractColorsFromCoverArt(String imageUrl)` method
  - Extract vibrant, lightVibrant, darkVibrant colors
  - Cache colors in `_glowColors` list
  - Set 200ms timeout on extraction
  - Fallback to genre gradient colors on failure
  - _Requirements: 10.1, 10.2_

- [x] 30. Create GlowPainter for pill glow effect
  - Add GlowPainter class extending CustomPainter in pill_form.dart
  - Accept colors list and intensity parameters
  - Paint radial gradient using provided colors
  - Apply MaskFilter.blur with 20dp radius
  - Interpolate color opacity based on intensity
  - Implement shouldRepaint checking intensity changes
  - _Requirements: 10.5_

- [x] 31. Implement glow intensity from waveform amplitude
  - Wire MasterMediaObject 60 Hz masterRms curves directly into _sampleAmplitude()
  - Sample mmo.modulationBus.sampleStemCurve(mmo.modulationBus.masterRmsBytes, posMs)
  - Fallback to smooth amplitude oscillation when no MMO attached
  - Map amplitude (0.0-1.0) to glow intensity (0.2-1.0)
  - Update pill CustomPaint with new intensity
  - Wrap CustomPaint in RepaintBoundary for optimization
  - _Requirements: 10.3, 10.4, 10.6_

- [x] 32. Implement glow breathe animation for paused state
  - Check playerState.isPlaying in _sampleAmplitude
  - If paused, calculate sine wave breathe: (sin(time / 1000) + 1) / 2
  - Scale breathe to 0.5 max intensity
  - Cycle over 2 seconds
  - _Requirements: 10.7_

- [x] 33. Implement glow lifecycle management
  - Stop animation timer when app enters background
  - Start animation timer when app returns to foreground
  - Dispose _glowController and _amplitudeTimer properly
  - Check MediaQuery.of(context).disableAnimations for reduce motion
  - Display static 0.5 intensity when reduce motion is enabled
  - _Requirements: 10.8, 10.9_

- [x] 34. Phase 3 checkpoint - Advanced forms validation
  - Verify diagonal drag morphs to card with edge attachment
  - Verify card can be freely positioned with 16dp edge clearance
  - Verify top zone morphs to pill
  - Verify pill displays glow with extracted colors
  - Verify glow intensity pulses with music at 30fps
  - Verify breathe animation shows when paused
  - Verify reduce motion setting displays static glow
  - Ensure all tests pass, ask the user if questions arise.

### Phase 4: Now Playing Controls (VH-017)

- [ ] 35. Implement Now Playing chevron close action
  - Locate back chevron button in expanded_cockpit_modal.dart
  - Wire onPressed to Navigator.pop with 300ms slide-down animation
  - Set controller.isNowPlayingOpen to false on close
  - Restore previous player form (bar, card, or pill)
  - If previous form was card or pill in manual mode, restore position
  - _Requirements: 13.1, 13.2, 13.3_

- [ ] 36. Implement Now Playing heart like/unlike action
  - Ensure only ONE heart icon in header (remove duplicate from action row)
  - Wire heart tap to toggle like state with optimistic UI
  - Update icon immediately to filled/outline
  - Call backend API to persist like
  - Implement 2-second timeout on API call
  - Revert icon and show toast on error
  - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 24.1, 24.3_

- [ ] 37. Create Now Playing lyrics view
  - Ensure only ONE lyrics access point via tab (remove duplicate header icon)
  - Implement tab switching to lyrics content
  - Display scrollable lyrics text replacing waveform
  - For synced lyrics, highlight current line based on playback position (100ms accuracy)
  - Auto-scroll to keep current line vertically centered
  - For static lyrics, display plain scrollable text
  - Show "Lyrics not available" message when no lyrics exist
  - _Requirements: 15.1, 15.2, 15.3, 15.4, 15.5, 15.6, 24.2, 24.4_

- [ ] 38. Create Now Playing overflow menu
  - Wire overflow button to open bottom sheet menu
  - Add menu options: "Add to playlist", "Download", "Copy link", "Change visibility", "Delete"
  - Implement playlist selection modal for add action
  - Implement download initiation with progress notification
  - Implement clipboard copy with confirmation toast
  - Implement visibility toggle (Public/Private) with backend persistence
  - Implement delete with confirmation dialog and cockpit close
  - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5, 16.6, 16.7_

- [ ] 39. Implement Now Playing share action with visibility check
  - Wire share button tap to check track visibility state
  - If private, show dialog "This track is private. Make it public to share?"
  - On confirm, update visibility to public and persist to backend
  - After visibility confirmed public, open system share sheet
  - Format share text: "Check out \"{title}\" by {artist} on Vhunambi!\n{url}"
  - Include platform-native share options (Messages, Mail, social apps)
  - _Requirements: 17.1, 17.2, 17.3, 17.4, 17.5_

- [ ] 40. Enhance waveform seek with preview scrubber
  - Ensure waveform displays pre-computed peaks as vertical bars
  - Highlight played portion with brand accent color
  - Implement tap seek: (tapX / width) * duration
  - Implement hold-drag with preview scrubber overlay
  - Display timestamp at scrubber position
  - Commit seek on drag release
  - Ensure 100ms seek response time
  - Maintain 60fps during drag
  - _Requirements: 18.1, 18.2, 18.3, 18.4, 18.5, 18.6_

- [ ] 41. Implement shuffle toggle with persistence
  - Display shuffle button in bottom control row
  - Wire tap to toggle shuffle mode
  - Highlight button with brand accent when shuffle is on
  - Randomize queue on shuffle enable, preserving current track
  - Restore original queue order on shuffle disable
  - Persist to SharedPreferences key "playback_shuffle"
  - Restore shuffle mode on app launch
  - _Requirements: 19.1, 19.2, 19.3, 19.4, 19.5, 19.6, 19.7_

- [ ] 42. Implement repeat mode cycle
  - Display repeat button in bottom control row
  - Wire tap to cycle: off → all → one → off
  - Display outline icon with no highlight when off
  - Display filled icon with brand accent when all (no badge)
  - Display filled icon with brand accent and "1" badge when one
  - Implement track restart on track end when mode is one
  - Implement queue restart on last track end when mode is all
  - Stop playback on last track end when mode is off
  - Persist to SharedPreferences key "playback_repeat"
  - Restore repeat mode on app launch
  - _Requirements: 20.1, 20.2, 20.3, 20.4, 20.5, 20.6, 20.7, 20.8, 20.9, 20.10_

- [ ] 43. Implement stems mixer access
  - Wire stems button tap to check stem availability
  - If available, open stem mixer modal with 4 faders (vocals, drums, bass, other)
  - If unavailable, show prompt "Stems not generated. Generate now?"
  - On confirm, initiate background stem separation with progress display
  - Poll separation status every 2 seconds with 30 second timeout
  - Auto-open mixer on completion
  - Implement fader volume control (0.0 to 1.0, 0.05 steps)
  - Apply fader changes to audio within 50ms
  - _Requirements: 21.1, 21.2, 21.3, 21.4, 21.5, 21.6, 21.7_

- [ ] 44. Create Now Playing details modal
  - Wire details button tap to open bottom sheet
  - Display: generation prompt, genre, mood, tempo feel, vocal energy, DNA percentage, creation date, visibility, licensing
  - Format creation date: relative for < 7 days ("3 days ago"), else absolute ("Jan 15, 2026")
  - Display DNA percentage with explanation "Your profile influenced this generation"
  - Display licensing as "Vhunambi Standard License" with "View full terms" link
  - _Requirements: 22.1, 22.2, 22.3, 22.4, 22.5_

- [ ] 45. Fix action row horizontal scroll with fade indicators
  - Wrap action row in SingleChildScrollView with horizontal axis
  - Use BouncingScrollPhysics for iOS-style scroll
  - Add Stack with gradient fade overlays at left and right edges
  - Hide left fade when scrolled to start
  - Hide right fade when scrolled to end
  - Display buttons in order: Share, Stems, Details, overflow
  - _Requirements: 23.1, 23.2, 23.3, 23.4, 23.5, 23.6_

- [ ] 46. Fix duration label width and formatting
  - Set minimum width of 48dp on duration label
  - Display in MM:SS format (pad seconds with leading zero)
  - Prevent layout shift when duration changes
  - Enable flex-shrink on track title to truncate before duration
  - _Requirements: 25.1, 25.2, 25.3, 25.4_

- [ ] 47. Implement title long-press expansion
  - Create _ExpandableTitle stateful widget
  - Detect long press on truncated title
  - Expand to show 2 lines for 3 seconds
  - Collapse back to 1 line after timeout
  - Cancel timeout timer on tap or disposal
  - Only expand when title is actually truncated
  - _Requirements: 26.1, 26.2_

- [ ] 48. Implement title marquee scroll for playing state
  - Check MediaQuery.of(context).disableAnimations for reduce motion
  - If reduce motion disabled AND playing AND truncated, show marquee at 20dp/s
  - If reduce motion enabled, show static ellipsis truncation
  - Do not trigger action on title tap
  - _Requirements: 26.3, 26.4, 26.5_

- [ ] 49. Phase 4 checkpoint - Full feature validation
  - Verify all 12 Now Playing controls are functional
  - Verify only one heart icon and one lyrics access point
  - Verify action row scrolls with fade indicators
  - Verify duration label doesn't truncate
  - Verify title expands on long press or scrolls when playing
  - Verify share checks visibility before opening sheet
  - Verify shuffle and repeat persist across sessions
  - Ensure all tests pass, ask the user if questions arise.

### Testing & Quality Assurance

- [ ] 50. Write unit tests for direction classification
  - Test vertical drag (< 20°) classified correctly
  - Test diagonal-up-left (20-70°, dx < 0) classified correctly
  - Test diagonal-up-right (20-70°, dx > 0) classified correctly
  - Test horizontal drag (> 70°) is ignored
  - Test diagonal-down is ignored
  - _Requirements: 4.6, 4.7_

- [ ] 51. Write unit tests for extreme zone detection
  - Test position in top zone returns ExtremeZone.top
  - Test position in bottom zone returns ExtremeZone.bottom
  - Test position outside zones returns null
  - Test 8dp hysteresis prevents flicker
  - _Requirements: 5.1, 9.1_

- [ ] 52. Write unit tests for obstacle registry
  - Test registerObstacle adds to obstacles map
  - Test unregisterObstacle removes from obstacles map
  - Test calculateTargetY finds highest obstacle
  - Test bar positions 8dp above highest obstacle
  - _Requirements: 2.1, 2.2, 2.3_

- [ ] 53. Write unit tests for state persistence
  - Test position persists as screen fraction (0.0-1.0)
  - Test form persists as enum index
  - Test mode persists as enum index
  - Test restore clamps to safe area bounds
  - Test restore survives device rotation
  - _Requirements: 7.1, 7.2, 7.3, 7.5_

- [ ] 54. Write widget tests for BarForm rendering
  - Test displays track title, genre chip, time labels
  - Test displays previous, play/pause, next buttons
  - Test buttons disabled at queue boundaries when repeat off
  - Test tap on body triggers onExpand callback
  - Test progress line displays at correct position
  - _Requirements: 3.1, 3.2, 3.5, 3.6, 3.7_

- [ ] 55. Write widget tests for CardForm rendering
  - Test renders as 128x128dp square
  - Test displays cover art gradient
  - Test displays progress percentage overlay
  - Test tap triggers onExpand callback
  - _Requirements: 8.3, 8.5_

- [ ] 56. Write widget tests for PillForm rendering
  - Test renders as 160x48dp pill
  - Test displays circular cover art (32dp) and play/pause icon
  - Test CustomPaint with GlowPainter is present
  - Test tap triggers onExpand callback
  - _Requirements: 9.4, 9.5_

- [ ] 57. Write widget tests for MiniPlayerHost visibility
  - Test hides when onboarding route active
  - Test hides when splash route active
  - Test hides when auth route active
  - Test hides when Now Playing is open
  - Test hides when keyboard is open (viewInsets.bottom > 0)
  - Test shows when active track exists and no hide conditions
  - _Requirements: 1.7, 2.5_

- [ ] 58. Write integration test for complete morph flow
  - Test Bar → diagonal drag → Card
  - Test Card → drag to top → Pill
  - Test Pill → drag to bottom → Bar
  - Test animations complete smoothly at 60fps
  - Test state persists across each morph
  - _Requirements: 8.1, 8.2, 9.3, 5.4_

- [ ] 59. Write integration test for auto mode obstacle avoidance
  - Register obstacle in dock area
  - Verify bar moves up 8dp above obstacle
  - Unregister obstacle
  - Verify bar returns to bottom dock position
  - Test animation completes in 200ms
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [ ] 60. Write integration test for fling dismiss
  - Perform horizontal fling gesture with velocity > 250 px/s
  - Verify dismiss animation plays
  - Verify playback stops
  - Verify track state clears
  - Verify player widget unmounts
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [ ] 61. Write integration test for Now Playing coordination
  - Open Now Playing from bar
  - Verify player host hides
  - Close Now Playing
  - Verify player host shows in original form
  - Test with each form (bar, card, pill)
  - _Requirements: 13.1, 13.2, 13.3_

- [ ] 62. Write accessibility tests for semantic labels
  - Test BarForm has semantic label describing state
  - Test CardForm has semantic label describing state
  - Test PillForm has semantic label describing state
  - Test custom semantic actions present for form morphing
  - _Requirements: 11.1, 11.2, 11.3_

- [ ] 63. Write accessibility tests for touch targets
  - Test all control buttons are minimum 48x48dp
  - Test previous, play/pause, next buttons meet size requirement
  - Test waveform seek scrubber has 48x48dp touch target
  - _Requirements: 3.x controls_

- [ ] 64. Write performance test for glow animation
  - Measure frame times over 3 seconds of playback
  - Verify average fps ≥ 28 (30fps target with 2fps variance)
  - Verify frame budget stays within 33ms
  - Measure memory overhead < 15MB
  - _Requirements: 10.6_

- [ ] 65. Write performance test for drag gesture smoothness
  - Simulate vertical drag over 500ms
  - Measure frame times during drag
  - Verify fps ≥ 58 (60fps target with 2fps variance)
  - Verify no dropped frames
  - _Requirements: 4.9_

- [ ] 66. Write performance test for morph animation
  - Trigger morph between all form combinations
  - Measure frame times during 280ms animation
  - Verify fps ≥ 58
  - Verify animation completes in target duration
  - _Requirements: 8.8_

### Documentation & Accessibility

- [ ] 67. Implement custom semantic actions for gesture alternatives
  - Add "Dock player" action to all forms
  - Add "Move to top" action to bar and card forms
  - Add "Convert to card" action to bar and pill forms
  - Add "Convert to pill" action to card form
  - Wire actions to morph methods
  - Test with TalkBack/VoiceOver
  - _Requirements: 11.4, 11.5, 11.6, 11.7_

- [ ] 68. Implement haptic feedback schedule
  - Add HapticSchedule utility class
  - Define onLongPressStart (medium impact)
  - Define onEnterExtremeZone (selection click)
  - Define onMorphComplete (light impact)
  - Define onDismiss (heavy impact)
  - Define onControlTap (selection click)
  - Respect system haptics setting
  - _Requirements: 4.2, 5.2_

- [ ] 69. Add reduce motion accessibility support
  - Check MediaQuery.of(context).disableAnimations
  - Reduce glow animation to static 0.5 intensity
  - Reduce morph duration to 150ms with linear curve
  - Disable marquee title scroll
  - Maintain all functionality with reduced motion
  - _Requirements: 10.9, 26.3, 26.4_

- [ ] 70. Document player architecture in code comments
  - Add comprehensive class-level documentation for MiniPlayerHost
  - Add comprehensive class-level documentation for MiniPlayerController
  - Document all public methods with parameter descriptions
  - Document state management patterns
  - Add examples for obstacle registration

- [ ] 71. Create developer guide for obstacle registration
  - Write guide on when to use PlayerObstacle widget
  - Document best practices for obstacle ID naming
  - Provide examples of wrapping bottom-anchored UI
  - Document reserved bottom padding usage
  - Add troubleshooting section

- [ ] 72. Final validation and documentation
  - Verify all 26 requirements have passing tests
  - Verify all acceptance criteria are met
  - Verify performance targets achieved (60fps drag, 30fps glow)
  - Verify accessibility compliance (WCAG AA)
  - Update feature documentation with usage examples
  - Ensure all tests pass, ask the user if questions arise.

## Notes

### Implementation Language
This feature is implemented in **Dart** using the Flutter framework with Riverpod state management.

### Task Organization
- Tasks are numbered 1-72 for clear dependency tracking
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at phase boundaries
- Testing tasks are distributed throughout to enable continuous quality validation

### Key Dependencies
- Tasks 1-13 (Phase 1) must complete before Phase 2
- Tasks 14-21 (Phase 2) must complete before Phase 3
- Tasks 22-34 (Phase 3) must complete before Phase 4
- Testing tasks can run in parallel with implementation once code exists

### Performance Considerations
- All drag interactions target 60fps (16.67ms frame budget)
- Glow animation throttled to 30fps (33.33ms frame budget) for battery conservation
- RepaintBoundary used to isolate glow repaints from rest of widget tree
- Animation controllers properly disposed to prevent memory leaks

### Accessibility Requirements
- All controls meet 48x48dp minimum touch target size
- Semantic labels and custom actions provide non-gesture alternatives
- Reduce motion setting respected throughout
- Haptic feedback respects system settings

### State Persistence Strategy
- Positions stored as screen fractions (0.0-1.0) for rotation safety
- Safe area clamping applied on restore to handle different screen sizes
- All user preferences (form, mode, position, shuffle, repeat) persist across sessions

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1", "7"] },
    { "id": 1, "tasks": ["2", "3", "5", "8", "11"] },
    { "id": 2, "tasks": ["4", "6", "9", "12"] },
    { "id": 3, "tasks": ["10", "13"] },
    { "id": 4, "tasks": ["14", "17", "22", "26"] },
    { "id": 5, "tasks": ["15", "16", "18", "23", "27", "29"] },
    { "id": 6, "tasks": ["19", "20", "24", "25", "28", "30"] },
    { "id": 7, "tasks": ["21", "31", "32", "33"] },
    { "id": 8, "tasks": ["34"] },
    { "id": 9, "tasks": ["35", "36", "37", "38", "39", "40", "41", "42", "43", "44", "45", "46", "47", "48"] },
    { "id": 10, "tasks": ["49"] },
    { "id": 11, "tasks": ["50", "51", "52", "53", "54", "55", "56", "57", "67", "68", "69"] },
    { "id": 12, "tasks": ["58", "59", "60", "61", "62", "63"] },
    { "id": 13, "tasks": ["64", "65", "66"] },
    { "id": 14, "tasks": ["70", "71", "72"] }
  ]
}
```
