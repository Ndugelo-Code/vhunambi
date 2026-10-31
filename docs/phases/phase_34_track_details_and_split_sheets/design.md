# Phase 34: Track Details & Collections Split-Sheet ZAR Royalty Convergence — Design
**Document Version:** 1.0.0  
**Status:** Approved for Implementation  

---

## 1. Domain Models & Service Contracts

### 1.1 Extended `SplitParticipant` (`collection_entity.dart`)
```dart
@immutable
class SplitParticipant {
  final String name;
  final String role;
  final double sharePercent;
  final String? creatorId;
  final String? handle;
  final String? walletAddress;

  const SplitParticipant({
    required this.name,
    required this.role,
    required this.sharePercent,
    this.creatorId,
    this.handle,
    this.walletAddress,
  });

  // Serialization to/from JSON preserving backward compatibility
  Map<String, dynamic> toJson() => {
    'name': name,
    'role': role,
    'share_percent': sharePercent,
    if (creatorId != null) 'creator_id': creatorId,
    if (handle != null) 'handle': handle,
    if (walletAddress != null) 'wallet_address': walletAddress,
  };

  factory SplitParticipant.fromJson(Map<String, dynamic> json) {
    return SplitParticipant(
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      sharePercent: (json['share_percent'] as num?)?.toDouble() ?? 0.0,
      creatorId: json['creator_id'] as String?,
      handle: json['handle'] as String?,
      walletAddress: json['wallet_address'] as String?,
    );
  }
}
```

### 1.2 `RoyaltyDistributionService`
```dart
class SplitShareDistribution {
  final SplitParticipant participant;
  final double zarAmount;
  final int coinsAmount;

  const SplitShareDistribution({
    required this.participant,
    required this.zarAmount,
    required this.coinsAmount,
  });
}

class RoyaltyDistributionResult {
  final bool isBalanced;
  final double grossZar;
  final int grossCoins;
  final List<SplitShareDistribution> distributions;

  const RoyaltyDistributionResult({
    required this.isBalanced,
    required this.grossZar,
    required this.grossCoins,
    required this.distributions,
  });
}

class RoyaltyDistributionService {
  static RoyaltyDistributionResult calculateSplit({
    required CollectionEntity collection,
    double grossZar = 0.0,
    int grossCoins = 0,
  }) {
    if (!collection.isSplitBalanced || collection.participants.isEmpty) {
      return RoyaltyDistributionResult(
        isBalanced: false,
        grossZar: grossZar,
        grossCoins: grossCoins,
        distributions: const [],
      );
    }

    final distributions = <SplitShareDistribution>[];
    double allocatedZar = 0.0;
    int allocatedCoins = 0;

    for (int i = 0; i < collection.participants.length; i++) {
      final p = collection.participants[i];
      final rawZar = double.parse((grossZar * (p.sharePercent / 100.0)).toStringAsFixed(2));
      final rawCoins = (grossCoins * (p.sharePercent / 100.0)).floor();

      allocatedZar += rawZar;
      allocatedCoins += rawCoins;

      distributions.add(SplitShareDistribution(
        participant: p,
        zarAmount: rawZar,
        coinsAmount: rawCoins,
      ));
    }

    // Residual dust attribution to primary contributor
    final diffZar = double.parse((grossZar - allocatedZar).toStringAsFixed(2));
    final diffCoins = grossCoins - allocatedCoins;

    if (distributions.isNotEmpty && (diffZar.abs() > 0.001 || diffCoins > 0)) {
      final first = distributions.first;
      distributions[0] = SplitShareDistribution(
        participant: first.participant,
        zarAmount: first.zarAmount + diffZar,
        coinsAmount: first.coinsAmount + diffCoins,
      );
    }

    return RoyaltyDistributionResult(
      isBalanced: true,
      grossZar: grossZar,
      grossCoins: grossCoins,
      distributions: List.unmodifiable(distributions),
    );
  }
}
```

---

## 2. Audio Engine Convergence (`StemSeparationLab` & `StemMixerNotifier`)

### 2.1 State Flow
1. When user taps "Separate" in `StemSeparationLab`:
   - `StemSeparationLab` calls `ref.read(trackDetailFamilyProvider(trackId).notifier).separateStems()` or reads `stemMixerProvider`.
   - `StemMixerNotifier` is initialized with active track channels.
2. The UI renders 4 stem rows (Vocals, Drums, Bass, Melody/Instrumental) with:
   - Soft rounded Phosphor icons (`AppIcons.microphone`, `AppIcons.disc`, `AppIcons.waveSine`, `AppIcons.piano`).
   - Mute button calling `ref.read(stemMixerProvider.notifier).toggleMute(StemType)`.
   - Solo button calling `ref.read(stemMixerProvider.notifier).toggleSolo(StemType)`.
   - Live waveform gain meters reflecting channel volume.
3. Quick Action Dock:
   - "Open Pocket Stem Mixer" $\to$ `StemMixerDeck` in modal sheet.
   - "Studio Master Polisher" $\to$ `MasteringSessionNotifier`.

---

## 3. UI/UX Modernization & Iconography Tokens (`STD-UIUX-001`)

### 3.1 Reaction Deck Tokens
```dart
class ReactionBadge {
  final String key;
  final IconData icon;
  final Color color;
  final String label;

  const ReactionBadge({
    required this.key,
    required this.icon,
    required this.color,
    required this.label,
  });
}

const kReactionBadges = [
  ReactionBadge(key: 'fire', icon: PhosphorIconsRegular.fire, color: AppColors.brandPrimary, label: 'Fire'),
  ReactionBadge(key: 'love', icon: PhosphorIconsRegular.heart, color: AppColors.accentCrimson, label: 'Love'),
  ReactionBadge(key: 'rhythm', icon: PhosphorIconsRegular.musicNotes, color: AppColors.brandSecondary, label: 'Rhythm'),
  ReactionBadge(key: 'hands', icon: PhosphorIconsRegular.handsClapping, color: AppColors.coinGold, label: 'Praise'),
  ReactionBadge(key: 'globe', icon: PhosphorIconsRegular.globeHemisphereWest, color: AppColors.accentBlue, label: 'Heritage'),
];
```

### 3.2 Toolbar Tokens
- All buttons use `AppRadius.pillBorder`.
- Touch target padding ensures $\ge 44 \times 44\text{dp}$.
- Highlight & splash colors conform to `AppColors.brandPrimary.withAlpha(25)`.

