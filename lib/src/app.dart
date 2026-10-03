import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

class JlptMasterApp extends StatefulWidget {
  const JlptMasterApp({super.key});

  @override
  State<JlptMasterApp> createState() => _JlptMasterAppState();
}

class _JlptMasterAppState extends State<JlptMasterApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _cycleTheme() {
    setState(() {
      _themeMode = switch (_themeMode) {
        ThemeMode.system => ThemeMode.light,
        ThemeMode.light => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.system,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JLPTmaster',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      home: HomeScreen(
        themeMode: _themeMode,
        onThemePressed: _cycleTheme,
      ),
    );
  }
}
