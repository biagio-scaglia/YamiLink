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
                  color: activeGlowColor.withOpacity(0.2),
                  blurRadius: 10.0,
                  spreadRadius: 0.5,
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

    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.fromARGB(
            100,
            random.nextInt(60) + 10,
            random.nextInt(60) + 10,
            random.nextInt(100) + 50,
          ),
          YamiTheme.surfaceDark,
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), bgPaint);

    final geometryType = random.nextInt(4);
    final strokePaint = Paint()
      ..color = glowColor.withOpacity(0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final fillPaint = Paint()
      ..color = glowColor.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final notchPaint = Paint()
      ..color = glowColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (int i = 0; i < 8; i++) {
      final angle = (i * pi) / 4;
      final start = Offset(
        center.dx + cos(angle) * (maxRadius - 4),
        center.dy + sin(angle) * (maxRadius - 4),
      );
      final end = Offset(
        center.dx + cos(angle) * maxRadius,
        center.dy + sin(angle) * maxRadius,
      );
      canvas.drawLine(start, end, notchPaint);
    }

    canvas.drawCircle(
      center,
      maxRadius * 0.12,
      fillPaint..color = glowColor.withOpacity(0.25),
    );

    if (geometryType == 0) {
      canvas.drawCircle(center, maxRadius * 0.45, strokePaint);
      canvas.drawCircle(
        center,
        maxRadius * 0.72,
        strokePaint..strokeWidth = 0.6,
      );

      canvas.drawLine(
        Offset(width * 0.18, height / 2),
        Offset(width * 0.82, height / 2),
        strokePaint..color = glowColor.withOpacity(0.4),
      );
      canvas.drawLine(
        Offset(width / 2, height * 0.18),
        Offset(width / 2, height * 0.82),
        strokePaint,
      );

      final angle1 = random.nextDouble() * 2 * pi;
      final angle2 = angle1 + pi / 3;
      canvas.drawCircle(
        Offset(
          center.dx + cos(angle1) * (maxRadius * 0.45),
          center.dy + sin(angle1) * (maxRadius * 0.45),
        ),
        3,
        fillPaint..color = glowColor,
      );
      canvas.drawCircle(
        Offset(
          center.dx + cos(angle2) * (maxRadius * 0.72),
          center.dy + sin(angle2) * (maxRadius * 0.72),
        ),
        2,
        fillPaint..color = glowColor.withOpacity(0.8),
      );
    } else if (geometryType == 1) {
      final path = Path();
      path.moveTo(center.dx, center.dy - maxRadius * 0.7);
      path.lineTo(center.dx - maxRadius * 0.6, center.dy + maxRadius * 0.4);
      path.lineTo(center.dx + maxRadius * 0.6, center.dy + maxRadius * 0.4);
      path.close();
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, strokePaint);

      final innerPath = Path();
      innerPath.moveTo(center.dx, center.dy + maxRadius * 0.35);
      innerPath.lineTo(
        center.dx - maxRadius * 0.3,
        center.dy - maxRadius * 0.2,
      );
      innerPath.lineTo(
        center.dx + maxRadius * 0.3,
        center.dy - maxRadius * 0.2,
      );
      innerPath.close();
      canvas.drawPath(
        innerPath,
        strokePaint..color = YamiTheme.glowAmbient.withOpacity(0.5),
      );
    } else if (geometryType == 2) {
      final points = <Offset>[];
      final nodeCount = 5 + random.nextInt(3);
      for (int i = 0; i < nodeCount; i++) {
        final angle = random.nextDouble() * 2 * pi;
        final dist = (0.3 + random.nextDouble() * 0.45) * maxRadius;
        points.add(
          Offset(center.dx + cos(angle) * dist, center.dy + sin(angle) * dist),
        );
      }

      for (int i = 0; i < points.length; i++) {
        for (int j = i + 1; j < points.length; j++) {
          if (random.nextDouble() > 0.4) {
            canvas.drawLine(
              points[i],
              points[j],
              strokePaint..color = glowColor.withOpacity(0.18),
            );
          }
        }
      }

      for (var point in points) {
        canvas.drawCircle(point, 3, fillPaint..color = glowColor);
        canvas.drawCircle(
          point,
          5,
          strokePaint
            ..color = glowColor.withOpacity(0.4)
            ..strokeWidth = 0.5,
        );
      }
    } else {
      canvas.drawCircle(
        center,
        maxRadius * 0.6,
        strokePaint..color = glowColor.withOpacity(0.35),
      );

      final orbitCount = 2 + random.nextInt(2);
      for (int i = 0; i < orbitCount; i++) {
        final angle = random.nextDouble() * 2 * pi;
        final orbitRadius = maxRadius * (0.35 + (i * 0.25));
        final satellite = Offset(
          center.dx + cos(angle) * orbitRadius,
          center.dy + sin(angle) * orbitRadius,
        );
        canvas.drawCircle(
          satellite,
          3.5,
          fillPaint..color = YamiTheme.glowAmbient,
        );
        canvas.drawLine(
          center,
          satellite,
          strokePaint
            ..color = YamiTheme.borderGlass
            ..strokeWidth = 0.4,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant YamiAvatarPainter oldDelegate) {
    return oldDelegate.seed != seed || oldDelegate.glowColor != glowColor;
  }
}
