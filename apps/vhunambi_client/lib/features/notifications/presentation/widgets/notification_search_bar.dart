import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/notifications_provider.dart';

/// Search field for the Notifications Center with an animated focus glow,
/// a leading search glyph, and a 44×44px clear affordance.
///
/// Binds bidirectionally to [searchQueryProvider].
class NotificationSearchBar extends ConsumerStatefulWidget {
  const NotificationSearchBar({super.key});

  @override
  ConsumerState<NotificationSearchBar> createState() =>
      _NotificationSearchBarState();
}

class _NotificationSearchBarState
    extends ConsumerState<NotificationSearchBar> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(searchQueryProvider),
    );
    _focusNode.addListener(() {
      if (mounted) setState(() => _hasFocus = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    ref.read(searchQueryProvider.notifier).state = value;
    setState(() {});
  }

  void _clear() {
    _controller.clear();
    _onChanged('');
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: AppRadius.inputBorder,
          border: Border.all(
            color: _hasFocus
                ? AppColors.brandPrimary.withValues(alpha: 0.35)
                : AppColors.borderSubtle,
            width: _hasFocus ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.search_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: TextField(
                key: const Key('notification_search_field'),
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
                cursorColor: AppColors.brandPrimary,
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  hintText: 'Search alerts...',
                  hintStyle: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  key: const Key('notification_search_clear'),
                  onPressed: _clear,
                  splashRadius: 22,
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
