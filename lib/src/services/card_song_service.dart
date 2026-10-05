import 'dart:math';

import 'package:audioplayers/audioplayers.dart';

class CardSongService {
  CardSongService._();

  static final CardSongService instance = CardSongService._();

  final AudioPlayer _player = AudioPlayer();
  final Random _random = Random();
  String? _playingTemplateId;

  List<String> _assetPaths(String templateId) {
    switch (templateId) {
      case 'hachiware_basic':
        return const ['audio/hachiware.mp3', 'audio/hachiware2.mp3'];
      case 'usagi_basic':
        return const ['audio/usagi.mp3', 'audio/usagi2.mp3'];
      case 'chiikawa_basic':
      default:
        return const ['audio/chiikawa.mp3', 'audio/chiikawa2.mp3'];
    }
  }

  Future<void> play(String templateId) async {
    await _player.stop();
    _playingTemplateId = templateId;
    final candidates = _assetPaths(templateId);
    final selected = candidates[_random.nextInt(candidates.length)];
    await _player.play(AssetSource(selected));
  }

  Future<void> stop() async {
    _playingTemplateId = null;
    await _player.stop();
  }

  bool get isPlaying => _playingTemplateId != null;
}
