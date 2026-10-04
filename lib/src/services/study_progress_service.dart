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

  /// The pre-login prototype stored round/final-known test values locally.
  /// They are intentionally discarded now that the server is the source of truth.
  Future<void> migrateLegacyLocalState() async {
    final userId = SessionStore.userId;
    if (userId == null || userId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final marker = '$_migrationPrefix:$userId';
    if (prefs.getBool(marker) == true) return;

    final keys = prefs.getKeys().toList();
    for (final key in keys) {
      if (key.startsWith('$_legacyRoundPrefix:') ||
          key.startsWith('$_legacyFinalKnownPrefix:')) {
        await prefs.remove(key);
      }
    }
    await prefs.setBool(marker, true);
  }
}
