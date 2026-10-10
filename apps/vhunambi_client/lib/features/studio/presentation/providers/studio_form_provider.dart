import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/studio_form_state.dart';

final studioFormProvider =
    StateNotifierProvider<StudioFormNotifier, StudioFormState>((ref) {
  return StudioFormNotifier();
});

class StudioFormNotifier extends StateNotifier<StudioFormState> {
  StudioFormNotifier() : super(const StudioFormState());

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

  void setMood(String mood) {
    state = state.copyWith(mood: mood);
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

  void toggleAutoTitle(bool auto) {
    state = state.copyWith(isAutoTitle: auto);
  }

  void setCustomTitle(String title) {
    state = state.copyWith(customTitle: title);
  }

  void togglePublic(bool isPublic) {
    state = state.copyWith(isPublic: isPublic);
  }

  void setReferenceAudio(String? path) {
    state = state.copyWith(referenceAudioPath: path);
  }

  void applyPromptPreset(String preset) {
    state = state.copyWith(prompt: preset);
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
}
