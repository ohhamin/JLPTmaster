import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'session_store.dart';

class ProfileService {
  ProfileService._();

  static final ProfileService instance = ProfileService._();

  final http.Client _client = http.Client();
  final ValueNotifier<String?> nickname = ValueNotifier<String?>(null);

  static final RegExp _nicknamePattern = RegExp(r'^[가-힣]{2,6}$');

  bool get hasNickname {
    final value = nickname.value;
    return value != null && _nicknamePattern.hasMatch(value);
  }

  static bool isValidNickname(String value) {
    return _nicknamePattern.hasMatch(value.trim());
  }

  Future<String?> refresh() async {
    final response = await _client
        .get(
          Uri.parse('${ApiService.baseUrl}/api/settings'),
          headers: SessionStore.headers(),
        )
        .timeout(const Duration(seconds: 8));

    _ensureOk(response, '닉네임 정보를 불러오지 못했습니다.');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final settings = decoded is Map<String, dynamic>
        ? decoded['settings'] as Map<String, dynamic>? ?? const <String, dynamic>{}
        : const <String, dynamic>{};
    final raw = settings['nickname']?.toString().trim() ?? '';
    final value = isValidNickname(raw) ? raw : null;
    nickname.value = value;
    return value;
  }

  Future<String> updateNickname(String value) async {
    final clean = value.trim();
    if (!isValidNickname(clean)) {
      throw ArgumentError('닉네임은 한글 2~6자로 입력해 주세요.');
    }

    final response = await _client
        .patch(
          Uri.parse('${ApiService.baseUrl}/api/settings'),
          headers: SessionStore.headers(json: true),
          body: jsonEncode({
            'settings': {'nickname': clean},
          }),
        )
        .timeout(const Duration(seconds: 8));

    _ensureOk(response, '닉네임을 저장하지 못했습니다.');
    nickname.value = clean;
    return clean;
  }

  void reset() {
    nickname.value = null;
  }

  static void _ensureOk(http.Response response, String message) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String? detail;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        detail = decoded['detail']?.toString();
      }
    } catch (_) {}
    throw Exception(
      '$message (${response.statusCode})${detail == null ? '' : ' $detail'}',
    );
  }
}
