import 'package:audioplayers/audioplayers.dart';

class CardSongService {
  CardSongService._();

  static final CardSongService instance = CardSongService._();

  static const String _audioBaseUrl =
      'https://jlptmaster.duckdns.org/audio';

  final AudioPlayer _player = AudioPlayer();
  String? _playingTemplateId;

  String _audioUrl(String templateId) {
    switch (templateId) {
      case 'hachiware_basic':
        return '$_audioBaseUrl/hachiware.mp3';
      case 'usagi_basic':
        return '$_audioBaseUrl/usagi.mp3';
      case 'chiikawa_basic':
      default:
        return '$_audioBaseUrl/chiikawa.mp3';
    }
  }

  Future<void> play(String templateId) async {
    await _player.stop();
    _playingTemplateId = templateId;
    await _player.play(UrlSource(_audioUrl(templateId)));
  }

  Future<void> stop() async {
    _playingTemplateId = null;
    await _player.stop();
  }

  bool get isPlaying => _playingTemplateId != null;
}
