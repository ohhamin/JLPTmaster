import 'package:audioplayers/audioplayers.dart';

class CardSongService {
  CardSongService._();

  static final CardSongService instance = CardSongService._();

  final AudioPlayer _player = AudioPlayer();
  String? _playingTemplateId;

  String _assetPath(String templateId) {
    switch (templateId) {
      case 'hachiware_basic':
        return 'audio/hachiware.mp3';
      case 'usagi_basic':
        return 'audio/usagi.mp3';
      case 'chiikawa_basic':
      default:
        return 'audio/chiikawa.mp3';
    }
  }

  Future<void> play(String templateId) async {
    await _player.stop();
    _playingTemplateId = templateId;
    await _player.play(AssetSource(_assetPath(templateId)));
  }

  Future<void> stop() async {
    _playingTemplateId = null;
    await _player.stop();
  }

  bool get isPlaying => _playingTemplateId != null;
}
