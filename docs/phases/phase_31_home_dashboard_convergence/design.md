# Phase 31: V4.1 Creator Home Dashboard Convergence — Technical Design
**Phase:** 31  
**Status:** Approved & Ready for Execution  

---

## 1. Domain Models & Utilities

### 1.1. African Rhythm Matrix (`lib/features/home/domain/models/african_rhythm_matrix.dart`)
```dart
@immutable
class AfricanRhythmSpotlight {
  final int weekday; // 1 (Mon) .. 7 (Sun)
  final String dayName;
  final String genre;
  final String title;
  final String description;
  final int bpm;
  final String musicalKey;
  final String samplePrompt;

  const AfricanRhythmSpotlight({
    required this.weekday,
    required this.dayName,
    required this.genre,
    required this.title,
    required this.description,
    required this.bpm,
    required this.musicalKey,
    required this.samplePrompt,
  });
}

class AfricanRhythmMatrix {
  static const List<AfricanRhythmSpotlight> schedule = [
    AfricanRhythmSpotlight(
      weekday: 1,
      dayName: 'Monday',
      genre: 'Amapiano',
      title: 'Amapiano Private School Rhodes',
      description: 'Lush jazzy Rhodes progressions with deep, warm log-drum syncopation.',
      bpm: 113,
      musicalKey: 'F# Minor',
      samplePrompt: 'Deep soulful Amapiano with warm Rhodes piano and private school log drums',
    ),
    AfricanRhythmSpotlight(
      weekday: 2,
      dayName: 'Tuesday',
      genre: 'Gqom',
      title: 'Durban Gqom Broken Beat',
      description: 'Raw, heavy kick triplets, atmospheric synths, and Durban street pulse.',
      bpm: 127,
      musicalKey: 'C Minor',
      samplePrompt: 'Raw Durban Gqom club banger with heavy 808 sub kick and syncopated snare',
    ),
    AfricanRhythmSpotlight(
      weekday: 3,
      dayName: 'Wednesday',
      genre: 'Afro-Indigenous',
      title: 'Tshivenḓa Malende Pulse',
      description: 'Poly-rhythmic ngoma drums, indigenous bamboo flutes, and Limpopo cadence.',
      bpm: 108,
      musicalKey: 'G Minor',
      samplePrompt: 'Indigenous Tshivenḓa Malende rhythm with traditional ngoma drums and tribal chants',
    ),
    AfricanRhythmSpotlight(
      weekday: 4,
      dayName: 'Thursday',
      genre: 'Maskandi',
      title: 'Maskandi Ukupika Tuning',
      description: 'Zulu finger-picking guitar syncopation with native acoustic tuning.',
      bpm: 122,
      musicalKey: 'D Major',
      samplePrompt: 'Maskandi acoustic guitar rhythm with Zulu fingerpicking and driving bassline',
    ),
    AfricanRhythmSpotlight(
      weekday: 5,
      dayName: 'Friday',
      genre: 'Kwaito',
      title: 'Soweto 90s Kwaito Groove',
      description: 'Slow-tempo house shuffle, deep basslines, and authentic Mzansi street attitude.',
      bpm: 110,
      musicalKey: 'A Minor',
      samplePrompt: 'Classic 90s Soweto Kwaito with slow house kick and heavy rolling baseline',
    ),
    AfricanRhythmSpotlight(
      weekday: 6,
      dayName: 'Saturday',
      genre: 'Afro-Tech',
      title: 'Lagos Afro-Tech Energy',
      description: 'Driving 4/4 tribal percussion, hypnotic synth stabs, and continental club power.',
      bpm: 124,
      musicalKey: 'E Minor',
      samplePrompt: 'Hypnotic Lagos Afro-Tech with driving tribal percussion and atmospheric synth stabs',
    ),
    AfricanRhythmSpotlight(
      weekday: 7,
      dayName: 'Sunday',
      genre: 'Gospel',
      title: 'African Gospel Choral Harmonies',
      description: 'Rich vocal polyphony, uplifting Hammond organ, and traditional handclaps.',
      bpm: 78,
      musicalKey: 'C Major',
      samplePrompt: 'Inspiring South African Gospel chorus with rich layered harmonies and warm organ',
    ),
  ];

  static AfricanRhythmSpotlight forWeekday([int? weekday]) {
    final day = weekday ?? DateTime.now().weekday;
    final clamped = (day >= 1 && day <= 7) ? day : 1;
    return schedule.firstWhere(
      (s) => s.weekday == clamped,
      orElse: () => schedule.first,
    );
  }
}
```

---

## 2. Widget Architecture & Implementation Specs

### 2.1. 2-Tier Adaptive Top Bar
```dart
// Left: Avatar + Compact Greeting
CreatorAvatar(
  avatarKey: const Key('home_avatar_btn'),
  avatarUrl: ownerProfile.avatarUrl,
  monogram: ownerProfile.monogram.isNotEmpty ? ownerProfile.monogram : 'ND',
  size: 44,
  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OwnerProfileView())),
  onLongPress: () => AvatarCustomizationModal.show(context),
),
const SizedBox(width: AppSpacing.sm),
Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'CREATOR STUDIO',
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
      Text(
        '$greetingText $timeGlyph',
        key: const Key('home_greeting_text'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: (isDesktop ? AppTypography.titleLarge : AppTypography.titleMedium).copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  ),
),
// Right: Action Triad
// 1. Streak Pill
Container(
  key: const Key('home_streak_pill'),
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  decoration: BoxDecoration(
    color: AppColors.surfaceSecondary,
    borderRadius: AppRadius.pillBorder,
    border: Border.all(color: AppColors.borderSubtle),
  ),
  child: Row(
    children: [
      const Text('🔥'),
      const SizedBox(width: 4),
      Text(
        '${ownerProfile.dayStreak} Streak',
        style: AppTypography.caption.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  ),
),
const SizedBox(width: 6),
// 2. Coin Pill (tapping opens SubscriptionUpgradeModal to preserve Pin #8)
InkWell(
  key: const Key('home_coins_pill'),
  onTap: () => SubscriptionUpgradeModal.show(context),
  borderRadius: AppRadius.pillBorder,
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.coinGold.withAlpha(20),
      borderRadius: AppRadius.pillBorder,
      border: Border.all(color: AppColors.coinGold.withAlpha(120)),
    ),
    child: Row(
      children: [
        const Icon(Icons.monetization_on_rounded, color: AppColors.coinGold, size: 16),
        const SizedBox(width: 4),
        Text(
          '${creatorWallet.userCoinsBalance}',
          style: AppTypography.caption.copyWith(
            color: AppColors.coinGold,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  ),
),
const SizedBox(width: 6),
// 3. Notification Bell Action
InkWell(
  key: const Key('home_notifications_btn'),
  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsView())),
  borderRadius: BorderRadius.circular(20),
  child: const ConstrainedBox(
    constraints: BoxConstraints(minWidth: 44, minHeight: 44),
    child: Center(
      child: Icon(Icons.notifications_outlined, size: 22, color: AppColors.textPrimary),
    ),
  ),
),
```

### 2.2. Conditional In-Flight Generation Banner
```dart
final pipelineState = ref.watch(generationProgressProvider);
if (pipelineState != null && pipelineState.isGenerating)
  SliverToBoxAdapter(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16, vertical: 6),
      child: InkWell(
        key: const Key('home_inflight_generation_banner'),
        onTap: () => widget.onNavigateToStudio?.call(),
        borderRadius: AppRadius.cardBorder,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.brandPrimary.withAlpha(120)),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandPrimary.withAlpha(30),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(AppColors.brandPrimary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Synthesizing "${pipelineState.trackTitle}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${pipelineState.statusMessage} • ${(pipelineState.progressPercent * 100).toInt()}%',
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.brandPrimary),
            ],
          ),
        ),
      ),
    ),
  );
```

### 2.3. Responsive 6-Tool Creation Hub
```dart
Widget _buildCreationHub(bool isDesktop) {
  final tools = [
    (key: 'home_hub_ai_studio', icon: Icons.auto_awesome_rounded, title: 'AI Studio', subtitle: 'Compose track', color: AppColors.brandPrimary, onTap: () => widget.onNavigateToStudio?.call()),
    (key: 'home_hub_voice_clone', icon: Icons.record_voice_over_rounded, title: 'Voice Clone', subtitle: '24 Voices & DNA', color: const Color(0xFFEC4899), onTap: () => VocalIdentityPickerSheet.show(context)),
    (key: 'home_hub_melody_sketchpad', icon: Icons.piano_rounded, title: 'Sketchpad', subtitle: 'Log-Drum & Keys', color: const Color(0xFF8B5CF6), onTap: () => MelodySketchpadModal.show(context)),
    (key: 'home_hub_stem_master', icon: Icons.tune_rounded, title: 'Stem Lab', subtitle: 'Studio Master', color: const Color(0xFF10B981), onTap: () => _openMastering(context)),
    (key: 'home_hub_beats_market', icon: Icons.shopping_bag_outlined, title: 'Beats Market', subtitle: 'License beats', color: AppColors.coinGold, onTap: () => widget.onNavigateToMarket?.call()),
    (key: 'home_hub_asset_vault', icon: Icons.library_music_outlined, title: 'Asset Vault', subtitle: 'Tracks & Beats', color: const Color(0xFF3B82F6), onTap: () => widget.onNavigateToLibrary?.call()),
  ];

  if (isDesktop) {
    return Row(
      children: tools.map((t) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _buildHubCard(t)))).toList(),
    );
  }

  // Mobile: 2 rows of 3 columns
  return Column(
    children: [
      Row(
        children: tools.sublist(0, 3).map((t) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _buildHubCard(t)))).toList(),
      ),
      const SizedBox(height: 8),
      Row(
        children: tools.sublist(3, 6).map((t) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _buildHubCard(t)))).toList(),
      ),
    ],
  );
}
```

