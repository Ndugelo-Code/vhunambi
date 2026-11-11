import 'package:flutter/foundation.dart';
import '../../../mastering/domain/models/stem_mastering_recipe.dart';

/// Gender classification for regional African voice archetypes.
enum VocalGender {
  female('Female', 'female'),
  male('Male', 'male'),
  duet('Duet / Choir', 'duet');

  const VocalGender(this.label, this.apiValue);
  final String label;
  final String apiValue;

  static VocalGender fromApi(String value) {
    return VocalGender.values.firstWhere(
      (e) => e.apiValue == value || e.name == value,
      orElse: () => VocalGender.female,
    );
  }
}

/// Regional grouping across Africa & the Diaspora (REQ-VOC-01).
enum AfricanVoiceRegion {
  southernAfrica('Southern Africa', 'southern_africa'),
  westAfrica('West Africa', 'west_africa'),
  eastAfrica('East Africa', 'east_africa'),
  centralAfrica('Central Africa', 'central_africa'),
  diaspora('Diaspora', 'diaspora');

  const AfricanVoiceRegion(this.label, this.apiValue);
  final String label;
  final String apiValue;

  static AfricanVoiceRegion fromApi(String value) {
    return AfricanVoiceRegion.values.firstWhere(
      (e) => e.apiValue == value || e.name == value,
      orElse: () => AfricanVoiceRegion.southernAfrica,
    );
  }
}

/// Vocal delivery style for synthesis conditioning and timbre selection (REQ-VOC-02).
enum VocalDeliveryStyle {
  amapianoChant('Amapiano Chant', 'amapiano_chant'),
  melodicSoul('Melodic Soul', 'melodic_soul'),
  maskandiPraise('Maskandi Praise', 'maskandi_praise'),
  afrobeatsPidgin('Afrobeats Pidgin', 'afrobeats_pidgin'),
  gqomMc('Gqom MC', 'gqom_mc'),
  choirHarmony('Choir Harmony', 'choir_harmony');

  const VocalDeliveryStyle(this.label, this.apiValue);
  final String label;
  final String apiValue;

  /// Canonical aliases for IDE LSP compatibility.
  static const VocalDeliveryStyle afroSoulMelodic =
      VocalDeliveryStyle.melodicSoul;
  static const VocalDeliveryStyle gqomHype = VocalDeliveryStyle.gqomMc;
  static const VocalDeliveryStyle afrobeatsBounce =
      VocalDeliveryStyle.afrobeatsPidgin;
  static const VocalDeliveryStyle zionChoir = VocalDeliveryStyle.choirHarmony;

  static VocalDeliveryStyle fromApi(String value) {
    return VocalDeliveryStyle.values.firstWhere(
      (e) => e.apiValue == value || e.name == value,
      orElse: () => VocalDeliveryStyle.melodicSoul,
    );
  }
}

/// Sovereign Regional African Voice Archetype in the 24-voice catalog (REQ-VOC-01, REQ-VOC-02).
@immutable
class RegionalVoiceArchetype {
  const RegionalVoiceArchetype({
    required this.id,
    required this.name,
    required this.region,
    required this.gender,
    required this.deliveryStyle,
    required this.nativeLanguage,
    required this.accentDescription,
    required this.vocalRange,
    required this.loraScale,
    required this.formantShiftSemitones,
    required this.recommendedCleanseFlavor,
    required this.samplePreviewUrl,
  });

  final String id;
  final String name;
  final AfricanVoiceRegion region;
  final VocalGender gender;
  final VocalDeliveryStyle deliveryStyle;
  final String nativeLanguage;
  final String accentDescription;
  final String vocalRange;
  final double loraScale;
  final double formantShiftSemitones;
  final VocalCleanseFlavor recommendedCleanseFlavor;
  final String samplePreviewUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'region': region.apiValue,
        'gender': gender.apiValue,
        'deliveryStyle': deliveryStyle.apiValue,
        'nativeLanguage': nativeLanguage,
        'accentDescription': accentDescription,
        'vocalRange': vocalRange,
        'loraScale': loraScale,
        'formantShiftSemitones': formantShiftSemitones,
        'recommendedCleanseFlavor': recommendedCleanseFlavor.wireValue,
        'samplePreviewUrl': samplePreviewUrl,
      };
}

/// A single phonetically scored lyric line extracted from the user's lyrics (REQ-VOC-04).
@immutable
class PhoneticCalibrationLine {
  const PhoneticCalibrationLine({
    required this.lineIndex,
    required this.text,
    required this.phoneticScore,
    required this.highlightedTokens,
    required this.estimatedDurationSec,
  });

  final int lineIndex;
  final String text;
  final double phoneticScore;
  final List<String> highlightedTokens;
  final int estimatedDurationSec;

  Map<String, dynamic> toJson() => {
        'lineIndex': lineIndex,
        'text': text,
        'phoneticScore': phoneticScore,
        'highlightedTokens': highlightedTokens,
        'estimatedDurationSec': estimatedDurationSec,
      };
}

/// Complete 3-line calibration script for the 15-20s post-lyrics voice note recorder (REQ-VOC-05).
@immutable
class PhoneticCalibrationScript {
  const PhoneticCalibrationScript({
    required this.language,
    required this.lines,
    required this.totalEstimatedDurationSec,
  });

  final String language;
  final List<PhoneticCalibrationLine> lines;
  final int totalEstimatedDurationSec;
}

/// Zero-Shot Cloned Voice Profile capturing the creator's timbre & Bantu pronunciation (REQ-VOC-08).
@immutable
class CreatorVoiceCloneProfile {
  const CreatorVoiceCloneProfile({
    required this.id,
    required this.creatorName,
    required this.nativeLanguage,
    required this.calibrationLines,
    required this.timbreEmbeddingPreview,
    required this.phonemeCadenceMap,
    required this.cadenceWpm,
    required this.clarityScore,
    required this.recordingDurationSec,
    required this.createdAtIso,
    this.r2ReferenceUrl,
    this.signatureId,
    this.recommendedCleanseFlavor = VocalCleanseFlavor.studioClean,
  });

  final String id;
  final String creatorName;
  final String nativeLanguage;
  final List<String> calibrationLines;
  final List<double> timbreEmbeddingPreview;
  final Map<String, double> phonemeCadenceMap;
  final int cadenceWpm;
  final double clarityScore;
  final double recordingDurationSec;
  final String createdAtIso;
  final String? r2ReferenceUrl;

  /// Phase 35: Link to immutable local SoundSignatureDna entity (REQ-SIG-DNA-05).
  final String? signatureId;
  final VocalCleanseFlavor recommendedCleanseFlavor;

  CreatorVoiceCloneProfile copyWith({
    String? id,
    String? creatorName,
    String? nativeLanguage,
    List<String>? calibrationLines,
    List<double>? timbreEmbeddingPreview,
    Map<String, double>? phonemeCadenceMap,
    int? cadenceWpm,
    double? clarityScore,
    double? recordingDurationSec,
    String? createdAtIso,
    String? r2ReferenceUrl,
    String? signatureId,
    VocalCleanseFlavor? recommendedCleanseFlavor,
  }) {
    return CreatorVoiceCloneProfile(
      id: id ?? this.id,
      creatorName: creatorName ?? this.creatorName,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      calibrationLines: calibrationLines ?? this.calibrationLines,
      timbreEmbeddingPreview:
          timbreEmbeddingPreview ?? this.timbreEmbeddingPreview,
      phonemeCadenceMap: phonemeCadenceMap ?? this.phonemeCadenceMap,
      cadenceWpm: cadenceWpm ?? this.cadenceWpm,
      clarityScore: clarityScore ?? this.clarityScore,
      recordingDurationSec: recordingDurationSec ?? this.recordingDurationSec,
      createdAtIso: createdAtIso ?? this.createdAtIso,
      r2ReferenceUrl: r2ReferenceUrl ?? this.r2ReferenceUrl,
      signatureId: signatureId ?? this.signatureId,
      recommendedCleanseFlavor:
          recommendedCleanseFlavor ?? this.recommendedCleanseFlavor,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'creatorName': creatorName,
        'nativeLanguage': nativeLanguage,
        'calibrationLines': calibrationLines,
        'timbreEmbeddingPreview': timbreEmbeddingPreview,
        'phonemeCadenceMap': phonemeCadenceMap,
        'cadenceWpm': cadenceWpm,
        'clarityScore': clarityScore,
        'recordingDurationSec': recordingDurationSec,
        'createdAtIso': createdAtIso,
        'r2ReferenceUrl': r2ReferenceUrl,
        'signatureId': signatureId,
        'recommendedCleanseFlavor': recommendedCleanseFlavor.wireValue,
      };

  factory CreatorVoiceCloneProfile.fromJson(Map<String, dynamic> json) {
    final rawLines = (json['calibrationLines'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    final rawEmbedding =
        (json['timbreEmbeddingPreview'] as List<dynamic>? ?? const [])
            .map((e) => (e as num).toDouble())
            .toList();
    final rawCadence =
        (json['phonemeCadenceMap'] as Map<String, dynamic>? ?? const {}).map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );

    return CreatorVoiceCloneProfile(
      id: (json['id'] as String?) ?? 'vclone_default',
      creatorName: (json['creatorName'] as String?) ?? 'My Studio Voice',
      nativeLanguage: (json['nativeLanguage'] as String?) ?? 'Tshivenḓa',
      calibrationLines: rawLines,
      timbreEmbeddingPreview: rawEmbedding,
      phonemeCadenceMap: rawCadence,
      cadenceWpm: (json['cadenceWpm'] as num?)?.toInt() ?? 112,
      clarityScore: (json['clarityScore'] as num?)?.toDouble() ?? 0.94,
      recordingDurationSec:
          (json['recordingDurationSec'] as num?)?.toDouble() ?? 18.0,
      createdAtIso:
          (json['createdAtIso'] as String?) ?? DateTime.now().toIso8601String(),
      r2ReferenceUrl: json['r2ReferenceUrl'] as String?,
      signatureId: json['signatureId'] as String?,
      recommendedCleanseFlavor: VocalCleanseFlavor.fromWire(
        (json['recommendedCleanseFlavor'] as String?) ?? 'studio_clean',
      ),
    );
  }
}

/// Seeded 24 Sovereign Regional African Voice Archetypes matching `/v1/voices/catalog` (REQ-VOC-01..03).
const List<RegionalVoiceArchetype> kRegionalVoiceCatalog = [
  RegionalVoiceArchetype(
    id: 'vox_venda_royal_alto',
    name: 'Makhado Royal Alto',
    region: AfricanVoiceRegion.southernAfrica,
    gender: VocalGender.female,
    deliveryStyle: VocalDeliveryStyle.melodicSoul,
    nativeLanguage: 'Tshivenḓa',
    accentDescription:
        'Warm Vhembe valley alto with crisp dental plosives (ḓ, ṱ, ṋ, ḽ) and velvet vibrato',
    vocalRange: 'F3 – D5',
    loraScale: 0.92,
    formantShiftSemitones: -0.2,
    recommendedCleanseFlavor: VocalCleanseFlavor.warmIntimate,
    samplePreviewUrl: '/mock-storage/vox_venda_royal_alto.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_thohoyandou_log_chant',
    name: 'Thohoyandou Night Chanter',
    region: AfricanVoiceRegion.southernAfrica,
    gender: VocalGender.male,
    deliveryStyle: VocalDeliveryStyle.amapianoChant,
    nativeLanguage: 'Tshivenḓa',
    accentDescription:
        'Percussive Tshivenḓa baritone chant tailored for 113 BPM log-drum call-and-response',
    vocalRange: 'G2 – E4',
    loraScale: 0.95,
    formantShiftSemitones: -0.6,
    recommendedCleanseFlavor: VocalCleanseFlavor.studioClean,
    samplePreviewUrl: '/mock-storage/vox_thohoyandou_log_chant.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_soweto_soul_soprano',
    name: 'Soweto Golden Hour Soprano',
    region: AfricanVoiceRegion.southernAfrica,
    gender: VocalGender.female,
    deliveryStyle: VocalDeliveryStyle.melodicSoul,
    nativeLanguage: 'isiZulu',
    accentDescription:
        'Silky Private School Amapiano soprano with breathy falsetto runs and clean Nguni clicks',
    vocalRange: 'A3 – G5',
    loraScale: 0.90,
    formantShiftSemitones: 0.3,
    recommendedCleanseFlavor: VocalCleanseFlavor.wideAnthem,
    samplePreviewUrl: '/mock-storage/vox_soweto_soul_soprano.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_kzn_maskandi_induna',
    name: 'uThukela Maskandi Induna',
    region: AfricanVoiceRegion.southernAfrica,
    gender: VocalGender.male,
    deliveryStyle: VocalDeliveryStyle.maskandiPraise,
    nativeLanguage: 'isiZulu',
    accentDescription:
        'Commanding KwaZulu-Natal tenor with rapid izibongo praise articulation and chest resonance',
    vocalRange: 'A2 – F4',
    loraScale: 0.96,
    formantShiftSemitones: -0.4,
    recommendedCleanseFlavor: VocalCleanseFlavor.studioClean,
    samplePreviewUrl: '/mock-storage/vox_kzn_maskandi_induna.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_durban_gqom_general',
    name: 'eThekwini Warehouse MC',
    region: AfricanVoiceRegion.southernAfrica,
    gender: VocalGender.male,
    deliveryStyle: VocalDeliveryStyle.gqomMc,
    nativeLanguage: 'isiZulu',
    accentDescription:
        'High-voltage Durban Gqom hype vocalist with sharp transient attack and rhythmic grit',
    vocalRange: 'F2 – D4',
    loraScale: 0.94,
    formantShiftSemitones: -0.8,
    recommendedCleanseFlavor: VocalCleanseFlavor.studioClean,
    samplePreviewUrl: '/mock-storage/vox_durban_gqom_general.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_eastern_cape_click_queen',
    name: 'Mthatha Neo-Soul Queen',
    region: AfricanVoiceRegion.southernAfrica,
    gender: VocalGender.female,
    deliveryStyle: VocalDeliveryStyle.melodicSoul,
    nativeLanguage: 'isiXhosa',
    accentDescription:
        'Expressive Eastern Cape vocalist with effortless alveolar/palatal click clarity (c, q, x)',
    vocalRange: 'G3 – F5',
    loraScale: 0.91,
    formantShiftSemitones: 0.1,
    recommendedCleanseFlavor: VocalCleanseFlavor.warmIntimate,
    samplePreviewUrl: '/mock-storage/vox_eastern_cape_click_queen.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_polokwane_lekompo_star',
    name: 'Polokwane Lekompo Crooner',
    region: AfricanVoiceRegion.southernAfrica,
    gender: VocalGender.male,
    deliveryStyle: VocalDeliveryStyle.amapianoChant,
    nativeLanguage: 'Sepedi',
    accentDescription:
        'Bouncy Limpopo Bolo/Lekompo tenor with rolled trills and infectious township swagger',
    vocalRange: 'B2 – G4',
    loraScale: 0.89,
    formantShiftSemitones: 0.0,
    recommendedCleanseFlavor: VocalCleanseFlavor.studioClean,
    samplePreviewUrl: '/mock-storage/vox_polokwane_lekompo_star.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_giyani_xibelani_soprano',
    name: 'Giyani Electric Soprano',
    region: AfricanVoiceRegion.southernAfrica,
    gender: VocalGender.female,
    deliveryStyle: VocalDeliveryStyle.amapianoChant,
    nativeLanguage: 'Xitsonga',
    accentDescription:
        'Bright, high-energy Xitsonga soprano cutting cleanly above fast marimba & synth stabs',
    vocalRange: 'B3 – A5',
    loraScale: 0.93,
    formantShiftSemitones: 0.5,
    recommendedCleanseFlavor: VocalCleanseFlavor.wideAnthem,
    samplePreviewUrl: '/mock-storage/vox_giyani_xibelani_soprano.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_mafikeng_motswako_poet',
    name: 'Mahikeng Jazz-Piano Baritone',
    region: AfricanVoiceRegion.southernAfrica,
    gender: VocalGender.male,
    deliveryStyle: VocalDeliveryStyle.melodicSoul,
    nativeLanguage: 'Setswana',
    accentDescription:
        'Laid-back Setswana conversational croon built for Rhodes-heavy Private School chords',
    vocalRange: 'G2 – E4',
    loraScale: 0.88,
    formantShiftSemitones: -0.3,
    recommendedCleanseFlavor: VocalCleanseFlavor.warmIntimate,
    samplePreviewUrl: '/mock-storage/vox_mafikeng_motswako_poet.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_maluti_mountain_tenor',
    name: 'Maluti Highland Tenor',
    region: AfricanVoiceRegion.southernAfrica,
    gender: VocalGender.male,
    deliveryStyle: VocalDeliveryStyle.maskandiPraise,
    nativeLanguage: 'Sesotho',
    accentDescription:
        'Soaring Lesotho-style acoustic tenor with rich harmonic overtones and poetic cadence',
    vocalRange: 'A2 – G4',
    loraScale: 0.91,
    formantShiftSemitones: 0.1,
    recommendedCleanseFlavor: VocalCleanseFlavor.warmIntimate,
    samplePreviewUrl: '/mock-storage/vox_maluti_mountain_tenor.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_pretoria_bacardi_duo',
    name: 'Tshwane Bacardi Duo',
    region: AfricanVoiceRegion.southernAfrica,
    gender: VocalGender.duet,
    deliveryStyle: VocalDeliveryStyle.amapianoChant,
    nativeLanguage: 'Sepedi / Pitori Slang',
    accentDescription:
        'Synchronized Pretoria male-female call-and-response chant with octave-doubled hooks',
    vocalRange: 'G2 – F5',
    loraScale: 0.95,
    formantShiftSemitones: 0.0,
    recommendedCleanseFlavor: VocalCleanseFlavor.wideAnthem,
    samplePreviewUrl: '/mock-storage/vox_pretoria_bacardi_duo.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_harare_mbira_velvet',
    name: 'Harare Mbira Soul',
    region: AfricanVoiceRegion.southernAfrica,
    gender: VocalGender.female,
    deliveryStyle: VocalDeliveryStyle.melodicSoul,
    nativeLanguage: 'ChiShona',
    accentDescription:
        'Crystalline Zimbabwean Shona vocal with interlocking melodic phrasing and warm air',
    vocalRange: 'G3 – E5',
    loraScale: 0.90,
    formantShiftSemitones: 0.2,
    recommendedCleanseFlavor: VocalCleanseFlavor.warmIntimate,
    samplePreviewUrl: '/mock-storage/vox_harare_mbira_velvet.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_mzansi_zion_gospel_choir',
    name: 'Mzansi Cathedral Ensemble',
    region: AfricanVoiceRegion.southernAfrica,
    gender: VocalGender.duet,
    deliveryStyle: VocalDeliveryStyle.choirHarmony,
    nativeLanguage: 'isiZulu / Tshivenḓa',
    accentDescription:
        '4-part Southern African gospel & Afro-tech choir stack with lush stereo width',
    vocalRange: 'F2 – G5',
    loraScale: 0.97,
    formantShiftSemitones: 0.0,
    recommendedCleanseFlavor: VocalCleanseFlavor.wideAnthem,
    samplePreviewUrl: '/mock-storage/vox_mzansi_zion_gospel_choir.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_mbabane_swati_silk',
    name: 'Ezulwini Valley Contralto',
    region: AfricanVoiceRegion.southernAfrica,
    gender: VocalGender.female,
    deliveryStyle: VocalDeliveryStyle.melodicSoul,
    nativeLanguage: 'siSwati',
    accentDescription:
        'Deep, velvety siSwati contralto with intimate chest-voice warmth and smooth glides',
    vocalRange: 'E3 – C5',
    loraScale: 0.89,
    formantShiftSemitones: -0.4,
    recommendedCleanseFlavor: VocalCleanseFlavor.warmIntimate,
    samplePreviewUrl: '/mock-storage/vox_mbabane_swati_silk.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_lagos_island_cruiser',
    name: 'Lagos Island Afro-Fusion',
    region: AfricanVoiceRegion.westAfrica,
    gender: VocalGender.male,
    deliveryStyle: VocalDeliveryStyle.afrobeatsPidgin,
    nativeLanguage: 'Yoruba / Naija Pidgin',
    accentDescription:
        'Smoky Lagos baritone-tenor with effortless Yoruba-Pidgin bounce and melodic vibrato',
    vocalRange: 'A2 – F4',
    loraScale: 0.93,
    formantShiftSemitones: -0.2,
    recommendedCleanseFlavor: VocalCleanseFlavor.studioClean,
    samplePreviewUrl: '/mock-storage/vox_lagos_island_cruiser.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_lekki_alt_siren',
    name: 'Lekki Alté Siren',
    region: AfricanVoiceRegion.westAfrica,
    gender: VocalGender.female,
    deliveryStyle: VocalDeliveryStyle.afrobeatsPidgin,
    nativeLanguage: 'Naija Pidgin / English',
    accentDescription:
        'Airy, hypnotic West African Alté mezzo-soprano with featherlight phrasing and lush doubles',
    vocalRange: 'A3 – F5',
    loraScale: 0.91,
    formantShiftSemitones: 0.3,
    recommendedCleanseFlavor: VocalCleanseFlavor.wideAnthem,
    samplePreviewUrl: '/mock-storage/vox_lekki_alt_siren.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_accra_highlife_gold',
    name: 'Osu Highlife Crooner',
    region: AfricanVoiceRegion.westAfrica,
    gender: VocalGender.male,
    deliveryStyle: VocalDeliveryStyle.afrobeatsPidgin,
    nativeLanguage: 'Twi / Ghanaian Pidgin',
    accentDescription:
        'Sunny Accra tenor blending classic Highlife guitar cadences with modern Asakaa bounce',
    vocalRange: 'B2 – G4',
    loraScale: 0.90,
    formantShiftSemitones: 0.0,
    recommendedCleanseFlavor: VocalCleanseFlavor.warmIntimate,
    samplePreviewUrl: '/mock-storage/vox_accra_highlife_gold.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_dakar_sahel_griot',
    name: 'Dakar Teranga Griot',
    region: AfricanVoiceRegion.westAfrica,
    gender: VocalGender.male,
    deliveryStyle: VocalDeliveryStyle.maskandiPraise,
    nativeLanguage: 'Wolof',
    accentDescription:
        'Piercing Senegalese griot tenor with ornate melismatic runs that soar over Afro-Tech house',
    vocalRange: 'C3 – A4',
    loraScale: 0.95,
    formantShiftSemitones: 0.4,
    recommendedCleanseFlavor: VocalCleanseFlavor.wideAnthem,
    samplePreviewUrl: '/mock-storage/vox_dakar_sahel_griot.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_nairobi_arbantone_wave',
    name: 'Kilimani Arbantone Wave',
    region: AfricanVoiceRegion.eastAfrica,
    gender: VocalGender.female,
    deliveryStyle: VocalDeliveryStyle.amapianoChant,
    nativeLanguage: 'Kiswahili / Sheng',
    accentDescription:
        'Crisp Nairobi Sheng & Kiswahili rhythmic vocalist with bouncy East African syllabic flow',
    vocalRange: 'G3 – E5',
    loraScale: 0.90,
    formantShiftSemitones: 0.1,
    recommendedCleanseFlavor: VocalCleanseFlavor.studioClean,
    samplePreviewUrl: '/mock-storage/vox_nairobi_arbantone_wave.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_dar_bongo_flava_star',
    name: 'Dar es Salaam Bongo Velvet',
    region: AfricanVoiceRegion.eastAfrica,
    gender: VocalGender.male,
    deliveryStyle: VocalDeliveryStyle.melodicSoul,
    nativeLanguage: 'Kiswahili',
    accentDescription:
        'Honeyed Coastal Tanzanian tenor with coastal Taarab ornamentation and pure vowel tone',
    vocalRange: 'A2 – F4',
    loraScale: 0.89,
    formantShiftSemitones: 0.0,
    recommendedCleanseFlavor: VocalCleanseFlavor.warmIntimate,
    samplePreviewUrl: '/mock-storage/vox_dar_bongo_flava_star.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_kampala_afro_dancehall',
    name: 'Kampala Fire Baritone',
    region: AfricanVoiceRegion.eastAfrica,
    gender: VocalGender.male,
    deliveryStyle: VocalDeliveryStyle.gqomMc,
    nativeLanguage: 'Luganda',
    accentDescription:
        'Gritty Ugandan Luganda dancehall/electronic toaster with chest-rattling low end',
    vocalRange: 'F2 – D4',
    loraScale: 0.92,
    formantShiftSemitones: -0.7,
    recommendedCleanseFlavor: VocalCleanseFlavor.studioClean,
    samplePreviewUrl: '/mock-storage/vox_kampala_afro_dancehall.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_addis_tizita_alto',
    name: 'Addis Tizita Pentatonic Alto',
    region: AfricanVoiceRegion.eastAfrica,
    gender: VocalGender.female,
    deliveryStyle: VocalDeliveryStyle.melodicSoul,
    nativeLanguage: 'Amharic',
    accentDescription:
        'Hypnotic Ethiopian Amharic alto with signature Tizita pentatonic pitch bends',
    vocalRange: 'F3 – D5',
    loraScale: 0.91,
    formantShiftSemitones: -0.1,
    recommendedCleanseFlavor: VocalCleanseFlavor.warmIntimate,
    samplePreviewUrl: '/mock-storage/vox_addis_tizita_alto.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_kinshasa_rumba_sebene',
    name: 'Kinshasa Rumba-Sebene Duet',
    region: AfricanVoiceRegion.centralAfrica,
    gender: VocalGender.duet,
    deliveryStyle: VocalDeliveryStyle.choirHarmony,
    nativeLanguage: 'Lingala',
    accentDescription:
        'Sweet Congolese Lingala parallel-thirds duet with animated Sebene atalaku shouts',
    vocalRange: 'A2 – F5',
    loraScale: 0.94,
    formantShiftSemitones: 0.2,
    recommendedCleanseFlavor: VocalCleanseFlavor.wideAnthem,
    samplePreviewUrl: '/mock-storage/vox_kinshasa_rumba_sebene.mp3',
  ),
  RegionalVoiceArchetype(
    id: 'vox_london_afro_house_diva',
    name: 'South London Afro-Tech Diva',
    region: AfricanVoiceRegion.diaspora,
    gender: VocalGender.female,
    deliveryStyle: VocalDeliveryStyle.melodicSoul,
    nativeLanguage: 'English',
    accentDescription:
        'Powerhouse Afro-House & UK Funky soul vocalist with stadium-ready belt and air sheen',
    vocalRange: 'G3 – G5',
    loraScale: 0.90,
    formantShiftSemitones: 0.1,
    recommendedCleanseFlavor: VocalCleanseFlavor.wideAnthem,
    samplePreviewUrl: '/mock-storage/vox_london_afro_house_diva.mp3',
  ),
];
