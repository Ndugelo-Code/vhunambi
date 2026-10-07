import 'package:flutter/foundation.dart';

/// Hardware audio focus interruption taxonomy (REQ-AUD-07).
///
/// * [pause] — the system fully suspends the app's audio focus (incoming
///   telephony call, VoIP call, Siri / voice assistant activation). Playback is
///   paused and may be auto-resumed once the interruption clears.
/// * [duck] — the system temporarily lowers playback volume (turn-by-turn
///   navigation prompts, notification alerts). The engine restores the volume
///   when focus returns; the transport is never paused.
enum AudioInterruptionType { pause, duck }

/// Immutable description of an operating system audio interruption.
/// Reference: `docs/phases/phase_09_hardware_audio_bridge/blueprint.md` §4.
@immutable
class AudioInterruptionEvent {
  /// `true` when the interruption begins, `false` when it ends.
  final bool isInterrupted;

  /// Whether the interruption suspends playback or merely ducks the volume.
  final AudioInterruptionType type;

  /// `true` when the platform permits playback to resume automatically.
  final bool shouldResume;

  const AudioInterruptionEvent({
    required this.isInterrupted,
    this.type = AudioInterruptionType.pause,
    this.shouldResume = false,
  });

  /// An interruption beginning (incoming call, assistant activation, alert).
  const AudioInterruptionEvent.begin({
    this.type = AudioInterruptionType.pause,
  })  : isInterrupted = true,
        shouldResume = false;

  /// An interruption ending. Pause interruptions may request auto-resumption.
  const AudioInterruptionEvent.end({
    this.type = AudioInterruptionType.pause,
    this.shouldResume = true,
  }) : isInterrupted = false;

  /// `true` when playback may be resumed without an explicit user gesture.
  bool get isResumable =>
      !isInterrupted &&
      shouldResume &&
      type == AudioInterruptionType.pause;

  /// `true` when the event only requires a volume duck.
  bool get isDuck => type == AudioInterruptionType.duck;

  AudioInterruptionEvent copyWith({
    bool? isInterrupted,
    AudioInterruptionType? type,
    bool? shouldResume,
  }) {
    return AudioInterruptionEvent(
      isInterrupted: isInterrupted ?? this.isInterrupted,
      type: type ?? this.type,
      shouldResume: shouldResume ?? this.shouldResume,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioInterruptionEvent &&
          runtimeType == other.runtimeType &&
          isInterrupted == other.isInterrupted &&
          type == other.type &&
          shouldResume == other.shouldResume;

  @override
  int get hashCode => Object.hash(isInterrupted, type, shouldResume);

  @override
  String toString() =>
      'AudioInterruptionEvent(isInterrupted: $isInterrupted, type: $type, '
      'shouldResume: $shouldResume)';
}

/// Emitted when the active audio route disappears — wired headphones unplugged
/// or a bluetooth peripheral disconnecting (REQ-AUD-08).
///
/// Playback MUST pause immediately and MUST NOT auto-resume: an explicit user
/// play gesture is always required afterwards.
@immutable
class BecomingNoisyEvent {
  /// Always `true` for the native event; retained so callers can choose to
  /// ignore the signal without branching on the event type.
  final bool shouldPause;

  /// Timestamp assigned by the session manager when the native event landed.
  final DateTime? occurredAt;

  const BecomingNoisyEvent({this.shouldPause = true, this.occurredAt});

  BecomingNoisyEvent copyWith({bool? shouldPause, DateTime? occurredAt}) {
    return BecomingNoisyEvent(
      shouldPause: shouldPause ?? this.shouldPause,
      occurredAt: occurredAt ?? this.occurredAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BecomingNoisyEvent &&
          runtimeType == other.runtimeType &&
          shouldPause == other.shouldPause &&
          occurredAt == other.occurredAt;

  @override
  int get hashCode => Object.hash(shouldPause, occurredAt);

  @override
  String toString() =>
      'BecomingNoisyEvent(shouldPause: $shouldPause, occurredAt: $occurredAt)';
}
