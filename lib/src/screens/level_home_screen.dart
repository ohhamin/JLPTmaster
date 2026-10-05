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

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
            itemCount: levels.length + 1,
            separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 20 : 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const _LevelHeader();
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
  const _LevelHeader();

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
          '6챕터 단위로 누적 복습하고, 완료할 때마다 회독 수를 쌓아요.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
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
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 58,
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
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${summary.total}단어 · ${summary.chapters}챕터',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '즐겨찾기 ${summary.favorites} · 챕터를 골라 반복 학습',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 17,
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
