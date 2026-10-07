# Phase 15 · Technical Design — Full-Stack Autonomous Synthesis Architecture

> **Phase:** 15  
> **Codename:** `backend-engine-bridge`  
> **Status:** 🟡 SPECIFICATION  
> **Repository Root:** `c:\Users\Ndugelo\VHUNAMBI\monorepo\`  
> **Target Apps:** `apps/vhunambi_api` & `apps/vhunambi_client`  

---

## 1. Backend Service Design (`apps/vhunambi_api`)

### 1.1 Technology Stack & Structure
The backend is built as a lightweight, lightning-fast TypeScript service using Node/Hono or Next.js API runtime with zero heavy framework overhead:

```
apps/vhunambi_api/
├── package.json
├── tsconfig.json
├── .env.example
├── src/
│   ├── index.ts                      # Server entry point (default port 3000)
│   ├── config/
│   │   └── env.ts                    # Zod-validated environment config
│   ├── modules/
│   │   ├── lyrics/
│   │   │   ├── llm_handler.ts        # Claude 3.5 Sonnet & Grok caller
│   │   │   ├── system_prompts.ts     # African genre prompt templates
│   │   │   └── lyrics_service.ts     # Transform & refine coordinator
│   │   ├── bantu/
│   │   │   ├── language_context.ts   # Bantu phonetic & linguistic metadata
│   │   │   └── tshi_venda.ts         # Tshivenḓa vocabulary, idioms & proverbs
│   │   ├── synthesis/
│   │   │   ├── prompt_compiler.ts    # SongSpec -> ACE-Step caption & metadata
│   │   │   ├── runpod_adapter.ts     # RunPod Serverless /run & /status caller
│   │   │   ├── mock_worker.ts        # Local mock simulator when RunPod API key absent
│   │   │   └── r2_storage.ts         # Cloudflare R2 Presigned PUT/GET URLs
│   │   └── jobs/
│   │       ├── job_store.ts          # In-memory / SQLite / D1 job tracking state
│   │       └── job_types.ts          # JobStatus, GenerationJob entity
│   └── routes/
│       ├── lyrics_routes.ts          # POST /v1/lyrics/generate, POST /v1/lyrics/refine
│       ├── generation_routes.ts      # POST /v1/generations, GET /v1/generations/:id
│       └── webhook_routes.ts         # POST /v1/webhooks/ace-step (HMAC verification)
```

### 1.2 Data Schemas & API Contracts

#### Lyrics Generation Request (`POST /v1/lyrics/generate`)
```typescript
export interface GenerateLyricsRequest {
  prompt: string;
  genre: string;
  language: string; // e.g., 've', 'zu', 'xh', 'en'
}

export interface GenerateLyricsResponse {
  rawLyrics: string;
  stanzas: Array<{
    type: 'intro' | 'verse' | 'pre_chorus' | 'chorus' | 'bridge' | 'outro';
    header: string; // e.g. '[VERSE 1]'
    lines: string[];
  }>;
  vocalInstructions: string;
  cultureTags: string[];
  moodAnalysis: string[];
}
```

#### Job Submission Request (`POST /v1/generations`)
```typescript
export interface SubmitGenerationRequest {
  trackTitle: string;
  genre: string;
  language: string;
  lyrics: string;
  isInstrumental: boolean;
  tempoBpm?: number;
  musicalKey?: string;
}

export interface SubmitGenerationResponse {
  generationId: string;
  status: 'queued';
  pollUrl: string;
  websocketUrl: string;
}
```

#### Job Status Response (`GET /v1/generations/:id`)
```typescript
export interface GenerationStatusResponse {
  generationId: string;
  status: 'queued' | 'running' | 'succeeded' | 'failed';
  step: 'queued' | 'synthesizing' | 'separating_stems' | 'ready' | 'failed';
  progressPct: number; // 0..100
  masterMp3Url?: string; // 24-hr presigned R2 GET URL
  stemsZipUrl?: string;
  durationSec?: number;
  errorMessage?: string;
}
```

---

## 2. Flutter Client Integration Design (`apps/vhunambi_client`)

### 2.1 Services & Providers Architecture

```
lib/features/studio/
├── data/services/
│   ├── http_lyrics_generation_service.dart   # Implements ILyricsGenerationService
│   ├── http_generation_service.dart          # Submits job & manages polling fallback
│   └── stem_download_service.dart            # Existing Dio streaming to <temp>
├── domain/services/
│   ├── i_lyrics_generation_service.dart      # Existing contract
│   └── i_generation_service.dart             # New contract for job dispatch
└── presentation/providers/
    ├── lyrics_review_provider.dart           # Wired to httpLyricsGenerationServiceProvider
    └── generation_pipeline_providers.dart    # Wired to HttpGenerationService + Socket
```

### 2.2 Dart Implementation Blueprint

#### `HttpLyricsGenerationService`
```dart
class HttpLyricsGenerationService implements ILyricsGenerationService {
  final Dio _dio;
  final String _baseUrl;

  HttpLyricsGenerationService({
    Dio? dio,
    String? baseUrl,
  })  : _dio = dio ?? Dio(),
        _baseUrl = baseUrl ?? AppConstants.apiBaseUrl;

  @override
  Future<LyricsReviewDraft> generateLyrics({
    required String prompt,
    required String genre,
    required String language,
  }) async {
    final response = await _dio.post(
      '$_baseUrl/lyrics/generate',
      data: {
        'prompt': prompt,
        'genre': genre,
        'language': language,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final stanzasJson = data['stanzas'] as List<dynamic>;

    final stanzas = stanzasJson.map((s) {
      final header = s['header'] as String;
      final lines = (s['lines'] as List<dynamic>).map((l) => l.toString()).toList();
      return LyricsStanza(
        header: header,
        body: lines.join('\n'),
      );
    }).toList();

    return LyricsReviewDraft(
      prompt: prompt,
      genre: genre,
      language: language,
      stanzas: stanzas,
      rawText: data['rawLyrics'] as String,
    );
  }

  @override
  Future<LyricsReviewDraft> regenerateLyrics(LyricsReviewDraft currentDraft) {
    return generateLyrics(
      prompt: currentDraft.prompt,
      genre: currentDraft.genre,
      language: currentDraft.language,
    );
  }
}
```

---

## 3. Baseline Repair Design (16 Beats Vault Tests)

The 16 failing tests in `test/features/beats/` occurred due to an unseeded mock in the provider state test and an unmounted route navigator in `beats_vault_view_test.dart`.

* **Fix 1 (`beats_provider_test.dart`)**: Ensure test fixtures explicitly seed the 3 default African producer beats via `InMemoryBeatRepository(seedDemoData: true)` before exercising ordering filters.
* **Fix 2 (`beats_vault_view_test.dart`)**: Wrap cockpit view tests inside `MaterialApp` with explicit mock navigation observers to prevent null-assertion exceptions on publish and stem export.
