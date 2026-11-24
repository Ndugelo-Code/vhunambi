import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/content_studio_preset.dart';

/// Glowing 48-bar waveform hook trimmer supporting 15s / 30s / 60s / 90s windows,
/// dual start/end range handles, and SafeArea clearance (`REQ-P79-STU-02`).
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
      isScrollControlled: true,
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
  late double _endSec;

  double get _maxTrackSec => math.max(15.0, widget.totalDurationSec);

  @override
  void initState() {
    super.initState();
    _startSec = (widget.initialStartMs / 1000.0)
        .clamp(0.0, _maxTrackSec - 5.0)
        .toDouble();
    final rawEnd = widget.initialEndMs / 1000.0;
    _endSec = rawEnd
        .clamp(_startSec + 5.0, math.min(_maxTrackSec, _startSec + 90.0))
        .toDouble();
  }

  String _fmt(double seconds) {
    final s = seconds.round();
    final mins = s ~/ 60;
    final rem = (s % 60).toString().padLeft(2, '0');
    return '$mins:$rem';
  }

  @override
  Widget build(BuildContext context) {
    final clampedStart = _startSec
        .clamp(0.0, math.max(0.0, _maxTrackSec - 5.0))
        .toDouble();
    final clampedEnd = _endSec
        .clamp(math.min(_maxTrackSec, clampedStart + 5.0), _maxTrackSec)
        .toDouble();
    final windowSec = clampedEnd - clampedStart;
    final maxStart = math.max(0.0, _maxTrackSec - windowSec);

    return SafeArea(
      top: false,
      child: Container(
        key: const Key('reel_audio_trimmer_sheet'),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: AppColors.surfaceModalOf(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
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
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${_fmt(clampedStart)} – ${_fmt(clampedEnd)}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _windowPresets
                    .map((preset) {
                      final sec = preset.targetSeconds.toDouble();
                      final active = (windowSec - sec).abs() < 0.6;
                      return ChoiceChip(
                        key: Key('reel_duration_pill_${preset.targetSeconds}'),
                        selected: active,
                        label: Text('${preset.targetSeconds}s'),
                        onSelected: (_) {
                          setState(() {
                            final boundedWin = math.min(sec, _maxTrackSec);
                            _startSec = clampedStart
                                .clamp(
                                  0.0,
                                  math.max(0.0, _maxTrackSec - boundedWin),
                                )
                                .toDouble();
                            _endSec = math.min(
                              _maxTrackSec,
                              _startSec + boundedWin,
                            );
                          });
                        },
                      );
                    })
                    .toList(growable: false),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 60,
                width: double.infinity,
                child: CustomPaint(
                  painter: _GlowingWaveformPainter(
                    startFrac: clampedStart / _maxTrackSec,
                    endFrac: clampedEnd / _maxTrackSec,
                    accentColor: AppColors.brandPrimary,
                  ),
                ),
              ),
              RangeSlider(
                key: const Key('reel_audio_trim_range_slider'),
                values: RangeValues(clampedStart, clampedEnd),
                min: 0.0,
                max: _maxTrackSec,
                activeColor: AppColors.brandPrimary,
                onChanged: (values) {
                  final span = (values.end - values.start)
                      .clamp(5.0, 90.0)
                      .toDouble();
                  setState(() {
                    _startSec = values.start
                        .clamp(0.0, math.max(0.0, _maxTrackSec - span))
                        .toDouble();
                    _endSec = (_startSec + span)
                        .clamp(5.0, _maxTrackSec)
                        .toDouble();
                  });
                },
              ),
              Slider(
                key: const Key('reel_audio_trim_slider'),
                value: clampedStart
                    .clamp(0.0, maxStart > 0 ? maxStart : 1.0)
                    .toDouble(),
                min: 0.0,
                max: maxStart > 0 ? maxStart : 1.0,
                activeColor: AppColors.brandPrimary,
                onChanged: maxStart > 0
                    ? (v) => setState(() {
                        _startSec = v;
                        _endSec = math.min(_maxTrackSec, v + windowSec);
                      })
                    : null,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  key: const Key('reel_audio_trimmer_done_btn'),
                  onPressed: () {
                    Navigator.of(context).pop((
                      startMs: (clampedStart * 1000).round(),
                      endMs: (clampedEnd * 1000).round(),
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
        ),
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

    final handlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5;
    final startX =
        (startFrac * size.width).clamp(1.0, size.width - 1.0).toDouble();
    final endX = (endFrac * size.width).clamp(1.0, size.width - 1.0).toDouble();
    canvas.drawLine(Offset(startX, 0), Offset(startX, size.height), handlePaint);
    canvas.drawLine(Offset(endX, 0), Offset(endX, size.height), handlePaint);
  }

  @override
  bool shouldRepaint(_GlowingWaveformPainter oldDelegate) =>
      oldDelegate.startFrac != startFrac || oldDelegate.endFrac != endFrac;
}
