import 'package:flutter/material.dart';

import '../services/gamification_service.dart';
import '../services/session_store.dart';
import '../widgets/brand_mascot.dart';
import 'settings_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  bool _loading = true;
  bool _loggingOut = false;
  LevelingStatus? _leveling;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final status = await GamificationService.instance.fetchStatus();
      if (!mounted) return;
      setState(() {
        _leveling = status;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    await widget.onLogout();
  }

  void _showCardEditingComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('카드 꾸미기는 다음 단계에서 연결할게요.')),
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
                      '내 레벨과 꾸밈 요소가 담길 프로필 카드예요.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _showCardEditingComingSoon,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('꾸미기'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _UserCardPreview(
            displayName: '닉네임',
            status: status,
            loading: _loading,
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
                        SessionStore.username ?? '사용자',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '닉네임은 다음 단계에서 별도로 설정할 수 있게 연결합니다.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
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
  }
}

class _UserCardPreview extends StatelessWidget {
  const _UserCardPreview({
    required this.displayName,
    required this.status,
    required this.loading,
  });

  final String displayName;
  final LevelingStatus? status;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final level = status?.level ?? 1;
    final experience = status?.experience ?? 0;
    final required = status?.xpRequired ?? 30;
    final progress = status?.progress.clamp(0.0, 1.0) ?? 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const outline = Color(0xFF5A2B20);
    final cardFill = isDark ? const Color(0xFFF9F3E9) : const Color(0xFFFFFCF6);
    final mint = isDark ? const Color(0xFF9ADDB9) : const Color(0xFFBFF1D2);

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: mint,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: outline, width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: cardFill,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: outline, width: 3),
          ),
          child: Column(
            children: [
              Expanded(
                flex: 55,
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 18, 12, 12),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              color: outline,
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 132,
                      margin: const EdgeInsets.fromLTRB(0, 10, 10, 8),
                      decoration: BoxDecoration(
                        color: mint.withValues(alpha: 0.76),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: outline, width: 3),
                      ),
                      child: const Center(
                        child: BrandMascot(size: 102),
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 3, color: outline),
              Expanded(
                flex: 45,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 15, 22, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (loading)
                        const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      else ...[
                        Text(
                          '레벨 : $level    경험치 : $experience/$required',
                          style: const TextStyle(
                            color: outline,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _CuteProgressBar(progress: progress, fillColor: mint),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CuteProgressBar extends StatelessWidget {
  const _CuteProgressBar({required this.progress, required this.fillColor});

  final double progress;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    const outline = Color(0xFF5A2B20);
    return Container(
      height: 20,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: outline, width: 2.5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth * progress.clamp(0.0, 1.0);
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                width: width,
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              if (width > 28)
                Positioned(
                  right: constraints.maxWidth - width + 7,
                  top: 1,
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 11,
                    color: Color(0xFFFFD65A),
                  ),
                ),
            ],
          );
        },
      ),
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
