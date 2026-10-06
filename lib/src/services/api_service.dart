import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/study_summary.dart';
import '../models/word.dart';
import 'session_store.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://jlptmaster.duckdns.org',
  );

  final http.Client _client;
  final Map<String, Map<String, dynamic>> _pendingStates = {};
  final Map<String, List<Completer<void>>> _pendingWaiters = {};
  Timer? _stateTimer;
  bool _flushing = false;

  Future<bool> health() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/health'))
        .timeout(const Duration(seconds: 5));
    return response.statusCode == 200;
  }

  Future<List<LevelSummary>> fetchLevels() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/api/levels'), headers: SessionStore.headers())
        .timeout(const Duration(seconds: 8));
    _ensureOk(response, '레벨 정보를 불러오지 못했습니다.');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return decoded
        .map((item) => LevelSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ChapterSummary>> fetchChapters(String level) async {
    final uri = Uri.parse('$baseUrl/api/chapters').replace(
      queryParameters: {'level': level},
    );
    final response = await _client
        .get(uri, headers: SessionStore.headers())
        .timeout(const Duration(seconds: 8));
    _ensureOk(response, '챕터 정보를 불러오지 못했습니다.');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return decoded
        .map((item) => ChapterSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Word>> fetchWords({
    String? level,
    int? chapter,
    bool? favorite,
    String? query,
  }) async {
    final params = <String, String>{};
    if (level != null && level != 'ALL') params['level'] = level;
    if (chapter != null) params['chapter'] = chapter.toString();
    if (favorite != null) params['favorite'] = favorite.toString();
    if (query != null && query.trim().isNotEmpty) params['q'] = query.trim();

    final uri = Uri.parse('$baseUrl/api/words').replace(queryParameters: params);
    final response = await _client
        .get(uri, headers: SessionStore.headers())
        .timeout(const Duration(seconds: 8));
    _ensureOk(response, '단어장을 불러오지 못했습니다.');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return decoded.map((e) => Word.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Word> fetchWord(String wordId, {int? chapter}) async {
    final uri = Uri.parse('$baseUrl/api/words/$wordId').replace(
      queryParameters: chapter == null ? null : {'chapter': chapter.toString()},
    );
    final response = await _client
        .get(uri, headers: SessionStore.headers())
        .timeout(const Duration(seconds: 8));
    _ensureOk(response, '단어 정보를 불러오지 못했습니다.');
    return Word.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<Word> updateWord(
    String wordId, {
    bool? favorite,
    bool? known,
    int? chapter,
  }) async {
    final payload = <String, dynamic>{};
    if (favorite != null) payload['favorite'] = favorite;
    if (known != null) payload['known'] = known;

    final uri = Uri.parse('$baseUrl/api/words/$wordId').replace(
      queryParameters: chapter == null ? null : {'study_chapter': chapter.toString()},
    );
    final response = await _client
        .put(
          uri,
          headers: SessionStore.headers(json: true),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));
    _ensureOk(response, '학습 상태를 저장하지 못했습니다.');
    return Word.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<void> queueWordState(
    String wordId, {
    bool? favorite,
    bool? known,
    int? chapter,
  }) {
    final key = '$wordId@${chapter ?? 0}';
    final payload = _pendingStates.putIfAbsent(key, () => <String, dynamic>{
          'word_id': wordId,
          if (chapter != null) 'chapter': chapter,
        });
    if (favorite != null) payload['favorite'] = favorite;
    if (known != null) payload['known'] = known;

    final completer = Completer<void>();
    _pendingWaiters.putIfAbsent(key, () => <Completer<void>>[]).add(completer);
    _stateTimer?.cancel();
    _stateTimer = Timer(const Duration(milliseconds: 120), _flushStates);
    return completer.future;
  }

  Future<void> _flushStates() async {
    if (_flushing || _pendingStates.isEmpty) return;
    _flushing = true;

    final states = Map<String, Map<String, dynamic>>.fromEntries(
      _pendingStates.entries.map(
        (entry) => MapEntry(entry.key, Map<String, dynamic>.from(entry.value)),
      ),
    );
    final waiters = <String, List<Completer<void>>>{
      for (final key in states.keys)
        key: List<Completer<void>>.from(_pendingWaiters[key] ?? const []),
    };
    for (final key in states.keys) {
      _pendingStates.remove(key);
      _pendingWaiters.remove(key);
    }

    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/progress/batch'),
            headers: SessionStore.headers(json: true),
            body: jsonEncode({'updates': states.values.toList()}),
          )
          .timeout(const Duration(seconds: 8));
      _ensureOk(response, '학습 상태를 저장하지 못했습니다.');
      for (final list in waiters.values) {
        for (final completer in list) {
          if (!completer.isCompleted) completer.complete();
        }
      }
    } catch (error, stack) {
      for (final list in waiters.values) {
        for (final completer in list) {
          if (!completer.isCompleted) completer.completeError(error, stack);
        }
      }
    } finally {
      _flushing = false;
      if (_pendingStates.isNotEmpty) {
        _stateTimer?.cancel();
        _stateTimer = Timer(const Duration(milliseconds: 80), _flushStates);
      }
    }
  }

  Future<Map<int, int>> fetchRounds(String level) async {
    final uri = Uri.parse('$baseUrl/api/progress/rounds').replace(
      queryParameters: {'level': level},
    );
    final response = await _client
        .get(uri, headers: SessionStore.headers())
        .timeout(const Duration(seconds: 8));
    _ensureOk(response, '회독 정보를 불러오지 못했습니다.');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final raw = decoded['rounds'] as Map<String, dynamic>? ?? const {};
    return {
      for (final entry in raw.entries)
        if (int.tryParse(entry.key) != null)
          int.parse(entry.key): (entry.value as num?)?.toInt() ?? 0,
    };
  }

  Future<int> incrementRound(String level, int chapter) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/api/progress/rounds/increment'),
          headers: SessionStore.headers(json: true),
          body: jsonEncode({'level': level, 'chapter': chapter}),
        )
        .timeout(const Duration(seconds: 8));
    _ensureOk(response, '회독 정보를 저장하지 못했습니다.');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (decoded['rounds'] as num?)?.toInt() ?? 0;
  }

  Future<int> setRound(String level, int chapter, int value) async {
    final response = await _client
        .put(
          Uri.parse('$baseUrl/api/progress/rounds'),
          headers: SessionStore.headers(json: true),
          body: jsonEncode({
            'level': level,
            'chapter': chapter,
            'value': value,
          }),
        )
        .timeout(const Duration(seconds: 8));
    _ensureOk(response, '회독 정보를 저장하지 못했습니다.');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return (decoded['rounds'] as num?)?.toInt() ?? 0;
  }

  Future<Set<String>> fetchFinalKnown(String level) async {
    final uri = Uri.parse('$baseUrl/api/progress/final-known').replace(
      queryParameters: {'level': level},
    );
    final response = await _client
        .get(uri, headers: SessionStore.headers())
        .timeout(const Duration(seconds: 8));
    _ensureOk(response, '전체 복습 상태를 불러오지 못했습니다.');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final ids = decoded['word_ids'] as List<dynamic>? ?? const [];
    return ids.map((item) => item.toString()).toSet();
  }

  Future<void> setFinalKnown(String level, Set<String> wordIds) async {
    final ids = wordIds.toList()..sort();
    final response = await _client
        .put(
          Uri.parse('$baseUrl/api/progress/final-known'),
          headers: SessionStore.headers(json: true),
          body: jsonEncode({'level': level, 'word_ids': ids}),
        )
        .timeout(const Duration(seconds: 8));
    _ensureOk(response, '전체 복습 상태를 저장하지 못했습니다.');
  }

  Future<String?> fetchStudyCursor(String level, int chapter) async {
    final uri = Uri.parse('$baseUrl/api/progress/cursor').replace(
      queryParameters: {
        'level': level,
        'chapter': chapter.toString(),
      },
    );
    final response = await _client
        .get(uri, headers: SessionStore.headers())
        .timeout(const Duration(seconds: 8));
    _ensureOk(response, '학습 위치를 불러오지 못했습니다.');
    final decoded =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final value = decoded['word_id']?.toString().trim();
    return value == null || value.isEmpty || value == 'null' ? null : value;
  }

  Future<void> setStudyCursor(
    String level,
    int chapter,
    String? wordId,
  ) async {
    final response = await _client
        .put(
          Uri.parse('$baseUrl/api/progress/cursor'),
          headers: SessionStore.headers(json: true),
          body: jsonEncode({
            'level': level,
            'chapter': chapter,
            'word_id': wordId,
          }),
        )
        .timeout(const Duration(seconds: 8));
    _ensureOk(response, '학습 위치를 저장하지 못했습니다.');
  }

  Future<Map<String, dynamic>> fetchSettings() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/api/settings'), headers: SessionStore.headers())
        .timeout(const Duration(seconds: 8));
    _ensureOk(response, '설정을 불러오지 못했습니다.');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return Map<String, dynamic>.from(decoded['settings'] as Map? ?? const {});
  }

  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> changes) async {
    final response = await _client
        .patch(
          Uri.parse('$baseUrl/api/settings'),
          headers: SessionStore.headers(json: true),
          body: jsonEncode({'settings': changes}),
        )
        .timeout(const Duration(seconds: 8));
    _ensureOk(response, '설정을 저장하지 못했습니다.');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return Map<String, dynamic>.from(decoded['settings'] as Map? ?? const {});
  }

  Future<String> explainWord(String wordId) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/api/words/$wordId/explain'),
          headers: SessionStore.headers(),
        )
        .timeout(const Duration(seconds: 60));
    _ensureOk(response, 'AI 설명을 불러오지 못했습니다.');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return decoded['content'] as String? ?? '';
  }

  void _ensureOk(http.Response response, String message) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String? detail;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        detail = decoded['detail']?.toString();
      }
    } catch (_) {
      detail = null;
    }
    throw Exception('$message (${response.statusCode})${detail == null ? '' : ' $detail'}');
  }
}
