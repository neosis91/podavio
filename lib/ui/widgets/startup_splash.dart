import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icône SVG affichée le temps que l’application s’ouvre.
class StartupSplash extends StatefulWidget {
  const StartupSplash({super.key, required this.child});

  final Widget child;

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _leave;
  var _show = true;

  @override
  void initState() {
    super.initState();
    _leave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _holdThenLeave());
  }

  void _holdThenLeave() {
    if (!mounted) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
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
            opacity: Tween<double>(
              begin: 1,
              end: 0,
            ).animate(CurvedAnimation(parent: _leave, curve: Curves.easeOut)),
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Center(
                child: SvgPicture.asset(
                  'assets/brand/icon.svg',
                  width: 240,
                  height: 88,
                  semanticsLabel: 'Podavio',
                ),
              ),
            ),
          ),
      ],
    );
  }
}
