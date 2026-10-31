import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_assets.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/widgets/vhunambi_top_bar_kit.dart';
import '../../../notifications/presentation/widgets/notification_bell_button.dart';
import '../../../offline/presentation/widgets/vault_storage_modal.dart';
import '../../domain/models/library_models.dart';
import '../providers/library_providers.dart';

/// Responsive vault header (REQ-LIB-01 / Blueprint 04 §1.1).
///
/// Mobile (< 768px): brand emblem, credit chip, notification bell, overflow
/// menu, and a square create action.
/// Desktop (> 1024px): back chevron, brand emblem, centred breadcrumb, credit
/// chip, bell, analytics action, overflow menu, and the Create pill.
class LibraryAppBar extends ConsumerWidget {
  static const String creditBalanceLabel = '10 songs left';

  final VoidCallback? onCreateRequested;

  const LibraryAppBar({super.key, this.onCreateRequested});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    // Root tab: no back chevron on either breakpoint (Library is an
    // IndexedStack sibling, never pushed). Geometry is inset-aware so the row
    // never squishes on notched devices.
    return VhunambiTopBarSurface(
      toolbarHeight: isDesktop ? 64 : 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: isDesktop ? _desktopRow(context) : _mobileRow(context),
      ),
    );
  }

  Widget _desktopRow(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _brandGroup(context, showBackChevron: false)),
        Text('My Library', style: AppTypography.bodyMuted),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _CreditBalancePill(),
                  const SizedBox(width: AppSpacing.xs),
                  const NotificationBellButton(),
                  const SizedBox(width: AppSpacing.xxs),
                  const _AnalyticsButton(),
                  const SizedBox(width: AppSpacing.xxs),
                  _HeaderIconButton(
                    icon: PhosphorIconsRegular.hardDrives,
                    tooltip: 'Vault Storage Quota',
                    onPressed: () => VaultStorageModal.show(context),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  const _OverflowMenu(),
                  const SizedBox(width: AppSpacing.xs),
                  _CreateButton(onPressed: onCreateRequested, isCompact: false),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mobileRow(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _brandGroup(context, showBackChevron: false)),
        const _CreditBalancePill(),
        const SizedBox(width: AppSpacing.xxs),
        const NotificationBellButton(),
        const SizedBox(width: AppSpacing.xxs),
        const _OverflowMenu(),
        const SizedBox(width: AppSpacing.xs),
        _CreateButton(onPressed: onCreateRequested, isCompact: true),
      ],
    );
  }

  Widget _brandGroup(BuildContext context, {required bool showBackChevron}) {
    return Row(
      children: [
        if (showBackChevron) ...[
          VhunambiBackButton(
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: AppSpacing.xxs),
        ],
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: AppColors.brandPrimary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: ClipOval(
            child: Image.asset(
              AppAssets.vhunambiGlyph,
              width: 30,
              height: 30,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const PhosphorIcon(
                AppIcons.songs,
                size: 18,
                color: AppColors.brandContrast,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            'VHUNAMBI',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// `⚡ 10 songs left` credit token chip.
class _CreditBalancePill extends StatelessWidget {
  const _CreditBalancePill();

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
            LibraryAppBar.creditBalanceLabel,
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
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

/// Square mobile create action vs. solid orange desktop Create pill.
class _CreateButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isCompact;

  const _CreateButton({required this.onPressed, required this.isCompact});

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
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
              child: const Icon(
                Icons.auto_awesome,
                size: 18,
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
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.pillBorder,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),
      icon: const Icon(
        Icons.auto_awesome,
        size: 16,
        color: AppColors.brandContrast,
      ),
      label: Text(
        'Create',
        style: AppTypography.bodyLarge.copyWith(
          color: AppColors.brandContrast,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// `📊 Analytics` vault summary action (desktop header only).
class _AnalyticsButton extends ConsumerWidget {
  const _AnalyticsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => _showVaultAnalytics(context, ref),
      borderRadius: AppRadius.pillBorder,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.analytics_outlined,
              size: 15,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              'Analytics',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header overflow control (`⋮`) exposing the vault ordering options and tools.
class _OverflowMenu extends ConsumerWidget {
  const _OverflowMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOrder = ref.watch(librarySortProvider);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      child: PopupMenuButton<Object>(
        padding: EdgeInsets.zero,
        iconSize: 20,
        tooltip: 'Library options',
        color: AppColors.surfaceModal,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.inputBorder,
          side: BorderSide(color: AppColors.borderSubtle),
        ),
        icon: const Icon(
          Icons.more_vert_rounded,
          color: AppColors.textSecondary,
        ),
        onSelected: (value) {
          if (value is LibrarySortOrder) {
            ref.read(librarySortProvider.notifier).state = value;
          } else if (value == 'storage') {
            VaultStorageModal.show(context);
          } else if (value == 'analytics') {
            _showVaultAnalytics(context, ref);
          }
        },
        itemBuilder: (context) => [
          for (final order in LibrarySortOrder.values)
            PopupMenuItem<Object>(
              value: order,
              height: 40,
              child: Row(
                children: [
                  Icon(
                    _sortIcon(order),
                    size: 16,
                    color: order == activeOrder
                        ? AppColors.brandPrimary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      _sortLabel(order),
                      style: AppTypography.bodySmall.copyWith(
                        color: order == activeOrder
                            ? AppColors.brandPrimary
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (order == activeOrder)
                    const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: AppColors.brandPrimary,
                    ),
                ],
              ),
            ),
          const PopupMenuDivider(),
          PopupMenuItem<Object>(
            value: 'storage',
            height: 40,
            child: Row(
              children: [
                const Icon(
                  Icons.storage_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Vault Storage Quota',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<Object>(
            value: 'analytics',
            height: 40,
            child: Row(
              children: [
                const Icon(
                  Icons.analytics_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Vault Analytics',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _sortIcon(LibrarySortOrder order) => switch (order) {
        LibrarySortOrder.newestFirst => PhosphorIconsRegular.clock,
        LibrarySortOrder.oldestFirst => PhosphorIconsRegular.clockCounterClockwise,
        LibrarySortOrder.titleAscending => AppIcons.sort,
        LibrarySortOrder.mostPlayed => AppIcons.flame,
      };

  static String _sortLabel(LibrarySortOrder order) => switch (order) {
        LibrarySortOrder.newestFirst => 'Newest first',
        LibrarySortOrder.oldestFirst => 'Oldest first',
        LibrarySortOrder.titleAscending => 'Title A–Z',
        LibrarySortOrder.mostPlayed => 'Most played',
      };
}

void _showVaultAnalytics(BuildContext context, WidgetRef ref) {
  final tracks = ref.read(libraryTracksProvider);
  final offlineCount = tracks.where((track) => track.isOfflineAvailable).length;
  final totalSeconds =
      tracks.fold<int>(0, (sum, track) => sum + track.durationSeconds);
  final runtime =
      '${totalSeconds ~/ 60}m ${(totalSeconds % 60).toString().padLeft(2, '0')}s';

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppColors.surfaceModal,
      duration: const Duration(seconds: 4),
      content: Text(
        'Vault analytics — ${tracks.length} assets • $offlineCount offline • $runtime of audio.',
        style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
      ),
    ),
  );
}

