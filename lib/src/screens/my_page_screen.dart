import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../services/card_customization_service.dart';
import '../services/card_image_service.dart';
import '../services/gamification_service.dart';
import '../services/profile_service.dart';
import '../services/session_store.dart';
import '../widgets/nickname_dialog.dart';
import '../widgets/user_profile_card.dart';
import 'card_editor_screen.dart';
import 'settings_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final GlobalKey _cardCaptureKey = GlobalKey();
  bool _loading = true;
  bool _loggingOut = false;
  bool _syncingCard = false;
  LevelingStatus? _leveling;
  List<CardDecorationPlacement> _decorations = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    LevelingStatus? status;
    List<CardDecorationPlacement>? decorations;
    try {
      status = await GamificationService.instance.fetchStatus();
    } catch (_) {}
    try {
      await ProfileService.instance.refresh();
    } catch (_) {}
    try {
      decorations = await CardCustomizationService.instance.refresh();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _leveling = status ?? _leveling;
      _decorations = decorations ?? _decorations;
      _loading = false;
    });
    _scheduleCardSnapshotSync();
  }

  void _scheduleCardSnapshotSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _loading || _syncingCard) return;
      _syncCardSnapshot();
    });
  }

  Future<void> _syncCardSnapshot() async {
    if (_syncingCard || !ProfileService.instance.hasNickname) return;
    final renderObject = _cardCaptureKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary || renderObject.debugNeedsPaint) {
      return;
    }
    _syncingCard = true;
    try {
      final image = await renderObject.toImage(pixelRatio: 3.0);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) return;
        await CardImageService.instance.upload(data.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    } catch (_) {
      // The editable metadata remains the source of truth. A failed snapshot
      // can be retried on the next My Page refresh or card save.
    } finally {
      _syncingCard = false;
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    CardCustomizationService.instance.reset();
    await widget.onLogout();
  }

  Future<void> _editNickname() async {
    await NicknameDialog.show(
      context,
      requiredNickname: false,
      initialValue: ProfileService.instance.nickname.value ?? '',
      onSave: (nickname) async {
        await ProfileService.instance.updateNickname(nickname);
      },
    );
    if (!mounted) return;
    setState(() {});
    _scheduleCardSnapshotSync();
  }

  Future<void> _openCardEditor(String displayName) async {
    final status = _leveling;
    final result = await Navigator.of(context).push<List<CardDecorationPlacement>>(
      MaterialPageRoute<List<CardDecorationPlacement>>(
        builder: (context) => CardEditorScreen(
          nickname: displayName,
          level: status?.level ?? 1,
          experience: status?.experience ?? 0,
          xpRequired: status?.xpRequired ?? 30,
          initialDecorations: _decorations,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _decorations = result);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('카드 이미지까지 서버에 저장했어요.')),
    );
  }

  void _openLearningSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('학습 설정'),
            centerTitle: true,
          ),
          body: SettingsScreen(onLogout: widget.onLogout),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = _leveling;

    return ValueListenableBuilder<String?>(
      valueListenable: ProfileService.instance.nickname,
      builder: (context, nickname, _) {
        final displayName = nickname ?? '닉네임';
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '나의 카드',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.6,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '내 레벨과 꾸밈 요소가 담긴 프로필 카드예요.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _loading ? null : () => _openCardEditor(displayName),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('꾸미기'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              RepaintBoundary(
                key: _cardCaptureKey,
                child: UserProfileCard(
                  nickname: displayName,
                  level: status?.level ?? 1,
                  experience: status?.experience ?? 0,
                  xpRequired: status?.xpRequired ?? 30,
                  loading: _loading,
                  decorations: _decorations,
                ),
              ),
              const SizedBox(height: 18),
              _MyPageCard(
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Icon(Icons.person_rounded, color: scheme.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '로그인 ID · ${SessionStore.username ?? '-'}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _editNickname,
                      child: const Text('수정하기'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _MyPageCard(
                child: Column(
                  children: [
                    _MenuRow(
                      icon: Icons.tune_rounded,
                      title: '학습 설정',
                      subtitle: 'TTS 음성, 속도, 음높이와 음량',
                      onTap: _openLearningSettings,
                    ),
                    const Divider(height: 28),
                    _MenuRow(
                      icon: Icons.logout_rounded,
                      title: _loggingOut ? '로그아웃 중...' : '로그아웃',
                      subtitle: '현재 계정에서 로그아웃합니다.',
                      onTap: _loggingOut ? null : _logout,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MyPageCard extends StatelessWidget {
  const _MyPageCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.72)),
      ),
      child: child,
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: scheme.primary, size: 21),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
