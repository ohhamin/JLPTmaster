import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/api_service.dart';

class WordDetailScreen extends StatefulWidget {
  const WordDetailScreen({super.key, required this.word});

  final Word word;

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  final ApiService _api = ApiService();
  late Word _word;
  bool _savingFavorite = false;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    _word = widget.word;
    _refreshWord();
  }

  Future<void> _refreshWord() async {
    try {
      final fresh = await _api.fetchWord(widget.word.id);
      if (mounted) setState(() => _word = fresh);
    } catch (_) {
      // Keep the already loaded list item if a background refresh fails.
    }
  }

  Future<void> _toggleFavorite() async {
    if (_savingFavorite) return;
    final before = _word;
    setState(() {
      _savingFavorite = true;
      _word = _word.copyWith(favorite: !_word.favorite);
    });
    try {
      final updated = await _api.updateWord(before.id, favorite: !before.favorite);
      if (!mounted) return;
      setState(() {
        _word = updated;
        _savingFavorite = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _word = before;
        _savingFavorite = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('즐겨찾기 저장 실패: $error')),
      );
    }
  }

  Future<void> _requestAiExplanation() async {
    if (_aiLoading) return;
    setState(() => _aiLoading = true);
    try {
      final explanation = await _api.explainWord(_word.id);
      if (!mounted) return;
      setState(() => _aiLoading = false);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, controller) => Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
            child: ListView(
              controller: controller,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded),
                    const SizedBox(width: 8),
                    Text(
                      'AI 단어 · 예문 분석',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SelectableText(
                  explanation,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.65),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _aiLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 설명 요청 실패: $error')),
      );
    }
  }

  void _showRelatedWord(RelatedWord item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.word,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (item.reading.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      item.reading,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (item.level != null)
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(item.level!),
              ),
            if (item.meaningKo.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.meaningKo,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.45),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _word.word,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: _word.favorite ? '즐겨찾기 해제' : '즐겨찾기 추가',
            onPressed: _savingFavorite ? null : _toggleFavorite,
            icon: Icon(
              _word.favorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: _word.favorite ? scheme.primary : null,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
        children: [
          Row(
            children: [
              _Badge(text: _word.level),
              const SizedBox(width: 8),
              _Badge(text: 'Chapter ${_word.chapter}'),
              const Spacer(),
              if (_word.known)
                Text(
                  '알고 있음',
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  _word.word,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              if (_word.reading.isNotEmpty) ...[
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    _word.reading,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _word.meaningKo,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (_word.partOfSpeech.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(_word.partOfSpeech),
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 20),
          Text(
            '예문',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _word.exampleJa.isEmpty ? '예문이 없습니다.' : _word.exampleJa,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (_word.exampleReading.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _word.exampleReading,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                    ),
                  ],
                  if (_word.exampleKo.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _word.exampleKo,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            '예문 속 JLPT 단어',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          if (_word.exampleWords.isEmpty)
            Text(
              '연결된 JLPT 단어가 없습니다.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          else
            ..._word.exampleWords.map(
              (item) => Card(
                child: ListTile(
                  onTap: () => _showRelatedWord(item),
                  leading: item.level == null
                      ? null
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.level!,
                            style: TextStyle(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                  title: Text(
                    item.word,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    [item.reading, item.meaningKo].where((text) => text.isNotEmpty).join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            ),
          const SizedBox(height: 30),
          Text(
            'AI 설명',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              onTap: _aiLoading ? null : _requestAiExplanation,
              leading: const Icon(Icons.auto_awesome_rounded),
              title: const Text(
                'GPT로 단어 · 예문 분석',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('뜻, 연어, 번역, 문법, 주요 어휘를 한국어로 설명합니다.'),
              trailing: _aiLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
