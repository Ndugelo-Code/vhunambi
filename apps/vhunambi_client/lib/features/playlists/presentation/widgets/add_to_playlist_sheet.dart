import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/models/track.dart';
import '../../domain/models/playlist_entity.dart';
import '../providers/playlists_provider.dart';

/// Searchable playlist picker with inline playlist creation (T12.7 /
/// REQ-PL-08).
class AddToPlaylistSheet extends ConsumerStatefulWidget {
  const AddToPlaylistSheet({super.key, required this.track});

  final Track track;

  static Future<void> show(BuildContext context, Track track) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceModal,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.modalBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (_) => AddToPlaylistSheet(track: track),
    );
  }

  @override
  ConsumerState<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends ConsumerState<AddToPlaylistSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  String _query = '';
  bool _isCreating = false;

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  List<PlaylistEntity> _visiblePlaylists(List<PlaylistEntity> playlists) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return playlists;
    return playlists
        .where((playlist) => playlist.title.toLowerCase().contains(query))
        .toList(growable: false);
  }

  /// Creates the inline playlist and immediately files the current track.
  Future<void> _createPlaylist() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final notifier = ref.read(playlistsProvider.notifier);
    final created = await notifier.createPlaylist(title);
    await notifier.addTrackToPlaylist(created.id, widget.track.id);

    if (!mounted) return;
    _titleController.clear();
    setState(() => _isCreating = false);
  }

  @override
  Widget build(BuildContext context) {
    final playlists = ref.watch(playlistsProvider);
    final notifier = ref.read(playlistsProvider.notifier);
    final visible = _visiblePlaylists(playlists);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHeader(trackTitle: widget.track.title),
            const SizedBox(height: AppSpacing.sm),
            _SearchField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              key: const Key('new_playlist_toggle'),
              onPressed: () => setState(() => _isCreating = !_isCreating),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: AppColors.borderSubtle),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
              icon: const Icon(
                Icons.add_rounded,
                size: 16,
                color: AppColors.brandPrimary,
              ),
              label: Text(
                'Create New Playlist',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (_isCreating) ...[
              const SizedBox(height: AppSpacing.xs),
              _NewPlaylistField(
                controller: _titleController,
                onSubmit: _createPlaylist,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: visible.isEmpty
                  ? _EmptyPlaylistPicker(query: _query)
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: visible.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.xxs),
                      itemBuilder: (context, index) {
                        final playlist = visible[index];
                        return _PlaylistCheckboxTile(
                          playlist: playlist,
                          isSelected:
                              playlist.trackIds.contains(widget.track.id),
                          onToggle: () => notifier.toggleTrackInPlaylist(
                            playlist.id,
                            widget.track.id,
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                key: const Key('playlist_sheet_done'),
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.brandContrast,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
                child: Text(
                  'Done',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.brandContrast,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet header carrying the target track title.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.trackTitle});

  final String trackTitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.playlist_add_rounded,
          size: 20,
          color: AppColors.brandPrimary,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add to Playlist', style: AppTypography.titleMedium),
              Text(
                trackTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Search field filtering the playlist vault (REQ-PL-08).
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: AppRadius.pillBorder,
      borderSide: BorderSide(color: AppColors.borderSubtle),
    );

    return TextField(
      key: const Key('playlist_search'),
      controller: controller,
      onChanged: onChanged,
      style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search playlists...',
        hintStyle: AppTypography.bodySmall,
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 18,
          color: AppColors.textTertiary,
        ),
        filled: true,
        fillColor: AppColors.surfaceSecondary,
        border: border,
        enabledBorder: border,
      ),
    );
  }
}

/// Inline `+ New Playlist` creator row.
class _NewPlaylistField extends StatelessWidget {
  const _NewPlaylistField({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('new_playlist_title'),
            controller: controller,
            onSubmitted: (_) => onSubmit(),
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Playlist name',
              border: OutlineInputBorder(borderRadius: AppRadius.inputBorder),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.inputBorder,
                borderSide: BorderSide(color: AppColors.brandPrimary),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        ElevatedButton(
          key: const Key('new_playlist_submit'),
          onPressed: onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandPrimary,
            foregroundColor: AppColors.brandContrast,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.pillBorder,
            ),
          ),
          child: Text(
            'Create',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.brandContrast,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// One playlist row with its membership checkbox.
class _PlaylistCheckboxTile extends StatelessWidget {
  const _PlaylistCheckboxTile({
    required this.playlist,
    required this.isSelected,
    required this.onToggle,
  });

  final PlaylistEntity playlist;
  final bool isSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceElevated,
      borderRadius: AppRadius.cardBorder,
      child: InkWell(
        key: Key('playlist_tile_${playlist.id}'),
        onTap: onToggle,
        borderRadius: AppRadius.cardBorder,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.album_rounded,
                  size: 16,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(playlist.trackCountLabel, style: AppTypography.caption),
                  ],
                ),
              ),
              Checkbox(
                key: Key('playlist_check_${playlist.id}'),
                value: isSelected,
                onChanged: (_) => onToggle(),
                activeColor: AppColors.brandPrimary,
                checkColor: AppColors.brandContrast,
                side: BorderSide(color: AppColors.borderActive),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the vault — or the active search — holds no playlists.
class _EmptyPlaylistPicker extends StatelessWidget {
  const _EmptyPlaylistPicker({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          Icon(
            Icons.queue_music_rounded,
            size: 28,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            query.isEmpty ? 'No playlists yet' : 'No playlists match "$query"',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Create your first playlist above.',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}
