import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/study_summary.dart';
import '../models/word.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://jlptmaster.duckdns.org',
  );

  final http.Client _client;

  Future<bool> health() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/health'))
        .timeout(const Duration(seconds: 5));
    return response.statusCode == 200;
  }

  Future<List<LevelSummary>> fetchLevels() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/api/levels'))
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
    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
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
    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    _ensureOk(response, '단어장을 불러오지 못했습니다.');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return decoded.map((e) => Word.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Word> fetchWord(String wordId) async {
    final response = await _client
        .get(Uri.parse('$baseUrl/api/words/$wordId'))
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
  }) async {
    final payload = <String, dynamic>{};
    if (favorite != null) payload['favorite'] = favorite;
    if (known != null) payload['known'] = known;

    final response = await _client
        .put(
          Uri.parse('$baseUrl/api/words/$wordId'),
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));
    _ensureOk(response, '학습 상태를 저장하지 못했습니다.');
    return Word.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<String> explainWord(String wordId) async {
    final response = await _client
        .post(Uri.parse('$baseUrl/api/words/$wordId/explain'))
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
