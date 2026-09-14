import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Nocturne design tokens, mirrored from the design project's nocturne.css.
abstract final class Noc {
  static const bg = Color(0xFF161826);
  static const surface = Color(0xFF232532);
  static const text = Color(0xFFE9E9ED);
  static const accent = Color(0xFF9184D9);
  static const divider = Color(0x29E9E9ED);

  static const n100 = Color(0xFFF3F5FE);
  static const n200 = Color(0xFFE4E7F5);
  static const n300 = Color(0xFFCFD3E5);
  static const n400 = Color(0xFFB2B6CA);
  static const n500 = Color(0xFF9397AB);
  static const n600 = Color(0xFF75798C);
  static const n700 = Color(0xFF595D6C);
  static const n800 = Color(0xFF3F424D);
  static const n900 = Color(0xFF292B31);

  static const a100 = Color(0xFFF5F4FF);
  static const a200 = Color(0xFFE7E5FE);
  static const a300 = Color(0xFFD2CEFD);
  static const a400 = Color(0xFFB5ABFC);
  static const a500 = Color(0xFF968AE0);
  static const a600 = Color(0xFF796CBF);
  static const a700 = Color(0xFF5D5294);
  static const a800 = Color(0xFF423A6A);
  static const a900 = Color(0xFF2B2741);

  static const radiusSm = 4.0;
  static const radiusMd = 8.0;
  static const radiusLg = 14.0;

  static const tabular = [FontFeature.tabularFigures()];
}

ThemeData buildNocturneTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  final textTheme = GoogleFonts.interTextTheme(base.textTheme)
      .apply(bodyColor: Noc.text, displayColor: Noc.text);
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(Noc.radiusMd),
    borderSide: const BorderSide(color: Noc.divider),
  );

  return base.copyWith(
    scaffoldBackgroundColor: Noc.bg,
    colorScheme: const ColorScheme.dark(
      primary: Noc.accent,
      onPrimary: Noc.bg,
      secondary: Noc.accent,
      onSecondary: Noc.bg,
      surface: Noc.bg,
      onSurface: Noc.text,
      surfaceContainerHigh: Noc.surface,
      surfaceContainerHighest: Noc.surface,
      outline: Noc.divider,
      error: Noc.a300,
    ),
    textTheme: textTheme,
    splashFactory: InkRipple.splashFactory,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Noc.accent,
      selectionColor: Noc.accent.withValues(alpha: 0.3),
      selectionHandleColor: Noc.accent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Noc.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      hintStyle: const TextStyle(color: Noc.n600, fontSize: 14),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(borderSide: const BorderSide(color: Noc.accent)),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Noc.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Noc.radiusLg))),
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: Noc.surface,
      headerBackgroundColor: Noc.surface,
    ),
    popupMenuTheme: const PopupMenuThemeData(color: Noc.surface),
  );
}
