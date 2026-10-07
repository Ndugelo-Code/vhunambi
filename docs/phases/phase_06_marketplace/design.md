# Phase 6 Design Specification: Beats Marketplace & Marketing Funnel (`/market` & `/`)

> **Package:** `apps/vhunambi_client`  
> **Feature Directories:** `lib/features/marketplace/` & `lib/features/landing/`  
> **State Engine:** Flutter Riverpod 2.x+

---

## 1. Domain Models & Enums

### 1.1 Marketplace Entities (`lib/features/marketplace/domain/models/marketplace_models.dart`)
```dart
@immutable
class BeatListingEntity {
  final String id;
  final String title;
  final String producerId;
  final String producerName;
  final String producerHandle;
  final String? producerAvatarUrl;
  final String genre;
  final int bpm;
  final String musicalKey;
  final int priceInCredits;
  final String previewAudioUrl;
  final String? stemZipUrl;
  final String licenseType;
  final int totalSales;
  final DateTime createdAt;

  const BeatListingEntity({
    required this.id,
    required this.title,
    required this.producerId,
    required this.producerName,
    required this.producerHandle,
    this.producerAvatarUrl,
    required this.genre,
    required this.bpm,
    required this.musicalKey,
    required this.priceInCredits,
    required this.previewAudioUrl,
    this.stemZipUrl,
    this.licenseType = 'Non-Exclusive Commercial',
    this.totalSales = 0,
    required this.createdAt,
  });

  String get bpmLabel => '$bpm BPM';
  String get priceLabel => '⚡ $priceInCredits Credits';
}

@immutable
class MarketplaceFilterState {
  final String searchQuery;
  final String genre;
  final int? minBpm;
  final int? maxBpm;
  final int? maxPriceCredits;

  const MarketplaceFilterState({
    this.searchQuery = '',
    this.genre = 'All',
    this.minBpm,
    this.maxBpm,
    this.maxPriceCredits,
  });

  MarketplaceFilterState copyWith({
    String? searchQuery,
    String? genre,
    int? minBpm,
    int? maxBpm,
    int? maxPriceCredits,
  }) {
    return MarketplaceFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      genre: genre ?? this.genre,
      minBpm: minBpm ?? this.minBpm,
      maxBpm: maxBpm ?? this.maxBpm,
      maxPriceCredits: maxPriceCredits ?? this.maxPriceCredits,
    );
  }
}
```

### 1.2 Landing & Pricing Entities (`lib/features/landing/domain/models/landing_models.dart`)
```dart
enum BillingCycle {
  monthly,
  yearly,
}

@immutable
class PricingTier {
  final String id;
  final String name;
  final int monthlyPrice;
  final int yearlyPrice;
  final String songAllowance;
  final String audioQuality;
  final String licenseScope;
  final List<String> features;
  final bool isPopular;
  final String ctaLabel;

  const PricingTier({
    required this.id,
    required this.name,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.songAllowance,
    required this.audioQuality,
    required this.licenseScope,
    required this.features,
    this.isPopular = false,
    required this.ctaLabel,
  });

  int priceFor(BillingCycle cycle) => cycle == BillingCycle.yearly ? yearlyPrice : monthlyPrice;
}

@immutable
class CreatorTestimonial {
  final String id;
  final String authorName;
  final String handle;
  final String location;
  final String quote;
  final int rating;
  final String? avatarUrl;

  const CreatorTestimonial({
    required this.id,
    required this.authorName,
    required this.handle,
    required this.location,
    required this.quote,
    this.rating = 5,
    this.avatarUrl,
  });
}

@immutable
class ValuePillar {
  final String title;
  final String description;
  final IconData iconData;

  const ValuePillar({
    required this.title,
    required this.description,
    required this.iconData,
  });
}
```

---

## 2. Riverpod State Providers

### 2.1 Marketplace Providers (`lib/features/marketplace/presentation/providers/marketplace_providers.dart`)
```dart
final marketplaceFilterProvider = StateProvider<MarketplaceFilterState>(
  (ref) => const MarketplaceFilterState(),
);

final marketplaceBeatsProvider = StateNotifierProvider<MarketplaceBeatsNotifier, List<BeatListingEntity>>((ref) {
  return MarketplaceBeatsNotifier();
});

final filteredBeatsProvider = Provider<List<BeatListingEntity>>((ref) {
  final beats = ref.watch(marketplaceBeatsProvider);
  final filter = ref.watch(marketplaceFilterProvider);

  return filterBeats(beats: beats, filter: filter);
});

void auditionBeat(WidgetRef ref, BeatListingEntity beat) {
  final playerNotifier = ref.read(playerStateProvider.notifier);
  final track = Track(
    id: beat.id,
    title: beat.title,
    creatorName: beat.producerName,
    creatorHandle: beat.producerHandle,
    genre: beat.genre,
    duration: const Duration(seconds: 180),
    audioUrl: beat.previewAudioUrl,
  );
  playerNotifier.playTrack(track);
}
```

### 2.2 Landing Providers (`lib/features/landing/presentation/providers/landing_providers.dart`)
```dart
final pricingBillingCycleProvider = StateProvider<BillingCycle>(
  (ref) => BillingCycle.monthly,
);

final pricingTiersProvider = Provider<List<PricingTier>>((ref) {
  return const [
    PricingTier(
      id: 'free',
      name: 'Free',
      monthlyPrice: 0,
      yearlyPrice: 0,
      songAllowance: '10 songs/mo',
      audioQuality: 'Standard MP3',
      licenseScope: 'Community Public Feed',
      features: ['10 songs per month', 'Standard MP3 bitrate', 'Community generation feed', 'Basic genre selection'],
      ctaLabel: 'Get Started',
    ),
    PricingTier(
      id: 'creator',
      name: 'Creator',
      monthlyPrice: 9,
      yearlyPrice: 7,
      songAllowance: '400 songs/mo',
      audioQuality: 'High Quality MP3',
      licenseScope: 'Commercial Sync',
      features: ['400 songs per month', 'High Quality 320kbps MP3', 'Priority generation queue', '100% Commercial rights', 'Private generation mode'],
      ctaLabel: 'Subscribe',
    ),
    PricingTier(
      id: 'pro',
      name: 'Pro',
      monthlyPrice: 29,
      yearlyPrice: 23,
      songAllowance: '2,000 songs/mo',
      audioQuality: 'Lossless WAV',
      licenseScope: 'Full Commercial & Stems',
      features: ['2,000 songs per month', 'Lossless 24-bit WAV', '4-Stem isolation (Vocals, Drums, Bass, Instruments)', 'Full commercial license + split sheets', 'Beat marketplace listing privileges'],
      isPopular: true,
      ctaLabel: 'Go Pro ★',
    ),
    PricingTier(
      id: 'studio',
      name: 'Studio',
      monthlyPrice: 119,
      yearlyPrice: 95,
      songAllowance: '20,000 songs/mo',
      audioQuality: 'Lossless WAV + MIDI',
      licenseScope: 'Team API & White-label',
      features: ['20,000 songs per month', 'Lossless WAV + MIDI stems', 'Multi-seat team workspace', 'Dedicated audio synthesis API', 'Enterprise licensing support'],
      ctaLabel: 'Contact Us',
    ),
  ];
});

final creatorTestimonialsProvider = Provider<List<CreatorTestimonial>>((ref) {
  return const [
    CreatorTestimonial(id: 't1', authorName: 'Thabo M.', handle: '@thabo_thohoyandou', location: 'Thohoyandou, Limpopo', quote: 'Finally, an AI that understands Tshivenḓa phonetics and authentic African meters without robotic artifacts.'),
    CreatorTestimonial(id: 't2', authorName: 'Sipho Khumalo', handle: '@sipho_beats', location: 'Johannesburg, Gauteng', quote: 'The log drum synthesis in Amapiano mode is indistinguishable from my custom FL Studio templates.'),
    CreatorTestimonial(id: 't3', authorName: 'Amina Osei', handle: '@amina_music', location: 'Nairobi, Kenya', quote: 'A revelation for Gengetone and Bongo Flava rhythm production. The speed of workflow is incredible.'),
    CreatorTestimonial(id: 't4', authorName: 'Adeola Balogun', handle: '@adeola_sound', location: 'Lagos, Nigeria', quote: 'Afrobeats brass syncopation and Pidgin cadence are dead-on. High quality output every time.'),
  ];
});
```

---

## 3. Widget Tree & Hierarchy

### 3.1 Marketplace (`MarketplaceView`)
```
MarketplaceView (Scaffold with CustomScrollView)
├── SliverToBoxAdapter: MarketplaceTopBar (Back, brand, search, credit chip, bell)
├── SliverToBoxAdapter: MarketplaceHeader (Shopping bag icon, title, subtitle, filter trigger)
├── SliverToBoxAdapter: SellerCalloutBanner (Amber glow, coin icon, "Go to Library" CTA)
├── SliverPadding -> SliverGrid: BeatCard (4-col Desktop / 2-col Mobile)
│   ├── Dynamic genre gradient artwork
│   ├── BPM & Key badges
│   ├── Play audition button
│   ├── Title, producer handle, tags
│   └── Price & "License Beat" CTA
├── SliverToBoxAdapter: MarketplaceEmptyState (when 0 matches)
└── Stack / Overlay: PwaInstallDock (Floating install prompt)
```

### 3.2 Landing Funnel (`HomeLandingView`)
```
HomeLandingView (SingleChildScrollView / CustomScrollView)
├── LandingHeroSection (New AI badge, H1 with gradient, subtitle, prompt input, sample audio card)
├── SocialProofCounters (210+ songs, 27+ musicians, 1,008 likes)
├── HowItWorksSection (3 workflow cards: Describe, Generate, Share + CTA)
├── HeritageGenreShowcase (20+ African genres, regional tabs)
├── ValuePillarsGrid (6 feature cards: AI, Multilingual, African 1st, Collaborate, Ownership, WhatsApp)
├── CulturalTranslationSpotlight (Generic AI vs Vhunambi Indigenous side-by-side)
├── TestimonialsWall (4 creator review cards with star ratings)
├── PricingMatrixSection (Monthly/Yearly toggle, 4 pricing cards)
└── LandingFooter (Tshivenḓa mission, product links, legal links)
```

---

## 4. Shell Integration (`lib/main.dart`)
- Tab Index 0: `HomeLandingView(onGetStarted: () => setState(() => _currentIndex = 2))`
- Tab Index 4: `MarketplaceView(onNavigateToLibrary: () => setState(() => _currentIndex = 3))`
