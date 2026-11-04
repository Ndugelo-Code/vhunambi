# Phase 43 Design: Universal Cross-Platform Native Social Share, Gallery Media Export & Legal Transparency

## 1. UI & Visual Hierarchy

### 1.1 LegalTransparencyModal
- Mounted via `showModalBottomSheet` with `isScrollControlled: true` and maximum height of `85%` screen height.
- Header: Gold shield icon (`PhosphorIconsFill.shieldCheck`) and Title "Creator Sovereignty & Legal Transparency".
- 4 Segmented Sections:
  1. **85% Sovereign Royalties**: Direct split breakdown (85% to Creator, 15% platform infrastructure).
  2. **Commercial Licensing**: Stem and Master commercial sync rights.
  3. **Bantu Heritage & Attribution**: Ethical AI sourcing, non-exclusive ownership, and cultural preservation.
  4. **SARB Direct Banking**: Capitec, FNB, Standard Bank, Nedbank, Absa, TymeBank direct EFT clearing.

### 1.2 Video Export Phosphor Syndication Dock
- 4 Circular icon buttons (52x52dp):
  - TikTok: `PhosphorIconsFill.tiktokLogo`
  - Instagram Reels: `PhosphorIconsFill.instagramLogo`
  - YouTube Shorts: `PhosphorIconsFill.youtubeLogo`
  - Save to Gallery: `PhosphorIconsFill.floppyDisk`
- Micro-labels rendered in `AppTypography.caption` with `AppColors.textSecondaryOf(context)`.

### 1.3 Export Action Sheet
- Success container rendered with `AppColors.brandPrimary.withValues(alpha: 0.1)` and `PhosphorIconsFill.checkCircle`.
- Buttons updated with `PhosphorIconsRegular.paperPlaneRight`, `PhosphorIconsRegular.copy`, and `PhosphorIconsRegular.downloadSimple`.

