import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/card_customization_service.dart';

class CardDecorationDefinition {
  const CardDecorationDefinition({
    required this.id,
    required this.label,
    required this.category,
  });

  final String id;
  final String label;
  final String category;
}

const cardDecorationCatalog = <CardDecorationDefinition>[
  CardDecorationDefinition(id: 'pink_bow', label: '분홍 리본', category: '머리'),
  CardDecorationDefinition(id: 'red_headband', label: '빨간 머리띠', category: '머리'),
  CardDecorationDefinition(id: 'blue_headband', label: '파란 머리띠', category: '머리'),
  CardDecorationDefinition(id: 'mint_headband', label: '민트 머리띠', category: '머리'),
  CardDecorationDefinition(id: 'heart_pair', label: '하트 두 개', category: '포인트'),
  CardDecorationDefinition(id: 'heart_bubble', label: '하트 말풍선', category: '포인트'),
  CardDecorationDefinition(id: 'sparkle', label: '반짝이', category: '포인트'),
  CardDecorationDefinition(id: 'daisy', label: '데이지', category: '머리'),
  CardDecorationDefinition(id: 'sprout', label: '새싹', category: '머리'),
  CardDecorationDefinition(id: 'halo', label: '천사 링', category: '머리'),
  CardDecorationDefinition(id: 'round_glasses', label: '동그란 안경', category: '얼굴'),
  CardDecorationDefinition(id: 'star_glasses', label: '별 안경', category: '얼굴'),
];

class CardDecorationVisual extends StatelessWidget {
  const CardDecorationVisual({
    super.key,
    required this.assetId,
    required this.size,
  });

  final String assetId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _DecorationPainter(assetId)),
      ),
    );
  }
}

class CardDecorationOverlay extends StatelessWidget {
  const CardDecorationOverlay({
    super.key,
    required this.placement,
    required this.cardWidth,
    required this.cardHeight,
  });

  final CardDecorationPlacement placement;
  final double cardWidth;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    final baseSize = cardWidth * 0.16;
    final size = baseSize * placement.scale;
    return Positioned(
      left: placement.x * cardWidth - size / 2,
      top: placement.y * cardHeight - size / 2,
      width: size,
      height: size,
      child: Transform.rotate(
        angle: placement.rotation * math.pi / 180,
        child: CardDecorationVisual(assetId: placement.assetId, size: size),
      ),
    );
  }
}

class _DecorationPainter extends CustomPainter {
  const _DecorationPainter(this.id);

  final String id;

  static const _outline = Color(0xFF5A3428);
  static const _pink = Color(0xFFFF91AF);
  static const _red = Color(0xFFF46A67);
  static const _blue = Color(0xFF79B7EA);
  static const _mint = Color(0xFF86D7B1);
  static const _yellow = Color(0xFFFFD85C);
  static const _cream = Color(0xFFFFF9E9);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final fill = Paint()..style = PaintingStyle.fill;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _outline;

    switch (id) {
      case 'pink_bow':
        _bow(canvas, fill, line, _pink);
        break;
      case 'red_headband':
        _headband(canvas, fill, line, _red);
        break;
      case 'blue_headband':
        _headband(canvas, fill, line, _blue);
        break;
      case 'mint_headband':
        _headband(canvas, fill, line, _mint);
        break;
      case 'heart_pair':
        _heart(canvas, const Offset(37, 46), 25, _pink, fill, line);
        _heart(canvas, const Offset(65, 60), 19, _red, fill, line);
        break;
      case 'heart_bubble':
        final bubble = Path()
          ..moveTo(18, 24)
          ..quadraticBezierTo(50, 8, 82, 24)
          ..quadraticBezierTo(94, 48, 76, 70)
          ..quadraticBezierTo(50, 84, 27, 68)
          ..lineTo(15, 83)
          ..lineTo(19, 61)
          ..quadraticBezierTo(7, 42, 18, 24)
          ..close();
        fill.color = _cream;
        canvas.drawPath(bubble, fill);
        canvas.drawPath(bubble, line);
        _heart(canvas, const Offset(51, 47), 19, _pink, fill, line);
        break;
      case 'sparkle':
        _spark(canvas, const Offset(50, 50), 37, _yellow, fill, line);
        _spark(canvas, const Offset(78, 25), 13, _cream, fill, line);
        break;
      case 'daisy':
        for (var i = 0; i < 8; i++) {
          final angle = i * math.pi / 4;
          final center = Offset(
            50 + math.cos(angle) * 23,
            50 + math.sin(angle) * 23,
          );
          fill.color = _cream;
          canvas.drawOval(
            Rect.fromCenter(center: center, width: 24, height: 34),
            fill,
          );
          canvas.drawOval(
            Rect.fromCenter(center: center, width: 24, height: 34),
            line,
          );
        }
        fill.color = _yellow;
        canvas.drawCircle(const Offset(50, 50), 15, fill);
        canvas.drawCircle(const Offset(50, 50), 15, line);
        break;
      case 'sprout':
        line.strokeWidth = 6;
        line.color = _mint;
        canvas.drawLine(const Offset(50, 78), const Offset(50, 42), line);
        final left = Path()
          ..moveTo(49, 50)
          ..quadraticBezierTo(16, 45, 22, 17)
          ..quadraticBezierTo(53, 19, 49, 50)
          ..close();
        final right = Path()
          ..moveTo(51, 48)
          ..quadraticBezierTo(86, 43, 78, 15)
          ..quadraticBezierTo(50, 20, 51, 48)
          ..close();
        fill.color = _mint;
        canvas.drawPath(left, fill);
        canvas.drawPath(right, fill);
        line.color = _outline;
        line.strokeWidth = 5;
        canvas.drawPath(left, line);
        canvas.drawPath(right, line);
        break;
      case 'halo':
        fill.color = _yellow;
        canvas.drawOval(const Rect.fromLTWH(12, 30, 76, 34), fill);
        line.strokeWidth = 5;
        canvas.drawOval(const Rect.fromLTWH(12, 30, 76, 34), line);
        fill.color = _cream;
        canvas.drawOval(const Rect.fromLTWH(25, 39, 50, 16), fill);
        break;
      case 'round_glasses':
        line.strokeWidth = 6;
        canvas.drawCircle(const Offset(31, 51), 22, line);
        canvas.drawCircle(const Offset(69, 51), 22, line);
        canvas.drawLine(const Offset(53, 48), const Offset(47, 48), line);
        canvas.drawLine(const Offset(9, 43), const Offset(1, 38), line);
        canvas.drawLine(const Offset(91, 43), const Offset(99, 38), line);
        break;
      case 'star_glasses':
        _starOutline(canvas, const Offset(29, 50), 25, line);
        _starOutline(canvas, const Offset(71, 50), 25, line);
        canvas.drawLine(const Offset(47, 49), const Offset(53, 49), line);
        break;
      default:
        _spark(canvas, const Offset(50, 50), 34, _yellow, fill, line);
        break;
    }
    canvas.restore();
  }

  void _bow(Canvas canvas, Paint fill, Paint line, Color color) {
    final left = Path()
      ..moveTo(47, 49)
      ..cubicTo(24, 16, 7, 27, 14, 57)
      ..cubicTo(21, 82, 39, 72, 48, 57)
      ..close();
    final right = Path()
      ..moveTo(53, 49)
      ..cubicTo(76, 16, 93, 27, 86, 57)
      ..cubicTo(79, 82, 61, 72, 52, 57)
      ..close();
    fill.color = color;
    canvas.drawPath(left, fill);
    canvas.drawPath(right, fill);
    canvas.drawPath(left, line);
    canvas.drawPath(right, line);
    canvas.drawCircle(const Offset(50, 53), 13, fill);
    canvas.drawCircle(const Offset(50, 53), 13, line);
  }

  void _headband(Canvas canvas, Paint fill, Paint line, Color color) {
    final band = Path()
      ..moveTo(12, 66)
      ..quadraticBezierTo(50, 14, 88, 66)
      ..lineTo(78, 74)
      ..quadraticBezierTo(50, 34, 22, 74)
      ..close();
    fill.color = color;
    canvas.drawPath(band, fill);
    canvas.drawPath(band, line);
    final knot = Path()
      ..moveTo(75, 63)
      ..lineTo(95, 50)
      ..lineTo(90, 78)
      ..close();
    canvas.drawPath(knot, fill);
    canvas.drawPath(knot, line);
  }

  void _heart(
    Canvas canvas,
    Offset center,
    double size,
    Color color,
    Paint fill,
    Paint line,
  ) {
    final x = center.dx;
    final y = center.dy;
    final s = size;
    final path = Path()
      ..moveTo(x, y + s * 0.45)
      ..cubicTo(
        x - s * 0.95,
        y - s * 0.10,
        x - s * 0.72,
        y - s * 0.82,
        x,
        y - s * 0.30,
      )
      ..cubicTo(
        x + s * 0.72,
        y - s * 0.82,
        x + s * 0.95,
        y - s * 0.10,
        x,
        y + s * 0.45,
      )
      ..close();
    fill.color = color;
    canvas.drawPath(path, fill);
    canvas.drawPath(path, line);
  }

  void _spark(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    Paint fill,
    Paint line,
  ) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + i * math.pi / 4;
      final r = i.isEven ? radius : radius * 0.22;
      final p = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    fill.color = color;
    canvas.drawPath(path, fill);
    canvas.drawPath(path, line);
  }

  void _starOutline(Canvas canvas, Offset center, double radius, Paint line) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final r = i.isEven ? radius : radius * 0.45;
      final p = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _DecorationPainter oldDelegate) =>
      oldDelegate.id != id;
}
