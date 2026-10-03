import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/api_service.dart';
import 'word_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Word>> _favorites;

  @override
  void initState() {
    super.initState();
    _favorites = _api.fetchWords(favorite: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _favorites = _api.fetchWords(
        favorite: true,
        query: _searchController.text,
      );
    });
  }

  Future<void> _refresh() async {
    final future = _api.fetchWords(
      favorite: true,
      query: _searchController.text,
    );
    setState(() => _favorites = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Word>>(
        future: _favorites,
        builder: (context, snapshot) {
          final words = snapshot.data ?? const <Word>[];
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            children: [
              TextField(
                controller: _searchController,
                onChanged: (_) => _reload(),
                decoration: const InputDecoration(
                  hintText: '단어 검색...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 18),
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                const Padding(
                  padding: EdgeInsets.only(top: 160),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 120),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 42),
                      const SizedBox(height: 10),
                      Text(snapshot.error.toString(), textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('다시 시도'),
                      ),
                    ],
                  ),
                )
              else ...[
                Text(
                  '총 ${words.length}단어',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                if (words.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 120),
                    child: Center(child: Text('즐겨찾기한 단어가 없습니다.')),
                  )
                else
                  ...words.map(
                    (word) => _FavoriteRow(
                      word: word,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => WordDetailScreen(word: word),
                          ),
                        );
                        if (mounted) _reload();
                      },
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({required this.word, required this.onTap});

  final Word word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                word.level,
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      word.word,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  if (word.reading.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        word.reading,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 135),
              child: Text(
                word.meaningKo,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
