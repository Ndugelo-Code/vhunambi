import 'phonetic_articulation_profile.dart';
import 'pitch_contour_profile.dart';
import 'recording_quality_profile.dart';
import 'rhythmic_transient_grid.dart';
import 'sound_idealizer_recipe.dart';
import 'timbre_identity_profile.dart';

/// Provenance source of the audio intake.
enum SignatureSource {
  /// Captured live via microphone (eligible for voice identity cloning).
  live('live'),

  /// Uploaded via file picker (style/melody reference only; protected from identity cloning).
  imported('imported');

  const SignatureSource(this.wireValue);
  final String wireValue;

  static SignatureSource fromWire(String? wire) {
    if (wire == 'imported') return SignatureSource.imported;
    return SignatureSource.live;
  }
}

/// Sovereign Sound Signature DNA entity (REQ-SIG-DNA-01 / Design 2.1).
///
/// Decomposes an audio intake into 5 independent mathematical layers (Timbre, Pitch,
/// Articulation, Rhythm, Quality) plus a non-destructive [SoundIdealizerRecipe].
class SoundSignatureDna {
  const SoundSignatureDna({
    required this.id,
    required this.displayCode,
    required this.source,
    required this.createdAtIso,
    required this.durationSec,
    this.sampleRate = 44100,
    this.bpmHint = 112.0,
    required this.identity,
    required this.pitch,
    required this.articulation,
    required this.rhythm,
    required this.quality,
    this.recipe = const SoundIdealizerRecipe(),
    this.rawAudioPath,
    this.cloudEmbeddingRef,
    this.consentAtIso,
    this.schemaVersion = 1,
  });

  /// Generates a human-readable badge display code (e.g., 'VHU-SIG-9A4F') from an ID.
  static String generateDisplayCode(String id) {
    final clean = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final suffix = clean.length >= 4
        ? clean.substring(clean.length - 4)
        : clean.padLeft(4, '0');
    return 'VHU-SIG-$suffix';
  }

  /// Canonical unique identifier (e.g. ULID or UUID v4).
  final String id;

  /// Human-readable deterministic badge label (e.g. 'VHU-SIG-9A4F').
  final String displayCode;

  /// Whether captured live or imported from audio file.
  final SignatureSource source;

  /// ISO 8601 creation timestamp.
  final String createdAtIso;

  /// Duration of analyzed intake in seconds.
  final double durationSec;

  /// Master sampling rate (fixed at 44,100 Hz).
  final int sampleRate;

  /// Project or detected BPM reference.
  final double bpmHint;

  /// Layer 1: Timbre and formant resonance identity.
  final TimbreIdentityProfile identity;

  /// Layer 2: Fundamental pitch contour and scale alignment.
  final PitchContourProfile pitch;

  /// Layer 3: Consonant transients and protected phonetic frames.
  final PhoneticArticulationProfile articulation;

  /// Layer 4: Micro-timing deviations and 16-step quantized notes.
  final RhythmicTransientGrid rhythm;

  /// Layer 5: Objective input recording quality metrics.
  final RecordingQualityProfile quality;

  /// Non-destructive sculpt recipe applied during 44.1 kHz resynthesis.
  final SoundIdealizerRecipe recipe;

  /// Relative path to raw audio WAV file in local application documents directory.
  final String? rawAudioPath;

  /// Cloud speaker embedding ID if analyzed on GPU.
  final String? cloudEmbeddingRef;

  /// ISO 8601 timestamp of explicit user consent if uploaded.
  final String? consentAtIso;

  /// Schema version for binary codec evolution.
  final int schemaVersion;

  /// Whether this signature is eligible for zero-shot voice identity cloning (REQ-SIG-PRIV-04).
  bool get isEligibleForVoiceIdentity => source == SignatureSource.live;

  SoundSignatureDna copyWith({
    String? id,
    String? displayCode,
    SignatureSource? source,
    String? createdAtIso,
    double? durationSec,
    int? sampleRate,
    double? bpmHint,
    TimbreIdentityProfile? identity,
    PitchContourProfile? pitch,
    PhoneticArticulationProfile? articulation,
    RhythmicTransientGrid? rhythm,
    RecordingQualityProfile? quality,
    SoundIdealizerRecipe? recipe,
    String? rawAudioPath,
    String? cloudEmbeddingRef,
    String? consentAtIso,
    int? schemaVersion,
  }) {
    return SoundSignatureDna(
      id: id ?? this.id,
      displayCode: displayCode ?? this.displayCode,
      source: source ?? this.source,
      createdAtIso: createdAtIso ?? this.createdAtIso,
      durationSec: durationSec ?? this.durationSec,
      sampleRate: sampleRate ?? this.sampleRate,
      bpmHint: bpmHint ?? this.bpmHint,
      identity: identity ?? this.identity,
      pitch: pitch ?? this.pitch,
      articulation: articulation ?? this.articulation,
      rhythm: rhythm ?? this.rhythm,
      quality: quality ?? this.quality,
      recipe: recipe ?? this.recipe,
      rawAudioPath: rawAudioPath ?? this.rawAudioPath,
      cloudEmbeddingRef: cloudEmbeddingRef ?? this.cloudEmbeddingRef,
      consentAtIso: consentAtIso ?? this.consentAtIso,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayCode': displayCode,
    'source': source.wireValue,
    'createdAtIso': createdAtIso,
    'durationSec': durationSec,
    'sampleRate': sampleRate,
    'bpmHint': bpmHint,
    'identity': identity.toJson(),
    'pitch': pitch.toJson(),
    'articulation': articulation.toJson(),
    'rhythm': rhythm.toJson(),
    'quality': quality.toJson(),
    'recipe': recipe.toJson(),
    'rawAudioPath': rawAudioPath,
    'cloudEmbeddingRef': cloudEmbeddingRef,
    'consentAtIso': consentAtIso,
    'schemaVersion': schemaVersion,
  };

  factory SoundSignatureDna.fromJson(Map<String, dynamic> json) {
    return SoundSignatureDna(
      id: json['id'] as String,
      displayCode: json['displayCode'] as String? ?? 'VHU-SIG-0000',
      source: SignatureSource.fromWire(json['source'] as String?),
      createdAtIso: json['createdAtIso'] as String,
      durationSec: (json['durationSec'] as num).toDouble(),
      sampleRate: (json['sampleRate'] as num?)?.toInt() ?? 44100,
      bpmHint: (json['bpmHint'] as num?)?.toDouble() ?? 112.0,
      identity: TimbreIdentityProfile.fromJson(
        json['identity'] as Map<String, dynamic>? ?? const {},
      ),
      pitch: PitchContourProfile.fromJson(
        json['pitch'] as Map<String, dynamic>? ?? const {},
      ),
      articulation: PhoneticArticulationProfile.fromJson(
        json['articulation'] as Map<String, dynamic>? ?? const {},
      ),
      rhythm: RhythmicTransientGrid.fromJson(
        json['rhythm'] as Map<String, dynamic>? ?? const {},
      ),
      quality: RecordingQualityProfile.fromJson(
        json['quality'] as Map<String, dynamic>? ?? const {},
      ),
      recipe: json['recipe'] != null
          ? SoundIdealizerRecipe.fromJson(
              json['recipe'] as Map<String, dynamic>,
            )
          : const SoundIdealizerRecipe(),
      rawAudioPath: json['rawAudioPath'] as String?,
      cloudEmbeddingRef: json['cloudEmbeddingRef'] as String?,
      consentAtIso: json['consentAtIso'] as String?,
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }
}
