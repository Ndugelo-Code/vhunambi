# Design Specification: Phase 30
## V4.1 Creator Profile Convergence (`/profile/:id` & `/profile/me`)

> **Document ID:** `DESIGN-PHASE-30-PROFILE`  
> **Status:** 🟡 SPECIFICATION  
> **Target Apps:** `apps/vhunambi_client`, `apps/vhunambi_api`  

---

## 1. Domain Models & Immutable Entities

### 1.1 Non-Breaking `TipRecordEntity` Expansion
To align the profile ledger with the canonical African cultural micro-tipping economy without breaking existing tests, `TipRecordEntity` is extended with optional Coin, ZAR, and gift metadata:

```dart
// lib/features/profile/domain/models/profile_models.dart
@immutable
class TipRecordEntity {
  final String id;
  final String senderName;
  final String senderHandle;
  final String recipientName;
  final int amountCredits;       // Preserved for backward compatibility
  final int amountCoins;         // Canonical V4.1 Coin economy
  final double amountZar;        // Real ZAR equivalent
  final String giftEmoji;        // 👏, ☕, 🎛️, 👑
  final String giftName;         // e.g., 'Studio Beats'
  final String trackTitle;
  final DateTime timestamp;
  final bool isReceived;

  const TipRecordEntity({
    required this.id,
    required this.senderName,
    required this.senderHandle,
    required this.recipientName,
    this.amountCredits = 0,
    this.amountCoins = 0,
    this.amountZar = 0.0,
    this.giftEmoji = '🪙',
    this.giftName = 'Cultural Tip',
    required this.trackTitle,
    required this.timestamp,
    this.isReceived = true,
  });

  String get amountLabel {
    if (amountCoins > 0) return '$giftEmoji $amountCoins Coins (R${amountZar.toStringAsFixed(0)})';
    return '⚡ $amountCredits';
  }
}
```

### 1.2 Owner Studio Segment Enum
```dart
// lib/features/profile/domain/models/profile_models.dart
enum OwnerStudioTab {
  songs,
  releases,
  beatstore;

  String get label {
    return switch (this) {
      OwnerStudioTab.songs => '🎵 Songs',
      OwnerStudioTab.releases => '💿 Releases',
      OwnerStudioTab.beatstore => '🎛️ My Beatstore',
    };
  }
}
```

### 1.3 `ArtistProfileEntity` Optional Additions
```dart
// lib/features/profile/domain/models/profile_models.dart
// Added optional fields to ArtistProfileEntity with safe defaults:
final String? vocalArchetypeTitle; // e.g. 'Venda Royal Matriarch'
final String? vocalArchetypeLanguage; // e.g. 'Tshivenḓa'
final String? vocalSampleUrl; // 10-second audition snippet
final CreatorDna? creatorDna; // Artist's genuine sound DNA
```

---

## 2. Riverpod State Architecture & Helpers

### 2.1 Idempotent Creator ID Normalization Helpers
```dart
// lib/core/utils/creator_id_utils.dart
/// Normalizes any creator identifier to the canonical 'creator_<id>' format.
String normalizeCreatorId(String id) {
  final trimmed = id.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed.startsWith('creator_') ? trimmed : 'creator_$trimmed';
}

/// Strips the 'creator_' prefix to get the raw alphanumeric username.
String extractRawCreatorId(String id) {
  final trimmed = id.trim();
  return trimmed.startsWith('creator_') ? trimmed.substring(8) : trimmed;
}
```

### 2.2 Creator Beats Family Provider
```dart
// lib/features/marketplace/presentation/providers/marketplace_providers.dart
/// Filters the global marketplace beats by creator identifier (with prefix tolerance).
final creatorBeatsFamilyProvider =
    Provider.family<List<BeatListingEntity>, String>((ref, creatorId) {
  final allBeats = ref.watch(marketplaceBeatsProvider);
  final normalized = normalizeCreatorId(creatorId);
  final raw = extractRawCreatorId(creatorId);

  return allBeats.where((beat) {
    return beat.producerId == normalized ||
        beat.producerId == raw ||
        beat.producerHandle.toLowerCase() == '@$raw'.toLowerCase() ||
        beat.producerName.toLowerCase() == raw.toLowerCase();
  }).toList();
});
```

### 2.3 Artist Scoped DNA Family Provider
```dart
// lib/features/creator_dna/presentation/providers/creator_dna_provider.dart
/// Provides sound identity attunement for visited external artists.
final artistDnaFamilyProvider =
    Provider.family<CreatorDna, String>((ref, artistId) {
  final raw = extractRawCreatorId(artistId).toLowerCase();

  // Curated archetype profiles for featured African artists
  if (raw.contains('makhadzi') || raw.contains('sigwa')) {
    return const CreatorDna(
      dominantGenre: 'Amapiano',
      genreWeights: {'Amapiano': 0.75, 'Afro House': 0.15, 'Tshivenḓa Folk': 0.10},
      tempoAttunementBpm: 112,
      harmonicKeyPreference: 'F# Minor',
      acousticPurityScore: 0.88,
      culturalAuthenticityScore: 0.94,
      isPrivateOnDevice: false,
    );
  }
  if (raw.contains('fifi')) {
    return const CreatorDna(
      dominantGenre: 'Amapiano',
      genreWeights: {'Amapiano': 0.80, 'Soul': 0.20},
      tempoAttunementBpm: 114,
      harmonicKeyPreference: 'C Major',
      acousticPurityScore: 0.82,
      culturalAuthenticityScore: 0.91,
      isPrivateOnDevice: false,
    );
  }
  if (raw.contains('khakhathi')) {
    return const CreatorDna(
      dominantGenre: 'Maskandi',
      genreWeights: {'Maskandi': 0.70, 'Mbaqanga': 0.30},
      tempoAttunementBpm: 120,
      harmonicKeyPreference: 'A Minor',
      acousticPurityScore: 0.95,
      culturalAuthenticityScore: 0.98,
      isPrivateOnDevice: false,
    );
  }

  // Default balanced DNA fallback
  return const CreatorDna(
    dominantGenre: 'Afrobeats',
    genreWeights: {'Afrobeats': 0.50, 'Amapiano': 0.30, 'Afro House': 0.20},
    tempoAttunementBpm: 115,
    harmonicKeyPreference: 'G Minor',
    acousticPurityScore: 0.85,
    culturalAuthenticityScore: 0.90,
    isPrivateOnDevice: false,
  );
});
```

---

## 3. Component Architecture & UI Interactions

### 3.1 Direct Cultural Tipping via `CreatorTippingSheet`
`CreatorTippingSheet` is enhanced with a unified constructor that seamlessly accommodates both reel context and standalone profile context:

```dart
// lib/features/social/presentation/widgets/creator_tipping_sheet.dart
class CreatorTippingSheet extends ConsumerStatefulWidget {
  final PublishedClip? clip;
  final String creatorId;
  final String creatorDisplayName;
  final String? creatorAvatarUrl;

  const CreatorTippingSheet({
    super.key,
    this.clip,
    required this.creatorId,
    required this.creatorDisplayName,
    this.creatorAvatarUrl,
  });

  static Future<void> show(
    BuildContext context, {
    PublishedClip? clip,
    String? creatorId,
    String? creatorName,
    String? creatorAvatarUrl,
  }) {
    final effectiveId = clip?.creatorId ?? creatorId ?? '';
    final effectiveName = clip?.creatorDisplayName ?? creatorName ?? 'Artist';
    final effectiveAvatar = clip?.creatorAvatarUrl ?? creatorAvatarUrl;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreatorTippingSheet(
        clip: clip,
        creatorId: effectiveId,
        creatorDisplayName: effectiveName,
        creatorAvatarUrl: effectiveAvatar,
      ),
    );
  }
...
```

Inside `ArtistProfileView`:
```dart
ProfileBannerHeader(
  profile: profile,
  onToggleFollow: () => ref.read(profileOperationProvider(artistId).notifier).toggleFollow(),
  onTipArtist: () => CreatorTippingSheet.show(
    context,
    creatorId: profile.id,
    creatorName: profile.displayName,
    creatorAvatarUrl: profile.avatarUrl,
  ),
  onShare: () { ... },
)
```

### 3.2 Public Beats Tab: `ProducerBeatListingTile` & Audition Dock
Inside `ArtistProfileView._beatsCommunityTab`:
```dart
Widget _beatsCommunityTab(BuildContext context, WidgetRef ref, ArtistProfileEntity profile) {
  final beats = ref.watch(creatorBeatsFamilyProvider(profile.id));

  return ListView(
    padding: const EdgeInsets.all(AppSpacing.md),
    children: [
      // Section Header
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_rounded, color: AppColors.brandPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Producer Beat Store',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Text(
            '${beats.length} beats available',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),

      // Beat Listings or Empty State
      if (beats.isEmpty)
        _buildEmptyBeatsCard(context)
      else
        for (final beat in beats)
          ProducerBeatListingTile(
            beat: beat,
            onAudition: () => auditionBeat(ref, beat),
            onLicense: () => BeatLicenseModal.show(context, beat: beat),
          ),

      const SizedBox(height: AppSpacing.lg),

      // Supporters Leaderboard
      TopSupportersLeaderboard(
        supporters: profile.topSupporters,
        onTipFirst: () => CreatorTippingSheet.show(
          context,
          creatorId: profile.id,
          creatorName: profile.displayName,
          creatorAvatarUrl: profile.avatarUrl,
        ),
      ),
    ],
  );
}
```

Each `ProducerBeatListingTile`:
```dart
class ProducerBeatListingTile extends StatelessWidget {
  final BeatListingEntity beat;
  final VoidCallback onAudition;
  final VoidCallback onLicense;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          // Play / Audition Button (44x44dp touch target)
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: InkWell(
              onTap: onAudition,
              borderRadius: AppRadius.thumbBorder,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppGradients.forGenre(beat.genre),
                  borderRadius: AppRadius.thumbBorder,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Beat Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  beat.title,
                  style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${beat.genre} • ${beat.bpmLabel} • ${beat.musicalKey}',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Price Badge & License Button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${beat.priceInCredits} Coins',
                style: AppTypography.caption.copyWith(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: onLicense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceSecondary,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  minimumSize: const Size(72, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                  side: const BorderSide(color: AppColors.borderSubtle),
                ),
                child: const Text('License', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

### 3.3 Owner Studio: 3-Segment Selector & Beatstore Cockpit
Inside `OwnerProfileView`:
```dart
// State variable:
OwnerStudioTab _activeTab = OwnerStudioTab.songs;

// Segmented Selector Widget:
Widget _buildStudioSegmentedSelector() {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.surfaceSecondary,
      borderRadius: AppRadius.pillBorder,
      border: Border.all(color: AppColors.borderSubtle),
    ),
    child: Row(
      children: OwnerStudioTab.values.map((tab) {
        final isSelected = _activeTab == tab;
        return Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: InkWell(
              onTap: () => setState(() => _activeTab = tab),
              borderRadius: AppRadius.pillBorder,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.brandPrimary : Colors.transparent,
                  borderRadius: AppRadius.pillBorder,
                ),
                alignment: Alignment.center,
                child: Text(
                  tab.label,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.brandContrast : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}
```

When `_activeTab == OwnerStudioTab.beatstore`:
Mounts `OwnerBeatstoreCockpit`:
- **Revenue Summary Card**: Total Beats Listed, Total Sales Count, Realized ZAR Balance.
- **Upload Action Button**: `[ ➕ Upload / Publish Beat ]` (`Key('owner_upload_beat_btn')`).
- **Owner Beats List**: Rendered from `creatorBeatsFamilyProvider('creator_ndugelo')` with stem indicator badges and quick unpublish toggle.

### 3.4 Parameterized `CreatorDnaProfileCard`
```dart
// lib/features/creator_dna/presentation/widgets/creator_dna_profile_card.dart
class CreatorDnaProfileCard extends ConsumerWidget {
  final bool isOwner;
  final CreatorDna? customDna;

  const CreatorDnaProfileCard({
    super.key,
    this.isOwner = true,
    this.customDna,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dna = customDna ?? ref.watch(creatorDnaProvider);
    // Suppress reset controls and on-device privacy toggles if !isOwner
    ...
```

### 3.5 Top-Bar Navigation Convergence
In `DesktopExploreTopBar`:
```dart
InkWell(
  key: const Key('explore_desktop_user_avatar'),
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OwnerProfileView()),
    );
  },
  borderRadius: BorderRadius.circular(18),
  child: const _UserAvatar(),
)
```
In `MobileExploreTopBar`:
Add `_UserAvatarButton` (`Key('explore_mobile_user_avatar_btn')`) to the trailing icon row, satisfying the 44×44dp touch area requirement and routing to `OwnerProfileView`.

---

## 4. Accessibility, Responsive Layouts & Design Token Invariants

1. **Strict Token Adherence**:
   - Backgrounds: `AppColors.surfaceCanvas`, `AppColors.surfaceElevated`, `AppColors.surfaceSecondary`, `AppColors.surfaceModal`.
   - Brand Accent: `AppColors.brandPrimary` (`#F97316`).
   - Text Tokens: `AppColors.textPrimary` (pure white `#FFFFFF`), `AppColors.textSecondary`, `AppColors.textMuted`.
   - **CRITICAL RULE**: `AppColors.brandContrast` (`#000000`) is only permitted on solid orange fills (`AppColors.brandPrimary`), NEVER directly on dark surfaces.
2. **Apple HIG & WCAG 2.1 AA**:
   - Every tap target maintains a bounding box $\ge 44 \times 44\text{dp}$.
   - Contrast ratio for all text elements $\ge 4.5:1$.
3. **Headless & SSR Test Safety**:
   - Safe defaults for un-seeded profiles.
   - Clean disposal of all animation controllers and text controllers in `dispose()`.

