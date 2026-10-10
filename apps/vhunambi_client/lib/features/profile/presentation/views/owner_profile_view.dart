import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../shared/models/track.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../domain/models/profile_models.dart';
import '../providers/profile_providers.dart';
import '../widgets/profile_referral_card.dart';
import '../widgets/releases_manager_card.dart';
import '../widgets/tip_history_ledger.dart';
import '../../../social/presentation/providers/creator_clips_provider.dart';
import '../../../social/presentation/widgets/creator_reel_thumbnail_card.dart';
import '../../../social/presentation/widgets/kinetic_reels_modal.dart';

/// Account Owner Creator Studio Profile View (`/profile/me`) (REQ-TRK-15, REQ-TRK-16).
class OwnerProfileView extends ConsumerStatefulWidget {
  const OwnerProfileView({super.key});

  @override
  ConsumerState<OwnerProfileView> createState() => _OwnerProfileViewState();
}

class _OwnerProfileViewState extends ConsumerState<OwnerProfileView> {
  // Track visibility map (trackId -> isPublic)
  final Map<String, bool> _trackVisibility = {
    'track_own_01': true,
    'track_own_02': true,
  };

  void _showNewReleaseDialog() {
    final titleController = TextEditingController();
    ReleaseType selectedType = ReleaseType.single;
    String selectedGenre = 'House';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceModal,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
              title: Text(
                'Create New Release',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    style: AppTypography.bodySmall,
                    decoration: const InputDecoration(
                      labelText: 'Release Title',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.borderSubtle),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Release Type', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Row(
                    children: ReleaseType.values.map((type) {
                      final isSelected = type == selectedType;
                      final label = switch (type) {
                        ReleaseType.single => 'Single',
                        ReleaseType.ep => 'EP',
                        ReleaseType.album => 'Album',
                      };
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          selectedColor: AppColors.brandPrimary,
                          backgroundColor: AppColors.surfaceElevated,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.brandContrast : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) setDialogState(() => selectedType = type);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBorder),
                  ),
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isNotEmpty) {
                      ref.read(ownerProfileProvider.notifier).addRelease(
                            MusicReleaseEntity(
                              id: 'rel_${DateTime.now().millisecondsSinceEpoch}',
                              title: title,
                              releaseType: selectedType,
                              trackCount: selectedType == ReleaseType.single ? 1 : 4,
                              releaseDate: DateTime.now(),
                              genre: selectedGenre,
                            ),
                          );
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Release "$title" created! 💿')),
                      );
                    }
                  },
                  child: const Text('Create Release'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final profile = ref.watch(ownerProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.music_note_rounded,
              color: AppColors.brandPrimary,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              'CREATOR STUDIO',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 16,
                vertical: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Owner Profile Scaffolding Row
                  Row(
                    children: [
                      // Monogram Circle
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.borderSubtle, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            profile.monogram,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandContrast,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.displayName,
                              style: AppTypography.titleLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${profile.username} • Verified Creator',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 2. Management Action Strip
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildActionPill(
                        icon: Icons.edit_rounded,
                        label: 'Edit Profile',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Opening Profile Editor...')),
                          );
                        },
                      ),
                      _buildActionPill(
                        icon: Icons.push_pin_rounded,
                        label: 'Pin Song',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Select a song to pin to top')),
                          );
                        },
                      ),
                      _buildActionPill(
                        icon: Icons.analytics_outlined,
                        label: 'Studio Analytics',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Opening Analytics Console...')),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 3. Top Genres Analytics Chips
                  Text(
                    'TOP GENRES',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildGenreChip('🎵 House', '1'),
                      _buildGenreChip('🎹 Amapiano', '4'),
                      _buildGenreChip('🎸 Maskandi', '2'),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 4. Your Songs Shelf with Public/Private Visibility Switch
                  Row(
                    children: [
                      Text(
                        'Your Songs',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${profile.songCount} total',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildOwnerTrackTile(
                    trackId: 'track_own_01',
                    rank: 1,
                    title: 'ZaYN',
                    genre: 'House',
                    duration: '3:20',
                    plays: 4,
                    likes: 0,
                  ),
                  const SizedBox(height: 10),
                  _buildOwnerTrackTile(
                    trackId: 'track_own_02',
                    rank: 2,
                    title: 'Ndo Mufuna Matibe',
                    genre: 'Amapiano',
                    duration: '3:18',
                    plays: 12,
                    likes: 3,
                  ),

                  const SizedBox(height: 14),

                  // 4b. My Clips & Reels (Phase 18 · REQ-SOC-07)
                  const _OwnerReelsShelf(),

                  const SizedBox(height: 14),

                  // 5. Discography Releases Manager
                  ReleasesManagerCard(
                    releases: profile.releases,
                    onNewRelease: _showNewReleaseDialog,
                  ),

                  // 6. Tip History Ledger
                  TipHistoryLedger(
                    tipHistory: profile.tipHistory,
                    tipsEnabled: profile.tipsEnabled,
                    onToggleTips: (val) {
                      ref.read(ownerProfileProvider.notifier).toggleTipsEnabled();
                    },
                  ),

                  // 7. Profile Referral Link Card
                  ProfileReferralCard(username: profile.username),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.brandPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreChip(String label, String count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        '$label ($count)',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildOwnerTrackTile({
    required String trackId,
    required int rank,
    required String title,
    required String genre,
    required String duration,
    required int plays,
    required int likes,
  }) {
    final isPublic = _trackVisibility[trackId] ?? true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Text(
            '[$rank]',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppGradients.forGenre(genre),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '$genre • $duration • ▶ $plays • ❤️ $likes',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Inline Public / Private Visibility Switch
          InkWell(
            onTap: () {
              setState(() {
                _trackVisibility[trackId] = !isPublic;
              });
            },
            borderRadius: AppRadius.pillBorder,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isPublic
                    ? const Color(0xFF10B981).withAlpha(20)
                    : AppColors.surfaceSecondary,
                borderRadius: AppRadius.pillBorder,
                border: Border.all(
                  color: isPublic
                      ? const Color(0xFF10B981)
                      : AppColors.borderSubtle,
                ),
              ),
              child: Text(
                isPublic ? '🌐 Public' : '🔒 Private',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isPublic ? const Color(0xFF34D399) : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            iconSize: 24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.play_circle_fill_rounded,
              color: AppColors.brandPrimary,
            ),
            onPressed: () {
              ref.read(playerStateProvider.notifier).playTrack(
                    Track(
                      id: trackId,
                      title: title,
                      creatorName: 'cern',
                      genre: genre,
                      duration: const Duration(minutes: 3, seconds: 20),
                    ),
                  );
            },
          ),
        ],
      ),
    );
  }
}

/// Horizontal shelf of the owner's published clips & reels (Phase 18).
class _OwnerReelsShelf extends ConsumerWidget {
  const _OwnerReelsShelf();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clips = ref.watch(creatorClipsFamilyProvider('creator_me'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.movie_filter_rounded,
                color: AppColors.brandPrimary, size: 18),
            const SizedBox(width: 8),
            Text('My Clips & Reels',
                style: AppTypography.titleMedium
                    .copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${clips.length}',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (clips.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: AppRadius.cardBorder,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Text(
              'Publish a reel from the Content Studio to feature it here.',
              style: AppTypography.bodyMuted,
            ),
          )
        else
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: clips.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final clip = clips[i];
                return SizedBox(
                  width: 96,
                  child: CreatorReelThumbnailCard(
                    clip: clip,
                    onTap: () => KineticReelsModal.show(
                      context,
                      clips: clips,
                      initialClipId: clip.id,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
