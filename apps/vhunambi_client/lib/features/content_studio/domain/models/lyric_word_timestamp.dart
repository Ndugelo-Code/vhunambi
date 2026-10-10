import 'package:flutter/foundation.dart';

/// Represents a single word and its synchronized start/end timestamps
/// in seconds within the audio track.
@immutable
class LyricWordTimestamp {
  final String word;
  final double start;
  final double end;
  final int stanzaIndex;

  const LyricWordTimestamp({
    required this.word,
    required this.start,
    required this.end,
    this.stanzaIndex = 0,
  });

  Map<String, dynamic> toJson() => {
        'word': word,
        'start': start,
        'end': end,
        'stanzaIndex': stanzaIndex,
      };

  factory LyricWordTimestamp.fromJson(Map<String, dynamic> json) =>
      LyricWordTimestamp(
        word: json['word'] as String? ?? '',
        start: (json['start'] as num?)?.toDouble() ?? 0.0,
        end: (json['end'] as num?)?.toDouble() ?? 0.0,
        stanzaIndex: json['stanzaIndex'] as int? ?? 0,
      );

  LyricWordTimestamp copyWith({
    String? word,
    double? start,
    double? end,
    int? stanzaIndex,
  }) =>
      LyricWordTimestamp(
        word: word ?? this.word,
        start: start ?? this.start,
        end: end ?? this.end,
        stanzaIndex: stanzaIndex ?? this.stanzaIndex,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricWordTimestamp &&
          runtimeType == other.runtimeType &&
          word == other.word &&
          start == other.start &&
          end == other.end &&
          stanzaIndex == other.stanzaIndex;

  @override
  int get hashCode => Object.hash(word, start, end, stanzaIndex);
}
