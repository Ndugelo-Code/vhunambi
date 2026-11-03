import 'dart:math' as math;
import 'dart:typed_data';
import 'fft.dart';

/// Extracts 16-coefficient mel-cepstral acoustic descriptor vector (REQ-SIG-ANALYSIS-04 / Design 4.6).
///
/// Converts voiced audio frames through 24 triangular mel filters and DCT-II
/// to produce a scale-invariant spectral envelope fingerprint.
class CepstralDescriptorExtractor {
  CepstralDescriptorExtractor({
    this.sampleRate = 16000,
    this.numMelBands = 24,
    this.numCoefficients = 16,
    this.minFrequencyHz = 200.0,
    this.maxFrequencyHz = 7500.0,
  })  : _fft = FastFourierTransform(512),
        _melFilters = _buildMelFilterbank(
          512,
          sampleRate,
          numMelBands,
          minFrequencyHz,
          maxFrequencyHz,
        );

  final int sampleRate;
  final int numMelBands;
  final int numCoefficients;
  final double minFrequencyHz;
  final double maxFrequencyHz;

  final FastFourierTransform _fft;
  final List<Float64List> _melFilters;

  /// Extracts the mean 16-coefficient descriptor across voiced frames of [pcm16k].
  List<double> extractDescriptor(Float32List pcm16k, {List<bool>? voicedMask}) {
    const frameSize = 512;
    const hopSize = 256;
    final frameCount = (pcm16k.length - frameSize) ~/ hopSize;

    if (frameCount <= 0) {
      return List<double>.filled(numCoefficients, 0.0);
    }

    final runningSums = Float64List(numCoefficients);
    var voicedCount = 0;

    final real = Float64List(frameSize);
    final imag = Float64List(frameSize);

    for (var f = 0; f < frameCount; f++) {
      if (voicedMask != null && f < voicedMask.length && !voicedMask[f]) {
        continue;
      }

      final start = f * hopSize;

      // Apply Hann window
      for (var i = 0; i < frameSize; i++) {
        final hann = 0.5 * (1.0 - math.cos(2.0 * math.pi * i / (frameSize - 1)));
        real[i] = pcm16k[start + i] * hann;
        imag[i] = 0.0;
      }

      _fft.forward(real, imag);
      final power = _fft.powerSpectrum(real, imag);

      // Filterbank energies
      final melEnergies = Float64List(numMelBands);
      for (var m = 0; m < numMelBands; m++) {
        var energy = 0.0;
        final filter = _melFilters[m];
        for (var k = 0; k < filter.length; k++) {
          energy += power[k] * filter[k];
        }
        melEnergies[m] = math.log(math.max(1e-8, energy));
      }

      // DCT-II to obtain c1..c16 (dropping c0 energy bias)
      for (var k = 1; k <= numCoefficients; k++) {
        var sum = 0.0;
        for (var m = 0; m < numMelBands; m++) {
          sum += melEnergies[m] * math.cos(math.pi * k * (m + 0.5) / numMelBands);
        }
        runningSums[k - 1] += sum;
      }

      voicedCount++;
    }

    if (voicedCount == 0) {
      return List<double>.filled(numCoefficients, 0.0);
    }

    // Mean across voiced frames
    final descriptor = List<double>.generate(numCoefficients, (k) {
      final meanVal = runningSums[k] / voicedCount;
      return (meanVal * 10000).roundToDouble() / 10000.0;
    });

    return descriptor;
  }

  /// Calculates cosine similarity between two 16-coefficient descriptors (1.0 = identical).
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = math.sqrt(normA) * math.sqrt(normB);
    return denom > 1e-8 ? (dot / denom).clamp(-1.0, 1.0) : 0.0;
  }

  static List<Float64List> _buildMelFilterbank(
    int fftSize,
    int sampleRate,
    int numBands,
    double minHz,
    double maxHz,
  ) {
    double hzToMel(double hz) => 2595.0 * math.log(1.0 + hz / 700.0) / math.ln10;
    double melToHz(double mel) => 700.0 * (math.pow(10.0, mel / 2595.0) - 1.0);

    final minMel = hzToMel(minHz);
    final maxMel = hzToMel(maxHz);
    final melPoints = Float64List(numBands + 2);

    for (var i = 0; i <= numBands + 1; i++) {
      melPoints[i] = melToHz(minMel + (maxMel - minMel) * i / (numBands + 1));
    }

    final numBins = fftSize ~/ 2 + 1;
    final filters = <Float64List>[];

    for (var m = 1; m <= numBands; m++) {
      final filter = Float64List(numBins);
      final leftHz = melPoints[m - 1];
      final centerHz = melPoints[m];
      final rightHz = melPoints[m + 1];

      for (var k = 0; k < numBins; k++) {
        final freq = (k * sampleRate) / fftSize;
        if (freq >= leftHz && freq <= centerHz) {
          filter[k] = (freq - leftHz) / (centerHz - leftHz);
        } else if (freq > centerHz && freq <= rightHz) {
          filter[k] = (rightHz - freq) / (rightHz - centerHz);
        }
      }
      filters.add(filter);
    }

    return filters;
  }
}

