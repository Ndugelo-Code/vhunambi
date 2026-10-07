import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../notifications/presentation/widgets/notification_bell_button.dart';
import '../providers/explore_providers.dart';

/// Desktop discovery top bar — 68px with breadcrumb, wide search, credit chip,
/// bell, avatar and `+ Create` pill (REQ-EXP-01 / Blueprint 01 §3.1).
class DesktopExploreTopBar extends StatelessWidget {
  static const String searchHint = 'Search songs or artists...';
  static const String creditLabel = '10 songs left';
  static const double barHeight = 68;

  final VoidCallback? onCreateRequested;

  const DesktopExploreTopBar({super.key, this.onCreateRequested});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: barHeight,
      decoration: const BoxDecoration(
        color: AppColors.surfaceCanvas,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              const _BrandGroup(showBreadcrumb: true),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: const _ExploreSearchField(
                      hint: DesktopExploreTopBar.searchHint,
                      showShortcutBadge: true,
                      enableShortcut: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              const _CreditPill(),
              const SizedBox(width: AppSpacing.xs),
              const NotificationBellButton(),
              const SizedBox(width: AppSpacing.xs),
              const _UserAvatar(),
              const SizedBox(width: AppSpacing.sm),
              _CreateAction(onPressed: onCreateRequested, compact: false),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mobile discovery top bar — 56px with back/brand, centered search pill and a
/// compact `+ Create` action (REQ-EXP-01).
class MobileExploreTopBar extends StatelessWidget {
  static const String searchHint = 'Search songs...';
  static const double barHeight = 56;

  final VoidCallback? onCreateRequested;

  const MobileExploreTopBar({super.key, this.onCreateRequested});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: barHeight,
      decoration: const BoxDecoration(
        color: AppColors.surfaceCanvas,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            children: [
              _HeaderIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.brandPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  size: 16,
                  color: AppColors.brandContrast,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Expanded(
                child: _ExploreSearchField(
                  hint: searchHint,
                  showShortcutBadge: false,
                  enableShortcut: false,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _CreateAction(onPressed: onCreateRequested, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandGroup extends StatelessWidget {
  final bool showBreadcrumb;

  const _BrandGroup({required this.showBreadcrumb});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.brandPrimary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.music_note_rounded,
            size: 20,
            color: AppColors.brandContrast,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'VHUNAMBI',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        if (showBreadcrumb) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(
            '/ Explore',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Search pill bound to `exploreSearchQueryProvider`, with an optional
/// `Ctrl + K` keyboard shortcut badge and focus accelerator.
class _ExploreSearchField extends ConsumerStatefulWidget {
  final String hint;
  final bool showShortcutBadge;
  final bool enableShortcut;

  const _ExploreSearchField({
    required this.hint,
    required this.showShortcutBadge,
    required this.enableShortcut,
  });

  @override
  ConsumerState<_ExploreSearchField> createState() =>
      _ExploreSearchFieldState();
}

class _ExploreSearchFieldState extends ConsumerState<_ExploreSearchField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(exploreSearchQueryProvider),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the field in sync when the query is cleared from elsewhere.
    ref.listen(exploreSearchQueryProvider, (previous, next) {
      if (_controller.text != next) {
        _controller.text = next;
      }
    });

    final field = Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            size: 18,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Center(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.search,
                onChanged: (value) {
                  ref.read(exploreSearchQueryProvider.notifier).state = value;
                  resetExploreCatalogCursor(ref);
                },
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
                cursorColor: AppColors.brandPrimary,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: AppTypography.caption,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          if (widget.showShortcutBadge)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: AppRadius.pillBorder,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Text('Ctrl + K', style: AppTypography.caption),
            ),
        ],
      ),
    );

    if (!widget.enableShortcut) return field;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(
          LogicalKeyboardKey.keyK,
          control: true,
        ): () => _focusNode.requestFocus(),
      },
      child: field,
    );
  }
}

class _CreditPill extends StatelessWidget {
  const _CreditPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bolt_rounded,
            size: 15,
            color: AppColors.brandPrimary,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            DesktopExploreTopBar.creditLabel,
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 20,
        tooltip: tooltip,
        icon: Icon(icon, color: AppColors.textSecondary),
        onPressed: onPressed,
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.brandPrimary, width: 1.5),
      ),
      child: const Icon(
        Icons.person_rounded,
        size: 18,
        color: AppColors.brandPrimary,
      ),
    );
  }
}

/// Square compact `+ Create` action (mobile) vs. solid orange pill (desktop).
class _CreateAction extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool compact;

  const _CreateAction({required this.onPressed, required this.compact});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.thumbBorder,
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.brandPrimary,
            borderRadius: AppRadius.thumbBorder,
          ),
          child: const Icon(
            Icons.add_rounded,
            size: 20,
            color: AppColors.brandContrast,
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: AppColors.brandContrast,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.pillBorder,
        ),
      ),
      icon: const Icon(
        Icons.add_rounded,
        size: 16,
        color: AppColors.brandContrast,
      ),
      label: Text(
        'Create',
        style: AppTypography.bodyLarge.copyWith(
          color: AppColors.brandContrast,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
