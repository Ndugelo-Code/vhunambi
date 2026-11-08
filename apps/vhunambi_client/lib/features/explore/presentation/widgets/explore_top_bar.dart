import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_top_bar_kit.dart';
import '../../../notifications/presentation/views/notifications_view.dart';
import '../../../notifications/presentation/widgets/notification_bell_button.dart';
import '../providers/explore_providers.dart';
import '../views/explore_search_view.dart';
import 'explore_discovery_drawer_sheet.dart';

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
    return VhunambiTopBarSurface(
      toolbarHeight: barHeight,
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
            const VhunambiUserAvatarButton(
              avatarKey: Key('explore_desktop_user_avatar'),
              size: 36,
            ),
            const SizedBox(width: AppSpacing.sm),
            _CreateAction(onPressed: onCreateRequested, compact: false),
          ],
        ),
      ),
    );
  }
}

/// Mobile discovery top bar — 56px minimalist chrome with transient 4s Explore title
/// and direct action triad (Discovery Drawer, Search View, Notifications View).
/// (REQ-EXP-TOPBAR-01..06)
class MobileExploreTopBar extends StatelessWidget {
  static const double barHeight = 56;

  final VoidCallback? onCreateRequested;

  const MobileExploreTopBar({super.key, this.onCreateRequested});

  @override
  Widget build(BuildContext context) {
    return VhunambiTopBarSurface(
      toolbarHeight: barHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Row(
          children: [
            // Root tab: the brand monogram anchors the top-left.
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: AppColors.brandPrimary,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Image.asset(
                  AppAssets.vhunambiGlyph,
                  width: 30,
                  height: 30,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const PhosphorIcon(
                    AppIcons.songs,
                    size: 16,
                    color: AppColors.brandContrast,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'VHUNAMBI',
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const _TransientExploreTitlePill(
                    key: Key('explore_transient_title_pill'),
                  ),
                ],
              ),
            ),

            // Action Triad (REQ-EXP-TOPBAR-05):
            // 1. Discovery Drawer Button
            const _DiscoveryDrawerButton(
              key: Key('explore_open_discovery_drawer_btn'),
            ),

            // 2. Search Icon Button
            const _SearchIconButton(key: Key('explore_open_search_view_btn')),

            // 3. Notifications Bell Button (1-step on mobile)
            const _NotificationBellAction(
              key: Key('explore_open_notifications_btn'),
            ),

            // 4. Compact Profile Avatar Action (Phase 30 REQ-PROF-NAV-02)
            const VhunambiUserAvatarButton(
              avatarKey: Key('explore_mobile_user_avatar_btn'),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

/// Transient 4-second title pill that auto-collapses to reclaim viewport width (REQ-EXP-TOPBAR-03..04).
class _TransientExploreTitlePill extends ConsumerStatefulWidget {
  const _TransientExploreTitlePill({super.key});

  @override
  ConsumerState<_TransientExploreTitlePill> createState() =>
      _TransientExploreTitlePillState();
}

class _TransientExploreTitlePillState
    extends ConsumerState<_TransientExploreTitlePill>
    with SingleTickerProviderStateMixin {
  Timer? _fadeTimer;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _startFadeTimer();
  }

  void _startFadeTimer() {
    _fadeTimer?.cancel();
    _isVisible = true;
    _fadeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(exploreTitlePillVisibleProvider, (previous, next) {
      if (next) {
        _startFadeTimer();
        setState(() {});
      }
    });

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _isVisible ? 1.0 : 0.0,
        curve: Curves.easeInOut,
        child: _isVisible
            ? Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.brandPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Explore',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _DiscoveryDrawerButton extends StatelessWidget {
  const _DiscoveryDrawerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: PhosphorIcon(
          PhosphorIconsRegular.squaresFour,
          color: AppColors.textPrimaryOf(context),
          size: 20,
        ),
        tooltip: 'Discovery Hub',
        onPressed: () => ExploreDiscoveryDrawerSheet.show(context),
      ),
    );
  }
}

class _SearchIconButton extends StatelessWidget {
  const _SearchIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: PhosphorIcon(
          AppIcons.search,
          color: AppColors.textPrimaryOf(context),
          size: 22,
        ),
        tooltip: 'Search',
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ExploreSearchView())),
      ),
    );
  }
}

class _NotificationBellAction extends StatelessWidget {
  const _NotificationBellAction({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: NotificationBellButton(
        color: AppColors.textPrimaryOf(context),
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const NotificationsView()));
        },
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
          child: ClipOval(
            child: Image.asset(
              AppAssets.vhunambiGlyph,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const PhosphorIcon(
                AppIcons.songs,
                size: 20,
                color: AppColors.brandContrast,
              ),
            ),
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
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(exploreSearchQueryProvider),
    );
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    ref.read(exploreSearchQueryProvider.notifier).state = value;
    resetExploreCatalogCursor(ref);
  }

  void _clear() {
    _controller.clear();
    _onChanged('');
    _focusNode.unfocus();
  }

  void _handleShortcut() {
    if (!widget.enableShortcut) return;
    _focusNode.requestFocus();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(exploreSearchQueryProvider);
    if (_controller.text != query) {
      _controller.value = _controller.value.copyWith(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }

    final field = Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.sm),
          PhosphorIcon(
            AppIcons.search,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              key: const Key('explore_search_field'),
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onChanged,
              style: AppTypography.bodyMedium,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (query.isNotEmpty)
            IconButton(
              key: const Key('explore_search_clear_button'),
              icon: const PhosphorIcon(AppIcons.close, size: 16),
              color: AppColors.textSecondary,
              splashRadius: 16,
              onPressed: _clear,
            )
          else if (widget.showShortcutBadge)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.xs),
              child: _ShortcutBadge(),
            ),
        ],
      ),
    );

    if (!widget.enableShortcut) return field;

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
            const _FocusSearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) {
              _handleShortcut();
              return null;
            },
          ),
        },
        child: Focus(canRequestFocus: false, child: field),
      ),
    );
  }
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _ShortcutBadge extends StatelessWidget {
  const _ShortcutBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        'Ctrl + K',
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
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
          const PhosphorIcon(
            AppIcons.lightning,
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
        borderRadius: BorderRadius.circular(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.brandPrimary,
                borderRadius: AppRadius.thumbBorder,
              ),
              child: const PhosphorIcon(
                AppIcons.plus,
                size: 20,
                color: AppColors.brandContrast,
              ),
            ),
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 44),
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: AppColors.brandContrast,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
      ),
      icon: const PhosphorIcon(
        AppIcons.plus,
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
