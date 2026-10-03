import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.themeMode,
    required this.onThemePressed,
  });

  final ThemeMode themeMode;
  final VoidCallback onThemePressed;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  final _searchController = TextEditingController();
  String _level = 'ALL';
  late Future<List<Word>> _words;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _words = _api.fetchWords(
      level: _level,
      query: _searchController.text,
    );
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _words;
  }

  IconData get _themeIcon => switch (widget.themeMode) {
        ThemeMode.system => Icons.brightness_auto_rounded,
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        titleSpacing: 20,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 16,
              child: Text('J', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            SizedBox(width: 10),
            Text('JLPTmaster', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '테마 변경',
            onPressed: widget.onThemePressed,
            icon: Icon(_themeIcon),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                sliver: SliverList.list(
                  children: [
                    Text(
                      '오늘도 한 단어씩.',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '필요한 단어를 빠르게 찾고, JLPT 레벨별로 정리하세요.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _searchController,
                      onSubmitted: (_) => setState(_reload),
                      decoration: InputDecoration(
                        hintText: '일본어 · 읽기 · 한국어 뜻 검색',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(_reload),
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: const ['ALL', 'N5', 'N4', 'N3', 'N2', 'N1'].length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final level = const ['ALL', 'N5', 'N4', 'N3', 'N2', 'N1'][index];
                          return ChoiceChip(
                            label: Text(level == 'ALL' ? '전체' : level),
                            selected: _level == level,
                            onSelected: (_) {
                              setState(() {
                                _level = level;
                                _reload();
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              FutureBuilder<List<Word>>(
                future: _words,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ErrorState(
                        message: snapshot.error.toString(),
                        onRetry: () => setState(_reload),
                      ),
                    );
                  }
                  final words = snapshot.data ?? const <Word>[];
                  if (words.isEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('아직 등록된 단어가 없습니다.')),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverList.separated(
                      itemCount: words.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _WordCard(word: words[index]),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({required this.word});

  final Word word;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        word.word,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(word.level, style: Theme.of(context).textTheme.labelSmall),
                      ),
                    ],
                  ),
                  if (word.reading.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(word.reading, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    word.meaningKo,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              word.favorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: word.favorite ? Theme.of(context).colorScheme.primary : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 42),
            const SizedBox(height: 14),
            const Text('서버에 연결할 수 없습니다.'),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
