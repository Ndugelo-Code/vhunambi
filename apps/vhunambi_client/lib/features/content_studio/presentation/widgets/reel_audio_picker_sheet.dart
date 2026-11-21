import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/vhunambi_mood.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// Selected audio payload returned from [ReelAudioPickerSheet] (`REQ-P74-STU-03`).
@immutable
class ReelStudioAudioSelection {
  final String trackId;
  final String title;
  final String creatorHandle;
  final String genre;
  final String mood;
  final String audioUrl;
  final String coverUrl;
  final double durationSeconds;
  final bool isInitiallySaved;
  final SongMetadataDna dna;
  final Uint8List? importedAudioBytes;
  final String? importedAudioMime;

  const ReelStudioAudioSelection({
    required this.trackId,
    required this.title,
    required this.creatorHandle,
    required this.genre,
    required this.mood,
    required this.audioUrl,
    required this.coverUrl,
    required this.durationSeconds,
    this.isInitiallySaved = false,
    required this.dna,
    this.importedAudioBytes,
    this.importedAudioMime,
  });

  factory ReelStudioAudioSelection.fromLibraryTrack(LibraryTrack track) {
    return ReelStudioAudioSelection(
      trackId: track.id,
      title: track.title,
      creatorHandle: track.creatorHandle ?? track.creatorName,
      genre: track.genre,
      mood: track.moodId ?? track.mood ?? 'uplifting',
      audioUrl: track.remoteAudioUrl,
      coverUrl: track.coverImageUrl ?? '',
      durationSeconds:
          track.durationSeconds > 5 ? track.durationSeconds.toDouble() : 120.0,
      isInitiallySaved: track.isFavorite,
      dna: track.toSongMetadataDna(),
    );
  }

  factory ReelStudioAudioSelection.fromExploreTrack(Track track) {
    final sec = track.duration.inSeconds;
    return ReelStudioAudioSelection(
      trackId: track.id,
      title: track.title,
      creatorHandle: track.creatorHandle ?? track.creatorName,
      genre: track.genre,
      mood: track.mood ?? 'uplifting',
      audioUrl: track.audioUrl ?? '',
      coverUrl: track.coverUrl ?? '',
      durationSeconds: sec > 5 ? sec.toDouble() : 120.0,
      isInitiallySaved: false,
      dna: SongMetadataDna.fromTrackInfo(
        id: track.id,
        title: track.title,
        genre: track.genre,
        language: track.language,
        durationSec: sec > 5 ? sec : 120,
        coverUrl: track.coverUrl,
      ),
    );
  }
}

/// 4-tab Instagram-grade audio picker (`My Vault`, `Trending`, `Saved`, `Vibes`)
/// with live search (`Key('reel_audio_search_input')`) and local `[Import]` (`REQ-P74-STU-03`).
class ReelAudioPickerSheet extends ConsumerStatefulWidget {
  final ValueChanged<ReelStudioAudioSelection> onSelected;

  const ReelAudioPickerSheet({super.key, required this.onSelected});

  static Future<ReelStudioAudioSelection?> show(BuildContext context) {
    return showModalBottomSheet<ReelStudioAudioSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReelAudioPickerSheet(
        onSelected: (selection) => Navigator.of(ctx).pop(selection),
      ),
    );
  }

  @override
  ConsumerState<ReelAudioPickerSheet> createState() =>
      _ReelAudioPickerSheetState();
}

class _ReelAudioPickerSheetState extends ConsumerState<ReelAudioPickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _savedTrackIds = <String>{};
  String _query = '';
  VhunambiMood _selectedMood = VhunambiMood.uplifting;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _importLocalAudio() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['mp3', 'm4a'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.first;
      final ext = (file.extension ?? 'mp3').toLowerCase();
      final mime = ext == 'm4a' ? 'audio/mp4' : 'audio/mpeg';
      final rawTitle = file.name.replaceAll(RegExp(r'\.[^.]+$'), '').trim();
      final resolvedTitle = rawTitle.isEmpty ? 'Imported Audio' : rawTitle;
      final id = 'local_audio_${DateTime.now().millisecondsSinceEpoch}';
      widget.onSelected(
        ReelStudioAudioSelection(
          trackId: id,
          title: resolvedTitle,
          creatorHandle: 'local_import',
          genre: 'Amapiano',
          mood: _selectedMood.moodId,
          audioUrl: file.path ?? '',
          coverUrl: '',
          durationSeconds: 90.0,
          dna: SongMetadataDna.fromTrackInfo(
            id: id,
            title: resolvedTitle,
            genre: 'Amapiano',
            language: 'English',
            durationSec: 90,
          ),
          importedAudioBytes: file.bytes,
          importedAudioMime: mime,
        ),
      );
    } catch (_) {
      // Safe no-op in headless test environments
    }
  }

  List<ReelStudioAudioSelection> _filterItems(
    List<ReelStudioAudioSelection> source, {
    bool requireMood = false,
  }) {
    final q = _query.trim().toLowerCase();
    return source
        .where((item) {
          if (requireMood) {
            final mood =
                VhunambiMood.tryNormalize(item.mood) ?? VhunambiMood.uplifting;
            if (mood != _selectedMood) return false;
          }
          if (q.isEmpty) return true;
          return item.title.toLowerCase().contains(q) ||
              item.genre.toLowerCase().contains(q) ||
              item.creatorHandle.toLowerCase().contains(q);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final vaultTracks = ref
        .watch(libraryTracksProvider)
        .map(ReelStudioAudioSelection.fromLibraryTrack)
        .toList(growable: false);
    final exploreTracks = ref
        .watch(exploreTracksProvider)
        .map(ReelStudioAudioSelection.fromExploreTrack)
        .toList(growable: false);
    final combined = <ReelStudioAudioSelection>[
      ...vaultTracks,
      ...exploreTracks,
    ];
    final savedTracks = combined
        .where(
          (t) => t.isInitiallySaved || _savedTrackIds.contains(t.trackId),
        )
        .toList(growable: false);

    return Container(
      key: const Key('reel_audio_picker_sheet'),
      height: MediaQuery.sizeOf(context).height * 0.78,
      decoration: BoxDecoration(
        color: AppColors.surfaceModalOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderSubtleOf(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const Key('reel_audio_search_input'),
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search Vault, Trending, or Moods...',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: PhosphorIcon(
                          AppIcons.search,
                          size: 18,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const Key('reel_audio_import_btn'),
                  onPressed: _importLocalAudio,
                  icon: const PhosphorIcon(AppIcons.upload, size: 16),
                  label: const Text('Import'),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.brandPrimary,
            unselectedLabelColor: AppColors.textSecondaryOf(context),
            indicatorColor: AppColors.brandPrimary,
            tabs: const <Tab>[
              Tab(text: 'My Vault'),
              Tab(text: 'Trending'),
              Tab(text: 'Saved'),
              Tab(text: 'Vibes'),
            ],
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: TabBarView(
                controller: _tabController,
                children: <Widget>[
                  _buildTrackList(_filterItems(vaultTracks), prefix: 'vault'),
                  _buildTrackList(
                    _filterItems(exploreTracks),
                    prefix: 'trending',
                  ),
                  _buildTrackList(_filterItems(savedTracks), prefix: 'saved'),
                  Column(
                    children: <Widget>[
                      SizedBox(
                        height: 48,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: VhunambiMood.values.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final mood = VhunambiMood.values[idx];
                            final active = mood == _selectedMood;
                            return ChoiceChip(
                              key: Key('reel_audio_vibe_${mood.moodId}'),
                              selected: active,
                              label: Text(mood.label),
                              avatar: PhosphorIcon(
                                mood.icon,
                                size: 14,
                                color: mood.accentColor,
                              ),
                              onSelected: (_) =>
                                  setState(() => _selectedMood = mood),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: _buildTrackList(
                          _filterItems(combined, requireMood: true),
                          prefix: 'vibes',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackList(
    List<ReelStudioAudioSelection> tracks, {
    required String prefix,
  }) {
    if (tracks.isEmpty) {
      return Center(
        child: Text(
          'No matching tracks found',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondaryOf(context),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: tracks.length,
      itemBuilder: (context, i) {
        final item = tracks[i];
        final isSaved =
            item.isInitiallySaved || _savedTrackIds.contains(item.trackId);
        return ListTile(
          key: Key('reel_audio_pick_${prefix}_${item.trackId}'),
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: VhunambiTrackArtwork(
            coverUrl: item.coverUrl,
            genre: item.genre,
            trackId: item.trackId,
            width: 48,
            height: 48,
            borderRadius: AppRadius.thumbBorder,
          ),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${item.genre} • ${item.creatorHandle}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption,
          ),
          trailing: IconButton(
            onPressed: () {
              setState(() {
                if (!_savedTrackIds.add(item.trackId)) {
                  _savedTrackIds.remove(item.trackId);
                }
              });
            },
            icon: PhosphorIcon(
              isSaved
                  ? PhosphorIconsFill.bookmarkSimple
                  : PhosphorIconsRegular.bookmarkSimple,
              size: 20,
              color: isSaved
                  ? AppColors.brandPrimary
                  : AppColors.textSecondaryOf(context),
            ),
          ),
          onTap: () => widget.onSelected(item),
        );
      },
    );
  }
}
