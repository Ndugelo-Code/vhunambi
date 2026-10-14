import 'package:flutter/foundation.dart';

/// Categories of implicit and explicit user behaviors that update Creator DNA weights.
enum BehaviorEventType {
  trackPlay,
  trackLike,
  trackSkip,
  generationSubmit,
  genreFilterTap,
  exploreScrollDepth,
  trackShare,
}

/// A structured telemetry event recording an interaction with musical content.
@immutable
class BehaviorEvent {
  final BehaviorEventType type;
  final DateTime timestamp;
  final Map<String, dynamic> payload;

  const BehaviorEvent({
    required this.type,
    required this.timestamp,
    required this.payload,
  });

  factory BehaviorEvent.trackPlay({
    required String trackId,
    String? genreHint,
    String? languageHint,
    required int listenRatioPercent,
  }) =>
      BehaviorEvent(
        type: BehaviorEventType.trackPlay,
        timestamp: DateTime.now(),
        payload: {
          'trackId': trackId,
          'genreHint': ?genreHint,
          'languageHint': ?languageHint,
          'listenRatioPercent': listenRatioPercent,
        },
      );

  factory BehaviorEvent.trackLike({
    required String trackId,
    String? genreHint,
    String? languageHint,
    String? moodHint,
  }) =>
      BehaviorEvent(
        type: BehaviorEventType.trackLike,
        timestamp: DateTime.now(),
        payload: {
          'trackId': trackId,
          'genreHint': ?genreHint,
          'languageHint': ?languageHint,
          'moodHint': ?moodHint,
        },
      );

  factory BehaviorEvent.trackSkip({
    required String trackId,
    String? genreHint,
    required int secondsBeforeSkip,
  }) =>
      BehaviorEvent(
        type: BehaviorEventType.trackSkip,
        timestamp: DateTime.now(),
        payload: {
          'trackId': trackId,
          'genreHint': ?genreHint,
          'secondsBeforeSkip': secondsBeforeSkip,
        },
      );

  factory BehaviorEvent.generationSubmit({
    required String genre,
    required String language,
    String? tempo,
    String? vocalEnergy,
    String? mood,
  }) =>
      BehaviorEvent(
        type: BehaviorEventType.generationSubmit,
        timestamp: DateTime.now(),
        payload: {
          'genre': genre,
          'language': language,
          'tempo': ?tempo,
          'vocalEnergy': ?vocalEnergy,
          'mood': ?mood,
        },
      );

  factory BehaviorEvent.genreFilterTap(String genre) => BehaviorEvent(
        type: BehaviorEventType.genreFilterTap,
        timestamp: DateTime.now(),
        payload: {'genre': genre},
      );

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        'payload': payload,
      };

  factory BehaviorEvent.fromJson(Map<String, dynamic> json) {
    return BehaviorEvent(
      type: BehaviorEventType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => BehaviorEventType.trackPlay,
      ),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BehaviorEvent &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          timestamp == other.timestamp &&
          mapEquals(payload, other.payload);

  @override
  int get hashCode => Object.hash(type, timestamp, payload);
}
