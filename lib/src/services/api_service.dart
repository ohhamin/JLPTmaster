import 'dart:convert';

import 'package:http/http.dart' as http;

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

  Future<List<Word>> fetchWords({String? level, String? query}) async {
    final params = <String, String>{};
    if (level != null && level != 'ALL') params['level'] = level;
    if (query != null && query.trim().isNotEmpty) params['q'] = query.trim();

    final uri = Uri.parse('$baseUrl/api/words').replace(queryParameters: params);
    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('단어장을 불러오지 못했습니다. (${response.statusCode})');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return decoded.map((e) => Word.fromJson(e as Map<String, dynamic>)).toList();
  }
}
