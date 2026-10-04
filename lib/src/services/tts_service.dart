import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  Future<void>? _initializing;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    if (_initializing != null) {
      return _initializing!;
    }

    final initializing = _initialize();
    _initializing = initializing;
    try {
      await initializing;
      _initialized = true;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initialize() async {
    await _tts.setLanguage('ja-JP');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> speakJapanese(String text) async {
    final value = text.trim();
    if (value.isEmpty) return;

    await _ensureInitialized();
    await _tts.stop();
    await _tts.speak(value);
  }

  Future<void> stop() async {
    if (!_initialized && _initializing == null) return;
    await _tts.stop();
  }
}
