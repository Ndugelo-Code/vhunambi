import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/hive_compaction_scheduler.dart';
import '../../../mastering/domain/models/stem_mastering_recipe.dart';
import '../../../mastering/presentation/providers/mastering_session_provider.dart';
import '../../../sound_signature/data/sound_signature_repository.dart';
import '../../data/services/pre_gen_r2_upload_service.dart';
import '../../data/services/sketchpad_audio_player_service.dart';
import '../../domain/models/vocal_identity_models.dart';
import '../../domain/services/i_voice_calibration_recorder.dart';
import '../../domain/services/melody_wav_synthesizer.dart';
import '../../domain/services/phonetic_calibration_extractor.dart';

/// Injectable provider for the voice calibration microphone recorder (REQ-VOC-07).
final voiceCalibrationRecorderProvider = Provider<IVoiceCalibrationRecorder>((
  ref,
) {
  final recorder = ProductionVoiceCalibrationRecorder();
  ref.onDispose(recorder.dispose);
  return recorder;
});

/// Immutable state for the Phase 26 Vocal Identity & Zero-Shot Voice Cloning engine.
@immutable
class VocalIdentityState {
  const VocalIdentityState({
    this.catalog = kRegionalVoiceCatalog,
    required this.activeArchetype,
    this.clonedProfiles = const [],
    this.activeClonedProfile,
    this.selectedRegion,
    this.selectedGender,
    this.selectedStyle,
    this.searchQuery = '',
    this.calibrationScript,
    this.isRecording = false,
    this.isSynthesizingClone = false,
    this.liveAmplitude = 0.0,
    this.previewingArchetypeId,
  });

  final List<RegionalVoiceArchetype> catalog;
  final RegionalVoiceArchetype activeArchetype;
  final List<CreatorVoiceCloneProfile> clonedProfiles;
  final CreatorVoiceCloneProfile? activeClonedProfile;
  final AfricanVoiceRegion? selectedRegion;
  final VocalGender? selectedGender;
  final VocalDeliveryStyle? selectedStyle;
  final String searchQuery;
  final PhoneticCalibrationScript? calibrationScript;
  final bool isRecording;
  final bool isSynthesizingClone;
  final double liveAmplitude;
  final String? previewingArchetypeId;

  /// Whether a zero-shot cloned creator voice is currently active for synthesis.
  bool get isUsingClonedVoice => activeClonedProfile != null;

  /// Display label for the currently active voice identity in `BantuVoiceDeck`.
  String get activeVoiceDisplayLabel => activeClonedProfile != null
      ? '${activeClonedProfile!.creatorName} (Cloned DNA)'
      : '${activeArchetype.name} (${activeArchetype.nativeLanguage})';

  /// Recommended Phase 25 VocalCleanseFlavor for the active voice identity.
  VocalCleanseFlavor get recommendedCleanseFlavor =>
      activeClonedProfile?.recommendedCleanseFlavor ??
      activeArchetype.recommendedCleanseFlavor;

  /// Filtered list of regional voice archetypes matching region, gender, style, and query.
  List<RegionalVoiceArchetype> get filteredCatalog {
    final q = searchQuery.trim().toLowerCase();
    return catalog.where((arch) {
      if (selectedRegion != null && arch.region != selectedRegion) {
        return false;
      }
      if (selectedGender != null && arch.gender != selectedGender) {
        return false;
      }
      if (selectedStyle != null && arch.deliveryStyle != selectedStyle) {
        return false;
      }
      if (q.isNotEmpty) {
        final hay =
            '${arch.name} ${arch.nativeLanguage} ${arch.accentDescription} ${arch.region.label}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  VocalIdentityState copyWith({
    List<RegionalVoiceArchetype>? catalog,
    RegionalVoiceArchetype? activeArchetype,
    List<CreatorVoiceCloneProfile>? clonedProfiles,
    CreatorVoiceCloneProfile? activeClonedProfile,
    bool clearActiveClone = false,
    AfricanVoiceRegion? selectedRegion,
    bool clearRegionFilter = false,
    VocalGender? selectedGender,
    bool clearGenderFilter = false,
    VocalDeliveryStyle? selectedStyle,
    bool clearStyleFilter = false,
    String? searchQuery,
    PhoneticCalibrationScript? calibrationScript,
    bool? isRecording,
    bool? isSynthesizingClone,
    double? liveAmplitude,
    String? previewingArchetypeId,
    bool clearPreviewingArchetype = false,
  }) {
    return VocalIdentityState(
      catalog: catalog ?? this.catalog,
      activeArchetype: activeArchetype ?? this.activeArchetype,
      clonedProfiles: clonedProfiles ?? this.clonedProfiles,
      activeClonedProfile: clearActiveClone
          ? null
          : (activeClonedProfile ?? this.activeClonedProfile),
      selectedRegion: clearRegionFilter
          ? null
          : (selectedRegion ?? this.selectedRegion),
      selectedGender: clearGenderFilter
          ? null
          : (selectedGender ?? this.selectedGender),
      selectedStyle: clearStyleFilter
          ? null
          : (selectedStyle ?? this.selectedStyle),
      searchQuery: searchQuery ?? this.searchQuery,
      calibrationScript: calibrationScript ?? this.calibrationScript,
      isRecording: isRecording ?? this.isRecording,
      isSynthesizingClone: isSynthesizingClone ?? this.isSynthesizingClone,
      liveAmplitude: liveAmplitude ?? this.liveAmplitude,
      previewingArchetypeId: clearPreviewingArchetype
          ? null
          : (previewingArchetypeId ?? this.previewingArchetypeId),
    );
  }
}

/// Manages the 24 Regional African Voice Archetypes, 3-Line Bantu Phonetic Calibration,
/// and Zero-Shot Creator Voice Clone profiles with Hive persistence (REQ-VOC-01..15).
class VocalIdentityNotifier extends StateNotifier<VocalIdentityState> {
  VocalIdentityNotifier(this._ref, this._recorder)
    : super(
        VocalIdentityState(
          activeArchetype: kRegionalVoiceCatalog.first,
          calibrationScript: PhoneticCalibrationExtractor.extractScript(
            '',
            language: 'Tshivenḓa',
          ),
        ),
      ) {
    _loadPersistedClones();
    _amplitudeSub = _recorder.amplitudeStream.listen((amp) {
      if (mounted) {
        state = state.copyWith(liveAmplitude: amp);
      }
    });
  }

  final Ref _ref;
  final IVoiceCalibrationRecorder _recorder;
  StreamSubscription<double>? _amplitudeSub;
  static const String _profilesListKey = 'cloned_voice_profiles_json';
  static const String _voiceKeyPrefix = 'voice_';
  static const String _activeVoiceIdKey = 'active_cloned_voice_id';

  void _loadPersistedClones() {
    try {
      if (!Hive.isBoxOpen(AppConstants.voiceProfilesBoxKey)) return;
      final box = Hive.box<dynamic>(AppConstants.voiceProfilesBoxKey);

      // Migrate legacy monolithic JSON list to O(1) entity keys ('voice_<id>').
      final legacyRaw = box.get(_profilesListKey) as String?;
      if (legacyRaw != null && legacyRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(legacyRaw) as List<dynamic>;
          final legacyProfiles = decoded
              .map(
                (e) => CreatorVoiceCloneProfile.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
          for (final profile in legacyProfiles) {
            unawaited(
              box.put(
                '$_voiceKeyPrefix${profile.id}',
                jsonEncode(profile.toJson()),
              ),
            );
          }
          if (legacyProfiles.isNotEmpty &&
              !box.containsKey(_activeVoiceIdKey)) {
            unawaited(box.put(_activeVoiceIdKey, legacyProfiles.first.id));
          }
          unawaited(box.delete(_profilesListKey));
        } catch (_) {}
      }

      final profiles = <CreatorVoiceCloneProfile>[];
      for (final rawKey in box.keys) {
        final key = rawKey.toString();
        if (!key.startsWith(_voiceKeyPrefix)) continue;
        final rawVal = box.get(rawKey);
        if (rawVal is String && rawVal.isNotEmpty) {
          try {
            profiles.add(
              CreatorVoiceCloneProfile.fromJson(
                Map<String, dynamic>.from(jsonDecode(rawVal) as Map),
              ),
            );
          } catch (_) {}
        } else if (rawVal is Map) {
          try {
            profiles.add(
              CreatorVoiceCloneProfile.fromJson(
                Map<String, dynamic>.from(rawVal),
              ),
            );
          } catch (_) {}
        }
      }

      if (profiles.isEmpty) return;
      profiles.sort((a, b) => b.createdAtIso.compareTo(a.createdAtIso));

      final hasActiveKey = box.containsKey(_activeVoiceIdKey);
      final activeId = box.get(_activeVoiceIdKey) as String?;
      CreatorVoiceCloneProfile? activeProfile;
      if (hasActiveKey) {
        if (activeId != null && activeId.isNotEmpty) {
          activeProfile = profiles.where((p) => p.id == activeId).firstOrNull;
        }
      } else {
        activeProfile = profiles.first;
      }

      state = state.copyWith(
        clonedProfiles: profiles,
        activeClonedProfile: activeProfile,
        clearActiveClone: activeProfile == null,
      );
    } catch (_) {
      // Safe fallback in headless tests when Hive is not initialized
    }
  }

  Future<void> _persistSingleProfile(CreatorVoiceCloneProfile profile) async {
    try {
      if (!Hive.isBoxOpen(AppConstants.voiceProfilesBoxKey)) return;
      final box = Hive.box<dynamic>(AppConstants.voiceProfilesBoxKey);
      await box.put(
        '$_voiceKeyPrefix${profile.id}',
        jsonEncode(profile.toJson()),
      );
      await box.put(_activeVoiceIdKey, profile.id);
      await HiveCompactionScheduler.recordMutation(
        AppConstants.voiceProfilesBoxKey,
      );
    } catch (_) {
      // Safe fallback in headless tests
    }
  }

  Future<void> _deleteSingleProfile(
    String profileId, {
    required bool clearActive,
  }) async {
    try {
      if (!Hive.isBoxOpen(AppConstants.voiceProfilesBoxKey)) return;
      final box = Hive.box<dynamic>(AppConstants.voiceProfilesBoxKey);
      await box.delete('$_voiceKeyPrefix$profileId');
      if (clearActive) {
        await box.put(_activeVoiceIdKey, '');
      }
      await HiveCompactionScheduler.recordMutation(
        AppConstants.voiceProfilesBoxKey,
      );
    } catch (_) {}
  }

  void _persistActiveVoiceSelection(String? profileId) {
    try {
      if (!Hive.isBoxOpen(AppConstants.voiceProfilesBoxKey)) return;
      final box = Hive.box<dynamic>(AppConstants.voiceProfilesBoxKey);
      unawaited(box.put(_activeVoiceIdKey, profileId ?? ''));
    } catch (_) {}
  }

  /// Syncs the active voice's recommended `VocalCleanseFlavor` into Phase 25's mastering session.
  void _syncCleanseFlavorToMastering(VocalCleanseFlavor flavor) {
    Future.microtask(() {
      if (!mounted) return;
      _ref.read(masteringSessionProvider.notifier).setVocalFlavor(flavor);
    });
  }

  /// Selects one of the 24 regional African voice archetypes and clears any active clone override.
  void selectArchetype(RegionalVoiceArchetype archetype) {
    state = state.copyWith(activeArchetype: archetype, clearActiveClone: true);
    _persistActiveVoiceSelection(null);
    _syncCleanseFlavorToMastering(archetype.recommendedCleanseFlavor);
  }

  /// Selects a previously recorded `CreatorVoiceCloneProfile` for zero-shot synthesis.
  void selectClonedProfile(CreatorVoiceCloneProfile profile) {
    state = state.copyWith(activeClonedProfile: profile);
    _persistActiveVoiceSelection(profile.id);
    _syncCleanseFlavorToMastering(profile.recommendedCleanseFlavor);
  }

  /// Toggles audible formant vocal phrase preview for a catalog voice archetype card.
  void togglePreviewArchetype(String archetypeId) {
    final audioService = _ref.read(sketchpadAudioPlayerServiceProvider);
    if (state.previewingArchetypeId == archetypeId) {
      unawaited(audioService.stopVocalPreview());
      state = state.copyWith(clearPreviewingArchetype: true);
    } else {
      state = state.copyWith(previewingArchetypeId: archetypeId);
      final archetype = state.catalog.firstWhere(
        (a) => a.id == archetypeId,
        orElse: () => state.activeArchetype,
      );
      final wavBytes = MelodyWavSynthesizer.synthesizeVocalPreviewWavBytes(
        archetype,
      );
      unawaited(
        audioService.playVocalPreview(
          wavBytes,
          onComplete: () {
            if (mounted && state.previewingArchetypeId == archetypeId) {
              state = state.copyWith(clearPreviewingArchetype: true);
            }
          },
        ),
      );
    }
  }

  /// Updates the regional filter chip (passing null or same region clears filter).
  void setRegionFilter(AfricanVoiceRegion? region) {
    if (region == null || state.selectedRegion == region) {
      state = state.copyWith(clearRegionFilter: true);
    } else {
      state = state.copyWith(selectedRegion: region);
    }
  }

  /// Updates the gender filter chip (passing null or same gender clears filter).
  void setGenderFilter(VocalGender? gender) {
    if (gender == null || state.selectedGender == gender) {
      state = state.copyWith(clearGenderFilter: true);
    } else {
      state = state.copyWith(selectedGender: gender);
    }
  }

  /// Updates the delivery style filter chip.
  void setStyleFilter(VocalDeliveryStyle? style) {
    if (style == null || state.selectedStyle == style) {
      state = state.copyWith(clearStyleFilter: true);
    } else {
      state = state.copyWith(selectedStyle: style);
    }
  }

  /// Updates the free-text search query across name, language, and accent description.
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Resets all catalog filters to show all 24 regional voice archetypes.
  void clearAllFilters() {
    state = state.copyWith(
      clearRegionFilter: true,
      clearGenderFilter: true,
      clearStyleFilter: true,
      searchQuery: '',
    );
  }

  /// Extracts the top 3 phonetically rich calibration lines from [lyrics] (REQ-VOC-05).
  PhoneticCalibrationScript prepareCalibrationFromLyrics(
    String lyrics, {
    String language = 'Tshivenḓa',
  }) {
    final script = PhoneticCalibrationExtractor.extractScript(
      lyrics,
      language: language,
    );
    state = state.copyWith(calibrationScript: script);
    return script;
  }

  /// Starts capturing the 15-20s 3-line calibration voice note (REQ-VOC-07).
  Future<void> startCalibrationRecording() async {
    final script =
        state.calibrationScript ??
        PhoneticCalibrationExtractor.extractScript('', language: 'Tshivenḓa');
    await _recorder.startRecording(script);
    if (!mounted) return;
    state = state.copyWith(isRecording: true, liveAmplitude: 0.68);
  }

  /// Stops capturing and synthesizes a new `CreatorVoiceCloneProfile` (REQ-VOC-08).
  Future<CreatorVoiceCloneProfile> finalizeVoiceClone({
    String creatorName = 'My Studio Voice',
    String? nativeLanguage,
  }) async {
    state = state.copyWith(isSynthesizingClone: true);

    final result = await _recorder.stopRecording();
    final script =
        state.calibrationScript ??
        PhoneticCalibrationExtractor.extractScript('', language: 'Tshivenḓa');

    final cleanName = creatorName.trim().isEmpty
        ? 'My Studio Voice'
        : creatorName.trim();
    final lang = nativeLanguage ?? script.language;

    final profile = CreatorVoiceCloneProfile(
      id: 'vclone_${DateTime.now().millisecondsSinceEpoch}',
      creatorName: cleanName,
      nativeLanguage: lang,
      calibrationLines: script.lines.map((l) => l.text).toList(),
      timbreEmbeddingPreview: result.timbreEmbeddingPreview,
      phonemeCadenceMap: result.phonemeCadenceMap,
      cadenceWpm: result.cadenceWpm,
      clarityScore: result.clarityScore,
      recordingDurationSec: result.durationSec,
      createdAtIso: DateTime.now().toIso8601String(),
      recommendedCleanseFlavor: VocalCleanseFlavor.studioClean,
      signatureId: result.signature?.id,
    );

    if (!mounted) return profile;
    final updatedList = [profile, ...state.clonedProfiles];
    state = state.copyWith(
      isRecording: false,
      isSynthesizingClone: false,
      liveAmplitude: 0.0,
      clonedProfiles: updatedList,
      activeClonedProfile: profile,
    );

    await _persistSingleProfile(profile);
    _syncCleanseFlavorToMastering(profile.recommendedCleanseFlavor);

    var finalProfile = profile;
    try {
      final uploadedUrl = await _ref
          .read(preGenR2UploadServiceProvider)
          .uploadVoiceCloneReference(
            profileId: finalProfile.id,
            wavBytes: result.wavBytes,
            creatorName: finalProfile.creatorName,
            nativeLanguage: finalProfile.nativeLanguage,
            calibrationLines: finalProfile.calibrationLines,
            recordingDurationSec: finalProfile.recordingDurationSec,
          );
      if (uploadedUrl != null && uploadedUrl.isNotEmpty && mounted) {
        finalProfile = finalProfile.copyWith(r2ReferenceUrl: uploadedUrl);
        final updatedWithUrl = state.clonedProfiles
            .map((p) => p.id == finalProfile.id ? finalProfile : p)
            .toList();
        state = state.copyWith(
          clonedProfiles: updatedWithUrl,
          activeClonedProfile:
              state.activeClonedProfile?.id == finalProfile.id
              ? finalProfile
              : state.activeClonedProfile,
        );
        await _persistSingleProfile(finalProfile);
      }
    } catch (_) {
      // Best-effort R2 upload; local voice clone remains active.
    }

    if (result.signature != null) {
      try {
        final uploader = _ref.read(preGenR2UploadServiceProvider);
        unawaited(
          _ref
              .read(soundSignatureRepositoryProvider)
              .uploadSignatureTakeToCloud(
                dna: result.signature!,
                wavBytes: result.wavBytes,
                uploader: uploader,
              ),
        );
      } catch (_) {}
    }

    return finalProfile;
  }

  /// Deletes a saved `CreatorVoiceCloneProfile` from device storage and clears active override if matched.
  Future<void> deleteClonedProfile(String profileId) async {
    final updated = state.clonedProfiles
        .where((p) => p.id != profileId)
        .toList();
    final clearActive = state.activeClonedProfile?.id == profileId;
    state = state.copyWith(
      clonedProfiles: updated,
      clearActiveClone: clearActive,
    );
    await _deleteSingleProfile(profileId, clearActive: clearActive);
  }

  /// Seeds and aligns vocal identity from parent reel DNA for viral remixing (Phase D).
  void initializeFromRemixDna({String? deliveryMode, String? genre}) {
    RegionalVoiceArchetype? matched;
    if (deliveryMode != null && deliveryMode.isNotEmpty) {
      final style = VocalDeliveryStyle.values.firstWhere(
        (s) => s.name.toLowerCase() == deliveryMode.toLowerCase(),
        orElse: () => VocalDeliveryStyle.afroSoulMelodic,
      );
      matched = state.catalog.firstWhere(
        (a) => a.deliveryStyle == style,
        orElse: () => state.catalog.first,
      );
    } else if (genre != null && genre.isNotEmpty) {
      matched = state.catalog.firstWhere(
        (a) =>
            a.region.label.toLowerCase().contains(genre.toLowerCase()) ||
            a.nativeLanguage.toLowerCase().contains(genre.toLowerCase()),
        orElse: () => state.catalog.first,
      );
    }
    if (matched != null) {
      selectArchetype(matched);
    }
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    super.dispose();
  }
}

/// Global Riverpod provider for the Phase 26 Vocal Identity & Zero-Shot Voice Cloning engine.
final vocalIdentityProvider =
    StateNotifierProvider<VocalIdentityNotifier, VocalIdentityState>((ref) {
      final recorder = ref.watch(voiceCalibrationRecorderProvider);
      return VocalIdentityNotifier(ref, recorder);
    });
