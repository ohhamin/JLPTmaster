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
    this.initialTemplateId = 'chiikawa_basic',
  });

  final String nickname;
  final int level;
  final int experience;
  final int xpRequired;
  final List<CardDecorationPlacement> initialDecorations;
  final String initialTemplateId;

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  final GlobalKey _cardCaptureKey = GlobalKey();
  late List<CardDecorationPlacement> _items;
  late String _templateId;
  String? _selectedUid;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = widget.initialDecorations.take(1).toList(growable: true);
    _templateId = isKnownCardTemplate(widget.initialTemplateId)
        ? widget.initialTemplateId
        : 'chiikawa_basic';
    if (_items.isNotEmpty) _selectedUid = _items.first.uid;
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
    if (_items.isEmpty) return;
    setState(() => _items[0] = placement);
  }

  void _move(String uid, double dx, double dy, double cardWidth, double cardHeight) {
    if (_items.isEmpty || _items.first.uid != uid) return;
    final current = _items.first;
    setState(() {
      _items[0] = current.copyWith(
        x: (current.x + dx / cardWidth).clamp(0.02, 0.98).toDouble(),
        y: (current.y + dy / cardHeight).clamp(0.02, 0.98).toDouble(),
      );
    });
  }

  void _selectTemplate(CardTemplateDefinition template) {
    if (widget.level < template.unlockLevel) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lv.${template.unlockLevel}부터 ${template.label} 카드를 사용할 수 있어요.')),
      );
      return;
    }
    setState(() => _templateId = template.id);
  }

  void _add(CardDecorationDefinition definition) {
    final placement = CardDecorationPlacement(
      uid: '${DateTime.now().microsecondsSinceEpoch}_${definition.id}',
      assetId: definition.id,
      x: 0.76,
      y: 0.27,
    );
    setState(() {
      _items
        ..clear()
        ..add(placement);
      _selectedUid = placement.uid;
    });
  }

  void _removeSelected() {
    setState(() {
      _items.clear();
      _selectedUid = null;
    });
  }

  void _reset() {
    setState(() {
      _items.clear();
      _selectedUid = null;
      _templateId = 'chiikawa_basic';
    });
  }

  Future<Uint8List> _captureStaticCardPng() async {
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
      final pngBytes = await _captureStaticCardPng();
      final saved = await CardCustomizationService.instance.save(
        _items,
        templateId: _templateId,
      );
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

  Widget _buildEditableArtwork(ColorScheme scheme) {
    return Stack(
      fit: StackFit.expand,
      children: [
        UserCardArtwork(templateId: _templateId),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth;
            final cardHeight = constraints.maxHeight;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: _items.map((item) {
                final baseSize = cardWidth * 0.18;
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
                              ? Border.all(color: scheme.primary, width: 2.4)
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
    );
  }

  Widget _templateSelector(ColorScheme scheme) {
    return Row(
      children: [
        for (var index = 0; index < cardTemplateCatalog.length; index++) ...[
          if (index > 0) const SizedBox(width: 7),
          Expanded(
            child: _TemplateChoice(
              template: cardTemplateCatalog[index],
              selected: _templateId == cardTemplateCatalog[index].id,
              unlocked: widget.level >= cardTemplateCatalog[index].unlockLevel,
              onTap: () => _selectTemplate(cardTemplateCatalog[index]),
              scheme: scheme,
            ),
          ),
        ],
      ],
    );
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
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
        child: Column(
          children: [
            _templateSelector(scheme),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    key: _cardCaptureKey,
                    child: _buildEditableArtwork(scheme),
                  ),
                  IgnorePointer(
                    child: UserCardInfoOverlay(
                      nickname: widget.nickname,
                      level: widget.level,
                      experience: widget.experience,
                      xpRequired: widget.xpRequired,
                      templateId: _templateId,
                    ),
                  ),
                ],
              ),
            ),
            if (selected != null) ...[
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
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
                          visualDensity: VisualDensity.compact,
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
            ],
            const SizedBox(height: 8),
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
                  '${_items.isEmpty ? 0 : 1}/1',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const columns = 4;
                  const gap = 8.0;
                  final rows = (cardDecorationCatalog.length / columns).ceil();
                  final tileWidth =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  final tileHeight =
                      (constraints.maxHeight - gap * (rows - 1)) / rows;
                  final ratio = tileHeight <= 0 ? 1.0 : tileWidth / tileHeight;

                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: cardDecorationCatalog.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: gap,
                      crossAxisSpacing: gap,
                      childAspectRatio: ratio,
                    ),
                    itemBuilder: (context, index) {
                      final decoration = cardDecorationCatalog[index];
                      final selectedAsset =
                          _items.isNotEmpty && _items.first.assetId == decoration.id;
                      return InkWell(
                        onTap: () => _add(decoration),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(6, 6, 6, 5),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selectedAsset
                                  ? scheme.primary
                                  : scheme.outlineVariant.withValues(alpha: 0.8),
                              width: selectedAsset ? 2 : 1,
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
                              const SizedBox(height: 2),
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateChoice extends StatelessWidget {
  const _TemplateChoice({
    required this.template,
    required this.selected,
    required this.unlocked,
    required this.onTap,
    required this.scheme,
  });

  final CardTemplateDefinition template;
  final bool selected;
  final bool unlocked;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: 0.16)
          : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!unlocked) ...[
                Icon(Icons.lock_rounded, size: 13, color: scheme.onSurfaceVariant),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  unlocked ? template.label : '${template.label} · Lv.${template.unlockLevel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: unlocked ? scheme.onSurface : scheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ),
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
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
            width: 44,
            child: Text(
              valueText,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
