# vhunambi_client

Production Flutter cross-platform client for **VHUNAMBI** (`apps/vhunambi_client`), targeting Android, iOS, Windows, macOS, and Web.

## Build & Run Commands

### Cloud-Wired Release APK (Android ARM64)
Always pass `API_BASE_URL` and `MEDIA_BASE_URL` at compile time so physical devices connect to Cloudflare Workers and R2 rather than `10.0.2.2:3000`:

```powershell
cd apps/vhunambi_client

flutter build apk --release --target-platform android-arm64 `
  --dart-define=API_BASE_URL=https://vhunambi-api.ndugelosigwadi.workers.dev `
  --dart-define=MEDIA_BASE_URL=https://pub-d22409017abb4dd999327a092c5f06d3.r2.dev

# Install on connected Android device
adb -s EPHUT20917014649 install -r build/app/outputs/flutter-apk/app-release.apk
```

### Verification Gates
```powershell
flutter analyze
flutter test --timeout=60s
```

## Current Runtime Standings (2026-11-12)
- **Cloud Origin & Auth:** `SovereignApiClient` and all HTTP repositories resolve from `AppConstants.resolveApiRootUrl()` / `resolveMediaBaseUrl()`. Supabase GoTrue `ES256` JWTs are stored in AES-256 encrypted Tier-0 box `vhunambi_tokens`.
- **On-Device Persistence:** `SovereignHiveBootstrapService` opens 26 Sovereign Hive boxes on boot (`lib/main.dart`).
- **Audio Hardware Notes:**
  - **Sketchpad / Vocal Previews** (`RealSketchpadAudioPlayerService`) and **4-Stem Pocket DAW** (`JustAudioMultiStemEngine`) drive `just_audio` speaker playback.
  - **Global MiniPlayer (`audioHandlerProvider`):** Currently defaults to headless `TestVhunambiAudioHandler` because `bootstrapPlatformAudioHandler` is not overridden inside `ProviderScope` in `lib/main.dart`.

See [`../../README.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/README.md) and [`../../docs/AGENT_HANDOFF_BIBLE.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/AGENT_HANDOFF_BIBLE.md) for full architecture and roadmap documentation.
