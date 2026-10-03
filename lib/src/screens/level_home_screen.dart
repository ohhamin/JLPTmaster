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
            return const ListView(
              physics: AlwaysScrollableScrollPhysics(),
              children: [SizedBox(height: 280), Center(child: CircularProgressIndicator())],
            );
          }
          if (snapshot.hasError) {
            return _LevelError(
              message: snapshot.error.toString(),
              onRetry: () => setState(() => _levels = _api.fetchLevels()),
            );
          }

          final levels = snapshot.data ?? const <LevelSummary>[];
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              Text(
                '어느 단계부터 공부할까요?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'JLPT 등급을 선택한 뒤 50단어 단위의 챕터로 학습합니다.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                height: 410,
                child: PageView.builder(
                  controller: PageController(viewportFraction: 0.86),
                  itemCount: levels.length,
                  padEnds: false,
                  itemBuilder: (context, index) {
                    final item = levels[index];
                    return Padding(
                      padding: EdgeInsets.only(right: index == levels.length - 1 ? 0 : 14),
                      child: _LevelCard(
                        summary: item,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ChapterScreen(level: item.level),
                            ),
                          );
                          if (mounted) _refresh();
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '카드를 좌우로 넘겨 N5 → N1을 선택할 수 있습니다.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          );
        },
      ),
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              left: -30,
              right: -30,
              bottom: -80,
              height: 250,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(90),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primaryContainer.withValues(alpha: 0.45),
                      scheme.primary.withValues(alpha: 0.18),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${summary.total}단어 · ${summary.chapters}챕터',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    summary.level,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                        ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value: summary.progress,
                            backgroundColor: scheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '${summary.known}/${summary.total}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 18, color: scheme.primary),
                      const SizedBox(width: 5),
                      Text('즐겨찾기 ${summary.favorites}'),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
