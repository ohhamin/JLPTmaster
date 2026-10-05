import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UserProfileCard extends StatelessWidget {
  const UserProfileCard({
    super.key,
    required this.nickname,
    required this.level,
    required this.experience,
    required this.xpRequired,
    this.loading = false,
  });

  final String nickname;
  final int level;
  final int experience;
  final int xpRequired;
  final bool loading;

  static const int _artworkPartCount = 14;
  static Future<Uint8List>? _artworkBytes;

  static Future<Uint8List> _loadArtwork() {
    return _artworkBytes ??= () async {
      final parts = await Future.wait(
        List.generate(
          _artworkPartCount,
          (index) => rootBundle.loadString(
            'assets/cards/default_chiikawa_card.part-${index.toString().padLeft(2, '0')}',
          ),
        ),
      );
      return base64Decode(parts.join());
    }();
  }

  @override
  Widget build(BuildContext context) {
    const outline = Color(0xFF4F2B22);
    const mint = Color(0xFFB8EBCB);
    final progress = xpRequired <= 0
        ? 0.0
        : (experience / xpRequired).clamp(0.0, 1.0).toDouble();

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: FutureBuilder<Uint8List>(
        future: _loadArtwork(),
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
                children: [
                  Image.memory(
                    snapshot.data!,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.high,
                  ),
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
                        fillColor: mint,
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
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
