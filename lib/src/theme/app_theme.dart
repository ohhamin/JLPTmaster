import 'package:flutter/material.dart';

import 'app_typography.dart';

class AppTheme {
  static const _lightSeed = Color(0xFF78AD73);
  static const _darkSeed = Color(0xFFE1B86A);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final baseScheme = ColorScheme.fromSeed(
      seedColor: isLight ? _lightSeed : _darkSeed,
      brightness: brightness,
    );

    final scheme = baseScheme.copyWith(
      primary: isLight ? const Color(0xFF679B64) : const Color(0xFFE5B963),
      onPrimary: isLight ? const Color(0xFFFFFFFF) : const Color(0xFF241A0D),
      secondary: isLight ? const Color(0xFFE8B968) : const Color(0xFF8497B2),
      tertiary: isLight ? const Color(0xFFE99C94) : const Color(0xFFC9948B),
      surface: isLight ? const Color(0xFFF4F8EE) : const Color(0xFF0C121A),
      surfaceContainerLow: isLight ? const Color(0xFFFFFEF8) : const Color(0xFF151E29),
      surfaceContainerHighest: isLight ? const Color(0xFFE5EFDE) : const Color(0xFF243040),
      onSurface: isLight ? const Color(0xFF28372B) : const Color(0xFFF3F0E7),
      onSurfaceVariant: isLight ? const Color(0xFF667267) : const Color(0xFFB7C1CF),
      outline: isLight ? const Color(0xFFB8C9B2) : const Color(0xFF4C5A6D),
      outlineVariant: isLight ? const Color(0xFFD4E0CE) : const Color(0xFF2E3A49),
      errorContainer: isLight ? const Color(0xFFFFE2DD) : const Color(0xFF4B2928),
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
        backgroundColor: isLight
            ? const Color(0xDDF8FBF1)
            : const Color(0xD20B121B),
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
        color: isLight
            ? const Color(0xF5FFFEF8)
            : const Color(0xF018222E),
        shadowColor: Colors.black.withValues(alpha: isLight ? 0.05 : 0.22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isLight ? 0.92 : 0.86),
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
        fillColor: isLight
            ? const Color(0xF5FFFEF8)
            : const Color(0xF018222E),
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
        backgroundColor: isLight
            ? const Color(0xF4FFFEF8)
            : const Color(0xF0121922),
        indicatorColor: isLight
            ? const Color(0xFFDCEBD4)
            : const Color(0xFF313B49),
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
        backgroundColor: isLight
            ? const Color(0xFF334437)
            : const Color(0xFFE8E0D2),
        contentTextStyle: TextStyle(
          color: isLight ? Colors.white : const Color(0xFF1B2028),
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
