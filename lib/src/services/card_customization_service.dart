import 'dart:math';

import 'package:flutter/foundation.dart';

import 'api_service.dart';

class CardTemplateDefinition {
  const CardTemplateDefinition({
    required this.id,
    required this.label,
    required this.unlockLevel,
  });

  final String id;
  final String label;
  final int unlockLevel;
}

const cardTemplateCatalog = <CardTemplateDefinition>[
  CardTemplateDefinition(id: 'chiikawa_basic', label: '치이카와', unlockLevel: 1),
  CardTemplateDefinition(id: 'hachiware_basic', label: '하치와레', unlockLevel: 5),
  CardTemplateDefinition(id: 'usagi_basic', label: '우사기', unlockLevel: 10),
];

const defaultUnlockedDecorationIds = <String>{'1', '2', '3'};

const allDecorationIds = <String>[
  '1', '2', '3', '4', '5', '6', '7', '8', '9', '10',
  '11', '12', '13', '14', '15', '16', '17', '18', '19', '20',
  '21', '22', '23', '24', '25', '26', '27', '28', '29', '30',
  '31', '32', '33', '34', '35', '36', '37', '38', '39',
];

const legacyDecorationIdMap = <String, String>{
  'pink_bow': '1',
  'red_headband': '2',
  'blue_headband': '3',
  'mint_headband': '4',
  'heart_pair': '5',
  'heart_bubble': '6',
  'sparkle': '7',
  'daisy': '8',
  'sprout': '9',
  'halo': '10',
  'round_glasses': '11',
  'star_glasses': '12',
};

String normalizeDecorationId(String raw) {
  final value = raw.trim();
  return legacyDecorationIdMap[value] ?? value;
}

List<String> sortDecorationIds(Iterable<String> ids) {
  final result = ids.toList(growable: false);
  result.sort(
    (a, b) => (int.tryParse(a) ?? 9999).compareTo(int.tryParse(b) ?? 9999),
  );
  return result;
}

bool isKnownCardTemplate(String id) =>
    cardTemplateCatalog.any((template) => template.id == id);

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
      assetId: normalizeDecorationId(json['asset_id']?.toString() ?? ''),
      x: ((json['x'] as num?)?.toDouble() ?? 0.78).clamp(0.0, 1.0).toDouble(),
      y: ((json['y'] as num?)?.toDouble() ?? 0.30).clamp(0.0, 1.0).toDouble(),
      scale: ((json['scale'] as num?)?.toDouble() ?? 1.0)
          .clamp(0.45, 2.2)
          .toDouble(),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'asset_id': normalizeDecorationId(assetId),
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
  final Random _random = Random();
  final ValueNotifier<List<CardDecorationPlacement>> decorations =
      ValueNotifier<List<CardDecorationPlacement>>(const []);
  final ValueNotifier<String> templateId = ValueNotifier<String>('chiikawa_basic');
  final ValueNotifier<Set<String>> unlockedDecorationIds =
      ValueNotifier<Set<String>>(defaultUnlockedDecorationIds);

  Set<String> _parseUnlocked(dynamic raw) {
    final result = <String>{...defaultUnlockedDecorationIds};
    if (raw is List) {
      for (final value in raw) {
        final id = normalizeDecorationId(value.toString());
        if (allDecorationIds.contains(id)) result.add(id);
      }
    }
    return result;
  }

  Future<List<CardDecorationPlacement>> refresh() async {
    final settings = await _api.fetchSettings();
    final card = Map<String, dynamic>.from(
      settings['card'] as Map? ?? const <String, dynamic>{},
    );

    final rawTemplate = card['template_id']?.toString() ?? 'chiikawa_basic';
    templateId.value = isKnownCardTemplate(rawTemplate)
        ? rawTemplate
        : 'chiikawa_basic';
    unlockedDecorationIds.value = Set.unmodifiable(
      _parseUnlocked(card['unlocked_decorations']),
    );

    final raw = card['decorations'];
    final parsed = <CardDecorationPlacement>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final placement = CardDecorationPlacement.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (placement.uid.isEmpty ||
            !allDecorationIds.contains(placement.assetId)) {
          continue;
        }
        parsed.add(placement);
        break;
      }
    }
    decorations.value = List.unmodifiable(parsed);
    return decorations.value;
  }

  Future<List<String>> grantRandomDecorations(int count) async {
    if (count <= 0) return const [];
    final settings = await _api.fetchSettings();
    final card = Map<String, dynamic>.from(
      settings['card'] as Map? ?? const <String, dynamic>{},
    );
    final unlocked = _parseUnlocked(card['unlocked_decorations']);
    final candidates = allDecorationIds.where((id) => !unlocked.contains(id)).toList()
      ..shuffle(_random);
    final granted = candidates.take(count).toList(growable: false);
    unlocked.addAll(granted);
    await _api.updateSettings({
      'card': {
        ...card,
        'unlocked_decorations': sortDecorationIds(unlocked),
      },
    });
    unlockedDecorationIds.value = Set.unmodifiable(unlocked);
    return granted;
  }

  Future<List<CardDecorationPlacement>> save(
    List<CardDecorationPlacement> value, {
    String? templateId,
  }) async {
    final selectedTemplate = templateId != null && isKnownCardTemplate(templateId)
        ? templateId
        : this.templateId.value;
    final normalized = value
        .take(1)
        .map(
          (item) => item.copyWith(
            assetId: normalizeDecorationId(item.assetId),
            x: item.x.clamp(0.0, 1.0).toDouble(),
            y: item.y.clamp(0.0, 1.0).toDouble(),
            scale: item.scale.clamp(0.45, 2.2).toDouble(),
          ),
        )
        .where((item) => allDecorationIds.contains(item.assetId))
        .toList(growable: false);
    await _api.updateSettings({
      'card': {
        'template_id': selectedTemplate,
        'decorations': normalized.map((item) => item.toJson()).toList(),
        'unlocked_decorations': sortDecorationIds(unlockedDecorationIds.value),
      },
    });
    this.templateId.value = selectedTemplate;
    decorations.value = List.unmodifiable(normalized);
    return decorations.value;
  }

  bool isDecorationUnlocked(String id) =>
      unlockedDecorationIds.value.contains(normalizeDecorationId(id));

  void reset() {
    templateId.value = 'chiikawa_basic';
    decorations.value = const [];
    unlockedDecorationIds.value = defaultUnlockedDecorationIds;
  }
}
