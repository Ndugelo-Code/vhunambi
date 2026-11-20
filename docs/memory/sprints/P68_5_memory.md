```json vhunambi-memory
{
  "phase_id": "P68.5",
  "memory_key": "MEM-P68-5-MADONI-CINEMA-SPLASH",
  "title": "Phase 68.5 Cinema Splash Screen & Madoni Software Parent Attribution",
  "status": "completed",
  "completed_at": "2026-11-18",
  "predecessor_keys": ["MEM-P68-HOME-MAIN-ROOM"],
  "concept_hubs": ["media_artwork", "ui_surface_std"],
  "consumes": [],
  "endpoints": [
    {
      "id": "EP-P68-5-MADONI-BRANDING",
      "kind": "brand_assets",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["media_artwork", "ui_surface_std"],
      "spec_anchor": "docs/audits/VHUNAMBI_REPO_TOPOLOGY_AND_MEMORY_READINESS_AUDIT.md",
      "code_anchor": "apps/vhunambi_client/lib/features/onboarding/presentation/views/splash_view.dart",
      "summary": "Full-bleed sunset Cinema Splash (SplashView), obsidian launch_background.xml eliminating white flash, and AppAssets.madoniSoftwareLogo / madoniSoftwareIcon.",
      "consumers": ["P68.5:splash_view", "P68.5:launch_background.xml"],
      "open_opportunities": "Reuse AppAssets.madoniSoftwareLogo in Settings/About drawer and legal attribution footer"
    }
  ],
  "edges": [
    {
      "from": "apps/vhunambi_client/lib/features/onboarding/presentation/views/splash_view.dart",
      "relation": "CONSUMES",
      "to": "apps/vhunambi_client/lib/core/constants/app_assets.dart",
      "note": "Reads AppAssets.splashHero and AppAssets.madoniSoftwareLogo"
    }
  ],
  "breakthroughs": [
    "Eliminated Android cold-start white flash via obsidian #FF0A0A0C launch_background.xml (drawable + drawable-v21) paired with animated SplashView.",
    "Registered assets/branding/madonisoftware/madoni_logo.png and android-chrome-192x192.png in pubspec.yaml and AppAssets."
  ],
  "gotchas": [
    "Un-spec'd sprint bundled into commit bf7ca98 with no docs/phases/ folder; tracked here under docs/memory/sprints/ so future sessions never overwrite splash_view.dart or launch_background.xml."
  ]
}
```

# Phase 68.5 Sprint Memory (Madoni Software Cinema Splash)

Verified in [`splash_view.dart`](../../../apps/vhunambi_client/lib/features/onboarding/presentation/views/splash_view.dart#L17-L420), [`app_assets.dart`](../../../apps/vhunambi_client/lib/core/constants/app_assets.dart#L46-L53), and [`launch_background.xml`](../../../apps/vhunambi_client/android/app/src/main/res/drawable/launch_background.xml).
