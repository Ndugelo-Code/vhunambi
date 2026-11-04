# Phase 39 Design: Creator Identity, Discovery Hierarchy & Talent Marketplace

**Document Version:** 1.0.0  
**Status:** Approved for Implementation  
**Predecessor:** Phase 38 Design  
**Target:** `apps/vhunambi_client` & `apps/vhunambi_api`  

---

## 1. Track B: Architecture & Data Models

### 1.1 Creator Identity Archetypes (`profile_models.dart`)
```dart
enum CreatorIdentityArchetype {
  dawProducer,
  naturalVocalist,
  liveInstrumentalist,
  kineticPerformer,
  aiSonicArchitect,
}

extension CreatorIdentityArchetypeExtension on CreatorIdentityArchetype {
  String get displayName => switch (this) {
    CreatorIdentityArchetype.dawProducer => 'DAW Producer',
    CreatorIdentityArchetype.naturalVocalist => 'Natural Vocalist',
    CreatorIdentityArchetype.liveInstrumentalist => 'Live Instrumentalist',
    CreatorIdentityArchetype.kineticPerformer => 'Kinetic Performer',
    CreatorIdentityArchetype.aiSonicArchitect => 'AI Sonic Architect',
  };

  IconData get icon => switch (this) {
    CreatorIdentityArchetype.dawProducer => PhosphorIconsRegular.slidersHorizontal,
    CreatorIdentityArchetype.naturalVocalist => PhosphorIconsRegular.microphone,
    CreatorIdentityArchetype.liveInstrumentalist => PhosphorIconsRegular.guitar,
    CreatorIdentityArchetype.kineticPerformer => PhosphorIconsRegular.personSimpleRun,
    CreatorIdentityArchetype.aiSonicArchitect => PhosphorIconsRegular.sparkle,
  };
}
```

### 1.2 Audio Provenance Types (`profile_models.dart` or `track.dart`)
```dart
enum AudioProvenanceType {
  humanDawMaster,
  liveVocalRecording,
  liveInstrumentStem,
  hybridCoCreation,
  aiGenerated,
}

extension AudioProvenanceTypeExtension on AudioProvenanceType {
  String get displayName => switch (this) {
    AudioProvenanceType.humanDawMaster => 'Human DAW Master',
    AudioProvenanceType.liveVocalRecording => '100% Live Vocal',
    AudioProvenanceType.liveInstrumentStem => 'Live Instrument',
    AudioProvenanceType.hybridCoCreation => 'Hybrid Co-Creation',
    AudioProvenanceType.aiGenerated => 'Vhunambi AI',
  };

  IconData get icon => switch (this) {
    AudioProvenanceType.humanDawMaster => PhosphorIconsRegular.slidersHorizontal,
    AudioProvenanceType.liveVocalRecording => PhosphorIconsRegular.microphone,
    AudioProvenanceType.liveInstrumentStem => PhosphorIconsRegular.musicNotes,
    AudioProvenanceType.hybridCoCreation => PhosphorIconsRegular.gitFork,
    AudioProvenanceType.aiGenerated => PhosphorIconsRegular.sparkle,
  };
}
```

### 1.3 Direct DAW / Vocal Uploader Sheet (`direct_daw_vocal_upload_sheet.dart`)
```
┌────────────────────────────────────────────────────────┐
│ DIRECT DAW & VOCAL UPLOADER WORKSTATION               [X]│
│ ────────────────────────────────────────────────────── │
│ [ 🎛️ DAW Master ] [ 🎙️ Live Vocal/Stem ] [ 💃 Dance Reel ] │
│                                                        │
│ ┌────────────────────────────────────────────────────┐ │
│ │  Drag & drop .wav / .mp3 master or stems           │ │
│ │  [ 📁 Browse Files ] (FL Studio / Ableton / Logic) │ │
│ └────────────────────────────────────────────────────┘ │
│ Title:    [ Durban Kwaito 120 Master              ]   │
│ Genre:    [ Kwaito              ▼ ] BPM: [ 120   ]    │
│ Key:      [ F# Minor            ▼ ]                   │
│ Provenance: [ 🎛️ Human DAW Master (100% Audio)     ▼ ] │
│                                                        │
│ [x] Publish to Explore Feed                            │
│ [x] List Stems on /market for 85% ZAR Royalties        │
│                                                        │
│ [           🚀 PUBLISH TO EXPLORE & VAULT            ] │
└────────────────────────────────────────────────────────┘
```

---

## 2. Track C: 3-Stage Discovery Hierarchy

### 2.1 Discovery Hierarchy Ranker (`discovery_hierarchy_ranker.dart`)
```dart
enum DiscoveryStageTier {
  mainstage,
  risingBreakout,
  freshCrate,
}

class DiscoveryRankResult {
  final SocialMusicPost post;
  final double score;
  final DiscoveryStageTier tier;

  const DiscoveryRankResult({
    required this.post,
    required this.score,
    required this.tier,
  });
}

class DiscoveryHierarchyRanker {
  static DiscoveryRankResult rank(SocialMusicPost post) {
    // 1. Completion & Play Velocity (0-100)
    final completionVelocity = (post.track.playCount * 0.4).clamp(0.0, 100.0);

    // 2. Co-Creation Remix & Repost Pull (0-100)
    final remixPull = ((post.remixCount * 12.0) + (post.repostCount * 6.0)).clamp(0.0, 100.0);

    // 3. Creator Influence (0-100)
    final creatorInfluence = ((post.likeCount * 0.5) + (post.isCreatorVerified ? 20.0 : 0.0)).clamp(0.0, 100.0);

    // 4. Craft & Provenance Bonus
    final craftBonus = switch (post.provenanceType) {
      AudioProvenanceType.humanDawMaster => 100.0,
      AudioProvenanceType.liveVocalRecording => 100.0,
      AudioProvenanceType.liveInstrumentStem => 90.0,
      AudioProvenanceType.hybridCoCreation => 75.0,
      AudioProvenanceType.aiGenerated => 50.0,
    };

    final totalScore = (completionVelocity * 0.30) +
        (remixPull * 0.25) +
        (creatorInfluence * 0.20) +
        (craftBonus * 0.25);

    final tier = totalScore >= 70.0
        ? DiscoveryStageTier.mainstage
        : (totalScore >= 35.0
            ? DiscoveryStageTier.risingBreakout
            : DiscoveryStageTier.freshCrate);

    return DiscoveryRankResult(post: post, score: totalScore, tier: tier);
  }
}
```

---

## 3. Track D: 4-Pillar Multi-Talent Marketplace

### 3.1 Asset Categories & Filter State (`marketplace_models.dart`)
```dart
enum MarketplaceAssetCategory {
  all,
  beats,
  vocals,
  liveInstruments,
  voiceDnaAndPacks,
}

extension MarketplaceAssetCategoryExtension on MarketplaceAssetCategory {
  String get label => switch (this) {
    MarketplaceAssetCategory.all => 'All Assets',
    MarketplaceAssetCategory.beats => 'Beats & Instrumentals',
    MarketplaceAssetCategory.vocals => 'Vocal Hooks & Acapellas',
    MarketplaceAssetCategory.liveInstruments => 'Live Guitars, Sax & Loops',
    MarketplaceAssetCategory.voiceDnaAndPacks => 'Voice DNA & Packs',
  };
}
```

### 3.2 Category Navigation on `MarketplaceView`
A horizontal scrollable switcher of frosted category pills anchored directly under the search bar:
- `Key('market_category_tab_all')`
- `Key('market_category_tab_beats')`
- `Key('market_category_tab_vocals')`
- `Key('market_category_tab_liveInstruments')`
- `Key('market_category_tab_voiceDnaAndPacks')`

---

## 4. Track E: Contrast & Testing Architecture

All new and updated widgets adhere strictly to:
- Surfaces: `AppColors.surfaceElevatedOf(context)` / `AppColors.surfaceSecondaryOf(context)`
- Texts: `AppColors.textPrimaryOf(context)` / `AppColors.textSecondaryOf(context)`
- Borders: `AppColors.borderSubtleOf(context)`
- Accents: `AppColors.brandPrimary`, `AppColors.badgeCyan`, `AppColors.coinGold`
- Zero unconstrained animations in tests; zero hydration errors.

