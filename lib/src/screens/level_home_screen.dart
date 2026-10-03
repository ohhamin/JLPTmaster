import 'package:flutter/material.dart';

import '../models/study_summary.dart';
import '../services/api_service.dart';
import 'chapter_screen.dart';

class LevelHomeScreen extends StatefulWidget {
  const LevelHomeScreen({super.key});

  @override
  State<LevelHomeScreen> createState() => _LevelHomeScreenState();
}

class _LevelHomeScreenState extends State<LevelHomeScreen> {
  final ApiService _api = ApiService();
  late Future<List<LevelSummary>> _levels;

  @override
  void initState() {
    super.initState();
    _levels = _api.fetchLevels();
  }

  Future<void> _refresh() async {
    final future = _api.fetchLevels();
    setState(() => _levels = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<LevelSummary>>(
        future: _levels,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 280),
                Center(child: CircularProgressIndicator()),
              ],
            );
          }
          if (snapshot.hasError) {
            return _LevelError(
              message: snapshot.error.toString(),
              onRetry: () => setState(() => _levels = _api.fetchLevels()),
            );
          }

          final levels = snapshot.data ?? const <LevelSummary>[];
          final totalWords = levels.fold<int>(0, (sum, item) => sum + item.total);
          final knownWords = levels.fold<int>(0, (sum, item) => sum + item.known);

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
            itemCount: levels.length + 1,
            separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 22 : 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _LevelHeader(
                  knownWords: knownWords,
                  totalWords: totalWords,
                );
              }

              final item = levels[index - 1];
              return _LevelCard(
                summary: item,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ChapterScreen(level: item.level),
                    ),
                  );
                  if (mounted) _refresh();
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _LevelHeader extends StatelessWidget {
  const _LevelHeader({required this.knownWords, required this.totalWords});

  final int knownWords;
  final int totalWords;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '오늘은 어디서 시작할까요?',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          '등급을 고르면 50단어 단위 챕터로 이어서 학습할 수 있어요.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                '전체 진행',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              Text(
                '$knownWords / $totalWords',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.summary, required this.onTap});

  final LevelSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = (summary.progress * 100).round();
    final levelNumber = int.tryParse(summary.level.replaceFirst('N', '')) ?? 5;
    final accentAlpha = 0.56 + ((6 - levelNumber) * 0.07);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 76,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: accentAlpha.clamp(0.0, 1.0)),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 74,
                  child: Text(
                    summary.level,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                        ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${summary.total}단어 · ${summary.chapters}챕터',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${summary.known}개 알고 있음  ·  즐겨찾기 ${summary.favorites}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 5,
                          value: summary.progress,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: summary.progress,
                        strokeWidth: 4,
                        backgroundColor: scheme.surfaceContainerHighest,
                        strokeCap: StrokeCap.round,
                      ),
                      Text(
                        '$percent%',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelError extends StatelessWidget {
  const _LevelError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 180),
        const Icon(Icons.cloud_off_rounded, size: 44),
        const SizedBox(height: 12),
        const Text('서버에 연결할 수 없습니다.', textAlign: TextAlign.center),
        const SizedBox(height: 8),
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
