import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_top_bar_kit.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../domain/models/producer_beat_entity.dart';
import '../beat_format.dart';
import '../providers/beats_provider.dart';
import '../widgets/beat_form_dialog.dart';
import '../widgets/beat_status_badge.dart';
import '../widgets/stem_export_modal.dart';

/// Detailed beat management & royalty cockpit (REQ-BEAT-17).
///
/// Opened from every vault card / tile; reads the live beat from
/// `beatsProvider` so publish toggles and edits are reflected immediately.
class BeatDetailCockpitView extends ConsumerWidget {
  final String beatId;

  const BeatDetailCockpitView({super.key, required this.beatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beat = _beatById(ref.watch(beatsProvider), beatId);
    final playback = ref.watch(playerStateProvider);

    if (beat == null) {
      return Scaffold(
        backgroundColor: AppColors.surfaceCanvas,
        appBar: AppBar(
          backgroundColor: AppColors.surfaceCanvas,
          leading: const VhunambiBackButton(tooltip: 'Back to Vault'),
          title: Text('Beat unavailable', style: AppTypography.titleMedium),
        ),
        body: Center(
          child: Text(
            'This beat is no longer in your vault.',
            style: AppTypography.bodyMuted,
          ),
        ),
      );
    }

    final isAuditioning = isBeatAuditioning(playback, beat);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCanvas,
        elevation: 0,
        leading: VhunambiBackButton(
          key: Key('cockpit_back'),
          tooltip: 'Back to Vault',
          color: AppColors.textPrimary,
        ),
        title: Text(
          beat.title,
          style: AppTypography.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          _CockpitMenu(
            beat: beat,
            onEdit: () => _showEditDialog(context, ref, beat),
            onTogglePublish: () => _togglePublication(context, ref, beat),
            onExportStems: () => _showStemModal(context, ref, beat),
            onDelete: () => _deleteBeat(context, ref, beat),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroSection(
                  beat: beat,
                  isAuditioning: isAuditioning,
                  onAudition: () => _audition(context, ref, beat),
                  onEdit: () => _showEditDialog(context, ref, beat),
                  onExportStems: () => _showStemModal(context, ref, beat),
                ),
                const SizedBox(height: AppSpacing.lg),
                _MarketplaceStatusCard(
                  beat: beat,
                  onTogglePublish: () => _togglePublication(context, ref, beat),
                ),
                const SizedBox(height: AppSpacing.md),
                _StemsCard(
                  beat: beat,
                  onExportStems: () => _showStemModal(context, ref, beat),
                ),
                const SizedBox(height: AppSpacing.md),
                _LedgerCard(beat: beat),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lookup that survives vault refreshes without `package:collection`.
ProducerBeatEntity? _beatById(List<ProducerBeatEntity> beats, String id) {
  for (final beat in beats) {
    if (beat.id == id) return beat;
  }
  return null;
}

/// Plays / pauses the 180s preview and counts the audition (REQ-BEAT-22).
void _audition(BuildContext context, WidgetRef ref, ProducerBeatEntity beat) {
  final playback = ref.read(playerStateProvider);
  if (isBeatAuditioning(playback, beat)) {
    ref.read(playerStateProvider.notifier).pause();
    return;
  }
  auditionBeatPreview(ref, beat);
}

/// One-tap `Publish to Marketplace` / `Switch to Draft` toggle (REQ-BEAT-17).
void _togglePublication(
  BuildContext context,
  WidgetRef ref,
  ProducerBeatEntity beat,
) {
  final notifier = ref.read(beatsProvider.notifier);
  if (beat.isPublished) {
    notifier.unpublishFromMarket(beat.id);
    _showSnack(context, '"${beat.title}" switched back to draft');
    return;
  }

  notifier.publishToMarket(beat.id);
  _showSnack(context, '"${beat.title}" is live on the marketplace');
}

void _showEditDialog(
  BuildContext context,
  WidgetRef ref,
  ProducerBeatEntity beat,
) {
  showDialog<void>(
    context: context,
    builder: (_) => BeatFormDialog(
      initial: beat,
      onSubmitted: (result) {
        ref.read(beatsProvider.notifier).updateBeat(
              beat.copyWith(
                title: result.title,
                genre: result.genre,
                bpm: result.bpm,
                musicalKey: result.musicalKey,
                tags: result.tags,
                priceInCredits: result.priceInCredits,
                licenseTier: result.licenseTier,
                status: result.status,
              ),
            );
      },
    ),
  );
}

void _showStemModal(
  BuildContext context,
  WidgetRef ref,
  ProducerBeatEntity beat,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => StemExportModal(
      beat: beat,
      onAuditionStem: (stem) => _showSnack(context, 'Auditioning $stem stem'),
      onDownloadStem: (stem) =>
          _showSnack(context, '$stem stem queued for download'),
      onDownloadBundle: () => _showSnack(context, 'ZIP manifest queued'),
    ),
  );
}

void _deleteBeat(
  BuildContext context,
  WidgetRef ref,
  ProducerBeatEntity beat,
) {
  ref.read(beatsProvider.notifier).deleteBeat(beat.id);
  _showSnack(context, '"${beat.title}" deleted');
  Navigator.of(context).maybePop();
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: AppTypography.bodyLarge),
      backgroundColor: AppColors.surfaceElevated,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// AppBar overflow actions for the cockpit (REQ-BEAT-17).
class _CockpitMenu extends StatelessWidget {
  final ProducerBeatEntity beat;
  final VoidCallback onEdit;
  final VoidCallback onTogglePublish;
  final VoidCallback onExportStems;
  final VoidCallback onDelete;

  const _CockpitMenu({
    required this.beat,
    required this.onEdit,
    required this.onTogglePublish,
    required this.onExportStems,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: const Key('cockpit_menu'),
      icon: Icon(
        Icons.more_vert_rounded,
        color: AppColors.textPrimary,
      ),
      color: AppColors.surfaceModal,
      tooltip: 'Beat actions',
      onSelected: (action) {
        if (action == 'edit') onEdit();
        if (action == 'publish') onTogglePublish();
        if (action == 'stems') onExportStems();
        if (action == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        const PopupMenuItem<String>(value: 'edit', child: Text('Edit Beat')),
        PopupMenuItem<String>(
          value: 'publish',
          child: Text(
            beat.isPublished ? 'Switch to Draft' : 'Publish to Marketplace',
          ),
        ),
        const PopupMenuItem<String>(
          value: 'stems',
          child: Text('Export Stems Bundle'),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('Delete Beat', style: TextStyle(color: AppColors.error)),
        ),
      ],
    );
  }
}

/// Hero band: 160×160 genre artwork, metadata and the cockpit CTAs
/// (REQ-BEAT-17).
class _HeroSection extends StatelessWidget {
  final ProducerBeatEntity beat;
  final bool isAuditioning;
  final VoidCallback onAudition;
  final VoidCallback onEdit;
  final VoidCallback onExportStems;

  const _HeroSection({
    required this.beat,
    required this.isAuditioning,
    required this.onAudition,
    required this.onEdit,
    required this.onExportStems,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 640;
        final artwork = _GenreArtwork(beat: beat, size: isNarrow ? 132 : 160);

        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              beat.title,
              style: AppTypography.displayMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Producer: ${beat.producerHandle} (${beat.producerName}) • '
              '${beat.createdAgoLabel}',
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Genre: ${beat.genre} • Key: ${beat.keyLabel} • '
              'Tempo: ${beat.bpmLabel}',
              style: AppTypography.bodySmall,
            ),
            if (beat.tags.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xxs,
                runSpacing: AppSpacing.xxs,
                children: [
                  for (final tag in beat.tags) _TagChip(label: tag),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                ElevatedButton.icon(
                  key: const Key('cockpit_audition'),
                  onPressed: onAudition,
                  icon: Icon(
                    isAuditioning
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 16,
                  ),
                  label: Text(
                    isAuditioning ? 'Pause Preview' : 'Audition Preview',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('cockpit_edit'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.borderSubtle),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('cockpit_export_stems'),
                  onPressed: onExportStems,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Export Stems'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.borderSubtle),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '180s preview • ${beat.auditionCount} auditions',
              style: AppTypography.caption,
            ),
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              artwork,
              const SizedBox(height: AppSpacing.md),
              details,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            artwork,
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: details),
          ],
        );
      },
    );
  }
}

/// Squircle genre gradient artwork with the BPM / key badge overlay.
class _GenreArtwork extends StatelessWidget {
  final ProducerBeatEntity beat;
  final double size;

  const _GenreArtwork({required this.beat, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('cockpit_artwork'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: beatGenreGradient(beat.genre),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              Icons.graphic_eq_rounded,
              size: size / 3,
              color: AppColors.textPrimary,
            ),
          ),
          Positioned(
            left: AppSpacing.xs,
            top: AppSpacing.xs,
            child: _ArtworkBadge(label: beat.bpmLabel),
          ),
          Positioned(
            right: AppSpacing.xs,
            bottom: AppSpacing.xs,
            child: _ArtworkBadge(label: beat.keyLabel),
          ),
        ],
      ),
    );
  }
}

class _ArtworkBadge extends StatelessWidget {
  final String label;

  const _ArtworkBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.badgeCyanBg,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: AppColors.badgeCyan),
      ),
      child: Text(
        label,
        style: AppTypography.badge.copyWith(color: AppColors.badgeCyan),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

/// Marketplace listing status card with the one-tap publish toggle
/// (REQ-BEAT-17).
class _MarketplaceStatusCard extends StatelessWidget {
  final ProducerBeatEntity beat;
  final VoidCallback onTogglePublish;

  const _MarketplaceStatusCard({
    required this.beat,
    required this.onTogglePublish,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.storefront_rounded,
      title: 'MARKETPLACE LISTING STATUS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              BeatStatusBadge(status: beat.status),
              ElevatedButton(
                key: const Key('cockpit_publish_toggle'),
                onPressed: onTogglePublish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: beat.isPublished
                      ? AppColors.surfaceSecondary
                      : AppColors.brandPrimary,
                  foregroundColor: beat.isPublished
                      ? AppColors.textPrimary
                      : AppColors.brandContrast,
                  side: BorderSide(color: AppColors.borderSubtle),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
                child: Text(
                  beat.isPublished ? 'Switch to Draft' : 'Publish to Marketplace',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatusRow(label: 'Price', value: beat.priceLabel),
          _StatusRow(label: 'License Tier', value: beat.licenseTier.label),
          _StatusRow(label: 'Total Sales', value: '${beat.totalSales}'),
          _StatusRow(
            label: 'Royalties Earned',
            value: '⚡ ${beat.totalEarningsCredits} Credits',
          ),
          _StatusRow(
            label: 'Audition Previews',
            value: '${beat.auditionCount}',
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label, style: AppTypography.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Four-stem availability card with the bundle export CTA (REQ-BEAT-17).
class _StemsCard extends StatelessWidget {
  final ProducerBeatEntity beat;
  final VoidCallback onExportStems;

  const _StemsCard({required this.beat, required this.onExportStems});

  bool _isReady(String? url) => url != null && url.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final stems = beat.stemPackage;

    return _SectionCard(
      icon: Icons.graphic_eq_rounded,
      title: 'STEMS PACKAGE (${stems.stemCount}/4)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _StemChip(
                slug: 'drums',
                label: 'Drums',
                icon: Icons.album_rounded,
                isReady: _isReady(stems.drumsUrl),
              ),
              _StemChip(
                slug: 'bass',
                label: 'Bass',
                icon: Icons.graphic_eq_rounded,
                isReady: _isReady(stems.bassUrl),
              ),
              _StemChip(
                slug: 'melody',
                label: 'Melody',
                icon: Icons.piano_rounded,
                isReady: _isReady(stems.melodyUrl),
              ),
              _StemChip(
                slug: 'other',
                label: 'Other',
                icon: Icons.auto_awesome_rounded,
                isReady: _isReady(stems.otherUrl),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            key: const Key('cockpit_export_stems_cta'),
            onPressed: onExportStems,
            icon: const Icon(Icons.folder_zip_rounded, size: 16),
            label: const Text('Export Stems Bundle (ZIP)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandPrimary,
              side: BorderSide(color: AppColors.borderSubtle),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.pillBorder,
              ),
            ),
          ),
          if (!stems.hasAllStems) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Run the Stem Separation Lab to unlock the complete 4-stem bundle.',
              style: AppTypography.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _StemChip extends StatelessWidget {
  final String slug;
  final String label;
  final IconData icon;
  final bool isReady;

  const _StemChip({
    required this.slug,
    required this.label,
    required this.icon,
    required this.isReady,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isReady ? AppColors.success : AppColors.textTertiary;

    return Container(
      key: Key('stem_indicator_$slug'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: accent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            '$label: ${isReady ? 'Ready' : 'Missing'}',
            style: AppTypography.bodySmall.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}

/// Chronological royalty ledger of completed license purchases (REQ-BEAT-17).
class _LedgerCard extends StatelessWidget {
  final ProducerBeatEntity beat;

  const _LedgerCard({required this.beat});

  @override
  Widget build(BuildContext context) {
    final records = beat.salesRecords.reversed.toList(growable: false);

    return _SectionCard(
      icon: Icons.receipt_long_rounded,
      title: 'RECENT LICENSE TRANSACTIONS (${beat.totalSales})',
      child: records.isEmpty
          ? Text(
              'No licenses yet — publish this beat and every license will land '
              'here with its buyer handle and credit royalty.',
              style: AppTypography.bodyMuted,
            )
          : Column(
              children: [
                for (final sale in records) _SaleRow(sale: sale),
              ],
            ),
    );
  }
}

class _SaleRow extends StatelessWidget {
  final BeatSaleRecord sale;

  const _SaleRow({required this.sale});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key('sale_row_${sale.saleId}'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(sale.dateLabel, style: AppTypography.caption),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Licensed by ${sale.buyerHandle}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  sale.licenseTier.label,
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            sale.creditsLabel,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.coinGold,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Elevated card shell shared by the cockpit sections.
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.brandPrimary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.badge.copyWith(
                    color: AppColors.brandPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}
