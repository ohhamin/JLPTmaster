import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/session_store.dart';

class ThemeController {
  ThemeController._();

  static const _localThemeKey = 'jlptmaster_theme_mode';

  static ThemeMode _initialMode() {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
  }

  static final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(_initialMode());

  static Future<void> restoreLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localThemeKey);
      if (raw == 'dark') {
        mode.value = ThemeMode.dark;
      } else if (raw == 'light') {
        mode.value = ThemeMode.light;
      }
    } catch (_) {}
  }

  static Future<void> _saveLocal(ThemeMode value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _localThemeKey,
        value == ThemeMode.dark ? 'dark' : 'light',
      );
    } catch (_) {}
  }

  static Future<void> syncFromServer() async {
    if (!SessionStore.isAuthenticated) return;
    try {
      final settings = await ApiService().fetchSettings();
      final raw = settings['theme_mode']?.toString();
      if (raw == 'dark') {
        mode.value = ThemeMode.dark;
        await _saveLocal(ThemeMode.dark);
      } else if (raw == 'light') {
        mode.value = ThemeMode.light;
        await _saveLocal(ThemeMode.light);
      }
    } catch (_) {}
  }

  static Future<void> toggle() async {
    final next = mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    mode.value = next;
    await _saveLocal(next);

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
        final scheme = Theme.of(context).colorScheme;

        return Material(
          color: scheme.surfaceContainerLow.withValues(alpha: dark ? 0.84 : 0.92),
          shape: CircleBorder(
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.9),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            tooltip: dark ? '라이트 모드' : '다크 모드',
            onPressed: () => ThemeController.toggle(),
            icon: Icon(
              dark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              size: 21,
              color: dark ? scheme.secondary : scheme.primary,
            ),
          ),
        );
      },
    );
  }
}
