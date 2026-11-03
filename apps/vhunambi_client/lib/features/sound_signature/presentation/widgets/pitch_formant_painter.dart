import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/idealizer/pitch_trajectory_editor.dart';
import '../../domain/models/pitch_contour_profile.dart';
import '../../domain/models/sound_idealizer_recipe.dart';
import '../../domain/models/sound_signature_dna.dart';

/// Canvas renderer for raw and idealized pitch trajectories, modal scale rails,
/// Bantu protected phonetics, and formant resonance lines (REQ-SIG-UI-01 / Design 7.1).
///
/// Adheres strictly to `STD-UIUX-001`: reads dynamic `AppColors` getters inside `paint()`.
class PitchFormantPainter extends CustomPainter {
  const PitchFormantPainter({
    required this.signature,
    required this.recipe,
    this.isAuditioningIdealized = true,
    this.refusedNotes = const [],
    this.idealSemitones,
    required this.brightness,
  });

  final SoundSignatureDna signature;
  final SoundIdealizerRecipe recipe;
  final bool isAuditioningIdealized;
  final List<RefusedNote> refusedNotes;
  final Float64List? idealSemitones;
  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    AppColors.syncWithBrightness(brightness);

    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // 1. Background rounded card canvas
    final bgPaint = Paint()..color = AppColors.surfaceSecondary;
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      const Radius.circular(12),
    );
    canvas.drawRRect(bgRect, bgPaint);

    final borderPaint = Paint()
      ..color = AppColors.borderSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(bgRect, borderPaint);

    // Coordinate mapping: Pitch spans MIDI 40 (E2) to MIDI 76 (E5)
    const minMidi = 40.0;
    const maxMidi = 76.0;
    double midiToY(double midi) {
      final norm = (midi - minMidi) / (maxMidi - minMidi);
      return (1.0 - norm).clamp(0.0, 1.0) * h;
    }

    final durationSec = math.max(0.1, signature.durationSec);
    double secToX(double sec) {
      return (sec / durationSec).clamp(0.0, 1.0) * w;
    }

    // 2. African Modal Scale Rails
    final scaleMode = signature.pitch.scaleMode;
    final rootPc = signature.pitch.rootPitchClass;
    final scalePcs = scaleMode.semitoneOffsets
        .map((o) => (rootPc + o) % 12)
        .toSet();

    for (var m = minMidi.toInt(); m <= maxMidi.toInt(); m++) {
      final pc = m % 12;
      final isRoot = pc == rootPc;
      final inScale = scalePcs.contains(pc);

      if (inScale || isRoot) {
        final y = midiToY(m.toDouble());
        final railPaint = Paint()
          ..color = isRoot
              ? AppColors.coinGold.withValues(alpha: 0.35)
              : AppColors.borderSubtle.withValues(alpha: 0.40)
          ..strokeWidth = isRoot ? 1.2 : 0.8
          ..style = PaintingStyle.stroke;

        // Draw horizontal dashed rail
        var currentX = 0.0;
        const dashWidth = 4.0;
        const dashSpace = 4.0;
        while (currentX < w) {
          canvas.drawLine(
            Offset(currentX, y),
            Offset(math.min(w, currentX + dashWidth), y),
            railPaint,
          );
          currentX += dashWidth + dashSpace;
        }
      }
    }

    // 3. Protected Bantu Phonetic spans (clicks, plosives, breath)
    final protectedPaint = Paint()
      ..color = AppColors.brandPrimary.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    for (final span in signature.articulation.protectedSegments) {
      final startSec = span.startMs / 1000.0;
      final endSec = span.endMs / 1000.0;
      final x0 = secToX(startSec);
      final x1 = secToX(endSec);
      final spanW = math.max(2.0, x1 - x0);
      canvas.drawRect(Rect.fromLTWH(x0, 0, spanW, h), protectedPaint);
    }

    // 4. Formant Resonance Indicators (F1, F2)
    final formants = signature.identity.formantsHz;
    if (formants.isNotEmpty && formants[0] > 0) {
      final f1 = formants[0];
      final f2 = formants.length > 1 ? formants[1] : 0.0;

      final formantPaint = Paint()
        ..color = AppColors.badgeCyan.withValues(alpha: 0.25)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      // Approximate mapping of formant Hz to vocal frequency Y
      final f1Midi = 69.0 + 12.0 * math.log(f1 / 440.0) / math.ln2;
      if (f1Midi >= minMidi && f1Midi <= maxMidi) {
        final yF1 = midiToY(f1Midi);
        canvas.drawLine(Offset(0, yF1), Offset(w, yF1), formantPaint);
      }

      if (f2 > 0) {
        final f2Midi = 69.0 + 12.0 * math.log(f2 / 440.0) / math.ln2;
        if (f2Midi >= minMidi && f2Midi <= maxMidi) {
          final yF2 = midiToY(f2Midi);
          canvas.drawLine(Offset(0, yF2), Offset(w, yF2), formantPaint);
        }
      }
    }

    // 5. Raw F0 Pitch Contour (Dim background line)
    final rawCents = signature.pitch.f0CentsMidi;
    final rawPaint = Paint()
      ..color = AppColors.textTertiary.withValues(alpha: 0.55)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final frameCount = rawCents.length;
    final secPerFrame = frameCount > 0
        ? (signature.durationSec / frameCount)
        : 0.02;

    Path? currentRawPath;
    for (var i = 0; i < frameCount; i++) {
      final c = rawCents[i];
      if (c == PitchContourProfile.unvoicedSentinel || c <= 0) {
        if (currentRawPath != null) {
          canvas.drawPath(currentRawPath, rawPaint);
          currentRawPath = null;
        }
      } else {
        final midi = c / 100.0;
        final x = secToX(i * secPerFrame);
        final y = midiToY(midi);

        if (currentRawPath == null) {
          currentRawPath = Path()..moveTo(x, y);
        } else {
          currentRawPath.lineTo(x, y);
        }
      }
    }
    if (currentRawPath != null) {
      canvas.drawPath(currentRawPath, rawPaint);
    }

    // 6. Idealized F0 Pitch Contour (Vibrant Amber)
    if (isAuditioningIdealized &&
        idealSemitones != null &&
        idealSemitones!.isNotEmpty) {
      final idealPaint = Paint()
        ..color = AppColors.brandPrimary
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      Path? currentIdealPath;
      final idealCount = idealSemitones!.length;
      final idealSecPerFrame = frameCount > 0
          ? (signature.durationSec / idealCount)
          : 0.02;

      for (var i = 0; i < idealCount; i++) {
        final m = idealSemitones![i];
        if (m.isNaN || m <= 0) {
          if (currentIdealPath != null) {
            canvas.drawPath(currentIdealPath, idealPaint);
            currentIdealPath = null;
          }
        } else {
          final x = secToX(i * idealSecPerFrame);
          final y = midiToY(m);

          if (currentIdealPath == null) {
            currentIdealPath = Path()..moveTo(x, y);
          } else {
            currentIdealPath.lineTo(x, y);
          }
        }
      }
      if (currentIdealPath != null) {
        canvas.drawPath(currentIdealPath, idealPaint);
      }
    }

    // 7. Refused note markers (> 7 semitone snap prevented)
    final cautionPaint = Paint()
      ..color = AppColors.error
      ..style = PaintingStyle.fill;

    for (final refused in refusedNotes) {
      final midSec = (refused.startMs + refused.endMs) / 2000.0;
      final x = secToX(midSec);
      final y = midiToY(refused.originalPitchMidi);
      canvas.drawCircle(Offset(x, y), 3.5, cautionPaint);
    }
  }

  @override
  bool shouldRepaint(covariant PitchFormantPainter oldDelegate) {
    return oldDelegate.signature != signature ||
        oldDelegate.recipe != recipe ||
        oldDelegate.isAuditioningIdealized != isAuditioningIdealized ||
        oldDelegate.brightness != brightness ||
        oldDelegate.refusedNotes.length != refusedNotes.length ||
        oldDelegate.idealSemitones != idealSemitones;
  }
}
