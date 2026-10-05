import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/card_customization_service.dart';
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
      x: (0.76 + (count % 3) * 0.035).clamp(0.08, 0.92),
      y: (0.27 + (count % 4) * 0.03).clamp(0.08, 0.90),
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

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final saved = await CardCustomizationService.instance.save(_items);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카드 꾸미기를 저장하지 못했어요. $error')),
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
          AspectRatio(
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
                      clipBehavior: Clip.none,
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
                            onPanUpdate: (details) {
                              _replace(
                                item.copyWith(
                                  x: (item.x + details.delta.dx / cardWidth)
                                      .clamp(0.02, 0.98),
                                  y: (item.y + details.delta.dy / cardHeight)
                                      .clamp(0.02, 0.98),
                                ),
                              );
                            },
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
                    value: selected.rotation.clamp(-180, 180),
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
            '장식은 벡터 방식으로 그려져 확대해도 깨지지 않아요. 저장하면 위치·크기·회전값이 계정에 저장되어 다른 기기에서도 그대로 불러옵니다.',
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
            value: value.clamp(min, max),
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
