# 🔍 Vhunambi Flaws & Unfinished Features Master Audit

> **Canonical Document Reference:** [FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md)  
> **Document ID:** `AUDIT-FLAWS-UNFINISHED-001`  
> **Standard Reference:** `STD-UIUX-001` (Vhunambi UI/UX, Touch Physics & Iconography Standard)  
> **Status:** Active Engineering Living Audit & Remediation Roadmap  
> **Target:** Mobile Client (`apps/vhunambi_client`), Backend API (`apps/vhunambi_api`)

---

## Quick Navigation

1. [Executive Summary & Core Philosophy](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md#1-executive-summary--audit-philosophy)
2. [Category A: Top Bar & Navigation Chrome Inconsistencies](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md#2-category-a-top-bar--header-navigation-chrome-inconsistencies)
   - Home Dashboard Golden Standard vs Studio, Marketplace, Library & Explore
3. [Category B: The Notification Dual-Surface Defect](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md#3-category-b-the-notification-dual-surface-defect)
   - 360px `NotificationsPopover` Dialog vs Modern Fullscreen `NotificationsView`
4. [Category C: Design System & Iconography Violations (`STD-UIUX-001`)](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md#4-category-c-design-system--iconography-violations-std-uiux-001)
   - Residual Stock Material Icons Inventory (`Icons.*`)
   - Strict Emoji Ban Violations in UI Controls & Toasts
5. [Category D: Unfinished Features & Placeholder "SnackBar/Toast" Dead-Ends](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md#5-category-d-unfinished-features--placeholder-snackbartoast-dead-ends)
   - Subscription Upgrade Modal Stub
   - Disconnected "Add to Playlist" on Track Detail
   - Profile Action Stubs (Edit Profile, Pin Song, Studio Analytics)
   - Video Export & Content Studio Social Share Stubs
   - Landing Footer Legal Link Stubs
   - Creator Royalty Payout Account Data Defect
   - Hardcoded Sender Identity in Tipping Sheet
6. [Category E: Dormant, Dead & Orphaned Code](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md#6-category-e-dormant-dead--orphaned-code)
   - `AfricanChartsBanner`, `CreatorCard`, `ExploreHeaderSection`, `GenreRadioTile`, `FluidDeckSwitcher`, `fake_stem_download_service.dart`
7. [Category F: Simulated Production Services & Pipelines](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md#7-category-f-simulated-production-services--pipelines)
   - Silent Stem Mix Bounce, `simulateDownloads: true` Production Default, Mock Storage Mastering Fallbacks
8. [Category G: Backend API Route Gaps (`apps/vhunambi_api`)](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md#8-category-g-backend-api-route-gaps-appsvhunambi_api)
9. [Prioritized Remediation Roadmap (Sprints M4–M8)](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md#9-prioritized-remediation-roadmap)
10. [User Device Testing Notes & Field Findings (Reserved Section)](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md#10-user-device-testing-notes--field-findings)
11. [Post-Phase-63 Live Cloud Deployment & Physical Device Gap Audit (`2026-11-12`)](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md#11-post-phase-63-live-cloud-deployment--physical-device-gap-audit-2026-11-12)

---

> Please read and edit the canonical document at:  
> **`docs/audits/FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md`**

