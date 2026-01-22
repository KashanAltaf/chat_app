import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:just_waveform/just_waveform.dart';
import 'package:path_provider/path_provider.dart';

class WaveformUtils {
  /// Extracts a normalized waveform (0.0 – 1.0)
  /// Returns a fixed-length list suitable for UI rendering
  static Future<List<double>> extractWaveform(
      File audioFile, {
        int barCount = 60,
      }) async {
    final tempDir = await getTemporaryDirectory();

    final waveFile = File(
      '${tempDir.path}/${audioFile.path.hashCode}.wave',
    );

    final progressStream = JustWaveform.extract(
      audioInFile: audioFile,
      waveOutFile: waveFile,
    );

    Waveform? waveform;

    // Wait until waveform extraction is complete
    await for (final progress in progressStream) {
      if (progress.waveform != null) {
        waveform = progress.waveform;
        break;
      }
    }

    if (waveform == null) return [];

    final List<int> rawData = waveform.data;
    if (rawData.isEmpty) return [];

    // Find max amplitude
    int maxSample = 1;
    for (final s in rawData) {
      maxSample = max(maxSample, s.abs());
    }

    // Normalize to 0.0 – 1.0
    final normalized = rawData
        .map((e) => (e.abs() / maxSample).clamp(0.0, 1.0))
        .toList();

    // Downsample to barCount for UI
    final double samplesPerBar = normalized.length / barCount;

    final List<double> bars = List.generate(barCount, (i) {
      final int start = (i * samplesPerBar).floor();
      final int end = min(
        ((i + 1) * samplesPerBar).floor(),
        normalized.length,
      );

      if (start >= end) return 0.0;

      double sum = 0;
      for (int j = start; j < end; j++) {
        sum += normalized[j];
      }

      return sum / (end - start);
    });

    return bars;
  }
}
