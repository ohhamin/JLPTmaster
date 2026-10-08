import 'package:flutter/material.dart';

import '../models/word.dart';
import '../widgets/kanji_section.dart';
import '../widgets/copy_text_button.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import '../theme/theme_controller.dart';

class WordDetailScreen extends StatefulWidget {
  const WordDetailScreen({super.key, required this.word});

  final Word word;

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  final ApiService _api = ApiService();
  final TtsService _tts = TtsService.instance;
  late Word _word;
  bool _savingFavorite = false;
  bool _savingKnown = false;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    _word = widget.word;
    _refreshWord();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speakJapanese(String text) async {
    try {
      await _tts.speakJapanese(text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('음성 재생을 사용할 수 없습니다. 기기 TTS의 일본어 음성을 확인해 주세요.'),
        ),
      );
    }
  }

  void _speakWord() {
    _speakJapanese(_word.reading.isNotEmpty ? _word.reading : _word.word);
  }

  Future<void> _refreshWord() async {
    try {
      final fresh = await _api.fetchWord(widget.word.id);
      if (mounted) setState(() => _word = fresh);
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    if (_savingFavorite) return;
    final before = _word;
    final next = !before.favorite;
    setState(() {
      _savingFavorite = true;
      _word = _word.copyWith(favorite: next);
    });
    try {
      final updated = await _api.updateWord(before.id, favorite: next);
      if (!mounted) return;
      setState(() {
        _word = updated.copyWith(kanji: before.kanji);
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

  Future<void> _toggleKnown() async {
    if (_savingKnown) return;
    final before = _word;
    final next = !before.known;
    setState(() {
      _savingKnown = true;
      _word = _word.copyWith(known: next);
    });
    try {
      await _api.queueWordState(before.id, known: next);
      if (!mounted) return;
      setState(() => _savingKnown = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _word = before;
        _savingKnown = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('알고 있음 저장 실패: $error')),
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
          initialChildSize: 0.8,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, controller) => SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
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
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SelectableText(
                    explanation,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.68),
                  ),
                ],
              ),
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
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                item.word,
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ),
                            if (item.reading.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  item.reading,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),,
                  ),
                  CopyTextButton(text: item.word, label: '단어'),
                ],
              ),
              const SizedBox(height: 12),
              if (item.level != null) _SmallBadge(text: item.level!),
              if (item.meaningKo.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  item.meaningKo,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
              if (item.exampleJa.isNotEmpty || item.exampleKo.isNotEmpty) ...[
                const SizedBox(height: 22),
                Divider(color: scheme.outlineVariant),
                const SizedBox(height: 18),
                Text(
                  '예문',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if (item.exampleJa.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                              item.exampleJa,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    height: 1.55,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),,
                      ),
                      CopyTextButton(text: item.exampleJa, label: '예문'),
                    ],
                  ),
                ],
                if (item.exampleKo.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.exampleKo,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final relatedTileWidth = (screenWidth - 52) / 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '단어 상세',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: const [
          ThemeToggleButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 72 + bottomInset),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.75)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _SmallBadge(text: _word.level),
                      const SizedBox(width: 8),
                      _SmallBadge(text: 'CH ${_word.chapter.toString().padLeft(2, '0')}'),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: _word.known ? '알고 있음 해제' : '알고 있음으로 표시',
                        onPressed: _savingKnown ? null : _toggleKnown,
                        icon: Icon(
                          _word.known
                              ? Icons.check_circle_rounded
                              : Icons.check_circle_outline_rounded,
                          color: _word.known ? scheme.primary : scheme.onSurfaceVariant,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: _word.favorite ? '즐겨찾기 해제' : '즐겨찾기 추가',
                        onPressed: _savingFavorite ? null : _toggleFavorite,
                        icon: Icon(
                          _word.favorite ? Icons.star_rounded : Icons.star_border_rounded,
                          color: _word.favorite ? scheme.primary : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Semantics(
                              button: true,
                              label: '${_word.word} 발음 듣기',
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _speakWord,
                                child: Text(
                                  _word.word,
                                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1.2,
                                      ),
                                ),
                              ),
                            ),,
                      ),
                      CopyTextButton(text: _word.word, label: '단어'),
                    ],
                  ),
                  if (_word.reading.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _word.reading,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    _word.meaningKo,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (_word.partOfSpeech.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _word.partOfSpeech,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),
            const _SectionLabel(number: '01', title: '예문'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: 82,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Semantics(
                                    button: _word.exampleJa.isNotEmpty,
                                    label: _word.exampleJa.isEmpty ? null : '예문 발음 듣기',
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: _word.exampleJa.isEmpty
                                          ? null
                                          : () => _speakJapanese(_word.exampleJa),
                                      child: Text(
                                        _word.exampleJa.isEmpty ? '예문이 없습니다.' : _word.exampleJa,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              height: 1.55,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ),,
                            ),
                            if (_word.exampleJa.isNotEmpty)
                          CopyTextButton(text: _word.exampleJa, label: '예문'),
                          ],
                        ),
                        if (_word.exampleReading.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            _word.exampleReading,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                          ),
                        ],
                        if (_word.exampleKo.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            _word.exampleKo,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  height: 1.5,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_word.kanji.isNotEmpty) ...[
              const SizedBox(height: 34),
              const _SectionLabel(number: '02', title: '한자'),
              const SizedBox(height: 14),
              KanjiSection(
                kanji: _word.kanji,
                onSpeak: _speakJapanese,
                showHeading: false,
              ),
            ],
            const SizedBox(height: 34),
            const _SectionLabel(number: '03', title: '예문 속 JLPT 단어'),
            const SizedBox(height: 14),
            if (_word.exampleWords.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  '연결된 JLPT 단어가 없습니다.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _word.exampleWords
                    .map(
                      (item) => SizedBox(
                        width: relatedTileWidth,
                        child: _RelatedTile(
                          item: item,
                          onTap: () => _showRelatedWord(item),
                        ),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 34),
            const _SectionLabel(number: '04', title: 'AI 설명'),
            const SizedBox(height: 14),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _aiLoading ? null : _requestAiExplanation,
                borderRadius: BorderRadius.circular(22),
                child: Ink(
                  padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary.withValues(alpha: 0.15),
                        scheme.surfaceContainerLow,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: scheme.primary.withValues(alpha: 0.28)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.auto_awesome_rounded, color: scheme.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '이 단어를 더 깊게 보기',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '뜻 · 연어 · 문법 · 예문을 한국어로 분석해요.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_aiLoading)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        const Icon(Icons.arrow_forward_rounded),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.number, required this.title});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          number,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _RelatedTile extends StatelessWidget {
  const _RelatedTile({required this.item, required this.onTap});

  final RelatedWord item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 112,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (item.level != null) _SmallBadge(text: item.level!),
                  const Spacer(),
                  CopyTextButton(text: item.word, label: '단어'),
                  Icon(Icons.north_east_rounded, size: 16, color: scheme.onSurfaceVariant),
                ],
              ),
              const Spacer(),
              Text(
                item.word,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                [item.reading, item.meaningKo].where((value) => value.isNotEmpty).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
