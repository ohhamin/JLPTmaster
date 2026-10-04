import 'package:flutter/material.dart';

class ThemeController {
  ThemeController._();

  static ThemeMode _initialMode() {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
  }

  static final ValueNotifier<ThemeMode> mode = ValueNotifier<ThemeMode>(_initialMode());

  static void toggle() {
    mode.value = mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
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
          onPressed: ThemeController.toggle,
          icon: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
        );
      },
    );
  }
}
