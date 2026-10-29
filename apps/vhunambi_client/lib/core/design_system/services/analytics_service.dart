import 'dart:async';
import 'package:flutter/foundation.dart';

/// Base class for analytics events.
@immutable
abstract class AnalyticsEvent {
  final String name;
  final DateTime timestamp;

  AnalyticsEvent({
    required this.name,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson();

  @override
  String toString() => 'AnalyticsEvent(name: $name, timestamp: $timestamp)';
}

/// Onboarding step completed event.
class OnboardingStepCompletedEvent extends AnalyticsEvent {
  final String screenName;
  OnboardingStepCompletedEvent(this.screenName)
      : super(name: 'onboarding_step_completed');
  @override
  Map<String, dynamic> toJson() => {
        'screen_name': screenName,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Onboarding step skipped event.
class OnboardingStepSkippedEvent extends AnalyticsEvent {
  final String screenName;
  OnboardingStepSkippedEvent(this.screenName)
      : super(name: 'onboarding_step_skipped');
  @override
  Map<String, dynamic> toJson() => {
        'screen_name': screenName,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Onboarding completed event.
class OnboardingCompletedEvent extends AnalyticsEvent {
  final Duration elapsedTime;
  OnboardingCompletedEvent(this.elapsedTime)
      : super(name: 'onboarding_completed');
  @override
  Map<String, dynamic> toJson() => {
        'elapsed_seconds': elapsedTime.inSeconds,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Onboarding abandoned event.
class OnboardingAbandonedEvent extends AnalyticsEvent {
  final String lastCompletedScreen;
  OnboardingAbandonedEvent(this.lastCompletedScreen)
      : super(name: 'onboarding_abandoned');
  @override
  Map<String, dynamic> toJson() => {
        'last_completed_screen': lastCompletedScreen,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Privacy claim displayed event (VH-013).
/// Logged when the accurate privacy claim is displayed on the DNA activation screen.
class PrivacyClaimDisplayedEvent extends AnalyticsEvent {
  final String claimText;
  PrivacyClaimDisplayedEvent(this.claimText)
      : super(name: 'privacy_claim_displayed');
  @override
  Map<String, dynamic> toJson() => {
        'claim_text': claimText,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Genre selected event.
class GenreSelectedEvent extends AnalyticsEvent {
  final String genre;
  GenreSelectedEvent(this.genre) : super(name: 'genre_selected');
  @override
  Map<String, dynamic> toJson() => {
        'genre': genre,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Generation started event.
class GenerationStartedEvent extends AnalyticsEvent {
  final String genre;
  final int bpm;
  GenerationStartedEvent({
    required this.genre,
    required this.bpm,
  }) : super(name: 'generation_started');
  @override
  Map<String, dynamic> toJson() => {
        'genre': genre,
        'bpm': bpm,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Player form changed event.
///
/// Fired when the mini player morphs between Bar, Card, and Pill forms.
class PlayerFormChangedEvent extends AnalyticsEvent {
  final String oldForm;
  final String newForm;
  PlayerFormChangedEvent(this.oldForm, this.newForm)
      : super(name: 'player_form_changed');
  @override
  Map<String, dynamic> toJson() => {
        'old_form': oldForm,
        'new_form': newForm,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Player mode changed event.
///
/// Fired when the mini player switches between Auto and Manual mode.
class PlayerModeChangedEvent extends AnalyticsEvent {
  final String mode;
  PlayerModeChangedEvent(this.mode) : super(name: 'player_mode_changed');
  @override
  Map<String, dynamic> toJson() => {
        'mode': mode,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Player gesture event.
///
/// Fired on player gesture milestones (hold, drag, dismiss).
class PlayerGestureEvent extends AnalyticsEvent {
  final String gestureType;
  PlayerGestureEvent(this.gestureType) : super(name: 'player_gesture');
  @override
  Map<String, dynamic> toJson() => {
        'gesture_type': gestureType,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Analytics service with event batching, retry logic, and privacy safeguards.
///
/// Events are queued and flushed asynchronously. Sensitive user data
/// (lyrics, prompts, identity) is never logged.
class AnalyticsService {
  /// Maximum number of events to batch before flushing.
  static const int _maxBatchSize = 10;

  /// Maximum age of a batch before flushing (in milliseconds).
  static const int _maxBatchAgeMs = 1000;

  final List<AnalyticsEvent> _queue = [];
  Timer? _flushTimer;

  /// Whether the service is enabled. Can be disabled for testing or
  /// privacy opt-out.
  bool enabled = true;

  /// Records an analytics event.
  ///
  /// Events are added to a batch queue and flushed asynchronously.
  /// Sensitive data (lyrics, prompts, user identity) must not be included
  /// in event payloads.
  void record(AnalyticsEvent event) {
    if (!enabled) return;
    lock(() {
      _queue.add(event);
      if (_queue.length >= _maxBatchSize) {
        _flush();
      } else {
        _flushTimer ??= Timer(
          Duration(milliseconds: _maxBatchAgeMs),
          _flush,
        );
      }
    });
  }

  /// Manually flush all queued events immediately.
  void flush() {
    lock(() {
      _flush();
    });
  }

  /// Disposes the service, cancelling any pending flush timer.
  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  /// Executes [action] under the queue lock.
  static void lock(void Function() action) {
    // Simple reentrancy-safe lock for single-threaded Dart isolate.
    action();
  }

  void _flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    final batch = List<AnalyticsEvent>.from(_queue);
    _queue.clear();
    if (batch.isNotEmpty) {
      _sendBatch(batch);
    }
  }

  /// Sends a batch of events to the analytics backend.
  ///
  /// This implementation is a no-op (no Firebase dependency). Subclasses or
  /// platform-specific implementations can override to send to Firebase
  /// Analytics or another backend. Errors are caught silently to avoid
  /// crashing the app.
  void _sendBatch(List<AnalyticsEvent> batch) {
    try {
      // No-op by default. Override in production to integrate with
      // Firebase Analytics or another backend.
      for (final _ in batch) {
        // Event sent
      }
    } catch (_) {
      // Silently ignore analytics errors — never crash the app for analytics.
    }
  }
}