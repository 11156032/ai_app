import 'dart:math' as math;
import 'package:flutter/material.dart';

// ======================================================
//  ParticleData — 3-layer particle data structure
// ======================================================
class ParticleData {
  final double x;
  final double y;
  final double radius;
  final double speed;
  final double phase;
  final int layer; // 0 = 遠景, 1 = 中景, 2 = 近景

  const ParticleData({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.phase,
    this.layer = 1,
  });
}

// ======================================================
//  NebulaPainter — Soft drifting nebula clouds
// ======================================================
class NebulaPainter extends CustomPainter {
  final double time;
  final double scrollOffset;
  final Color primaryColor;

  NebulaPainter({
    required this.time,
    required this.scrollOffset,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = time * 2 * math.pi;
    final purpleAccentColor =
        Color.lerp(primaryColor, Colors.purpleAccent, 0.5)!;
    final blueAccentColor = Color.lerp(primaryColor, Colors.blueAccent, 0.4)!;
    final deepPurpleColor = Color.lerp(primaryColor, Colors.deepPurple, 0.55)!;

    // (relX, relY, radiusX, radiusY, driftPhase, alpha, color)
    final blobs = [
      (0.14, 0.10, 190.0, 130.0, 0.0, 0.070, primaryColor),
      (0.82, 0.20, 155.0, 105.0, 1.2, 0.055, purpleAccentColor),
      (0.32, 0.72, 205.0, 135.0, 2.4, 0.062, blueAccentColor),
      (0.72, 0.82, 145.0, 92.0, 3.7, 0.048, deepPurpleColor),
    ];

    for (final blob in blobs) {
      final relX = blob.$1;
      final relY = blob.$2;
      final rX = blob.$3;
      final rY = blob.$4;
      final phase = blob.$5;
      final alpha = blob.$6;
      final color = blob.$7;

      final driftX = math.sin(t * 0.28 + phase) * 18.0;
      final driftY = math.cos(t * 0.19 + phase) * 13.0 - scrollOffset * 0.11;

      final cx = relX * size.width + driftX;
      final cy = relY * size.height + driftY;

      final rect = Rect.fromCenter(
          center: Offset(cx, cy), width: rX * 2, height: rY * 2);

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * 0.38),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect);

      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(1.0, rY / rX);
      canvas.translate(-cx, -cy);
      canvas.drawCircle(Offset(cx, cy), rX, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(NebulaPainter old) =>
      old.time != time || old.scrollOffset != scrollOffset;
}

// ======================================================
//  FlowGridPainter — Animated hexagonal grid
// ======================================================
class FlowGridPainter extends CustomPainter {
  final double time;
  final double scrollOffset;
  final Color primaryColor;

  FlowGridPainter({
    required this.time,
    required this.scrollOffset,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    const hexR = 22.0;
    final hexW = math.sqrt(3) * hexR; // ~38.1
    const hexH = 2.0 * hexR; // 44.0
    const rowStep = hexH * 0.75; // 33.0

    final t = time * 2 * math.pi;
    // Grid drifts slowly downward with scroll for parallax depth
    final yShift = (scrollOffset * 0.055) % rowStep;

    final linePaint = Paint()
      ..strokeWidth = 0.55
      ..style = PaintingStyle.stroke;

    final nodePaint = Paint();
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    int nodeIndex = 0;
    final colCount = (size.width / hexW + 3).ceil();
    final rowCount = (size.height / rowStep + 3).ceil();

    for (int col = -1; col < colCount; col++) {
      for (int row = -1; row < rowCount; row++) {
        final cx = col * hexW + (row.isOdd ? hexW * 0.5 : 0.0);
        final cy = row * rowStep + yShift;

        // Each node pulses independently
        final pulse = math.sin(t * 0.55 + nodeIndex * 0.43) * 0.5 + 0.5;
        final lineAlpha = 0.022 + pulse * 0.022;
        final nodeAlpha = 0.028 + pulse * 0.042;

        // Hex outline
        final path = Path();
        for (int v = 0; v <= 6; v++) {
          final angle = (v * 60 - 30) * math.pi / 180.0;
          final px = cx + hexR * math.cos(angle);
          final py = cy + hexR * math.sin(angle);
          if (v == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        path.close();
        linePaint.color = primaryColor.withValues(alpha: lineAlpha);
        canvas.drawPath(path, linePaint);

        // Center node dot
        nodePaint.color = primaryColor.withValues(alpha: nodeAlpha);
        canvas.drawCircle(Offset(cx, cy), 1.2, nodePaint);

        // Periodic glow nodes (every 11th)
        if (nodeIndex % 11 == 0) {
          glowPaint.color = primaryColor.withValues(alpha: pulse * 0.075);
          canvas.drawCircle(Offset(cx, cy), 4.0, glowPaint);
        }

        nodeIndex++;
      }
    }
  }

  @override
  bool shouldRepaint(FlowGridPainter old) =>
      old.time != time || old.scrollOffset != scrollOffset;
}

// ======================================================
//  OrbitalSpherePainter — Pure Flutter 3D
// ======================================================
class OrbitalSpherePainter extends CustomPainter {
  final double rotation;
  final Color primaryColor;

  OrbitalSpherePainter({required this.rotation, required this.primaryColor});

  Offset _project(double x, double y, double z, Offset center) {
    const f = 480.0;
    final p = f / (f + z * 0.18);
    return Offset(center.dx + x * p, center.dy + y * p);
  }

  (double, double, double) _rotY(double x, double y, double z, double a) {
    final c = math.cos(a), s = math.sin(a);
    return (x * c + z * s, y, -x * s + z * c);
  }

  (double, double, double) _rotX(double x, double y, double z, double a) {
    final c = math.cos(a), s = math.sin(a);
    return (x, y * c - z * s, y * s + z * c);
  }

  void _drawRing(Canvas canvas, Offset center, double radius, double tiltX,
      double phaseY, Color color, double sw) {
    const seg = 96;
    final path = Path();
    bool started = false;
    for (int i = 0; i <= seg; i++) {
      final angle = i * 2 * math.pi / seg;
      double x = radius * math.cos(angle),
          y = 0.0,
          z = radius * math.sin(angle);
      var (rx, ry, rz) = _rotX(x, y, z, tiltX);
      var (fx, fy, fz) = _rotY(rx, ry, rz, phaseY);
      final p = _project(fx, fy, fz, center);
      if (!started) {
        path.moveTo(p.dx, p.dy);
        started = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round);
  }

  void _drawNode(Canvas canvas, Offset center, double radius, double nodeAngle,
      double tiltX, double phaseY, Color color, double nodeR) {
    double x = radius * math.cos(nodeAngle),
        y = 0.0,
        z = radius * math.sin(nodeAngle);
    var (rx, ry, rz) = _rotX(x, y, z, tiltX);
    var (fx, fy, fz) = _rotY(rx, ry, rz, phaseY);
    final p = _project(fx, fy, fz, center);
    final depth = ((fz + radius) / (2 * radius)).clamp(0.2, 1.0);
    final r = nodeR * (0.8 + depth * 0.4);
    canvas.drawCircle(
        p,
        r * 2.8,
        Paint()
          ..color = color.withValues(alpha: 0.16 * depth)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(
        p,
        r,
        Paint()
          ..color = color.withValues(alpha: (0.5 + depth * 0.5).clamp(0, 1)));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 16);
    final pc = primaryColor;
    final accent = Color.lerp(pc, Colors.purpleAccent, 0.45)!;

    canvas.drawCircle(
        center,
        130,
        Paint()
          ..shader = RadialGradient(colors: [
            pc.withValues(alpha: 0.22),
            pc.withValues(alpha: 0.0),
          ]).createShader(Rect.fromCircle(center: center, radius: 130)));

    _drawRing(
        canvas, center, 90, 1.15, rotation, pc.withValues(alpha: 0.72), 1.5);
    for (int i = 0; i < 3; i++) {
      _drawNode(canvas, center, 90, rotation + i * 2 * math.pi / 3, 1.15,
          rotation, pc, 5.5);
    }
    _drawRing(canvas, center, 114, -0.75, -rotation * 0.8,
        accent.withValues(alpha: 0.48), 1.2);
    for (int i = 0; i < 4; i++) {
      _drawNode(canvas, center, 114, -rotation * 0.8 + i * math.pi / 2, -0.75,
          -rotation * 0.8, accent, 4.0);
    }
    _drawRing(canvas, center, 68, 0.22, rotation * 1.3,
        Colors.white.withValues(alpha: 0.22), 1.0);

    canvas.drawCircle(
        center,
        34,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.35),
            colors: [
              Colors.white.withValues(alpha: 0.95),
              pc.withValues(alpha: 0.9),
              pc.withValues(alpha: 0.4),
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: 34)));
    canvas.drawCircle(
        center + const Offset(-10, -10),
        10,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawCircle(
        center,
        38,
        Paint()
          ..color = pc.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);
  }

  @override
  bool shouldRepaint(OrbitalSpherePainter old) => old.rotation != rotation;
}

// ======================================================
//  ParticlePainter — 3-layer depth floating particles
// ======================================================
class ParticlePainter extends CustomPainter {
  final List<ParticleData> particles;
  final double time;
  final double scrollOffset;
  final Color primaryColor;

  ParticlePainter({
    required this.particles,
    required this.time,
    required this.scrollOffset,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final accent = Color.lerp(primaryColor, Colors.purpleAccent, 0.35)!;

    for (final p in particles) {
      final x = p.x * size.width;
      final rawY = p.y * size.height - scrollOffset * p.speed;
      final y = rawY % size.height;
      final pulse = (math.sin(time * 2 * math.pi * 1.5 + p.phase) * 0.35 + 0.5)
          .clamp(0.0, 1.0);

      final double baseAlpha;
      final double blurFactor;
      final Color color;

      if (p.layer == 0) {
        // Far: small, dim, purple-tinted
        baseAlpha = 0.26;
        blurFactor = 0.65;
        color = Color.lerp(primaryColor, accent, 0.65)!;
      } else if (p.layer == 2) {
        // Near: large, bright, with halo glow
        baseAlpha = 0.68;
        blurFactor = 1.5;
        color = Color.lerp(primaryColor, Colors.white, 0.22)!;
        // Extra soft halo
        canvas.drawCircle(
          Offset(x, y),
          p.radius * 2.4,
          Paint()
            ..color = primaryColor.withValues(alpha: pulse * 0.11)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.radius * 2.2),
        );
      } else {
        // Mid: default
        baseAlpha = 0.46;
        blurFactor = 0.95;
        color = primaryColor;
      }

      canvas.drawCircle(
        Offset(x, y),
        p.radius,
        Paint()
          ..color = color.withValues(alpha: pulse * baseAlpha)
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, p.radius * blurFactor),
      );
    }
  }

  @override
  bool shouldRepaint(ParticlePainter old) =>
      old.time != time || old.scrollOffset != scrollOffset;
}

// ======================================================
//  ShimmerPainter — Diagonal sweep light on Mission Card
// ======================================================
class ShimmerPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;

  ShimmerPainter({required this.progress, required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    const shimmerHalfW = 90.0;
    const tilt = 32.0;
    // Sweep from left-off to right-off
    final x = -shimmerHalfW -
        tilt +
        (size.width + (shimmerHalfW + tilt) * 2) * progress;

    final path = Path()
      ..moveTo(x - shimmerHalfW - tilt, 0)
      ..lineTo(x + shimmerHalfW - tilt, 0)
      ..lineTo(x + shimmerHalfW + tilt, size.height)
      ..lineTo(x - shimmerHalfW + tilt, size.height)
      ..close();

    final shaderRect = Rect.fromLTWH(
        x - shimmerHalfW - tilt, 0, (shimmerHalfW + tilt) * 2, size.height);

    final gradient = LinearGradient(
      colors: [
        Colors.transparent,
        primaryColor.withValues(alpha: 0.09),
        Colors.white.withValues(alpha: 0.07),
        primaryColor.withValues(alpha: 0.09),
        Colors.transparent,
      ],
      stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
    );

    canvas.drawPath(path, Paint()..shader = gradient.createShader(shaderRect));
  }

  @override
  bool shouldRepaint(ShimmerPainter old) => old.progress != progress;
}
