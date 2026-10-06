import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Onde du logo, animée le temps que l’application s’ouvre.
class StartupSplash extends StatefulWidget {
  const StartupSplash({super.key, required this.child});

  final Widget child;

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash>
    with TickerProviderStateMixin {
  late final AnimationController _wave;
  late final AnimationController _leave;
  var _show = true;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _leave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _holdThenLeave());
  }

  void _holdThenLeave() {
    if (!mounted) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) _wave.stop();
    final hold = reduce
        ? const Duration(milliseconds: 350)
        : const Duration(milliseconds: 1500);
    Future<void>.delayed(hold, () async {
      if (!mounted || !_show) return;
      await _leave.forward();
      if (!mounted) return;
      setState(() => _show = false);
    });
  }

  @override
  void dispose() {
    _wave.dispose();
    _leave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_show)
          FadeTransition(
            key: const Key('startup-splash'),
            opacity: Tween<double>(begin: 1, end: 0).animate(
              CurvedAnimation(parent: _leave, curve: Curves.easeOut),
            ),
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Center(
                child: Semantics(
                  label: 'Podavio',
                  child: AnimatedBuilder(
                    animation: _wave,
                    builder: (context, _) {
                      return CustomPaint(
                        size: const Size(240, 88),
                        painter: _StartupWavePainter(
                          phase: _wave.value,
                          color: podavioGreen,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StartupWavePainter extends CustomPainter {
  _StartupWavePainter({required this.phase, required this.color});

  final double phase;
  final Color color;

  static const _shape = <double>[
    0.16, 0.26, 0.4, 0.58, 0.74, 0.5, 0.86, 0.64, 0.44, 0.9,
    0.62, 0.82, 0.48, 0.94, 0.7, 0.42, 0.66, 0.5, 0.32, 0.22, 0.14,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final slot = size.width / _shape.length;
    final barWidth = slot * 0.58;
    final turn = phase * math.pi * 2;
    for (var i = 0; i < _shape.length; i++) {
      final pulse = 0.62 + 0.38 * math.sin(turn + i * 0.62);
      final height = (size.height * _shape[i] * pulse).clamp(5.0, size.height);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(slot * i + slot / 2, size.height / 2),
            width: barWidth,
            height: height,
          ),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StartupWavePainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.color != color;
  }
}
