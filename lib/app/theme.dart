import 'package:flutter/material.dart';

/// Palette "Prune et ocre". L'ocre est reserve a l'activite recente.
abstract final class AppColors {
  static const background = Color(0xFFF5F1F6);
  static const card = Color(0xFFFFFFFF);
  static const primary = Color(0xFF5B2A6E);
  static const accent = Color(0xFFA16207);
  static const ink = Color(0xFF2A1830);
  static const inkSoft = Color(0xFF6A5870);
  static const border = Color(0xFFE1D6E5);
  static const danger = Color(0xFFB3261E);
  static const pressed = Color(0x145B2A6E);
  static const skeleton = Color(0xFFEDE6F0);
}

const _displayFont = 'Newsreader';

/// Titre d'une discussion, porte l'identite du forum.
const threadTitleStyle = TextStyle(
  fontFamily: _displayFont,
  fontVariations: [FontVariation('wght', 500), FontVariation('opsz', 18)],
  fontSize: 17.5,
  height: 1.25,
  color: AppColors.ink,
);

const screenTitleStyle = TextStyle(
  fontFamily: _displayFont,
  fontVariations: [FontVariation('wght', 500), FontVariation('opsz', 28)],
  fontSize: 26,
  height: 1.15,
  color: AppColors.ink,
);

const logoStyle = TextStyle(
  fontFamily: _displayFont,
  fontVariations: [FontVariation('wght', 600), FontVariation('opsz', 28)],
  fontSize: 22,
  color: AppColors.ink,
);

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.accent,
    surface: AppColors.background,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkSoft,
    outlineVariant: AppColors.border,
    error: AppColors.danger,
  );

  OutlineInputBorder fieldBorder(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    splashColor: AppColors.pressed,
    highlightColor: AppColors.pressed,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 52,
      titleTextStyle: logoStyle,
    ),
    // Barre du bas : onglet actif en prune, plein et en gras, sur une
    // pastille bien visible ; les autres restent sombres et lisibles.
    navigationBarTheme: NavigationBarThemeData(
      height: 66,
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primary.withValues(alpha: 0.14),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.ink.withValues(alpha: 0.72),
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.ink.withValues(alpha: 0.72),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      extendedTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: fieldBorder(AppColors.border),
      enabledBorder: fieldBorder(AppColors.border),
      focusedBorder: fieldBorder(AppColors.primary, 1.5),
      errorBorder: fieldBorder(AppColors.danger),
      focusedErrorBorder: fieldBorder(AppColors.danger, 1.5),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
    // Cartes (widget Card) : fond blanc, coins arrondis, bordure fine,
    // sans ombre ni marge. Toutes les Card de l'appli prennent ce style.
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
  );
}
