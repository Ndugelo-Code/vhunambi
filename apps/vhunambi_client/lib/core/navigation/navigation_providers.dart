import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global active bottom navigation tab index (REQ-NAV-01 / Phase 37).
///
/// Tab Mapping:
/// - 0: Home Dashboard
/// - 1: Explore Social Feed
/// - 2: Studio Cockpit (Create / AI Remix)
/// - 3: Library / Vault
/// - 4: Beats Marketplace
final appNavigationTabProvider = StateProvider<int>((ref) => 0);

/// Tracks active modal bottom sheets and full-screen dialogs (REQ-P44-MINI-02).
/// When > 0, floating UI components like [MiniPlayerHost] are suppressed to
/// prevent awkward overlap with modal inputs and interactive buttons.
final modalSheetOpenCountProvider = StateProvider<int>((ref) => 0);

/// True while `NowPlayingHomeCard` is mounted in the Main Room tree (`Phase 68`).
/// Combined with `appNavigationTabProvider == 0`, prevents floating [MiniPlayerHost]
/// from duplicating playback controls on Home while preserving standalone tests.
final homeInlineNowPlayingMountedProvider = StateProvider<bool>((ref) => false);

/// Reference-counted tracker for mounted `TrackDetailView` routes that already
/// render an inline `WaveformScrubber` (`Phase 70`, `REQ-P70-MINI-01`).
/// When > 0, `MiniPlayerHost` suppresses itself to avoid duplicate audio bars.
final trackDetailInlinePlayerMountedProvider = StateProvider<int>((ref) => 0);

/// Reference-counted tracker for pushed full-screen routes rendered outside
/// `RootShell`'s 56dp bottom navigation bar (`ArtistProfileView`, etc.)
/// (`Phase 70`, `REQ-P70-MINI-02`).
final pushedFullScreenOverlayCountProvider = StateProvider<int>((ref) => 0);



