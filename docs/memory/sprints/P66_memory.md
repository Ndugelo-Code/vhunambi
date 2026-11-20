```json vhunambi-memory
{
  "phase_id": "P66",
  "memory_key": "MEM-P66-AUDIO-PROMPT-HYGIENE-V3",
  "title": "VH001-VH006 Studio Cockpit Wiring, ACE-Step Lyric Sanitizer, Bantu Phonetic Guard & -14 LUFS Mastering",
  "status": "completed",
  "completed_at": "2026-11-16",
  "predecessor_keys": ["MEM-P65-FOUNDATION-CRASH-IMMUNITY"],
  "concept_hubs": ["ai_synthesis_gpu", "mood_taxonomy"],
  "consumes": ["EP-P65-CRASH-AUDIO-SHIELD"],
  "endpoints": [
    {
      "id": "EP-P66-ACESTEP-PROMPT-HYGIENE",
      "kind": "synthesis_pipeline",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["ai_synthesis_gpu", "mood_taxonomy"],
      "spec_anchor": "docs/AGENT_HANDOFF_BIBLE.md#L1840-L1912",
      "code_anchor": "apps/vhunambi_api/src/modules/lyrics/lyrics_sanitizer.ts",
      "summary": "Comma-separated ACE-Step style tags (buildAceStepStyleTags), bracketed stage-direction lyric sanitizer, Bantu Latin language guard, and gentle -14.0 LUFS mastering.",
      "consumers": [
        "P66:prompt_compiler.ts",
        "P66:runpod_adapter.ts",
        "P66:tools/zr-studio-gpu/model_utils.py",
        "P66:tools/zr-studio-gpu/stem_mastering_worker.py"
      ],
      "open_opportunities": "Feed unified VhunambiMood taxonomy directly into buildAceStepStyleTags() once EP-P68-MOOD-FRAGMENTED is unified"
    },
    {
      "id": "EP-P66-LYRICS-REFINE-STORY",
      "kind": "backend_api",
      "state": "OPEN",
      "hubs": ["ai_synthesis_gpu", "mood_taxonomy"],
      "spec_anchor": "docs/audits/VHUNAMBI_REPO_TOPOLOGY_AND_MEMORY_READINESS_AUDIT.md",
      "code_anchor": "apps/vhunambi_api/src/routes/lyrics_routes.ts",
      "summary": "POST /v1/lyrics/refine & POST /v1/lyrics/story-transform endpoints.",
      "consumers": [],
      "open_opportunities": "Wire line-level AI lyric refinement and story-to-lyrics transform UI inside Studio Lyrics Review (HttpLyricsGenerationService only calls /v1/lyrics/generate)"
    }
  ],
  "edges": [
    {
      "from": "apps/vhunambi_client/lib/features/studio/presentation/providers/generation_pipeline_providers.dart",
      "relation": "PROVIDES",
      "to": "apps/vhunambi_api/src/routes/generation_routes.ts",
      "note": "Passes mood from studioFormProvider end-to-end into buildAceStepStyleTags()"
    }
  ],
  "breakthroughs": [
    "Un-spec'd sprint (commit c70fcde / vhunambi-v3): replaced destructive Demucs 4-stem re-summing (-9.5 LUFS) with master_clean_stereo_gentle() at -14.0 LUFS / -1.0 dBTP.",
    "Added _install_latin_language_guard() in tools/zr-studio-gpu/model_utils.py to stop py3langid/LangSegment from misclassifying Bantu lyrics as Mandarin Chinese."
  ],
  "gotchas": [
    "Non-structural bracketed stage directions (e.g. [Log drum drop]) are sung aloud by ACE-Step unless stripped by lyrics_sanitizer.ts / sanitize_lyrics_for_ace_step().",
    "This sprint had no docs/phases/phase_66 folder; documented in docs/AGENT_HANDOFF_BIBLE.md Section 42 and preserved here."
  ]
}
```

# Phase 66 Sprint Memory (`vhunambi-v3` Audio & Prompt Hygiene)

Captured in `docs/memory/sprints/` because Phase 66 shipped directly via commit `c70fcde` + `f87b38c` without a `docs/phases/phase_66_*` folder.
