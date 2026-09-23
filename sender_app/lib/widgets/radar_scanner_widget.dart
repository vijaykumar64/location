import 'dart:math' as math;
import 'package:flutter/material.dart';

class RadarScannerWidget extends StatefulWidget {
  final bool isActive;
  final double size;

  const RadarScannerWidget({
    super.key,
    required this.isActive,
    this.size = 240,
  });

  @override
  State<RadarScannerWidget> createState() => _RadarScannerWidgetState();
}

class _RadarScannerWidgetState extends State<RadarScannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(RadarScannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated Radar Painter
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _RadarPainter(
                  rotation: _controller.value * 2 * math.pi,
                  isActive: widget.isActive,
                ),
              );
            },
          ),

          // Central Glowing Core
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isActive
                  ? const Color(0xFF06B6D4)
                  : const Color(0xFF64748B),
              boxShadow: [
                BoxShadow(
                  color: widget.isActive
                      ? const Color(0xFF06B6D4).withAlpha(180)
                      : Colors.transparent,
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: widget.isActive
                      ? const Color(0xFF8B5CF6).withAlpha(150)
                      : Colors.transparent,
                  blurRadius: 28,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Active / Scanning Floating Pill
          Positioned(
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0E1A).withAlpha(220),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isActive
                      ? const Color(0xFF10B981).withAlpha(160)
                      : const Color(0xFF64748B).withAlpha(100),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isActive
                        ? const Color(0xFF10B981).withAlpha(60)
                        : Colors.transparent,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isActive
                          ? const Color(0xFF10B981)
                          : const Color(0xFF94A3B8),
                      boxShadow: widget.isActive
                          ? [
                              const BoxShadow(
                                color: Color(0xFF10B981),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.isActive ? 'ACTIVE' : 'PAUSED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: widget.isActive
                          ? const Color(0xFF10B981)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double rotation;
  final bool isActive;

  _RadarPainter({
    required this.rotation,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // 1. Draw outer ambient glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isActive ? const Color(0xFF8B5CF6) : const Color(0xFF334155))
              .withAlpha(isActive ? 45 : 15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius, glowPaint);

    // 2. Draw Concentric Rings
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rings = [0.28, 0.52, 0.76, 1.0];
    for (int i = 0; i < rings.length; i++) {
      final r = maxRadius * rings[i];
      final isOuter = i == rings.length - 1;
      ringPaint.color = isActive
          ? (isOuter
              ? const Color(0xFF8B5CF6).withAlpha(100)
              : const Color(0xFF06B6D4).withAlpha(45))
          : const Color(0xFF334155).withAlpha(50);
      ringPaint.strokeWidth = isOuter ? 1.5 : 1.0;
      canvas.drawCircle(center, r, ringPaint);
    }

    // 3. Draw Crosshairs & Diagonal Tech Ticks
    final gridPaint = Paint()
      ..color = (isActive ? const Color(0xFF38BDF8) : const Color(0xFF475569))
          .withAlpha(isActive ? 35 : 20)
      ..strokeWidth = 0.8;

    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      gridPaint,
    );

    // 4. Draw Rotating Radar Sweep Gradient
    if (isActive) {
      final sweepPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = SweepGradient(
          startAngle: 0.0,
          endAngle: math.pi / 2,
          colors: [
            const Color(0xFF06B6D4).withAlpha(0),
            const Color(0xFF06B6D4).withAlpha(60),
            const Color(0xFF8B5CF6).withAlpha(120),
          ],
          transform: GradientRotation(rotation - math.pi / 2),
        ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

      canvas.drawCircle(center, maxRadius * 0.98, sweepPaint);

      // Leading beam line
      final beamPaint = Paint()
        ..color = const Color(0xFF38BDF8).withAlpha(200)
        ..strokeWidth = 2.0;

      final beamEnd = Offset(
        center.dx + maxRadius * 0.98 * math.cos(rotation),
        center.dy + maxRadius * 0.98 * math.sin(rotation),
      );
      canvas.drawLine(center, beamEnd, beamPaint);
    }

    // 5. Draw Orbiting Node Blips (Simulated radar targets)
    final blipPaint = Paint()..style = PaintingStyle.fill;
    final blips = [
      {'dist': 0.42, 'angle': 0.8, 'color': const Color(0xFF38BDF8)},
      {'dist': 0.65, 'angle': 2.3, 'color': const Color(0xFF8B5CF6)},
      {'dist': 0.82, 'angle': 4.1, 'color': const Color(0xFF10B981)},
    ];

    for (final b in blips) {
      final d = (b['dist'] as double) * maxRadius;
      final a = (b['angle'] as double) + (isActive ? rotation * 0.1 : 0);
      final c = b['color'] as Color;
      final blipPos = Offset(
        center.dx + d * math.cos(a),
        center.dy + d * math.sin(a),
      );

      blipPaint.color = isActive ? c.withAlpha(220) : const Color(0xFF64748B);
      canvas.drawCircle(blipPos, 3.5, blipPaint);

      if (isActive) {
        blipPaint.color = c.withAlpha(70);
        canvas.drawCircle(blipPos, 8.0, blipPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.rotation != rotation || oldDelegate.isActive != isActive;
  }
}
