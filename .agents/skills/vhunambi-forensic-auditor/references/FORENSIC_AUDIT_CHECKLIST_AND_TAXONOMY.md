# Forensic Audit Checklist, 6-Pillar Inspection Matrix & Scan Recipes (`vhunambi-forensic-auditor`)

Use this reference guide during **Step 2 (Evidence Sweep)** and **Step 3 (Cross-Boundary Diffing)** of `vhunambi-forensic-auditor` to ensure zero blind spots across the Vhunambi monorepo.

---

## 1. The 6-Pillar Full-Stack Forensic Inspection Matrix

| Pillar | Target Directories | High-Yield Forensic Traps to Inspect |
| :--- | :--- | :--- |
| **Pillar 1: Flutter Lifecycle, Crash Shield & StateNotifiers** | `apps/vhunambi_client/lib/main.dart`, `lib/core/resilience/`, `lib/features/**/providers/` | • Missing `if (!mounted) return;` or `SafeNotifierMixin` after `await` in `StateNotifier` methods.<br>• Missing `if (!context.mounted) return;` in widgets after `await` before touching `ref` or `Navigator`.<br>• Stream `.listen(...)` calls missing `onError:` handlers or `.cancel()` in `dispose()`.<br>• `AnimationController` or `Timer.periodic` leaks on widget/notifier disposal.<br>• Duplicate state sources (e.g., local `_currentIndex` vs `appNavigationTabProvider`). |
| **Pillar 2: Audio Engines, ExoPlayer & 3D Biome Performance** | `apps/vhunambi_client/lib/features/player/`, `lib/features/studio/`, `lib/features/social/` | • Concurrent `just_audio` / `ExoPlayer` instances competing without `SafeAudioOrchestrator` mutex.<br>• Missing Android notification drawable resources (`drawable/ic_stat_music`) referenced by `AudioServiceConfig`.<br>• Synthetic `Timer.periodic` progress tickers running out of sync with real hardware `player.durationStream` / `positionStream`.<br>• Heavy 60 FPS 3D canvas/biome viewports mounted inside modal sheets where they cause frame drops on mobile GPUs.<br>• Unbounded `pumpAndSettle()` in widget tests on animated trees. |
| **Pillar 3: UI/UX Surface Harmony, `STD-UIUX-001` & Dead-End Stubs** | `apps/vhunambi_client/lib/features/**/views/`, `widgets/`, `lib/core/theme/`, `lib/core/widgets/` | • Raw Unicode emojis (`'🔥'`, `'🪙'`, `'✨'`, `'🎵'`) in UI strings or snackbars (`STD-UIUX-001` ban).<br>• Stock Material `Icon(Icons.*)` instead of `PhosphorIcon(AppIcons.*)`.<br>• Hardcoded hex colors (`Color(0xFF...)`) or nonexistent `AppColors` / `AppTypography` tokens.<br>• Touch targets smaller than $44 \times 44\text{dp}$ or `RenderFlex` overflows on `360x800` viewports.<br>• **SnackBar Dead-Ends**: Buttons that only call `showSnackBar(...)` instead of executing real logic or opening existing sheets.<br>• Missing `VhunambiBottomDockMetrics.scrollInset` or `PlayerObstacle` registration causing mini-player occlusion. |
| **Pillar 4: Sovereign Hive Vault, Offline Outbox & Safe JSON Parsing** | `apps/vhunambi_client/lib/core/storage/`, `lib/core/sync/`, `lib/core/utils/` | • Direct unsafe casts (`data['x'] as Map<String, dynamic>`, `(v as num).toDouble()`) instead of `JsonSafe.*` helpers.<br>• Single `try/catch` wrapping an entire loop of Hive records so 1 corrupt record aborts loading the whole snapshot.<br>• Static L1 caches in Phase 60 repositories not cleared during `SovereignHiveAccountSanitizer.sanitizeForAccountTransition()`.<br>• `SovereignAuthRepository.clearSession()` wiping `vhunambi_tokens` via `.clear()` instead of `.delete(sessionStorageKey)`, destroying `'onboarding_state_v1'`. |
| **Pillar 5: Cloudflare Worker (`workerd`), Hono Routes & Supabase/SQLite Parity** | `apps/vhunambi_api/src/worker.ts`, `src/server.ts`, `src/routes/`, `src/db/`, `supabase/migrations/` | • Unguarded `vhunambiDb.*` calls in routes loaded by `worker.ts` without `isNodeSqliteAvailable()` (`SQLITE_UNAVAILABLE_IN_EDGE_ISOLATE`).<br>• Volatile isolate `Map` fallbacks (`edgeIsolateFallbackJobs`, `edgeIsolateCheckouts`) losing state across Worker isolates.<br>• Adapters (`runpod_adapter.ts`, `comfyui_adapter.ts`) calling `resolveRuntimeEnv()` without passing per-request `c.env`.<br>• Background async tasks omitting `ctx.waitUntil(...)`.<br>• SQLite (`vhunambi_db.ts`) vs Postgres (`supabase/migrations/`) column name, primary key, `BIGINT` vs ISO string, and payout sign convention drift.<br>• `GenerationSessionDO` camelCase JSON vs Flutter `PipelineSocketEvent.fromJson` snake_case expectations. |
| **Pillar 6: RunPod Serverless GPU, ACE-Step 1.5, Demucs & R2 Media Integrity** | `tools/zr-studio-gpu/handler.py`, `model_utils.py`, `stem_mastering_worker.py`, `mmo_extractor.py`, `apps/vhunambi_api/src/modules/synthesis/` | • **Cockpit Parameter Drop**: Studio UI selections (`genre`, `language`, `mood`, `bpm`) ignored by `PromptInputBox`, `lyrics_routes.ts` (e.g., `prompt: z.string().min(1)` rejecting empty prompt when chips are selected), or `prompt_compiler.ts`.<br>• **Sung Stage Directions**: Non-structural bracketed descriptions (`[Crisp soft shakers...]`, `[Log drum drop...]`) passed into `ACE-Step` lyrics and sung out loud by `VoiceBpeTokenizer`.<br>• **Bantu-to-Chinese Vocal Misclassification**: `LangSegment` (`py3langid`) misclassifying Bantu words (`ve`, `zu`, `xh`, `st`, `tn`, `ts`) as Mandarin Chinese (`zh`) unless normalized to Latin `[en]` phonetic tokenization in `model_utils.py`.<br>• **White-Noise Mastering Distortion**: Destructive Demucs 4-stem re-summing + `-9.5 LUFS` brickwall boost applied to `master.mp3` instead of preserving clean ACE-Step stereo output with gentle `-14 LUFS` mastering (`master_clean_stereo_gentle`).<br>• **MIME Poisoning**: Serving `RIFF/WAVE` bytes as `.mp3`, `BM` BMP bytes as `.png`, or header-only 512-byte `.mp4` files. |

---

## 2. Severity Classification Standard (`P0` – `P3`)

Use this standardized severity taxonomy in every Vhunambi audit report:

| Severity | Label | Definition & Qualification Criteria |
| :---: | :--- | :--- |
| **`P0`** | **Critical / Release Blocker** | • Native Android/iOS or Dart isolate crash, uncaught exception, or `workerd` HTTP 500.<br>• Broken end-to-end user journey (e.g., generation never starts, audio cannot play, checkout loses funds).<br>• Severe audio/visual synthesis corruption (e.g., white-noise clipping roar, sung stage directions, wrong language vocal model, MIME poisoning).<br>• Cross-account data leak or database schema/ledger sign corruption. |
| **`P1`** | **High / Major Functional Defect** | • Silent degradation to fake/mock data (`FakeLyricsGenerationService`, volatile RAM maps, hardcoded `0` balances) when live cloud/user inputs should be used.<br>• Post-`await` `StateNotifier` / `BuildContext` lifecycle mutation without `mounted` check.<br>• Cross-tab navigation desync (e.g., MiniPlayer appearing over Studio tab) or unguarded `NetworkImage` codec crash risk.<br>• High-visibility "SnackBar Dead-End" on a core user action. |
| **`P2`** | **Medium / Standards & Ergonomics Drift** | • `STD-UIUX-001` iconography or typography violation (stock Material `Icons.*`, raw Unicode emojis, non-token colors).<br>• Touch target below $44 \times 44\text{dp}$ or compact mobile (`360dp`) row crowding.<br>• Missing structured warning telemetry on fallback paths or minor timeout gaps. |
| **`P3`** | **Low / Dead Code & Polish** | • Orphaned/unmounted widget files in `lib/`.<br>• Redundant comments, minor spacing asymmetries, or non-blocking code duplication. |

---

## 3. Fast PowerShell Static Scan Recipes (Scoped & Non-Hanging)

Always scope PowerShell searches strictly to source directories (`apps/vhunambi_client/lib`, `apps/vhunambi_api/src`, `tools/zr-studio-gpu`) so commands never scan `build/`, `.dart_tool/`, or `node_modules/`:

### 3.1 Scan for Stock Material Icons (`STD-UIUX-001`)
```powershell
Get-ChildItem -Recurse -Path "apps/vhunambi_client/lib" -Filter "*.dart" |
  Select-String "\bIcons\.[a-zA-Z0-9_]+" |
  Select-Object Filename, LineNumber, Line
```

### 3.2 Scan for SnackBar Dead-Ends & Mock Actions
```powershell
Get-ChildItem -Recurse -Path "apps/vhunambi_client/lib/features" -Filter "*.dart" |
  Select-String "showSnackBar|isSimulated|simulateDownloads|mock-storage" |
  Select-Object Filename, LineNumber, Line
```

### 3.3 Scan for Direct Unsafe JSON Casts in Flutter Client
```powershell
Get-ChildItem -Recurse -Path "apps/vhunambi_client/lib" -Filter "*.dart" |
  Select-String "as Map<String,\s*dynamic>|as List<dynamic>" |
  Select-Object Filename, LineNumber, Line
```

### 3.4 Scan for Unguarded `vhunambiDb.` Calls in Cloudflare Worker Routes
```powershell
Get-ChildItem -Recurse -Path "apps/vhunambi_api/src/routes", "apps/vhunambi_api/src/modules" -Filter "*.ts" |
  Select-String "vhunambiDb\.|isNodeSqliteAvailable" |
  Select-Object Filename, LineNumber, Line
```

### 3.5 Physical Device Crash & Audio Focus Forensics (ADB)
```powershell
$adb = "C:\Users\Ndugelo\AppData\Local\Android\Sdk\platform-tools\adb.exe"
& $adb devices -l
& $adb logcat -b crash -d -t 100
& $adb shell dumpsys media.player
```
