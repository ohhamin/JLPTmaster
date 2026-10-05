import 'package:flutter/material.dart';

import '../services/card_customization_service.dart';
import 'card_decoration.dart';

class UserProfileCard extends StatelessWidget {
  const UserProfileCard({
    super.key,
    required this.nickname,
    required this.level,
    required this.experience,
    required this.xpRequired,
    this.currentAttendanceStreak = 0,
    this.templateId = 'chiikawa_basic',
    this.loading = false,
    this.decorations = const [],
    this.onCharacterTap,
  });

  final String nickname;
  final int level;
  final int experience;
  final int xpRequired;
  final int currentAttendanceStreak;
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
                currentAttendanceStreak: currentAttendanceStreak,
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

  String get _assetPath => switch (templateId) {
        'hachiware_basic' => 'assets/cards/hachiware.png',
        'usagi_basic' => 'assets/cards/usagi.png',
        _ => 'assets/cards/chiikawa.png',
      };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            Image.asset(
              _assetPath,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => const SizedBox.expand(),
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
  }
}

class UserCardInfoOverlay extends StatelessWidget {
  const UserCardInfoOverlay({
    super.key,
    required this.nickname,
    required this.level,
    required this.experience,
    required this.xpRequired,
    this.currentAttendanceStreak = 0,
    this.templateId = 'chiikawa_basic',
    this.loading = false,
  });

  final String nickname;
  final int level;
  final int experience;
  final int xpRequired;
  final int currentAttendanceStreak;
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
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '레벨 : $level    경험치 : $experience/$xpRequired    연속출석일 : $currentAttendanceStreak',
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: 'HSYuji',
                          fontSize: width * 0.038,
                          fontWeight: FontWeight.w400,
                          color: outline,
                          height: 1,
                        ),
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
            ],
          );
        },
      ),
    );
  }
}
