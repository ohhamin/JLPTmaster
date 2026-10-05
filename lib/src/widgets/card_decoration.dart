import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/card_customization_service.dart';

class CardDecorationDefinition {
  const CardDecorationDefinition({
    required this.id,
    required this.label,
    this.category = '장식',
  });

  final String id;
  final String label;
  final String category;

  String get assetPath => 'assets/decorations/$id.png';
}

const cardDecorationCatalog = <CardDecorationDefinition>[
  CardDecorationDefinition(id: '1', label: '새싹'),
  CardDecorationDefinition(id: '2', label: '하트 두 개'),
  CardDecorationDefinition(id: '3', label: '반짝이'),
  CardDecorationDefinition(id: '4', label: '파란 꽃 화관'),
  CardDecorationDefinition(id: '5', label: '분홍 꽃 화관'),
  CardDecorationDefinition(id: '6', label: '노란 꽃 화관'),
  CardDecorationDefinition(id: '7', label: '하치와레 물고기 포셰트'),
  CardDecorationDefinition(id: '8', label: '치이카와 곰 포셰트'),
  CardDecorationDefinition(id: '9', label: '우사기 별 포셰트'),
  CardDecorationDefinition(id: '10', label: '파란 고깔모자'),
  CardDecorationDefinition(id: '11', label: '빨간 고깔모자'),
  CardDecorationDefinition(id: '12', label: '노란 고깔모자'),
  CardDecorationDefinition(id: '13', label: '별 안경'),
  CardDecorationDefinition(id: '14', label: '파란 선물상자'),
  CardDecorationDefinition(id: '15', label: '노란 리본'),
  CardDecorationDefinition(id: '16', label: '삼색 풍선'),
  CardDecorationDefinition(id: '17', label: '하트 요술봉'),
  CardDecorationDefinition(id: '18', label: '달과 별 장식'),
  CardDecorationDefinition(id: '19', label: '딸기 컵케이크'),
  CardDecorationDefinition(id: '20', label: '무지개 구름'),
  CardDecorationDefinition(id: '21', label: '체리 리본'),
  CardDecorationDefinition(id: '22', label: '하트 캔디'),
  CardDecorationDefinition(id: '23', label: '리본 음표'),
  CardDecorationDefinition(id: '24', label: '분홍 나비'),
  CardDecorationDefinition(id: '25', label: '진주 조개'),
  CardDecorationDefinition(id: '26', label: '천사 링'),
  CardDecorationDefinition(id: '27', label: '보석 왕관'),
  CardDecorationDefinition(id: '28', label: '벚꽃'),
  CardDecorationDefinition(id: '29', label: '토끼 반창고'),
  CardDecorationDefinition(id: '30', label: '컬러 음표'),
  CardDecorationDefinition(id: '31', label: '파란 리본'),
  CardDecorationDefinition(id: '32', label: '보라 마법사 모자'),
  CardDecorationDefinition(id: '33', label: '분홍 동그란 안경'),
  CardDecorationDefinition(id: '34', label: '하트 꽃 선글라스'),
  CardDecorationDefinition(id: '35', label: '검은 선글라스'),
  CardDecorationDefinition(id: '36', label: '금테 동그란 안경'),
  CardDecorationDefinition(id: '37', label: '하트 머리핀'),
  CardDecorationDefinition(id: '38', label: '구름 머리핀'),
  CardDecorationDefinition(id: '39', label: '딸기 머리핀'),
];

CardDecorationDefinition? cardDecorationById(String rawId) {
  final id = normalizeDecorationId(rawId);
  for (final item in cardDecorationCatalog) {
    if (item.id == id) return item;
  }
  return null;
}

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
    final definition = cardDecorationById(assetId);
    if (definition == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: SizedBox.square(
        dimension: size,
        child: Image.asset(
          definition.assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
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
