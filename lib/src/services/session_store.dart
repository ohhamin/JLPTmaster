import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  SessionStore._();

  static const _tokenKey = 'auth_session_token_v1';
  static const _userIdKey = 'auth_user_id_v1';
  static const _usernameKey = 'auth_username_v1';

  static String? token;
  static String? userId;
  static String? username;

  static bool get isAuthenticated => token != null && token!.isNotEmpty;

  static Map<String, String> headers({bool json = false}) => {
        if (json) 'Content-Type': 'application/json; charset=utf-8',
        if (isAuthenticated) 'Authorization': 'Bearer $token',
      };

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_tokenKey);
    userId = prefs.getString(_userIdKey);
    username = prefs.getString(_usernameKey);
  }

  static Future<void> save({
    required String sessionToken,
    required String id,
    required String name,
  }) async {
    token = sessionToken;
    userId = id;
    username = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, sessionToken);
    await prefs.setString(_userIdKey, id);
    await prefs.setString(_usernameKey, name);
  }

  static Future<void> clear() async {
    token = null;
    userId = null;
    username = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
  }
}
