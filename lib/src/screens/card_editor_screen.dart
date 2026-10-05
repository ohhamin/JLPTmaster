import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../services/card_customization_service.dart';
import '../services/card_image_service.dart';
import '../widgets/card_decoration.dart';
import '../widgets/user_profile_card.dart';

class CardEditorScreen extends StatefulWidget {
  const CardEditorScreen({
    super.key,
    required this.nickname,
    required this.level,
    required this.experience,
    required this.xpRequired,
    required this.initialDecorations,
  });

  final String nickname;
  final int level;
  final int experience;
  final int xpRequired;
  final List<CardDecorationPlacement> initialDecorations;

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  final GlobalKey _cardCaptureKey = GlobalKey();
  late List<CardDecorationPlacement> _items;
  String? _selectedUid;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = widget.initialDecorations.toList(growable: true);
  }

  CardDecorationPlacement? get _selected {
    final uid = _selectedUid;
    if (uid == null) return null;
    for (final item in _items) {
      if (item.uid == uid) return item;
    }
    return null;
  }

  CardDecorationDefinition? _definition(String id) {
    for (final item in cardDecorationCatalog) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _replace(CardDecorationPlacement placement) {
    final index = _items.indexWhere((item) => item.uid == placement.uid);
    if (index < 0) return;
    setState(() => _items[index] = placement);
  }

  void _move(String uid, double dx, double dy, double cardWidth, double cardHeight) {
    final index = _items.indexWhere((item) => item.uid == uid);
    if (index < 0) return;
    final current = _items[index];
    setState(() {
      _items[index] = current.copyWith(
        x: (current.x + dx / cardWidth).clamp(0.02, 0.98).toDouble(),
        y: (current.y + dy / cardHeight).clamp(0.02, 0.98).toDouble(),
      );
    });
  }

  void _add(CardDecorationDefinition definition) {
    if (_items.length >= 24) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('장식은 최대 24개까지 놓을 수 있어요.')),
      );
      return;
    }
    final count = _items.length;
    final placement = CardDecorationPlacement(
      uid: '${DateTime.now().microsecondsSinceEpoch}_${definition.id}',
      assetId: definition.id,
      x: (0.76 + (count % 3) * 0.035).clamp(0.08, 0.92).toDouble(),
      y: (0.27 + (count % 4) * 0.03).clamp(0.08, 0.90).toDouble(),
    );
    setState(() {
      _items.add(placement);
      _selectedUid = placement.uid;
    });
  }

  void _removeSelected() {
    final uid = _selectedUid;
    if (uid == null) return;
    setState(() {
      _items.removeWhere((item) => item.uid == uid);
      _selectedUid = null;
    });
  }

  void _reset() {
    setState(() {
      _items.clear();
      _selectedUid = null;
    });
  }

  Future<Uint8List> _captureCardPng() async {
    await WidgetsBinding.instance.endOfFrame;
    final renderObject = _cardCaptureKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw Exception('카드 이미지를 만들 준비가 되지 않았어요.');
    }
    final image = await renderObject.toImage(pixelRatio: 3.0);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw Exception('카드 이미지를 PNG로 변환하지 못했어요.');
      }
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _selectedUid = null;
    });
    try {
      final pngBytes = await _captureCardPng();
      final saved = await CardCustomizationService.instance.save(_items);
      await CardImageService.instance.upload(pngBytes);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카드를 저장하지 못했어요. $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selected;
    final selectedDefinition = selected == null ? null : _definition(selected.assetId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('카드 꾸미기'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saving ? null : _reset,
            child: const Text('초기화'),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
        children: [
          Text(
            '장식을 눌러 추가하고 카드 위에서 드래그해서 옮겨보세요.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 14),
          RepaintBoundary(
            key: _cardCaptureKey,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  UserProfileCard(
                    nickname: widget.nickname,
                    level: widget.level,
                    experience: widget.experience,
                    xpRequired: widget.xpRequired,
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = constraints.maxWidth;
                      final cardHeight = constraints.maxHeight;
                      return Stack(
                        clipBehavior: Clip.hardEdge,
                        children: _items.map((item) {
                          final baseSize = cardWidth * 0.16;
                          final size = baseSize * item.scale;
                          final isSelected = item.uid == _selectedUid;
                          return Positioned(
                            left: item.x * cardWidth - size / 2,
                            top: item.y * cardHeight - size / 2,
                            width: size,
                            height: size,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () => setState(() => _selectedUid = item.uid),
                              onPanStart: (_) => setState(() => _selectedUid = item.uid),
                              onPanUpdate: (details) => _move(
                                item.uid,
                                details.delta.dx,
                                details.delta.dy,
                                cardWidth,
                                cardHeight,
                              ),
                              child: Transform.rotate(
                                angle: item.rotation * math.pi / 180,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: isSelected
                                        ? Border.all(
                                            color: scheme.primary,
                                            width: 2.4,
                                          )
                                        : null,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: CardDecorationVisual(
                                      assetId: item.assetId,
                                      size: size - 4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (selected != null) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 13, 12, 14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedDefinition?.label ?? '선택한 장식',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      IconButton(
                        tooltip: '장식 삭제',
                        onPressed: _removeSelected,
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                  _EditorSlider(
                    label: '크기',
                    valueText: '${(selected.scale * 100).round()}%',
                    value: selected.scale,
                    min: 0.45,
                    max: 2.2,
                    onChanged: (value) => _replace(selected.copyWith(scale: value)),
                  ),
                  _EditorSlider(
                    label: '회전',
                    valueText: '${selected.rotation.round()}°',
                    value: selected.rotation.clamp(-180, 180).toDouble(),
                    min: -180,
                    max: 180,
                    onChanged: (value) => _replace(selected.copyWith(rotation: value)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          Row(
            children: [
              Text(
                '장식',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const Spacer(),
              Text(
                '${_items.length}/24',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cardDecorationCatalog.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.83,
            ),
            itemBuilder: (context, index) {
              final decoration = cardDecorationCatalog[index];
              return InkWell(
                onTap: () => _add(decoration),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(7, 8, 7, 6),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: FittedBox(
                          child: CardDecorationVisual(
                            assetId: decoration.id,
                            size: 64,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        decoration.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            '저장하면 장식 배치 정보와 완성된 카드 PNG가 함께 서버에 저장돼요. 다시 수정하면 같은 사용자 카드 파일을 덮어써서 용량이 계속 늘어나지 않아요.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}

class _EditorSlider extends StatelessWidget {
  const _EditorSlider({
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 42,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            valueText,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ],
    );
  }
}
