import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/api_service.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({
    super.key,
    required this.level,
    required this.chapter,
  });

  final String level;
  final int chapter;

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  final ApiService _api = ApiService();
  List<Word> _words = const [];
  int _index = 0;
  bool _loading = true;
  bool _showReading = false;
  bool _showMeaning = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final words = await _api.fetchWords(level: widget.level, chapter: widget.chapter);
      if (!mounted) return;
      setState(() {
        _words = words;
        _index = 0;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Word get _current => _words[_index];

  void _resetReveal() {
    setState(() {
      _showReading = false;
      _showMeaning = false;
    });
  }

  Future<void> _toggleFavorite() async {
    if (_submitting) return;
    final current = _current;
    final next = !current.favorite;
    setState(() {
      _words = [..._words]..[_index] = current.copyWith(favorite: next);
    });
    try {
      final updated = await _api.updateWord(current.id, favorite: next);
      if (!mounted) return;
      setState(() {
        _words = [..._words]..[_index] = updated;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _words = [..._words]..[_index] = current;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('즐겨찾기 저장 실패: $error')),
      );
    }
  }

  Future<void> _advance({required bool markKnown}) async {
    if (_submitting || _words.isEmpty) return;
    final current = _current;
    setState(() => _submitting = true);

    try {
      if (markKnown && !current.known) {
        final updated = await _api.updateWord(current.id, known: true);
        if (!mounted) return;
        setState(() {
          _words = [..._words]..[_index] = updated;
        });
      }

      if (!mounted) return;
      if (_index >= _words.length - 1) {
        setState(() => _submitting = false);
        await _showCompleteDialog();
        return;
      }

      setState(() {
        _index += 1;
        _showReading = false;
        _showMeaning = false;
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('학습 상태 저장 실패: $error')),
      );
    }
  }

  Future<void> _showCompleteDialog() async {
    final known = _words.where((word) => word.known).length;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('챕터 학습 완료'),
        content: Text('${_words.length}단어를 모두 확인했습니다.\n현재 알고 있음: $known/${_words.length}'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: const Text('챕터로 돌아가기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          '${widget.level} · Chapter ${widget.chapter}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }
    if (_words.isEmpty) {
      return const Center(child: Text('이 챕터에는 단어가 없습니다.'));
    }

    final current = _current;
    final scheme = Theme.of(context).colorScheme;
    final answered = _index;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  '$answered/${_words.length}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      value: _words.isEmpty ? 0 : answered / _words.length,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'New',
                              style: TextStyle(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: current.favorite ? '즐겨찾기 해제' : '즐겨찾기 추가',
                            onPressed: _toggleFavorite,
                            icon: Icon(
                              current.favorite ? Icons.star_rounded : Icons.star_border_rounded,
                              color: current.favorite ? scheme.primary : scheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          _RevealIconButton(
                            tooltip: '히라가나',
                            selected: _showReading,
                            icon: Icons.translate_rounded,
                            onPressed: () => setState(() => _showReading = !_showReading),
                          ),
                          const SizedBox(width: 8),
                          _RevealIconButton(
                            tooltip: '의미',
                            selected: _showMeaning,
                            icon: Icons.notes_rounded,
                            onPressed: () => setState(() => _showMeaning = !_showMeaning),
                          ),
                        ],
                      ),
                      const Spacer(flex: 2),
                      if (_showReading && current.reading.isNotEmpty) ...[
                        Text(
                          current.reading,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          current.word,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontSize: 66,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -2,
                              ),
                        ),
                      ),
                      if (_showMeaning && current.meaningKo.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          current.meaningKo,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                      const Spacer(),
                      const Divider(),
                      const Spacer(),
                      Text(
                        current.exampleJa.isEmpty ? '예문이 없습니다.' : current.exampleJa,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              height: 1.55,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      if (_showReading && current.exampleReading.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          current.exampleReading,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                        ),
                      ],
                      if (_showMeaning && current.exampleKo.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          current.exampleKo,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.45,
                              ),
                        ),
                      ],
                      const Spacer(flex: 2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton.outlined(
                          tooltip: '단어 + 예문만 보기',
                          onPressed: (_showReading || _showMeaning) ? _resetReveal : null,
                          icon: const Icon(Icons.undo_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 64,
                    child: OutlinedButton(
                      onPressed: _submitting ? null : () => _advance(markKnown: false),
                      child: const Text(
                        '다시 학습',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 64,
                    child: FilledButton(
                      onPressed: _submitting ? null : () => _advance(markKnown: true),
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              '알고 있음',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealIconButton extends StatelessWidget {
  const _RevealIconButton({
    required this.tooltip,
    required this.selected,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final bool selected;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.outlined(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: selected ? scheme.primaryContainer : null,
      ),
      icon: Icon(icon),
    );
  }
}
