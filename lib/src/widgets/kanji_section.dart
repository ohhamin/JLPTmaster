import 'package:flutter/material.dart';

import '../models/word.dart';
import '../theme/app_typography.dart';
import 'copy_text_button.dart';
import 'tts_pressable.dart';

/// Minimal per-character reference cards. No JLPT grade or related-word list.
class KanjiSection extends StatelessWidget {
  const KanjiSection({
    super.key,
    required this.kanji,
    this.onSpeak,
    this.showHeading = true,
  });

  final List<KanjiInfo> kanji;
  final ValueChanged<String>? onSpeak;
  final bool showHeading;

  @override
  Widget build(BuildContext context) {
    if (kanji.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeading) ...[
          Text(
            '한자 (${kanji.length})',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 14),
        ],
        for (final item in kanji) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.65)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 66,
                  child: onSpeak != null && item.onyomi.isNotEmpty
                      ? Semantics(
                          button: true,
                          label: '${item.character} 음독 발음 듣기',
                          child: TtsPressable(
                            onPressed: () => onSpeak!(item.onyomi.first),
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.zero,
                            child: Text(
                              item.character,
                              style: AppTypography.japanese(
                                Theme.of(context).textTheme.displaySmall,
                              ).copyWith(fontSize: 40, height: 1.2),
                            ),
                          ),
                        )
                      : Text(
                          item.character,
                          style: AppTypography.japanese(
                            Theme.of(context).textTheme.displaySmall,
                          ).copyWith(fontSize: 40, height: 1.2),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.meaningKo,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      _ReadingLine(title: '음독', values: item.onyomi),
                      const SizedBox(height: 6),
                      _ReadingLine(title: '훈독', values: item.kunyomi),
                    ],
                  ),
                ),
                CopyTextButton(text: item.character, label: '한자'),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ReadingLine extends StatelessWidget {
  const _ReadingLine({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            values.isEmpty ? '—' : values.join(' · '),
            style: AppTypography.japanese(
              Theme.of(context).textTheme.bodyMedium,
            ).copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}
