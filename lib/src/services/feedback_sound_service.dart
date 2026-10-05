import 'dart:math';

import 'package:audioplayers/audioplayers.dart';

class FeedbackSoundService {
  FeedbackSoundService._();

  static final FeedbackSoundService instance = FeedbackSoundService._();

  static const List<String> _yesAssets = <String>[
    'audio/yes.mp3',
    'audio/yes2.mp3',
    'audio/yes3.mp3',
    'audio/yes4.mp3',
  ];

  static const List<String> _noAssets = <String>[
    'audio/no.mp3',
    'audio/no2.mp3',
    'audio/no3.mp3',
  ];

  final AudioPlayer _player = AudioPlayer();
  final Random _random = Random();

  Future<void> playYes() => _playRandom(_yesAssets);

  Future<void> playNo() => _playRandom(_noAssets);

  Future<void> _playRandom(List<String> assets) async {
    if (assets.isEmpty) return;
    await _player.stop();
    final selected = assets[_random.nextInt(assets.length)];
    await _player.play(AssetSource(selected));
  }

  Future<void> stop() => _player.stop();
}
