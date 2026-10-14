import 'package:flutter/foundation.dart';

/// Evolutionary stage of the user's on-device music taste profile.
enum DnaLifecycleState {
  uninitialized,
  seeded,
  learning,
  calibrated,
  attuned,
}

/// Creative archetypes selected during onboarding or inferred through usage.
enum CreativeRole {
  producer,
  vocalist,
  songwriter,
  multiHyphenate,
  musicLover;

  String get label => switch (this) {
        CreativeRole.producer => 'Producer / Beatmaker',
        CreativeRole.vocalist => 'Vocalist / Singer',
        CreativeRole.songwriter => 'Songwriter / Lyricist',
        CreativeRole.multiHyphenate => 'Multi-Hyphenate Artist',
        CreativeRole.musicLover => 'Music Enthusiast',
      };

  String get emoji => switch (this) {
        CreativeRole.producer => '🎹',
        CreativeRole.vocalist => '🎤',
        CreativeRole.songwriter => '✍️',
        CreativeRole.multiHyphenate => '⚡',
        CreativeRole.musicLover => '🎧',
      };
}

/// Experience level indicating familiarization with African music production.
enum ExperienceLevel {
  newbie,
  growing,
  pro;

  String get label => switch (this) {
        ExperienceLevel.newbie => 'Just Starting Out',
        ExperienceLevel.growing => 'Crafting & Exploring',
        ExperienceLevel.pro => 'Seasoned Creator',
      };
}

/// Immutable on-device profile capturing the creator's cultural sound signature,
/// regional affinities, language preferences, and behavioral telemetry weights.
@immutable
class CreatorDnaProfile {
  final String userId;

  // Creative Identity (seeded at onboarding Step 1)
  final CreativeRole creativeRole;
  final ExperienceLevel experienceLevel;

  // Genre Affinity Map: genre name → accumulated signal weight (0.0–20.0)
  final Map<String, double> genreWeights;

  // Language Affinity Map: language name → signal weight
  final Map<String, double> languageWeights;

  // Primary language for AI vocal generation default
  final String primaryLanguage;

  // Mood Affinity Map: mood key → signal weight
  final Map<String, double> moodWeights;

  // Sound Signature Seed (Step 4)
  final String tempoPreference; // 'slow' | 'medium' | 'fast' | 'hyperspeed'
  final String vocalEnergyPreference; // 'soft' | 'balanced' | 'intense'

  // Lifecycle & Metadata
  final DnaLifecycleState lifecycleState;
  final int totalBehaviorEvents;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;
  final bool onboardingCompleted;
  final double onboardingCompleteness; // 0.0–1.0

  // UI Preferences
  final bool dnaInsightCardDismissed;

  const CreatorDnaProfile({
    required this.userId,
    this.creativeRole = CreativeRole.musicLover,
    this.experienceLevel = ExperienceLevel.newbie,
    this.genreWeights = const {},
    this.languageWeights = const {},
    this.primaryLanguage = 'English',
    this.moodWeights = const {},
    this.tempoPreference = 'medium',
    this.vocalEnergyPreference = 'balanced',
    this.lifecycleState = DnaLifecycleState.uninitialized,
    this.totalBehaviorEvents = 0,
    required this.createdAt,
    required this.lastUpdatedAt,
    this.onboardingCompleted = false,
    this.onboardingCompleteness = 0.0,
    this.dnaInsightCardDismissed = false,
  });

  factory CreatorDnaProfile.initial() {
    final now = DateTime.now();
    return CreatorDnaProfile(
      userId: '',
      createdAt: now,
      lastUpdatedAt: now,
    );
  }

  /// DNA Strength: 0–100 whole number percentage reflecting model confidence.
  int get strengthPercent {
    final eventScore = (totalBehaviorEvents / 200.0).clamp(0.0, 1.0) * 0.60;
    final allWeights = [
      ...genreWeights.values,
      ...languageWeights.values,
      ...moodWeights.values,
    ];
    final diversity = allWeights.isEmpty
        ? 0.0
        : (allWeights.where((w) => w > 0.5).length / 30.0).clamp(0.0, 1.0) * 0.25;
    final onboarding = onboardingCompleteness * 0.15;
    return ((eventScore + diversity + onboarding) * 100).clamp(0, 100).round();
  }

  /// Top N genres sorted by weight in descending order.
  List<String> topGenres(int n) {
    final sorted = genreWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).map((e) => e.key).toList();
  }

  CreatorDnaProfile copyWith({
    String? userId,
    CreativeRole? creativeRole,
    ExperienceLevel? experienceLevel,
    Map<String, double>? genreWeights,
    Map<String, double>? languageWeights,
    String? primaryLanguage,
    Map<String, double>? moodWeights,
    String? tempoPreference,
    String? vocalEnergyPreference,
    DnaLifecycleState? lifecycleState,
    int? totalBehaviorEvents,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
    bool? onboardingCompleted,
    double? onboardingCompleteness,
    bool? dnaInsightCardDismissed,
  }) {
    return CreatorDnaProfile(
      userId: userId ?? this.userId,
      creativeRole: creativeRole ?? this.creativeRole,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      genreWeights: genreWeights ?? this.genreWeights,
      languageWeights: languageWeights ?? this.languageWeights,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      moodWeights: moodWeights ?? this.moodWeights,
      tempoPreference: tempoPreference ?? this.tempoPreference,
      vocalEnergyPreference: vocalEnergyPreference ?? this.vocalEnergyPreference,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      totalBehaviorEvents: totalBehaviorEvents ?? this.totalBehaviorEvents,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? DateTime.now(),
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      onboardingCompleteness: onboardingCompleteness ?? this.onboardingCompleteness,
      dnaInsightCardDismissed: dnaInsightCardDismissed ?? this.dnaInsightCardDismissed,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'creativeRole': creativeRole.name,
        'experienceLevel': experienceLevel.name,
        'genreWeights': genreWeights,
        'languageWeights': languageWeights,
        'primaryLanguage': primaryLanguage,
        'moodWeights': moodWeights,
        'tempoPreference': tempoPreference,
        'vocalEnergyPreference': vocalEnergyPreference,
        'lifecycleState': lifecycleState.name,
        'totalBehaviorEvents': totalBehaviorEvents,
        'createdAt': createdAt.toIso8601String(),
        'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
        'onboardingCompleted': onboardingCompleted,
        'onboardingCompleteness': onboardingCompleteness,
        'dnaInsightCardDismissed': dnaInsightCardDismissed,
      };

  factory CreatorDnaProfile.fromJson(Map<String, dynamic> json) {
    return CreatorDnaProfile(
      userId: json['userId'] as String? ?? '',
      creativeRole: CreativeRole.values.firstWhere(
        (r) => r.name == json['creativeRole'],
        orElse: () => CreativeRole.musicLover,
      ),
      experienceLevel: ExperienceLevel.values.firstWhere(
        (e) => e.name == json['experienceLevel'],
        orElse: () => ExperienceLevel.newbie,
      ),
      genreWeights: Map<String, double>.from(
        (json['genreWeights'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as num).toDouble()),
            ) ??
            {},
      ),
      languageWeights: Map<String, double>.from(
        (json['languageWeights'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as num).toDouble()),
            ) ??
            {},
      ),
      primaryLanguage: json['primaryLanguage'] as String? ?? 'English',
      moodWeights: Map<String, double>.from(
        (json['moodWeights'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as num).toDouble()),
            ) ??
            {},
      ),
      tempoPreference: json['tempoPreference'] as String? ?? 'medium',
      vocalEnergyPreference: json['vocalEnergyPreference'] as String? ?? 'balanced',
      lifecycleState: DnaLifecycleState.values.firstWhere(
        (s) => s.name == json['lifecycleState'],
        orElse: () => DnaLifecycleState.uninitialized,
      ),
      totalBehaviorEvents: json['totalBehaviorEvents'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      lastUpdatedAt: DateTime.tryParse(json['lastUpdatedAt'] as String? ?? '') ?? DateTime.now(),
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      onboardingCompleteness: (json['onboardingCompleteness'] as num?)?.toDouble() ?? 0.0,
      dnaInsightCardDismissed: json['dnaInsightCardDismissed'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreatorDnaProfile &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          creativeRole == other.creativeRole &&
          experienceLevel == other.experienceLevel &&
          primaryLanguage == other.primaryLanguage &&
          tempoPreference == other.tempoPreference &&
          vocalEnergyPreference == other.vocalEnergyPreference &&
          lifecycleState == other.lifecycleState &&
          totalBehaviorEvents == other.totalBehaviorEvents &&
          onboardingCompleted == other.onboardingCompleted &&
          dnaInsightCardDismissed == other.dnaInsightCardDismissed &&
          mapEquals(genreWeights, other.genreWeights) &&
          mapEquals(languageWeights, other.languageWeights) &&
          mapEquals(moodWeights, other.moodWeights);

  @override
  int get hashCode => Object.hash(
        userId,
        creativeRole,
        experienceLevel,
        primaryLanguage,
        tempoPreference,
        vocalEnergyPreference,
        lifecycleState,
        totalBehaviorEvents,
        onboardingCompleted,
        dnaInsightCardDismissed,
      );
}
