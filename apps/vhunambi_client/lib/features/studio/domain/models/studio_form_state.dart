import 'package:flutter/foundation.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/lyric_word_timestamp.dart';
import 'bantu_voice_profile.dart';

enum LyricsMode { aiWrite, myOwn, fromPhoto, instrumental }

enum TempoBracket { slow, medium, fast, veryFast }

extension TempoBracketLabel on TempoBracket {
  String get label => switch (this) {
        TempoBracket.slow => 'Slow (95-108 BPM)',
        TempoBracket.medium => 'Medium (112-115 BPM)',
        TempoBracket.fast => 'Fast (118-124 BPM)',
        TempoBracket.veryFast => 'Very Fast (128+ BPM)',
      };
}

enum VocalVoices { solo, duet, choir }

enum VocalGender { male, female, mixed }

enum VocalMode { auto, melodic, rap, spokenWord, choir }

enum VocalEnergy { soft, mid, intense }

enum SongStructure { standard, extended, freestyle, loop }

enum GenerationPhase {
  idle,
  generatingLyrics,
  reviewingLyrics,
  queued,
  processing,
  ready,
  failed,
}

/// Authority and processing mode for stems on the 3D Song Organelle (REQ-P52-STEM-01).
enum StemLockMode {
  /// Preserves the exact pre-generated/uploaded 44.1 kHz stem with ZERO AI degradation.
  /// The AI receives timing/key grid for accompaniment synthesis only.
  lockedPure44k,

  /// The AI synthesizes or inpaints this specific missing stem harmonically locked to locked stems.
  harmonicInpaint,

  /// The AI freely transforms, re-harmonizes, and re-synthesizes the input reference audio.
  elasticResynth;

  String get displayName => switch (this) {
        StemLockMode.lockedPure44k => 'Lock Pure 44.1k',
        StemLockMode.harmonicInpaint => 'Guided Inpaint',
        StemLockMode.elasticResynth => 'AI Re-Imagine',
      };

  String get fullLabel => switch (this) {
        StemLockMode.lockedPure44k => '🔒 Stem-Locked (Pure 44.1 kHz)',
        StemLockMode.harmonicInpaint => '🧬 Guided AI Inpaint',
        StemLockMode.elasticResynth => '✨ AI Style Re-Imagine',
      };
}

@immutable
class StudioFormState {
  final String prompt;
  final String? referenceAudioPath;
  final String genre;
  final String region;
  final String language;
  final bool isInstrumental;
  final int durationSeconds;
  final LyricsMode lyricsMode;
  final String? customLyrics;
  final String mood;
  final TempoBracket tempo;
  final VocalVoices vocalVoices;
  final VocalGender vocalGender;
  final VocalMode vocalMode;
  final VocalEnergy vocalEnergy;
  final SongStructure songStructure;
  final bool isAutoTitle;
  final String? customTitle;

  /// Visibility of the generated track: "public" or "private" (VH-002).
  final String visibility;
  final GenerationPhase phase;
  final double generationProgress;
  final String? errorMessage;

  /// Selected Bantu singer timbre profile for African vocal synthesis (REQ-VOX-01).
  final BantuVoiceProfile selectedVoiceProfile;

  /// Fine-grained dialect inflection shaping (vowels, vibrato, choir backing) (REQ-VOX-02).
  final DialectInflectionConfig dialectInflection;

  /// Authority and processing modes for individual stem branches (REQ-P52-STEM-01..02).
  final Map<String, StemLockMode> branchStemLockModes;

  const StudioFormState({
    this.prompt = '',
    this.referenceAudioPath,
    this.genre = 'Amapiano',
    this.region = 'South Africa',
    this.language = 'English',
    this.isInstrumental = false,
    this.durationSeconds = 30,
    this.lyricsMode = LyricsMode.aiWrite,
    this.customLyrics,
    this.mood = 'Uplifting',
    this.tempo = TempoBracket.medium,
    this.vocalVoices = VocalVoices.solo,
    this.vocalGender = VocalGender.male,
    this.vocalMode = VocalMode.auto,
    this.vocalEnergy = VocalEnergy.mid,
    this.songStructure = SongStructure.standard,
    this.isAutoTitle = true,
    this.customTitle,
    bool? isPublic,
    String? visibility,
    this.phase = GenerationPhase.idle,
    this.generationProgress = 0.0,
    this.errorMessage,
    this.selectedVoiceProfile = const BantuVoiceProfile(
      id: 'venda_folk_elder',
      name: 'Venda Folk Elder',
      language: 'Tshivenḓa',
      region: 'Limpopo / Makhado',
      timbreDescription:
          'Deep resonant chest timbre with natural dental articulation and ancestral oral storytelling cadence.',
      iconEmoji: '👴',
      loraScale: 0.90,
      characteristicAdLibs: [
        'Ndi zwone!',
        'Aa!',
        'Kha ri tshimbile!',
        'Vhukuma!',
      ],
    ),
    this.dialectInflection = const DialectInflectionConfig(),
    Map<String, StemLockMode>? branchStemLockModes,
  })  : branchStemLockModes = branchStemLockModes ??
            const {
              'node_beat_tempo': StemLockMode.lockedPure44k,
              'node_sketchpad_groove': StemLockMode.lockedPure44k,
              'node_vocal_persona': StemLockMode.harmonicInpaint,
              'node_spatial_atmosphere': StemLockMode.harmonicInpaint,
            },
        visibility = visibility ?? (isPublic == false ? 'private' : 'public');

  /// Backward-compatible getter during VH-002 migration.
  bool get isPublic => visibility == 'public';

  /// Title used for the pipeline card and the completion notification.
  ///
  /// Falls back to a deterministic excerpt of the prompt when the creator has
  /// not overridden the auto-title (REQ-LYR-08).
  String get resolvedTitle {
    final explicit = customTitle?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final words = prompt
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(4)
        .join(' ');

    if (words.isEmpty) return '$genre Sketch';
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }

  /// Compiles current wizard state into an immutable canonical [SongMetadataDna].
  SongMetadataDna toSongMetadataDna({
    String? id,
    List<LyricWordTimestamp> alignment = const [],
  }) {
    final bpm = switch (tempo) {
      TempoBracket.slow => 85,
      TempoBracket.medium => 112,
      TempoBracket.fast => 124,
      TempoBracket.veryFast => 135,
    };

    final energyStr = switch (vocalEnergy) {
      VocalEnergy.soft => 'soft',
      VocalEnergy.mid => 'mid',
      VocalEnergy.intense => 'intense',
    };

    final genderStr = switch (vocalGender) {
      VocalGender.male => 'male',
      VocalGender.female => 'female',
      VocalGender.mixed => 'duet',
    };

    final modeStr = switch (vocalMode) {
      VocalMode.auto => 'melodic',
      VocalMode.melodic => 'melodic',
      VocalMode.rap => 'rap',
      VocalMode.spokenWord => 'spokenWord',
      VocalMode.choir => 'choir',
    };

    return SongMetadataDna(
      id: id ?? 'dna_${DateTime.now().millisecondsSinceEpoch}',
      title: resolvedTitle,
      genre: genre,
      language: language,
      culturalContext: CulturalContextDna(
        region: region,
        idioms: const [],
        phoneticGuidelines: '',
      ),
      musical: MusicalDna(
        bpm: bpm,
        key: 'F# Minor',
        energyBracket: energyStr,
        durationSec: durationSeconds,
      ),
      vocals: VocalsDna(
        deliveryMode: modeStr,
        gender: genderStr,
        energy: energyStr,
        loras: [
          {
            'profileId': selectedVoiceProfile.id,
            'loraScale': selectedVoiceProfile.loraScale,
            'dialectInflection': dialectInflection.toJson(),
          },
        ],
      ),
      visualTheme: VisualThemeDna(
        mood: mood,
        comfyPrompt:
            '$genre album cover art, $mood aesthetic, cinematic studio lighting, 8k resolution, 9:16 vertical ratio',
        seed: DateTime.now().millisecondsSinceEpoch % 100000000,
        aspectRatio: '9:16',
      ),
      alignment: alignment,
    );
  }

  StudioFormState copyWith({
    String? prompt,
    String? referenceAudioPath,
    bool clearReferenceAudio = false,
    String? genre,
    String? region,
    String? language,
    bool? isInstrumental,
    int? durationSeconds,
    LyricsMode? lyricsMode,
    String? customLyrics,
    String? mood,
    TempoBracket? tempo,
    VocalVoices? vocalVoices,
    VocalGender? vocalGender,
    VocalMode? vocalMode,
    VocalEnergy? vocalEnergy,
    SongStructure? songStructure,
    bool? isAutoTitle,
    String? customTitle,
    bool? isPublic,
    String? visibility,
    GenerationPhase? phase,
    double? generationProgress,
    String? errorMessage,
    BantuVoiceProfile? selectedVoiceProfile,
    DialectInflectionConfig? dialectInflection,
    Map<String, StemLockMode>? branchStemLockModes,
  }) {
    return StudioFormState(
      prompt: prompt ?? this.prompt,
      referenceAudioPath: clearReferenceAudio
          ? null
          : (referenceAudioPath ?? this.referenceAudioPath),
      genre: genre ?? this.genre,
      region: region ?? this.region,
      language: language ?? this.language,
      isInstrumental: isInstrumental ?? this.isInstrumental,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      lyricsMode: lyricsMode ?? this.lyricsMode,
      customLyrics: customLyrics ?? this.customLyrics,
      mood: mood ?? this.mood,
      tempo: tempo ?? this.tempo,
      vocalVoices: vocalVoices ?? this.vocalVoices,
      vocalGender: vocalGender ?? this.vocalGender,
      vocalMode: vocalMode ?? this.vocalMode,
      vocalEnergy: vocalEnergy ?? this.vocalEnergy,
      songStructure: songStructure ?? this.songStructure,
      isAutoTitle: isAutoTitle ?? this.isAutoTitle,
      customTitle: customTitle ?? this.customTitle,
      visibility:
          visibility ??
          (isPublic != null
              ? (isPublic ? 'public' : 'private')
              : this.visibility),
      phase: phase ?? this.phase,
      generationProgress: generationProgress ?? this.generationProgress,
      errorMessage: errorMessage,
      selectedVoiceProfile: selectedVoiceProfile ?? this.selectedVoiceProfile,
      dialectInflection: dialectInflection ?? this.dialectInflection,
      branchStemLockModes: branchStemLockModes ?? this.branchStemLockModes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudioFormState &&
          runtimeType == other.runtimeType &&
          prompt == other.prompt &&
          referenceAudioPath == other.referenceAudioPath &&
          genre == other.genre &&
          region == other.region &&
          language == other.language &&
          isInstrumental == other.isInstrumental &&
          durationSeconds == other.durationSeconds &&
          lyricsMode == other.lyricsMode &&
          customLyrics == other.customLyrics &&
          mood == other.mood &&
          tempo == other.tempo &&
          vocalVoices == other.vocalVoices &&
          vocalGender == other.vocalGender &&
          vocalMode == other.vocalMode &&
          vocalEnergy == other.vocalEnergy &&
          songStructure == other.songStructure &&
          isAutoTitle == other.isAutoTitle &&
          customTitle == other.customTitle &&
          visibility == other.visibility &&
          phase == other.phase &&
          generationProgress == other.generationProgress &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hashAll([
    prompt,
    referenceAudioPath,
    genre,
    region,
    language,
    isInstrumental,
    durationSeconds,
    lyricsMode,
    customLyrics,
    mood,
    tempo,
    vocalVoices,
    vocalGender,
    vocalMode,
    vocalEnergy,
    songStructure,
    isAutoTitle,
    customTitle,
    visibility,
    phase,
    generationProgress,
    errorMessage,
  ]);
}
