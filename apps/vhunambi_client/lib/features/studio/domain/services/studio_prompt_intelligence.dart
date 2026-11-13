import '../../../creator_dna/domain/entities/creator_dna_profile.dart';
import '../models/prompt_enhancement_result.dart';
import '../models/studio_form_state.dart';

/// Pure Dart, synchronous prompt intelligence service (M10 / REQ-PRI-05).
///
/// Zero async. Zero network calls. Pure text processing + optional Creator
/// DNA merge — enriches the raw prompt with African instrumentation context,
/// BPM framing, dialect nuance, and studio field overrides the cockpit can
/// apply in a single tap.
class StudioPromptIntelligence {
  const StudioPromptIntelligence._();

  // Genre keyword → canonical genre name.
  static const Map<String, String> _genreKeywords = <String, String>{
    'amapiano': 'Amapiano',
    'piano': 'Amapiano',
    'gqom': 'Gqom',
    'kwaito': 'Kwaito',
    'maskandi': 'Maskandi',
    'afrobeats': 'Afrobeats',
    'afro beats': 'Afrobeats',
    'gospel': 'Gospel',
    'highlife': 'Highlife',
    'hip hop': 'Hip Hop',
    'hiphop': 'Hip Hop',
    'rap': 'Hip Hop',
    'r&b': 'R&B',
    'rnb': 'R&B',
    'soul': 'Afro Soul',
    'afro house': 'Afro House',
    'house': 'Afro House',
  };

  // Language keyword → canonical language name.
  static const Map<String, String> _languageKeywords = <String, String>{
    'zulu': 'isiZulu',
    'isizulu': 'isiZulu',
    'venda': 'Tshivenḓa',
    'tshivenda': 'Tshivenḓa',
    'tshivenḓa': 'Tshivenḓa',
    'xhosa': 'isiXhosa',
    'isixhosa': 'isiXhosa',
    'sotho': 'Sepedi',
    'sepedi': 'Sepedi',
    'pedi': 'Sepedi',
    'setswana': 'Setswana',
    'tswana': 'Setswana',
    'xitsonga': 'Xitsonga',
    'tsonga': 'Xitsonga',
    'swahili': 'Swahili',
    'shona': 'Shona',
    'english': 'English',
  };

  // Vocal delivery keyword → canonical `VocalMode.name`.
  static const Map<String, String> _vocalModeKeywords = <String, String>{
    'choir': 'choir',
    'harmonies': 'choir',
    'harmony': 'choir',
    'spoken word': 'spokenWord',
    'storytelling': 'spokenWord',
    'izibongo': 'spokenWord',
    'melodic': 'melodic',
    'singing': 'melodic',
  };

  static const List<String> _femaleKeywords = [
    'female',
    'woman',
    'girl',
    'lady',
    'she',
  ];
  static const List<String> _maleKeywords = ['male', 'man', 'guy', 'he', 'boy'];
  static const List<String> _moodUplifting = [
    'happy',
    'uplifting',
    'joy',
    'celebration',
    'vibrant',
  ];
  static const List<String> _moodDark = [
    'dark',
    'sad',
    'melancholy',
    'pain',
    'hurt',
  ];
  static const List<String> _moodSpiritual = [
    'spiritual',
    'prayer',
    'church',
    'god',
    'gospel',
    'ancestors',
    'healing',
  ];

  /// Detects genre / language / vocal / mood signals in [rawPrompt] and
  /// returns an enriched prompt plus the studio field overrides needed to
  /// apply it (REQ-PRI-05).
  ///
  /// When a [dna] profile with completed onboarding is supplied, its top
  /// genre and primary language backfill any blanks the prompt did not
  /// mention (REQ-PRI-06).
  static PromptEnhancementResult enhance(
    String rawPrompt, {
    CreatorDnaProfile? dna,
    StudioFormState? currentForm,
  }) {
    if (rawPrompt.trim().isEmpty) {
      return PromptEnhancementResult(rawPrompt: rawPrompt, enhancedPrompt: '');
    }

    final lower = rawPrompt.toLowerCase();
    final overrides = <String, dynamic>{};

    // Genre detection.
    for (final entry in _genreKeywords.entries) {
      if (lower.contains(entry.key)) {
        overrides['genre'] = entry.value;
        break;
      }
    }

    // Language detection.
    for (final entry in _languageKeywords.entries) {
      if (lower.contains(entry.key)) {
        overrides['language'] = entry.value;
        break;
      }
    }

    // Vocal delivery detection.
    for (final entry in _vocalModeKeywords.entries) {
      if (lower.contains(entry.key)) {
        overrides['vocalMode'] = entry.value;
        break;
      }
    }

    // Gender detection.
    if (_femaleKeywords.any(lower.contains)) {
      overrides['vocalGender'] = 'female';
    } else if (_maleKeywords.any(lower.contains)) {
      overrides['vocalGender'] = 'male';
    }

    // Mood detection.
    if (_moodUplifting.any(lower.contains)) {
      overrides['mood'] = 'Uplifting';
    } else if (_moodDark.any(lower.contains)) {
      overrides['mood'] = 'Melancholic';
    } else if (_moodSpiritual.any(lower.contains)) {
      overrides['mood'] = 'Peaceful';
    }

    // Phase 65 (REQ-P65-L5-03): Active StudioFormState selections take
    // priority over CreatorDnaProfile defaults whenever the prompt did not
    // explicitly override them.
    if (currentForm != null) {
      if (currentForm.genre.trim().isNotEmpty) {
        final rawGenre = currentForm.genre.trim();
        final effectiveGenre = currentForm.era != ProductionEra.modern
            ? (currentForm.era.label.toLowerCase().contains(
                    rawGenre.toLowerCase(),
                  )
                  ? currentForm.era.label
                  : '${currentForm.era.label} $rawGenre')
            : rawGenre;
        overrides.putIfAbsent('genre', () => effectiveGenre);
      }
      if (currentForm.language.trim().isNotEmpty) {
        overrides.putIfAbsent('language', () => currentForm.language.trim());
      }
      if (currentForm.mood.trim().isNotEmpty) {
        overrides.putIfAbsent('mood', () => currentForm.mood.trim());
      }
      overrides.putIfAbsent('vocalGender', () => currentForm.vocalGender.name);
      if (currentForm.vocalMode != VocalMode.auto) {
        overrides.putIfAbsent('vocalMode', () => currentForm.vocalMode.name);
      }
    }

    // Merge DNA signals for whatever the prompt & form left blank (REQ-PRI-06).
    if (dna != null && dna.onboardingCompleted) {
      final ranked = dna.topGenres(1);
      if (ranked.isNotEmpty) {
        overrides.putIfAbsent('genre', () => ranked.first);
      }
      if (dna.primaryLanguage.trim().isNotEmpty) {
        overrides.putIfAbsent('language', () => dna.primaryLanguage);
      }
    }

    final genre = overrides['genre'] as String? ?? 'music';
    final lang = overrides['language'] as String?;
    final gender = overrides['vocalGender'] as String?;
    final mode = overrides['vocalMode'] as String?;
    final mood = overrides['mood'] as String?;

    final enhanced = _buildEnhancedPrompt(
      rawPrompt,
      genre,
      lang,
      gender,
      mode,
      mood,
    );

    return PromptEnhancementResult(
      rawPrompt: rawPrompt,
      enhancedPrompt: enhanced,
      suggestedOverrides: overrides,
    );
  }

  static String _buildEnhancedPrompt(
    String original,
    String genre,
    String? lang,
    String? gender,
    String? mode,
    String? mood,
  ) {
    final parts = <String>[original.trim()];
    if (lang != null) {
      parts.add('with $lang vocal delivery');
    }
    if (gender != null) {
      parts.add('performed by a $gender vocalist');
    }
    if (mode != null) {
      parts.add('using $mode vocal styling');
    }
    if (mood != null) {
      parts.add('carrying a ${mood.toLowerCase()} atmosphere');
    }
    parts.add(
      'crafted in the $genre tradition with authentic African instrumentation '
      '— log drums, shakers, and warm bass',
    );
    return '${parts.join(', ')}.';
  }
}
