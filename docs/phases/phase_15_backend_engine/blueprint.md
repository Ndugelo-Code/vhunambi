# Phase 15 · Blueprint — Autonomous African AI Music Synthesis API Gateway & Full-Stack Bridge

> **Phase:** 15  
> **Codename:** `backend-engine-bridge`  
> **Status:** 🟡 SPECIFICATION  
> **Repository Root:** `c:\Users\Ndugelo\VHUNAMBI\monorepo\`  
> **Target App:** `apps/vhunambi_api` (Backend) & `apps/vhunambi_client` (Flutter Client)  
> **Architecture Standard:** Dual-Agent Pair Programming Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  
> **Foundation Blueprints:**  
> — `docs/foundation_blueprints/03_CREATE_STUDIO_SPEC.md` (§4 — State Machine & Payload)  
> — `docs/foundation_blueprints/07_AUDIO_TRANSPORT_AND_PIPELINE_MODALS_SPEC.md` (§5 — Provider Contracts)  
> — `C:\Users\Ndugelo\Zania-Explore-v2.5\Zania-Explore\lib\zr-studio\` (ZR Studio Synthesis Engine SSOT)  

---

## 1. Executive Summary & Purpose

Phase 15 transitions VHUNAMBI from a client-only prototype into a **fully autonomous, end-to-end African AI music synthesis and commercial licensing platform**.

By colocating the ZR Studio backend architecture from `Zania-Explore` into `apps/vhunambi_api`, this monorepo gains:
1. **Real AI Music Synthesis Engine**: Integration with **ACE-Step** on RunPod Serverless GPU infrastructure.
2. **Authentic Story-to-Lyrics Engine**: Claude 3.5 Sonnet & Grok-backed generation producing authentic African genre verse-chorus stanzas (`[INTRO]`, `[VERSE 1]`, `[CHORUS]`, `[BRIDGE]`, `[OUTRO]`).
3. **Bantu Linguistic & Cultural Engine**: Deep phonetic guides, cognate enrichment, and language-neutral genre DNA supporting 9+ indigenous South African languages (featuring Tshivenḓa `ve-ZA`).
4. **Cloudflare R2 Presigned Audio Storage**: Direct GPU-to-bucket uploads for 320kbps master MP3s and 4-stem ZIP packages, eliminating dead CDN domains.
5. **Real-time Pipeline Dispatch & Bridge**: Connecting Flutter’s `StudioFormNotifier`, `LyricsReviewModal`, and `GenerationPipelineNotifier` to live backend APIs.

---

## 2. End-to-End System Topology

```mermaid
graph TD
    subgraph "Client Tier (Flutter / Riverpod)"
        UI[Studio Cockpit / Lyrics Review Modal]
        FN[StudioFormNotifier]
        LN[LyricsReviewNotifier]
        GN[GenerationPipelineNotifier]
        Downloader[StemDownloadService]
    end

    subgraph "API Tier (apps/vhunambi_api - Next.js / TypeScript)"
        Router[API Gateway: /v1]
        LyricsRoute[/v1/lyrics/generate & refine]
        GenRoute[/v1/generations]
        StatusRoute[/v1/generations/:id]
        SocketGateway[/ws/generation WebSocket Server]
        WebhookRoute[/v1/webhooks/ace-step HMAC-SHA256]
        Compiler[PromptCompiler + BantuEngine]
        D1[(Database: D1 / SQLite)]
    end

    subgraph "AI & Storage Infrastructure"
        Claude[Anthropic Claude / Grok LLM]
        RunPod[RunPod Serverless GPU: ACE-Step]
        R2[(Cloudflare R2 Object Storage)]
    end

    %% Client to API
    UI -->|1. Generate Lyrics| LN
    LN -->|HTTP POST| LyricsRoute
    LyricsRoute -->|2. Genre-structured Prompt| Claude
    Claude -->|Return bracketed stanzas| LyricsRoute
    LyricsRoute -->|JSON Stanzas| LN

    UI -->|3. Approve & Produce Beat| FN
    FN -->|Trigger Synthesis| GN
    GN -->|4. HTTP POST /v1/generations| GenRoute
    GenRoute -->|5. Compile SongSpec| Compiler
    GenRoute -->|6. Presigned PUT URLs| R2
    GenRoute -->|7. Dispatch Job| RunPod
    GenRoute -->|Record Job & Return gen_id| D1
    GenRoute -->|{ generation_id, status: queued }| GN

    %% Real-time updates
    GN -.->|8. Connect wss://...| SocketGateway
    RunPod -->|9. HMAC-signed Progress Ticks| WebhookRoute
    WebhookRoute -->|Update Job Record| D1
    WebhookRoute -->|Emit Frame to Socket| SocketGateway
    SocketGateway -.->|10. PipelineSocketEvent (step, progress)| GN

    %% Completion & Download
    RunPod -->|11. Direct PUT master.mp3 & stems.zip| R2
    WebhookRoute -->|12. Final 'ready' Event| SocketGateway
    SocketGateway -.->|ready event with master_mp3_url| GN
    GN -->|13. Stream master.mp3 into vault| Downloader
    Downloader -->|Presigned GET| R2
```

---

## 3. Directory Layout in Monorepo

```
c:\Users\Ndugelo\VHUNAMBI\monorepo\
├── apps/
│   ├── vhunambi_client/            # Cross-Platform Flutter Client (Phases 0–14)
│   │   └── lib/features/
│   │       └── studio/
│   │           └── data/services/  # HttpLyricsGenerationService, HttpGenerationService
│   │
│   └── vhunambi_api/               # Standalone Synthesis & Lyrics API Gateway
│       ├── package.json            # Node / TypeScript dependencies
│       ├── tsconfig.json
│       ├── .env.example
│       ├── src/
│       │   ├── core/               # Environment, auth session, rate limiters, crypto
│       │   ├── db/                 # Drizzle ORM schema (songs, jobs, credits)
│       │   ├── bantu/              # Bantu language context & Tshivenḓa glossary
│       │   ├── lyrics/             # Claude/Grok lyrics engine & African genre prompts
│       │   ├── synthesis/          # PromptCompiler, RunPod adapter, R2 presigned URLs
│       │   └── routes/             # Next.js / Hono route handlers:
│       │       ├── lyrics.ts       # POST /v1/lyrics/generate, /v1/lyrics/refine
│       │       ├── generations.ts  # POST /v1/generations, GET /v1/generations/:id
│       │       ├── websocket.ts    # WebSocket bridge for /ws/generation
│       │       └── webhooks.ts     # POST /v1/webhooks/ace-step
│
└── docs/
    └── phases/
        └── phase_15_backend_engine/
            ├── blueprint.md
            ├── requirements.md
            ├── design.md
            └── tasks.md
```

---

## 4. Synthesis State Machine & Bridge Synchronization

The backend maintains strict state alignment with Flutter’s Phase 10 FSM ([`PipelineStep`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/studio/domain/models/generation_pipeline_state.dart)):

| Backend Job Status | WebSocket Frame Step | Flutter UI Representation | Progress % Range |
| :--- | :--- | :--- | :--- |
| `queued` | `queued` | "Queued for synthesis..." | `0% – 10%` |
| `running` (stage 1) | `synthesizing` | "Rendering Amapiano log drum groove..." | `11% – 60%` |
| `running` (stage 2) | `separating_stems`| "Demixing Drums, Bass, Melody stems..." | `61% – 90%` |
| `uploading` | `separating_stems`| "Finalizing master upload to R2..." | `91% – 99%` |
| `succeeded` | `ready` | "Master Ready • Tap to Play / Download" | `100%` |
| `failed` | `failed` | Error banner + Retry button | N/A |

---

## 5. Security & Authentication Architecture

1. **Client Request Auth**: Bearer JWT tokens stored in Hive [`tokenBoxKey`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/core/constants/app_constants.dart#L9), verified via `requireAuth` in the backend.
2. **GPU Worker Webhook Auth**: Every webhook from RunPod passes an `x-zrs-signature` header containing `HMAC-SHA256(rawBody, ZR_WEBHOOK_SECRET)`. Mismatched signatures return `401 Unauthorized` and prevent replay attacks.
3. **Audio Delivery**: Cloudflare R2 presigned GET URLs with a 24-hour expiration token, ensuring audio assets cannot be scraped anonymously.
