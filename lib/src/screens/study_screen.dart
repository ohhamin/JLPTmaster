import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/api_service.dart';
import '../theme/theme_controller.dart';

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
  List<String> _queue = const [];
  bool _loading = true;
  bool _showReading = false;
  bool _showMeaning = false;
  bool _savingFavorite = false;
  bool _reviewMode = false;
  int _reviewIndex = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int get _knownCount => _words.where((word) => word.known).length;

  Word get _current {
    if (_reviewMode) {
      return _words[_reviewIndex % _words.length];
    }
    final currentId = _queue.first;
    return _words.firstWhere((word) => word.id == currentId);
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
        _queue = words.where((word) => !word.known).map((word) => word.id).toList();
        _loading = false;
        _showReading = false;
        _showMeaning = false;
        _reviewMode = false;
        _reviewIndex = 0;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _resetReveal() {
    setState(() {
      _showReading = false;
      _showMeaning = false;
    });
  }

  void _replaceWord(Word updated) {
    final index = _words.indexWhere((word) => word.id == updated.id);
    if (index < 0) return;
    _words = [..._words]..[index] = updated;
  }

  Future<void> _toggleFavorite() async {
    if (_savingFavorite || _words.isEmpty) return;
    final current = _current;
    final next = !current.favorite;
    setState(() {
      _savingFavorite = true;
      _replaceWord(current.copyWith(favorite: next));
    });

    try {
      final updated = await _api.updateWord(current.id, favorite: next);
      if (!mounted) return;
      setState(() {
        _replaceWord(updated);
        _savingFavorite = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _replaceWord(current);
        _savingFavorite = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('즐겨찾기 저장 실패: $error')),
      );
    }
  }

  void _studyAgain() {
    if (_queue.isEmpty) return;
    setState(() {
      if (_queue.length > 1) {
        final currentId = _queue.first;
        _queue = [..._queue.skip(1), currentId];
      }
      _showReading = false;
      _showMeaning = false;
    });
  }

  Future<void> _markKnown() async {
    if (_queue.isEmpty) return;
    final current = _current;

    setState(() {
      _replaceWord(current.copyWith(known: true));
      _queue = _queue.skip(1).toList();
      _showReading = false;
      _showMeaning = false;
    });

    if (current.known) return;
    try {
      await _api.queueWordState(current.id, known: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _replaceWord(current);
        if (!_queue.contains(current.id)) {
          _queue = [..._queue, current.id];
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('학습 상태 저장 실패: $error')),
      );
    }
  }

  void _startReview() {
    setState(() {
      _reviewMode = true;
      _reviewIndex = 0;
      _showReading = false;
      _showMeaning = false;
    });
  }

  void _nextReviewWord() {
    if (_words.isEmpty) return;
    setState(() {
      _reviewIndex = (_reviewIndex + 1) % _words.length;
      _showReading = false;
      _showMeaning = false;
    });
  }

  Future<void> _toggleKnownInReview() async {
    if (_words.isEmpty) return;
    final current = _current;
    final next = !current.known;
    setState(() => _replaceWord(current.copyWith(known: next)));

    try {
      await _api.queueWordState(current.id, known: next);
    } catch (error) {
      if (!mounted) return;
      setState(() => _replaceWord(current));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('학습 상태 저장 실패: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          '${widget.level}  ·  ${widget.chapter.toString().padLeft(2, '0')}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: const [
          ThemeToggleButton(),
          SizedBox(width: 8),
        ],
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
    if (!_reviewMode && _queue.isEmpty) {
      return _AlreadyComplete(
        total: _words.length,
        onBack: () => Navigator.of(context).pop(),
        onReview: _startReview,
      );
    }

    final current = _current;
    final scheme = Theme.of(context).colorScheme;
    final known = _knownCount;
    final total = _words.length;
    final progress = total == 0 ? 0.0 : known / total;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
        child: Column(
          children: [
            if (!_reviewMode) ...[
              _ProgressHeader(
                known: known,
                total: total,
                remaining: _queue.length,
                progress: progress,
              ),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 4),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.9),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.11),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _reviewMode
                                  ? '다시보기 ${_reviewIndex + 1}/$total'
                                  : '${_queue.length}개 남음',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: current.favorite ? '즐겨찾기 해제' : '즐겨찾기 추가',
                            onPressed: _savingFavorite ? null : _toggleFavorite,
                            icon: Icon(
                              current.favorite ? Icons.star_rounded : Icons.star_border_rounded,
                              color: current.favorite ? scheme.primary : scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(8, 18, 8, 20),
                          child: Column(
                            children: [
                              if (current.reading.isNotEmpty) ...[
                                AnimatedOpacity(
                                  opacity: _showReading ? 1 : 0,
                                  duration: const Duration(milliseconds: 140),
                                  child: Text(
                                    current.reading,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  current.word,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                        fontSize: 68,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -2.2,
                                      ),
                                ),
                              ),
                              if (current.meaningKo.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                AnimatedOpacity(
                                  opacity: _showMeaning ? 1 : 0,
                                  duration: const Duration(milliseconds: 140),
                                  child: Text(
                                    current.meaningKo,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 28),
                              Row(
                                children: [
                                  Container(
                                    width: 18,
                                    height: 2,
                                    color: scheme.primary.withValues(alpha: 0.8),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'EXAMPLE',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.4,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  current.exampleJa.isEmpty ? '예문이 없습니다.' : current.exampleJa,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        height: 1.55,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              if (current.exampleReading.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                AnimatedOpacity(
                                  opacity: _showReading ? 1 : 0,
                                  duration: const Duration(milliseconds: 140),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      current.exampleReading,
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            height: 1.5,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                              if (current.exampleKo.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                AnimatedOpacity(
                                  opacity: _showMeaning ? 1 : 0,
                                  duration: const Duration(milliseconds: 140),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      current.exampleKo,
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            height: 1.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      _RevealBar(
                        showReading: _showReading,
                        showMeaning: _showMeaning,
                        onReading: () => setState(() => _showReading = !_showReading),
                        onMeaning: () => setState(() => _showMeaning = !_showMeaning),
                        onReset: _resetReveal,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_reviewMode)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: OutlinedButton.icon(
                        onPressed: _nextReviewWord,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                        label: const Text(
                          '다음 단어',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: FilledButton.icon(
                        onPressed: _toggleKnownInReview,
                        icon: Icon(
                          current.known
                              ? Icons.remove_circle_outline_rounded
                              : Icons.check_rounded,
                          size: 20,
                        ),
                        label: Text(
                          current.known ? '알고 있음 해제' : '알고 있음',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: OutlinedButton.icon(
                        onPressed: _studyAgain,
                        icon: const Icon(Icons.replay_rounded, size: 20),
                        label: const Text(
                          '다시 학습',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: FilledButton.icon(
                        onPressed: _markKnown,
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text(
                          '알고 있음',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.known,
    required this.total,
    required this.remaining,
    required this.progress,
  });

  final int known;
  final int total;
  final int remaining;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Text(
              '알고 있음 $known / $total',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const Spacer(),
            Text(
              '$remaining개 학습 중',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: progress,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _RevealBar extends StatelessWidget {
  const _RevealBar({
    required this.showReading,
    required this.showMeaning,
    required this.onReading,
    required this.onMeaning,
    required this.onReset,
  });

  final bool showReading;
  final bool showMeaning;
  final VoidCallback onReading;
  final VoidCallback onMeaning;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasReveal = showReading || showMeaning;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _RevealChoice(
              label: '히라가나',
              icon: Icons.translate_rounded,
              selected: showReading,
              onTap: onReading,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _RevealChoice(
              label: '의미',
              icon: Icons.subject_rounded,
              selected: showMeaning,
              onTap: onMeaning,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: '가리기',
            onPressed: hasReveal ? onReset : null,
            icon: const Icon(Icons.undo_rounded),
          ),
        ],
      ),
    );
  }
}

class _RevealChoice extends StatelessWidget {
  const _RevealChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlreadyComplete extends StatelessWidget {
  const _AlreadyComplete({
    required this.total,
    required this.onBack,
    required this.onReview,
  });

  final int total;
  final VoidCallback onBack;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.done_all_rounded, color: scheme.primary, size: 34),
              ),
              const SizedBox(height: 18),
              Text(
                '이 챕터는 완료했어요',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '$total개 단어가 모두 알고 있음 상태입니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 240,
                child: FilledButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('챕터 목록으로'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 240,
                child: OutlinedButton.icon(
                  onPressed: onReview,
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('챕터 단어 다시보기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
