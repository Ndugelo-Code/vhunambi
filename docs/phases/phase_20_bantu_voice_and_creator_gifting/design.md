# Phase 20 · Design — Bantu Voice LoRA Synthesis & Creator Cultural Micro-Gifting

> **Phase:** 20  
> **Codename:** `bantu-voice-and-creator-gifting`  
> **Status:** 🟡 SPECIFICATION  
> **Target Apps:** `apps/vhunambi_client`  
> **Architecture Standard:** Dual-Agent Pair Programming Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  

---

## 1. Domain Models & Entities

### 1.1 `BantuVoiceProfile` Entity
```dart
// lib/features/studio/domain/models/bantu_voice_profile.dart

import 'package:flutter/foundation.dart';

@immutable
class BantuVoiceProfile {
  final String id;
  final String name;
  final String language;
  final String region;
  final String timbreDescription;
  final String iconEmoji;
  final double loraScale;
  final List<String> characteristicAdLibs;

  const BantuVoiceProfile({
    required this.id,
    required this.name,
    required this.language,
    required this.region,
    required this.timbreDescription,
    required this.iconEmoji,
    this.loraScale = 0.85,
    this.characteristicAdLibs = const [],
  });
}
```

### 1.2 `DialectInflectionConfig` Entity
```dart
// lib/features/studio/domain/models/dialect_inflection_config.dart

import 'package:flutter/foundation.dart';

@immutable
class DialectInflectionConfig {
  final double vowelElongation; // 0.0 - 1.0 (Penultimate stretch)
  final double vibratoDepth; // 0.0 - 1.0 (Resonance)
  final double callAndResponseIntensity; // 0.0 - 1.0 (Choir backing)
  final double adLibFrequency; // 0.0 - 1.0 (Cultural shouts)

  const DialectInflectionConfig({
    this.vowelElongation = 0.5,
    this.vibratoDepth = 0.4,
    this.callAndResponseIntensity = 0.6,
    this.adLibFrequency = 0.5,
  });

  DialectInflectionConfig copyWith({
    double? vowelElongation,
    double? vibratoDepth,
    double? callAndResponseIntensity,
    double? adLibFrequency,
  }) {
    return DialectInflectionConfig(
      vowelElongation: vowelElongation ?? this.vowelElongation,
      vibratoDepth: vibratoDepth ?? this.vibratoDepth,
      callAndResponseIntensity: callAndResponseIntensity ?? this.callAndResponseIntensity,
      adLibFrequency: adLibFrequency ?? this.adLibFrequency,
    );
  }
}
```

### 1.3 `CulturalGift` Entity
```dart
// lib/features/social/domain/models/cultural_gift.dart

import 'package:flutter/foundation.dart';

@immutable
class CulturalGift {
  final String id;
  final String name;
  final String emoji;
  final int coinPrice;
  final double zarPrice;
  final String culturalMeaning;

  const CulturalGift({
    required this.id,
    required this.name,
    required this.emoji,
    required this.coinPrice,
    required this.zarPrice,
    required this.culturalMeaning,
  });
}

const List<CulturalGift> kCulturalGifts = [
  CulturalGift(
    id: 'cowrie_shell',
    name: 'Cowrie Shell (Mbaḓi)',
    emoji: '🐚',
    coinPrice: 5,
    zarPrice: 2.0,
    culturalMeaning: 'Ancient African currency representing honor and lasting appreciation.',
  ),
  CulturalGift(
    id: 'african_drum',
    name: 'African Drum (Ngoma)',
    emoji: '🥁',
    coinPrice: 15,
    zarPrice: 5.0,
    culturalMeaning: 'Sacred rhythm salute honoring the heartbeat of the track.',
  ),
  CulturalGift(
    id: 'log_drum_trophy',
    name: 'Log Drum Trophy (Tshikona)',
    emoji: '🎹',
    coinPrice: 50,
    zarPrice: 15.0,
    culturalMeaning: 'Trophy for top-tier Amapiano bassline mastery and sonic innovation.',
  ),
  CulturalGift(
    id: 'royal_venda_crown',
    name: 'Royal Venda Crown (Khare)',
    emoji: '👑',
    coinPrice: 200,
    zarPrice: 50.0,
    culturalMeaning: 'Royal crown honor reserved for master producers and legendary artists.',
  ),
];
```

---

## 2. Riverpod State Providers

### 2.1 `CreatorWalletNotifier` & Provider
```dart
// lib/features/social/presentation/providers/creator_wallet_provider.dart

class CreatorWalletState {
  final int userCoinsBalance;
  final double creatorEarnedZar;
  final int creatorReceivedCoins;
  final List<GiftTransaction> transactions;

  const CreatorWalletState({
    this.userCoinsBalance = 250,
    this.creatorEarnedZar = 1420.0,
    this.creatorReceivedCoins = 4750,
    this.transactions = const [],
  });
}

class CreatorWalletNotifier extends StateNotifier<CreatorWalletState> {
  // sendGift, requestPayout, topUpCoins
}
```

### 2.2 Studio Form Enhancements
Extend `StudioFormState` with:
- `selectedVoiceProfile`: `BantuVoiceProfile`
- `dialectInflection`: `DialectInflectionConfig`

---

## 3. UI Widgets & Presentation

1. **`BantuVoiceDeck`** (`lib/features/studio/presentation/widgets/bantu_voice_deck.dart`):
   - Timbre selection cards (👴 Venda Elder, 🎤 Soweto Soul, ⚡ Gqom Chanter, etc.).
   - Inflection sliders with percentage labels and cultural context annotations.
2. **`LivePhoneticAlignmentPreview`** (`lib/features/studio/presentation/widgets/live_phonetic_alignment_preview.dart`):
   - Highlighted phonetic chips identifying dental consonants (`ḓ`, `ṱ`) and click sounds (`c`, `q`, `x`).
3. **`CreatorTippingSheet`** (`lib/features/social/presentation/widgets/creator_tipping_sheet.dart`):
   - 2x2 grid of cultural gifts, balance counter, message input, Send Gift action.
4. **`CreatorWalletDeck`** (`lib/features/profile/presentation/widgets/creator_wallet_deck.dart`):
   - Lifetime tips counter, supporter leaderboard, Cash-out CTA.
