import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

/// A tactile, mechanical-looking spinner replacing CircularProgressIndicator.
class YamiTactileLoader extends StatefulWidget {
  final double size;
  final Color? activeColor;

  const YamiTactileLoader({
    super.key,
    this.size = 24.0,
    this.activeColor,
  });

  @override
  State<YamiTactileLoader> createState() => _YamiTactileLoaderState();
}

class _YamiTactileLoaderState extends State<YamiTactileLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.activeColor ?? YamiTheme.accentActive;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _TactileLoaderPainter(
              progress: _controller.value,
              activeColor: color,
            ),
          );
        },
      ),
    );
  }
}

class _TactileLoaderPainter extends CustomPainter {
  final double progress;
  final Color activeColor;

  _TactileLoaderPainter({
    required this.progress,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    final strokeWidth = radius * 0.25;

    // Background track (sunken metallic ring)
    final trackPaint = Paint()
      ..color = YamiTheme.surfaceBase
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius - strokeWidth / 2, trackPaint);

    // Inner shadow simulation for the track
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawCircle(
        center.translate(0, 1), radius - strokeWidth / 2, shadowPaint);

    // Active arc
    final arcPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.7
      ..strokeCap = StrokeCap.square; // Hardware-like, not round

    final startAngle = progress * 2 * pi;
    final sweepAngle = pi * 0.75 + (sin(progress * 2 * pi) * pi * 0.25);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_TactileLoaderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor;
  }
}

/// A sequential slot loader replacing LinearProgressIndicator.
class YamiLinearLoader extends StatefulWidget {
  final int slots;
  final double width;
  final double height;
  final Color? activeColor;

  const YamiLinearLoader({
    super.key,
    this.slots = 5,
    this.width = 100.0,
    this.height = 6.0,
    this.activeColor,
  });

  @override
  State<YamiLinearLoader> createState() => _YamiLinearLoaderState();
}

class _YamiLinearLoaderState extends State<YamiLinearLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.activeColor ?? YamiTheme.accentActive;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final currentSlot = (_controller.value * widget.slots).floor();

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(widget.slots, (index) {
              final isActive = index == currentSlot;
              final isPassed = index < currentSlot;

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                      right: index < widget.slots - 1 ? 2.0 : 0.0),
                  decoration: BoxDecoration(
                    color: isActive
                        ? color
                        : (isPassed
                            ? color.withValues(alpha: 0.3)
                            : YamiTheme.surfaceBase),
                    borderRadius: BorderRadius.circular(1.0),
                    border: Border.all(
                      color: isActive
                          ? color
                          : YamiTheme.borderMid.withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 4.0,
                              spreadRadius: 0.5,
                            )
                          ]
                        : [],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
