import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'session_store.dart';

class StudyProgressService {
  StudyProgressService._();

  static final StudyProgressService instance = StudyProgressService._();

  static const String _legacyRoundPrefix = 'study_rounds_v1';
  static const String _legacyFinalKnownPrefix = 'final_known_v1';
  static const String _migrationPrefix = 'server_progress_migrated_v1';

  final ApiService _api = ApiService();

  Future<int> rounds(String level, int chapter) async {
    final values = await _api.fetchRounds(level);
    return values[chapter] ?? 0;
  }

  Future<Map<int, int>> chapterRounds(
    String level,
    Iterable<int> chapters,
  ) async {
    final values = await _api.fetchRounds(level);
    return {
      for (final chapter in chapters) chapter: values[chapter] ?? 0,
    };
  }

  Future<int> incrementRound(String level, int chapter) =>
      _api.incrementRound(level, chapter);

  Future<Set<String>> finalKnown(String level) =>
      _api.fetchFinalKnown(level);

  Future<void> setFinalKnown(String level, Set<String> knownWordIds) =>
      _api.setFinalKnown(level, knownWordIds);

  Future<void> clearFinalKnown(String level) =>
      _api.setFinalKnown(level, <String>{});

  Future<void> migrateLegacyLocalState() async {
    final userId = SessionStore.userId;
    if (userId == null || userId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final marker = '$_migrationPrefix:$userId';
    if (prefs.getBool(marker) == true) return;

    final remoteByLevel = <String, Map<int, int>>{};
    final keys = prefs.getKeys().toList();

    for (final key in keys.where((key) => key.startsWith('$_legacyRoundPrefix:'))) {
      final parts = key.split(':');
      if (parts.length != 3) continue;
      final level = parts[1].toUpperCase();
      final chapter = int.tryParse(parts[2]);
      final localValue = prefs.getInt(key);
      if (chapter == null || localValue == null || localValue <= 0) continue;

      final remote = remoteByLevel.putIfAbsent(level, () => <int, int>{});
      if (remote.isEmpty) {
        remote.addAll(await _api.fetchRounds(level));
      }
      final next = localValue > (remote[chapter] ?? 0)
          ? localValue
          : (remote[chapter] ?? 0);
      if (next != (remote[chapter] ?? 0)) {
        await _api.setRound(level, chapter, next);
        remote[chapter] = next;
      }
    }

    for (final key in keys.where((key) => key.startsWith('$_legacyFinalKnownPrefix:'))) {
      final parts = key.split(':');
      if (parts.length != 2) continue;
      final level = parts[1].toUpperCase();
      final localIds = (prefs.getStringList(key) ?? const <String>[]).toSet();
      if (localIds.isEmpty) continue;
      final remoteIds = await _api.fetchFinalKnown(level);
      final merged = <String>{...remoteIds, ...localIds};
      if (merged.length != remoteIds.length) {
        await _api.setFinalKnown(level, merged);
      }
    }

    for (final key in keys) {
      if (key.startsWith('$_legacyRoundPrefix:') ||
          key.startsWith('$_legacyFinalKnownPrefix:')) {
        await prefs.remove(key);
      }
    }
    await prefs.setBool(marker, true);
  }
}
