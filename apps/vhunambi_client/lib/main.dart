import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/responsive_utils.dart';
import 'features/explore/presentation/views/explore_view.dart';
import 'features/home/presentation/views/home_dashboard_view.dart';
import 'features/library/presentation/providers/library_providers.dart';
import 'features/library/presentation/views/library_view.dart';
import 'features/marketplace/presentation/views/marketplace_view.dart';
import 'features/onboarding/presentation/views/splash_view.dart';
import 'features/player/presentation/providers/player_provider.dart';
import 'features/player/presentation/widgets/mobile_mini_player.dart';
import 'features/player/presentation/widgets/desktop_transport_bar.dart';
import 'features/player/presentation/widgets/expanded_cockpit_modal.dart';
import 'features/studio/presentation/views/studio_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: VhunambiApp(),
    ),
  );
}

class VhunambiApp extends StatelessWidget {
  final Widget? initialHome;

  const VhunambiApp({super.key, this.initialHome});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VHUNAMBI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
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

  /// Routes the vault `✨ Create` action into the Studio cockpit (tab index 2).
  void _openStudio() => setState(() => _currentIndex = 2);

  /// Routes the dashboard into the Marketplace tab (index 4).
  void _openMarket() => setState(() => _currentIndex = 4);

  /// Routes the marketplace seller callout into the Library vault (index 3).
  void _openLibrary() => setState(() => _currentIndex = 3);

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

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final hasActiveTrack = ref.watch(
      playerStateProvider.select((s) => s.hasActiveTrack),
    );

    // Jukebox play-count tracking: whenever the persistent player advances to a
    // new active track, register a play against the matching vault record.
    // Covers playTrack / skipNext / skipPrevious / playPlaylist uniformly.
    ref.listen<String?>(
      playerStateProvider.select((s) => s.currentTrack?.id),
      (previousId, currentId) {
        if (currentId == null || currentId == previousId) return;
        ref.read(libraryTracksProvider.notifier).incrementPlayCount(currentId);
        ref.read(recentlyPlayedIdsProvider.notifier).register(currentId);
      },
    );

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _buildPages(),
          ),

          // Persistent Audio Transport Bar
          if (hasActiveTrack)
            Positioned(
              left: 0,
              right: 0,
              bottom: isDesktop ? 0 : 0,
              child: isDesktop
                  ? DesktopTransportBar(
                      onExpand: () => ExpandedCockpitModal.show(context),
                    )
                  : MobileMiniPlayer(
                      onExpand: () => ExpandedCockpitModal.show(context),
                    ),
            ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home_filled),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.explore_outlined),
                  activeIcon: Icon(Icons.explore_rounded),
                  label: 'Explore',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.auto_awesome),
                  activeIcon: Icon(Icons.auto_awesome),
                  label: 'Create',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.library_music_outlined),
                  activeIcon: Icon(Icons.library_music_rounded),
                  label: 'Library',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.storefront_outlined),
                  activeIcon: Icon(Icons.storefront_rounded),
                  label: 'Market',
                ),
              ],
            ),
    );
  }
}
