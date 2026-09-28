import 'package:flutter/material.dart';

import 'theme.dart';

class WaveformMark extends StatelessWidget {
  const WaveformMark({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.62),
      painter: const _WaveformPainter(),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 140;
    final scaleY = size.height / 88;
    canvas.save();
    canvas.translate(8 * scaleX, 8 * scaleY);
    canvas.scale(scaleX, scaleY);

    void stroke(Path path, Color color, double width) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    stroke(
      Path()
        ..moveTo(16, 50)
        ..cubicTo(34, 50, 34, 24, 52, 24),
      podavioBlue,
      6,
    );
    stroke(
      Path()
        ..moveTo(52, 24)
        ..cubicTo(70, 24, 70, 72, 88, 72),
      podavioBlue,
      8,
    );
    stroke(
      Path()
        ..moveTo(52, 24)
        ..cubicTo(70, 24, 70, 72, 88, 72),
      Colors.white,
      4.5,
    );
    stroke(
      Path()
        ..moveTo(88, 72)
        ..cubicTo(106, 72, 106, 50, 124, 50),
      podavioRed,
      6,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
