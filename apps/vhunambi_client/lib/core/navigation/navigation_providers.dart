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


