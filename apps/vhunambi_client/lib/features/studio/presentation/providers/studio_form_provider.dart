import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/design_system/models/generation_request_notifier.dart';
import 'package:vhunambi_client/core/design_system/tokens/design_enums.dart';
import '../../domain/models/bantu_voice_profile.dart';
import '../../domain/models/mycelium_biome_models.dart';
import '../../domain/models/studio_form_state.dart';

/// Tracks the active 2D Studio Cockpit workspace tab (REQ-P54-TELE-02).
final studioCockpitTabProvider = StateProvider<CockpitWorkspaceTab>(
  (ref) => CockpitWorkspaceTab.compose,
);

/// Type alias for CockpitWorkspaceTab.
typedef StudioCockpitTab = CockpitWorkspaceTab;

/// Number of completed steps in the studio form (0 to 9).
final studioCompletedStepsProvider = Provider<int>((ref) {
  final s = ref.watch(studioFormProvider);
  int count = 0;
  if (s.prompt.isNotEmpty) count++;
  if (s.genre.isNotEmpty) count++;
  if (s.mood.isNotEmpty) count++;
  count++; // tempo has default
  count++; // vocalEnergy has default
  if (s.language.isNotEmpty) count++;
  count++; // lyricsMode has default
  count++; // dna usage has default
  count++; // visibility has default
  return count;
});

final studioFormProvider =
    StateNotifierProvider<StudioFormNotifier, StudioFormState>((ref) {
      return StudioFormNotifier(ref.read(generationRequestProvider.notifier));
    });

class StudioFormNotifier extends StateNotifier<StudioFormState> {
  StudioFormNotifier([this._generationRequestNotifier])
    : super(const StudioFormState());

  final GenerationRequestNotifier? _generationRequestNotifier;
  int _sonicVibePresetIndex = 0;

  static final List<String> _inspirationSeeds = [
    'A high-energy Amapiano anthem with driving log drums and soulful Tshivenḓa vocal harmonies celebrating heritage and resilience.',
    'A reflective Maskandi acoustic guitar storytelling piece about homecoming in KwaZulu-Natal with melodic call-and-response.',
    'Late-night log drum session in Soweto with hypnotic deep bass, jazz keys, and upbeat township chants.',
    'Afro House club shaker with driving percussion, soulful female lead, and melodic marimba chords.',
    'Township love story — two people meeting at a vibrant street festival with breezy Afrobeats guitar and romantic lyrics.',
    'Powerful Gqom raw club banger from Durban with dark synths, thumping bass kicks, and energetic stadium hype chants.',
  ];

  void updatePrompt(String prompt) {
    state = state.copyWith(prompt: prompt);
  }

  void setGenre(String genre) {
    state = state.copyWith(genre: genre);
    // Sync with GenerationRequestNotifier (design system state)
    _generationRequestNotifier?.setGenre(_mapStringToGenre(genre));
  }

  void setRegion(String region) {
    state = state.copyWith(region: region);
  }

  void setLanguage(String language) {
    state = state.copyWith(language: language);
  }

  void toggleInstrumental(bool value) {
    state = state.copyWith(
      isInstrumental: value,
      lyricsMode: value ? LyricsMode.instrumental : LyricsMode.aiWrite,
    );
  }

  void setDurationSeconds(int seconds) {
    state = state.copyWith(durationSeconds: seconds);
  }

  void setLyricsMode(LyricsMode mode) {
    state = state.copyWith(lyricsMode: mode);
  }

  void setCustomLyrics(String lyrics) {
    state = state.copyWith(customLyrics: lyrics);
  }

  void updateLyrics(String lyrics) => setCustomLyrics(lyrics);

  void setMood(String mood) {
    state = state.copyWith(mood: mood);
    // Sync with GenerationRequestNotifier (design system state)
    _generationRequestNotifier?.setMood(_mapStringToMood(mood));
  }

  void setTempo(TempoBracket tempo) {
    state = state.copyWith(tempo: tempo);
  }

  void setVocalVoices(VocalVoices voices) {
    state = state.copyWith(vocalVoices: voices);
  }

  void setVocalGender(VocalGender gender) {
    state = state.copyWith(vocalGender: gender);
  }

  void setVocalMode(VocalMode mode) {
    state = state.copyWith(vocalMode: mode);
  }

  void setVocalEnergy(VocalEnergy energy) {
    state = state.copyWith(vocalEnergy: energy);
  }

  void setSongStructure(SongStructure structure) {
    state = state.copyWith(songStructure: structure);
  }

  void setStructure(SongStructure structure) => setSongStructure(structure);
  void setVocalConfiguration(VocalVoices voices) => setVocalVoices(voices);
  void setVocalIntensity(VocalEnergy energy) => setVocalEnergy(energy);
  void selectMood(String mood) => setMood(mood);
  void setEra(ProductionEra era) => state = state.copyWith(era: era);

  void toggleAutoTitle(bool auto) {
    state = state.copyWith(isAutoTitle: auto);
  }

  void setCustomTitle(String title) {
    state = state.copyWith(customTitle: title);
  }

  /// VH-002: Sets track visibility to "public" or "private" (replaces
  /// togglePublic(bool) to align with backend API schema).
  void setVisibility(String visibility) {
    state = state.copyWith(visibility: visibility);
    // Sync with GenerationRequestNotifier (design system state)
    _generationRequestNotifier?.setVisibility(visibility);
  }

  /// Backward-compatible toggle during VH-002 migration.
  void togglePublic(bool isPublic) {
    setVisibility(isPublic ? 'public' : 'private');
  }

  void setReferenceAudio(String? path) {
    state = state.copyWith(
      referenceAudioPath: path,
      clearReferenceAudio: path == null,
    );
  }

  void applyPromptPreset(String preset) {
    state = state.copyWith(prompt: preset);
  }

  void setBantuVoiceProfile(BantuVoiceProfile profile) {
    state = state.copyWith(selectedVoiceProfile: profile);
  }

  void updateDialectInflection(DialectInflectionConfig inflection) {
    state = state.copyWith(dialectInflection: inflection);
  }

  void setBranchStemLockModes(Map<String, StemLockMode> modes) {
    state = state.copyWith(branchStemLockModes: modes);
  }

  /// Atomically sets a stem lock mode and synchronizes all canonical & legacy alias keys (REQ-P54-SYNC-02).
  void setBranchStemLockMode(String branchId, StemLockMode mode) {
    final updated = Map<String, StemLockMode>.from(state.branchStemLockModes);
    updated[branchId] = mode;

    // Synchronize canonical <-> legacy alias pairs
    switch (branchId) {
      case 'node_beat_tempo':
      case 'node_branch_beat':
        updated['node_beat_tempo'] = mode;
        updated['node_branch_beat'] = mode;
      case 'node_sketchpad_groove':
      case 'node_branch_instruments':
      case 'node_harmony_chords':
        updated['node_sketchpad_groove'] = mode;
        updated['node_branch_instruments'] = mode;
        updated['node_harmony_chords'] = mode;
      case 'node_vocal_persona':
      case 'node_branch_vocal':
      case 'node_emotion_mood':
        updated['node_vocal_persona'] = mode;
        updated['node_branch_vocal'] = mode;
        updated['node_emotion_mood'] = mode;
      case 'node_spatial_atmosphere':
      case 'node_branch_sfx':
        updated['node_spatial_atmosphere'] = mode;
        updated['node_branch_sfx'] = mode;
    }

    state = state.copyWith(branchStemLockModes: updated);
  }

  /// Sets the StemLockMode for a specific 3D MyceliumClusterDomain (REQ-P54-SYNC-02).
  void setClusterStemLockMode(MyceliumClusterDomain domain, StemLockMode mode) {
    setBranchStemLockMode(domain.studioBranchKey, mode);
  }

  /// Cycles StemLockMode (lockedPure44k -> harmonicInpaint -> elasticResynth) for a domain (REQ-P54-RACK-02).
  StemLockMode cycleClusterStemLockMode(MyceliumClusterDomain domain) {
    final current =
        state.branchStemLockModes[domain.studioBranchKey] ??
        state.branchStemLockModes[domain.legacyBranchAliasKey] ??
        StemLockMode.harmonicInpaint;
    final next = switch (current) {
      StemLockMode.lockedPure44k => StemLockMode.harmonicInpaint,
      StemLockMode.harmonicInpaint => StemLockMode.elasticResynth,
      StemLockMode.elasticResynth => StemLockMode.lockedPure44k,
    };
    setClusterStemLockMode(domain, next);
    return next;
  }

  /// Cycles through the 4 curated African Sonic Vibe DNA presets (REQ-P54-RACK-03).
  void cycleSonicVibeDice() {
    _sonicVibePresetIndex = (_sonicVibePresetIndex + 1) % 4;
    switch (_sonicVibePresetIndex) {
      case 0:
        applyDnaPresetPrivateSchoolPiano();
      case 1:
        applyDnaPresetDurbanDarkGqom();
      case 2:
        applyDnaPresetVendaTraditionalSoul();
      case 3:
        applyDnaPresetLagosAfroPop();
    }
  }

  void applyDnaPresetPrivateSchoolPiano() {
    state = state.copyWith(
      genre: 'Amapiano',
      region: 'South Africa',
      language: 'Tshivenḓa',
      mood: 'Soulful & Nostalgic',
      tempo: TempoBracket.medium,
      vocalVoices: VocalVoices.solo,
      vocalGender: VocalGender.female,
      vocalMode: VocalMode.melodic,
      vocalEnergy: VocalEnergy.mid,
      prompt:
          'Soulful private school piano with delicate jazz chords, warm rhodes, deep log drum basslines, and emotive female vocals.',
    );
  }

  void applyDnaPresetDurbanDarkGqom() {
    state = state.copyWith(
      genre: 'Gqom',
      region: 'South Africa',
      language: 'isiZulu',
      mood: 'Dark & Intense',
      tempo: TempoBracket.fast,
      vocalVoices: VocalVoices.solo,
      vocalGender: VocalGender.male,
      vocalMode: VocalMode.spokenWord,
      vocalEnergy: VocalEnergy.intense,
      prompt:
          'Underground Durban club banger with heavy 808 sub hits, metallic claps, repetitive vocal chants, and dark hypnotic tension.',
    );
  }

  void applyDnaPresetVendaTraditionalSoul() {
    state = state.copyWith(
      genre: 'Afro-Soul',
      region: 'Limpopo',
      language: 'Tshivenḓa',
      mood: 'Peaceful & Spiritual',
      tempo: TempoBracket.slow,
      vocalVoices: VocalVoices.choir,
      vocalGender: VocalGender.mixed,
      vocalMode: VocalMode.choir,
      vocalEnergy: VocalEnergy.soft,
      prompt:
          'Traditional acoustic storytelling layered with warm vocal harmonies, polyrhythmic percussion, and spiritual African call-and-response.',
    );
  }

  void applyDnaPresetLagosAfroPop() {
    state = state.copyWith(
      genre: 'Afrobeats',
      region: 'Nigeria',
      language: 'English',
      mood: 'Uplifting & Vibrant',
      tempo: TempoBracket.medium,
      vocalVoices: VocalVoices.duet,
      vocalGender: VocalGender.mixed,
      vocalMode: VocalMode.melodic,
      vocalEnergy: VocalEnergy.mid,
      prompt:
          'Sunny Afrobeats anthem with bright electric guitar plucks, upbeat percussion groove, and catchy melodic duet vocals.',
    );
  }

  void inspireMe() {
    final random = Random();
    final seed = _inspirationSeeds[random.nextInt(_inspirationSeeds.length)];
    state = state.copyWith(prompt: seed);
  }

  /// T12.5 — enters the lyrics review pause: the synthesis FSM stops in
  /// `generatingLyrics` while the AI drafts the stanzas (REQ-LYR-01).
  void beginLyricsReview() {
    state = state.copyWith(
      phase: GenerationPhase.generatingLyrics,
      generationProgress: 0.25,
      errorMessage: null,
    );
  }

  /// Publishes the drafted stanzas for review and opens the cockpit
  /// (REQ-LYR-02).
  void markReviewingLyrics() {
    state = state.copyWith(
      phase: GenerationPhase.reviewingLyrics,
      generationProgress: 0.4,
    );
  }

  /// Opens the Phase 38 Lyrics Review & Section Editor gate prior to generation.
  void openLyricsReview() {
    state = state.copyWith(phase: GenerationPhase.reviewingLyrics);
  }

  /// Cancels an unapproved Lyrics Review session and restores idle state (REQ-P56-PIPE-01)
  /// so the Studio viewport never renders a stuck empty Result skeleton card.
  void cancelLyricsReview() {
    if (state.phase == GenerationPhase.reviewingLyrics) {
      state = state.copyWith(phase: GenerationPhase.idle);
    }
  }

  /// Saves the approved lyrics and queues beat production (REQ-LYR-08).
  void approveLyrics(String lyrics) {
    state = state.copyWith(
      customLyrics: lyrics,
      phase: GenerationPhase.queued,
      generationProgress: 0.5,
      errorMessage: null,
    );
  }

  void triggerGeneration() {
    if (state.isInstrumental || state.lyricsMode != LyricsMode.aiWrite) {
      state = state.copyWith(
        phase: GenerationPhase.queued,
        generationProgress: 0.1,
      );
    } else {
      state = state.copyWith(
        phase: GenerationPhase.generatingLyrics,
        generationProgress: 0.25,
      );
    }
  }

  void reset() {
    state = const StudioFormState();
  }

  /// Maps a free-form [genre] string from [StudioFormState] to a
  /// [Genre] enum for the design system token registry.
  ///
  /// Unknown genres fall back to [Genre.amapiano].
  Genre _mapStringToGenre(String genre) {
    final normalized = genre.trim().toLowerCase();
    return switch (normalized) {
      'amapiano' => Genre.amapiano,
      'afro house' => Genre.afroHouse,
      'afrohouse' => Genre.afroHouse,
      'gqom' => Genre.gqom,
      'kwaito' => Genre.kwaito,
      'afro pop' => Genre.afroPop,
      'afropop' => Genre.afroPop,
      'afrobeats' => Genre.afroPop,
      'afro beats' => Genre.afroPop,
      'maskandi' => Genre.maskandi,
      'hip hop' => Genre.hipHop,
      'hiphop' => Genre.hipHop,
      'gospel' => Genre.gospel,
      _ => Genre.amapiano,
    };
  }

  /// Maps a free-form [mood] string from [StudioFormState] to a
  /// [Mood] enum for the design system token registry.
  ///
  /// Unknown moods fall back to [Mood.joyful].
  Mood _mapStringToMood(String mood) {
    final normalized = mood.trim().toLowerCase();
    return switch (normalized) {
      'uplifting' => Mood.joyful,
      'uplifting & vibrant' => Mood.joyful,
      'joyful' => Mood.joyful,
      'dark & intense' => Mood.melancholic,
      'dark' => Mood.melancholic,
      'melancholic' => Mood.melancholic,
      'peaceful & spiritual' => Mood.calm,
      'peaceful' => Mood.calm,
      'spiritual' => Mood.calm,
      'calm' => Mood.calm,
      'romantic' => Mood.romantic,
      _ => Mood.joyful,
    };
  }
}
