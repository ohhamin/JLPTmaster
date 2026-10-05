import 'package:flutter/material.dart';

import '../services/gamification_service.dart';
import 'card_decoration.dart';

class AttendanceDialog {
  const AttendanceDialog._();

  static Future<void> show(
    BuildContext context,
    ExperienceReward reward,
  ) async {
    if (!reward.attendanceAwarded || reward.xpGained <= 0) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _AttendanceDialogBody(reward: reward),
    );
  }
}

class _AttendanceDialogBody extends StatelessWidget {
  const _AttendanceDialogBody({required this.reward});

  final ExperienceReward reward;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = reward.xpRequired <= 0
        ? 0.0
        : (reward.experience / reward.xpRequired).clamp(0.0, 1.0).toDouble();
    final rewardDecorationId = reward.streakRewardDecorationId;
    final rewardDecoration = rewardDecorationId == null
        ? null
        : cardDecorationById(rewardDecorationId);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 30),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 390),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.22),
            width: 1.4,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0B8),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF6B4636),
                    width: 2.4,
                  ),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 39,
                  color: Color(0xFF6B4636),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '오늘도 출석 완료!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: 7),
              Text(
                '${reward.currentAttendanceStreak}일 연속 출석 중!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '최고 연속 출석 ${reward.maxAttendanceStreak}일',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (rewardDecorationId != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${reward.currentAttendanceStreak}일 연속 출석 보너스!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: scheme.primary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      CardDecorationVisual(
                        assetId: rewardDecorationId,
                        size: 68,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${rewardDecoration?.label ?? '장식 $rewardDecorationId'} 획득!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                '꾸준히 공부한 보상으로 경험치를 받았어요.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8DF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFE9C960),
                    width: 1.4,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFE3AA22),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '경험치 +${reward.xpGained}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF6B4636),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    'Lv.${reward.level}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    '${reward.experience} / ${reward.xpRequired} XP',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _AttendanceProgressBar(progress: progress),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '좋아!',
                    style: TextStyle(fontWeight: FontWeight.w900),
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

class _AttendanceProgressBar extends StatelessWidget {
  const _AttendanceProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0).toDouble();
    return Container(
      height: 18,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF6B4636),
          width: 2,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                width: constraints.maxWidth * value,
                decoration: BoxDecoration(
                  color: const Color(0xFFB8EBCB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
