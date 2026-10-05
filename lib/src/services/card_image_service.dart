import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'session_store.dart';

class CardImageService {
  CardImageService._();

  static final CardImageService instance = CardImageService._();

  Future<void> upload(Uint8List pngBytes) async {
    if (pngBytes.isEmpty) {
      throw Exception('카드 이미지가 비어 있습니다.');
    }
    final headers = <String, String>{
      ...SessionStore.headers(),
      'Content-Type': 'image/png',
      'Cache-Control': 'no-cache',
    };
    final response = await http
        .put(
          Uri.parse('${ApiService.baseUrl}/api/account/card-image'),
          headers: headers,
          body: pngBytes,
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String detail = '';
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        detail = decoded['detail']?.toString() ?? '';
      }
    } catch (_) {}
    throw Exception(
      '카드 이미지 저장 실패 (${response.statusCode})${detail.isEmpty ? '' : ' $detail'}',
    );
  }

  Future<Uint8List?> fetch() async {
    final response = await http
        .get(
          Uri.parse('${ApiService.baseUrl}/api/account/card-image'),
          headers: {
            ...SessionStore.headers(),
            'Cache-Control': 'no-cache',
          },
        )
        .timeout(const Duration(seconds: 12));
    if (response.statusCode == 404) return null;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw Exception('카드 이미지를 불러오지 못했습니다. (${response.statusCode})');
  }
}
