import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/widgets/vhunambi_ambient_mesh_backdrop.dart';
import '../../../../core/widgets/vhunambi_bottom_dock_kit.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../../../core/widgets/vhunambi_top_bar_kit.dart';
import '../../../beats/presentation/views/beats_vault_view.dart';
import '../../../collections/presentation/views/collections_vault_view.dart';
import '../../../marketplace/presentation/providers/marketplace_providers.dart';
import '../../../playlists/presentation/views/playlists_vault_view.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../domain/models/library_models.dart';
import '../providers/library_providers.dart';
import '../widgets/library_app_bar.dart';
import '../widgets/library_category_rail.dart';
import '../widgets/library_cover_art.dart';
import '../widgets/library_empty_state.dart';
import '../widgets/library_track_grid_card.dart';
import '../widgets/library_track_tile.dart';

/// Library & User Asset Vault (`/library`) — mounted at tab index 3 of `RootShell`.
class LibraryView extends ConsumerStatefulWidget {
  final VoidCallback? onCreateRequested;

  const LibraryView({super.key, this.onCreateRequested});

  @override
  ConsumerState<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends ConsumerState<LibraryView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = ref.read(authSessionProvider);
      if (session.isAuthenticated) {
        unawaited(ref.read(libraryTracksProvider.notifier).syncWithCloud());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final category = ref.watch(libraryCategoryProvider);
    final viewMode = ref.watch(libraryViewModeProvider);
    final searchQuery = ref.watch(librarySearchQueryProvider);
    final baseTracks = ref.watch(filteredLibraryTracksProvider);
    final activeCreatorId = ref.watch(currentCreatorIdProvider);
    final syncFilter = ref.watch(librarySyncFilterProvider);

    // Merge cloud buyer beat licenses (`EP-P72-BUYER-LICENSES-HTTP`) into Licensing tab
    final tracks = category == LibraryCategory.licensing
        ? _mergeLicensingTracks(
            baseTracks: baseTracks,
            remoteCerts:
                ref.watch(buyerLicensesFamilyProvider(activeCreatorId)).valueOrNull ??
                const [],
            searchQuery: searchQuery,
            syncFilter: syncFilter,
          )
        : baseTracks;

    final showSearchStrip = tracks.isNotEmpty || searchQuery.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvasOf(context),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          VhunambiTopBarMetrics.totalHeight(context),
        ),
        child: LibraryAppBar(onCreateRequested: widget.onCreateRequested),
      ),
      body: VhunambiAmbientMeshBackdrop(
        child: Column(
          children: [
            const LibraryCategoryRail(),
            Expanded(
              child: category == LibraryCategory.playlists
                  ? PlaylistsVaultView(
                      onCreateRequested: widget.onCreateRequested,
                    )
                  : category == LibraryCategory.collections
                  ? CollectionsVaultView(
                      onCreateRequested: widget.onCreateRequested,
                    )
                  : category == LibraryCategory.beats
                  ? BeatsVaultView(onCreateRequested: widget.onCreateRequested)
                  : Column(
                      children: [
                        if (showSearchStrip)
                          _VaultSearchStrip(
                            category: category,
                            viewMode: viewMode,
                            resultCount: tracks.length,
                          ),
                        if (category == LibraryCategory.songs &&
                            searchQuery.trim().isEmpty)
                          const _RecentlyPlayedShelf(),
                        Expanded(
                          child: RefreshIndicator(
                            color: AppColors.brandPrimary,
                            onRefresh: () => ref
                                .read(libraryTracksProvider.notifier)
                                .syncWithCloud(),
                            child: tracks.isEmpty
                                ? LayoutBuilder(
                                    builder: (context, constraints) =>
                                        SingleChildScrollView(
                                          physics:
                                              const AlwaysScrollableScrollPhysics(),
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              minHeight: constraints.maxHeight,
                                            ),
                                            child: LibraryEmptyState(
                                              category: category,
                                              searchQuery: searchQuery,
                                              onCreateRequested:
                                                  widget.onCreateRequested,
                                            ),
                                          ),
                                        ),
                                  )
                                : viewMode == LibraryViewMode.grid
                                ? _VaultGrid(tracks: tracks)
                                : _VaultList(
                                    tracks: tracks,
                                    isMobile: isMobile,
                                  ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<LibraryTrack> _mergeLicensingTracks({
    required List<LibraryTrack> baseTracks,
    required List<dynamic> remoteCerts,
    required String searchQuery,
    required LibrarySyncFilter syncFilter,
  }) {
    if (remoteCerts.isEmpty || syncFilter == LibrarySyncFilter.offlineOnly) {
      return baseTracks;
    }
    final seenCerts = {
      for (final t in baseTracks)
        if (t.licenseCertificateIdOverride != null &&
            t.licenseCertificateIdOverride!.isNotEmpty)
          t.licenseCertificateIdOverride!,
    };
    final q = searchQuery.trim().toLowerCase();
    final extra = <LibraryTrack>[];
    for (final cert in remoteCerts) {
      final certId = cert.certificateId as String;
      if (certId.isEmpty || seenCerts.contains(certId)) continue;
      final candidate = LibraryTrack(
        id: (cert.vaultTrackId as String).isNotEmpty
            ? cert.vaultTrackId as String
            : 'market_${cert.beatId}',
        title: (cert.beatTitle as String).isNotEmpty
            ? cert.beatTitle as String
            : 'Licensed Beat',
        creatorName: cert.producerName as String,
        creatorId: cert.producerId as String,
        creatorHandle: cert.producerHandle as String,
        genre: cert.genre as String,
        language: 'Instrumental',
        bpm: cert.bpm as int,
        durationSeconds: 180,
        remoteAudioUrl: cert.masterAudioFilePath as String,
        createdAt:
            DateTime.tryParse(cert.issuedAtIso8601 as String) ?? DateTime.now(),
        licenseType: cert.tier.displayName as String,
        isInstrumental: true,
        licenseCertificateIdOverride: certId,
        licenseHash: cert.licenseHash as String,
        licenseTierId: cert.tier.wireSlug as String,
      );
      if (q.isEmpty ||
          candidate.title.toLowerCase().contains(q) ||
          candidate.creatorName.toLowerCase().contains(q) ||
          candidate.genre.toLowerCase().contains(q)) {
        extra.add(candidate);
      }
    }
    if (extra.isEmpty) return baseTracks;
    return List<LibraryTrack>.unmodifiable([...baseTracks, ...extra]);
  }
}

class _CloudSyncStatusBadge extends ConsumerWidget {
  const _CloudSyncStatusBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(libraryCloudSyncStatusProvider);
    final (IconData icon, Color color, String label) = switch (status) {
      LibraryCloudSyncStatus.syncing => (
        PhosphorIconsRegular.arrowsClockwise,
        AppColors.brandPrimary,
        'Syncing',
      ),
      LibraryCloudSyncStatus.synced => (
        PhosphorIconsRegular.cloudCheck,
        AppColors.success,
        'Cloud Synced',
      ),
      LibraryCloudSyncStatus.offline || LibraryCloudSyncStatus.error => (
        PhosphorIconsRegular.cloudSlash,
        AppColors.textSecondaryOf(context),
        'Local Vault',
      ),
      LibraryCloudSyncStatus.idle => (
        PhosphorIconsRegular.cloud,
        AppColors.textSecondaryOf(context),
        'Cloud Ready',
      ),
    };

    return Tooltip(
      key: const Key('library_cloud_sync_badge'),
      message: label,
      child: VhunambiGlassSurface(
        variant: VhunambiGlassVariant.pill,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.badge.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recently Played horizontal shelf (Mission 11).
class _RecentlyPlayedShelf extends ConsumerWidget {
  const _RecentlyPlayedShelf();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentlyPlayedTracksProvider);
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Text(
            'Recently Played',
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
        ),
        SizedBox(
          height: 56,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final track = recent[index];
              return SizedBox(
                width: 44,
                height: 44,
                child: Tooltip(
                  message: track.title,
                  child: InkWell(
                    borderRadius: AppRadius.thumbBorder,
                    onTap: () => playLibraryTrack(ref, track),
                    child: LibraryCoverArt(track: track, size: 44),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}

class _VaultList extends ConsumerWidget {
  final List<LibraryTrack> tracks;
  final bool isMobile;

  const _VaultList({required this.tracks, required this.isMobile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = VhunambiBottomDockMetrics.scrollInset(
      hasActiveTrack:
          ref.watch(playerStateProvider.select((s) => s.hasActiveTrack)),
    );
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xxs,
        AppSpacing.md,
        bottomInset,
      ),
      itemCount: tracks.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (_, index) => LibraryTrackTile(
        track: tracks[index],
        showGenreBadge: !isMobile,
      ),
    );
  }
}

class _VaultGrid extends ConsumerWidget {
  final List<LibraryTrack> tracks;

  const _VaultGrid({required this.tracks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = VhunambiBottomDockMetrics.scrollInset(
      hasActiveTrack:
          ref.watch(playerStateProvider.select((s) => s.hasActiveTrack)),
    );
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xxs,
        AppSpacing.md,
        bottomInset,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveUtils.gridColumns(context),
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1,
      ),
      itemCount: tracks.length,
      itemBuilder: (_, index) => LibraryTrackGridCard(track: tracks[index]),
    );
  }
}

/// Real-time clearable glass search strip, visible mobile Cached Only pill, and view toggle.
class _VaultSearchStrip extends ConsumerStatefulWidget {
  final LibraryCategory category;
  final LibraryViewMode viewMode;
  final int resultCount;

  const _VaultSearchStrip({
    required this.category,
    required this.viewMode,
    required this.resultCount,
  });

  @override
  ConsumerState<_VaultSearchStrip> createState() => _VaultSearchStripState();
}

class _VaultSearchStripState extends ConsumerState<_VaultSearchStrip> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(librarySearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _hint => switch (widget.category) {
    LibraryCategory.songs => 'Search my songs...',
    LibraryCategory.playlists => 'Search my playlists...',
    LibraryCategory.collections => 'Search my collections...',
    LibraryCategory.beats => 'Search my beats...',
    LibraryCategory.licensing => 'Search my licenses...',
    LibraryCategory.trash => 'Search trash...',
  };

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final queryText = ref.watch(librarySearchQueryProvider);

    ref.listen(librarySearchQueryProvider, (previous, next) {
      if (_controller.text != next) {
        _controller.text = next;
      }
    });

    final searchField = VhunambiGlassSurface(
      variant: VhunambiGlassVariant.pill,
      borderRadius: AppRadius.inputBorder,
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          PhosphorIcon(
            PhosphorIconsRegular.magnifyingGlass,
            size: 18,
            color: AppColors.textSecondaryOf(context),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Center(
              child: TextField(
                controller: _controller,
                onChanged: (value) =>
                    ref.read(librarySearchQueryProvider.notifier).state = value,
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                textInputAction: TextInputAction.search,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimaryOf(context),
                ),
                cursorColor: AppColors.brandPrimary,
                decoration: InputDecoration(
                  hintText: _hint,
                  hintStyle: AppTypography.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          if (queryText.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: IconButton(
                key: const Key('vault_search_clear_btn'),
                padding: EdgeInsets.zero,
                tooltip: 'Reset search input',
                icon: PhosphorIcon(
                  PhosphorIconsRegular.x,
                  size: 15,
                  color: AppColors.textSecondaryOf(context),
                ),
                onPressed: () {
                  _controller.clear();
                  ref.read(librarySearchQueryProvider.notifier).state = '';
                },
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xxs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: searchField),
              if (isDesktop) ...[
                const SizedBox(width: AppSpacing.xs),
                const _CachedOnlyFilterPill(),
                const SizedBox(width: AppSpacing.xs),
                const _SyncFilterButton(),
              ],
              const SizedBox(width: AppSpacing.xs),
              _ViewModeToggle(viewMode: widget.viewMode),
              if (isDesktop) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${widget.resultCount} ${widget.resultCount == 1 ? 'asset' : 'assets'}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const _CloudSyncStatusBadge(),
              ],
            ],
          ),
          if (!isDesktop) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        _CachedOnlyFilterPill(),
                        SizedBox(width: AppSpacing.xs),
                        _SyncFilterButton(),
                        SizedBox(width: AppSpacing.xs),
                        _CloudSyncStatusBadge(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${widget.resultCount} ${widget.resultCount == 1 ? 'asset' : 'assets'}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CachedOnlyFilterPill extends ConsumerWidget {
  const _CachedOnlyFilterPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(librarySyncFilterProvider);
    final isCachedOnly = activeFilter == LibrarySyncFilter.offlineOnly;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Center(
        child: InkWell(
          key: const Key('vault_filter_cached_only'),
          borderRadius: AppRadius.inputBorder,
          onTap: () {
            ref.read(librarySyncFilterProvider.notifier).state = isCachedOnly
                ? LibrarySyncFilter.any
                : LibrarySyncFilter.offlineOnly;
          },
          child: VhunambiGlassSurface(
            variant: VhunambiGlassVariant.pill,
            borderRadius: AppRadius.inputBorder,
            tintAccent: isCachedOnly ? AppColors.brandPrimary : null,
            borderColorOverride:
                isCachedOnly ? AppColors.brandPrimary : null,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(
                  PhosphorIconsRegular.checkCircle,
                  size: 15,
                  color: isCachedOnly
                      ? AppColors.brandPrimary
                      : AppColors.textSecondaryOf(context),
                ),
                const SizedBox(width: AppSpacing.xxs + 2),
                Text(
                  'Cached Only',
                  style: AppTypography.caption.copyWith(
                    color: isCachedOnly
                        ? AppColors.brandPrimary
                        : AppColors.textPrimaryOf(context),
                    fontWeight:
                        isCachedOnly ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncFilterButton extends ConsumerWidget {
  const _SyncFilterButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(librarySyncFilterProvider);
    final isFiltered = activeFilter != LibrarySyncFilter.any;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Center(
        child: PopupMenuButton<LibrarySyncFilter>(
          tooltip: 'Filter assets',
          color: AppColors.surfaceModalOf(context),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.inputBorder,
            side: BorderSide(color: AppColors.borderSubtleOf(context)),
          ),
          onSelected: (filter) =>
              ref.read(librarySyncFilterProvider.notifier).state = filter,
          itemBuilder: (_) => [
            for (final filter in LibrarySyncFilter.values)
              PopupMenuItem<LibrarySyncFilter>(
                value: filter,
                height: 40,
                child: Row(
                  children: [
                    PhosphorIcon(
                      _syncFilterIcon(filter),
                      size: 16,
                      color: filter == activeFilter
                          ? AppColors.brandPrimary
                          : AppColors.textSecondaryOf(context),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        _syncFilterLabel(filter),
                        style: AppTypography.bodySmall.copyWith(
                          color: filter == activeFilter
                              ? AppColors.brandPrimary
                              : AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (filter == activeFilter)
                      const PhosphorIcon(
                        PhosphorIconsRegular.check,
                        size: 14,
                        color: AppColors.brandPrimary,
                      ),
                  ],
                ),
              ),
          ],
          child: VhunambiGlassSurface(
            variant: VhunambiGlassVariant.pill,
            borderRadius: AppRadius.inputBorder,
            borderColorOverride: isFiltered ? AppColors.brandPrimary : null,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(
                  PhosphorIconsRegular.slidersHorizontal,
                  size: 15,
                  color: isFiltered
                      ? AppColors.brandPrimary
                      : AppColors.textSecondaryOf(context),
                ),
                const SizedBox(width: AppSpacing.xxs + 2),
                Text(
                  isFiltered ? _syncFilterLabel(activeFilter) : 'Filter',
                  style: AppTypography.caption.copyWith(
                    color: isFiltered
                        ? AppColors.brandPrimary
                        : AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewModeToggle extends ConsumerWidget {
  final LibraryViewMode viewMode;

  const _ViewModeToggle({required this.viewMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VhunambiGlassSurface(
      variant: VhunambiGlassVariant.pill,
      borderRadius: AppRadius.inputBorder,
      height: 44,
      child: Row(
        children: [
          _ViewModeButton(
            icon: PhosphorIconsRegular.squaresFour,
            tooltip: 'Grid view',
            isActive: viewMode == LibraryViewMode.grid,
            onTap: () => ref.read(libraryViewModeProvider.notifier).state =
                LibraryViewMode.grid,
          ),
          _ViewModeButton(
            icon: PhosphorIconsRegular.listBullets,
            tooltip: 'List view',
            isActive: viewMode == LibraryViewMode.list,
            onTap: () => ref.read(libraryViewModeProvider.notifier).state =
                LibraryViewMode.list,
          ),
        ],
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _ViewModeButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.thumbBorder,
        child: Container(
          width: 44,
          height: 44,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isActive ? AppColors.brandPrimary : Colors.transparent,
            borderRadius: AppRadius.thumbBorder,
          ),
          child: Center(
            child: PhosphorIcon(
              icon,
              size: 17,
              color: isActive
                  ? AppColors.brandContrast
                  : AppColors.textSecondaryOf(context),
            ),
          ),
        ),
      ),
    );
  }
}

String _syncFilterLabel(LibrarySyncFilter filter) => switch (filter) {
  LibrarySyncFilter.any => 'All tracks',
  LibrarySyncFilter.offlineOnly => 'Offline only',
  LibrarySyncFilter.cloudOnly => 'Cloud only',
};

IconData _syncFilterIcon(LibrarySyncFilter filter) => switch (filter) {
  LibrarySyncFilter.any => PhosphorIconsRegular.disc,
  LibrarySyncFilter.offlineOnly => PhosphorIconsRegular.checkCircle,
  LibrarySyncFilter.cloudOnly => PhosphorIconsRegular.cloud,
};
