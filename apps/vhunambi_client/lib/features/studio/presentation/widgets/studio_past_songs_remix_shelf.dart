import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../domain/models/studio_genre_catalog.dart';
import '../providers/studio_form_provider.dart';

/// Past-songs shelf mounted in Compose allowing creators to 1-tap `Remix`
/// any previous vaulted song back into the Studio form (`T80.4.2`).
class StudioPastSongsRemixShelf extends ConsumerWidget {
  final VoidCallback? onRemixSelected;

  const StudioPastSongsRemixShelf({super.key, this.onRemixSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref
        .watch(libraryTracksProvider)
        .where((t) => !t.isDeleted)
        .take(8)
        .toList(growable: false);

    if (tracks.isEmpty) {
      return const SizedBox.shrink();
    }

    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final surfaceSecondary = AppColors.surfaceSecondaryOf(context);
    final borderSubtle = AppColors.borderSubtleOf(context);

    return VhunambiGlassSurface(
      key: const Key('studio_past_songs_remix_shelf'),
      borderRadius: AppRadius.cardBorder,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PhosphorIcon(
                PhosphorIconsFill.clockCounterClockwise,
                size: 18,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Recent Studio Creations',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
              Text(
                '${tracks.length} ready',
                style: AppTypography.caption.copyWith(
                  color: textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 110,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              scrollDirection: Axis.horizontal,
              itemCount: tracks.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final track = tracks[index];
                return Container(
                  width: 210,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: surfaceSecondary.withValues(alpha: 0.72),
                    borderRadius: AppRadius.inputBorder,
                    border: Border.all(color: borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${track.genre} • ${track.language}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          key: Key('past_song_remix_${track.id}'),
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            ref
                                .read(studioFormProvider.notifier)
                                .applyPastTrackRemix(
                                  trackId: track.id,
                                  title: track.title,
                                  genre: track.genre,
                                  region: regionForGenre(track.genre),
                                  language: track.language,
                                  referenceAudioPath:
                                      track.effectiveAudioPath ??
                                      track.remoteAudioUrl,
                                  lyrics: track.lyrics,
                                  isInstrumental: track.isInstrumental,
                                );
                            onRemixSelected?.call();
                          },
                          borderRadius: AppRadius.pillBorder,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 36),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brandPrimary.withValues(
                                alpha: 0.16,
                              ),
                              borderRadius: AppRadius.pillBorder,
                              border: Border.all(color: AppColors.brandPrimary),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const PhosphorIcon(
                                  PhosphorIconsRegular.arrowsClockwise,
                                  size: 13,
                                  color: AppColors.brandPrimary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Remix',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.brandPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
