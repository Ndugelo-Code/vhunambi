import 'dart:math' as math;
import 'dart:typed_data';

/// In-place Cooley-Tukey Radix-2 Fast Fourier Transform (REQ-SIG-ANALYSIS-01 / Design 4).
///
/// Pure Dart implementation with pre-computed twiddle tables for zero allocation in audio loops.
class FastFourierTransform {
  FastFourierTransform(this.size) {
    if ((size & (size - 1)) != 0 || size < 2) {
      throw ArgumentError('FFT size must be a power of two >= 2, got $size');
    }
    _bitRev = Int32List(size);
    var j = 0;
    for (var i = 0; i < size; i++) {
      _bitRev[i] = j;
      var bit = size >> 1;
      while (bit > 0 && (j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
    }

    _cosTwiddles = Float64List(size ~/ 2);
    _sinTwiddles = Float64List(size ~/ 2);
    for (var i = 0; i < size ~/ 2; i++) {
      final angle = -2.0 * math.pi * i / size;
      _cosTwiddles[i] = math.cos(angle);
      _sinTwiddles[i] = math.sin(angle);
    }
  }

  final int size;
  late final Int32List _bitRev;
  late final Float64List _cosTwiddles;
  late final Float64List _sinTwiddles;

  /// Executes forward FFT on [real] and [imag] in-place.
  void forward(Float64List real, Float64List imag) {
    _transform(real, imag, inverse: false);
  }

  /// Executes inverse FFT on [real] and [imag] in-place with 1/N scaling.
  void inverse(Float64List real, Float64List imag) {
    _transform(real, imag, inverse: true);
    final scale = 1.0 / size;
    for (var i = 0; i < size; i++) {
      real[i] *= scale;
      imag[i] *= scale;
    }
  }

  void _transform(Float64List real, Float64List imag, {required bool inverse}) {
    // 1. Bit-reversal permutation
    for (var i = 0; i < size; i++) {
      final j = _bitRev[i];
      if (j > i) {
        final tr = real[i];
        real[i] = real[j];
        real[j] = tr;

        final ti = imag[i];
        imag[i] = imag[j];
        imag[j] = ti;
      }
    }

    // 2. Butterfly computations
    for (var len = 2; len <= size; len <<= 1) {
      final half = len >> 1;
      final step = size ~/ len;
      final sign = inverse ? -1.0 : 1.0;

      for (var i = 0; i < size; i += len) {
        for (var j = 0; j < half; j++) {
          final twiddleIdx = j * step;
          final wr = _cosTwiddles[twiddleIdx];
          final wi = _sinTwiddles[twiddleIdx] * sign;

          final uIdx = i + j;
          final vIdx = i + j + half;

          final vr = real[vIdx];
          final vi = imag[vIdx];

          final tr = wr * vr - wi * vi;
          final ti = wr * vi + wi * vr;

          real[vIdx] = real[uIdx] - tr;
          imag[vIdx] = imag[uIdx] - ti;

          real[uIdx] += tr;
          imag[uIdx] += ti;
        }
      }
    }
  }

  /// Computes the power spectrum `real^2 + imag^2` for the first `size / 2 + 1` bins.
  Float64List powerSpectrum(Float64List real, Float64List imag) {
    final half = size ~/ 2 + 1;
    final power = Float64List(half);
    for (var i = 0; i < half; i++) {
      power[i] = real[i] * real[i] + imag[i] * imag[i];
    }
    return power;
  }

  /// Static helper for in-place forward FFT.
  static void fft(Float64List real, Float64List imag) {
    FastFourierTransform(real.length).forward(real, imag);
  }
}

/// Convenience alias matching spec.
typedef Fft = FastFourierTransform;
