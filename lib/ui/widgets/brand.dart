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
