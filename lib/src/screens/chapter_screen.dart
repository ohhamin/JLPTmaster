import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/study_summary.dart';
import '../services/api_service.dart';
import '../services/study_progress_service.dart';
import '../theme/theme_controller.dart';
import 'study_screen.dart';

class ChapterScreen extends StatefulWidget {
  const ChapterScreen({super.key, required this.level});

  final String level;

  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterPageData {
  const _ChapterPageData({
    required this.chapters,
    required this.rounds,
    required this.finalRounds,
  });

  final List<ChapterSummary> chapters;
  final Map<int, int> rounds;
  final int finalRounds;
}

class _ChapterScreenState extends State<ChapterScreen> {
  final ApiService _api = ApiService();
  final StudyProgressService _progress = StudyProgressService.instance;
  late Future<_ChapterPageData> _data;

  @override
  void initState() {
    super.initState();
    _data = _loadData();
  }

  Future<_ChapterPageData> _loadData() async {
    final chapters = await _api.fetchChapters(widget.level);
    final rounds = await _progress.chapterRounds(
      widget.level,
      chapters.map((item) => item.chapter),
    );

    // Migrate the old "all known = completed" state into the new round model.
    // Once a chapter reaches 100%, its known flags are cleared and the first
    // round is recorded immediately.
    for (final chapter in chapters.where((item) => item.completed)) {
      final words = await _api.fetchWords(
        level: widget.level,
        chapter: chapter.chapter,
      );
      if (words.isNotEmpty) {
        await Future.wait(
          words.map(
            (word) => _api.queueWordState(word.id, known: false),
          ),
        );
      }
      if ((rounds[chapter.chapter] ?? 0) == 0) {
        rounds[chapter.chapter] = await _progress.incrementRound(
          widget.level,
          chapter.chapter,
        );
      }
    }

    final finalRounds = await _progress.rounds(widget.level, 0);
    return _ChapterPageData(
      chapters: chapters,
      rounds: rounds,
      finalRounds: finalRounds,
    );
  }

  Future<void> _refresh() async {
    final future = _loadData();
    setState(() => _data = future);
    await future;
  }

  Future<void> _openStudy(int chapter) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StudyScreen(
          level: widget.level,
          chapter: chapter,
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = 96.0 + MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.level} 챕터',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: const [
          ThemeToggleButton(),
          SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_ChapterPageData>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 240),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }
            if (snapshot.hasError) {
              return _ChapterError(
                message: snapshot.error.toString(),
                onRetry: () => setState(() => _data = _loadData()),
              );
            }

            final data = snapshot.data;
            final chapters = data?.chapters ?? const <ChapterSummary>[];
            if (chapters.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 240),
                  Center(child: Text('아직 이 등급에 등록된 단어가 없습니다.')),
                ],
              );
            }

            final groups = <List<ChapterSummary>>[];
            for (var index = 0; index < chapters.length; index += 6) {
              groups.add(chapters.sublist(index, math.min(index + 6, chapters.length)));
            }
            final totalWords = groups.fold<int>(
              0,
              (sum, group) => sum + group.last.total,
            );

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPadding),
              itemCount: groups.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: _ChapterHeader(
                      level: widget.level,
                      total: chapters.length,
                    ),
                  );
                }

                if (index == groups.length + 1) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _FinalSetCard(
                      level: widget.level,
                      totalWords: totalWords,
                      rounds: data?.finalRounds ?? 0,
                      onTap: () => _openStudy(0),
                    ),
                  );
                }

                final group = groups[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ChapterGroup(
                    groupIndex: index,
                    chapters: group,
                    rounds: data?.rounds ?? const <int, int>{},
                    onTap: (chapter) => _openStudy(chapter.chapter),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ChapterHeader extends StatelessWidget {
  const _ChapterHeader({
    required this.level,
    required this.total,
  });

  final String level;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            level,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                ),
          ),
          const SizedBox(width: 14),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '$total개 챕터 · 완료할 때마다 회독 +1',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterGroup extends StatelessWidget {
  const _ChapterGroup({
    required this.groupIndex,
    required this.chapters,
    required this.rounds,
    required this.onTap,
  });

  final int groupIndex;
  final List<ChapterSummary> chapters;
  final Map<int, int> rounds;
  final ValueChanged<ChapterSummary> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final first = chapters.first;
    final last = chapters.last;
    final rangeLabel = first.chapter == last.chapter
        ? 'Chapter ${first.chapter}'
        : 'Chapter ${first.chapter}–${last.chapter}';
    final wordsLabel = first.total == last.total
        ? '${first.total}단어'
        : '${first.total} → ${last.total}단어';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    'SET ${groupIndex.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rangeLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Text(
                  '$wordsLabel 누적',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          ...chapters.indexed.map((entry) {
            final itemIndex = entry.$1;
            final chapter = entry.$2;
            return Padding(
              padding: EdgeInsets.only(bottom: itemIndex == chapters.length - 1 ? 0 : 8),
              child: _ChapterRow(
                summary: chapter,
                rounds: rounds[chapter.chapter] ?? 0,
                onTap: () => onTap(chapter),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ChapterRow extends StatelessWidget {
  const _ChapterRow({
    required this.summary,
    required this.rounds,
    required this.onTap,
  });

  final ChapterSummary summary;
  final int rounds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final completedBefore = rounds > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.72)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: completedBefore
                        ? scheme.primary.withValues(alpha: 0.14)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: completedBefore
                      ? Icon(Icons.done_all_rounded, color: scheme.primary)
                      : Text(
                          summary.chapter.toString().padLeft(2, '0'),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Chapter ${summary.chapter}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: completedBefore
                        ? scheme.primary.withValues(alpha: 0.11)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$rounds회독',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: completedBefore ? scheme.primary : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FinalSetCard extends StatelessWidget {
  const _FinalSetCard({
    required this.level,
    required this.totalWords,
    required this.rounds,
    required this.onTap,
  });

  final String level;
  final int totalWords;
  final int rounds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(18, 17, 16, 17),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'SET Final',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$level 전체 단어',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalWords단어 · 전체 복습 · $rounds회독',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 17,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterError extends StatelessWidget {
  const _ChapterError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 180),
        const Icon(Icons.error_outline_rounded, size: 42),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('다시 시도'),
          ),
        ),
      ],
    );
  }
}
