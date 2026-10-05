import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/card_customization_service.dart';
import 'card_decoration.dart';

class UserProfileCard extends StatelessWidget {
  const UserProfileCard({
    super.key,
    required this.nickname,
    required this.level,
    required this.experience,
    required this.xpRequired,
    this.templateId = 'chiikawa_basic',
    this.loading = false,
    this.decorations = const [],
    this.onCharacterTap,
  });

  final String nickname;
  final int level;
  final int experience;
  final int xpRequired;
  final String templateId;
  final bool loading;
  final List<CardDecorationPlacement> decorations;
  final VoidCallback? onCharacterTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              UserCardArtwork(
                templateId: templateId,
                decorations: decorations,
              ),
              UserCardInfoOverlay(
                nickname: nickname,
                level: level,
                experience: experience,
                xpRequired: xpRequired,
                templateId: templateId,
                loading: loading,
              ),
              if (onCharacterTap != null)
                Positioned(
                  left: width * 0.565,
                  top: height * 0.12,
                  width: width * 0.34,
                  height: height * 0.48,
                  child: Semantics(
                    button: true,
                    label: '캐릭터 노래 재생',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onCharacterTap,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class UserCardArtwork extends StatelessWidget {
  const UserCardArtwork({
    super.key,
    this.templateId = 'chiikawa_basic',
    this.decorations = const [],
  });

  final String templateId;
  final List<CardDecorationPlacement> decorations;

  static final Map<String, Future<Uint8List>> _templateCache = {};

  static Future<Uint8List> _loadPartedArtwork(
    String cacheKey,
    String filePrefix,
    int partCount,
  ) {
    return _templateCache.putIfAbsent(cacheKey, () async {
      final parts = await Future.wait(
        List.generate(
          partCount,
          (index) => rootBundle.loadString(
            'assets/cards/$filePrefix.part-${index.toString().padLeft(2, '0')}',
            cache: false,
          ),
        ),
      );
      return base64Decode(parts.join());
    });
  }

  static Future<Uint8List> _loadArtwork(String templateId) {
    return switch (templateId) {
      'usagi_basic' => _loadPartedArtwork(
          'usagi_basic',
          'usagi_card',
          5,
        ),
      _ => _loadPartedArtwork(
          'chiikawa_basic',
          'default_chiikawa_card',
          14,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (templateId == 'hachiware_basic') {
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              const CustomPaint(painter: _HachiwareCardPainter()),
              ...decorations.map(
                (placement) => CardDecorationOverlay(
                  placement: placement,
                  cardWidth: width,
                  cardHeight: height,
                ),
              ),
            ],
          );
        },
      );
    }

    return FutureBuilder<Uint8List>(
      key: ValueKey(templateId),
      future: _loadArtwork(templateId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF6),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const CircularProgressIndicator(strokeWidth: 2.5),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                Image.memory(
                  snapshot.data!,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFFFFCF6),
                  ),
                ),
                ...decorations.map(
                  (placement) => CardDecorationOverlay(
                    placement: placement,
                    cardWidth: width,
                    cardHeight: height,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _HachiwareCardPainter extends CustomPainter {
  const _HachiwareCardPainter();

  static const outline = Color(0xFF5A3428);
  static const cream = Color(0xFFFFFCF6);
  static const blue = Color(0xFF8ED0F3);
  static const paleBlue = Color(0xFFDFF3FF);
  static const mint = Color(0xFFCFF3DF);
  static const pink = Color(0xFFF59AB2);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 400;
    final sy = size.height / 300;
    canvas.save();
    canvas.scale(sx, sy);

    final fill = Paint()..style = PaintingStyle.fill;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = outline;

    final outer = RRect.fromRectAndRadius(
      const Rect.fromLTWH(14, 12, 372, 276),
      const Radius.circular(30),
    );
    fill.color = cream;
    canvas.drawRRect(outer, fill);
    line.color = blue;
    line.strokeWidth = 14;
    canvas.drawRRect(outer, line);
    line.color = outline;
    line.strokeWidth = 5;
    canvas.drawRRect(outer, line);

    final inner = RRect.fromRectAndRadius(
      const Rect.fromLTWH(28, 28, 344, 232),
      const Radius.circular(22),
    );
    line.strokeWidth = 4;
    canvas.drawRRect(inner, line);

    canvas.drawLine(const Offset(30, 175), const Offset(370, 175), line);
    canvas.drawLine(const Offset(235, 30), const Offset(235, 174), line);

    fill.color = mint;
    final crown = Path()
      ..moveTo(174, 32)
      ..lineTo(186, 48)
      ..lineTo(200, 29)
      ..lineTo(214, 48)
      ..lineTo(226, 32)
      ..lineTo(221, 58)
      ..lineTo(180, 58)
      ..close();
    canvas.drawPath(crown, fill);
    line.strokeWidth = 5;
    canvas.drawPath(crown, line);

    // Hachiware-inspired blue/white cat mascot.
    final head = Path()
      ..moveTo(260, 82)
      ..lineTo(270, 55)
      ..lineTo(293, 72)
      ..quadraticBezierTo(320, 60, 345, 76)
      ..lineTo(365, 58)
      ..lineTo(360, 92)
      ..quadraticBezierTo(370, 119, 358, 143)
      ..quadraticBezierTo(342, 168, 308, 166)
      ..quadraticBezierTo(274, 165, 253, 143)
      ..quadraticBezierTo(241, 119, 260, 82)
      ..close();
    fill.color = cream;
    canvas.drawPath(head, fill);
    canvas.drawPath(head, line);

    final cap = Path()
      ..moveTo(258, 90)
      ..quadraticBezierTo(280, 67, 309, 71)
      ..quadraticBezierTo(340, 67, 360, 92)
      ..quadraticBezierTo(345, 106, 331, 104)
      ..quadraticBezierTo(316, 91, 307, 89)
      ..quadraticBezierTo(296, 92, 284, 104)
      ..quadraticBezierTo(270, 106, 258, 90)
      ..close();
    fill.color = paleBlue;
    canvas.drawPath(cap, fill);

    fill.color = blue;
    canvas.drawPath(
      Path()
        ..moveTo(270, 56)
        ..lineTo(291, 72)
        ..lineTo(277, 78)
        ..close(),
      fill,
    );
    canvas.drawPath(
      Path()
        ..moveTo(365, 59)
        ..lineTo(345, 76)
        ..lineTo(356, 82)
        ..close(),
      fill,
    );

    fill.color = outline;
    canvas.drawCircle(const Offset(291, 122), 4, fill);
    canvas.drawCircle(const Offset(331, 122), 4, fill);

    line.strokeWidth = 4;
    final mouth = Path()
      ..moveTo(307, 137)
      ..quadraticBezierTo(311, 143, 316, 137)
      ..quadraticBezierTo(321, 143, 326, 137);
    canvas.drawPath(mouth, line);

    fill.color = pink;
    canvas.drawOval(const Rect.fromLTWH(267, 132, 24, 12), fill);
    canvas.drawOval(const Rect.fromLTWH(337, 132, 24, 12), fill);

    // Small paw/peace gesture.
    fill.color = cream;
    canvas.drawCircle(const Offset(261, 150), 13, fill);
    canvas.drawCircle(const Offset(253, 141), 7, fill);
    canvas.drawCircle(const Offset(266, 137), 7, fill);
    canvas.drawCircle(const Offset(261, 150), 13, line);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HachiwareCardPainter oldDelegate) => false;
}

class UserCardInfoOverlay extends StatelessWidget {
  const UserCardInfoOverlay({
    super.key,
    required this.nickname,
    required this.level,
    required this.experience,
    required this.xpRequired,
    this.templateId = 'chiikawa_basic',
    this.loading = false,
  });

  final String nickname;
  final int level;
  final int experience;
  final int xpRequired;
  final String templateId;
  final bool loading;

  Color get _progressColor => switch (templateId) {
        'hachiware_basic' => const Color(0xFFAADAF8),
        'usagi_basic' => const Color(0xFFD2B4F8),
        _ => const Color(0xFFB8EBCB),
      };

  @override
  Widget build(BuildContext context) {
    const outline = Color(0xFF4F2B22);
    final progress = xpRequired <= 0
        ? 0.0
        : (experience / xpRequired).clamp(0.0, 1.0).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: width * 0.115,
              top: height * 0.225,
              width: width * 0.43,
              height: height * 0.18,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    nickname,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'HSYuji',
                      fontSize: width * 0.066,
                      fontWeight: FontWeight.w400,
                      color: outline,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: width * 0.12,
              top: height * 0.655,
              width: width * 0.75,
              child: loading
                  ? Text(
                      '레벨 정보를 불러오는 중...',
                      style: TextStyle(
                        fontFamily: 'HSYuji',
                        fontSize: width * 0.033,
                        color: outline,
                      ),
                    )
                  : Text(
                      '레벨 : $level    경험치 : $experience/$xpRequired',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'HSYuji',
                        fontSize: width * 0.038,
                        fontWeight: FontWeight.w400,
                        color: outline,
                        height: 1,
                      ),
                    ),
            ),
            if (!loading)
              Positioned(
                left: width * 0.12,
                top: height * 0.75,
                width: width * 0.75,
                height: height * 0.067,
                child: _CardProgressBar(
                  progress: progress,
                  fillColor: _progressColor,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CardProgressBar extends StatelessWidget {
  const _CardProgressBar({
    required this.progress,
    required this.fillColor,
  });

  final double progress;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    const outline = Color(0xFF4F2B22);
    final value = progress.clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: outline, width: 2.4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final filledWidth = constraints.maxWidth * value;
          final markerLeft = filledWidth <= 18
              ? 2.0
              : filledWidth >= constraints.maxWidth - 15
                  ? constraints.maxWidth - 17
                  : filledWidth - 15;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: filledWidth,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              if (filledWidth > 42)
                Positioned(
                  left: 10,
                  top: 2,
                  width: filledWidth * 0.34,
                  height: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              if (value > 0)
                Positioned(
                  left: markerLeft,
                  top: -5,
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: Color(0xFFFFCF55),
                    shadows: [
                      Shadow(color: outline, blurRadius: 0.6),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
