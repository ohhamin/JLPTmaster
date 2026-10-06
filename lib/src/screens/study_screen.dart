import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/api_service.dart';
import '../services/feedback_sound_service.dart';
import '../services/study_progress_service.dart';
import '../services/tts_service.dart';
import '../theme/app_typography.dart';
import '../theme/theme_controller.dart';
import '../widgets/level_up_dialog.dart';
import '../widgets/tts_pressable.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({
    super.key,
    required this.level,
    required this.chapter,
  });

  final String level;

  /// 1+ = regular cumulative chapter, 0 = SET Final for the whole level.
  final int chapter;

  bool get isFinal => chapter == 0;

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  final ApiService _api = ApiService();
  final TtsService _tts = TtsService.instance;
  final StudyProgressService _progress = StudyProgressService.instance;

  List<Word> _words = const [];
  List<String> _queue = const [];
  Set<String> _finalKnownIds = <String>{};

  bool _loading = true;
  bool _showReading = false;
  bool _showMeaning = false;
  bool _savingFavorite = false;
  bool _completingRound = false;
  bool _completionInFlight = false;
  bool _advancingWord = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  int get _knownCount => _words.where((word) => word.known).length;

  Word get _current {
    final currentId = _queue.first;
    return _words.firstWhere((word) => word.id == currentId);
  }

  List<String> _queueFromCursor(List<Word> words, String? cursor) {
    final remaining = words
        .where((word) => !word.known)
        .map((word) => word.id)
        .toList(growable: false);
    if (remaining.isEmpty || cursor == null || cursor.isEmpty) return remaining;

    final exactIndex = remaining.indexOf(cursor);
    if (exactIndex >= 0) {
      return [...remaining.skip(exactIndex), ...remaining.take(exactIndex)];
    }

    final originalIndex = words.indexWhere((word) => word.id == cursor);
    if (originalIndex < 0) return remaining;

    for (var offset = 0; offset < words.length; offset++) {
      final candidate = words[(originalIndex + offset) % words.length].id;
      final remainingIndex = remaining.indexOf(candidate);
      if (remainingIndex >= 0) {
        return [
          ...remaining.skip(remainingIndex),
          ...remaining.take(remainingIndex),
        ];
      }
    }
    return remaining;
  }

  Future<void> _saveCursor(String? wordId) async {
    try {
      await _api.setStudyCursor(widget.level, widget.chapter, wordId);
    } catch (_) {
      // The word state remains authoritative; cursor save can retry on the next move.
    }
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

  void _speakWord(Word word) {
    _speakJapanese(word.reading.isNotEmpty ? word.reading : word.word);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _completingRound = false;
    });

    try {
      List<Word> words;
      if (widget.isFinal) {
        final fetched = await _api.fetchWords(level: widget.level);
        final knownIds = await _progress.finalKnown(widget.level);
        _finalKnownIds = knownIds;
        words = fetched
            .map((word) => word.copyWith(known: knownIds.contains(word.id)))
            .toList();
      } else {
        words = await _api.fetchWords(
          level: widget.level,
          chapter: widget.chapter,
        );
      }

      final cursor = await _api.fetchStudyCursor(widget.level, widget.chapter);
      final queue = _queueFromCursor(words, cursor);

      if (!mounted) return;
      setState(() {
        _words = words;
        _queue = queue;
        _loading = false;
        _showReading = false;
        _showMeaning = false;
        _completingRound = words.isNotEmpty && queue.isEmpty;
      });

      if (words.isNotEmpty && queue.isEmpty) {
        await _completeRound();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _completingRound = false;
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

  Future<void> _hideRevealBeforeAdvance() async {
    if (!_showReading && !_showMeaning) return;

    setState(() {
      _advancingWord = true;
      _showReading = false;
      _showMeaning = false;
    });

    // Let the reveal fade-out finish before swapping the current word.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
  }

  void _finishAdvance() {
    if (!mounted || !_advancingWord) return;
    setState(() => _advancingWord = false);
  }

  void _replaceWord(Word updated) {
    final index = _words.indexWhere((word) => word.id == updated.id);
    if (index < 0) return;
    _words = [..._words]..[index] = updated;
  }

  Future<void> _toggleFavorite() async {
    if (_savingFavorite || _words.isEmpty || _queue.isEmpty) return;
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
        _replaceWord(updated.copyWith(known: current.known));
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

  Future<void> _studyAgain() async {
    if (_queue.isEmpty || _completingRound || _advancingWord) return;
    _tts.stop();

    final hadReveal = _showReading || _showMeaning;
    if (hadReveal) {
      await _hideRevealBeforeAdvance();
      if (!mounted) return;
    } else {
      setState(() => _advancingWord = true);
    }

    String? nextWordId;
    setState(() {
      if (_queue.length > 1) {
        final currentId = _queue.first;
        _queue = [..._queue.skip(1), currentId];
      }
      nextWordId = _queue.isEmpty ? null : _queue.first;
      _showReading = false;
      _showMeaning = false;
      _advancingWord = false;
    });
    await _saveCursor(nextWordId);
  }

  Future<void> _persistKnown(Word word, bool known) async {
    if (widget.isFinal) {
      if (known) {
        _finalKnownIds.add(word.id);
      } else {
        _finalKnownIds.remove(word.id);
      }
      await _progress.setFinalKnown(widget.level, _finalKnownIds);
      return;
    }

    await _api.queueWordState(word.id, known: known);
  }

  Future<void> _markKnown() async {
    if (_queue.isEmpty || _completingRound || _advancingWord) return;
    final current = _current;
    _tts.stop();

    final hadReveal = _showReading || _showMeaning;
    if (hadReveal) {
      await _hideRevealBeforeAdvance();
      if (!mounted) return;
    } else {
      setState(() => _advancingWord = true);
    }

    final nextQueue = _queue.skip(1).toList();
    final finished = nextQueue.isEmpty;

    setState(() {
      _replaceWord(current.copyWith(known: true));
      _queue = nextQueue;
      _showReading = false;
      _showMeaning = false;
      _advancingWord = false;
      if (finished) _completingRound = true;
    });

    if (current.known) {
      if (finished) await _completeRound();
      return;
    }

    try {
      await _persistKnown(current, true);
    } catch (error) {
      if (!mounted) return;
      if (widget.isFinal) {
        _finalKnownIds.remove(current.id);
      }
      setState(() {
        _replaceWord(current);
        if (!_queue.contains(current.id)) {
          _queue = [..._queue, current.id];
        }
        _completingRound = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('학습 상태 저장 실패: $error')),
      );
      return;
    }

    if (!finished) {
      await _saveCursor(nextQueue.first);
    }

    if (finished) {
      await _completeRound();
    }
  }

  Future<void> _completeRound() async {
    if (_completionInFlight || _words.isEmpty) return;
    _completionInFlight = true;

    if (mounted && !_completingRound) {
      setState(() => _completingRound = true);
    }

    try {
      if (widget.isFinal) {
        await _progress.clearFinalKnown(widget.level);
        _finalKnownIds = <String>{};
      } else {
        await Future.wait(
          _words.map(
            (word) => _api.queueWordState(word.id, known: false),
          ),
        );
      }

      final completion = await _progress.completeRound(
        widget.level,
        widget.chapter,
      );
      final rounds = completion.rounds;

      if (!widget.isFinal) {
        try {
          await FeedbackSoundService.instance.playYes();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _words = _words.map((word) => word.copyWith(known: false)).toList();
        _queue = _words.map((word) => word.id).toList();
        _showReading = false;
        _showMeaning = false;
        _completingRound = false;
      });
      await _saveCursor(_queue.isEmpty ? null : _queue.first);

      final leave = await _showCompletionDialog(
        rounds,
        completion.reward.xpGained,
      );
      if (completion.reward.leveledUp && mounted) {
        await LevelUpDialog.show(context, completion.reward);
      }
      if (leave && mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _completingRound = false;
        _error = '회독 완료 처리에 실패했습니다.\n$error';
      });
    } finally {
      _completionInFlight = false;
    }
  }

  Future<bool> _showCompletionDialog(int rounds, int xpGained) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        final title = widget.isFinal
            ? '${widget.level} 전체 단어 회독 완료!'
            : '챕터를 완료했어요!';
        final description = widget.isFinal
            ? '${_words.length}개 단어의 알고 있음 상태를 초기화하고 $rounds회독으로 기록했어요.\n+$xpGained XP'
            : '${_words.length}개 단어의 알고 있음 상태를 모두 해제하고 $rounds회독으로 기록했어요.\n+$xpGained XP';

        return AlertDialog(
          icon: Icon(
            Icons.done_all_rounded,
            color: scheme.primary,
            size: 36,
          ),
          title: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(
            description,
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('챕터 목록으로'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('한 번 더 학습'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.isFinal
              ? '${widget.level}  ·  FINAL'
              : '${widget.level}  ·  ${widget.chapter.toString().padLeft(2, '0')}',
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
      return Center(
        child: Text(
          widget.isFinal ? '이 등급에는 단어가 없습니다.' : '이 챕터에는 단어가 없습니다.',
        ),
      );
    }
    if (_completingRound || _queue.isEmpty) {
      return const Center(child: CircularProgressIndicator());
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
            _ProgressHeader(
              known: known,
              total: total,
              remaining: _queue.length,
              progress: progress,
            ),
            const SizedBox(height: 16),
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
                              '${_queue.length}개 남음',
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
                                    style: AppTypography.japanese(
                                          Theme.of(context).textTheme.titleLarge,
                                        ).copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Semantics(
                                button: true,
                                label: '${current.word} 발음 듣기',
                                child: TtsPressable(
                                  onPressed: () => _speakWord(current),
                                  borderRadius: BorderRadius.circular(20),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      current.word,
                                      textAlign: TextAlign.center,
                                      style: AppTypography.japanese(
                                            Theme.of(context).textTheme.displayLarge,
                                          ).copyWith(
                                            fontSize: 68,
                                            height: 1.12,
                                            letterSpacing: -0.6,
                                          ),
                                    ),
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
                                child: Semantics(
                                  button: current.exampleJa.isNotEmpty,
                                  label: current.exampleJa.isEmpty ? null : '예문 발음 듣기',
                                  child: TtsPressable(
                                    onPressed: () => _speakJapanese(current.exampleJa),
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                    child: Text(
                                      current.exampleJa.isEmpty ? '예문이 없습니다.' : current.exampleJa,
                                      style: AppTypography.japanese(
                                            Theme.of(context).textTheme.titleLarge,
                                          ).copyWith(
                                            height: 1.60,
                                          ),
                                    ),
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
                                      style: AppTypography.japanese(
                                            Theme.of(context).textTheme.bodyLarge,
                                          ).copyWith(
                                            color: scheme.onSurfaceVariant,
                                            height: 1.55,
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
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: OutlinedButton.icon(
                      onPressed: _completingRound || _advancingWord ? null : _studyAgain,
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
                      onPressed: _completingRound || _advancingWord ? null : _markKnown,
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
