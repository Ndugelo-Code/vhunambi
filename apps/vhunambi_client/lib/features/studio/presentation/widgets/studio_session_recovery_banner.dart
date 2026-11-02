import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../notifications/presentation/utils/time_ago_utils.dart';
import '../providers/studio_session_provider.dart';
import '../utils/studio_haptics.dart';

/// Ghost Session recovery banner rendered at the top of the Studio Compose
/// tab (M10 / REQ-SES-03, REQ-SES-04).
///
/// Shows an unobtrusive "Unfinished session" card with a human-readable
/// time elapsed, a 1-tap [Restore] and [Start Fresh] pair, and an `×`
/// dismissal — all with 44×44px ergonomics.
class StudioSessionRecoveryBanner extends ConsumerWidget {
  const StudioSessionRecoveryBanner({super.key});

  String _promptExcerpt(String prompt) {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return 'Untitled draft';
    if (trimmed.length <= 40) return trimmed;
    return '${trimmed.substring(0, 40)}…';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(studioSessionProvider);
    final notifier = ref.read(studioSessionProvider.notifier);
    final draft = session.savedDraft;

    if (session.recoveryState != SessionRecoveryState.available ||
        draft == null) {
      return const SizedBox.shrink();
    }

    return Container(
      key: const Key('studio_session_recovery_banner'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withAlpha(15),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.accentGold),
      ),
      child: Row(
        children: [
          const Text('↩', style: TextStyle(fontSize: 16)),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Unfinished session: "${_promptExcerpt(draft.prompt)}" '
                  '(${TimeAgoUtils.format(draft.savedAt)})',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${draft.genre} • ${draft.language}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Dual keys: handoff guide (`session_restore_btn`) and tasks.md
          // (`studio_session_resume_btn`) both address this control.
          KeyedSubtree(
            key: const Key('studio_session_resume_btn'),
            child: ElevatedButton(
              key: const Key('session_restore_btn'),
              onPressed: () {
                unawaited(StudioHaptics.successPulse());
                notifier.resumeSession(draft);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.brandContrast,
                minimumSize: const Size(72, 44),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
              child: Text(
                'Restore',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.brandContrast,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          KeyedSubtree(
            key: const Key('studio_session_start_fresh_btn'),
            child: TextButton(
              key: const Key('session_discard_btn'),
              onPressed: () {
                unawaited(StudioHaptics.chipSnap());
                notifier.clearSession();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                minimumSize: const Size(64, 44),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              ),
              child: Text(
                'Start Fresh',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          IconButton(
            key: const Key('studio_session_dismiss_banner'),
            tooltip: 'Dismiss',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: notifier.dismissRecovery,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}