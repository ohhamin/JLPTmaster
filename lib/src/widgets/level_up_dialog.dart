import 'package:flutter/material.dart';

import '../services/card_customization_service.dart';
import '../services/gamification_service.dart';
import 'card_decoration.dart';

class LevelUpDialog {
  const LevelUpDialog._();

  static CardDecorationDefinition? _definition(String id) {
    for (final item in cardDecorationCatalog) {
      if (item.id == id) return item;
    }
    return null;
  }

  static Future<void> show(
    BuildContext context,
    ExperienceReward reward,
  ) async {
    if (!reward.leveledUp) return;

    List<String> unlocked = const [];
    try {
      unlocked = await CardCustomizationService.instance.grantRandomDecorations(
        reward.levelsGained <= 0 ? 1 : reward.levelsGained,
      );
    } catch (_) {}
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        final definitions = unlocked
            .map(_definition)
            .whereType<CardDecorationDefinition>()
            .toList(growable: false);
        return AlertDialog(
          icon: Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              color: scheme.primary,
              size: 36,
            ),
          ),
          title: Text(
            '레벨 업!  Lv.${reward.level}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                reward.levelsGained > 1
                    ? '${reward.levelsGained}레벨 상승했어요.\n다음 레벨까지 ${reward.experience} / ${reward.xpRequired} XP'
                    : '새로운 레벨에 도달했어요.\n다음 레벨까지 ${reward.experience} / ${reward.xpRequired} XP',
                textAlign: TextAlign.center,
              ),
              if (definitions.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  definitions.length > 1 ? '새 장식이 해금됐어요!' : '새 장식이 해금됐어요!',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    for (final definition in definitions)
                      Container(
                        width: 92,
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CardDecorationVisual(
                              assetId: definition.id,
                              size: 54,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              definition.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }
}
