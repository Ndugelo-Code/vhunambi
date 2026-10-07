# Blueprint 00: System Design Tokens & Styling Primitives

> **Target Platform:** Flutter 3.x+ / Dart 3.x+ (Windows, macOS, Android, iOS)  
> **Source Origin:** Production Web Client (`https://vhunambi.com`)  
> **Package Namespace:** `package:vhunambi/core/theme/`

---

## 1. Color Palette & Surface Tokens

Vhunambi uses a high-contrast, dark-mode-first aesthetic inspired by nighttime studio hardware and southern African aesthetics ("Mountain Silhouette" / "Pitch Canvas").

### 1.1 Core Surfaces & Canvas

| Token Name | Hex Value | RGBA Preview | Semantic Role |
| :--- | :--- | :--- | :--- |
| `surfaceCanvas` | `#0A0A0C` | `Color(0xFF0A0A0C)` | Primary background canvas for all route scaffolds |
| `surfaceElevated` | `#141418` | `Color(0xFF141418)` | Elevated cards, tiles, bottom navigation bar, headers |
| `surfaceSecondary` | `#1B1B22` | `Color(0xFF1B1B22)` | Inset containers, chips, inactive tabs, stat pills |
| `surfaceModal` | `#16161C` | `Color(0xFF16161C)` | Bottom sheets, dialogs, dropdown menus, cockpit drawers |
| `borderSubtle` | `#2D2D38` | `Color(0xFF2D2D38)` | Card borders, dividers, list separators (1px stroke) |
| `borderActive` | `#4B4B5A` | `Color(0xFF4B4B5A)` | Focused inputs, hover outlines, highlighted borders |

### 1.2 Brand Accents & Interactive States

| Token Name | Hex Value | RGBA Preview | Semantic Role |
| :--- | :--- | :--- | :--- |
| `brandPrimary` | `#F97316` | `Color(0xFFF97316)` | Vibrant Amber/Orange. Main CTA, active tab indicator, play triggers |
| `brandPrimaryHover`| `#EA580C` | `Color(0xFFEA580C)` | Pressed / hovered state for primary buttons |
| `brandContrastText`| `#000000` | `Color(0xFF000000)` | Pure Black text on `brandPrimary` buttons & active chips |
| `badgeCyan` | `#22D3EE` | `Color(0xFF22D3EE)` | Text/Icon color for `"NEW"` drop badges |
| `badgeCyanBg` | `#0E3842` | `Color(0xFF0E3842)` | Pill container background for `"NEW"` drop badges |
| `accentFire` | `#EA580C` | `Color(0xFFEA580C)` | Daily streak flame icon and hot trending markers |
| `accentSuccess` | `#10B981` | `Color(0xFF10B981)` | Live streaming indicators, active audio status |
| `accentError` | `#EF4444` | `Color(0xFFEF4444)` | Validation errors, destructive actions, cancel buttons |

### 1.3 Text & Content Hierarchy

| Token Name | Hex Value | Opacity | Semantic Role |
| :--- | :--- | :--- | :--- |
| `textPrimary` | `#FFFFFF` | 100% | Primary headings, track titles, active tab text |
| `textSecondary` | `#9CA3AF` | 100% | Subtitles, creator usernames, duration labels, metadata |
| `textTertiary` | `#6B7280` | 100% | Placeholder hints, disabled labels, timestamps |
| `textInverse` | `#000000` | 100% | High-contrast text on solid orange/amber accents |

---

## 2. Dynamic African Regional Genre Gradients

Curated high-saturation gradients reflecting traditional and contemporary African musical movements:

| Genre Name | Start Hex | End Hex | Gradient Direction | Suggested Art Theme |
| :--- | :--- | :--- | :--- | :--- |
| **Amapiano** | `#D97706` | `#F59E0B` | Top-Left $\rightarrow$ Bottom-Right | Warm Gold & Brass (Log drum pulse) |
| **Kwaito** | `#991B1B` | `#DC2626` | Top-Left $\rightarrow$ Bottom-Right | Brick Red / Terracotta (Street township rhythm) |
| **Gqom** | `#312E81` | `#4F46E5` | Top-Left $\rightarrow$ Bottom-Right | Neon Ultraviolet / Deep Indigo (Durban dark club sound) |
| **Maskandi** | `#065F46` | `#059669` | Top-Left $\rightarrow$ Bottom-Right | Emerald / Deep Forest (Zulu folk acoustic strings) |
| **Afro House** | `#C2410C` | `#EA580C` | Top-Left $\rightarrow$ Bottom-Right | Deep Sunburst Amber (Deep tribal percussion) |
| **Afrobeats** | `#B45309` | `#F59E0B` | Top-Left $\rightarrow$ Bottom-Right | Saffron Yellow / Warm Ochre (Vibrant horn sections) |
| **Mbaqanga** | `#78350F` | `#B45309` | Top-Left $\rightarrow$ Bottom-Right | Earthy Bronze / Ochre (Township jazz heritage) |
| **Marabi** | `#581C87` | `#7E22CE` | Top-Left $\rightarrow$ Bottom-Right | Royal Violet (Shebeen keyboard harmonies) |
| **Bubblegum** | `#BE185D` | `#F43F5E` | Top-Left $\rightarrow$ Bottom-Right | Electric Magenta / Hot Pink (80s SA disco pop) |
| **Afro Jazz** | `#1E3A8A` | `#2563EB` | Top-Left $\rightarrow$ Bottom-Right | Midnight Sapphire (Brass & upright bass) |
| **Afro Soul** | `#831843` | `#DB2777` | Top-Left $\rightarrow$ Bottom-Right | Deep Burgundy (Intimate vocal expression) |
| **Afro-Arabic** | `#047857` | `#0D9488` | Top-Left $\rightarrow$ Bottom-Right | Jade & Turquoise (North/East African oud scales) |

---

## 3. Typography Hierarchy

The type scale uses **Inter** (or **Plus Jakarta Sans**) with geometric clarity and tight letter-spacing for high-density music metadata displays:

```
Display Large    32px / 38px line-height / FontWeight.bold (w700)
Display Medium   28px / 34px line-height / FontWeight.bold (w700)
Title Large      20px / 26px line-height / FontWeight.w600
Title Medium     16px / 22px line-height / FontWeight.w600
Body Large       14px / 20px line-height / FontWeight.w500
Body Regular     14px / 20px line-height / FontWeight.w400
Body Small       12px / 16px line-height / FontWeight.w400
Caption / Badge  10px / 12px line-height / FontWeight.w700 (Letter-spacing +0.5px)
```

### Flutter Typography Contract

```dart
abstract final class AppTypography {
  static const String fontFamily = 'Inter';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    height: 38 / 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const TextStyle badge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    height: 12 / 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );
}
```

---

## 4. Elevation, Radii & Spacing Grid

### 4.1 Corner Radii (`AppRadius`)

* **Full Pill (`9999px`)**: Action chips, filter pills, CTAs (`+ Create`), status badges, search input.
* **Containers & Cards (`16px`)**: Track cover containers, featured banners, creator grid cards, modal sheets.
* **Thumbnails & Inputs (`12px`)**: Track list tiles (`48x48`), text input fields, dropdown trigger buttons.
* **Avatars (`Circular / 9999px`)**: Monogram creator avatars, user profile icons.

```dart
abstract final class AppRadius {
  static const double pill = 9999.0;
  static const double card = 16.0;
  static const double input = 12.0;
  static const double thumb = 8.0;

  static const BorderRadius pillBorder = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius cardBorder = BorderRadius.all(Radius.circular(card));
  static const BorderRadius inputBorder = BorderRadius.all(Radius.circular(input));
}
```

### 4.2 Spacing & Padding Metrics (`AppSpacing`)

Based on an 8-point layout grid:

```dart
abstract final class AppSpacing {
  static const double xxs = 4.0;
  static const double xs  = 8.0;
  static const double sm  = 12.0;
  static const double md  = 16.0;
  static const double lg  = 20.0;
  static const double xl  = 24.0;
  static const double xxl = 32.0;
  static const double section = 40.0;
}
```

---

## 5. Dart Design Tokens Implementation Contract

```dart
// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

abstract final class AppColors {
  // Surfaces
  static const Color surfaceCanvas    = Color(0xFF0A0A0C);
  static const Color surfaceElevated  = Color(0xFF141418);
  static const Color surfaceSecondary = Color(0xFF1B1B22);
  static const Color surfaceModal     = Color(0xFF16161C);
  static const Color borderSubtle     = Color(0xFF2D2D38);
  static const Color borderActive     = Color(0xFF4B4B5A);

  // Brand Accents
  static const Color brandPrimary     = Color(0xFFF97316);
  static const Color brandPrimaryDark = Color(0xFFEA580C);
  static const Color brandContrast    = Color(0xFF000000);

  // Status & Badges
  static const Color badgeCyanText    = Color(0xFF22D3EE);
  static const Color badgeCyanBg      = Color(0xFF0E3842);
  static const Color streakFire       = Color(0xFFEA580C);
  static const Color success          = Color(0xFF10B981);
  static const Color error            = Color(0xFFEF4444);

  // Text
  static const Color textPrimary      = Color(0xFFFFFFFF);
  static const Color textSecondary    = Color(0xFF9CA3AF);
  static const Color textTertiary     = Color(0xFF6B7280);
}
```
