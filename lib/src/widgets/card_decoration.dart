import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/card_customization_service.dart';

class CardDecorationDefinition {
  const CardDecorationDefinition({
    required this.id,
    required this.label,
    required this.category,
    required this.assetNumber,
  });

  final String id;
  final String label;
  final String category;
  final int assetNumber;

  String get assetPath => 'assets/decorations/$assetNumber.png';
}

const cardDecorationCatalog = <CardDecorationDefinition>[
  CardDecorationDefinition(id: 'pink_bow', label: '분홍 리본', category: '머리', assetNumber: 1),
  CardDecorationDefinition(id: 'red_headband', label: '빨간 머리띠', category: '머리', assetNumber: 2),
  CardDecorationDefinition(id: 'blue_headband', label: '파란 머리띠', category: '머리', assetNumber: 3),
  CardDecorationDefinition(id: 'mint_headband', label: '민트 머리띠', category: '머리', assetNumber: 4),
  CardDecorationDefinition(id: 'heart_pair', label: '하트 두 개', category: '포인트', assetNumber: 5),
  CardDecorationDefinition(id: 'heart_bubble', label: '하트 말풍선', category: '포인트', assetNumber: 6),
  CardDecorationDefinition(id: 'sparkle', label: '반짝이', category: '포인트', assetNumber: 7),
  CardDecorationDefinition(id: 'daisy', label: '데이지', category: '머리', assetNumber: 8),
  CardDecorationDefinition(id: 'sprout', label: '새싹', category: '머리', assetNumber: 9),
  CardDecorationDefinition(id: 'halo', label: '천사 링', category: '머리', assetNumber: 10),
  CardDecorationDefinition(id: 'round_glasses', label: '동그란 안경', category: '얼굴', assetNumber: 11),
  CardDecorationDefinition(id: 'star_glasses', label: '별 안경', category: '얼굴', assetNumber: 12),
];

class CardDecorationVisual extends StatelessWidget {
  const CardDecorationVisual({
    super.key,
    required this.assetId,
    required this.size,
  });

  final String assetId;
  final double size;

  CardDecorationDefinition? get _definition {
    for (final item in cardDecorationCatalog) {
      if (item.id == assetId) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final definition = _definition;
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
