import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GymIcon extends StatelessWidget {
  const GymIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.color,
  });

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}
