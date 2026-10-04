import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsVoiceOption {
  const TtsVoiceOption({
    required this.name,
    required this.locale,
  });

  final String name;
  final String locale;

  String get label => name.isEmpty ? locale : '$name · $locale';
}

class TtsSettings {
  const TtsSettings({
    required this.speechRate,
    required this.pitch,
    required this.volume,
    this.voiceName,
    this.voiceLocale,
  });

  final double speechRate;
  final double pitch;
  final double volume;
  final String? voiceName;
  final String? voiceLocale;
}

class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  static const String _rateKey = 'tts_speech_rate_v1';
  static const String _pitchKey = 'tts_pitch_v1';
  static const String _volumeKey = 'tts_volume_v1';
  static const String _voiceNameKey = 'tts_voice_name_v1';
  static const String _voiceLocaleKey = 'tts_voice_locale_v1';

  final FlutterTts _tts = FlutterTts();
  Future<void>? _initializing;
  bool _initialized = false;

  double _speechRate = 0.45;
  double _pitch = 1.0;
  double _volume = 1.0;
  String? _voiceName;
  String? _voiceLocale;

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
    final prefs = await SharedPreferences.getInstance();
    _speechRate = prefs.getDouble(_rateKey) ?? 0.45;
    _pitch = prefs.getDouble(_pitchKey) ?? 1.0;
    _volume = prefs.getDouble(_volumeKey) ?? 1.0;
    _voiceName = prefs.getString(_voiceNameKey);
    _voiceLocale = prefs.getString(_voiceLocaleKey);

    await _tts.setLanguage('ja-JP');
    await _tts.setSpeechRate(_speechRate);
    await _tts.setVolume(_volume);
    await _tts.setPitch(_pitch);

    final voiceName = _voiceName;
    if (voiceName != null && voiceName.isNotEmpty) {
      await _tts.setVoice({
        'name': voiceName,
        'locale': (_voiceLocale?.isNotEmpty ?? false) ? _voiceLocale! : 'ja-JP',
      });
    }
  }

  Future<TtsSettings> settings() async {
    await _ensureInitialized();
    return TtsSettings(
      speechRate: _speechRate,
      pitch: _pitch,
      volume: _volume,
      voiceName: _voiceName,
      voiceLocale: _voiceLocale,
    );
  }

  Future<List<TtsVoiceOption>> japaneseVoices() async {
    await _ensureInitialized();
    final voices = await _tts.getVoices;
    if (voices is! List) return const [];

    final result = <TtsVoiceOption>[];
    for (final raw in voices) {
      if (raw is! Map) continue;
      final name = raw['name']?.toString() ?? '';
      final locale = raw['locale']?.toString() ?? '';
      if (!locale.toLowerCase().startsWith('ja')) continue;
      result.add(TtsVoiceOption(name: name, locale: locale));
    }

    result.sort((a, b) => a.label.compareTo(b.label));
    return result;
  }

  Future<void> setSpeechRate(double value) async {
    await _ensureInitialized();
    _speechRate = value;
    await _tts.setSpeechRate(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_rateKey, value);
  }

  Future<void> setPitch(double value) async {
    await _ensureInitialized();
    _pitch = value;
    await _tts.setPitch(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_pitchKey, value);
  }

  Future<void> setVolume(double value) async {
    await _ensureInitialized();
    _volume = value;
    await _tts.setVolume(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, value);
  }

  Future<void> setVoice(TtsVoiceOption? voice) async {
    await _ensureInitialized();
    final prefs = await SharedPreferences.getInstance();

    if (voice == null) {
      _voiceName = null;
      _voiceLocale = null;
      await prefs.remove(_voiceNameKey);
      await prefs.remove(_voiceLocaleKey);
      await _tts.setLanguage('ja-JP');
      return;
    }

    _voiceName = voice.name;
    _voiceLocale = voice.locale;
    await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
    await prefs.setString(_voiceNameKey, voice.name);
    await prefs.setString(_voiceLocaleKey, voice.locale);
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
