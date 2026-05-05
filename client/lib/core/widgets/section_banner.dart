import 'package:flutter/material.dart';
import 'gym_icon.dart';

class SectionBanner extends StatelessWidget {
  const SectionBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.label,
    required this.accentColor,
    required this.iconName,
    required this.gradientColors,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String label;
  final Color accentColor;
  final String iconName;
  final List<Color> gradientColors;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 118,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Large faded icon — right side
              Positioned(
                right: 10,
                top: 6,
                child: Opacity(
                  opacity: 0.10,
                  child: GymIcon(iconName, size: 100, color: Colors.white),
                ),
              ),
              // Bío-Bío river wave — yellow signature element
              Positioned(
                right: 0,
                bottom: 26,
                child: CustomPaint(
                  size: const Size(210, 18),
                  painter: _WavePainter(opacity: 0.30),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 10,
                child: CustomPaint(
                  size: const Size(160, 14),
                  painter: _WavePainter(opacity: 0.16),
                ),
              ),
              // Text content — bottom left
              Positioned(
                left: 20,
                right: trailing != null ? 60 : 20,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withAlpha(110),
                        fontSize: 11,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              // Trailing action — top right
              if (trailing != null)
                Positioned(
                  right: 14,
                  top: 10,
                  child: trailing!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter({this.opacity = 0.28});
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF9B214).withAlpha((opacity * 255).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(0, h * 0.5);
    for (var i = 0; i < 3; i++) {
      final segment = w / 3;
      final x1 = segment * i + segment * 0.25;
      final x3 = segment * i + segment * 0.75;
      final x4 = segment * (i + 1);
      final yUp = i.isEven ? 0.0 : h;
      final yDown = i.isEven ? h : 0.0;
      path.cubicTo(x1, yUp, x3, yDown, x4, h * 0.5);
    }

    canvas.save();
    // fade from left to right
    final shader = LinearGradient(
      colors: [
        Colors.transparent,
        const Color(0xFFF9B214).withAlpha((opacity * 255).round()),
      ],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    paint.shader = shader;
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.opacity != opacity;
}

