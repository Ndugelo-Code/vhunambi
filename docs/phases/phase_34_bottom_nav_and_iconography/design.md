# 🎨 Phase 34 Design: Mobile Bottom Navigation & Phosphor Iconography

**Phase Identifier:** `PHASE-34-NAV-ICON`  
**Status:** Approved for Implementation  

---

## 1. Visual Mockups & Geometry

### 1.1 Bottom Navigation Layout Matrix
The navigation bar is rendered inside `VhunambiBottomDockSurface`:
- **Total Height:** $56\text{dp}$ + device bottom safe-area padding.
- **Surface Backdrop:** Translucent dark canvas (`AppColors.surfaceCanvas.withAlpha(215)`) with $18\text{-sigma}$ blur.
- **Top Border:** $1\text{dp}$ hairline border (`AppColors.borderSubtle`).

```
◄────────────────────────────── 360dp - 428dp Screen Width ─────────────────────────────►
┌───────────────┬───────────────┬───────────────────────┬───────────────┬───────────────┐
│     Tab 0     │     Tab 1     │         Tab 2         │     Tab 3     │     Tab 4     │
│    [ Home ]   │  [ Explore ]  │   [ 🌟 Create Orb ]   │  [ Library ]  │   [ Market ]  │
│  Active Pill  │               │    Elevated Center    │               │               │
│  (32dp height)│               │   (40×40dp Capsule)   │               │               │
└───────────────┴───────────────┴───────────────────────┴───────────────┴───────────────┘
```

### 1.2 Active Indicator Capsule Geometry
- **Height:** $32\text{dp}$
- **Horizontal Padding:** $16\text{dp}$
- **Corner Radius:** $16\text{dp}$ (`AppRadius.pillBorder`)
- **Color:** `AppColors.brandPrimary.withAlpha(30)`
- **Border:** `Border.all(color: AppColors.brandPrimary.withAlpha(60), width: 1.0)`
- **Animation Curve:** `Curves.easeOutCubic` over $220\text{ms}$

### 1.3 Center Hero Orb Geometry (Tab 2 — Create)
- **Size:** $42 \times 42\text{dp}$
- **Decoration:**
  - Gradient: `AppGradients.brandGlow` (Linear gradient from `Color(0xFFFF6B00)` to `Color(0xFFFF8533)`)
  - Shape: Rounded rectangle (`borderRadius: 14dp`)
  - Shadow: `BoxShadow(color: AppColors.brandPrimary.withAlpha(90), blurRadius: 12, offset: Offset(0, 4))`
- **Icon:** `PhosphorIcon(PhosphorIconsFill.sparkle, color: Colors.white, size: 22)`

---

## 2. Widget Tree Structure: `VhunambiMobileBottomNav`

```
VhunambiMobileBottomNav (ConsumerStatefulWidget)
 └── SafeArea (top: false, bottom: true)
      └── SizedBox (height: 56)
           └── Row (mainAxisAlignment: MainAxisAlignment.spaceAround)
                ├── _NavBarItem (index: 0, Home)
                ├── _NavBarItem (index: 1, Explore)
                ├── _CreateHeroOrb (index: 2, Create)
                ├── _NavBarItem (index: 3, Library)
                └── _NavBarItem (index: 4, Market)
```

### 2.1 Zero-Flash Touch Interaction
```dart
GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTap: () => _handleTap(index),
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutCubic,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: isSelected ? AppColors.brandPrimary.withAlpha(25) : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      border: isSelected
          ? Border.all(color: AppColors.brandPrimary.withAlpha(50), width: 1)
          : null,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedScale(
          scale: isSelected ? 1.12 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: PhosphorIcon(
            isSelected ? activeIcon : idleIcon,
            size: 22,
            color: isSelected ? AppColors.brandPrimary : AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.brandPrimary : AppColors.textTertiary,
          ),
        ),
      ],
    ),
  ),
)
```

---

## 3. Centralized `AppIcons` Design Tokens

`lib/core/design_system/tokens/app_icons.dart` maps semantic tokens to Phosphor vector glyphs:

```dart
abstract final class AppIcons {
  // Navigation
  static const homeRegular = PhosphorIconsRegular.house;
  static const homeFill = PhosphorIconsFill.house;
  
  static const exploreRegular = PhosphorIconsRegular.compass;
  static const exploreFill = PhosphorIconsFill.compass;
  
  static const createSparkle = PhosphorIconsFill.sparkle;
  static const studioMagic = PhosphorIconsFill.magicWand;
  
  static const libraryRegular = PhosphorIconsRegular.musicNotesSimple;
  static const libraryFill = PhosphorIconsFill.musicNotesSimple;
  
  static const marketRegular = PhosphorIconsRegular.storefront;
  static const marketFill = PhosphorIconsFill.storefront;

  // Status & Gamification (Replaces Emojis)
  static const flame = PhosphorIconsFill.flame;               // Replaces 🔥
  static const coin = PhosphorIconsFill.coin;                 // Replaces 🪙
  static const coins = PhosphorIconsFill.coins;               // Multi-coins
  static const trophy = PhosphorIconsFill.trophy;             // Replaces 🏆
  static const lightning = PhosphorIconsFill.lightning;       // Replaces ⚡
  static const dna = PhosphorIconsFill.dna;                   // Replaces 🧬
  static const verified = PhosphorIconsFill.checkCircle;      // Verified Badge
  static const heart = PhosphorIconsFill.heart;               // Favorites
  static const share = PhosphorIconsRegular.shareNetwork;     // Share

  // Audio DAW & Stems
  static const microphone = PhosphorIconsFill.microphone;     // Vocals (Replaces 🎤)
  static const drums = PhosphorIconsFill.waveform;            // Drums (Replaces 🥁)
  static const piano = PhosphorIconsFill.pianoKeys;           // Keys / Bass (Replaces 🎹)
  static const guitar = PhosphorIconsFill.guitar;             // Melody / Strings (Replaces 🎸)
  static const disc = PhosphorIconsFill.disc;                 // Releases (Replaces 💿)
  static const sliders = PhosphorIconsFill.slidersHorizontal; // Beatstore (Replaces 🎛️)
}
```

