import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PodavioLogo extends StatelessWidget {
  const PodavioLogo({super.key, this.width = 240});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/brand/logo.svg',
      width: width,
      semanticsLabel: 'Podavio',
    );
  }
}

class PodavioIcon extends StatelessWidget {
  const PodavioIcon({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/brand/icon.svg',
      width: size,
      height: size,
      semanticsLabel: 'Podavio',
    );
  }
}
