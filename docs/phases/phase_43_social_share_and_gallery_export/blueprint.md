# Phase 43 Blueprint: Universal Cross-Platform Native Social Share, Gallery Media Export & Legal Transparency

## 1. Executive Summary
Phase 43 seals the final production surface of the Vhunambi platform before compiling the release APK. It provides end-to-end social syndication, cross-platform media export with persistent notification receipts, and total legal and royalty transparency. 

## 2. Core Architectural Tracks
- **Track A: Legal & Royalty Transparency Modal**: A dedicated bottom sheet in `landing_footer.dart` detailing the 85% Creator Sovereign Royalty guarantee, Master & Stem commercial licensing terms, and South African SARB-compliant EFT payouts.
- **Track B: Universal Social Post Share Rail**: Upgrading Explore social card sharing to copy link, trigger native sharing protocols, and dispatch activity alerts to `notificationsProvider`.
- **Track C: Modernized Video Export Modal & Phosphor Syndication**: Stripping legacy emojis in favor of crisp Phosphor icons (`PhosphorIcons.tiktokLogo`, `instagramLogo`, `youtubeLogo`, `floppyDisk`), dynamic `AppColors.*Of(context)` theme styling, and dispatching notification events.
- **Track D: Content Studio Export Action Sheet**: Modernizing `export_action_sheet.dart` with Phosphor icons, dynamic theme colors, and gallery save / social share receipts.

## 3. Invariants & Guardrails
- **Zero Raw Emojis**: Comply strictly with STD-UIUX-001 by using Phosphor vector icons exclusively.
- **Dynamic Theming**: Use `AppColors.*Of(context)` across all sheets and dialogs to guarantee light/dark contrast parity.
- **Reactive Notification Receipts**: Every user-initiated export, copy, or social share action dispatches a verifiable event to `notificationsProvider`.

