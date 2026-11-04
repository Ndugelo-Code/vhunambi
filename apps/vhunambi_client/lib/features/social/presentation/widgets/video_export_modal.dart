import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../notifications/domain/models/notification_entity.dart';
import '../../../notifications/domain/models/notification_enums.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../domain/models/video_export_job.dart';
import '../providers/video_export_provider.dart';

/// Native hardware video muxer & direct social syndication rail (REQ-VID-01 … 05).
class VideoExportModal extends ConsumerStatefulWidget {
  final VideoExportJob job;
  const VideoExportModal({super.key, required this.job});

  static Future<void> show(BuildContext context, {required VideoExportJob job}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VideoExportModal(job: job),
    );
  }

  @override
  ConsumerState<VideoExportModal> createState() => _VideoExportModalState();
}

class _VideoExportModalState extends ConsumerState<VideoExportModal> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(videoExportProvider.notifier).prepareJob(widget.job);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(videoExportProvider);
    final notifier = ref.read(videoExportProvider.notifier);
    final job = state.activeJob ?? widget.job;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.surfaceModalOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtleOf(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                PhosphorIcon(PhosphorIconsFill.filmStrip, color: AppColors.brandPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Native Video Muxer',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryOf(context),
                      )),
                ),
                Container(
                  key: const Key('export_badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondaryOf(context),
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(color: AppColors.borderSubtleOf(context)),
                  ),
                  child: Text('1080p ${job.fps} FPS',
                      style: AppTypography.caption.copyWith(color: AppColors.coinGold)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _label(context, 'Resolution'),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final res in VideoExportResolution.values)
                  _ConfigChip(
                    key: Key('res_${res.name}'),
                    label: res.label,
                    isActive: job.resolution == res,
                    onTap: () => notifier.setResolution(res),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _label(context, 'Framerate'),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final fps in [30, 60])
                  _ConfigChip(
                    key: Key('fps_$fps'),
                    label: '$fps FPS',
                    isActive: job.fps == fps,
                    onTap: () => notifier.setFps(fps),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text('Holographic Watermark',
                    style: TextStyle(color: AppColors.textSecondaryOf(context))),
                const Spacer(),
                Switch(
                  key: const Key('watermark_switch'),
                  value: job.includeHolographicWatermark,
                  activeThumbColor: AppColors.brandPrimary,
                  onChanged: notifier.toggleWatermark,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              key: const Key('export_render_btn'),
              onPressed: state.isMuxing
                  ? null
                  : () async {
                      final path = await notifier.startMuxing();
                      if (path != null && mounted) {
                        ref.read(notificationsProvider.notifier).addNotification(
                          NotificationEntity(
                            id: 'notif_vid_render_${DateTime.now().millisecondsSinceEpoch}',
                            title: 'Reel Render Completed',
                            message: 'Master reel "${job.title}" rendered at ${job.resolution.label}.',
                            createdAt: DateTime.now(),
                            category: NotificationCategory.creatorActivity,
                            isRead: false,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                minimumSize: const Size.fromHeight(50),
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.inputBorder),
              ),
              icon: const PhosphorIcon(PhosphorIconsFill.lightning, color: AppColors.brandContrast),
              label: Text(
                state.isMuxing ? 'Muxing…' : 'Render MP4',
                style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.brandContrast, fontWeight: FontWeight.bold),
              ),
            ),
            if (state.isMuxing || state.isCompleted) ...[
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(
                value: state.progress,
                backgroundColor: AppColors.surfaceSecondaryOf(context),
                color: AppColors.brandPrimary,
                minHeight: 8,
                borderRadius: AppRadius.thumbBorder,
              ),
              const SizedBox(height: 4),
              Text('${(state.progress * 100).round()}%',
                  key: const Key('export_progress'),
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondaryOf(context))),
            ],
            if (state.isCompleted) ...[
              const SizedBox(height: AppSpacing.md),
              _SharePanel(state: state),
            ],
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: AppTypography.caption.copyWith(
                color: AppColors.textSecondaryOf(context), fontWeight: FontWeight.w600)),
      );
}

class _ConfigChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _ConfigChip({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.brandPrimary : AppColors.surfaceSecondaryOf(context),
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: isActive ? AppColors.brandPrimary : AppColors.borderSubtleOf(context),
          ),
        ),
        child: Text(label,
            style: AppTypography.caption.copyWith(
              color: isActive ? AppColors.brandContrast : AppColors.textSecondaryOf(context),
              fontWeight: FontWeight.w600,
            )),
      ),
    );
  }
}

class _SharePanel extends ConsumerWidget {
  final VideoExportState state;
  const _SharePanel({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(videoExportProvider.notifier);
    final job = state.activeJob;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondaryOf(context),
            borderRadius: AppRadius.inputBorder,
            border: Border.all(color: AppColors.borderSubtleOf(context)),
          ),
          child: Text(state.generatedCaption ?? '',
              style: AppTypography.caption.copyWith(color: AppColors.textPrimaryOf(context))),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton.icon(
          key: const Key('copy_caption_btn'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: state.generatedCaption ?? ''));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Caption copied to clipboard')),
            );
          },
          icon: PhosphorIcon(PhosphorIconsRegular.copy, size: 16, color: AppColors.textSecondaryOf(context)),
          label: Text('Copy Caption',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimaryOf(context))),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final target in SocialShareTarget.values)
              _ShareButton(
                target: target,
                onTap: () async {
                  final ok = await notifier.shareTo(target);
                  if (ok && context.mounted) {
                    ref.read(notificationsProvider.notifier).addNotification(
                      NotificationEntity(
                        id: 'notif_vid_share_${DateTime.now().millisecondsSinceEpoch}',
                        title: 'Video Export Shared',
                        message: 'Shared "${job?.title ?? "Reel"}" to ${target.label}.',
                        createdAt: DateTime.now(),
                        category: NotificationCategory.creatorActivity,
                        isRead: false,
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Shared to ${target.label}!')),
                    );
                  }
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _ShareButton extends StatelessWidget {
  final SocialShareTarget target;
  final VoidCallback onTap;
  const _ShareButton({required this.target, required this.onTap});

  IconData _iconForTarget(SocialShareTarget target) {
    switch (target) {
      case SocialShareTarget.tiktok:
        return PhosphorIconsFill.tiktokLogo;
      case SocialShareTarget.instagramReels:
        return PhosphorIconsFill.instagramLogo;
      case SocialShareTarget.youtubeShorts:
        return PhosphorIconsFill.youtubeLogo;
      case SocialShareTarget.cameraRoll:
        return PhosphorIconsFill.floppyDisk;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('share_${target.name}_btn'),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondaryOf(context),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtleOf(context)),
            ),
            child: PhosphorIcon(
              _iconForTarget(target),
              size: 22,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(target.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondaryOf(context), fontSize: 9)),
          ),
        ],
      ),
    );
  }
}
