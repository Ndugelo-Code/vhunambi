# Implementation Plan: Cross-Cutting Design System

## Overview

This plan implements the Cross-Cutting Design System, providing foundational infrastructure for consistency, accessibility, and maintainability across Vhunambi. The system includes design token registry (genre/mood colors), theme integration, haptics service, generation request state management, accessibility utilities, and analytics instrumentation.

**Implementation Language:** Dart (Flutter)

**Key Components:**
- DesignTokenRegistry: 8 genre + 5 mood color tokens with WCAG AA validation
- VhunambiThemeExtension: Flutter theme integration
- HapticsService: Platform-abstracted haptic feedback
- GenerationRequestModel: Unified state with validation and persistence
- AccessibilityService: Reduce-motion, touch targets, semantic labels
- AnalyticsService: Event batching with retry logic

## Tasks

- [ ] 1. Set up design system infrastructure
  - Create `lib/core/design_system/` directory structure
  - Create subdirectories: `tokens/`, `theme/`, `services/`, `models/`
  - Add barrel exports for clean imports
  - _Requirements: 1.1, 2.1, 22.1, 22.2_

- [ ] 2. Implement DesignTokenRegistry foundation
  - [ ] 2.1 Create ColorToken data class
    - Define immutable ColorToken class with accent, surfaceTint, glow, textColor fields
    - Implement equality and hashCode overrides
    - Add ColorToken.auto factory constructor with automatic text color calculation
    - File: `lib/core/design_system/tokens/color_token.dart`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 25.5_
  
  - [ ] 2.2 Define Genre and Mood enums
    - Create Genre enum with 8 values: amapiano, afroHouse, gqom, kwaito, afroPop, maskandi, hipHop, gospel
    - Create Mood enum with 5 values: joyful, melancholic, energetic, calm, romantic
    - Add displayName getters for UI presentation
    - File: `lib/core/design_system/tokens/design_enums.dart`
    - _Requirements: 1.3, 2.3_
  
  - [ ] 2.3 Implement contrast ratio calculation
    - Create private helper methods: _calculateContrastRatio, _relativeLuminance, _linearize
    - Follow WCAG formula for contrast calculation
    - Return ratio as double (e.g., 4.5 for 4.5:1)
    - File: `lib/core/design_system/tokens/contrast_utils.dart`
    - _Requirements: 1.4, 2.4, 4.1_
  
  - [ ] 2.4 Create custom exceptions for token registry
    - Define DuplicateTokenException for duplicate registrations
    - Define ContrastViolationException with token details and actual ratio
    - Define TokenNotFoundException with available token list
    - File: `lib/core/design_system/tokens/token_exceptions.dart`
    - _Requirements: 1.6, 4.2, 24.1, 24.2_
  
  - [ ] 2.5 Implement DesignTokenRegistry core
    - Create static registry with _genreTokens and _moodTokens maps
    - Implement registerGenre and registerMood methods with validation
    - Implement _validateToken to enforce 4.5:1 contrast minimum
    - Add _isSealed flag to prevent late registration
    - Implement getGenreToken and getMoodToken with sealing behavior
    - Add @visibleForTesting reset() method for test isolation
    - File: `lib/core/design_system/tokens/design_token_registry.dart`
    - _Requirements: 1.1, 1.6, 2.1, 4.1, 4.2, 22.1, 22.2, 22.3, 22.4, 22.5, 22.6, 27.3_
  
  - [ ] 2.6 Add validation report generation
    - Implement generateValidationReport method
    - Return map of token names to contrast ratios
    - Include both genre and mood tokens in report
    - File: `lib/core/design_system/tokens/design_token_registry.dart`
    - _Requirements: 4.3, 4.4_

- [ ] 3. Register all genre and mood color tokens
  - [ ] 3.1 Create token initialization file
    - Create initializeDesignTokens() function
    - Register 8 genre tokens with hex colors from design
    - Register 5 mood tokens with hex colors from design
    - Use ColorToken.auto factory for automatic text color selection
    - File: `lib/core/design_system/tokens/token_initialization.dart`
    - _Requirements: 1.1, 1.3, 2.1, 2.3, 2.5_
  
  - [ ] 3.2 Call token initialization in main.dart
    - Call initializeDesignTokens() before runApp()
    - Ensure tokens registered before MaterialApp builds
    - Add error handling for registration failures
    - File: `lib/main.dart`
    - _Requirements: 1.1, 2.1, 22.6_

- [ ] 4. Implement VhunambiThemeExtension
  - [ ] 4.1 Create theme extension class
    - Define VhunambiThemeExtension extending ThemeExtension
    - Add currentGenre and currentMood nullable fields
    - Implement genreToken and moodToken computed getters
    - Implement getGenreTokenFor and getMoodTokenFor methods
    - Override copyWith and lerp methods (discrete values, no interpolation)
    - Define empty constant for default state
    - File: `lib/core/design_system/theme/vhunambi_theme_extension.dart`
    - _Requirements: 1.2, 2.2, 22.4, 22.5, 23.1, 23.2, 23.3_
  
  - [ ] 4.2 Integrate with AppTheme
    - Update AppTheme.darkTheme to include VhunambiThemeExtension.empty
    - Add darkThemeWith factory method for genre/mood contexts
    - Update existing theme extensions list
    - File: `lib/core/theme/app_theme.dart`
    - _Requirements: 23.1, 23.2, 23.4_

- [ ] 5. Implement HapticsService
  - [ ] 5.1 Create HapticsService class
    - Define _isEnabled flag with system setting check
    - Implement _checkSystemSettings for iOS/Android
    - Implement lightImpact, mediumImpact, heavyImpact, selectionTick methods
    - Add vibrate method for Android custom patterns
    - Add setEnabled and isEnabled for testing control
    - File: `lib/core/design_system/services/haptics_service.dart`
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 6.1, 6.2, 6.3, 6.5, 24.3_
  
  - [ ] 5.2 Create Riverpod provider for HapticsService
    - Define hapticsServiceProvider as Provider<HapticsService>
    - Ensure singleton instance
    - File: `lib/core/design_system/services/haptics_service.dart`
    - _Requirements: 5.6_
  
  - [ ] 5.3 Create MockHapticsService for testing
    - Extend HapticsService with mock implementation
    - Add calls list to record method invocations
    - Override all haptic methods to record instead of trigger
    - Add reset() method for test isolation
    - File: `lib/core/design_system/services/mock_haptics_service.dart`
    - _Requirements: 27.1_

- [ ] 6. Implement GenerationRequestModel state classes
  - [ ] 6.1 Define supporting enums
    - Create TempoFeel enum: laidBack, moderate, upbeat, frenetic
    - Create VocalEnergy enum: subtle, balanced, dominant
    - Create Language enum: english, tshiVenda, isiZulu, isiXhosa
    - Create TrackVisibility enum: public, private
    - Add displayName getters for each enum
    - File: `lib/core/design_system/models/generation_enums.dart`
    - _Requirements: 7.2_
  
  - [ ] 6.2 Create GenerationRequestState class
    - Define immutable state with all 9 fields: promptText, genre, mood, tempoFeel, vocalEnergy, language, lyricsText, dnaPercentage, visibility
    - Implement copyWith method for immutable updates
    - Implement toJson for persistence
    - Implement fromJson with schema evolution support (handle missing fields)
    - Add _parseEnum helper for safe enum deserialization
    - File: `lib/core/design_system/models/generation_request_state.dart`
    - _Requirements: 7.1, 7.2, 7.6, 9.1, 9.4, 9.5_
  
  - [ ] 6.3 Implement ValidationEngine
    - Define validation constants: maxPromptLength=500, maxLyricsLength=2000, dnaRange=[0,100]
    - Create ValidationResult class with isValid and errors map
    - Implement validate static method checking all constraints
    - Return ValidationResult.valid() or ValidationResult.invalid(errors)
    - File: `lib/core/design_system/models/validation_engine.dart`
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6, 24.4_
  
  - [ ] 6.4 Create GenerationRequestNotifier
    - Extend StateNotifier<GenerationRequestState>
    - Accept SharedPreferences in constructor
    - Implement _loadFromStorage and _saveToStorage methods
    - Implement setter methods: setPromptText, setGenre, setMood, setTempoFeel, setVocalEnergy, setLanguage, setLyricsText, setDnaPercentage, setVisibility
    - Implement validate() returning ValidationResult
    - Implement reset() to clear state
    - Ensure persistence happens within 100ms of state change
    - File: `lib/core/design_system/models/generation_request_notifier.dart`
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 9.1, 9.2, 9.3_
  
  - [ ] 6.5 Create Riverpod providers for generation request
    - Define sharedPreferencesProvider (to be overridden at startup)
    - Define generationRequestProvider as StateNotifierProvider
    - Ensure provider reads from sharedPreferencesProvider
    - File: `lib/core/design_system/models/generation_request_providers.dart`
    - _Requirements: 7.5, 9.1_

- [ ] 7. Implement AccessibilityService
  - [ ] 7.1 Create AccessibilityService static utilities
    - Implement isReduceMotionEnabled reading from MediaQuery.disableAnimations
    - Implement getTextScaleFactor reading from MediaQuery.textScaleFactor
    - Implement isLargeTextScale checking if factor > 1.3
    - File: `lib/core/design_system/services/accessibility_service.dart`
    - _Requirements: 11.1, 11.3, 12.1, 12.2_
  
  - [ ] 7.2 Implement touch target enforcement
    - Create ensureTouchTarget static method
    - Calculate padding to reach 48dp minimum size
    - Wrap child with Padding and optional GestureDetector
    - File: `lib/core/design_system/services/accessibility_service.dart`
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_
  
  - [ ] 7.3 Implement semantic label builders
    - Create genreChipLabel static method
    - Create moodChipLabel static method
    - Create progressSlotLabel static method
    - Create miniPlayerLabel static method
    - File: `lib/core/design_system/services/accessibility_service.dart`
    - _Requirements: 14.1, 14.2, 14.3, 14.4_
  
  - [ ] 7.4 Create AccessibilityProvider widget
    - Create StatelessWidget that wraps child with ProviderScope
    - Override reduceMotionProvider with MediaQuery value
    - File: `lib/core/design_system/services/accessibility_service.dart`
    - _Requirements: 11.3_

- [ ] 8. Implement AnalyticsService event schema
  - [ ] 8.1 Create base AnalyticsEvent class
    - Define abstract class with name and timestamp fields
    - Define abstract toJson method
    - File: `lib/core/design_system/services/analytics/analytics_event.dart`
    - _Requirements: 16.1, 16.2, 16.3, 16.4_
  
  - [ ] 8.2 Create onboarding event classes
    - Implement OnboardingStepCompletedEvent with screenName
    - Implement OnboardingStepSkippedEvent with screenName
    - Implement OnboardingCompletedEvent with elapsedTime
    - Implement OnboardingAbandonedEvent with lastCompletedScreen
    - File: `lib/core/design_system/services/analytics/onboarding_events.dart`
    - _Requirements: 16.1, 16.2, 16.3, 16.4_
  
  - [ ] 8.3 Create tour event classes
    - Implement TourCardViewedEvent with cardIndex
    - Implement TourCompletedEvent
    - Implement TourSkippedEvent with lastViewedCardIndex
    - Implement TourReplayedEvent
    - File: `lib/core/design_system/services/analytics/tour_events.dart`
    - _Requirements: 17.1, 17.2, 17.3, 17.4_
  
  - [ ] 8.4 Create progress tracker event classes
    - Implement ProgressSlotTappedEvent with slotName
    - Implement ProgressSlotSetEvent with slotName and wasSetByDna
    - Implement ProgressTrackerExpandedEvent
    - Implement GenerationStartedIncompleteEvent with emptySlotCount
    - File: `lib/core/design_system/services/analytics/progress_events.dart`
    - _Requirements: 18.1, 18.2, 18.3, 18.4_
  
  - [ ] 8.5 Create visibility event classes
    - Implement GenerationVisibilityPublicEvent
    - Implement GenerationVisibilityPrivateEvent
    - Implement TrackVisibilityChangedEvent with oldVisibility and newVisibility
    - File: `lib/core/design_system/services/analytics/visibility_events.dart`
    - _Requirements: 19.1, 19.2, 19.3_
  
  - [ ] 8.6 Create DNA event classes
    - Implement DnaActivatedEvent with initialStrength
    - Implement GenerationDnaUsedEvent with dnaPercentage
    - Implement DnaStrengthIncreasedEvent with oldStrength and newStrength
    - Implement DnaMilestoneReachedEvent with milestoneValue
    - File: `lib/core/design_system/services/analytics/dna_events.dart`
    - _Requirements: 20.1, 20.2, 20.3, 20.4_
  
  - [ ] 8.7 Create mini player event classes
    - Implement PlayerFormChangedEvent with oldForm and newForm
    - Implement PlayerModeChangedEvent with mode
    - Implement PlayerGestureEvent with gestureType
    - Implement PlayerDismissedEvent with currentForm
    - File: `lib/core/design_system/services/analytics/player_events.dart`
    - _Requirements: 21.1, 21.2, 21.3, 21.4_

- [ ] 9. Implement AnalyticsService core
  - [ ] 9.1 Create AnalyticsService class
    - Accept FirebaseAnalytics in constructor
    - Initialize _eventQueue and _lastEventTime maps
    - Start _batchTimer with 1-second interval
    - Implement track method with deduplication (500ms window)
    - Implement _flushEvents with batch sending
    - Implement _sendWithRetry with exponential backoff (3 retries)
    - Implement onAppPaused for lifecycle handling
    - Implement dispose method
    - File: `lib/core/design_system/services/analytics/analytics_service.dart`
    - _Requirements: 16.5, 26.1, 26.2, 26.3, 26.4, 26.5_
  
  - [ ] 9.2 Create Riverpod provider for AnalyticsService
    - Define analyticsServiceProvider as Provider<AnalyticsService>
    - Initialize with FirebaseAnalytics.instance
    - Add onDispose callback to flush events
    - File: `lib/core/design_system/services/analytics/analytics_service.dart`
    - _Requirements: 26.1, 26.2_
  
  - [ ] 9.3 Create MockAnalyticsService for testing
    - Extend AnalyticsService with mock implementation
    - Add trackedEvents list to record all events
    - Override track to record without sending
    - Override _flushEvents as no-op
    - Add reset() method for test isolation
    - File: `lib/core/design_system/services/analytics/mock_analytics_service.dart`
    - _Requirements: 27.2_

- [ ] 10. Checkpoint - Core infrastructure complete
  - Ensure all tests pass for foundation components
  - Verify no compilation errors
  - Verify design token registry has all 13 tokens registered
  - Verify theme extension integrates correctly
  - Ask user if questions arise

- [ ] 11. Write unit tests for DesignTokenRegistry
  - [ ] 11.1 Test token registration
    - Test successful genre token registration
    - Test successful mood token registration
    - Test DuplicateTokenException on duplicate registration
    - Test all 8 genres and 5 moods can be registered
    - File: `test/core/design_system/tokens/design_token_registry_test.dart`
    - _Requirements: 1.1, 1.6, 2.1, 22.1, 22.2, 22.3_
  
  - [ ] 11.2 Test contrast validation
    - Test ContrastViolationException for low-contrast tokens
    - Test successful registration for tokens meeting 4.5:1 minimum
    - Test contrast ratio calculation accuracy
    - File: `test/core/design_system/tokens/design_token_registry_test.dart`
    - _Requirements: 1.4, 2.4, 4.1, 4.2_
  
  - [ ] 11.3 Test token retrieval
    - Test getGenreToken returns correct token
    - Test getMoodToken returns correct token
    - Test TokenNotFoundException for non-existent tokens
    - Test registry sealing after first access
    - File: `test/core/design_system/tokens/design_token_registry_test.dart`
    - _Requirements: 22.4, 22.5, 24.2_
  
  - [ ] 11.4 Test validation report
    - Test generateValidationReport includes all tokens
    - Test report contains correct contrast ratios
    - File: `test/core/design_system/tokens/design_token_registry_test.dart`
    - _Requirements: 4.3, 4.4_
  
  - [ ] 11.5 Test ColorToken behavior
    - Test equality and hashCode
    - Test ColorToken.auto chooses correct text color
    - Test immutability
    - File: `test/core/design_system/tokens/color_token_test.dart`
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 25.5_

- [ ] 12. Write unit tests for VhunambiThemeExtension
  - [ ] 12.1 Test theme extension accessors
    - Test genreToken returns correct value when currentGenre set
    - Test moodToken returns correct value when currentMood set
    - Test genreToken returns null when no genre selected
    - Test getGenreTokenFor and getMoodTokenFor work correctly
    - File: `test/core/design_system/theme/vhunambi_theme_extension_test.dart`
    - _Requirements: 1.2, 2.2, 22.4, 22.5, 23.2, 23.3_
  
  - [ ] 12.2 Test copyWith and lerp
    - Test copyWith updates only specified fields
    - Test lerp returns discrete values (no interpolation)
    - File: `test/core/design_system/theme/vhunambi_theme_extension_test.dart`
    - _Requirements: 23.1_

- [ ] 13. Write unit tests for HapticsService
  - [ ] 13.1 Test haptic methods when enabled
    - Test lightImpact, mediumImpact, heavyImpact, selectionTick
    - Verify methods complete without error
    - File: `test/core/design_system/services/haptics_service_test.dart`
    - _Requirements: 5.1, 5.2_
  
  - [ ] 13.2 Test haptic no-op when disabled
    - Test setEnabled(false) disables all haptics
    - Verify no platform API calls when disabled
    - File: `test/core/design_system/services/haptics_service_test.dart`
    - _Requirements: 5.2, 6.3_
  
  - [ ] 13.3 Test MockHapticsService recording
    - Test mock records all method calls
    - Test reset() clears call history
    - File: `test/core/design_system/services/mock_haptics_service_test.dart`
    - _Requirements: 27.1_

- [ ] 14. Write unit tests for GenerationRequestModel
  - [ ] 14.1 Test state updates
    - Test each setter updates state correctly
    - Test state changes propagate to listeners
    - File: `test/core/design_system/models/generation_request_notifier_test.dart`
    - _Requirements: 7.2, 7.3, 7.4, 7.5_
  
  - [ ] 14.2 Test validation
    - Test ValidationEngine validates prompt length
    - Test ValidationEngine validates lyrics length
    - Test ValidationEngine validates DNA percentage range
    - Test validate() returns correct ValidationResult
    - File: `test/core/design_system/models/validation_engine_test.dart`
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_
  
  - [ ] 14.3 Test persistence
    - Test state saves to SharedPreferences
    - Test state restores from SharedPreferences
    - Test persistence handles missing fields gracefully
    - Mock SharedPreferences for testing
    - File: `test/core/design_system/models/generation_request_notifier_test.dart`
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_
  
  - [ ] 14.4 Test JSON serialization
    - Test toJson includes all fields
    - Test fromJson handles all fields
    - Test fromJson with missing fields uses defaults
    - File: `test/core/design_system/models/generation_request_state_test.dart`
    - _Requirements: 7.6, 9.1, 9.4, 9.5_

- [ ] 15. Write unit tests for AccessibilityService
  - [ ] 15.1 Test touch target calculation
    - Test ensureTouchTarget adds correct padding for sizes < 48dp
    - Test ensureTouchTarget no-ops for sizes >= 48dp
    - Test GestureDetector wrapping when onTap provided
    - File: `test/core/design_system/services/accessibility_service_test.dart`
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_
  
  - [ ] 15.2 Test semantic label formatting
    - Test genreChipLabel format
    - Test moodChipLabel format
    - Test progressSlotLabel format
    - Test miniPlayerLabel format
    - File: `test/core/design_system/services/accessibility_service_test.dart`
    - _Requirements: 14.1, 14.2, 14.3, 14.4_

- [ ] 16. Write unit tests for AnalyticsService
  - [ ] 16.1 Test event tracking
    - Test track() queues events
    - Test deduplication within 500ms window
    - Test _lastEventTime updated correctly
    - File: `test/core/design_system/services/analytics/analytics_service_test.dart`
    - _Requirements: 16.5, 26.1_
  
  - [ ] 16.2 Test event batching
    - Test flush occurs every 1 second
    - Test immediate flush at 10+ queued events
    - Test onAppPaused flushes events
    - File: `test/core/design_system/services/analytics/analytics_service_test.dart`
    - _Requirements: 26.1, 26.2, 26.3_
  
  - [ ] 16.3 Test retry logic
    - Test exponential backoff retry on failure
    - Test gives up after 3 retries
    - Mock Firebase Analytics for testing
    - File: `test/core/design_system/services/analytics/analytics_service_test.dart`
    - _Requirements: 26.4_
  
  - [ ] 16.4 Test MockAnalyticsService
    - Test mock records all events
    - Test reset() clears event history
    - File: `test/core/design_system/services/analytics/mock_analytics_service_test.dart`
    - _Requirements: 27.2_

- [ ] 17. Write widget tests for theme integration
  - [ ] 17.1 Test genre token in widget tree
    - Create test widget reading Theme.of(context).extension<VhunambiThemeExtension>()
    - Test genreToken accessible from widget
    - Test token values match registry
    - File: `test/core/design_system/theme/theme_integration_test.dart`
    - _Requirements: 1.2, 23.2, 23.3, 23.4_
  
  - [ ] 17.2 Test theme rebuild on change
    - Test widgets rebuild when genre/mood changes
    - Test only affected widgets rebuild (not entire tree)
    - File: `test/core/design_system/theme/theme_integration_test.dart`
    - _Requirements: 23.4, 25.4_
  
  - [ ] 17.3 Test multiple theme contexts
    - Test different widgets can have different genre/mood contexts
    - Test nested theme contexts work correctly
    - File: `test/core/design_system/theme/theme_integration_test.dart`
    - _Requirements: 23.5_

- [ ] 18. Write widget tests for generation request UI binding
  - [ ] 18.1 Test genre/mood selector binding
    - Create mock genre selector widget
    - Test tapping updates GenerationRequestNotifier
    - Test selected state reflects notifier state
    - File: `test/core/design_system/models/generation_request_ui_test.dart`
    - _Requirements: 7.3, 7.4, 7.5_
  
  - [ ] 18.2 Test DNA slider binding
    - Create mock DNA slider widget
    - Test dragging updates dnaPercentage
    - Test value reflects notifier state
    - File: `test/core/design_system/models/generation_request_ui_test.dart`
    - _Requirements: 7.3, 7.4, 7.5_
  
  - [ ] 18.3 Test validation display
    - Create mock form widget with validation
    - Test validation errors shown in UI
    - Test isValid property affects submit button
    - File: `test/core/design_system/models/generation_request_ui_test.dart`
    - _Requirements: 8.5, 8.6_

- [ ] 19. Write integration tests
  - [ ] 19.1 Test end-to-end generation flow
    - Simulate user selecting genre, mood, DNA percentage, visibility
    - Verify state persisted to SharedPreferences
    - Simulate app restart
    - Verify state restored correctly
    - File: `integration_test/design_system/generation_flow_test.dart`
    - _Requirements: 7.1, 7.3, 9.1, 9.2_
  
  - [ ] 19.2 Test analytics event funnel
    - Simulate onboarding completion
    - Verify all events sent to Firebase (mocked)
    - Verify event order and parameters
    - File: `integration_test/design_system/analytics_funnel_test.dart`
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 26.1, 26.2_
  
  - [ ] 19.3 Test haptics with system settings
    - Simulate system haptics enabled
    - Trigger haptic, verify it fires
    - Simulate system haptics disabled (mocked)
    - Trigger haptic, verify no-op
    - File: `integration_test/design_system/haptics_integration_test.dart`
    - _Requirements: 5.2, 6.1, 6.2, 6.3_

- [ ] 20. Write performance tests
  - [ ] 20.1 Test token lookup performance
    - Register all 13 tokens
    - Perform 1000 lookups
    - Assert average time < 1ms
    - File: `test/core/design_system/performance/token_lookup_performance_test.dart`
    - _Requirements: 25.1_
  
  - [ ] 20.2 Test theme rebuild efficiency
    - Create widget tree with 100 genre chips
    - Change selected genre
    - Measure rebuild count
    - Assert only 2 widgets rebuild (old selected + new selected)
    - File: `test/core/design_system/performance/theme_rebuild_performance_test.dart`
    - _Requirements: 25.2, 25.4_
  
  - [ ] 20.3 Test analytics batching performance
    - Queue 100 events
    - Measure flush time
    - Assert completes within 500ms
    - Assert UI thread not blocked
    - File: `test/core/design_system/performance/analytics_performance_test.dart`
    - _Requirements: 26.1, 26.2, 26.3_
  
  - [ ] 20.4 Test generation request persistence performance
    - Update genre 100 times
    - Measure each update time
    - Assert each update < 5ms
    - Assert 60fps maintained (16ms frame budget)
    - File: `test/core/design_system/performance/generation_persistence_performance_test.dart`
    - _Requirements: 7.3, 9.1, 9.2, 25.1_

- [ ] 21. Checkpoint - Testing complete
  - Ensure all unit tests pass
  - Ensure all widget tests pass
  - Ensure all integration tests pass
  - Ensure all performance tests pass
  - Generate test coverage report
  - Ask user if questions arise

- [ ] 22. Migrate existing codebase - Genre/Mood colors
  - [ ] 22.1 Identify hardcoded genre/mood colors
    - Search codebase for genre color hex values
    - Search for mood color hex values
    - Document all locations for migration
    - File: Create migration checklist document
    - _Requirements: 1.1, 1.5, 2.1, 2.2_
  
  - [ ] 22.2 Replace genre colors in Studio Cockpit
    - Update genre selection cards to use Theme.of(context).extension<VhunambiThemeExtension>()!.getGenreTokenFor(genre)
    - Update progress tracker genre colors
    - Remove hardcoded color definitions
    - File: `lib/features/studio/` (various files)
    - _Requirements: 1.2, 1.5, 22.4, 22.5_
  
  - [ ] 22.3 Replace mood colors in Onboarding
    - Update mood selection chips to use theme extension
    - Update carousel mood indicators
    - File: `lib/features/onboarding/` (various files)
    - _Requirements: 2.2, 2.5, 22.4, 22.5_
  
  - [ ] 22.4 Replace genre/mood colors in Explore and Library
    - Update track card genre indicators
    - Update filter chip colors
    - File: `lib/features/explore/` and `lib/features/library/` (various files)
    - _Requirements: 1.2, 1.5, 2.2, 2.5_

- [ ] 23. Migrate existing codebase - Haptic feedback
  - [ ] 23.1 Replace HapticFeedback calls in Studio
    - Replace HapticFeedback.lightImpact() with ref.read(hapticsServiceProvider).lightImpact()
    - Replace HapticFeedback.selectionClick() with selectionTick()
    - Add ConsumerWidget where needed for ref access
    - File: `lib/features/studio/` (various files)
    - _Requirements: 5.1, 5.2, 5.6_
  
  - [ ] 23.2 Replace HapticFeedback calls in Onboarding
    - Replace all direct haptic calls with service calls
    - Update carousel snap feedback
    - Update chip selection feedback
    - File: `lib/features/onboarding/` (various files)
    - _Requirements: 5.1, 5.2, 5.6_
  
  - [ ] 23.3 Replace HapticFeedback calls in Mini Player
    - Replace all direct haptic calls with service calls
    - Update gesture feedback
    - Update button press feedback
    - File: `lib/features/player/` (various files)
    - _Requirements: 5.1, 5.2, 5.6_

- [ ] 24. Migrate existing codebase - Generation state
  - [ ] 24.1 Identify duplicated generation state
    - Search for genre/mood/DNA state variables in UI widgets
    - Document all state duplication locations
    - File: Create migration checklist document
    - _Requirements: 7.1, 7.4_
  
  - [ ] 24.2 Migrate Studio Cockpit to GenerationRequestModel
    - Replace local state with ref.watch(generationRequestProvider)
    - Use notifier setters for updates
    - Remove duplicated state variables
    - File: `lib/features/studio/` (various files)
    - _Requirements: 7.1, 7.2, 7.3, 7.5_
  
  - [ ] 24.3 Migrate visibility control to GenerationRequestModel
    - Replace local visibility state with generationRequestProvider
    - Update toggle to use setVisibility()
    - File: `lib/features/studio/` (various files)
    - _Requirements: 7.2, 7.3, 7.5_
  
  - [ ] 24.4 Migrate progress tracker to GenerationRequestModel
    - Update progress tracker to read from generationRequestProvider
    - Ensure slots reflect current state
    - File: `lib/features/studio/` (various files)
    - _Requirements: 7.1, 7.3, 7.4_

- [ ] 25. Add analytics instrumentation to features
  - [ ] 25.1 Instrument onboarding screens
    - Add OnboardingStepCompletedEvent on screen completion
    - Add OnboardingSkippedEvent on skip button
    - Add OnboardingCompletedEvent on flow completion
    - Add OnboardingAbandonedEvent on back navigation
    - File: `lib/features/onboarding/` (various files)
    - _Requirements: 16.1, 16.2, 16.3, 16.4_
  
  - [ ] 25.2 Instrument app tour
    - Add TourCardViewedEvent on card view
    - Add TourCompletedEvent on completion
    - Add TourSkippedEvent on skip
    - File: `lib/features/onboarding/` or tour feature
    - _Requirements: 17.1, 17.2, 17.3_
  
  - [ ] 25.3 Instrument progress tracker
    - Add ProgressSlotTappedEvent on slot tap
    - Add ProgressSlotSetEvent on value change
    - Add ProgressTrackerExpandedEvent on expansion
    - Add GenerationStartedIncompleteEvent when starting with empty slots
    - File: `lib/features/studio/` (progress tracker)
    - _Requirements: 18.1, 18.2, 18.3, 18.4_
  
  - [ ] 25.4 Instrument visibility controls
    - Add GenerationVisibilityPublicEvent on public selection
    - Add GenerationVisibilityPrivateEvent on private selection
    - Add TrackVisibilityChangedEvent on post-generation change
    - File: `lib/features/studio/` (visibility controls)
    - _Requirements: 19.1, 19.2, 19.3_
  
  - [ ] 25.5 Instrument DNA features
    - Add DnaActivatedEvent on DNA activation
    - Add GenerationDnaUsedEvent on generation with DNA
    - Add DnaStrengthIncreasedEvent on strength increase
    - Add DnaMilestoneReachedEvent on milestones
    - File: `lib/features/studio/` (DNA features)
    - _Requirements: 20.1, 20.2, 20.3, 20.4_
  
  - [ ] 25.6 Instrument mini player
    - Add PlayerFormChangedEvent on form change
    - Add PlayerModeChangedEvent on mode change
    - Add PlayerGestureEvent on gestures
    - Add PlayerDismissedEvent on dismissal
    - File: `lib/features/player/` (mini player)
    - _Requirements: 21.1, 21.2, 21.3, 21.4_

- [ ] 26. Add accessibility features to UI components
  - [ ] 26.1 Add semantic labels to genre/mood chips
    - Use AccessibilityService.genreChipLabel
    - Use AccessibilityService.moodChipLabel
    - Wrap chips with Semantics widget
    - File: `lib/features/studio/` and `lib/features/onboarding/`
    - _Requirements: 14.1, 14.2_
  
  - [ ] 26.2 Add semantic labels to progress tracker
    - Use AccessibilityService.progressSlotLabel
    - Wrap slots with Semantics widget
    - File: `lib/features/studio/` (progress tracker)
    - _Requirements: 14.4_
  
  - [ ] 26.3 Add semantic labels to mini player
    - Use AccessibilityService.miniPlayerLabel
    - Add custom semantic actions for gestures
    - File: `lib/features/player/` (mini player)
    - _Requirements: 14.5, 15.1, 15.2_
  
  - [ ] 26.4 Enforce touch targets on small buttons
    - Identify all interactive elements < 48dp
    - Wrap with AccessibilityService.ensureTouchTarget
    - Test with TalkBack/VoiceOver
    - File: Various feature files
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_
  
  - [ ] 26.5 Add reduce-motion support to animations
    - Check AccessibilityService.isReduceMotionEnabled
    - Disable/simplify animations when true
    - Test with system reduce-motion enabled
    - File: Various feature files with animations
    - _Requirements: 11.1, 11.2, 11.4, 11.5, 11.6_

- [ ] 27. Update documentation
  - [ ] 27.1 Write design system README
    - Document DesignTokenRegistry API with examples
    - Document HapticsService usage patterns
    - Document GenerationRequestModel integration
    - Document AccessibilityService utilities
    - Document AnalyticsService event tracking
    - File: `lib/core/design_system/README.md`
    - _Requirements: 28.1, 28.2, 28.3, 28.4, 28.5_
  
  - [ ] 27.2 Create migration guide
    - Document steps for migrating genre/mood colors
    - Document steps for migrating haptic calls
    - Document steps for migrating generation state
    - Document steps for adding analytics
    - File: `docs/design_system_migration.md`
    - _Requirements: 28.5_
  
  - [ ] 27.3 Generate API documentation
    - Run dartdoc on design system code
    - Verify all public APIs documented
    - File: `doc/api/` (generated)
    - _Requirements: 28.1, 28.2, 28.3, 28.4_

- [ ] 28. Final integration and cleanup
  - [ ] 28.1 Remove legacy color definitions
    - Remove hardcoded genre/mood colors from codebase
    - Remove duplicated color constants
    - Verify no compilation errors
    - File: Various files
    - _Requirements: 1.5, 2.5_
  
  - [ ] 28.2 Remove duplicated state management
    - Remove local generation state variables
    - Ensure all features use GenerationRequestModel
    - File: Various feature files
    - _Requirements: 7.4_
  
  - [ ] 28.3 Update main.dart initialization
    - Override sharedPreferencesProvider with initialized instance
    - Ensure token initialization called before runApp
    - Add Firebase initialization
    - File: `lib/main.dart`
    - _Requirements: 1.1, 2.1, 9.1_
  
  - [ ] 28.4 Run full test suite
    - Run all unit tests
    - Run all widget tests
    - Run all integration tests
    - Verify 100% pass rate
    - _Requirements: 27.1, 27.2, 27.3, 27.4, 27.5_
  
  - [ ] 28.5 Generate validation report
    - Call DesignTokenRegistry.generateValidationReport()
    - Verify all tokens meet 4.5:1 contrast ratio
    - Document results for design review
    - File: `docs/design_token_validation_report.md`
    - _Requirements: 4.3, 4.4_

- [ ] 29. Final checkpoint - Design system deployment ready
  - Verify all 28 requirements covered by implementation
  - Verify all 6 major components implemented and tested
  - Verify all migrations complete
  - Verify documentation complete
  - Verify no breaking changes to existing features
  - Ready for PR and code review

## Notes

- **Optional Tasks**: Test tasks are marked optional with `*` where appropriate for faster MVP delivery. However, given this is foundational infrastructure, comprehensive testing is strongly recommended.
- **Requirement Traceability**: Each task references specific requirements from requirements.md for full traceability.
- **Migration Strategy**: Phases 22-26 handle gradual migration of existing codebase to use the design system, allowing incremental rollout.
- **Testing Priority**: Unit tests (tasks 11-16) validate core logic. Widget tests (17-18) validate Flutter integration. Integration tests (19) validate end-to-end flows. Performance tests (20) validate non-functional requirements.
- **Dependencies**: Tasks must be completed in order within each phase. For example, Phase 2 (DesignTokenRegistry) must complete before Phase 3 (token registration), which must complete before Phase 4 (theme extension).
- **Language**: All implementation is in **Dart** for Flutter, using Riverpod for state management, SharedPreferences for persistence, and Firebase Analytics for event tracking.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1", "2.2", "2.3", "2.4"] },
    { "id": 1, "tasks": ["2.5", "2.6", "3.1", "6.1"] },
    { "id": 2, "tasks": ["3.2", "4.1", "5.1", "6.2", "6.3", "7.1", "8.1"] },
    { "id": 3, "tasks": ["4.2", "5.2", "5.3", "6.4", "7.2", "7.3", "7.4", "8.2", "8.3", "8.4", "8.5", "8.6", "8.7"] },
    { "id": 4, "tasks": ["6.5", "9.1"] },
    { "id": 5, "tasks": ["9.2", "9.3"] },
    { "id": 6, "tasks": ["11.1", "11.2", "11.3", "11.4", "11.5", "12.1", "12.2", "13.1", "13.2", "13.3", "14.1", "14.2", "14.3", "14.4", "15.1", "15.2", "16.1", "16.2", "16.3", "16.4"] },
    { "id": 7, "tasks": ["17.1", "17.2", "17.3", "18.1", "18.2", "18.3"] },
    { "id": 8, "tasks": ["19.1", "19.2", "19.3"] },
    { "id": 9, "tasks": ["20.1", "20.2", "20.3", "20.4"] },
    { "id": 10, "tasks": ["22.1"] },
    { "id": 11, "tasks": ["22.2", "22.3", "22.4", "23.1", "23.2", "23.3", "24.1"] },
    { "id": 12, "tasks": ["24.2", "24.3", "24.4"] },
    { "id": 13, "tasks": ["25.1", "25.2", "25.3", "25.4", "25.5", "25.6"] },
    { "id": 14, "tasks": ["26.1", "26.2", "26.3", "26.4", "26.5"] },
    { "id": 15, "tasks": ["27.1", "27.2", "27.3"] },
    { "id": 16, "tasks": ["28.1", "28.2", "28.3"] },
    { "id": 17, "tasks": ["28.4", "28.5"] }
  ]
}
```
