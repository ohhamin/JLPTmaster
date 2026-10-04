import 'package:shared_preferences/shared_preferences.dart';

class StudyProgressService {
  StudyProgressService._();

  static final StudyProgressService instance = StudyProgressService._();

  static const String _roundPrefix = 'study_rounds_v1';
  static const String _finalKnownPrefix = 'final_known_v1';

  Future<void> _finalWriteChain = Future<void>.value();

  String _roundKey(String level, int chapter) =>
      '$_roundPrefix:${level.toUpperCase()}:$chapter';

  String _finalKnownKey(String level) =>
      '$_finalKnownPrefix:${level.toUpperCase()}';

  Future<int> rounds(String level, int chapter) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_roundKey(level, chapter)) ?? 0;
  }

  Future<Map<int, int>> chapterRounds(
    String level,
    Iterable<int> chapters,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final chapter in chapters)
        chapter: prefs.getInt(_roundKey(level, chapter)) ?? 0,
    };
  }

  Future<int> incrementRound(String level, int chapter) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _roundKey(level, chapter);
    final next = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, next);
    return next;
  }

  Future<Set<String>> finalKnown(String level) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_finalKnownKey(level)) ?? const <String>[])
        .toSet();
  }

  Future<void> setFinalKnown(
    String level,
    Set<String> knownWordIds,
  ) {
    final ids = knownWordIds.toList()..sort();
    _finalWriteChain = _finalWriteChain.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_finalKnownKey(level), ids);
    });
    return _finalWriteChain;
  }

  Future<void> clearFinalKnown(String level) {
    _finalWriteChain = _finalWriteChain.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_finalKnownKey(level));
    });
    return _finalWriteChain;
  }
}
