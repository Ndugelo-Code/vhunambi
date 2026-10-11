import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/published_clip.dart';
import '../providers/social_feed_provider.dart';
import '../providers/stem_remix_provider.dart';
import '../../../studio/presentation/providers/studio_form_provider.dart';
import '../../../player/presentation/widgets/stem_mixer_deck.dart';
import 'reels_comment_sheet.dart';
import 'creator_tipping_sheet.dart';
import 'remix_attribution_badge.dart';

/// Full-screen vertical "Kinetic Reels" feed (REQ-SOC-11).
///
/// Zero-video: each page renders the clip's Song DNA (cover + metadata) rather
/// than an MP4 (REQ-SOC-26). This is the T4 tap target; T5 layers in the
/// synchronized `KineticPreviewCanvas`, audio streaming, the recycled
/// controller pool, and the viral "Remix in Studio" sound loop.
class KineticReelsModal extends ConsumerStatefulWidget {
  final List<PublishedClip> clips;
  final int initialIndex;

  const KineticReelsModal({
    super.key,
    required this.clips,
    this.initialIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required List<PublishedClip> clips,
    String? initialClipId,
  }) {
    var idx = 0;
    if (initialClipId != null) {
      final found = clips.indexWhere((c) => c.id == initialClipId);
      if (found >= 0) idx = found;
    }
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => KineticReelsModal(clips: clips, initialIndex: idx),
      ),
    );
  }

  @override
  ConsumerState<KineticReelsModal> createState() => _KineticReelsModalState();
}

class _KineticReelsModalState extends ConsumerState<KineticReelsModal> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _share(PublishedClip clip) {
    Clipboard.setData(ClipboardData(text: clip.shareUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Share link copied: ${clip.shareUrl}'),
        backgroundColor: AppColors.brandPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.clips.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.surfaceCanvas,
        body: Center(child: Text('No clips to show yet')),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemCount: widget.clips.length,
        itemBuilder: (context, i) {
          final clip = widget.clips[i];
          return _ReelPage(
            clip: clip,
            isActive: i == _currentIndex,
            onShare: () => _share(clip),
          );
        },
      ),
    );
  }
}


class _ReelPage extends ConsumerStatefulWidget {
  final PublishedClip clip;
  final bool isActive;
  final VoidCallback onShare;

  const _ReelPage({
    required this.clip,
    required this.isActive,
    required this.onShare,
  });

  @override
  ConsumerState<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends ConsumerState<_ReelPage>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = true;
  late final AnimationController _heartAnimController;
  late final Animation<double> _heartScale;
  late final Animation<double> _heartOpacity;
  bool _showBurstHeart = false;
  String _burstEmoji = '❤️';

  @override
  void initState() {
    super.initState();
    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.2, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.35, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_heartAnimController);

    _heartOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 45),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_heartAnimController);

    _heartAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) setState(() => _showBurstHeart = false);
      }
    });
  }

  @override
  void dispose() {
    _heartAnimController.dispose();
    super.dispose();
  }

  void _triggerBurst({String emoji = '❤️'}) {
    HapticFeedback.mediumImpact();
    setState(() {
      _showBurstHeart = true;
      _burstEmoji = emoji;
    });
    _heartAnimController.forward(from: 0.0);
  }

  void _handleDoubleTap(PublishedClip clip) {
    _triggerBurst(emoji: '❤️');
    ref.read(socialFeedProvider.notifier).recordLove(clip.id);
  }

  void _togglePlay() => setState(() => _isPlaying = !_isPlaying);

  void _remixInStudio(PublishedClip clip) {
    HapticFeedback.mediumImpact();
    ref.read(studioFormProvider.notifier).setGenre(clip.genre);
    ref.read(studioFormProvider.notifier).updatePrompt(
          'Remix inspired by ${clip.title} by ${clip.creatorDisplayName}',
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded sound into Studio: ${clip.title} 🎵'),
        backgroundColor: AppColors.brandPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reactively resolve the live clip so like counts update instantly.
    final clip = ref
        .watch(socialFeedProvider)
        .clips
        .firstWhere((c) => c.id == widget.clip.id, orElse: () => widget.clip);

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(gradient: AppGradients.forGenre(clip.genre)),
        ),
        if (clip.coverUrl.isNotEmpty)
          Image.network(clip.coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink()),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black87],
              stops: [0.4, 1.0],
            ),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePlay,
          onDoubleTap: () => _handleDoubleTap(clip),
          child: Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isPlaying ? 0.0 : 1.0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceCanvas,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: AppColors.brandPrimary, size: 44),
              ),
            ),
          ),
        ),
        if (_showBurstHeart)
          IgnorePointer(
            child: Center(
              child: AnimatedBuilder(
                animation: _heartAnimController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _heartOpacity.value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: _heartScale.value,
                      child: _burstEmoji == '❤️'
                          ? const Icon(
                              Icons.favorite_rounded,
                              color: AppColors.brandPrimary,
                              size: 110,
                            )
                          : Text(
                              _burstEmoji,
                              style: const TextStyle(fontSize: 88),
                            ),
                    ),
                  );
                },
              ),
            ),
          ),
        Positioned(
          right: 12,
          bottom: 120,
          child: _ActionRail(
            clip: clip,
            onShare: widget.onShare,
            onBurst: (emoji) => _triggerBurst(emoji: emoji),
          ),
        ),
        Positioned(
          left: 16,
          right: 76,
          bottom: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text('@${clip.creatorUsername}',
                      style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold)),
                  if (clip.isCreatorVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded,
                        color: AppColors.brandPrimary, size: 16),
                  ],
                ],
              ),
              if (clip.isRemix) ...[
                const SizedBox(height: 6),
                RemixAttributionBadge(clip: clip),
              ],
              const SizedBox(height: 6),
              if (clip.caption.isNotEmpty)
                Text(clip.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall),
              const SizedBox(height: 10),
              _SoundPill(
                title: clip.title,
                artist: clip.creatorDisplayName,
                onRemix: () => _remixInStudio(clip),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionRail extends StatefulWidget {
  final PublishedClip clip;
  final VoidCallback onShare;
  final ValueChanged<String> onBurst;

  const _ActionRail({
    required this.clip,
    required this.onShare,
    required this.onBurst,
  });

  @override
  State<_ActionRail> createState() => _ActionRailState();
}

class _ActionRailState extends State<_ActionRail> {
  bool _showReactions = false;
  static const List<String> _culturalEmojis = ['🔥', '👑', '🇿🇦', '🎹', '❤️'];

  void _recordLove(BuildContext context, WidgetRef ref, {String emoji = '❤️'}) {
    HapticFeedback.mediumImpact();
    widget.onBurst(emoji);
    final count = ref.read(socialFeedProvider.notifier).recordLove(widget.clip.id);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        key: ValueKey('love_toast_${widget.clip.id}'),
        content: Text('Loved ${count}x! $emoji'),
        backgroundColor: AppColors.brandPrimary,
        duration: const Duration(milliseconds: 900),
      ),
    );
    if (_showReactions) {
      setState(() => _showReactions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final clip = widget.clip;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showReactions)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceModal.withAlpha(220),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final emoji in _culturalEmojis)
                      InkWell(
                        key: ValueKey('burst_emoji_$emoji'),
                        onTap: () => _recordLove(context, ref, emoji: emoji),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(emoji, style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                  ],
                ),
              ),
            _RailButton(
              key: const Key('reel_like_btn'),
              icon: clip.isLikedByMe
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: clip.isLikedByMe ? AppColors.brandPrimary : AppColors.textPrimary,
              label: formatLikes(clip.likeCount),
              onTap: () => _recordLove(context, ref),
              onLongPress: () {
                HapticFeedback.selectionClick();
                setState(() => _showReactions = !_showReactions);
              },
            ),
            const SizedBox(height: 18),
            _RailButton(
              key: const Key('reel_comment_btn'),
              icon: Icons.mode_comment_outlined,
              color: AppColors.textPrimary,
              label: '${clip.commentCount}',
              onTap: () {
                HapticFeedback.selectionClick();
                ReelsCommentSheet.show(context, clip: clip);
              },
            ),
            const SizedBox(height: 18),
            _RailButton(
              key: const Key('reel_tip_btn'),
              icon: Icons.monetization_on_rounded,
              color: AppColors.coinGold,
              label: 'Tip',
              onTap: () {
                HapticFeedback.selectionClick();
                CreatorTippingSheet.show(context, clip: clip);
              },
            ),
            const SizedBox(height: 18),
            _RailButton(
              key: const Key('reel_share_btn'),
              icon: Icons.reply_rounded,
              color: AppColors.textPrimary,
              label: 'Share',
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onShare();
              },
            ),
            const SizedBox(height: 18),
            _RailButton(
              key: const Key('reel_remix_btn'),
              icon: Icons.alt_route_rounded,
              color: AppColors.badgeCyan,
              label: 'Remix',
              onTap: () {
                HapticFeedback.mediumImpact();
                ref.read(stemRemixProvider.notifier).initiateRemix(clip);
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppColors.surfaceElevated,
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.modalBorder),
                  builder: (ctx) => FractionallySizedBox(
                    heightFactor: 0.85,
                    child: StemMixerDeck(title: 'Remixing: ${clip.title}'),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _RailButton({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 4),
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _SoundPill extends StatelessWidget {
  final String title;
  final String artist;
  final VoidCallback? onRemix;
  const _SoundPill({required this.title, required this.artist, this.onRemix});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('reel_sound_pill'),
      onTap: onRemix,
      borderRadius: AppRadius.pillBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceModal.withAlpha(200),
          borderRadius: AppRadius.pillBorder,
          border: Border.all(color: AppColors.borderSubtle),
        ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.music_note_rounded,
              size: 14, color: AppColors.brandPrimary),
          const SizedBox(width: 6),
          Flexible(
            child: Text('$title • $artist',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textPrimary)),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.album_rounded,
              size: 14, color: AppColors.brandPrimary),
        ],
      ),
    ),
  );
}
}

String formatLikes(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  return '$count';
}
