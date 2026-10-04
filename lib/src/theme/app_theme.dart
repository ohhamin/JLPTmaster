import 'package:flutter/material.dart';

import 'app_typography.dart';

class AppTheme {
  static const _lightSeed = Color(0xFF78AD73);
  static const _darkSeed = Color(0xFF8DBA87);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final baseScheme = ColorScheme.fromSeed(
      seedColor: isLight ? _lightSeed : _darkSeed,
      brightness: brightness,
    );

    // The light theme feels like a soft meadow. The dark theme keeps the same
    // friendly palette, but shifts the environment toward a quiet mossy cave.
    final scheme = baseScheme.copyWith(
      primary: isLight ? const Color(0xFF679B64) : const Color(0xFFA7CEA0),
      onPrimary: isLight ? const Color(0xFFFFFFFF) : const Color(0xFF17301D),
      secondary: isLight ? const Color(0xFFE8B968) : const Color(0xFFE4C17C),
      tertiary: isLight ? const Color(0xFFE99C94) : const Color(0xFFD99C94),
      surface: isLight ? const Color(0xFFF0F6E9) : const Color(0xFF111A18),
      surfaceContainerLow: isLight ? const Color(0xFFFFFDF5) : const Color(0xFF1C2723),
      surfaceContainerHighest: isLight ? const Color(0xFFE1EBD8) : const Color(0xFF2A3831),
      onSurface: isLight ? const Color(0xFF2F3B31) : const Color(0xFFF2EEDF),
      onSurfaceVariant: isLight ? const Color(0xFF687367) : const Color(0xFFB6C1B6),
      outline: isLight ? const Color(0xFFB9C8B4) : const Color(0xFF53645A),
      outlineVariant: isLight ? const Color(0xFFD1DECA) : const Color(0xFF35463E),
      errorContainer: isLight ? const Color(0xFFFFE2DD) : const Color(0xFF4A2927),
    );

    final rounded16 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    final rounded18 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppTypography.uiFontFamily,
      scaffoldBackgroundColor: Colors.transparent,
      splashColor: scheme.primary.withValues(alpha: 0.08),
      highlightColor: scheme.primary.withValues(alpha: 0.05),
      dividerColor: scheme.outlineVariant,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface.withValues(alpha: isLight ? 0.86 : 0.90),
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontFamily: AppTypography.uiFontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.35,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shadowColor: Colors.black.withValues(alpha: isLight ? 0.05 : 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isLight ? 0.92 : 0.82),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.86),
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow.withValues(alpha: isLight ? 0.94 : 0.90),
        contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.error.withValues(alpha: 0.72)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: rounded18,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape: rounded18,
          side: BorderSide(color: scheme.outlineVariant),
          foregroundColor: scheme.onSurface,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: rounded16,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          shape: const CircleBorder(),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: isLight ? const Color(0xFFFFFDF5) : const Color(0xFF17221E),
        indicatorColor: isLight
            ? const Color(0xFFDCEBD4)
            : const Color(0xFF2C4034),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        modalBackgroundColor: scheme.surfaceContainerLow,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? const Color(0xFF334437) : const Color(0xFFE6E7D8),
        contentTextStyle: TextStyle(
          color: isLight ? Colors.white : const Color(0xFF1B241E),
          fontWeight: FontWeight.w700,
        ),
        shape: rounded16,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
    );
  }
}
