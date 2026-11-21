```json vhunambi-memory
{
  "phase_id": "P72",
  "memory_key": "MEM-P72-ASSET-VAULT-OWNER-PROFILE-GLASS",
  "title": "Asset Vault (LibraryView) & Owner Studio Profile (OwnerProfileView) Glass Overhaul, ViewerRole.owner Parity & Library/Playlist/License Cloud SWR",
  "status": "completed",
  "completed_at": "2026-11-21",
  "predecessor_keys": [
    "MEM-P68-HOME-MAIN-ROOM",
    "MEM-P69-KINETIC-POST-FOCUS",
    "MEM-P70-SONG-COCKPIT-VISITOR-PROFILE",
    "MEM-P71-CLOUD-SPINE-CONNECTOME-CLOSURE"
  ],
  "concept_hubs": [
    "media_artwork",
    "ui_surface_std",
    "identity_role",
    "mood_taxonomy",
    "quota_economy",
    "sync_outbox",
    "audio_transport",
    "social_graph"
  ],
  "consumes": [
    "EP-P70-GLASS-SURFACE",
    "EP-P68-TRACK-ARTWORK",
    "EP-P70-MOOD-TAXONOMY",
    "EP-P70-VIEWER-ROLE",
    "EP-P68-CREATOR-ALLOWANCE",
    "EP-P69-KPOST-FOCUS-ROUTE",
    "EP-P68-MINIPLAYER-SUPPRESS",
    "EP-P71-EDGE-SWR-READTHROUGH",
    "EP-P41-WALLET-DIRECT"
  ],
  "endpoints": [
    {
      "id": "EP-P72-VAULT-CLOUD-SWR",
      "kind": "backend_persistence",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["sync_outbox", "quota_economy"],
      "spec_anchor": "docs/phases/phase_72_asset_vault_and_owner_profile_glass_overhaul/design.md#1-pass-1-m721-backend-multi-isolate-swr--awaited-write-through-appsvhunambi_api",
      "code_anchor": "apps/vhunambi_api/src/db/edge_persistence_bridge.ts",
      "summary": "Domain-scoped 12s SWR read-through and awaited critical write-through for user_library_sync, playlists, marketplace_assets, and beat_licenses across Cloudflare Worker isolates with canonical creator/buyer ID matching and server.ts hasScopedReadThrough bypass.",
      "consumers": [
        "P72:library_routes",
        "P72:playlist_routes",
        "P72:marketplace_routes",
        "P72:server_scoped_bypass"
      ],
      "open_opportunities": "Extend domain-scoped SWR read-through to voice_routes (voice_models) and social_routes (reels/clips) to complete 100% route-level multi-isolate coverage"
    },
    {
      "id": "EP-P72-BUYER-LICENSES-HTTP",
      "kind": "client_repository",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["sync_outbox", "quota_economy"],
      "spec_anchor": "docs/phases/phase_72_asset_vault_and_owner_profile_glass_overhaul/design.md#2-pass-1-m722-client-asset-vault-glass-overhaul-viewerroleowner--buyer-licenses-appsvhunambi_client",
      "code_anchor": "apps/vhunambi_client/lib/features/marketplace/data/repositories/http_marketplace_repository.dart",
      "summary": "Client HTTP caller getBuyerLicenses(buyerId) hitting GET /api/marketplace/licenses/:buyerId via buyerLicensesFamilyProvider, hydrating cross-device SovereignLicenseCertificate purchases into BeatsVaultView Licensed Beats and LibraryCategory.licensing.",
      "consumers": [
        "P72:BeatsVaultView",
        "P72:LibraryView_licensing_tab"
      ],
      "open_opportunities": "Add offline Hive snapshot caching and certificate verification deep-link (GET /api/marketplace/licenses/verify/:certificateId) from licensed beat cards"
    }
  ],
  "edges": [
    {
      "from": "apps/vhunambi_client/lib/features/library/presentation/widgets/library_cover_art.dart",
      "relation": "CONSUMES",
      "to": "EP-P68-TRACK-ARTWORK",
      "note": "Replaces broken CachedNetworkImage('asset:...') loading across LibraryCoverArt, PlaylistCoverArt, CollectionArtworkPlaceholder, BeatsVaultView, and VaultStorageModal with VhunambiTrackArtwork"
    },
    {
      "from": "apps/vhunambi_client/lib/features/library/presentation/views/library_view.dart",
      "relation": "CONSUMES",
      "to": "EP-P70-GLASS-SURFACE",
      "note": "Wraps Asset Vault in VhunambiAmbientMeshBackdrop and VhunambiGlassSurface with enableLiveBlur: false on repeating list/grid tiles for 60 FPS Android rendering"
    },
    {
      "from": "apps/vhunambi_client/lib/features/track/presentation/providers/track_providers.dart",
      "relation": "CONSUMES",
      "to": "EP-P70-VIEWER-ROLE",
      "note": "Hydrates LibraryTrack.creatorId, creatorHandle, moodId, bpm, description, and allowOpenStemsRemix directly into TrackDetailNotifier so owned vault songs deterministically resolve ViewerRole.owner"
    },
    {
      "from": "apps/vhunambi_client/lib/features/library/presentation/widgets/library_app_bar.dart",
      "relation": "CONSUMES",
      "to": "EP-P68-CREATOR-ALLOWANCE",
      "note": "Replaces dead static '10 songs left' constant with live creatorAllowanceProvider pill in LibraryAppBar and embeds 10/10 monthly allowance card inside CreatorWalletDeck"
    },
    {
      "from": "apps/vhunambi_client/lib/features/profile/presentation/views/owner_profile_view.dart",
      "relation": "CONSUMES",
      "to": "EP-P68-MINIPLAYER-SUPPRESS",
      "note": "Ref-counts pushedFullScreenOverlayCountProvider in initState/dispose matching ArtistProfileView so MiniPlayerHost never overlaps OwnerProfileView"
    },
    {
      "from": "apps/vhunambi_client/lib/features/profile/presentation/views/owner_profile_view.dart",
      "relation": "CONSUMES",
      "to": "EP-P69-KPOST-FOCUS-ROUTE",
      "note": "Mounts live Owner Kinetic Posts shelf navigating directly to KineticPostFocusView(postId, initialPost)"
    },
    {
      "from": "apps/vhunambi_client/lib/features/profile/presentation/widgets/creator_wallet_deck.dart",
      "relation": "CONSUMES",
      "to": "EP-P41-WALLET-DIRECT",
      "note": "Reconciles legacy /api/wallet/summary catalog note with active GET /api/creators/:id/wallet + creatorWalletProvider and adds live creatorAllowanceProvider card inside CreatorWalletDeck"
    },
    {
      "from": "apps/vhunambi_api/src/routes/library_routes.ts",
      "relation": "CONSUMES",
      "to": "EP-P71-EDGE-SWR-READTHROUGH",
      "note": "Extends 12s domain-scoped SWR and awaited critical write-through to library_routes, playlist_routes, and marketplace_routes under EP-P72-VAULT-CLOUD-SWR"
    },
    {
      "from": "apps/vhunambi_client/lib/features/beats/presentation/views/beats_vault_view.dart",
      "relation": "CONSUMES",
      "to": "EP-P72-BUYER-LICENSES-HTTP",
      "note": "Hydrates remote buyer beat licenses from GET /api/marketplace/licenses/:buyerId into Licensed Beats tab"
    }
  ],
  "breakthroughs": [
    "Enriching LibraryTrack with explicit creatorId, creatorHandle, moodId, bpm, description, and allowOpenStemsRemix closes the subtle ViewerRole.visitor lockout caused by guessing ownership from display name strings when opening owned songs from LibraryView or OwnerProfileView.",
    "Routing LibraryCoverArt, PlaylistCoverArt, CollectionArtworkPlaceholder, PinnedSpotlightCard, BeatsVaultView, and VaultStorageModal through VhunambiTrackArtwork eliminates every failed CachedNetworkImage('asset:...') load on seeded vault songs and playlists while preserving deterministic genre artwork.",
    "Extending Phase 71's 12-second domain-scoped SWR pattern and awaited write-throughs to library_routes, playlist_routes, and marketplace_routes (with server.ts hasScopedReadThrough bypass) closes the remaining multi-isolate staleness gap for personal vaults, playlists, and purchased beat licenses."
  ],
  "gotchas": [
    "library_view_test.dart#L39, #L73 asserts find.text('10 songs left') and #L79 asserts find.byIcon(PhosphorIconsRegular.sparkle) == findsOneWidget on mobile; _AllowanceBalancePill in LibraryAppBar MUST use PhosphorIconsFill.musicNotes (never PhosphorIconsRegular.sparkle) and keep the '${remaining} songs left' format.",
    "AppColors defines surfaceElevatedOf, surfaceSecondaryOf, surfaceModalOf, borderSubtleOf, textPrimaryOf, and textSecondaryOf ONLY — there is no textTertiaryOf(context); always use AppColors.textSecondaryOf(context).",
    "Purging STD-UIUX-001 raw Unicode emojis and hardcoded track_own_01 ('ZaYN') in OwnerProfileView, CreatorWalletDeck, and AvatarCustomizationModal requires targeted test realignments in owner_profile_view_test.dart, creator_wallet_deck_test.dart, and avatar_customization_modal_test.dart during M72.4.",
    "Every new async SWR/write helper added to EdgeIsolateDatabaseEngine must be mirrored with an identical signature on VhunambiDatabase (vhunambi_db.ts) or tsc --noEmit fails on vhunambiDb.",
    "Keep enableLiveBlur: false on every VhunambiGlassSurface mounted inside ListView, GridView, or repeating profile studio cards to preserve the 60 FPS Android budget."
  ]
}
```

# Phase 72 Session Memory & Specification Summary

- **Specification Status:** `completed` (`2026-11-21` — Stage 4 Pass 1 & Pass 2 executed and verified: `apps/vhunambi_api` `tsc --noEmit` 0 errors & `28/28` suites passing; `apps/vhunambi_client` `flutter analyze --no-pub` 0 issues, all Phase 72 vault/track/profile suites & `phase72_asset_vault_and_owner_profile_test.dart` 6/6 passing, zero `Icons.` / raw emojis across touched modules).
- **Upstream Forensic Audit:** [`docs/audits/PHASE72_ASSET_VAULT_AND_OWNER_PROFILE_GLASS_OVERHAUL_AUDIT.md`](../../audits/PHASE72_ASSET_VAULT_AND_OWNER_PROFILE_GLASS_OVERHAUL_AUDIT.md).
- **Connectome Impact (Upon Stage 4 `SLEEP` Consolidation):**
  - **Consumes:** `EP-P70-GLASS-SURFACE`, `EP-P68-TRACK-ARTWORK`, `EP-P70-MOOD-TAXONOMY`, `EP-P70-VIEWER-ROLE`, `EP-P68-CREATOR-ALLOWANCE`, `EP-P69-KPOST-FOCUS-ROUTE`, `EP-P68-MINIPLAYER-SUPPRESS`, `EP-P71-EDGE-SWR-READTHROUGH`, and reconciles `EP-P41-WALLET-DIRECT`.
  - **Registers:** `EP-P72-VAULT-CLOUD-SWR` (`backend_persistence`, `CONNECTED_EXTENSIBLE`) and `EP-P72-BUYER-LICENSES-HTTP` (`client_repository`, `CONNECTED_EXTENSIBLE`).
- **Two-Pass Execution Plan:**
  - **Pass 1 (`M72.1`–`M72.2`):** Backend Library/Playlist/Marketplace 12s SWR durability (`28/28` API suites) + Client Asset Vault glass overhaul, `VhunambiTrackArtwork`, `LibraryTrack` `ViewerRole.owner` fidelity, live allowance, mobile `Cached Only`, and `EP-P72-BUYER-LICENSES-HTTP`.
  - **Pass 2 (`M72.3`–`M72.4`):** `OwnerProfileView` glass overhaul, Light-Mode contrast repair, `MiniPlayerHost` suppression, live owner songs + persisted visibility + Cockpit push, `OwnerBeatstoreCockpit` dynamic creator scoping, Owner Kinetic Posts shelf, `CreatorWalletDeck` live 10/10 allowance, 3 legacy profile test realignments, `phase72_asset_vault_and_owner_profile_test.dart`, and `consolidate_memory.mjs`.
