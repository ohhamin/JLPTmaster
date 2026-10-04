import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'session_store.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    this.createdAt = '',
  });

  final String id;
  final String username;
  final String createdAt;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        createdAt: json['created_at']?.toString() ?? '',
      );
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  final http.Client _client = http.Client();

  AuthUser? _currentUser;
  AuthUser? get currentUser => _currentUser;

  Future<AuthUser?> restoreSession() async {
    await SessionStore.load();
    if (!SessionStore.isAuthenticated) return null;
    try {
      final response = await _client
          .get(
            Uri.parse('${ApiService.baseUrl}/api/auth/me'),
            headers: SessionStore.headers(),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        await SessionStore.clear();
        return null;
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final user = AuthUser.fromJson(decoded['user'] as Map<String, dynamic>);
      _currentUser = user;
      await SessionStore.save(
        sessionToken: SessionStore.token!,
        id: user.id,
        name: user.username,
      );
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<AuthUser> login(String username, String password) =>
      _authenticate('/api/auth/login', username, password);

  Future<AuthUser> signup(String username, String password) =>
      _authenticate('/api/auth/signup', username, password);

  Future<AuthUser> _authenticate(
    String path,
    String username,
    String password,
  ) async {
    final response = await _client
        .post(
          Uri.parse('${ApiService.baseUrl}$path'),
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({
            'username': username.trim(),
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_detail(response, '로그인 처리에 실패했습니다.'));
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final token = decoded['token']?.toString() ?? '';
    final user = AuthUser.fromJson(decoded['user'] as Map<String, dynamic>);
    if (token.isEmpty || user.id.isEmpty) {
      throw Exception('서버의 로그인 응답이 올바르지 않습니다.');
    }

    await SessionStore.save(
      sessionToken: token,
      id: user.id,
      name: user.username,
    );
    _currentUser = user;
    return user;
  }

  Future<void> logout() async {
    try {
      if (SessionStore.isAuthenticated) {
        await _client
            .post(
              Uri.parse('${ApiService.baseUrl}/api/auth/logout'),
              headers: SessionStore.headers(),
            )
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {
    } finally {
      _currentUser = null;
      await SessionStore.clear();
    }
  }

  static String _detail(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
        final detail = decoded['detail'];
        if (detail is String) return detail;
      }
    } catch (_) {}
    return '$fallback (${response.statusCode})';
  }
}
