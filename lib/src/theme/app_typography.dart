import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static const String uiFontFamily = 'Pretendard';
  static const String japaneseFontFamily = 'PretendardJP';

  /// Japanese vocabulary is intentionally kept at regular weight.
  /// Heavy CJK strokes become visually dense on small mobile screens.
  static TextStyle japanese(TextStyle? base) =>
      (base ?? const TextStyle()).copyWith(
        fontFamily: japaneseFontFamily,
        fontWeight: FontWeight.w400,
      );
}
