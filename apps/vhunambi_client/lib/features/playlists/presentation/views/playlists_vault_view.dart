import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/models/track.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../library/presentation/widgets/library_empty_state.dart';
import '../../domain/models/playlist_entity.dart';
import '../providers/playlists_provider.dart';
import '../widgets/playlist_cover_art.dart';
import 'playlist_detail_view.dart';

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
        onCreated: (title, description) {
          ref.read(playlistsProvider.notifier).createPlaylist(
                title,
                description: description,
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
    return [
      for (final id in playlist.trackIds) ?byId[id],
    ];
  }

  void _showRenameDialog(PlaylistEntity playlist) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _RenamePlaylistDialog(
        currentTitle: playlist.title,
        currentDescription: playlist.description,
        onRenamed: (newTitle, newDescription) {
          ref.read(playlistsProvider.notifier).updatePlaylist(
                playlist.id,
                title: newTitle,
                description: newDescription,
              );
        },
      ),
    );
  }

  void _confirmDelete(PlaylistEntity playlist) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceModal,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        title: Text(
          'Delete Playlist?',
          style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary),
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

  @override
  Widget build(BuildContext context) {
    final allPlaylists = ref.watch(playlistsProvider);
    final viewMode = ref.watch(libraryViewModeProvider);

    final filteredPlaylists = _searchQuery.isEmpty
        ? allPlaylists
        : allPlaylists
            .where((p) =>
                p.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                p.description.toLowerCase().contains(_searchQuery.toLowerCase()))
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
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    style: AppTypography.bodyLarge,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      hintText: 'Search playlists...',
                      hintStyle: AppTypography.caption.copyWith(color: AppColors.textTertiary),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.pillBorder,
                        borderSide: const BorderSide(color: AppColors.borderSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.pillBorder,
                        borderSide: const BorderSide(color: AppColors.borderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.pillBorder,
                        borderSide: const BorderSide(color: AppColors.brandPrimary),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton.icon(
                onPressed: _showCreateDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.brandContrast,
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New Playlist', style: TextStyle(fontWeight: FontWeight.bold)),
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
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xxs,
                        AppSpacing.md,
                        110,
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
                                builder: (_) => PlaylistDetailView(playlist: playlist),
                              ),
                            );
                          },
                          onRename: () => _showRenameDialog(playlist),
                          onDelete: () => _confirmDelete(playlist),
                        );
                      },
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xxs,
                        AppSpacing.md,
                        110,
                      ),
                      itemCount: filteredPlaylists.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (_, index) {
                        final playlist = filteredPlaylists[index];
                        return _PlaylistListTile(
                          playlist: playlist,
                          tracks: _resolveTracks(playlist),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PlaylistDetailView(playlist: playlist),
                              ),
                            );
                          },
                          onRename: () => _showRenameDialog(playlist),
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
  final VoidCallback onDelete;

  const _PlaylistGridCard({
    required this.playlist,
    required this.tracks,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: AppRadius.cardBorder,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardBorder,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.borderSubtle),
          ),
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
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textSecondary),
                    color: AppColors.surfaceModal,
                    onSelected: (action) {
                      if (action == 'rename') onRename();
                      if (action == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 16, color: AppColors.textPrimary),
                            SizedBox(width: 8),
                            Text('Rename'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: AppColors.error)),
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
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
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
  final VoidCallback onDelete;

  const _PlaylistListTile({
    required this.playlist,
    required this.tracks,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
        leading: PlaylistCoverArt(
          playlist: playlist,
          tracks: tracks,
          size: 48,
        ),
        title: Text(
          playlist.title,
          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          playlist.description.isNotEmpty
              ? '${playlist.trackCount} ${playlist.trackCount == 1 ? 'song' : 'songs'} • ${playlist.description}'
              : '${playlist.trackCount} ${playlist.trackCount == 1 ? 'song' : 'songs'}',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textSecondary),
          color: AppColors.surfaceModal,
          onSelected: (action) {
            if (action == 'rename') onRename();
            if (action == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit_rounded, size: 16, color: AppColors.textPrimary),
                  SizedBox(width: 8),
                  Text('Rename'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
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

class _CreatePlaylistDialog extends StatefulWidget {
  final void Function(String title, String? description) onCreated;

  const _CreatePlaylistDialog({required this.onCreated});

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceModal,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
      title: Text(
        'Create New Playlist',
        style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            autofocus: true,
            style: AppTypography.bodyLarge,
            decoration: const InputDecoration(
              labelText: 'Playlist Title',
              hintText: 'e.g. Late Night Amapiano',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _descController,
            style: AppTypography.bodyLarge,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'e.g. Soulful deep cuts',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
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
            final title = _titleController.text.trim();
            if (title.isEmpty) return;
            widget.onCreated(title, _descController.text.trim());
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

class _RenamePlaylistDialog extends StatefulWidget {
  final String currentTitle;
  final String currentDescription;
  final void Function(String newTitle, String? newDescription) onRenamed;

  const _RenamePlaylistDialog({
    required this.currentTitle,
    required this.currentDescription,
    required this.onRenamed,
  });

  @override
  State<_RenamePlaylistDialog> createState() => _RenamePlaylistDialogState();
}

class _RenamePlaylistDialogState extends State<_RenamePlaylistDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.currentTitle);
    _descController = TextEditingController(text: widget.currentDescription);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceModal,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
      title: Text('Edit Playlist', style: AppTypography.titleMedium),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            autofocus: true,
            style: AppTypography.bodyLarge,
            decoration: const InputDecoration(labelText: 'Playlist Title'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _descController,
            style: AppTypography.bodyLarge,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
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
            final title = _titleController.text.trim();
            if (title.isEmpty) return;
            widget.onRenamed(title, _descController.text.trim());
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
