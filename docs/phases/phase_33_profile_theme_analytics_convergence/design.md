# Phase 33: Multi-Dimensional Creator Profile Hub, Adaptive Light/Dark Theme Engine & Synchronized Platform Analytics — Design

**Document Version:** 1.0.0  
**Status:** Canonical Engineering Specification  
**Document ID:** `PHASE-33-DESIGN`  
**Standard Reference:** `STD-UIUX-001`  

---

## 1. Domain Models & State Architecture

### 1.1 Theme Mode State & Persistence
```dart
enum AppThemeModePreference {
  system,
  light,
  dark;

  ThemeMode toThemeMode() => switch (this) {
        AppThemeModePreference.system => ThemeMode.system,
        AppThemeModePreference.light => ThemeMode.light,
        AppThemeModePreference.dark => ThemeMode.dark,
      };

  static AppThemeModePreference fromString(String? value) => switch (value) {
        'light' => AppThemeModePreference.light,
        'dark' => AppThemeModePreference.dark,
        _ => AppThemeModePreference.system,
      };
}

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Box? _prefsBox;
  ThemeModeNotifier([this._prefsBox]) : super(_initThemeMode(_prefsBox));

  static ThemeMode _initThemeMode(Box? box) {
    if (box == null) return ThemeMode.system;
    final stored = box.get('selected_theme_mode') as String?;
    return AppThemeModePreference.fromString(stored).toThemeMode();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefName = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _prefsBox?.put('selected_theme_mode', prefName);
  }
}
```

---

### 1.2 Synchronized Platform Analytics Model
```dart
class SynchronizedPlatformAnalytics {
  final int totalSongsCount;
  final int totalPlaysCount;
  final int totalLikesCount;
  final int totalReelsCount;
  final int totalReelsPlaysCount;
  final int totalReelsLikesCount;
  final int totalBeatsCount;
  final int totalBeatsSold;
  final double totalZarEarned;
  final int totalCoinsBalance;
  final int totalClonedVoicesCount;
  final int totalSavedMelodiesCount;
  final Map<String, int> genreDistributionMap;
  final List<AnalyticsDataPoint> velocityPoints;

  const SynchronizedPlatformAnalytics({
    this.totalSongsCount = 0,
    this.totalPlaysCount = 0,
    this.totalLikesCount = 0,
    this.totalReelsCount = 0,
    this.totalReelsPlaysCount = 0,
    this.totalReelsLikesCount = 0,
    this.totalBeatsCount = 0,
    this.totalBeatsSold = 0,
    this.totalZarEarned = 0.0,
    this.totalCoinsBalance = 0,
    this.totalClonedVoicesCount = 0,
    this.totalSavedMelodiesCount = 0,
    this.genreDistributionMap = const {},
    this.velocityPoints = const [],
  });
}

class AnalyticsDataPoint {
  final DateTime date;
  final int streams;
  final double zarRevenue;

  const AnalyticsDataPoint({
    required this.date,
    required this.streams,
    required this.zarRevenue,
  });
}
```

---

### 1.3 Extended Artist Profile Entity
```dart
// Extending ArtistProfileEntity with pinnedTrackId
class ArtistProfileEntity {
  ...
  final String? pinnedTrackId; // New: Selected Featured Anthem
  ...
}
```

---

## 2. Component Design & Layouts

### 2.1 OwnerProfileView Hero Header & Quick Actions
```
┌────────────────────────────────────────────────────────────────────────┐
│  [ 👤 Avatar 84dp ]  NDUGELO MUSICIAN (Verified ✓)                     │
│                      @ndugelo_musician • Johannesburg, South Africa    │
│                      "Exploring Afro-Futuristic Sounds & Amapiano"     │
│                                                                        │
│  [ 12 Songs ]    [ 4.8k Plays ]    [ 1.2k Likes ]    [ 340 Followers ] │
│                                                                        │
│  TOP GENRES:  [ Amapiano (6) ]  [ Afro House (3) ]  [ Maskandi (2) ]   │
│                                                                        │
│  [ 📷 Change ]  [ ✏️ Edit Profile ]  [ 📌 Pin Song ]  [ 📊 Analytics ] │
│  [ ☀️/🌙 Appearance & Settings ]                                       │
└────────────────────────────────────────────────────────────────────────┘
```

---

### 2.2 Pinned Spotlight Anthem Card (`Key('profile_pinned_spotlight_card')`)
```
┌────────────────────────────────────────────────────────────────────────┐
│  ⭐ FEATURED ARTIST ANTHEM                                             │
│  ┌───────────┐  Bakanzi Anthem (Remix)                                 │
│  │  Artwork  │  Ndugelo Musician • Amapiano • 112 BPM                  │
│  │   56dp    │  [ ▶ Play ]  [ 1.4k Plays ]  [ 420 Likes ]              │
│  └───────────┘                                                         │
└────────────────────────────────────────────────────────────────────────┘
```

---

### 2.3 5-Dimension Owner Studio Vault Tabs
```
┌────────────────────────────────────────────────────────────────────────┐
│  [ Songs ] [ Reels ] [ Beatstore ] [ Voices & Melodies ] [ Releases ]  │
├────────────────────────────────────────────────────────────────────────┤
│  If tab == voicesAndMelodies:                                          │
│    ├── Cloned Vocal DNA Profiles (Phase 26)                            │
│    │     - Zulu Soul Tenor [ ▶ Audition ] [ Open in Studio ]           │
│    │     - Venda Folk Soprano [ ▶ Audition ] [ Open in Studio ]        │
│    └── Saved Multi-Track Melody Grooves (Phase 32)                     │
│          - Amapiano Groove Am 112 BPM [ ▶ Audition ] [ Load Groove ]   │
│          - Maskandi Lead Guitar E 120 BPM [ ▶ Audition ] [ Load ]      │
└────────────────────────────────────────────────────────────────────────┘
```

---

### 2.4 Studio Analytics Console Sheet (`StudioAnalyticsConsoleSheet`)
```
┌────────────────────────────────────────────────────────────────────────┐
│  ── [ Drag Handle ] ──                                                 │
│  STUDIO ANALYTICS CONSOLE                                       [ ✕ ]  │
│  Period: [ 7 Days ] [ 30 Days ] [ All Time ]                           │
│                                                                        │
│  ┌──────────────────┐  ┌──────────────────┐                            │
│  │ Total Streams    │  │ Net Creator Rev  │                            │
│  │ 14,820 (+18%)    │  │ R 1,840.50 (ZAR) │                            │
│  └──────────────────┘  └──────────────────┘                            │
│  ┌──────────────────┐  ┌──────────────────┐                            │
│  │ Reel Remixes     │  │ Beat Licenses    │                            │
│  │ 42 viral clips   │  │ 8 stems packs    │                            │
│  └──────────────────┘  └──────────────────┘                            │
│                                                                        │
│  7-DAY STREAM & REVENUE VELOCITY                                       │
│  [ CustomPainter Bezier Smooth Area Chart ]                            │
│                                                                        │
│  GENRE AFFINITY DISTRIBUTION                                           │
│  Amapiano    ████████████████████  55%                                 │
│  Afro House  ██████████            25%                                 │
│  Maskandi    ██████                15%                                 │
│  Gqom        ██                     5%                                 │
│                                                                        │
│  TOP PERFORMING DROPS                                                  │
│  1. Bakanzi Anthem — 5.2k streams                                      │
│  2. Mbaḓi Nights (Reel) — 3.8k views                                   │
│  3. Pretoria Log Drum Kit — 5 licenses sold                            │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Bezier Velocity Curve Mathematics (`CustomPainter`)
To render high-fidelity, fluid stream curves without external charting package dependencies, `StreamVelocityChartPainter` computes a smooth cubic Bézier curve through normalized points $(x_i, y_i)$:

$$C_{i,1} = \left(x_i + \frac{x_{i+1} - x_{i-1}}{6}, y_i + \frac{y_{i+1} - y_{i-1}}{6}\right)$$
$$C_{i,2} = \left(x_{i+1} - \frac{x_{i+2} - x_i}{6}, y_{i+1} - \frac{y_{i+2} - y_i}{6}\right)$$

A linear gradient fill extends from the bezier path down to the canvas baseline, shaded with `AppColors.brandPrimary.withAlpha(50)` transitioning to transparent, with glowing data point anchors.

