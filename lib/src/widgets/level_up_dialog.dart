import 'package:flutter/material.dart';

import '../services/gamification_service.dart';

class LevelUpDialog {
  const LevelUpDialog._();

  static Future<void> show(
    BuildContext context,
    ExperienceReward reward,
  ) async {
    if (!reward.leveledUp) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
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
          content: Text(
            reward.levelsGained > 1
                ? '${reward.levelsGained}레벨 상승했어요.\n다음 레벨까지 ${reward.experience} / ${reward.xpRequired} XP'
                : '새로운 레벨에 도달했어요.\n다음 레벨까지 ${reward.experience} / ${reward.xpRequired} XP',
            textAlign: TextAlign.center,
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
