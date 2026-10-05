import 'package:flutter/foundation.dart';

import 'api_service.dart';

class CardDecorationPlacement {
  const CardDecorationPlacement({
    required this.uid,
    required this.assetId,
    required this.x,
    required this.y,
    this.scale = 1.0,
    this.rotation = 0.0,
  });

  final String uid;
  final String assetId;
  final double x;
  final double y;
  final double scale;
  final double rotation;

  CardDecorationPlacement copyWith({
    String? uid,
    String? assetId,
    double? x,
    double? y,
    double? scale,
    double? rotation,
  }) {
    return CardDecorationPlacement(
      uid: uid ?? this.uid,
      assetId: assetId ?? this.assetId,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  factory CardDecorationPlacement.fromJson(Map<String, dynamic> json) {
    return CardDecorationPlacement(
      uid: json['uid']?.toString() ?? '',
      assetId: json['asset_id']?.toString() ?? '',
      x: ((json['x'] as num?)?.toDouble() ?? 0.78).clamp(0.0, 1.0),
      y: ((json['y'] as num?)?.toDouble() ?? 0.30).clamp(0.0, 1.0),
      scale: ((json['scale'] as num?)?.toDouble() ?? 1.0).clamp(0.45, 2.2),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'asset_id': assetId,
        'x': x,
        'y': y,
        'scale': scale,
        'rotation': rotation,
      };
}

class CardCustomizationService {
  CardCustomizationService._();

  static final CardCustomizationService instance = CardCustomizationService._();

  final ApiService _api = ApiService();
  final ValueNotifier<List<CardDecorationPlacement>> decorations =
      ValueNotifier<List<CardDecorationPlacement>>(const []);

  Future<List<CardDecorationPlacement>> refresh() async {
    final settings = await _api.fetchSettings();
    final card = Map<String, dynamic>.from(
      settings['card'] as Map? ?? const <String, dynamic>{},
    );
    final raw = card['decorations'];
    final parsed = <CardDecorationPlacement>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final placement = CardDecorationPlacement.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (placement.uid.isEmpty || placement.assetId.isEmpty) continue;
        parsed.add(placement);
      }
    }
    decorations.value = List.unmodifiable(parsed);
    return decorations.value;
  }

  Future<List<CardDecorationPlacement>> save(
    List<CardDecorationPlacement> value,
  ) async {
    final normalized = value
        .take(24)
        .map(
          (item) => item.copyWith(
            x: item.x.clamp(0.0, 1.0),
            y: item.y.clamp(0.0, 1.0),
            scale: item.scale.clamp(0.45, 2.2),
          ),
        )
        .toList(growable: false);
    await _api.updateSettings({
      'card': {
        'template_id': 'chiikawa_basic',
        'decorations': normalized.map((item) => item.toJson()).toList(),
      },
    });
    decorations.value = List.unmodifiable(normalized);
    return decorations.value;
  }

  void reset() {
    decorations.value = const [];
  }
}
