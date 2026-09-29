import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PodavioLogo extends StatelessWidget {
  const PodavioLogo({super.key, this.width = 240});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/logo.png',
      width: width,
      semanticLabel: 'Podavio',
    );
  }
}

class PodavioIcon extends StatelessWidget {
  const PodavioIcon({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/icon.png',
      width: size,
      height: size,
      semanticLabel: 'Podavio',
    );
  }
}

class SkipIcon extends StatelessWidget {
  const SkipIcon.back({super.key, this.size = 24})
    : asset = 'assets/brand/fast_rewind.svg',
      label = 'Reculer';

  const SkipIcon.forward({super.key, this.size = 24})
    : asset = 'assets/brand/fast_forward.svg',
      label = 'Avancer';

  const SkipIcon.collapse({super.key, this.size = 24})
    : asset = 'assets/brand/keyboard_arrow_down.svg',
      label = 'Réduire';

  final String asset;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color =
        IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      semanticsLabel: label,
    );
  }
}

/// Bouton lecture / pause avec morph entre les deux logos.
class PlayPauseIcon extends StatelessWidget {
  const PlayPauseIcon({super.key, required this.playing, this.size = 24});

  final bool playing;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color =
        IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      tween: Tween<double>(end: playing ? 1 : 0),
      builder: (context, progress, _) {
        return Semantics(
          label: playing ? 'Pause' : 'Lecture',
          child: CustomPaint(
            size: Size.square(size),
            painter: _PlayPausePainter(progress: progress, color: color),
          ),
        );
      },
    );
  }
}

class _PlayPausePainter extends CustomPainter {
  _PlayPausePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final u = s / 24;
    final stroke = 1.7 * u;
    final t = progress;
    canvas.translate(s / 2, s / 2);

    final playAlpha = (1 - t * 1.1).clamp(0.0, 1.0);
    final pauseAlpha = ((t - 0.08) / 0.92).clamp(0.0, 1.0);

    if (playAlpha > 0) {
      canvas.save();
      final scale = _lerp(1, 0.72, t);
      canvas.scale(scale);
      canvas.rotate(t * 0.35);
      final paint = Paint()
        ..color = color.withValues(alpha: color.a * playAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke / scale
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      // Triangle aligné sur play_arrow.svg (viewBox 24, centré)
      final path = Path()
        ..moveTo(-3.5 * u, -5.8 * u)
        ..lineTo(6.3 * u, 0)
        ..lineTo(-3.5 * u, 5.8 * u)
        ..close();
      canvas.drawPath(path, paint);
      canvas.restore();
    }

    if (pauseAlpha > 0) {
      canvas.save();
      final scale = _lerp(0.72, 1, t);
      canvas.scale(scale);
      canvas.rotate((1 - t) * -0.35);
      final paint = Paint()
        ..color = color.withValues(alpha: color.a * pauseAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke / scale
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      final radius = Radius.circular(1.6 * u);
      // Barres alignées sur pause.svg (viewBox 24, centré)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(-4.4 * u, 0),
            width: 4.2 * u,
            height: 13.6 * u,
          ),
          radius,
        ),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(4.4 * u, 0),
            width: 4.2 * u,
            height: 13.6 * u,
          ),
          radius,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant _PlayPausePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
