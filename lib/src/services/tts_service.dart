import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'session_store.dart';

class TtsVoiceOption {
  const TtsVoiceOption({
    required this.name,
    required this.locale,
    this.displayIndex = 0,
  });

  final String name;
  final String locale;
  final int displayIndex;

  String get technicalLabel => name.isEmpty ? locale : '$name · $locale';

  String get koreanLabel {
    final lower = name.toLowerCase();
    final number = displayIndex > 0 ? ' $displayIndex' : '';
    if (lower.contains('female') || lower.contains('woman')) {
      return '일본어 여성 음성$number';
    }
    if (lower.contains('male') || lower.contains('man')) {
      return '일본어 남성 음성$number';
    }
    return '일본어 음성$number';
  }

  String get koreanDescription {
    final lower = name.toLowerCase();
    final provider = lower.contains('samsung')
        ? '삼성'
        : lower.contains('google') || lower.contains('wavenet')
            ? '구글'
            : '기기';
    final availability = lower.contains('network')
        ? '온라인'
        : lower.contains('local')
            ? '오프라인'
            : '기본';
    final quality = lower.contains('wavenet') || lower.contains('neural')
        ? ' · 고음질'
        : '';
    return '$provider · $availability$quality';
  }

  String get label => '$koreanLabel · $koreanDescription';
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

  static const String _legacyRateKey = 'tts_speech_rate_v1';
  static const String _legacyPitchKey = 'tts_pitch_v1';
  static const String _legacyVolumeKey = 'tts_volume_v1';
  static const String _legacyVoiceNameKey = 'tts_voice_name_v1';
  static const String _legacyVoiceLocaleKey = 'tts_voice_locale_v1';
  static const String _migrationPrefix = 'tts_server_migrated_v1';

  final FlutterTts _tts = FlutterTts();
  final ApiService _api = ApiService();
  Future<void>? _initializing;
  bool _initialized = false;

  double _speechRate = 0.45;
  double _pitch = 1.0;
  double _volume = 1.0;
  String? _voiceName;
  String? _voiceLocale;

  Future<void> resetForSession() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _initialized = false;
    _initializing = null;
    _speechRate = 0.45;
    _pitch = 1.0;
    _volume = 1.0;
    _voiceName = null;
    _voiceLocale = null;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    if (_initializing != null) return _initializing!;

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
    final allSettings = await _api.fetchSettings();
    final tts = Map<String, dynamic>.from(allSettings['tts'] as Map? ?? const {});
    _speechRate = (tts['speech_rate'] as num?)?.toDouble() ?? 0.45;
    _pitch = (tts['pitch'] as num?)?.toDouble() ?? 1.0;
    _volume = (tts['volume'] as num?)?.toDouble() ?? 1.0;
    _voiceName = tts['voice_name']?.toString();
    _voiceLocale = tts['voice_locale']?.toString();

    await _applyCurrentSettings();
  }

  Future<void> _applyCurrentSettings() async {
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

    final rawOptions = <TtsVoiceOption>[];
    for (final raw in voices) {
      if (raw is! Map) continue;
      final name = raw['name']?.toString() ?? '';
      final locale = raw['locale']?.toString() ?? '';
      if (!locale.toLowerCase().startsWith('ja')) continue;
      rawOptions.add(TtsVoiceOption(name: name, locale: locale));
    }
    rawOptions.sort((a, b) => a.technicalLabel.compareTo(b.technicalLabel));
    return [
      for (var index = 0; index < rawOptions.length; index++)
        TtsVoiceOption(
          name: rawOptions[index].name,
          locale: rawOptions[index].locale,
          displayIndex: index + 1,
        ),
    ];
  }

  Future<void> setSpeechRate(double value) async {
    await _ensureInitialized();
    _speechRate = value;
    await _tts.setSpeechRate(value);
    await _api.updateSettings({
      'tts': {'speech_rate': value},
    });
  }

  Future<void> setPitch(double value) async {
    await _ensureInitialized();
    _pitch = value;
    await _tts.setPitch(value);
    await _api.updateSettings({
      'tts': {'pitch': value},
    });
  }

  Future<void> setVolume(double value) async {
    await _ensureInitialized();
    _volume = value;
    await _tts.setVolume(value);
    await _api.updateSettings({
      'tts': {'volume': value},
    });
  }

  Future<void> setVoice(TtsVoiceOption? voice) async {
    await _ensureInitialized();
    if (voice == null) {
      _voiceName = null;
      _voiceLocale = null;
      await _tts.setLanguage('ja-JP');
      await _api.updateSettings({
        'tts': {
          'voice_name': null,
          'voice_locale': null,
        },
      });
      return;
    }

    _voiceName = voice.name;
    _voiceLocale = voice.locale;
    await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
    await _api.updateSettings({
      'tts': {
        'voice_name': voice.name,
        'voice_locale': voice.locale,
      },
    });
  }

  Future<void> migrateLegacyLocalSettings() async {
    final userId = SessionStore.userId;
    if (userId == null || userId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final marker = '$_migrationPrefix:$userId';
    if (prefs.getBool(marker) == true) return;

    for (final key in const [
      _legacyRateKey,
      _legacyPitchKey,
      _legacyVolumeKey,
      _legacyVoiceNameKey,
      _legacyVoiceLocaleKey,
    ]) {
      await prefs.remove(key);
    }
    await prefs.setBool(marker, true);
    await resetForSession();
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
