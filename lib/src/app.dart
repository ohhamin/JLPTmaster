import 'package:flutter/material.dart';

import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/gamification_service.dart';
import 'services/profile_service.dart';
import 'services/study_progress_service.dart';
import 'services/tts_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/app_scene_background.dart';
import 'widgets/attendance_dialog.dart';
import 'widgets/level_up_dialog.dart';
import 'widgets/nickname_dialog.dart';

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
    _showPostLoginDialogs(attendance);
  }

  Future<ExperienceReward?> _prepareUserSession({bool preserveLoginTheme = false}) async {
    await TtsService.instance.resetForSession();
    try {
      await StudyProgressService.instance.migrateLegacyLocalState();
    } catch (_) {}
    try {
      await TtsService.instance.migrateLegacyLocalSettings();
    } catch (_) {}
    if (preserveLoginTheme) {
      await ThemeController.syncCurrentToServer();
    } else {
      await ThemeController.syncFromServer();
    }
    try {
      await ProfileService.instance.refresh();
    } catch (_) {
      ProfileService.instance.reset();
    }
    try {
      return await GamificationService.instance.claimDailyAttendance();
    } catch (_) {
      return null;
    }
  }

  void _showPostLoginDialogs(ExperienceReward? reward) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!ProfileService.instance.hasNickname) {
        await NicknameDialog.show(
          context,
          requiredNickname: true,
          initialValue: '',
          onSave: (nickname) async {
            await ProfileService.instance.updateNickname(nickname);
          },
        );
      }
      if (!mounted) return;
      if (reward != null && reward.attendanceAwarded) {
        await AttendanceDialog.show(context, reward);
      }
      if (!mounted) return;
      if (reward != null && reward.leveledUp) {
        await LevelUpDialog.show(context, reward);
      }
    });
  }

  Future<void> _onAuthenticated() async {
    setState(() => _loading = true);
    final attendance = await _prepareUserSession(preserveLoginTheme: true);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _authenticated = true;
    });
    _showPostLoginDialogs(attendance);
  }

  Future<void> _logout() async {
    setState(() => _loading = true);
    await _auth.logout();
    ProfileService.instance.reset();
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
