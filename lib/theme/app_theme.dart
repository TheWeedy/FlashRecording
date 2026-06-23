import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const fontSerif = 'NotoSerif';
  static const fontSongti = 'NotoSerifSC';
  static const fontSans = 'Roboto';
  static const fontFallback = <String>[fontSongti, 'serif'];
  static const fontSansFallback = <String>[fontSongti, 'sans-serif'];

  static const background = Color(0xFFF7F4EF);
  static const surface = Color(0xFFFFFFFF);
  static const raisedSurface = Color(0xFFFFFAF2);
  static const ink = Color(0xFF182126);
  static const muted = Color(0xFF687277);
  static const faint = Color(0xFF9BA3A5);
  static const border = Color(0xFFE7DED1);
  static const primary = Color(0xFF256C6A);
  static const primarySoft = Color(0xFFE7F4EF);
  static const copper = Color(0xFFE37D50);
  static const copperSoft = Color(0xFFFFECE0);
  static const steel = Color(0xFF4E6FB5);
  static const steelSoft = Color(0xFFEAF0FF);
  static const sunshine = Color(0xFFF3C84B);
  static const sunshineSoft = Color(0xFFFFF6CF);
  static const success = Color(0xFF37966F);
  static const warning = Color(0xFFD49325);
  static const danger = Color(0xFFD35261);

  static const radiusCard = 18.0;
  static const radiusControl = 14.0;
  static const radiusSheet = 24.0;
  static const radiusPill = 999.0;
  static const pagePadding = 16.0;
  static const space1 = 6.0;
  static const space2 = 10.0;
  static const space3 = 16.0;
  static const space4 = 22.0;
  static const space5 = 30.0;
  static const space6 = 42.0;
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 520);
  static const motionCurve = Curves.easeOutCubic;
  static const motionOffset = Offset(0, 0.035);

  static final cardShadow = <BoxShadow>[
    BoxShadow(
      color: ink.withValues(alpha: 0.055),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static final liftShadow = <BoxShadow>[
    BoxShadow(
      color: primary.withValues(alpha: 0.18),
      blurRadius: 22,
      offset: const Offset(0, 10),
    ),
  ];

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: copper,
      surface: surface,
      error: danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: fontSerif,
    );
    final textTheme = _withFonts(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: _withFonts(base.primaryTextTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSheet),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: ink,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: muted),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        textStyle: textTheme.bodyMedium?.copyWith(
          color: ink,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          side: const BorderSide(color: border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: border,
        dragHandleSize: Size(42, 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusSheet),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(color: muted, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(color: faint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(44, 42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: border),
          minimumSize: const Size(44, 42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        sizeConstraints: BoxConstraints.tightFor(width: 58, height: 58),
        smallSizeConstraints: BoxConstraints.tightFor(width: 46, height: 46),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusControl)),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: muted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: false,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w800),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? primarySoft
                : raisedSurface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? primary : muted,
          ),
          side: const WidgetStatePropertyAll(BorderSide(color: border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusControl),
            ),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: raisedSurface,
        selectedColor: primarySoft,
        disabledColor: raisedSurface,
        labelStyle: textTheme.labelLarge?.copyWith(
          color: muted,
          fontWeight: FontWeight.w800,
        ),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: primary,
          fontWeight: FontWeight.w900,
        ),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
        ),
      ),
    );
  }

  static TextTheme _withFonts(TextTheme theme) {
    TextStyle? apply(TextStyle? style) => style?.copyWith(
      fontFamily: fontSerif,
      fontFamilyFallback: fontFallback,
      letterSpacing: 0,
      color: style.color ?? ink,
    );
    return TextTheme(
      displayLarge: apply(theme.displayLarge),
      displayMedium: apply(theme.displayMedium),
      displaySmall: apply(theme.displaySmall),
      headlineLarge: apply(theme.headlineLarge),
      headlineMedium: apply(theme.headlineMedium),
      headlineSmall: apply(theme.headlineSmall),
      titleLarge: apply(theme.titleLarge),
      titleMedium: apply(theme.titleMedium),
      titleSmall: apply(theme.titleSmall),
      bodyLarge: apply(theme.bodyLarge),
      bodyMedium: apply(theme.bodyMedium),
      bodySmall: apply(theme.bodySmall),
      labelLarge: apply(theme.labelLarge),
      labelMedium: apply(theme.labelMedium),
      labelSmall: apply(theme.labelSmall),
    );
  }

  static TextStyle? operationText(TextStyle? style) => style?.copyWith(
    fontFamily: fontSans,
    fontFamilyFallback: fontSansFallback,
    letterSpacing: 0,
  );
}
