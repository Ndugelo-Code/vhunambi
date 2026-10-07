import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../notifications/presentation/widgets/notification_bell_button.dart';
import '../providers/marketplace_providers.dart';

/// Responsive marketplace top bar: back chevron, brand emblem, centered search
/// pill, credit balance chip and notification bell (REQ-MKT-01).
class MarketplaceTopBar extends StatelessWidget {
  static const String searchHint = 'Search beats or producers...';
  static const double desktopHeight = 68;
  static const double mobileHeight = 56;

  const MarketplaceTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 1024;

    return Container(
      height: isDesktop ? desktopHeight : mobileHeight,
      decoration: const BoxDecoration(
        color: AppColors.surfaceCanvas,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? AppSpacing.md : AppSpacing.sm,
          ),
          child: Row(
            children: [
              _TopBarIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.brandPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  size: 18,
                  color: AppColors.brandContrast,
                ),
              ),
              if (isDesktop) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'VHUNAMBI',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: const _MarketplaceSearchField(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const _CreditChip(),
              const SizedBox(width: AppSpacing.xxs),
              const NotificationBellButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketplaceSearchField extends ConsumerStatefulWidget {
  const _MarketplaceSearchField();

  @override
  ConsumerState<_MarketplaceSearchField> createState() =>
      _MarketplaceSearchFieldState();
}

class _MarketplaceSearchFieldState
    extends ConsumerState<_MarketplaceSearchField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(marketplaceFilterProvider).searchQuery,
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
    // Keep the field in sync when the search query is cleared elsewhere.
    ref.listen(marketplaceFilterProvider, (previous, next) {
      if (_controller.text != next.searchQuery) {
        _controller.text = next.searchQuery;
      }
    });

    return Container(
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
                  final current = ref.read(marketplaceFilterProvider);
                  ref.read(marketplaceFilterProvider.notifier).state =
                      current.copyWith(searchQuery: value);
                },
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
                cursorColor: AppColors.brandPrimary,
                decoration: InputDecoration(
                  hintText: MarketplaceTopBar.searchHint,
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
        ],
      ),
    );
  }
}

/// `⚡ 10 songs left` credit balance chip driven by the credits provider.
class _CreditChip extends ConsumerWidget {
  const _CreditChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credits = ref.watch(marketplaceCreditsProvider);

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
            '$credits songs left',
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

class _TopBarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _TopBarIconButton({
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
