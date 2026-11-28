import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/analysis_overview.dart';

/// Vert et ambre de GitHub (mode sombre de la capture, plus foncés au clair).
({Color success, Color attention, Color danger}) analysisStatusColors(
  Brightness brightness,
) {
  if (brightness == Brightness.dark) {
    return (
      success: const Color(0xFF3FB950),
      attention: const Color(0xFFD29922),
      danger: const Color(0xFFF85149),
    );
  }
  return (
    success: const Color(0xFF1A7F37),
    attention: const Color(0xFF9A6700),
    danger: const Color(0xFFD1242F),
  );
}

/// Indicateur d’analyse, à la place du chevron.
///
/// Coche verte : analysé. Horloge ambre : pas encore. Point dans un anneau
/// qui tourne : en cours. Croix rouge : échec.
class AnalysisStatusMark extends StatelessWidget {
  const AnalysisStatusMark({
    super.key,
    required this.status,
    required this.label,
    this.size = 20,
  });

  final AnalysisOverviewStatus status;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = analysisStatusColors(Theme.of(context).brightness);
    final mark = switch (status) {
      AnalysisOverviewStatus.analysed => _Glyph(
          size: size,
          painter: _CheckPainter(colors.success),
        ),
      AnalysisOverviewStatus.pending => _Glyph(
          size: size,
          painter: _ClockPainter(colors.attention),
        ),
      AnalysisOverviewStatus.failed => _Glyph(
          size: size,
          painter: _CrossPainter(colors.danger),
        ),
      AnalysisOverviewStatus.inProgress => _SpinningDot(
          size: size,
          color: colors.attention,
        ),
    };
    return Tooltip(
      message: label,
      child: Semantics(label: label, child: mark),
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.size, required this.painter});

  final double size;
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: painter);
  }
}

class _SpinningDot extends StatefulWidget {
  const _SpinningDot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  State<_SpinningDot> createState() => _SpinningDotState();
}

class _SpinningDotState extends State<_SpinningDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turns = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _turns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _turns,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _SpinnerPainter(widget.color),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      size.width / 2,
      Paint()..color = color,
    );
    final mark = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.27, size.height * 0.52)
        ..lineTo(size.width * 0.44, size.height * 0.68)
        ..lineTo(size.width * 0.74, size.height * 0.36),
      mark,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) => oldDelegate.color != color;
}

class _ClockPainter extends CustomPainter {
  const _ClockPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, size.width * 0.40, stroke);
    canvas.drawLine(center, Offset(center.dx, size.height * 0.30), stroke);
    canvas.drawLine(
      center,
      Offset(size.width * 0.66, size.height * 0.60),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_ClockPainter oldDelegate) => oldDelegate.color != color;
}

class _SpinnerPainter extends CustomPainter {
  const _SpinnerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width * 0.40),
      -math.pi / 2,
      math.pi * 1.45,
      false,
      stroke,
    );
    canvas.drawCircle(center, size.width * 0.13, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SpinnerPainter oldDelegate) => oldDelegate.color != color;
}

class _CrossPainter extends CustomPainter {
  const _CrossPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.drawCircle(center, size.width / 2, Paint()..color = color);
    final mark = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.14
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.34, size.height * 0.34),
      Offset(size.width * 0.66, size.height * 0.66),
      mark,
    );
    canvas.drawLine(
      Offset(size.width * 0.66, size.height * 0.34),
      Offset(size.width * 0.34, size.height * 0.66),
      mark,
    );
  }

  @override
  bool shouldRepaint(_CrossPainter oldDelegate) => oldDelegate.color != color;
}
