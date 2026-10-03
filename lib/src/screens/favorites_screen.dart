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
    return FutureBuilder<List<Word>>(
      future: _favorites,
      builder: (context, snapshot) {
        final words = snapshot.data ?? const <Word>[];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => _reload(),
                        decoration: const InputDecoration(
                          hintText: '즐겨찾기 검색',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Text(
                            'MY WORDS',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                          ),
                          const Spacer(),
                          Text(
                            '${words.length}개',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _FavoriteError(
                    message: snapshot.error.toString(),
                    onRetry: _reload,
                  ),
                )
              else if (words.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyFavorites(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisExtent: 158,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final word = words[index];
                        return _FavoriteTile(
                          word: word,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => WordDetailScreen(word: word),
                              ),
                            );
                            if (mounted) _reload();
                          },
                        );
                      },
                      childCount: words.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({required this.word, required this.onTap});

  final Word word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.52)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      word.level,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.star_rounded, size: 18, color: scheme.primary),
                ],
              ),
              const Spacer(),
              Text(
                word.word,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              if (word.reading.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  word.reading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                word.meaningKo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_outline_rounded, size: 46, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              '아직 모아둔 단어가 없어요',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '학습 중 별을 누르면 여기에 저장됩니다.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteError extends StatelessWidget {
  const _FavoriteError({required this.message, required this.onRetry});

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
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
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
