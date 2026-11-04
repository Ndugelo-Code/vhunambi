# Phase 42: Cockpit Hardware Player Studio Bridge & Multitrack Stems Transport
## Architectural Blueprint

### Executive Summary
Phase 42 bridges the gap between active listening in the **Expanded Cockpit Hardware Player** (`expanded_cockpit_modal.dart`) and generative music creation in the **Studio Cockpit** (`studio_view.dart`), directly eliminating the dead-end stub in `FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md` (§5.9):

1. **Seamless Player-to-Studio Navigation Bridge (`appNavigationTabProvider`)**:
   - Tapping **`[ 🎛️ Remix in Studio ]`** (`Key('cockpit_remix_in_studio_btn')`) in the expanded player cockpit now pre-loads the track title, genre, language, and multitrack stems into `studioFormProvider`, automatically pops the cockpit modal, and switches the root tab to **Studio Cockpit (Tab 2)** via `appNavigationTabProvider`.
   - Dispatches a real-time system notification in `notificationsProvider`: `'Loaded "${track.title}" stems into Studio Cockpit'`.

2. **On-Deck Hardware Illuminated LED Toggles**:
   - Replaces the disruptive 1.5-second mobile toast SnackBar on "A/B Bypass" with a dedicated illuminated hardware status LED indicator mounted on the cockpit faceplate (`Key('cockpit_dsp_led_indicator')`):
     - Active: Glowing Emerald / Brand Primary LED with `[ 🟢 MASTER DSP: ACTIVE ]`.
     - Bypassed: Muted Amber / Grey LED with `[ ⚪ MASTER DSP: BYPASS (RAW AI) ]`.

3. **Continuous Phase Visualizer State Synchronization**:
   - Synchronizes visualizer meters on the hardware faceplate with audio playback states (`PlaybackStatus.playing`).

