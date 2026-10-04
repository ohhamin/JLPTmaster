import 'package:flutter/material.dart';

import '../services/tts_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TtsService _tts = TtsService.instance;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  double _speechRate = 0.45;
  double _pitch = 1.0;
  double _volume = 1.0;
  List<TtsVoiceOption> _voices = const [];
  TtsVoiceOption? _selectedVoice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final settings = await _tts.settings();
      final voices = await _tts.japaneseVoices();
      TtsVoiceOption? selected;

      for (final voice in voices) {
        if (voice.name == settings.voiceName &&
            voice.locale == settings.voiceLocale) {
          selected = voice;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _speechRate = settings.speechRate;
        _pitch = settings.pitch;
        _volume = settings.volume;
        _voices = voices;
        _selectedVoice = selected;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _save(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('TTS 설정 저장 실패: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testVoice() async {
    try {
      await _tts.speakJapanese('こんにちは。日本語の音声テストです。');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('음성 테스트 실패: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 140),
          const Icon(Icons.record_voice_over_outlined, size: 44),
          const SizedBox(height: 12),
          const Text('TTS 설정을 불러오지 못했습니다.', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 시도'),
            ),
          ),
        ],
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
      children: [
        Text(
          'TTS 설정',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          '단어와 예문을 눌렀을 때 재생되는 일본어 음성을 조절해요.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
        ),
        const SizedBox(height: 20),
        _SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '일본어 음성',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TtsVoiceOption>(
                key: ValueKey(_selectedVoice?.label ?? 'default-voice'),
                initialValue: _selectedVoice,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '음성 선택',
                ),
                items: [
                  const DropdownMenuItem<TtsVoiceOption>(
                    value: null,
                    child: Text('기기 기본 일본어 음성'),
                  ),
                  ..._voices.map(
                    (voice) => DropdownMenuItem<TtsVoiceOption>(
                      value: voice,
                      child: Text(
                        voice.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (voice) {
                        setState(() => _selectedVoice = voice);
                        _save(() => _tts.setVoice(voice));
                      },
              ),
              if (_voices.isEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '기기에서 별도의 일본어 음성을 찾지 못해 기본 음성을 사용합니다.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SettingsCard(
          child: Column(
            children: [
              _SliderSetting(
                title: '말하기 속도',
                valueLabel: '${(_speechRate * 100).round()}%',
                value: _speechRate,
                min: 0.25,
                max: 0.75,
                divisions: 20,
                onChanged: (value) => setState(() => _speechRate = value),
                onChangeEnd: (value) => _save(() => _tts.setSpeechRate(value)),
              ),
              const Divider(height: 28),
              _SliderSetting(
                title: '음 높이',
                valueLabel: '${_pitch.toStringAsFixed(2)}x',
                value: _pitch,
                min: 0.6,
                max: 1.4,
                divisions: 16,
                onChanged: (value) => setState(() => _pitch = value),
                onChangeEnd: (value) => _save(() => _tts.setPitch(value)),
              ),
              const Divider(height: 28),
              _SliderSetting(
                title: '음량',
                valueLabel: '${(_volume * 100).round()}%',
                value: _volume,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: (value) => setState(() => _volume = value),
                onChangeEnd: (value) => _save(() => _tts.setVolume(value)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: _testVoice,
            icon: const Icon(Icons.volume_up_rounded),
            label: const Text(
              '현재 설정으로 음성 테스트',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: child,
    );
  }
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const Spacer(),
            Text(
              valueLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }
}
