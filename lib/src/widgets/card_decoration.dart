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
  CardDecorationDefinition(id: '1', label: '분홍 리본'),
  CardDecorationDefinition(id: '2', label: '빨간 머리띠'),
  CardDecorationDefinition(id: '3', label: '파란 머리띠'),
  CardDecorationDefinition(id: '4', label: '민트 머리띠'),
  CardDecorationDefinition(id: '5', label: '하트 두 개'),
  CardDecorationDefinition(id: '6', label: '하트 말풍선'),
  CardDecorationDefinition(id: '7', label: '반짝이'),
  CardDecorationDefinition(id: '8', label: '데이지'),
  CardDecorationDefinition(id: '9', label: '새싹'),
  CardDecorationDefinition(id: '10', label: '천사 링'),
  CardDecorationDefinition(id: '11', label: '동그란 안경'),
  CardDecorationDefinition(id: '12', label: '별 안경'),
  CardDecorationDefinition(id: '13', label: '장식 13'),
  CardDecorationDefinition(id: '14', label: '장식 14'),
  CardDecorationDefinition(id: '15', label: '장식 15'),
  CardDecorationDefinition(id: '16', label: '장식 16'),
  CardDecorationDefinition(id: '17', label: '장식 17'),
  CardDecorationDefinition(id: '18', label: '장식 18'),
  CardDecorationDefinition(id: '19', label: '장식 19'),
  CardDecorationDefinition(id: '20', label: '장식 20'),
  CardDecorationDefinition(id: '21', label: '장식 21'),
  CardDecorationDefinition(id: '22', label: '장식 22'),
  CardDecorationDefinition(id: '23', label: '장식 23'),
  CardDecorationDefinition(id: '24', label: '장식 24'),
  CardDecorationDefinition(id: '25', label: '장식 25'),
  CardDecorationDefinition(id: '26', label: '장식 26'),
  CardDecorationDefinition(id: '27', label: '장식 27'),
  CardDecorationDefinition(id: '28', label: '장식 28'),
  CardDecorationDefinition(id: '29', label: '장식 29'),
  CardDecorationDefinition(id: '30', label: '장식 30'),
  CardDecorationDefinition(id: '31', label: '장식 31'),
  CardDecorationDefinition(id: '32', label: '장식 32'),
  CardDecorationDefinition(id: '33', label: '장식 33'),
  CardDecorationDefinition(id: '34', label: '장식 34'),
  CardDecorationDefinition(id: '35', label: '장식 35'),
  CardDecorationDefinition(id: '36', label: '장식 36'),
  CardDecorationDefinition(id: '37', label: '장식 37'),
  CardDecorationDefinition(id: '38', label: '장식 38'),
  CardDecorationDefinition(id: '39', label: '장식 39'),
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
