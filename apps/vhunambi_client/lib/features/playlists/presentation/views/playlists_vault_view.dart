import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/media/vhunambi_media_upload_service.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/utils/responsive_utils.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_bottom_dock_kit.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/library/presentation/widgets/library_empty_state.dart';
import 'package:vhunambi_client/features/playlists/domain/models/playlist_entity.dart';
import 'package:vhunambi_client/features/playlists/presentation/providers/playlists_provider.dart';
import 'package:vhunambi_client/features/playlists/presentation/views/playlist_detail_view.dart';
import 'package:vhunambi_client/features/playlists/presentation/widgets/playlist_cover_art.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_repository_provider.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// The Playlists tab view in User Library Vault (`/library?tab=playlists`).
///
/// Implements REQ-PV-02 and REQ-PV-03 from Phase 12.1.
class PlaylistsVaultView extends ConsumerStatefulWidget {
  final VoidCallback? onCreateRequested;

  const PlaylistsVaultView({super.key, this.onCreateRequested});

  @override
  ConsumerState<PlaylistsVaultView> createState() => _PlaylistsVaultViewState();
}

class _PlaylistsVaultViewState extends ConsumerState<PlaylistsVaultView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showCreateDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _CreatePlaylistDialog(
        onCreated: (title, description, coverImageUrl) {
          ref
              .read(playlistsProvider.notifier)
              .createPlaylist(
                title,
                description: description,
                coverImageUrl: coverImageUrl,
              );
        },
      ),
    );
  }

  /// Resolves a playlist's track ids into live vault [Track]s for the cover
  /// collage (Mission 10). Unknown ids are skipped.
  List<Track> _resolveTracks(PlaylistEntity playlist) {
    final byId = {
      for (final t in ref.read(libraryTracksProvider)) t.id: t.toTrack(),
    };
    return [for (final id in playlist.trackIds) ?byId[id]];
  }

  void _showRenameDialog(PlaylistEntity playlist) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _RenamePlaylistDialog(
        currentTitle: playlist.title,
        currentDescription: playlist.description,
        currentCoverImageUrl: playlist.coverImageUrl,
        onRenamed: (newTitle, newDescription, newCoverImageUrl, clearCover) {
          ref
              .read(playlistsProvider.notifier)
              .updatePlaylist(
                playlist.id,
                title: newTitle,
                description: newDescription,
                coverImageUrl: newCoverImageUrl,
                clearCoverImage: clearCover,
              );
        },
      ),
    );
  }

  void _confirmDelete(PlaylistEntity playlist) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceModalOf(dialogContext),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        title: Text(
          'Delete Playlist?',
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.textPrimaryOf(dialogContext),
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${playlist.title}"? Your saved tracks will remain in your Vault.',
          style: AppTypography.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(playlistsProvider.notifier).deletePlaylist(playlist.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleShare(PlaylistEntity playlist) async {
    final shared = await ref
        .read(playlistsProvider.notifier)
        .sharePlaylist(playlist.id);
    if (!mounted) return;
    final url = shared?.shareUrl ?? 'https://vhunambi.za/p/${playlist.id}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Share link ready: $url'),
        backgroundColor: AppColors.brandPrimary,
      ),
    );
  }

  Future<void> _handleCloudSync() async {
    await ref.read(playlistsProvider.notifier).syncWithCloud();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Playlists synchronized with Vhunambi Cloud'),
        backgroundColor: AppColors.brandPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPlaylists = ref.watch(playlistsProvider);
    final viewMode = ref.watch(libraryViewModeProvider);
    final isCloudSyncing = ref.watch(playlistCloudSyncingProvider);
    final hasActiveTrack = ref.watch(
      playerStateProvider.select((s) => s.hasActiveTrack),
    );
    final bottomInset = VhunambiBottomDockMetrics.scrollInset(
      hasActiveTrack: hasActiveTrack,
    );

    final filteredPlaylists = _searchQuery.isEmpty
        ? allPlaylists
        : allPlaylists
              .where(
                (p) =>
                    p.title.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    p.description.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
              )
              .toList();

    if (allPlaylists.isEmpty) {
      return LibraryEmptyState(
        category: LibraryCategory.playlists,
        searchQuery: '',
        onCreateRequested: _showCreateDialog,
      );
    }

    return Column(
      children: [
        // Action Strip
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim()),
                    style: AppTypography.bodyLarge,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      hintText: 'Search playlists...',
                      hintStyle: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: PhosphorIcon(
                          PhosphorIconsRegular.magnifyingGlass,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 38,
                        minHeight: 38,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: PhosphorIcon(
                                PhosphorIconsRegular.x,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.pillBorder,
                        borderSide: BorderSide(color: AppColors.borderSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.pillBorder,
                        borderSide: BorderSide(color: AppColors.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.pillBorder,
                        borderSide: BorderSide(
                          color: AppColors.textPrimaryOf(
                            context,
                          ).withValues(alpha: 0.22),
                          width: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                key: const Key('playlists_cloud_sync_btn'),
                tooltip: 'Sync Playlists to Cloud',
                onPressed: isCloudSyncing ? null : _handleCloudSync,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceElevated,
                  foregroundColor: AppColors.brandPrimary,
                  side: BorderSide(color: AppColors.borderSubtle),
                ),
                icon: isCloudSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brandPrimary,
                        ),
                      )
                    : const PhosphorIcon(
                        PhosphorIconsRegular.cloudArrowUp,
                        size: 18,
                        color: AppColors.brandPrimary,
                      ),
              ),
              const SizedBox(width: AppSpacing.xs),
              ElevatedButton.icon(
                onPressed: _showCreateDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.brandContrast,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                ),
                icon: const PhosphorIcon(
                  PhosphorIconsBold.plus,
                  size: 18,
                  color: AppColors.brandContrast,
                ),
                label: const Text(
                  'New Playlist',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        // List / Grid Body
        Expanded(
          child: filteredPlaylists.isEmpty
              ? Center(
                  child: Text(
                    'No playlists match "$_searchQuery"',
                    style: AppTypography.bodyMuted,
                  ),
                )
              : viewMode == LibraryViewMode.grid
              ? GridView.builder(
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
                    childAspectRatio: 0.85,
                  ),
                  itemCount: filteredPlaylists.length,
                  itemBuilder: (_, index) {
                    final playlist = filteredPlaylists[index];
                    return _PlaylistGridCard(
                      playlist: playlist,
                      tracks: _resolveTracks(playlist),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PlaylistDetailView(playlist: playlist),
                          ),
                        );
                      },
                      onRename: () => _showRenameDialog(playlist),
                      onShare: () => _handleShare(playlist),
                      onDelete: () => _confirmDelete(playlist),
                    );
                  },
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xxs,
                    AppSpacing.md,
                    bottomInset,
                  ),
                  itemCount: filteredPlaylists.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (_, index) {
                    final playlist = filteredPlaylists[index];
                    return _PlaylistListTile(
                      playlist: playlist,
                      tracks: _resolveTracks(playlist),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PlaylistDetailView(playlist: playlist),
                          ),
                        );
                      },
                      onRename: () => _showRenameDialog(playlist),
                      onShare: () => _handleShare(playlist),
                      onDelete: () => _confirmDelete(playlist),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PlaylistGridCard extends StatelessWidget {
  final PlaylistEntity playlist;
  final List<Track> tracks;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _PlaylistGridCard({
    required this.playlist,
    required this.tracks,
    required this.onTap,
    required this.onRename,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return VhunambiGlassSurface(
      variant: VhunambiGlassVariant.card,
      enableLiveBlur: false,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardBorder,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Artwork
            Expanded(
              child: Center(
                child: PlaylistCoverArt(
                  playlist: playlist,
                  tracks: tracks,
                  size: 120,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Title and context menu
            Row(
              children: [
                Expanded(
                  child: Text(
                    playlist.title,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryOf(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: PhosphorIcon(
                    PhosphorIconsRegular.dotsThreeVertical,
                    size: 18,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  color: AppColors.surfaceModalOf(context),
                  onSelected: (action) {
                    if (action == 'rename') onRename();
                    if (action == 'share') onShare();
                    if (action == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          PhosphorIcon(
                            PhosphorIconsRegular.pencilSimple,
                            size: 16,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 8),
                          const Text('Rename'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          PhosphorIcon(
                            PhosphorIconsRegular.shareNetwork,
                            size: 16,
                            color: AppColors.brandPrimary,
                          ),
                          SizedBox(width: 8),
                          Text('Share Link'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          PhosphorIcon(
                            PhosphorIconsRegular.trash,
                            size: 16,
                            color: AppColors.error,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Count info
            Text(
              '${playlist.trackCount} ${playlist.trackCount == 1 ? 'song' : 'songs'}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistListTile extends StatelessWidget {
  final PlaylistEntity playlist;
  final List<Track> tracks;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const _PlaylistListTile({
    required this.playlist,
    required this.tracks,
    required this.onTap,
    required this.onRename,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return VhunambiGlassSurface(
      variant: VhunambiGlassVariant.card,
      enableLiveBlur: false,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 4,
        ),
        leading: PlaylistCoverArt(playlist: playlist, tracks: tracks, size: 48),
        title: Text(
          playlist.title,
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryOf(context),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          playlist.description.isNotEmpty
              ? '${playlist.trackCount} ${playlist.trackCount == 1 ? 'song' : 'songs'} • ${playlist.description}'
              : '${playlist.trackCount} ${playlist.trackCount == 1 ? 'song' : 'songs'}',
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondaryOf(context),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          icon: PhosphorIcon(
            PhosphorIconsRegular.dotsThreeVertical,
            size: 20,
            color: AppColors.textSecondaryOf(context),
          ),
          color: AppColors.surfaceModalOf(context),
          onSelected: (action) {
            if (action == 'rename') onRename();
            if (action == 'share') onShare();
            if (action == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  PhosphorIcon(
                    PhosphorIconsRegular.pencilSimple,
                    size: 16,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  const Text('Rename'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  PhosphorIcon(
                    PhosphorIconsRegular.shareNetwork,
                    size: 16,
                    color: AppColors.brandPrimary,
                  ),
                  SizedBox(width: 8),
                  Text('Share Link'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  PhosphorIcon(
                    PhosphorIconsRegular.trash,
                    size: 16,
                    color: AppColors.error,
                  ),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePlaylistDialog extends ConsumerStatefulWidget {
  final void Function(String title, String? description, String? coverImageUrl)
  onCreated;

  const _CreatePlaylistDialog({required this.onCreated});

  @override
  ConsumerState<_CreatePlaylistDialog> createState() =>
      _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends ConsumerState<_CreatePlaylistDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String? _coverImageUrl;
  bool _isUploadingCover = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    if (_isUploadingCover) return;
    setState(() => _isUploadingCover = true);
    try {
      final uploaded = await VhunambiMediaUploadService.pickAndUploadImage(
        socialRepository: ref.read(socialRepositoryProvider),
        purposePrefix: 'playlist_cover',
      );
      if (!mounted || uploaded == null) return;
      setState(() => _coverImageUrl = uploaded.url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cover upload failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingCover = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    return AlertDialog(
      backgroundColor: AppColors.surfaceModalOf(context),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
      title: Text(
        'Create New Playlist',
        style: AppTypography.titleMedium.copyWith(color: textPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                VhunambiTrackArtwork(
                  coverUrl: _coverImageUrl,
                  genre: 'Amapiano',
                  trackId: 'new_pl_cover',
                  width: 64,
                  height: 64,
                  borderRadius: BorderRadius.circular(AppRadius.thumb),
                  badgeIconSize: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('playlist_pick_cover_btn'),
                        onPressed: _isUploadingCover ? null : _pickCoverImage,
                        icon: _isUploadingCover
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const PhosphorIcon(
                                PhosphorIconsRegular.image,
                                size: 16,
                              ),
                        label: Text(
                          _isUploadingCover ? 'Uploading...' : 'Upload Cover',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textPrimary,
                          side: BorderSide(
                            color: AppColors.borderSubtleOf(context),
                          ),
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                      if (_coverImageUrl != null)
                        TextButton(
                          key: const Key('playlist_clear_cover_btn'),
                          onPressed: () =>
                              setState(() => _coverImageUrl = null),
                          child: Text(
                            'Use Auto Collage',
                            style: AppTypography.caption.copyWith(
                              color: textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _titleController,
              autofocus: true,
              style: AppTypography.bodyLarge.copyWith(color: textPrimary),
              decoration: const InputDecoration(
                labelText: 'Playlist Title',
                hintText: 'e.g. Late Night Amapiano',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _descController,
              style: AppTypography.bodyLarge.copyWith(color: textPrimary),
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g. Soulful deep cuts',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isEmpty) return;
            widget.onCreated(
              title,
              _descController.text.trim(),
              _coverImageUrl,
            );
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandPrimary,
            foregroundColor: AppColors.brandContrast,
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _RenamePlaylistDialog extends ConsumerStatefulWidget {
  final String currentTitle;
  final String currentDescription;
  final String? currentCoverImageUrl;
  final void Function(
    String newTitle,
    String? newDescription,
    String? newCoverImageUrl,
    bool clearCover,
  )
  onRenamed;

  const _RenamePlaylistDialog({
    required this.currentTitle,
    required this.currentDescription,
    this.currentCoverImageUrl,
    required this.onRenamed,
  });

  @override
  ConsumerState<_RenamePlaylistDialog> createState() =>
      _RenamePlaylistDialogState();
}

class _RenamePlaylistDialogState extends ConsumerState<_RenamePlaylistDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  String? _coverImageUrl;
  bool _clearCover = false;
  bool _isUploadingCover = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.currentTitle);
    _descController = TextEditingController(text: widget.currentDescription);
    _coverImageUrl = widget.currentCoverImageUrl;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    if (_isUploadingCover) return;
    setState(() => _isUploadingCover = true);
    try {
      final uploaded = await VhunambiMediaUploadService.pickAndUploadImage(
        socialRepository: ref.read(socialRepositoryProvider),
        purposePrefix: 'playlist_cover',
      );
      if (!mounted || uploaded == null) return;
      setState(() {
        _coverImageUrl = uploaded.url;
        _clearCover = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cover upload failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingCover = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    return AlertDialog(
      backgroundColor: AppColors.surfaceModalOf(context),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
      title: Text(
        'Edit Playlist',
        style: AppTypography.titleMedium.copyWith(color: textPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                VhunambiTrackArtwork(
                  coverUrl: _clearCover ? null : _coverImageUrl,
                  genre: 'Amapiano',
                  trackId: widget.currentTitle,
                  width: 64,
                  height: 64,
                  borderRadius: BorderRadius.circular(AppRadius.thumb),
                  badgeIconSize: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('playlist_pick_cover_btn'),
                        onPressed: _isUploadingCover ? null : _pickCoverImage,
                        icon: _isUploadingCover
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const PhosphorIcon(
                                PhosphorIconsRegular.image,
                                size: 16,
                              ),
                        label: Text(
                          _isUploadingCover ? 'Uploading...' : 'Change Cover',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textPrimary,
                          side: BorderSide(
                            color: AppColors.borderSubtleOf(context),
                          ),
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                      if (_coverImageUrl != null && !_clearCover)
                        TextButton(
                          key: const Key('playlist_clear_cover_btn'),
                          onPressed: () => setState(() {
                            _coverImageUrl = null;
                            _clearCover = true;
                          }),
                          child: Text(
                            'Use Auto Collage',
                            style: AppTypography.caption.copyWith(
                              color: textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _titleController,
              autofocus: true,
              style: AppTypography.bodyLarge.copyWith(color: textPrimary),
              decoration: const InputDecoration(labelText: 'Playlist Title'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _descController,
              style: AppTypography.bodyLarge.copyWith(color: textPrimary),
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isEmpty) return;
            widget.onRenamed(
              title,
              _descController.text.trim(),
              _coverImageUrl,
              _clearCover,
            );
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandPrimary,
            foregroundColor: AppColors.brandContrast,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
