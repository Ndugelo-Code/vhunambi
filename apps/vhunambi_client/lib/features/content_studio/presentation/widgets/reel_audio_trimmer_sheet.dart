import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/content_studio_preset.dart';

/// Glowing 48-bar waveform hook trimmer supporting 15s / 30s / 60s / 90s windows (`REQ-P74-STU-03`).
class ReelAudioTrimmerSheet extends StatefulWidget {
  final String trackTitle;
  final double totalDurationSec;
  final int initialStartMs;
  final int initialEndMs;

  const ReelAudioTrimmerSheet({
    super.key,
    required this.trackTitle,
    required this.totalDurationSec,
    required this.initialStartMs,
    required this.initialEndMs,
  });

  static Future<({int startMs, int endMs})?> show(
    BuildContext context, {
    required String trackTitle,
    required double totalDurationSec,
    required int initialStartMs,
    required int initialEndMs,
  }) {
    return showModalBottomSheet<({int startMs, int endMs})>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ReelAudioTrimmerSheet(
        trackTitle: trackTitle,
        totalDurationSec: totalDurationSec,
        initialStartMs: initialStartMs,
        initialEndMs: initialEndMs,
      ),
    );
  }

  @override
  State<ReelAudioTrimmerSheet> createState() => _ReelAudioTrimmerSheetState();
}

class _ReelAudioTrimmerSheetState extends State<ReelAudioTrimmerSheet> {
  static const List<DurationPreset> _windowPresets = <DurationPreset>[
    DurationPreset.hook15s,
    DurationPreset.reel30s,
    DurationPreset.reel60s,
    DurationPreset.reel90s,
  ];

  late double _startSec;
  late double _windowSec;

  double get _maxTrackSec => math.max(15.0, widget.totalDurationSec);

  @override
  void initState() {
    super.initState();
    _startSec = (widget.initialStartMs / 1000.0).clamp(0.0, _maxTrackSec - 5.0);
    final rawWin = (widget.initialEndMs - widget.initialStartMs) / 1000.0;
    _windowSec = rawWin.clamp(15.0, math.min(90.0, _maxTrackSec));
  }

  String _fmt(double seconds) {
    final s = seconds.round();
    final mins = s ~/ 60;
    final rem = (s % 60).toString().padLeft(2, '0');
    return '$mins:$rem';
  }

  @override
  Widget build(BuildContext context) {
    final maxStart = math.max(0.0, _maxTrackSec - _windowSec);
    final clampedStart = _startSec.clamp(0.0, maxStart);
    final endSec = math.min(_maxTrackSec, clampedStart + _windowSec);

    return Container(
      key: const Key('reel_audio_trimmer_sheet'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceModalOf(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const PhosphorIcon(
                AppIcons.waveform,
                size: 18,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Trim Hook • ${widget.trackTitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${_fmt(clampedStart)} – ${_fmt(endSec)}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: _windowPresets
                .map((preset) {
                  final sec = preset.targetSeconds.toDouble();
                  final active = (_windowSec - sec).abs() < 0.5;
                  return ChoiceChip(
                    key: Key('reel_duration_pill_${preset.targetSeconds}'),
                    selected: active,
                    label: Text('${preset.targetSeconds}s'),
                    onSelected: (_) {
                      setState(() {
                        _windowSec = math.min(sec, _maxTrackSec);
                        _startSec = _startSec.clamp(
                          0.0,
                          math.max(0.0, _maxTrackSec - _windowSec),
                        );
                      });
                    },
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 64,
            width: double.infinity,
            child: CustomPaint(
              painter: _GlowingWaveformPainter(
                startFrac: clampedStart / _maxTrackSec,
                endFrac: endSec / _maxTrackSec,
                accentColor: AppColors.brandPrimary,
              ),
            ),
          ),
          Slider(
            key: const Key('reel_audio_trim_slider'),
            value: clampedStart,
            min: 0.0,
            max: maxStart > 0 ? maxStart : 1.0,
            activeColor: AppColors.brandPrimary,
            onChanged:
                maxStart > 0 ? (v) => setState(() => _startSec = v) : null,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('reel_audio_trimmer_done_btn'),
              onPressed: () {
                Navigator.of(context).pop((
                  startMs: (clampedStart * 1000).round(),
                  endMs: (endSec * 1000).round(),
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.brandContrast,
              ),
              child: const Text('Use Hook Segment'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowingWaveformPainter extends CustomPainter {
  final double startFrac;
  final double endFrac;
  final Color accentColor;

  const _GlowingWaveformPainter({
    required this.startFrac,
    required this.endFrac,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 48;
    final barSpacing = size.width / barCount;
    final barWidth = math.max(2.0, barSpacing * 0.52);

    for (var i = 0; i < barCount; i++) {
      final frac = i / barCount;
      final inWindow = frac >= startFrac && frac <= endFrac;
      final amp =
          0.25 + 0.72 * ((math.sin(i * 0.72) + math.cos(i * 0.31)).abs() / 2.0);
      final h = size.height * amp;
      final x = i * barSpacing;
      final y = (size.height - h) / 2.0;

      final paint = Paint()
        ..color = inWindow ? accentColor : accentColor.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, h),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GlowingWaveformPainter oldDelegate) =>
      oldDelegate.startFrac != startFrac || oldDelegate.endFrac != endFrac;
}
