import 'package:flutter/material.dart';

import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/gamification_service.dart';
import 'services/study_progress_service.dart';
import 'services/tts_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/app_scene_background.dart';
import 'widgets/level_up_dialog.dart';

class JlptMasterApp extends StatelessWidget {
  const JlptMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, themeMode, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'JLPTmaster',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        builder: (context, child) => AppSceneBackground(
          child: child ?? const SizedBox.shrink(),
        ),
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final AuthService _auth = AuthService.instance;
  bool _loading = true;
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final user = await _auth.restoreSession();
    if (!mounted) return;
    if (user == null) {
      setState(() {
        _loading = false;
        _authenticated = false;
      });
      return;
    }
    final attendance = await _prepareUserSession();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _authenticated = true;
    });
    _showAttendanceLevelUp(attendance);
  }

  Future<ExperienceReward?> _prepareUserSession() async {
    await TtsService.instance.resetForSession();
    try {
      await StudyProgressService.instance.migrateLegacyLocalState();
    } catch (_) {}
    try {
      await TtsService.instance.migrateLegacyLocalSettings();
    } catch (_) {}
    await ThemeController.syncFromServer();
    try {
      return await GamificationService.instance.claimDailyAttendance();
    } catch (_) {
      return null;
    }
  }

  void _showAttendanceLevelUp(ExperienceReward? reward) {
    if (reward == null || !reward.leveledUp) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) LevelUpDialog.show(context, reward);
    });
  }

  Future<void> _onAuthenticated() async {
    setState(() => _loading = true);
    final attendance = await _prepareUserSession();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _authenticated = true;
    });
    _showAttendanceLevelUp(attendance);
  }

  Future<void> _logout() async {
    setState(() => _loading = true);
    await _auth.logout();
    await TtsService.instance.resetForSession();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _authenticated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_authenticated) {
      return AuthScreen(onAuthenticated: _onAuthenticated);
    }
    return HomeScreen(onLogout: _logout);
  }
}
