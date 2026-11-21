import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/features/social/domain/models/sovereign_sticker_pack.dart';
import 'package:vhunambi_client/features/social/domain/repositories/i_social_repository.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_repository_provider.dart';

/// Selected rich media attachment returned by [GifStickerPickerSheet].
@immutable
class SelectedCommentMedia {
  final String? gifUrl;
  final String? stickerId;
  final String label;
  final double aspectRatio;

  const SelectedCommentMedia({
    this.gifUrl,
    this.stickerId,
    required this.label,
    this.aspectRatio = 1.33,
  });
}

/// Segmented bottom sheet offering bundled Sovereign Cultural Stickers & live GIF search.
class GifStickerPickerSheet extends ConsumerStatefulWidget {
  const GifStickerPickerSheet({super.key});

  static Future<SelectedCommentMedia?> show(BuildContext context) {
    return showModalBottomSheet<SelectedCommentMedia>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const GifStickerPickerSheet(),
    );
  }

  @override
  ConsumerState<GifStickerPickerSheet> createState() =>
      _GifStickerPickerSheetState();
}

class _GifStickerPickerSheetState extends ConsumerState<GifStickerPickerSheet> {
  int _tabIndex = 0; // 0 = Stickers, 1 = GIFs
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<GifSearchItem> _gifs = const <GifSearchItem>[];
  bool _isLoadingGifs = false;

  @override
  void initState() {
    super.initState();
    _loadGifs('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGifs(String query) async {
    setState(() => _isLoadingGifs = true);
    final repo = ref.read(socialRepositoryProvider);
    final items = query.trim().isEmpty
        ? await repo.getTrendingGifs(limit: 16)
        : await repo.searchGifs(query.trim(), limit: 16);
    if (!mounted) return;
    setState(() {
      _gifs = items;
      _isLoadingGifs = false;
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      _loadGifs(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sheetBg = AppColors.surfaceModalOf(context);
    final border = AppColors.borderSubtleOf(context);

    return Container(
      key: const Key('gif_sticker_picker_sheet'),
      height: MediaQuery.sizeOf(context).height * 0.56,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: border)),
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _SegmentButton(
                    key: const Key('picker_tab_stickers'),
                    label: 'Stickers',
                    icon: PhosphorIconsFill.sticker,
                    selected: _tabIndex == 0,
                    onTap: () => setState(() => _tabIndex = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SegmentButton(
                    key: const Key('picker_tab_gifs'),
                    label: 'GIFs',
                    icon: PhosphorIconsFill.gif,
                    selected: _tabIndex == 1,
                    onTap: () => setState(() => _tabIndex = 1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_tabIndex == 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                10,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondaryOf(context),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: border),
                ),
                child: TextField(
                  key: const Key('gif_search_input'),
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimaryOf(context),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search studio GIFs...',
                    hintStyle: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    prefixIcon: PhosphorIcon(
                      PhosphorIconsRegular.magnifyingGlass,
                      size: 18,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: _tabIndex == 0 ? _buildStickerGrid() : _buildGifGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 4, AppSpacing.lg, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      itemCount: SovereignStickerPack.all.length,
      itemBuilder: (context, index) {
        final sticker = SovereignStickerPack.all[index];
        return GestureDetector(
          key: Key('sticker_option_${sticker.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(
            SelectedCommentMedia(
              stickerId: sticker.id,
              label: sticker.title,
              aspectRatio: 1.33,
            ),
          ),
          child: SovereignStickerGraphic(
            sticker: sticker,
            width: double.infinity,
            height: double.infinity,
          ),
        );
      },
    );
  }

  Widget _buildGifGrid() {
    if (_isLoadingGifs && _gifs.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_gifs.isEmpty) {
      return Center(
        child: Text(
          'No GIFs found. Try Sovereign Stickers!',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondaryOf(context),
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 4, AppSpacing.lg, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.35,
      ),
      itemCount: _gifs.length,
      itemBuilder: (context, index) {
        final item = _gifs[index];
        return GestureDetector(
          key: Key('gif_option_${item.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(
            SelectedCommentMedia(
              gifUrl: item.gifUrl,
              label: item.title,
              aspectRatio: item.aspectRatio,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CachedNetworkImage(
                  imageUrl: item.previewUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => ColoredBox(
                    color: AppColors.surfaceSecondaryOf(context),
                  ),
                  errorWidget: (_, _, _) => ColoredBox(
                    color: AppColors.surfaceSecondaryOf(context),
                    child: Center(
                      child: PhosphorIcon(
                        PhosphorIconsRegular.gif,
                        size: 28,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandPrimary.withValues(alpha: 0.16)
              : AppColors.surfaceSecondaryOf(context),
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: selected
                ? AppColors.brandPrimary.withValues(alpha: 0.45)
                : AppColors.borderSubtleOf(context),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            PhosphorIcon(
              icon,
              size: 16,
              color: selected
                  ? AppColors.brandPrimary
                  : AppColors.textSecondaryOf(context),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.brandPrimary
                    : AppColors.textPrimaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
