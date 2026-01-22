import 'dart:math';
import 'package:flutter/material.dart';

/// Waveform painter draws vertical bars. `samples` should be normalized (0..1).
class AudioChatBubble extends CustomPainter {
  final List<double> samples;
  final double playedFraction; // 0..1
  final Color playedColor;
  final Color baseColor;
  final double barWidth;
  final double spacing;
  final double radius;

  AudioChatBubble({
    required this.samples,
    required this.playedFraction,
    required this.playedColor,
    required this.baseColor,
    required this.barWidth,
    required this.spacing,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint playedPaint = Paint()..color = playedColor;
    final Paint basePaint = Paint()..color = baseColor;

    final totalBars = samples.length;
    final totalWidth = totalBars * barWidth + max(0, totalBars - 1) * spacing;
    final leftOffset = (size.width - totalWidth) / 2.0;

    for (int i = 0; i < totalBars; i++) {
      final x = leftOffset + i * (barWidth + spacing);
      final sample = samples[i].clamp(0.0, 1.0);
      final barHeight = sample * size.height;
      final top = (size.height - barHeight) / 2;
      final rect = RRect.fromLTRBR(
        x,
        top,
        x + barWidth,
        top + barHeight,
        Radius.circular(radius),
      );

      final barCenterX = x + barWidth / 2;
      final fractionX = (barCenterX - leftOffset) / totalWidth;
      final paint = (fractionX <= playedFraction) ? playedPaint : basePaint;
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant AudioChatBubble old) {
    return old.playedFraction != playedFraction ||
        old.samples != samples ||
        old.playedColor != playedColor ||
        old.baseColor != baseColor;
  }
}

/// Audio bubble with waveform and seek-by-tap/drag.
class AudioChatBubbleWithWaveform extends StatefulWidget {
  final bool isMe;
  final bool isPlaying;
  final bool isLoading;
  final bool isPause;
  final Duration duration;
  final Duration position;
  final void Function(double seconds)? onSeekChanged; // seconds
  final VoidCallback onPlayPause;
  final List<double>? waveformSamples; // normalized 0..1, recommended 64..256 samples
  final double maxWidth; // max width for bubble

  const AudioChatBubbleWithWaveform({
    Key? key,
    required this.isMe,
    required this.isPlaying,
    required this.isLoading,
    required this.isPause,
    required this.duration,
    required this.position,
    this.onSeekChanged,
    required this.onPlayPause,
    this.waveformSamples,
    this.maxWidth = 360,
  }) : super(key: key);

  @override
  _AudioChatBubbleWithWaveformState createState() =>
      _AudioChatBubbleWithWaveformState();
}

class _AudioChatBubbleWithWaveformState
    extends State<AudioChatBubbleWithWaveform> {
  // When user is dragging on waveform we track local fraction
  bool _isInteracting = false;
  double _localFraction = 0.0;

  // Generate a pleasant placeholder waveform if none provided.
  List<double> _generatePlaceholder(int n) {
    final rng = Random(42);
    return List.generate(n, (i) {
      final base = 0.15 + 0.6 * (0.5 + 0.5 * sin(i / 3.0)); // wavy baseline
      final jitter = rng.nextDouble() * 0.25;
      return (base * (0.6 + jitter)).clamp(0.02, 1.0);
    });
  }

  // Clip number of samples for performance + consistent look
  List<double> _prepareSamples(List<double>? input) {
    const target = 90; // good balance for mobile
    if (input == null || input.isEmpty) return _generatePlaceholder(target);
    if (input.length == target) {
      return input.map((e) => e.clamp(0.0, 1.0)).toList();
    }
    // downsample/upsample to target
    List<double> out = List.filled(target, 0);
    final scale = input.length / target;
    for (int i = 0; i < target; i++) {
      final start = (i * scale).floor();
      final end = min(input.length - 1, ((i + 1) * scale).floor());
      double avg = 0;
      int count = 0;
      for (int j = start; j <= end; j++) {
        avg += input[j];
        count++;
      }
      out[i] = count > 0 ? (avg / count).clamp(0.0, 1.0) : 0.0;
    }
    return out;
  }

  void _handleInteraction(Offset localPos, double width) {
    final fraction = (localPos.dx / width).clamp(0.0, 1.0);
    setState(() {
      _isInteracting = true;
      _localFraction = fraction;
    });
  }

  void _finishInteraction(double width) {
    final fraction = _localFraction.clamp(0.0, 1.0);
    final seconds = widget.duration.inMilliseconds * fraction / 1000.0;
    widget.onSeekChanged?.call(seconds);
    setState(() {
      _isInteracting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = widget.isMe ? Colors.blue : Colors.grey;
    final playedColor = widget.isMe ? Colors.white : Colors.black87;
    final baseColor = widget.isMe
        ? Colors.white.withOpacity(0.18)
        : Colors.black26.withOpacity(0.12);

    final samples = _prepareSamples(widget.waveformSamples);
    final playedFraction = _isInteracting
        ? _localFraction
        : (widget.duration.inMilliseconds > 0
        ? (widget.position.inMilliseconds /
        max(1, widget.duration.inMilliseconds))
        : 0.0);

    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(40),
        ),
        child: Row(
          children: [
            // Play / Loading
            Stack(
              children: [
                Container(
                  height: 70,
                  width: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle
                  ),
                ),
                GestureDetector(
                  onTap: widget.isLoading ? null : widget.onPlayPause,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: widget.isMe ? Colors.blue : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: widget.isLoading
                          ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : Icon(
                        widget.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: widget.isMe ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 10),

            // Waveform area: interactive
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                final width = constraints.maxWidth;
                return GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: (d) =>
                      _handleInteraction(d.localPosition, width),
                  onHorizontalDragUpdate: (d) =>
                      _handleInteraction(d.localPosition, width),
                  onHorizontalDragEnd: (_) => _finishInteraction(width),
                  onTapDown: (d) => _handleInteraction(d.localPosition, width),
                  onTapUp: (_) => _finishInteraction(width),
                  child: SizedBox(
                    height: 60,
                    child: CustomPaint(
                      painter: AudioChatBubble(
                        samples: samples,
                        playedFraction: playedFraction,
                        playedColor: playedColor,
                        baseColor: baseColor,
                        barWidth: 1,
                        spacing: 2.2,
                        radius: 2.2,
                      ),
                      child: Container(),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(width: 8),

            // Optional: small visual indicator; not a textual duration
            // you can remove this or replace with an icon
            Container(width: 6),
          ],
        ),
      ),
    );
  }
}
