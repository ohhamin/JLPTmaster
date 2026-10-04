import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/study_summary.dart';
import '../services/api_service.dart';
import '../theme/theme_controller.dart';
import 'study_screen.dart';

class ChapterScreen extends StatefulWidget {
  const ChapterScreen({super.key, required this.level});

  final String level;

  @override
  State<ChapterScreen> createState() => _ChapterScreenState();
}

class _ChapterScreenState extends State<ChapterScreen> {
  final ApiService _api = ApiService();
  late Future<List<ChapterSummary>> _chapters;

  @override
  void initState() {
    super.initState();
    _chapters = _api.fetchChapters(widget.level);
  }

  Future<void> _refresh() async {
    final future = _api.fetchChapters(widget.level);
    setState(() => _chapters = future);
    await future;
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
        child: FutureBuilder<List<ChapterSummary>>(
          future: _chapters,
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
                onRetry: () => setState(() => _chapters = _api.fetchChapters(widget.level)),
              );
            }

            final chapters = snapshot.data ?? const <ChapterSummary>[];
            if (chapters.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 240),
                  Center(child: Text('아직 이 등급에 등록된 단어가 없습니다.')),
                ],
              );
            }

            final completed = chapters.where((item) => item.completed).length;
            final groups = <List<ChapterSummary>>[];
            for (var index = 0; index < chapters.length; index += 6) {
              groups.add(chapters.sublist(index, math.min(index + 6, chapters.length)));
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPadding),
              itemCount: groups.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: _ChapterHeader(
                      level: widget.level,
                      completed: completed,
                      total: chapters.length,
                    ),
                  );
                }

                final group = groups[index - 1];
                return Padding(
                  padding: EdgeInsets.only(bottom: index == groups.length ? 0 : 16),
                  child: _ChapterGroup(
                    groupIndex: index,
                    chapters: group,
                    onTap: (chapter) async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => StudyScreen(
                            level: widget.level,
                            chapter: chapter.chapter,
                          ),
                        ),
                      );
                      if (mounted) await _refresh();
                    },
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
    required this.completed,
    required this.total,
  });

  final String level;
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = total == 0 ? 0.0 : completed / total;
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completed / $total 챕터 완료',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: progress,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ],
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
    required this.onTap,
  });

  final int groupIndex;
  final List<ChapterSummary> chapters;
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
  const _ChapterRow({required this.summary, required this.onTap});

  final ChapterSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final complete = summary.completed;

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
                    color: complete
                        ? scheme.primary.withValues(alpha: 0.14)
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: complete
                      ? Icon(Icons.check_rounded, color: scheme.primary)
                      : Text(
                          summary.chapter.toString().padLeft(2, '0'),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
                        'Chapter ${summary.chapter}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                minHeight: 5,
                                value: summary.progress,
                                backgroundColor: scheme.surfaceContainerHighest,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${summary.known}/${summary.total}',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: scheme.onSurfaceVariant),
              ],
            ),
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
