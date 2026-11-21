import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/widgets/vhunambi_bottom_dock_kit.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../library/presentation/widgets/library_empty_state.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../domain/models/collection_entity.dart';
import '../providers/collections_provider.dart';
import '../widgets/collection_artwork_placeholder.dart';
import '../widgets/collection_form_dialog.dart';
import '../widgets/collection_type_badge.dart';
import 'collection_detail_view.dart';

/// The Collections tab view in the User Library Vault (`/library?tab=collections`).
///
/// Implements REQ-COL-12 through REQ-COL-19 from Phase 13: responsive grid/list
/// vault, universal empty state, create/rename dialogs and delete confirmation.
class CollectionsVaultView extends ConsumerStatefulWidget {
  /// Routes to the Studio cockpit when the host shell provides it.
  final VoidCallback? onCreateRequested;

  const CollectionsVaultView({super.key, this.onCreateRequested});

  @override
  ConsumerState<CollectionsVaultView> createState() =>
      _CollectionsVaultViewState();
}

class _CollectionsVaultViewState extends ConsumerState<CollectionsVaultView> {
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
      builder: (dialogContext) => CollectionFormDialog(
        onSubmitted: (title, type, genre, description, releaseDate) {
          ref.read(collectionsProvider.notifier).createCollection(
                title,
                type,
                genre: genre,
                description: description,
                releaseDate: releaseDate,
              );
        },
      ),
    );
  }

  void _showRenameDialog(CollectionEntity collection) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => CollectionFormDialog(
        initial: collection,
        onSubmitted: (title, type, genre, description, releaseDate) {
          ref.read(collectionsProvider.notifier).updateCollection(
                collection.id,
                title: title,
                type: type,
                genre: genre,
                description: description,
                releaseDate: releaseDate,
              );
        },
      ),
    );
  }

  void _confirmDelete(CollectionEntity collection) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceModal,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        title: Text(
          'Delete Collection?',
          style: AppTypography.titleMedium.copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${collection.title}"? '
          'Your saved tracks will remain in your Vault.',
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
            key: const Key('collection_dialog_delete_confirm'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref
                  .read(collectionsProvider.notifier)
                  .deleteCollection(collection.id);
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

  void _openDetail(CollectionEntity collection) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CollectionDetailView(collection: collection),
      ),
    );
  }

  /// Blueprint 13 §7 breakpoint contract: 2 / 3 / 4 columns.
  int _gridColumns(BuildContext context) {
    if (ResponsiveUtils.isDesktop(context)) return 4;
    if (ResponsiveUtils.isTablet(context)) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final allCollections = ref.watch(collectionsProvider);
    final viewMode = ref.watch(libraryViewModeProvider);
    final hasActiveTrack = ref.watch(
      playerStateProvider.select((s) => s.hasActiveTrack),
    );
    final bottomInset = VhunambiBottomDockMetrics.scrollInset(
      hasActiveTrack: hasActiveTrack,
    );

    final query = _searchQuery.toLowerCase();
    final filteredCollections = query.isEmpty
        ? allCollections
        : allCollections
            .where((collection) =>
                collection.title.toLowerCase().contains(query) ||
                collection.genre.toLowerCase().contains(query))
            .toList(growable: false);

    if (allCollections.isEmpty) {
      return LibraryEmptyState(
        category: LibraryCategory.collections,
        searchQuery: '',
        onCreateRequested: _showCreateDialog,
      );
    }

    return Column(
      children: [
        // Action strip — search + New Collection (REQ-COL-14)
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
                    key: const Key('collection_search'),
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _searchQuery = value.trim()),
                    style: AppTypography.bodyLarge,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceElevatedOf(context),
                      hintText: 'Search collections...',
                      hintStyle: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: PhosphorIcon(
                          PhosphorIconsRegular.magnifyingGlass,
                          size: 18,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 38,
                        minHeight: 38,
                      ),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: PhosphorIcon(
                                PhosphorIconsRegular.x,
                                size: 16,
                                color: AppColors.textSecondaryOf(context),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.pillBorder,
                        borderSide: BorderSide(
                          color: AppColors.borderSubtleOf(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton.icon(
                key: const Key('new_collection_button'),
                onPressed: _showCreateDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.brandContrast,
                  minimumSize: const Size(0, 44),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                ),
                icon: const PhosphorIcon(
                  PhosphorIconsBold.plus,
                  size: 18,
                  color: AppColors.brandContrast,
                ),
                label: const Text(
                  'New Collection',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredCollections.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      'No collections match "$_searchQuery"',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMuted,
                    ),
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
                        crossAxisCount: _gridColumns(context),
                        crossAxisSpacing: AppSpacing.sm,
                        mainAxisSpacing: AppSpacing.sm,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: filteredCollections.length,
                      itemBuilder: (_, index) {
                        final collection = filteredCollections[index];
                        return _CollectionCard(
                          collection: collection,
                          onTap: () => _openDetail(collection),
                          onRename: () => _showRenameDialog(collection),
                          onDelete: () => _confirmDelete(collection),
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
                      itemCount: filteredCollections.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.xs),

                      itemBuilder: (_, index) {
                        final collection = filteredCollections[index];
                        return _CollectionListTile(
                          collection: collection,
                          onTap: () => _openDetail(collection),
                          onRename: () => _showRenameDialog(collection),
                          onDelete: () => _confirmDelete(collection),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}


/// Grid card for a single collection bundle (REQ-COL-15).
class _CollectionCard extends StatelessWidget {
  final CollectionEntity collection;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _CollectionCard({
    required this.collection,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return VhunambiGlassSurface(
      key: ValueKey<String>('collection_card_${collection.id}'),
      variant: VhunambiGlassVariant.card,
      enableLiveBlur: false,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardBorder,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: CollectionArtworkPlaceholder(
                  size: 96,
                  iconSize: 30,
                  gap: 3,
                  genre: collection.genre,
                  seedId: collection.id,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                CollectionTypeBadge(type: collection.type),
                const Spacer(),
                _CollectionOverflowMenu(
                  collectionId: collection.id,
                  onRename: onRename,
                  onDelete: onDelete,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              collection.title,
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryOf(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              collection.trackCountLabel,
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

/// Dense list row for a collection bundle (REQ-COL-16).
class _CollectionListTile extends StatelessWidget {
  final CollectionEntity collection;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _CollectionListTile({
    required this.collection,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  String get _subtitle {
    final count = collection.trackCountLabel;
    final tail = '$count • ${collection.typeLabel}';
    return collection.description.isEmpty
        ? tail
        : '${collection.description} • $tail';
  }

  @override
  Widget build(BuildContext context) {
    return VhunambiGlassSurface(
      variant: VhunambiGlassVariant.card,
      enableLiveBlur: false,
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          key: ValueKey<String>('collection_tile_${collection.id}'),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 4,
          ),
          leading: CollectionArtworkPlaceholder(
            size: 48,
            genre: collection.genre,
            seedId: collection.id,
          ),
          title: Text(
            collection.title,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryOf(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            _subtitle,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _CollectionOverflowMenu(
            collectionId: collection.id,
            onRename: onRename,
            onDelete: onDelete,
          ),
        ),
      ),
    );
  }
}

/// Rename / Delete contextual menu shared by the card and list row.
class _CollectionOverflowMenu extends StatelessWidget {
  final String collectionId;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _CollectionOverflowMenu({
    required this.collectionId,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      child: PopupMenuButton<String>(
        key: Key('collection_menu_$collectionId'),
        icon: PhosphorIcon(
          PhosphorIconsRegular.dotsThreeVertical,
          size: 18,
          color: AppColors.textSecondaryOf(context),
        ),
        color: AppColors.surfaceModalOf(context),
        tooltip: 'Collection actions',
        onSelected: (action) {
          if (action == 'rename') onRename();
          if (action == 'delete') onDelete();
        },
        itemBuilder: (_) => [
          PopupMenuItem<String>(
            value: 'rename',
            child: Row(
              children: [
                PhosphorIcon(
                  PhosphorIconsRegular.pencilSimple,
                  size: 16,
                  color: AppColors.textPrimaryOf(context),
                ),
                const SizedBox(width: 8),
                const Text('Rename'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
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
    );
  }
}
