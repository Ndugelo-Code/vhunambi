# Forensic Specification Hardening Checklist (Argon Gate)

Use this checklist during **Stage 2 (Flash Spec Drafting)** and **Stage 3 (Argon Codebase Spec Hardening)** to verify that all 4 files in `docs/phases/phase_XX_<name>/` are 100% unified and free of implementation traps before Stage 4 code execution.

---

## 1. The 6 Forensic Trap Checks

| Trap # | Trap Name | What to Inspect in `blueprint.md`, `requirements.md`, `design.md`, `tasks.md` | Required Pass Condition |
| :--- | :--- | :--- | :--- |
| **Trap 1** | **Theory-vs-Code Bait-and-Switch** | Compare the mathematical equations in `design.md` §2 with the actual `CustomPainter` / service implementation in `design.md` §8 and method signatures in `tasks.md`. | `design.md` §8 implements the exact 3D mesh (`ui.Vertices`), spline waypoints, and shading passes defined in §2—never downgrading to flat 2D `drawOval` or single-line shortcuts. |
| **Trap 2** | **Coordinate Axis Contradiction** | Compare coordinate tuples $(X, Y, Z)$ and elevation equations across `blueprint.md` §4/§8, `requirements.md` §2, `design.md` §2/§3/§8, and `tasks.md` §4. | All 4 documents use **Right-Handed 3D Y-Up World Space** ($X$ horizontal, $+Y$ vertical elevation UP, $+Z$ foreground depth) with identical $(X_k, Y_{\text{root}}, Z_k)$ and $(X_k, Y_{\text{apex}}, Z_k)$ coordinates. |
| **Trap 3** | **Dead Hit-Testing / Unwired Callbacks** | Inspect every callback field (`onTap`, `onHitBoxesUpdated`, etc.) on painters and widgets in `design.md` §8–§12. | Every declared callback is invoked, OR hit-testing is handled synchronously via `ProjectionEngine.hitTest(...)` paired with semantic `Positioned` widget keys (`Key('...')`). |
| **Trap 4** | **Hallucinated Package & Token Names** | Grep all `import` statements, `AppColors.*`, `AppTypography.*`, and `PhosphorIcons*` in `design.md` and `tasks.md`. | Uses `package:vhunambi_client/...`, `package:phosphor_icons/phosphor_icons.dart`, valid `AppColors` tokens (`darkSurfaceElevated`, `darkSurfaceCanvas`, `brandPrimary`), and valid `AppTypography` getters (`titleLarge`, `titleMedium`, `titleSmall`, `bodyLarge`, `bodySmall`, `caption`, `badge`). |
| **Trap 5** | **Missing HUD Decks or Controls** | Cross-check every `REQ-PXX-HUD-*` requirement in `requirements.md` against widget classes in `design.md` and tasks in `tasks.md`. | 100% of required HUD decks, filter pills, and interactive control bars have complete Dart widget classes in `design.md` and tasks in `tasks.md`. |
| **Trap 6** | **Model Class Name Drift Across Docs** | Compare class and enum names in `design.md` §3 against `design.md` §8–§12 and `tasks.md`. | Identical class and enum names are used across all sections and files (e.g., `MyceliumClusterDomain`, `MushroomFruitingBody`, `MyceliumChildNode`, `MyceliumHyphaEdge`, `MusicalDnaGraph`). |

---

## 2. Authentic Vhunambi Token Reference Cheat-Sheet

### 2.1 Valid `AppColors` Tokens (`lib/core/theme/app_colors.dart`)
- **Dark Surfaces**: `AppColors.darkSurfaceCanvas` (`#0A0A0C`), `AppColors.darkSurfaceElevated` (`#141418`), `AppColors.darkSurfaceSecondary` (`#1B1B22`), `AppColors.darkSurfaceModal` (`#16161C`).
- **Borders**: `AppColors.darkBorderSubtle` (`#2D2D38`), `AppColors.darkBorderActive` (`#4B4B5A`).
- **Dynamic Context Adapters**: `AppColors.surfaceCanvasOf(context)`, `AppColors.surfaceElevatedOf(context)`, `AppColors.surfaceSecondaryOf(context)`, `AppColors.surfaceModalOf(context)`, `AppColors.borderSubtleOf(context)`, `AppColors.textPrimaryOf(context)`, `AppColors.textSecondaryOf(context)`.
- **Brand & Accents**: `AppColors.brandPrimary` (`#F97316`), `AppColors.brandPrimaryDark` (`#EA580C`), `AppColors.brandContrast` (`#000000`), `AppColors.badgeCyan` (`#22D3EE`), `AppColors.coinGold` (`#F59E0B`), `AppColors.success` (`#10B981`), `AppColors.error` (`#EF4444`), `AppColors.accentElectric` (`#8B5CF6`).

### 2.2 Valid `AppTypography` Getters (`lib/core/theme/app_typography.dart`)
- **Standard Inter Scales**: `AppTypography.displayLarge` (32px), `AppTypography.displayMedium` (28px), `AppTypography.titleLarge` (20px), `AppTypography.titleMedium` (16px), `AppTypography.titleSmall` (14px), `AppTypography.bodyLarge` (14px), `AppTypography.bodyMedium` (14px), `AppTypography.bodyMuted` (14px secondary), `AppTypography.bodySmall` (12px), `AppTypography.caption` (11px), `AppTypography.badge` (10px).
- **Kinetic Outfit Scales**: `AppTypography.bouncyDisplayLarge` (28px w900), `AppTypography.bouncyTitleLarge` (22px w800), `AppTypography.bouncyBadge` (11px w800).
- **FORBIDDEN (Do Not Exist)**: `AppTypography.labelSmall`, `AppTypography.labelMedium`, `AppTypography.headlineSmall`.

### 2.3 Valid Phosphor Icon Imports
- Import: `import 'package:phosphor_icons/phosphor_icons.dart';`
- Usage: `PhosphorIcon(PhosphorIconsBold.dna, size: 18, color: ...)` or `PhosphorIconsRegular.*` / `PhosphorIconsFill.*`.
- **FORBIDDEN**: `import 'package:phosphor_flutter/phosphor_flutter.dart';` or raw unicode emojis (`STD-UIUX-001`).

