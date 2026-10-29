# Requirements Document

## Introduction

The Cross-Cutting Design System provides foundational infrastructure that ensures consistency, accessibility, and maintainability across the Vhunambi application. This system addresses the need for a single source of truth for visual design tokens (genre and mood colors), haptic feedback patterns, generation request state management, accessibility standards, and analytics instrumentation. It is infrastructure supporting the Studio Cockpit Fixes (VH-001 to VH-006), Onboarding Modernization (VH-007 to VH-013), and Adaptive Mini Player (VH-014 to VH-017) features.

## Glossary

- **Design_Token**: A named, reusable design decision (color, spacing, typography) stored centrally and referenced throughout the application
- **Genre**: Musical style category (Amapiano, Afro House, Gqom, Kwaito, Afro Pop, Maskandi, Hip-Hop, Gospel)
- **Mood**: Emotional quality category (Joyful, Melancholic, Energetic, Calm, Romantic)
- **Haptic_Feedback**: Physical vibration feedback triggered by UI interactions
- **Generation_Request_Model**: The single source of truth state object holding all parameters for song generation
- **Reduce_Motion**: System accessibility preference that requests minimal animation
- **WCAG**: Web Content Accessibility Guidelines, industry standard for digital accessibility
- **Touch_Target**: The interactive area of a UI control
- **Semantic_Label**: Screen reader description of a UI element
- **Analytics_Event**: Tracked user interaction sent to analytics service
- **Theme_System**: The application's visual theming infrastructure (Flutter ThemeData)
- **Riverpod**: Flutter state management library used in the application
- **Accent_Color**: Primary color used for emphasis and selected states
- **Surface_Tint**: Color applied to background surfaces to indicate state
- **Glow_Color**: Color used for visual effects like shadows and highlights
- **Contrast_Ratio**: Measurement of visual difference between foreground and background, expressed as ratio (4.5:1, 7:1)

## Requirements

### Requirement 1: Genre Color Token System

**User Story:** As a designer, I want a single definition for each genre's visual identity, so that updates propagate consistently across the cockpit, onboarding, Explore, Library, and progress tracker without drift.

#### Acceptance Criteria

1. THE Design_Token_Registry SHALL define exactly one color set per Genre
2. WHEN a Genre is assigned, THE Theme_System SHALL return the accent color, surface tint, and glow color for that Genre
3. THE Design_Token_Registry SHALL support at least eight Genres: Amapiano, Afro House, Gqom, Kwaito, Afro Pop, Maskandi, Hip-Hop, Gospel
4. FOR ALL Genre color tokens, THE contrast ratio between text and tinted surface SHALL be at least 4.5:1
5. WHEN a Genre color token is updated, THE change SHALL be visible in all contexts (cockpit, onboarding, Explore, Library, progress tracker) without additional code changes
6. THE Design_Token_Registry SHALL prevent duplicate or conflicting definitions for the same Genre

### Requirement 2: Mood Color Token System

**User Story:** As a designer, I want a single definition for each mood's visual identity, so that mood colors remain consistent and visually distinct from genre colors.

#### Acceptance Criteria

1. THE Design_Token_Registry SHALL define exactly one color set per Mood
2. WHEN a Mood is assigned, THE Theme_System SHALL return the accent color, surface tint, and glow color for that Mood
3. THE Design_Token_Registry SHALL support at least five Moods: Joyful, Melancholic, Energetic, Calm, Romantic
4. FOR ALL Mood color tokens, THE contrast ratio between text and tinted surface SHALL be at least 4.5:1
5. THE Mood color palette SHALL be visually distinct from the Genre color palette
6. WHEN a Mood color token is updated, THE change SHALL be visible in all contexts without additional code changes

### Requirement 3: Color Token Structure

**User Story:** As a developer, I want each color token to include accent, surface tint, and glow colors, so that I can apply consistent visual treatments for selection states and emphasis.

#### Acceptance Criteria

1. THE Color_Token SHALL include an accent color field
2. THE Color_Token SHALL include a surface tint color field
3. THE Color_Token SHALL include a glow color field
4. THE Color_Token SHALL include a contrast-safe text color field for use on tinted surfaces
5. THE Design_Token_Registry SHALL validate that all Color_Token fields are defined before registration
6. THE Theme_System SHALL expose Color_Tokens through type-safe accessors (not raw string lookups)

### Requirement 4: Color Token Accessibility Validation

**User Story:** As a QA engineer, I want automatic validation of color contrast ratios, so that accessibility compliance is enforced at design time rather than discovered in testing.

#### Acceptance Criteria

1. WHEN a Color_Token is registered, THE Design_Token_Registry SHALL validate the contrast ratio between the text color and tinted surface
2. IF the contrast ratio is below 4.5:1, THEN THE Design_Token_Registry SHALL reject the registration with a descriptive error
3. THE Design_Token_Registry SHALL provide a validation report listing all tokens and their contrast ratios
4. THE validation report SHALL be generated during the build process for design review
5. THE Design_Token_Registry SHALL support overriding contrast validation for exceptional cases with explicit documentation of the exception reason

### Requirement 5: Haptics Service Architecture

**User Story:** As a developer, I need a centralized haptics service, so that I don't duplicate system setting checks and intensity configuration across five different features.

#### Acceptance Criteria

1. THE Haptics_Service SHALL provide methods for light impact, medium impact, selection click, and heavy impact haptic patterns
2. WHEN the system haptics setting is disabled, THE Haptics_Service SHALL no-op without error
3. THE Haptics_Service SHALL respect platform-specific haptics capabilities (iOS and Android)
4. THE Haptics_Service SHALL expose a single configuration point for haptic intensity tuning
5. WHEN Haptics_Service methods are called from multiple features concurrently, THE service SHALL queue and execute haptics without overlap or dropped events
6. THE Haptics_Service SHALL be accessible as a Riverpod provider for dependency injection

### Requirement 6: Haptics Service System Setting Integration

**User Story:** As a user, I want the app to respect my system haptics preferences, so that I'm not surprised by unexpected vibrations when I've disabled haptics system-wide.

#### Acceptance Criteria

1. WHEN the application starts, THE Haptics_Service SHALL read the system haptics setting
2. WHEN the system haptics setting changes while the app is running, THE Haptics_Service SHALL detect the change within 500ms
3. WHILE the system haptics setting is disabled, THE Haptics_Service SHALL not trigger any haptic feedback
4. THE Haptics_Service SHALL provide a stream of system haptics setting changes for reactive UI updates
5. IF the system haptics API is unavailable on a platform, THEN THE Haptics_Service SHALL default to no-op behavior without crashing

### Requirement 7: Generation Request Model as Single Source of Truth

**User Story:** As a developer, I need a unified state model for generation parameters, so that visibility, progress tracker slots, and tempo/vocal mappings stay synchronized without duplicated UI state.

#### Acceptance Criteria

1. THE Generation_Request_Model SHALL be the only mutable source of generation parameters
2. THE Generation_Request_Model SHALL include fields for: prompt text, genre, mood, tempo feel, vocal energy, language, lyrics text, DNA percentage, and visibility
3. WHEN any field in Generation_Request_Model changes, THE change SHALL propagate to all consumers within one frame (16ms at 60fps)
4. THE Generation_Request_Model SHALL not duplicate state in UI widgets
5. THE Generation_Request_Model SHALL be accessible as a Riverpod StateNotifier for reactive updates
6. THE Generation_Request_Model SHALL support serialization to JSON for persistence

### Requirement 8: Generation Request Model Validation

**User Story:** As a developer, I need validation rules enforced at the model level, so that invalid generation requests are caught before submission rather than after server rejection.

#### Acceptance Criteria

1. THE Generation_Request_Model SHALL validate that prompt text does not exceed 500 characters
2. THE Generation_Request_Model SHALL validate that DNA percentage is between 0 and 100
3. THE Generation_Request_Model SHALL validate that tempo feel is a defined enum value
4. THE Generation_Request_Model SHALL validate that vocal energy is a defined enum value
5. WHEN a validation rule fails, THE Generation_Request_Model SHALL expose the validation error to the UI without mutating state
6. THE Generation_Request_Model SHALL provide a computed isValid property that returns true only when all fields pass validation

### Requirement 9: Generation Request Model Persistence

**User Story:** As a user, I want my in-progress generation settings to survive app restarts, so that I don't lose my work when the app is killed.

#### Acceptance Criteria

1. WHEN the Generation_Request_Model changes, THE model SHALL persist to shared_preferences within 100ms
2. WHEN the application starts, THE Generation_Request_Model SHALL restore from shared_preferences
3. IF persistence fails, THEN THE Generation_Request_Model SHALL log the error and continue with default values
4. THE Generation_Request_Model SHALL restore only user-editable fields, not computed or derived fields
5. THE Generation_Request_Model SHALL handle schema evolution (missing fields from older app versions) without crashing

### Requirement 10: Accessibility - Color Independence

**User Story:** As a user with color blindness, I want visual information conveyed through multiple channels, so that I can use the app without relying on color alone.

#### Acceptance Criteria

1. WHEN a UI element uses color to convey state, THE element SHALL also use at least one non-color indicator (icon, shape, text label)
2. THE selected state of Genre and Mood cards SHALL include both a colored border and a check mark icon
3. THE progress tracker SHALL use both colored segments and numeric percentage
4. THE mini player forms SHALL use both color and shape to distinguish Bar, Card, and Pill
5. THE Design_Token_Registry SHALL document the non-color indicators required for each token

### Requirement 11: Accessibility - Reduce Motion Support

**User Story:** As a user with vestibular sensitivity, I want animations to be minimal when I've enabled reduce-motion, so that I can use the app without discomfort.

#### Acceptance Criteria

1. WHEN the system reduce-motion setting is enabled, THE application SHALL disable pulsing, spring, and parallax animations
2. WHEN the system reduce-motion setting is enabled, THE application SHALL replace animated transitions with immediate or linear transitions under 100ms
3. THE Accessibility_Service SHALL provide a stream of reduce-motion setting changes for reactive UI updates
4. THE mini player glow animation SHALL stop when reduce-motion is enabled
5. THE Creative Identity carousel snap animation SHALL become a linear slide when reduce-motion is enabled
6. THE DNA synthesis animation SHALL show the final state immediately when reduce-motion is enabled

### Requirement 12: Accessibility - Large Font Scale Support

**User Story:** As a user with low vision, I want the app to render correctly at large system font sizes, so that I can read all text without zooming.

#### Acceptance Criteria

1. THE application SHALL render correctly at 130%, 150%, and 200% system font scale without clipped text
2. WHEN text expands due to font scale, THE layout SHALL reflow without overlapping adjacent elements
3. THE mini player Bar SHALL show the full song title at 150% font scale (may require scrolling or marquee)
4. THE progress tracker slot labels SHALL remain readable at 200% font scale
5. THE onboarding card descriptions SHALL not overflow their containers at 200% font scale

### Requirement 13: Accessibility - Touch Target Size

**User Story:** As a user with motor impairments, I want all interactive controls to be large enough to tap accurately, so that I can use the app without frustration.

#### Acceptance Criteria

1. THE minimum touch target size for all interactive controls SHALL be 48x48 density-independent pixels
2. IF a visual control is smaller than 48x48dp, THEN THE touch target SHALL be padded invisibly to meet the minimum
3. THE mini player Bar buttons (prev, play, next) SHALL have 48x48dp touch targets
4. THE Genre and Mood selection cards SHALL have touch targets at least 48x48dp
5. THE progress tracker slots SHALL have touch targets at least 48x48dp when in the expanded slot list view

### Requirement 14: Accessibility - Semantic Labels

**User Story:** As a user who relies on screen readers, I want descriptive labels for all UI elements, so that I can navigate and understand the app non-visually.

#### Acceptance Criteria

1. WHEN a UI element is interactive, THE element SHALL have a semantic label describing its purpose
2. THE Genre selection cards SHALL have semantic labels like "Amapiano genre, selected" or "Afro House genre, not selected"
3. THE mini player Bar SHALL have a semantic label including the song title, artist, and playback state
4. THE progress tracker slots SHALL have semantic labels describing the slot name and current value
5. THE Haptics_Service SHALL not interfere with screen reader announcements

### Requirement 15: Accessibility - Custom Semantic Actions

**User Story:** As a user who cannot perform multi-touch or hold gestures, I want alternative actions for complex gestures, so that all functionality is accessible to me.

#### Acceptance Criteria

1. THE mini player SHALL expose custom semantic actions: "Dock player", "Convert to card", "Move to top"
2. WHEN a semantic action is invoked, THE mini player SHALL perform the equivalent gesture action
3. THE Creative Identity carousel SHALL expose semantic actions: "Next role", "Previous role", "Select role"
4. THE Genre selection grid SHALL expose semantic actions: "Select genre" for each genre card
5. THE custom semantic actions SHALL be discoverable through the system screen reader's actions menu

### Requirement 16: Analytics - Onboarding Events

**User Story:** As a product manager, I want to track onboarding completion and drop-off, so that I can identify friction points and optimize the activation funnel.

#### Acceptance Criteria

1. WHEN the user completes an onboarding screen, THE Analytics_Service SHALL send an "onboarding_step_completed" event with the screen name
2. WHEN the user skips an onboarding screen, THE Analytics_Service SHALL send an "onboarding_step_skipped" event with the screen name
3. WHEN the user completes the full onboarding flow, THE Analytics_Service SHALL send an "onboarding_completed" event with the total elapsed time
4. WHEN the user abandons onboarding, THE Analytics_Service SHALL send an "onboarding_abandoned" event with the last completed screen name
5. THE Analytics_Service SHALL not send duplicate events for the same action within 500ms

### Requirement 17: Analytics - Tour Events

**User Story:** As a product manager, I want to track app tour engagement, so that I can measure feature awareness and tune the tour content.

#### Acceptance Criteria

1. WHEN the user views an app tour card, THE Analytics_Service SHALL send a "tour_card_viewed" event with the card index
2. WHEN the user completes the app tour, THE Analytics_Service SHALL send a "tour_completed" event
3. WHEN the user skips the app tour, THE Analytics_Service SHALL send a "tour_skipped" event with the last viewed card index
4. WHEN the user replays the tour from settings, THE Analytics_Service SHALL send a "tour_replayed" event
5. THE Analytics_Service SHALL track tour completion rate and skip rate as derived metrics

### Requirement 18: Analytics - Progress Tracker Events

**User Story:** As a product manager, I want to track progress tracker interactions, so that I can understand which generation parameters users engage with most.

#### Acceptance Criteria

1. WHEN the user taps a progress tracker slot, THE Analytics_Service SHALL send a "progress_slot_tapped" event with the slot name
2. WHEN the user sets a progress tracker slot value, THE Analytics_Service SHALL send a "progress_slot_set" event with the slot name and whether it was set manually or by DNA
3. WHEN the user expands the progress tracker slot list, THE Analytics_Service SHALL send a "progress_tracker_expanded" event
4. WHEN the user generates with empty slots, THE Analytics_Service SHALL send a "generation_started_incomplete" event with the count of empty slots
5. THE Analytics_Service SHALL track slot completion rate per slot as a derived metric

### Requirement 19: Analytics - Visibility Events

**User Story:** As a product manager, I want to track visibility selection at generation time, so that I can understand user privacy preferences and inform default visibility decisions.

#### Acceptance Criteria

1. WHEN the user generates with public visibility, THE Analytics_Service SHALL send a "generation_visibility_public" event
2. WHEN the user generates with private visibility, THE Analytics_Service SHALL send a "generation_visibility_private" event
3. WHEN the user changes visibility after generation, THE Analytics_Service SHALL send a "track_visibility_changed" event with the old and new values
4. THE Analytics_Service SHALL track the ratio of public to private generations as a derived metric
5. THE Analytics_Service SHALL segment visibility choices by whether DNA suggested the visibility or the user explicitly set it

### Requirement 20: Analytics - DNA Activation Events

**User Story:** As a product manager, I want to track Creator DNA activation and usage, so that I can measure the feature's adoption and impact on retention.

#### Acceptance Criteria

1. WHEN the user activates Creator DNA, THE Analytics_Service SHALL send a "dna_activated" event with the initial model strength
2. WHEN the user generates with DNA influence, THE Analytics_Service SHALL send a "generation_dna_used" event with the DNA percentage applied
3. WHEN the user's DNA model strength increases, THE Analytics_Service SHALL send a "dna_strength_increased" event with the old and new strength values
4. WHEN the user reaches a DNA strength milestone (25%, 50%, 75%, 100%), THE Analytics_Service SHALL send a "dna_milestone_reached" event with the milestone value
5. THE Analytics_Service SHALL track DNA activation rate and average DNA usage percentage as derived metrics

### Requirement 21: Analytics - Mini Player Events

**User Story:** As a product manager, I want to track mini player form usage and gesture interactions, so that I can understand whether users discover and adopt the adaptive player features.

#### Acceptance Criteria

1. WHEN the user changes the mini player form (Bar to Card, Card to Pill, etc.), THE Analytics_Service SHALL send a "player_form_changed" event with the old and new forms
2. WHEN the user switches the mini player from Auto to Manual mode, THE Analytics_Service SHALL send a "player_mode_changed" event
3. WHEN the user performs a mini player morph gesture (diagonal drag, top extreme, bottom extreme), THE Analytics_Service SHALL send a "player_gesture" event with the gesture type
4. WHEN the user dismisses the mini player, THE Analytics_Service SHALL send a "player_dismissed" event with the current form
5. THE Analytics_Service SHALL track the usage rate of each player form (Bar, Card, Pill) as a derived metric

### Requirement 22: Design Token Registration API

**User Story:** As a developer, I want a simple API to register new genres and moods, so that extending the design system does not require changes to multiple files.

#### Acceptance Criteria

1. THE Design_Token_Registry SHALL expose a `registerGenre(name, colorToken)` method
2. THE Design_Token_Registry SHALL expose a `registerMood(name, colorToken)` method
3. WHEN a duplicate genre or mood name is registered, THE Design_Token_Registry SHALL throw a descriptive error
4. THE Design_Token_Registry SHALL expose a `getGenreToken(name)` method that returns the Color_Token
5. THE Design_Token_Registry SHALL expose a `getMoodToken(name)` method that returns the Color_Token
6. THE Design_Token_Registry SHALL validate Color_Token fields at registration time, not at access time

### Requirement 23: Theme System Integration

**User Story:** As a developer, I want design tokens integrated with Flutter's theme system, so that I can use them through the standard `Theme.of(context)` API without custom lookups.

#### Acceptance Criteria

1. THE Theme_System SHALL expose design tokens through a custom ThemeExtension
2. WHEN a genre is selected, THE Theme_System SHALL make the genre's Color_Token available via `Theme.of(context).extension<VhunambiTheme>()!.currentGenre`
3. WHEN a mood is selected, THE Theme_System SHALL make the mood's Color_Token available via `Theme.of(context).extension<VhunambiTheme>()!.currentMood`
4. THE Theme_System SHALL rebuild widgets when the selected genre or mood changes
5. THE Theme_System SHALL support multiple simultaneous genre/mood contexts (for example, a track card showing a different genre than the cockpit)

### Requirement 24: Error Handling and Diagnostics

**User Story:** As a developer, I want clear error messages and diagnostic tools, so that I can quickly identify and fix issues with design tokens, haptics, and state management.

#### Acceptance Criteria

1. WHEN a Color_Token fails contrast validation, THE error message SHALL include the token name, actual contrast ratio, and required minimum
2. WHEN a non-existent genre or mood is accessed, THE Design_Token_Registry SHALL throw an error listing all registered names
3. THE Haptics_Service SHALL log when system haptics are disabled, for debugging user reports of missing feedback
4. THE Generation_Request_Model SHALL provide a `validationErrors` property listing all current validation failures
5. THE Analytics_Service SHALL log failed event sends for debugging analytics data gaps

### Requirement 25: Performance - Token Lookup Efficiency

**User Story:** As a developer, I need efficient token lookups, so that rendering genre/mood colors does not introduce frame drops in scrolling lists.

#### Acceptance Criteria

1. THE Design_Token_Registry SHALL complete token lookup in O(1) time complexity
2. WHEN rendering a list of 100 genre cards, THE frame rate SHALL remain at 60fps on a mid-range device
3. THE Design_Token_Registry SHALL cache computed values (like contrast-safe text colors) to avoid redundant calculation
4. THE Theme_System SHALL not rebuild unaffected widgets when a genre or mood changes in a different context
5. THE Color_Token SHALL be immutable to allow safe sharing across isolates

### Requirement 26: Performance - Analytics Batching

**User Story:** As a product manager, I need analytics data to be reliable, so that I can trust the metrics when making product decisions, while minimizing performance impact.

#### Acceptance Criteria

1. THE Analytics_Service SHALL batch events and send them at most once per second
2. WHEN the app is backgrounded, THE Analytics_Service SHALL flush all pending events within 500ms
3. THE Analytics_Service SHALL not block the UI thread when sending events
4. IF analytics sending fails, THE Analytics_Service SHALL retry up to 3 times with exponential backoff
5. THE Analytics_Service SHALL discard events older than 24 hours to prevent unbounded queue growth

### Requirement 27: Testing Support

**User Story:** As a QA engineer, I need testable interfaces for design tokens, haptics, and analytics, so that I can write automated tests without requiring device hardware or network access.

#### Acceptance Criteria

1. THE Haptics_Service SHALL provide a mock implementation that records haptic calls without triggering hardware
2. THE Analytics_Service SHALL provide a mock implementation that records events without network calls
3. THE Design_Token_Registry SHALL provide a test-only reset method to clear registrations between test cases
4. THE Generation_Request_Model SHALL support test-only direct state injection without persistence side effects
5. THE Accessibility_Service SHALL provide mock implementations for reduce-motion and font scale settings

### Requirement 28: Documentation

**User Story:** As a new developer joining the team, I want comprehensive documentation for the design system, so that I can use it correctly without reverse-engineering the implementation.

#### Acceptance Criteria

1. THE Design_Token_Registry SHALL have API documentation with examples for registering and accessing tokens
2. THE Haptics_Service SHALL have documentation listing all haptic patterns and when to use each
3. THE Generation_Request_Model SHALL have documentation for each field including validation rules and default values
4. THE Analytics_Service SHALL have documentation listing all event names, required properties, and when to send each event
5. THE design system documentation SHALL include migration guides for converting existing code to use the centralized services

## Non-Functional Requirements

### Performance

- Design token lookups complete in under 1ms
- Analytics event recording completes in under 5ms (batching and sending happen asynchronously)
- Haptic feedback triggers within 16ms of the user action (same frame)
- Generation Request Model updates propagate to consumers within 16ms (one frame at 60fps)
- Theme rebuilds affect only the widgets that depend on the changed token

### Maintainability

- All design tokens defined in a single file or directory
- Adding a new genre or mood requires changes to exactly one registration site
- Haptic patterns defined as named constants, not magic numbers
- Analytics event names defined as constants with compile-time safety
- State management uses Riverpod providers for testability and dependency injection

### Compatibility

- Supports Flutter 3.10 or higher
- Supports iOS 13.0 or higher
- Supports Android API 21 or higher
- Handles platform differences (iOS vs Android haptics) transparently
- Supports dark mode (app is dark-first, tokens must work in dark theme)

### Testability

- All services have mock implementations for unit tests
- Design token registration can be tested without rendering widgets
- Haptic calls can be verified without device hardware
- Analytics events can be verified without network access
- Generation Request Model validation can be tested independently of UI

### Accessibility

- All color tokens meet WCAG AA contrast ratio (4.5:1 for normal text, 3:1 for large text)
- All interactive controls meet minimum 48x48dp touch target size
- All state changes conveyed through multiple channels (not color alone)
- Reduce-motion preference respected for all animations
- Semantic labels provided for all interactive elements
- Custom semantic actions provided for complex gestures

### Security

- Sensitive generation parameters (lyrics, prompts) are not logged in analytics events
- User identity information is not included in analytics events without explicit consent
- Design tokens do not expose internal implementation details through error messages
- Haptic feedback patterns do not create timing side channels for sensitive operations

### Reliability

- Design Token Registry validates all tokens at registration time, not access time
- Haptics Service gracefully handles missing platform APIs
- Analytics Service retries failed sends with exponential backoff
- Generation Request Model handles missing fields from older app versions
- Theme System provides fallback colors when tokens are not found

## Open Questions

1. Should genre and mood color tokens be user-customizable in a future version, or always designer-defined?
2. Should analytics events include generation quality ratings (user feedback on generated songs)?
3. Should the Haptics Service support custom haptic patterns beyond the standard types?
4. Should the Design Token Registry support runtime theme switching (light mode), or is dark-first sufficient?
5. Should the Generation Request Model track edit history for debugging user reports of "lost changes"?
