import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
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
        home: const HomeScreen(),
      ),
    );
  }
}
