import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/session_store.dart';

class ThemeController {
  ThemeController._();

  static ThemeMode _initialMode() {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
  }

  static final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(_initialMode());

  static Future<void> syncFromServer() async {
    if (!SessionStore.isAuthenticated) return;
    try {
      final settings = await ApiService().fetchSettings();
      final raw = settings['theme_mode']?.toString();
      if (raw == 'dark') {
        mode.value = ThemeMode.dark;
      } else if (raw == 'light') {
        mode.value = ThemeMode.light;
      }
    } catch (_) {}
  }

  static Future<void> toggle() async {
    final next = mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    mode.value = next;
    if (!SessionStore.isAuthenticated) return;
    try {
      await ApiService().updateSettings({
        'theme_mode': next == ThemeMode.dark ? 'dark' : 'light',
      });
    } catch (_) {}
  }
}

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) {
        final dark = mode == ThemeMode.dark;
        return IconButton(
          tooltip: dark ? '라이트 모드' : '다크 모드',
          onPressed: () => ThemeController.toggle(),
          icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
        );
      },
    );
  }
}
