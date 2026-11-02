import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../domain/models/collection_entity.dart';
import '../providers/collections_provider.dart';

/// Bottom sheet listing vault tracks that are not yet inside a collection
/// (REQ-COL-23).
class AddToCollectionSheet extends ConsumerStatefulWidget {
  final String collectionId;

  const AddToCollectionSheet({super.key, required this.collectionId});

  /// Opens the vault picker for [collectionId].
  static Future<void> show(
    BuildContext context, {
    required String collectionId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceModal,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.modalBorder),
      builder: (_) => AddToCollectionSheet(collectionId: collectionId),
    );
  }

  @override
  ConsumerState<AddToCollectionSheet> createState() =>
      _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends ConsumerState<AddToCollectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final collections = ref.watch(collectionsProvider);
    CollectionEntity? collection;
    for (final candidate in collections) {
      if (candidate.id == widget.collectionId) collection = candidate;
    }

    final existing = collection?.trackIds.toSet() ?? const <String>{};
    final available = ref
        .watch(libraryTracksProvider)
        .where((track) => !existing.contains(track.id))
        .toList(growable: false);

    final query = _query.toLowerCase();
    final candidates = query.isEmpty
        ? available
        : available
            .where((track) =>
                track.title.toLowerCase().contains(query) ||
                track.creatorName.toLowerCase().contains(query) ||
                track.genre.toLowerCase().contains(query))
            .toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: AppRadius.pillBorder,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add Track',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: TextField(
                key: const Key('collection_add_search'),
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value.trim()),
                style: AppTypography.bodyLarge,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  hintText: 'Search your vault...',
                  hintStyle: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.pillBorder,
                    borderSide: BorderSide(color: AppColors.borderSubtle),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: candidates.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          available.isEmpty
                              ? 'All your library tracks are already in this collection.'
                              : 'No vault tracks match "$_query"',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMuted,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.lg,
                      ),
                      itemCount: candidates.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (_, index) {
                        final track = candidates[index];
                        return Material(
                          color: AppColors.surfaceElevated,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.cardBorder,
                            side: BorderSide(color: AppColors.borderSubtle),
                          ),
                          child: ListTile(
                            key: Key('add_track_${track.id}'),
                            title: Text(
                              track.title,
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${track.creatorName} • ${track.genre}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            trailing: Text(
                              track.formattedDuration,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            onTap: () {
                              ref
                                  .read(collectionsProvider.notifier)
                                  .addTrack(widget.collectionId, track.id);
                              Navigator.of(context).pop();
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
