import 'package:flutter/material.dart';

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
