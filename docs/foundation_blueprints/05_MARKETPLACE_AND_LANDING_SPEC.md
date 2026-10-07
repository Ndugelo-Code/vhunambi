# Blueprint 05: Beats Marketplace & Native Home Dashboard Specification (`05_MARKETPLACE_AND_LANDING_SPEC.md`)

> **Target Platform:** Flutter 3.x+ / Dart 3.x+ (Windows, macOS, Android, iOS, Web)  
> **Route Paths:** `/market` (Beats Marketplace, Tab 4), `/` / `/home` (Native Creator Dashboard, Tab 0), `/splash`, `/onboarding`  
> **State Management:** Flutter Riverpod 2.x+  
> **Source Origin:** Production Web Client (`https://vhunambi.com` & `https://vhunambi.com/market`) tailored for Native Cross-Platform Application Architecture

---

## 1. Beats Marketplace Specification (`/market`)

The Beats Marketplace enables producers to monetize AI and human-assisted instrumental productions through a peer-to-peer credit economy and commercial synchronization licensing.

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ [ < ] (🎵) VHUNAMBI      [ 🔍 Search beats or producers... ]    [⚡ 10 songs left] [🔔]│ <-- Top Header
└──────────────────────────────────────────────────────────────────────────────────┘
│                                                                                  │
│ 🛍️ Beats Marketplace                                                 [ 🎛 Filters ]│
│ License African beats from top producers — pay in credits, download instantly     │
│                                                                                  │
│                                     ┌────┐                                       │
│                                     │ 🛍️ │   <-- Squircle Container (48x48)      │
│                                     └────┘                                       │
│                                 No beats found                                   │
│              Be the first to list your beat! Open any song in your               │
│                    Library and enable marketplace listing.                       │
│                                                                                  │
│ ┌──────────────────────────────────────────────────────────────────────────────┐ │
│ │ (🪙) Sell your beats                                          [Go to Library]│ │ <-- Monetization Banner
│ │ Create instrumental beats and list them here. Every time someone licenses    │ │     (Amber Glow)
│ │ your beat, credits go straight to your balance.                              │ │
│ └──────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                  │
│ ┌──────────────────────────────────────────────────────────────────────────────┐ │
│ │ [⭳] Install VHUNAMBI                                 [Not now]     [ How? ]  │ │ <-- PWA Install Dock
│ │     Tap to see how to add to home screen                                     │ │
│ └──────────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

### 1.1 Header & Marketplace Navigation Scaffolding

* **Top Bar Layout:**
  * **Leading:** Back chevron (`Icons.arrow_back_ios_new_rounded`, `size: 16`, `#FFFFFF`) + circular brand badge with musical note glyph + `"VHUNAMBI"` wordmark.
  * **Search Input:** Centered pill container (`height: 40px`, background `#141418`, border `1px solid #2D2D38`):
    * Prefix: `Icons.search_rounded` (`#9CA3AF`, `size: 18`).
    * Hint: `"Search beats or producers..."` (`color: #6B7280`, `fontSize: 14`).
  * **Credit Balance Chip:** Pill badge (`#1B1B22`, border `#2D2D38`): `⚡ 10 songs left`.
  * **Notification Bell:** Icon button `🔔` (`#9CA3AF`).
* **Page Header Section:**
  * **Title Row:** Shopping bag icon (`Icons.shopping_bag_outlined`, `color: #F97316`, `size: 26`) + `"Beats Marketplace"` (`fontSize: 28`, `fontWeight: FontWeight.bold`, `#FFFFFF`).
  * **Subtitle:** `"License African beats from top producers — pay in credits, download instantly"` (`fontSize: 14`, `color: #9CA3AF`).
  * **Filter Trigger:** Ghost pill button `🎛 Filters` (`background: #141418`, border `1px solid #2D2D38`, text `#FFFFFF`, `fontSize: 13`).

---

### 1.2 Seller Monetization Callout Banner

An elevated conversion banner educating creators on listing instrumental tracks for passive credit generation:

* **Container Styling:**
  * Background: `#141418` (`surfaceElevated`).
  * Border: `1px solid rgba(249, 115, 22, 0.35)` with a subtle amber ambient glow (`BoxShadow(color: Color(0x1AF97316), blurRadius: 16)`).
  * Corner Radius: `16px` (`AppRadius.card`).
  * Padding: `20px 24px`.
* **Left Emblem Badge:**
  * Circular container (`44x44px`), surface `#3A2508` (Dark amber inset).
  * Icon: Dual stacked coins / transaction glyph (`Icons.monetization_on_outlined` or `savings_outlined`, `color: #F59E0B`, `size: 22`).
* **Content Stack:**
  * Headline: `"Sell your beats"` (`fontSize: 18`, `fontWeight: FontWeight.bold`, `#FFFFFF`).
  * Body: `"Create instrumental beats and list them here. Every time someone licenses your beat, credits go straight to your balance."` (`fontSize: 13`, `color: #9CA3AF`, line-height `1.5`).
* **Action CTA:**
  * Button: Solid orange pill `"Go to Library"` (`background: #F97316`, text `#000000`, `fontWeight: FontWeight.bold`).
  * Route: Pushes `/library` with tab query parameter `?tab=beats`.

---

### 1.3 Empty State & Populated Listing Models

#### 1. Empty State Specification
* **Glyph Container:** Centered `48x48px` squircle container (`#141418`, border `1px solid #2D2D38`, radius `14px`).
* **Icon:** Outlined shopping bag (`Icons.shopping_bag_outlined`, `size: 22`, `#FFFFFF`).
* **Headline:** `"No beats found"` (`fontSize: 20`, `fontWeight: FontWeight.bold`, `#FFFFFF`).
* **Subtext:** `"Be the first to list your beat! Open any song in your Library and enable marketplace listing."` (`fontSize: 14`, `color: #9CA3AF`, centered).

#### 2. Populated Beat Card Specification (2-to-4 Column Grid)
When listings exist, each card displays:
* **Artwork Container (`1:1` aspect ratio):**
  * Dynamic genre gradient background with instrument vector emblem.
  * Badges: BPM badge (`112 BPM`, top-left) and Musical Key badge (`F# Minor`, top-right).
* **Playback Overlay:** Circular orange play button (`36x36px`) to audition high-quality preview stream.
* **Metadata Column:**
  * Beat Title: `fontSize: 15`, `fontWeight: FontWeight.w600`, `#FFFFFF`.
  * Producer Tag: `@producer_handle` with verified badge.
  * Genre / Tags: `Amapiano • Log Drum • Club Mix`.
* **Licensing Action Footer:**
  * Price Tag: `⚡ 5 Credits` (`fontSize: 14`, `fontWeight: FontWeight.bold`, `#F97316`).
  * Action Button: `"License Beat"` (invokes license modal confirming stem package download).

---

### 1.4 PWA / Mobile Client Installation Banner

A persistent floating dock prompting users to install the application:

* **Position:** Fixed floating dock above bottom navigation (`horizontal margin: 16px`, `bottom: 76px` on mobile).
* **Surface:** `#16161C` modal surface, border `1px solid #2D2D38`, radius `14px`, padding `12px 16px`.
* **Left Icon Container:** Rounded squircle (`40x40px`, `#2D2D38` surface) with download tray icon (`Icons.download_rounded`, `#F97316`).
* **Text Stack:**
  * Title: `"Install VHUNAMBI"` (`fontSize: 14`, `fontWeight: FontWeight.bold`, `#FFFFFF`).
  * Subtitle: `"Tap to see how to add to home screen"` (`fontSize: 12`, `#9CA3AF`).
* **Right Action Group:**
  * Dismiss: Text button `"Not now"` (`color: #9CA3AF`, `fontSize: 13`).
  * Primary Trigger: Solid orange pill button `"How?"` (`background: #F97316`, `color: #000000`, `fontSize: 13`, `fontWeight: FontWeight.bold`).

---

## 2. Native Home Dashboard, Splash & Onboarding Architecture (`/home`, `/splash`, `/onboarding`)

In native mobile/desktop client applications (Android, iOS, Windows, macOS), users do not navigate web marketing funnels on Tab 0. The client architecture provides:
1. **Startup Splash Screen (`/splash`):** Brand emblem reveal, African rhythm glow, Tshivenḓa motto (*"the talent to sing"*), and app initialization.
2. **First-Run Onboarding (`/onboarding`):** 3-step interactive onboarding for heritage genre and indigenous language preferences.
3. **Native Creator Home Dashboard (`/home`, Tab Index 0):** Personalized greeting (*"Ndi matsheloni"* / *"Sawubona"*), "What are you feeling today?" studio quick prompt bar, 4-card quick actions (Studio, Beats, Vault, Stems), "Jump Back In" recent session player, daily African rhythm spotlight, community recommendations, and in-app subscription upgrade modal trigger.
4. **In-App Subscription Modal:** The 4 pricing tiers (Free, Creator, Pro, Studio) and testimonials live in an in-app bottom sheet modal dialog (`SubscriptionUpgradeModal`), accessible whenever the user taps the credit token chip (`⚡ 10 songs left`) or the dashboard upgrade banner.

---

### 2.1 Hero Section & Interactive Audio Showcase

```
┌────────────────────────────────────────────────────────────────────────┐
│                        [ ⚡ New: African AI Music ]                    │
│                                                                        │
│                      Create African Music                              │
│                      with a Single Prompt                              │
│                                                                        │
│        Type an idea, pick a genre, and create high-quality songs       │
│        with authentic African rhythms and indigenous languages.        │
│                                                                        │
│  ┌─────────────────────────────────────────────────────────┬─────────┐ │
│  │ A powerful amapiano anthem about rising from hardship...│Generate │ │
│  └─────────────────────────────────────────────────────────┴─────────┘ │
│                                                                        │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                                                                  │  │
│  │                    [ CINEMATIC HERO IMAGE ]                      │  │
│  │                                                                  │  │
│  │  (▶) Limpopo Sunset • Amapiano • Tshivenḓa   ılılıllı|ı|ı|lılıl   │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

* **Pill Pill Badge:** Top-centered pill `[ ⚡ New: African AI Music ]` (`background: rgba(249,115,22,0.15)`, border `1px solid #F97316`, text `#F97316`, `fontSize: 12`).
* **H1 Headline:** `"Create African Music with a Single Prompt"`:
  * Typography: `fontSize: 44` (Desktop) / `32` (Mobile), `fontWeight: FontWeight.w800`.
  * Highlighting: `"African Music"` painted with a vibrant orange-to-amber text gradient (`#F97316` $\rightarrow$ `#F59E0B`).
* **Subtitle:** `"Type an idea, pick a genre, and create high-quality songs with authentic African rhythms and indigenous languages."` (`fontSize: 16`, `color: #9CA3AF`, centered).
* **Quick-Prompt Generation Input Bar:**
  * Full-width pill container (`height: 52px`, background `#141418`, border `1px solid #2D2D38`).
  * Text area / TextField: `"A powerful amapiano anthem about rising from hardship..."`.
  * Integrated Action Button: Solid orange pill `"Generate"` with sparkle glyph (`#F97316`, text `#000000`).
* **Hero Audio Showcase Card:**
  * Cinematic artwork of African vocalists with traditional styling.
  * Embedded Playback Bar:
    * Play Trigger: Circular amber button `(▶)`.
    * Track Title: `"Limpopo Sunset"` (Amapiano • Tshivenḓa).
    * Reactive Real-time Waveform Scrubber.

---

### 2.2 Social Proof Counters Strip

A 3-column metric banner proving platform adoption:

| Metric Value | Metric Description | Icon / Treatment |
| :---: | :--- | :--- |
| **`210+`** | Songs Created | Amber icon badge (`Icons.music_note_rounded`) |
| **`27+`** | Active Musicians & Producers | Indigo icon badge (`Icons.people_outline_rounded`) |
| **`1,008`** | Total Community Likes | Rose icon badge (`Icons.favorite_rounded`) |

---

### 2.3 "How It Works" 3-Step Guided Workflow

```
┌────────────────────────┐  ┌────────────────────────┐  ┌────────────────────────┐
│ 01 ✍️                  │  │ 02 ⚡                  │  │ 03 🚀                  │
│ Describe your song     │➔ │ AI generates it        │➔ │ Share with the world   │
│ Theme, mood, lyrics    │  │ Authentic rhythms &    │  │ Download MP3s, stems,  │
│ or story prompt.       │  │ lyrics in < 60s.       │  │ or share to WhatsApp.  │
└────────────────────────┘  └────────────────────────┘  └────────────────────────┘
```

1. **Step 01 (`Describe your song`):** Warm amber accent border. *"Type what you feel — a story, mood, or lyric idea. Pick your genre, language, and tempo."*
2. **Step 02 (`AI generates it`):** Tangerine orange accent border. *"Vhunambi writes indigenous lyrics and produces authentic regional rhythms in under 60 seconds."*
3. **Step 03 (`Share with the world`):** Emerald green accent border. *"Download studio-quality MP3s, separate stems, or share directly to WhatsApp and streaming platforms."*
* **Section CTA:** Solid orange pill `✨ Try it now — It's free`.

---

### 2.4 African Musical Heritage Showcase ("Every Sound on Earth")

Interactive 20+ genre grid with regional tabs (`All`, `South Africa`, `West Africa`, `East Africa`, `Central Africa`):
* `Amapiano`, `Kwaito`, `Gqom`, `Maskandi`, `Mbaqanga`, `Afro House`, `Afrobeats`, `Afro Jazz`, `Afro Soul`, `Highlife`, `Chimurenga`, `Bongo Flava`, `Soukous`, `Makompo`, `Marabi`, `Bubblegum`, `Rumba`, `Kuduro`.

---

### 2.5 Core Value Pillars (6 Feature Cards)

A 3x2 responsive card grid (`#141418` surface, `1px solid #2D2D38` border, `16px` radius):

1. **AI-Powered Generation:** State-of-the-art diffusion audio models trained specifically on African acoustic instruments and rhythmic syncopation.
2. **Multilingual Linguistic Engine:** Full fluency in Tshivenḓa, isiZulu, isiXhosa, Swahili, Yoruba, Hausa, Amharic, and English.
3. **African Genres First:** Amapiano log drums, Maskandi folk finger-picking, and Afrobeat brass treated as first-class citizens.
4. **Collaborate in Real Time:** Invite co-producers, split stems, and iterate on lyric sheets together in cloud studio rooms.
5. **Download & Full Ownership:** Retain 100% of your copyright on paid plans with high-bitrate MP3, WAV, and stem exports.
6. **Direct WhatsApp & Social Sharing:** Native one-tap export formatted directly for WhatsApp status, TikTok, and Instagram Reels.

---

### 2.6 Multilingual Cultural Translation Spotlight

A side-by-side comparative card highlighting cultural authenticity:

* **Left Card (`Generic AI Translation`):**
  * Border: `#EF4444` (Muted red).
  * Text: *"Literal machine translation lacking rhythm, cultural idioms, or proverb depth."*
* **Right Card (`Vhunambi Indigenous Synthesis`):**
  * Border: `#10B981` (Vibrant emerald).
  * Text: *"Culturally resonant lyrics using native Tshivenḓa and isiZulu idioms, respectful proverb usage, and syllabic cadence matching African meters."*

---

### 2.7 Creator Testimonial Wall

Verified creator review cards with star ratings (`⭐⭐⭐⭐⭐`), author avatar, creator handle, and geographic location:
* **Thohoyandou, Limpopo:** *"Finally, an AI that understands Tshivenḓa phonetics and doesn't sound robotic."*
* **Johannesburg, Gauteng:** *"The log drum synthesis in Amapiano mode is indistinguishable from my FL Studio templates."*
* **Nairobi, Kenya:** *"Genius tool for Gengetone and Bongo Flava songwriting."*
* **Lagos, Nigeria:** *"Afrobeats syncopation and Pidgin phrasing are spot on."*

---

### 2.8 Pricing & Credit Matrix ("Start Free, Scale Up")

4-tier subscription cards with billing cycle toggle (`Monthly` / `Yearly - Save 20%`):

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│     Free     │  │   Creator    │  │     Pro      │  │    Studio    │
│    $0/mo     │  │    $9/mo     │  │    $29/mo    │  │   $119/mo    │
├──────────────┤  ├──────────────┤  ├──────────────┤  ├──────────────┤
│ 10 songs/mo  │  │ 400 songs/mo │  │2,000 songs/mo│  │20,000 songs/m│
│ Standard MP3 │  │ High Quality │  │ Lossless WAV │  │ Lossless WAV │
│ Community    │  │ Priority     │  │ 4 Stems Split│  │ Stems + MIDI │
│ Public Feed  │  │ Commercial   │  │ Full License │  │ Team + API   │
├──────────────┤  ├──────────────┤  ├──────────────┤  ├──────────────┤
│ [Get Started]│  │ [Subscribe]  │  │ [Go Pro ★]   │  │[Contact Us]  │
└──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘
```

* **Enterprise Callout:** *"Need a custom enterprise plan? Contact our sales team ➔"*.

---

### 2.9 Closing CTA & Global Footer

* **Hero Banner:** `"The voice of Africa is yours — Create Your First Song"` (`#F97316` button).
* **Footer Navigation:**
  * **Brand Column:** Logo, Tshivenḓa mission statement, copyright notice.
  * **Product Links:** Explore, Studio, Library, Marketplace, Mobile PWA.
  * **Legal & Commercial:** Terms of Service, Privacy Policy, Commercial Licensing Agreement, DMCA.

---

## 3. Data Models & Riverpod Providers

```dart
// lib/features/marketplace/domain/models/beat_listing_entity.dart
import 'package:flutter/foundation.dart';

@immutable
class BeatListingEntity {
  final String id;
  final String title;
  final String producerId;
  final String producerName;
  final String producerAvatarUrl;
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
    required this.producerAvatarUrl,
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

### Riverpod Providers Contract

```dart
// lib/features/marketplace/presentation/providers/marketplace_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/beat_listing_entity.dart';

final marketplaceFilterProvider = StateProvider<MarketplaceFilterState>(
  (ref) => const MarketplaceFilterState(),
);

final marketplaceBeatsProvider = FutureProvider<List<BeatListingEntity>>((ref) async {
  final filter = ref.watch(marketplaceFilterProvider);
  // Fetch from Supabase marketplace_beats table applying active filter parameters
  return [];
});
```
