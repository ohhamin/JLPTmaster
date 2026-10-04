import 'package:flutter/material.dart';

import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/study_progress_service.dart';
import 'services/tts_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

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
    await _prepareUserSession();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _authenticated = true;
    });
  }

  Future<void> _prepareUserSession() async {
    await TtsService.instance.resetForSession();
    try {
      await StudyProgressService.instance.migrateLegacyLocalState();
    } catch (_) {}
    try {
      await TtsService.instance.migrateLegacyLocalSettings();
    } catch (_) {}
    await ThemeController.syncFromServer();
  }

  Future<void> _onAuthenticated() async {
    setState(() => _loading = true);
    await _prepareUserSession();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _authenticated = true;
    });
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
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_authenticated) {
      return AuthScreen(onAuthenticated: _onAuthenticated);
    }
    return HomeScreen(onLogout: _logout);
  }
}
