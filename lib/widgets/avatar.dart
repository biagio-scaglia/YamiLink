import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

class YamiAvatar extends StatelessWidget {
  final int seed;
  final double size;
  final Color? glowColor;
  final bool isGlowing;

  const YamiAvatar({
    super.key,
    required this.seed,
    this.size = 50,
    this.glowColor,
    this.isGlowing = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeGlowColor = glowColor ?? YamiTheme.glowActive;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isGlowing ? activeGlowColor : YamiTheme.borderGlass,
          width: isGlowing ? 1.5 : 1.0,
        ),
        boxShadow: isGlowing
            ? [
                BoxShadow(
                  color: activeGlowColor.withOpacity(0.25),
                  blurRadius: 8.0,
                  spreadRadius: 1.0,
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: CustomPaint(
          size: Size(size, size),
          painter: YamiAvatarPainter(seed: seed, glowColor: activeGlowColor),
        ),
      ),
    );
  }
}

class YamiAvatarPainter extends CustomPainter {
  final int seed;
  final Color glowColor;

  YamiAvatarPainter({required this.seed, required this.glowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    final width = size.width;
    final height = size.height;
    final center = Offset(width / 2, height / 2);
    final maxRadius = min(width, height) / 2;

    // Draw background subtle gradient based on seed
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.fromARGB(
            120,
            random.nextInt(100) + 10,
            random.nextInt(100) + 10,
            random.nextInt(150) + 80,
          ),
          YamiTheme.surfaceDark,
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

    // Dynamic geometry drawing based on random seed
    final geometryType = random.nextInt(4);
    final strokePaint = Paint()
      ..color = glowColor.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final fillPaint = Paint()
      ..color = glowColor.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    // Center indicator
    canvas.drawCircle(
      center,
      maxRadius * 0.15,
      fillPaint..color = glowColor.withOpacity(0.3),
    );

    if (geometryType == 0) {
      // Concentric rings with rotating segments
      canvas.drawCircle(center, maxRadius * 0.4, strokePaint);
      canvas.drawCircle(
        center,
        maxRadius * 0.7,
        strokePaint..strokeWidth = 0.8,
      );

      // Crosshair lines
      canvas.drawLine(
        Offset(width * 0.15, height / 2),
        Offset(width * 0.85, height / 2),
        strokePaint,
      );
      canvas.drawLine(
        Offset(width / 2, height * 0.15),
        Offset(width / 2, height * 0.85),
        strokePaint,
      );
    } else if (geometryType == 1) {
      // Triangle structures
      final path = Path();
      path.moveTo(center.dx, center.dy - maxRadius * 0.75);
      path.lineTo(center.dx - maxRadius * 0.65, center.dy + maxRadius * 0.5);
      path.lineTo(center.dx + maxRadius * 0.65, center.dy + maxRadius * 0.5);
      path.close();
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);

      // Inverted inner triangle
      final innerPath = Path();
      innerPath.moveTo(center.dx, center.dy + maxRadius * 0.45);
      innerPath.lineTo(
        center.dx - maxRadius * 0.35,
        center.dy - maxRadius * 0.2,
      );
      innerPath.lineTo(
        center.dx + maxRadius * 0.35,
        center.dy - maxRadius * 0.2,
      );
      innerPath.close();
      canvas.drawPath(
        innerPath,
        strokePaint..color = YamiTheme.glowAmbient.withOpacity(0.7),
      );
    } else if (geometryType == 2) {
      // Intersecting nodes (graph network visual)
      final points = <Offset>[];
      final nodeCount = 5 + random.nextInt(4);
      for (int i = 0; i < nodeCount; i++) {
        final angle = random.nextDouble() * 2 * pi;
        final dist = (0.25 + random.nextDouble() * 0.55) * maxRadius;
        points.add(
          Offset(center.dx + cos(angle) * dist, center.dy + sin(angle) * dist),
        );
      }

      // Draw connections
      for (int i = 0; i < points.length; i++) {
        for (int j = i + 1; j < points.length; j++) {
          if (random.nextDouble() > 0.4) {
            canvas.drawLine(
              points[i],
              points[j],
              strokePaint..color = glowColor.withOpacity(0.2),
            );
          }
        }
      }

      // Draw nodes
      for (var point in points) {
        canvas.drawCircle(point, 3, fillPaint..color = glowColor);
        canvas.drawCircle(
          point,
          5,
          strokePaint
            ..color = glowColor.withOpacity(0.5)
            ..strokeWidth = 0.5,
        );
      }
    } else {
      // Circular radar scan arc with orbiting satellites
      canvas.drawCircle(
        center,
        maxRadius * 0.55,
        strokePaint..color = glowColor.withOpacity(0.4),
      );

      final orbitCount = 2 + random.nextInt(3);
      for (int i = 0; i < orbitCount; i++) {
        final angle = random.nextDouble() * 2 * pi;
        final orbitRadius = maxRadius * (0.3 + (i * 0.25));
        final satellite = Offset(
          center.dx + cos(angle) * orbitRadius,
          center.dy + sin(angle) * orbitRadius,
        );
        canvas.drawCircle(
          satellite,
          4,
          fillPaint..color = YamiTheme.glowAmbient,
        );
        canvas.drawLine(
          center,
          satellite,
          strokePaint
            ..color = YamiTheme.borderGlass
            ..strokeWidth = 0.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant YamiAvatarPainter oldDelegate) {
    return oldDelegate.seed != seed || oldDelegate.glowColor != glowColor;
  }
}
