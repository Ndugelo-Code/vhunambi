import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/navigation/app_navigator.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/utils/responsive_utils.dart';
import 'core/widgets/vhunambi_bottom_dock_kit.dart';
import 'core/widgets/vhunambi_mobile_bottom_nav.dart';
import 'core/design_system/design_system.dart';
import 'features/explore/presentation/providers/explore_providers.dart';
import 'features/explore/presentation/views/explore_view.dart';
import 'features/home/presentation/views/home_dashboard_view.dart';
import 'features/library/presentation/providers/library_providers.dart';
import 'features/library/presentation/views/library_view.dart';
import 'features/marketplace/presentation/views/marketplace_view.dart';
import 'features/onboarding/presentation/views/splash_view.dart';
import 'features/player/presentation/providers/mini_player_controller.dart';
import 'features/player/presentation/providers/player_provider.dart';
import 'features/player/presentation/widgets/mini_player_host.dart';
import 'features/player/presentation/widgets/desktop_transport_bar.dart';
import 'features/player/presentation/widgets/expanded_cockpit_modal.dart';
import 'features/studio/presentation/views/studio_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences for design system state persistence.
  final prefs = await SharedPreferences.getInstance();

  // Register all genre and mood color tokens with the design system registry,
  // then seal the registry to prevent late or duplicate registrations.
  TokenRegistration.registerAllTokens();
  DesignTokenRegistry.seal();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const VhunambiApp(),
    ),
  );
}

class VhunambiApp extends ConsumerWidget {
  final Widget? initialHome;

  const VhunambiApp({super.key, this.initialHome});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'VHUNAMBI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        // Synchronize dynamic AppColors with active platform/theme brightness
        final platformBrightness = MediaQuery.platformBrightnessOf(context);
        final effectiveBrightness = switch (themeMode) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          ThemeMode.system => platformBrightness,
        };
        AppColors.syncWithBrightness(effectiveBrightness);

        return KeyedSubtree(
          key: ValueKey<Brightness>(effectiveBrightness),
          child: Stack(children: [?child, const MiniPlayerHost()]),
        );
      },
      home: initialHome ?? const SplashView(),
    );
  }
}

class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _currentIndex = 1; // Default to Explore view

  /// Per-session tab navigation history. The last entry is the visible tab;
  /// system back pops this stack before the OS is allowed to exit the shell.
  final List<int> _tabHistory = <int>[1];

  /// Switches the visible tab and records it in the back-history stack so a
  /// system-back gesture unwinds tab jumps (e.g. Home ➔ Studio ➔ back).
  void _switchTab(int index) {
    if (index == _currentIndex) return;
    HapticsService().selectionClick();
    if (index == 1) {
      resetExploreTitleFade(ref);
    }
    // Restore mini-player to Bar form if in Auto mode when switching tabs
    final playerController = ref.read(miniPlayerControllerProvider);
    if (playerController.form == PlayerForm.pill &&
        playerController.mode == PlayerMode.auto) {
      ref.read(miniPlayerControllerProvider.notifier).setForm(PlayerForm.bar);
    }
    setState(() {
      _tabHistory.add(index);
      _currentIndex = index;
    });
  }

  /// Routes the vault `✨ Create` action into the Studio cockpit (tab index 2).
  void _openStudio() => _switchTab(2);

  /// Routes the dashboard into the Marketplace tab (index 4).
  void _openMarket() => _switchTab(4);

  /// Routes the marketplace seller callout into the Library vault (index 3).
  void _openLibrary() => _switchTab(3);

  /// Pops the tab-history stack in response to a system back gesture.
  void _handleSystemBack() {
    if (_tabHistory.length <= 1) return;
    setState(() {
      _tabHistory.removeLast();
      _currentIndex = _tabHistory.last;
    });
  }

  List<Widget> _buildPages() => [
    HomeDashboardView(
      onNavigateToStudio: _openStudio,
      onNavigateToMarket: _openMarket,
      onNavigateToLibrary: _openLibrary,
    ),
    ExploreView(onCreateRequested: _openStudio),
    const StudioView(),
    LibraryView(onCreateRequested: _openStudio),
    MarketplaceView(onNavigateToLibrary: _openLibrary),
  ];

  bool _isTypingInTextField() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null || primaryFocus.context == null) return false;
    return primaryFocus.context!
            .findAncestorWidgetOfExactType<EditableText>() !=
        null;
  }

  void _handleSpaceShortcut() {
    if (_isTypingInTextField()) return;
    ref.read(playerStateProvider.notifier).togglePlayPause();
  }

  void _handleSeekBackwardShortcut() {
    if (_isTypingInTextField()) return;
    final player = ref.read(playerStateProvider);
    if (!player.hasActiveTrack) return;
    final target = player.position - const Duration(seconds: 5);
    ref
        .read(playerStateProvider.notifier)
        .seek(target < Duration.zero ? Duration.zero : target);
  }

  void _handleSeekForwardShortcut() {
    if (_isTypingInTextField()) return;
    final player = ref.read(playerStateProvider);
    if (!player.hasActiveTrack) return;
    final target = player.position + const Duration(seconds: 5);
    final max = player.duration;
    ref.read(playerStateProvider.notifier).seek(target > max ? max : target);
  }

  void _handleSearchShortcut() {
    setState(() => _currentIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final hasActiveTrack = ref.watch(
      playerStateProvider.select((s) => s.hasActiveTrack),
    );

    // Jukebox play-count tracking: whenever the persistent player advances to a
    // new active track, register a play against the matching vault record.
    // Covers playTrack / skipNext / skipPrevious / playPlaylist uniformly.
    ref.listen<String?>(playerStateProvider.select((s) => s.currentTrack?.id), (
      previousId,
      currentId,
    ) {
      if (currentId == null || currentId == previousId) return;
      ref.read(libraryTracksProvider.notifier).incrementPlayCount(currentId);
      ref.read(recentlyPlayedIdsProvider.notifier).register(currentId);
    });

    final shell = Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis != Axis.vertical) return false;
          if (notification is ScrollUpdateNotification) {
            final controller = ref.read(miniPlayerControllerProvider);
            if (controller.mode == PlayerMode.auto) {
              final delta = notification.scrollDelta ?? 0;
              final pixels = notification.metrics.pixels;

              // Downward scroll exploration (pixels > 40 & delta > 1.5): morph to Pill to reveal content
              if (pixels > 40 &&
                  delta > 1.5 &&
                  controller.form == PlayerForm.bar) {
                ref
                    .read(miniPlayerControllerProvider.notifier)
                    .setForm(PlayerForm.pill);
              }
              // Scrolled back to the top (pixels <= 10): restore docked Bar
              else if (pixels <= 10 && controller.form == PlayerForm.pill) {
                ref
                    .read(miniPlayerControllerProvider.notifier)
                    .setForm(PlayerForm.bar);
              }
            }
          }
          return false;
        },
        child: Stack(
          children: [
            IndexedStack(index: _currentIndex, children: _buildPages()),

            // Persistent Audio Transport Bar (Desktop only; Mobile is hosted by global MiniPlayerHost)
            if (hasActiveTrack && isDesktop)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DesktopTransportBar(
                  onExpand: () => ExpandedCockpitModal.show(context),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: isDesktop
          ? null
          : VhunambiBottomDockSurface(
              child: VhunambiMobileBottomNav(
                currentIndex: _currentIndex,
                onTap: _switchTab,
              ),
            ),
    );

    return PopScope(
      // Let the OS exit the app only from the root of the tab history;
      // otherwise intercept the back gesture to unwind tab jumps first.
      canPop: _tabHistory.length <= 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleSystemBack();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): _handleSpaceShortcut,
          const SingleActivator(LogicalKeyboardKey.keyK, control: true):
              _handleSearchShortcut,
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
              _handleSearchShortcut,
          const SingleActivator(LogicalKeyboardKey.arrowLeft):
              _handleSeekBackwardShortcut,
          const SingleActivator(LogicalKeyboardKey.arrowRight):
              _handleSeekForwardShortcut,
        },
        child: Focus(autofocus: true, child: shell),
      ),
    );
  }
}
