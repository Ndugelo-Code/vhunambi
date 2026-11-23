import 'package:vhunambi_client/core/utils/json_safe.dart';

/// A contiguous time span in milliseconds for protected acoustic frames.
class TimeSpanMs {
  const TimeSpanMs(this.startMs, this.endMs);

  final int startMs;
  final int endMs;

  int get durationMs => endMs - startMs;

  Map<String, dynamic> toJson() => {
        'startMs': startMs,
        'endMs': endMs,
      };

  factory TimeSpanMs.fromJson(Map<String, dynamic> json) => TimeSpanMs(
        JsonSafe.asInt(json['startMs']),
        JsonSafe.asInt(json['endMs']),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSpanMs &&
          other.startMs == startMs &&
          other.endMs == endMs;

  @override
  int get hashCode => Object.hash(startMs, endMs);
}

/// Articulation layer of SoundSignatureDna (REQ-SIG-DNA-01 / Design 2.1).
///
/// Encapsulates consonant attack transient sharpness and maps unvoiced/transient
/// segments (e.g. Bantu plosives ḓ, ṱ, ṋ, ḽ and Nguni clicks c, q, x) that are
/// protected from pitch-shifting to guarantee clarity by construction.
class PhoneticArticulationProfile {
  const PhoneticArticulationProfile({
    required this.consonantTransientSharpness,
    required this.protectedSegments,
  });

  /// Normalized consonant attack transient sharpness (0.0 .. 1.0).
  final double consonantTransientSharpness;

  /// Time segments that must bypass pitch-shifting during TD-PSOLA resynthesis.
  final List<TimeSpanMs> protectedSegments;

  PhoneticArticulationProfile copyWith({
    double? consonantTransientSharpness,
    List<TimeSpanMs>? protectedSegments,
  }) {
    return PhoneticArticulationProfile(
      consonantTransientSharpness:
          consonantTransientSharpness ?? this.consonantTransientSharpness,
      protectedSegments: protectedSegments ?? this.protectedSegments,
    );
  }

  Map<String, dynamic> toJson() => {
        'consonantTransientSharpness': consonantTransientSharpness,
        'protectedSegments': protectedSegments.map((s) => s.toJson()).toList(),
      };

  factory PhoneticArticulationProfile.fromJson(Map<String, dynamic> json) {
    return PhoneticArticulationProfile(
      consonantTransientSharpness: JsonSafe.asDouble(
        json['consonantTransientSharpness'],
        0.85,
      ),
      protectedSegments: JsonSafe.asList(json['protectedSegments'])
          .map((s) => TimeSpanMs.fromJson(JsonSafe.asMap(s)))
          .toList(),
    );
  }
}

