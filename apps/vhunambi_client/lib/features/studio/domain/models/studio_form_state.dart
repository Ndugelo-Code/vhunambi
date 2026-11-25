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

  int get defaultBpm => switch (this) {
    TempoBracket.slow => 85,
    TempoBracket.medium => 112,
    TempoBracket.fast => 124,
    TempoBracket.veryFast => 135,
  };
}

enum VocalVoices { solo, duet, choir }

enum VocalGender { male, female, mixed }

enum VocalMode { auto, melodic, rap, spokenWord, choir }

enum VocalEnergy { soft, mid, intense }

enum SongStructure { standard, extended, freestyle, loop }

enum ProductionEra {
  modern,
  vintage90s,
  heritageOldSchool,
  futuristic2030;

  String get label => switch (this) {
    modern => 'Modern (2020s)',
    vintage90s => '90s Kwaito',
    heritageOldSchool => 'Old School Heritage',
    futuristic2030 => 'Futuristic 2030',
  };
}

/// User-facing quality/routing engine tier (`StudioGenerationContractV6`).
/// Note: `YuE2` (`CC BY-NC 4.0`) is strictly excluded.
enum StudioEngineTier {
  fastDraft,
  studioBake,
  sovereignCustom;

  String get wireValue => switch (this) {
    StudioEngineTier.fastDraft => 'fast_draft',
    StudioEngineTier.studioBake => 'studio_bake',
    StudioEngineTier.sovereignCustom => 'sovereign_custom',
  };

  String get label => switch (this) {
    StudioEngineTier.fastDraft => 'Fast Draft',
    StudioEngineTier.studioBake => 'Studio Bake',
    StudioEngineTier.sovereignCustom => 'Sovereign Custom',
  };

  String get subtitle => switch (this) {
    StudioEngineTier.fastDraft => '20-45s rapid sketch',
    StudioEngineTier.studioBake => 'Flagship full-song polish',
    StudioEngineTier.sovereignCustom => 'LoRA, Remix & Voice Clone',
  };
}

/// Conditioned reference-audio intent (`StudioGenerationContractV6`).
enum ReferenceAudioMode {
  none,
  remix,
  cover,
  reference,
  inspiration;

  String get wireValue => switch (this) {
    ReferenceAudioMode.none => 'none',
    ReferenceAudioMode.remix => 'remix',
    ReferenceAudioMode.cover => 'cover',
    ReferenceAudioMode.reference => 'reference',
    ReferenceAudioMode.inspiration => 'inspiration',
  };

  String get label => switch (this) {
    ReferenceAudioMode.none => 'None',
    ReferenceAudioMode.remix => 'Remix',
    ReferenceAudioMode.cover => 'Cover',
    ReferenceAudioMode.reference => 'Reference',
    ReferenceAudioMode.inspiration => 'Inspiration',
  };

  String get description => switch (this) {
    ReferenceAudioMode.none => 'Pure prompt & lyrics',
    ReferenceAudioMode.remix => 'Rework beat & groove',
    ReferenceAudioMode.cover => 'New vocal over melody',
    ReferenceAudioMode.reference => 'Match mix & timbre',
    ReferenceAudioMode.inspiration => 'Capture vibe & mood',
  };
}

typedef VocalConfiguration = VocalVoices;
typedef VocalIntensity = VocalEnergy;
typedef SongStructureType = SongStructure;

extension VocalVoicesLabel on VocalVoices {
  String get label => switch (this) {
    VocalVoices.solo => 'Solo',
    VocalVoices.duet => 'Duet',
    VocalVoices.choir => 'Choir',
  };
}

extension VocalGenderLabel on VocalGender {
  String get label => switch (this) {
    VocalGender.male => 'Male',
    VocalGender.female => 'Female',
    VocalGender.mixed => 'Mixed',
  };
}

extension VocalEnergyLabel on VocalEnergy {
  String get label => switch (this) {
    VocalEnergy.soft => 'Soft',
    VocalEnergy.mid => 'Mid',
    VocalEnergy.intense => 'Intense',
  };
}

extension SongStructureLabel on SongStructure {
  String get label => switch (this) {
    SongStructure.standard => 'Standard',
    SongStructure.extended => 'Extended (DJ)',
    SongStructure.freestyle => 'Freestyle',
    SongStructure.loop => 'Loop',
  };
}

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
    StemLockMode.lockedPure44k => 'Stem-Locked (Pure 44.1 kHz)',
    StemLockMode.harmonicInpaint => 'Guided AI Inpaint',
    StemLockMode.elasticResynth => 'AI Style Re-Imagine',
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
  final ProductionEra era;
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

  /// Studio Cockpit V6 production routing tier (`fast_draft`, `studio_bake`, `sovereign_custom`).
  final StudioEngineTier engineTier;

  /// How attached reference audio shapes synthesis (`remix`, `cover`, `reference`, `inspiration`).
  final ReferenceAudioMode audioMode;

  /// Number of unique-seed takes to generate in one batch (`1..4`).
  final int batchCount;

  /// Multi-select voice archetype IDs for duet / ensemble casting (`<= 6`).
  final List<String> selectedVoiceIds;

  /// Local image path when `lyricsMode == LyricsMode.fromPhoto`.
  final String? sourcePhotoPath;

  /// Uploaded R2 image URL when `lyricsMode == LyricsMode.fromPhoto`.
  final String? sourcePhotoUrl;

  /// Original song ID when seeded via 1-tap Remix (`StudioPastSongsRemixShelf`).
  final String? sourceTrackId;

  /// Optional explicit Sovereign African LoRA Pack override (`EP-P83-SOVEREIGN-LORA-CATALOG`).
  final String? selectedLoraId;

  /// Blend strength weight for [selectedLoraId] (`0.10..1.20`).
  final double selectedLoraWeight;

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
    this.era = ProductionEra.modern,
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
    this.engineTier = StudioEngineTier.studioBake,
    this.audioMode = ReferenceAudioMode.none,
    int batchCount = 1,
    this.selectedVoiceIds = const <String>[],
    this.sourcePhotoPath,
    this.sourcePhotoUrl,
    this.sourceTrackId,
    this.selectedLoraId,
    this.selectedLoraWeight = 0.85,
  }) : batchCount = batchCount < 1 ? 1 : (batchCount > 4 ? 4 : batchCount),
       branchStemLockModes =
           branchStemLockModes ??
           const {
             'node_beat_tempo': StemLockMode.lockedPure44k,
             'node_branch_beat': StemLockMode.lockedPure44k,
             'node_sketchpad_groove': StemLockMode.lockedPure44k,
             'node_branch_instruments': StemLockMode.lockedPure44k,
             'node_harmony_chords': StemLockMode.lockedPure44k,
             'node_vocal_persona': StemLockMode.harmonicInpaint,
             'node_branch_vocal': StemLockMode.harmonicInpaint,
             'node_emotion_mood': StemLockMode.harmonicInpaint,
             'node_spatial_atmosphere': StemLockMode.harmonicInpaint,
             'node_branch_sfx': StemLockMode.harmonicInpaint,
           },
       visibility = visibility ?? (isPublic == false ? 'private' : 'public');

  /// Backward-compatible getter during VH-002 migration.
  bool get isPublic => visibility == 'public';

  /// Live preview of the backend engine resolved by `compileSongSpec` (`REQ-P80-CONTRACT-02`).
  String get resolvedEnginePreview {
    if (engineTier == StudioEngineTier.fastDraft) {
      return 'ACE-Step 1.5 XL-Turbo';
    }
    final hasRefAudio =
        (referenceAudioPath != null && referenceAudioPath!.trim().isNotEmpty) ||
        audioMode != ReferenceAudioMode.none;
    if (engineTier == StudioEngineTier.sovereignCustom || hasRefAudio) {
      return 'ACE-Step 1.5 XL-Base';
    }
    if (isInstrumental || lyricsMode == LyricsMode.instrumental) {
      return 'ACE-Step 1.5 XL-SFT';
    }
    return 'MiniMax Music 3.0';
  }

  /// Attribution pill required whenever `MiniMax Music 3.0` handles flagship vocal baking.
  String? get resolvedAttributionTag =>
      resolvedEnginePreview == 'MiniMax Music 3.0' ? 'MiniMax-Music3' : null;

  VocalConfiguration get vocalConfiguration => vocalVoices;
  VocalIntensity get vocalIntensity => vocalEnergy;
  SongStructureType get structure => songStructure;

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
    ProductionEra? era,
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
    StudioEngineTier? engineTier,
    ReferenceAudioMode? audioMode,
    int? batchCount,
    List<String>? selectedVoiceIds,
    String? sourcePhotoPath,
    String? sourcePhotoUrl,
    bool clearSourcePhoto = false,
    String? sourceTrackId,
    bool clearSourceTrackId = false,
    String? selectedLoraId,
    bool clearSelectedLoraId = false,
    double? selectedLoraWeight,
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
      era: era ?? this.era,
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
      engineTier: engineTier ?? this.engineTier,
      audioMode: audioMode ?? this.audioMode,
      batchCount: batchCount ?? this.batchCount,
      selectedVoiceIds: selectedVoiceIds ?? this.selectedVoiceIds,
      sourcePhotoPath: clearSourcePhoto
          ? null
          : (sourcePhotoPath ?? this.sourcePhotoPath),
      sourcePhotoUrl: clearSourcePhoto
          ? null
          : (sourcePhotoUrl ?? this.sourcePhotoUrl),
      sourceTrackId: clearSourceTrackId
          ? null
          : (sourceTrackId ?? this.sourceTrackId),
      selectedLoraId: clearSelectedLoraId
          ? null
          : (selectedLoraId ?? this.selectedLoraId),
      selectedLoraWeight: (selectedLoraWeight ?? this.selectedLoraWeight).clamp(
        0.10,
        1.20,
      ),
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
          errorMessage == other.errorMessage &&
          engineTier == other.engineTier &&
          audioMode == other.audioMode &&
          batchCount == other.batchCount &&
          listEquals(selectedVoiceIds, other.selectedVoiceIds) &&
          sourcePhotoPath == other.sourcePhotoPath &&
          sourcePhotoUrl == other.sourcePhotoUrl &&
          sourceTrackId == other.sourceTrackId &&
          selectedLoraId == other.selectedLoraId &&
          selectedLoraWeight == other.selectedLoraWeight;

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
    engineTier,
    audioMode,
    batchCount,
    Object.hashAll(selectedVoiceIds),
    sourcePhotoPath,
    sourcePhotoUrl,
    sourceTrackId,
    selectedLoraId,
    selectedLoraWeight,
  ]);
}

/// Curated African Style LoRA Pack metadata mirrored 1:1 with Worker `lora_catalog.ts`.
@immutable
class AfricanLoraPackOption {
  final String loraId;
  final String label;
  final String region;
  final double defaultWeight;

  const AfricanLoraPackOption({
    required this.loraId,
    required this.label,
    required this.region,
    this.defaultWeight = 0.85,
  });
}

const List<AfricanLoraPackOption> kAfricanLoraPacks = <AfricanLoraPackOption>[
  AfricanLoraPackOption(
    loraId: 'amapiano_logdrum_v1',
    label: 'Amapiano Log Drum',
    region: 'Gauteng / SA',
    defaultWeight: 0.85,
  ),
  AfricanLoraPackOption(
    loraId: 'amapiano_private_school_v1',
    label: 'Private School Rhodes',
    region: 'Joburg / SA',
    defaultWeight: 0.85,
  ),
  AfricanLoraPackOption(
    loraId: 'sgija_bacardi_v1',
    label: 'Sgija & Bacardi',
    region: 'Tshwane / SA',
    defaultWeight: 0.86,
  ),
  AfricanLoraPackOption(
    loraId: 'gqom_durban_v1',
    label: 'Durban Gqom Sub',
    region: 'KZN / Durban',
    defaultWeight: 0.88,
  ),
  AfricanLoraPackOption(
    loraId: 'maskandi_picking_v1',
    label: 'Maskandi Picking',
    region: 'KZN / SA',
    defaultWeight: 0.82,
  ),
  AfricanLoraPackOption(
    loraId: 'venda_malende_v1',
    label: 'Venda Malende',
    region: 'Limpopo / Venda',
    defaultWeight: 0.85,
  ),
  AfricanLoraPackOption(
    loraId: 'afrobeats_lagos_v1',
    label: 'Lagos Afrobeats',
    region: 'West & Pan-Africa',
    defaultWeight: 0.80,
  ),
  AfricanLoraPackOption(
    loraId: 'kwaito_township_v1',
    label: 'Township Kwaito',
    region: 'Soweto / SA',
    defaultWeight: 0.82,
  ),
  AfricanLoraPackOption(
    loraId: 'afro_gospel_choir_v1',
    label: 'Afro-Gospel Choir',
    region: 'Southern Africa',
    defaultWeight: 0.84,
  ),
  AfricanLoraPackOption(
    loraId: 'afrohouse_ancestral_v1',
    label: 'Ancestral Afro House',
    region: 'Southern & East Africa',
    defaultWeight: 0.85,
  ),
];
