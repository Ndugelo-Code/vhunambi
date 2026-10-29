# Privacy Data Flow — Vhunambi

**Document Type:** Privacy Audit & Data Flow Documentation  
**Feature:** Onboarding Experience Modernization (VH-013), Phase 26 Vocal Identity Cloning & Phase 27 Melody Sketchpad  
**Status:** Approved  
**Last Updated:** 2026-10-29  
**Audit By:** Engineering Team

---

## 1. Executive Summary

This document audits all data flows in the Vhunambi Creator DNA and generation pipeline. It replaces the previously displayed misleading claim *"100% on-device sovereignty (zero cloud tracking)"* with an accurate, audited privacy statement.

**Key Finding:** DNA profiles and user preferences are stored locally in Hive storage on-device. However, audio generation prompts are transmitted to private, encrypted GPU clusters for synthesis. Analytics events are batched and sent to the backend. Therefore, the claim *"zero cloud tracking"* is inaccurate and has been removed.

---

## 2. Data Classification

| Data Type | Storage Location | Transmitted to Cloud? | Encrypted? | Notes |
|-----------|-----------------|----------------------|------------|-------|
| Creator DNA Profile | Hive (local) | No | Yes (at rest) | Seeded at onboarding, updated via behavior events |
| Creator Voice Clone Profile | Hive (`vhunambi_voice_profiles_box`) | Optional (per-job conditioning) | Yes (TLS 1.3 + AES-256) | 256-D speaker timbre vector & phoneme cadence ratios stored locally; user can delete anytime |
| Voice Calibration Audio (20s 3-Line Script) | Memory / Encrypted R2 Ephemeral | **Yes** (when cloud SVC enabled) | Yes (TLS 1.3 + AES-256) | Used strictly for F0-locked Seed-VC inference on user's own track; zero foundation model training |
| Saved Melody Sketchpad Patterns | Hive (`vhunambi_melody_sketches_box`) | Optional (per-job conditioning) | Yes (at rest) | `< 2 KB` JSON note blueprint stored on-device; never transmitted unless explicitly attached to a song |
| Ephemeral Melody Reference WAV | Memory (RAM `Uint8List`) | **Yes** (when attached as reference) | Yes (TLS 1.3) | Synthesized on-demand in `< 20 ms` in RAM; transmitted over TLS 1.3 only when conditioning a generation job |
| Selected Genres | Hive (local) | No | Yes (at rest) | Part of DNA profile |
| Selected Languages | Hive (local) | No | Yes (at rest) | Part of DNA profile |
| Creative Role | Hive (local) | No | Yes (at rest) | Part of DNA profile |
| Tempo Preference | Hive (local) | No | Yes (at rest) | Part of DNA profile |
| Vocal Energy Preference | Hive (local) | No | Yes (at rest) | Part of DNA profile |
| Selected Moods | Hive (local) | No | Yes (at rest) | Part of DNA profile |
| Generation Prompts | Memory (ephemeral) | **Yes** | Yes (TLS 1.3) | Sent to private GPU clusters for synthesis |
| Generated Audio | Hive + Cloud Storage | **Yes** | Yes (TLS 1.3 + AES-256) | Stored locally, backed up to encrypted cloud |
| Analytics Events | Memory → Backend | **Yes** | Yes (TLS 1.3) | Batches of 10, flushed every 1s. No sensitive data. |
| User Identity (UserID) | Hive (local) | No | Yes (at rest) | Pseudonymous identifier |

---

## 3. Client vs. Server Data Flows

### 3.1 On-Device Data (Never Transmitted Without Explicit Synthesis Action)

The following data remains on the user's device in local Hive storage:

- **Creator DNA Profile** — Complete personalization profile including creative role, genre weights, language weights, mood weights, tempo preference, vocal energy preference
- **Creator Voice Clone Profiles (`vhunambi_voice_profiles_box`)** — Saved zero-shot voice clone metadata, WPM cadence, and phonetic calibration embeddings; creators can delete any cloned voice profile with a single tap
- **Saved Melody Sketchpad Patterns (`vhunambi_melody_sketches_box`)** — Compact (`< 2 KB`) scale-locked 16-step melody, chord, and log-drum JSON blueprints saved in the local Melody Vault; synthesized to 16-bit PCM WAV ephemerally in RAM (`< 20 ms`) without cluttering device storage with `.wav` files
- **Onboarding State** — User's onboarding progress, completion flag, selected preferences
- **User ID** — Pseudonymous identifier for local profile correlation

### 3.2 Data Transmitted to Cloud Services

The following data is transmitted to backend services:

1. **Generation Prompts & Vocal Conditioning (`svc_config`)** — Text prompts and optional vocal timbre conditioning (`selectedVoiceId` or `clonedVoiceProfileId`) for AI music generation are sent to private, encrypted GPU clusters for synthesis. Zero model training is performed on unreleased prompts or creator voice clones.
2. **Generated Audio & Mastered Stems** — Final audio output and 4 isolated stems (`vocals.wav`, `drums.wav`, `bass.wav`, `melodic.wav`) are stored in encrypted cloud storage for backup and cross-device access.
3. **Analytics Events** — Aggregated, non-sensitive events (onboarding completion, genre selection, feature usage) are batched and sent to the analytics backend. No lyrics, prompts, raw voice recordings, or user identity data is included.

---

## 4. Analytics Event Reference

| Event Name | Purpose | Sensitive Data? |
|------------|---------|-----------------|
| `onboarding_step_completed` | Track onboarding progress | No |
| `onboarding_step_skipped` | Track skip behavior | No |
| `onboarding_completed` | Track completion time | No |
| `onboarding_abandoned` | Track abandonment point | No |
| `genre_selected` | Track genre preferences | No |
| `generation_started` | Track generation usage | No (genre + BPM only) |
| `privacy_claim_displayed` | Privacy compliance verification | No |
| `player_form_changed` | Track UI state changes | No |
| `player_mode_changed` | Track player mode changes | No |
| `player_gesture` | Track player gestures | No |

---

## 5. Privacy Claim Wording

### Previous Claim (REMOVED - Misleading)

> *"100% on-device sovereignty (zero cloud tracking)"*

**Reason for removal:** Audio generation prompts are transmitted to cloud GPU clusters for synthesis, and analytics events are sent to the backend. The claim of "zero cloud tracking" is factually inaccurate.

### Current Claim (ACCURATE - Audited)

> *"Your creator profile, DNA preferences, and session history remain sovereign on your device. Audio generation is processed via private, encrypted GPU clusters with zero model training on your unreleased prompts."*

**Audit justification:** This claim accurately reflects that:
- DNA profiles, preferences, and session history stay on-device (Hive storage)
- Audio generation uses cloud GPU clusters (private, encrypted)
- No model training is performed on unreleased prompts or creator voice clones

---

## 6. Compliance & Review

- **REQ-VH013-01:** Data flow audit completed ✅
- **REQ-VH013-02:** Misleading "zero cloud tracking" claim removed ✅
- **REQ-VH013-03:** Accurate replacement claim deployed ✅
- **REQ-VH013-04:** N/A (analytics/generation prompts are transmitted, but DNA profile is local)
- **REQ-VH013-05:** This document serves as the audit record ✅
- **REQ-VH013-06:** Pending product/legal team review
- **REQ-VH013-07:** Privacy claim displayed on DNA activation screen with analytics tracking ✅
- **REQ-VH013-08:** `privacy_claim_displayed` analytics event logged ✅
- **REQ-VOC-14:** Phase 26 Voice Clone & Calibration Audio privacy classification documented ✅
- **REQ-SKP-14:** Phase 27 Local Melody Vault (`vhunambi_melody_sketches_box`) & Ephemeral RAM WAV synthesis privacy classification documented ✅

---

## 7. Storage Locations

| Component | Technology | Location | Encryption |
|-----------|-----------|----------|------------|
| Local Database | Hive | Device internal storage | AES-256 (at rest) |
| Cloud Storage | Encrypted bucket | Regional cloud provider | TLS 1.3 + AES-256 |
| Analytics Backend | Custom API | Regional cloud provider | TLS 1.3 |
| GPU Inference | Private cluster | Isolated VPC | TLS 1.3 |

---

**Document End**
