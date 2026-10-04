import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Full-screen illustrated scenery shared by every JLPTmaster route.
///
/// Light mode keeps the blue-sky meadow artwork. Dark mode uses the cave
/// artwork plus a lightweight painted cave frame/lantern so the cave mood is
/// always visible even on narrow phones where BoxFit.cover crops the sides.
class AppSceneBackground extends StatelessWidget {
  const AppSceneBackground({
    super.key,
    required this.child,
    this.playful = false,
  });

  final Widget child;
  final bool playful;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final asset = dark
        ? 'assets/scenes/cave_dark.webp'
        : 'assets/scenes/meadow_light.webp';

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: dark ? const Color(0xFF080D14) : const Color(0xFFF3FAEC),
          ),
        ),
        Positioned.fill(
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.high,
          ),
        ),
        if (dark)
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _CaveFramePainter()),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark
                    ? const [
                        Color(0x00070B12),
                        Color(0x0B070B12),
                        Color(0x22070B12),
                      ]
                    : const [
                        Color(0x05FFFFFF),
                        Color(0x0AFFFFFF),
                        Color(0x20F6FBEF),
                      ],
                stops: const [0, 0.56, 1],
              ),
            ),
          ),
        ),
        if (!playful)
          Positioned.fill(
            child: ColoredBox(
              color: dark
                  ? const Color(0x08040A11)
                  : const Color(0x06FFFFFF),
            ),
          ),
        child,
      ],
    );
  }
}

class _CaveFramePainter extends CustomPainter {
  const _CaveFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final edge = Paint()..color = const Color(0xB8131C2A);
    final edge2 = Paint()..color = const Color(0xB91C2635);
    final line = Paint()
      ..color = const Color(0x88465362)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, w * 0.0024);

    // Rocky ceiling. Keep the centre open enough for titles/mascot while still
    // making the environment unmistakably cave-like.
    _rock(canvas, Rect.fromLTWH(-0.08 * w, -0.055 * h, 0.34 * w, 0.16 * h), edge, line);
    _rock(canvas, Rect.fromLTWH(0.17 * w, -0.04 * h, 0.27 * w, 0.13 * h), edge2, line);
    _rock(canvas, Rect.fromLTWH(0.39 * w, -0.06 * h, 0.30 * w, 0.15 * h), edge, line);
    _rock(canvas, Rect.fromLTWH(0.64 * w, -0.045 * h, 0.37 * w, 0.17 * h), edge2, line);

    // Side walls are intentionally slim so cards stay clean and readable.
    _rock(canvas, Rect.fromLTWH(-0.15 * w, 0.12 * h, 0.23 * w, 0.26 * h), edge, line);
    _rock(canvas, Rect.fromLTWH(-0.13 * w, 0.53 * h, 0.20 * w, 0.31 * h), edge2, line);
    _rock(canvas, Rect.fromLTWH(0.92 * w, 0.20 * h, 0.21 * w, 0.27 * h), edge2, line);
    _rock(canvas, Rect.fromLTWH(0.91 * w, 0.57 * h, 0.23 * w, 0.31 * h), edge, line);

    // Bottom cave-floor stones.
    _rock(canvas, Rect.fromLTWH(-0.06 * w, 0.91 * h, 0.31 * w, 0.14 * h), edge, line);
    _rock(canvas, Rect.fromLTWH(0.19 * w, 0.94 * h, 0.26 * w, 0.10 * h), edge2, line);
    _rock(canvas, Rect.fromLTWH(0.67 * w, 0.93 * h, 0.40 * w, 0.13 * h), edge, line);

    _paintLantern(canvas, size);
  }

  void _rock(Canvas canvas, Rect rect, Paint fill, Paint stroke) {
    final r = Radius.circular(math.min(rect.width, rect.height) * 0.38);
    final shape = RRect.fromRectAndRadius(rect, r);
    canvas.drawRRect(shape, fill);
    canvas.drawRRect(shape, stroke);
  }

  void _paintLantern(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.84;
    final top = h * 0.065;
    final lanternW = w * 0.095;
    final lanternH = lanternW * 1.34;

    final glow = Paint()
      ..shader = RadialGradient(
        colors: const [
          Color(0x66FFD27A),
          Color(0x22E6A64C),
          Color(0x00E6A64C),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(cx, top + lanternH * 0.62),
        radius: lanternW * 1.9,
      ));
    canvas.drawCircle(
      Offset(cx, top + lanternH * 0.62),
      lanternW * 1.9,
      glow,
    );

    final metal = Paint()
      ..color = const Color(0xFF7D542D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.0, w * 0.006)
      ..strokeCap = StrokeCap.round;
    final warm = Paint()..color = const Color(0xFFFFC867);
    final glass = Paint()..color = const Color(0x44FFD88A);

    // Small bracket and hook.
    final armY = top - lanternH * 0.17;
    canvas.drawLine(Offset(cx - lanternW * 0.12, armY), Offset(cx + lanternW * 1.05, armY), metal);
    canvas.drawLine(Offset(cx + lanternW * 1.03, armY), Offset(cx + lanternW * 1.03, top + lanternH * 0.10), metal);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, top - lanternH * 0.03),
        width: lanternW * 0.43,
        height: lanternH * 0.28,
      ),
      math.pi,
      math.pi,
      false,
      metal,
    );

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, top + lanternH * 0.48),
        width: lanternW,
        height: lanternH * 0.75,
      ),
      Radius.circular(lanternW * 0.14),
    );
    canvas.drawRRect(body, glass);
    canvas.drawRRect(body, metal);

    final flame = Path()
      ..moveTo(cx, top + lanternH * 0.24)
      ..quadraticBezierTo(
        cx + lanternW * 0.22,
        top + lanternH * 0.48,
        cx,
        top + lanternH * 0.66,
      )
      ..quadraticBezierTo(
        cx - lanternW * 0.22,
        top + lanternH * 0.48,
        cx,
        top + lanternH * 0.24,
      );
    canvas.drawPath(flame, warm);

    canvas.drawLine(
      Offset(cx - lanternW * 0.65, top + lanternH * 0.88),
      Offset(cx + lanternW * 0.65, top + lanternH * 0.88),
      metal,
    );

    // A few warm floating specks keep the cave cozy without becoming busy.
    final speck = Paint()..color = const Color(0xB8F1B85B);
    for (final p in [
      Offset(w * 0.73, h * 0.12),
      Offset(w * 0.90, h * 0.17),
      Offset(w * 0.13, h * 0.21),
      Offset(w * 0.80, h * 0.31),
    ]) {
      canvas.drawCircle(p, math.max(1.8, w * 0.004), speck);
    }
  }

  @override
  bool shouldRepaint(covariant _CaveFramePainter oldDelegate) => false;
}
