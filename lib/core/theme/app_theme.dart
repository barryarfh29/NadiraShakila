import 'package:flutter/material.dart';

/// Kiro-style purple dark theme.
class AppColors {
  // Base backgrounds
  static const Color background = Color(0xFF1E1A27); // editor
  static const Color surface = Color(0xFF17141F); // sidebar / panels / tab bar
  static const Color surfaceVariant = Color(0xFF252131); // active tab / selected
  static const Color surfaceLight = Color(0xFF3A3148); // selected / highlight
  static const Color surfaceHover = Color(0xFF2A2536); // list hover

  // Activity bar
  static const Color activityBar = Color(0xFF141019);
  static const Color activityBarActive = Color(0xFF7C5CFF);

  // Sidebar
  static const Color sidebarBg = Color(0xFF17141F);
  static const Color sidebarHeader = Color(0xFF17141F);

  // Text colors
  static const Color textPrimary = Color(0xFFE8E4F0);
  static const Color textSecondary = Color(0xFFA39FB2);
  static const Color textMuted = Color(0xFF6E6880);
  static const Color textInverse = Color(0xFF1E1A27);

  // Accent colors (purple)
  static const Color primary = Color(0xFF7C5CFF);
  static const Color primaryHover = Color(0xFF8E72FF);
  static const Color primaryLight = Color(0xFFB3A1FF);
  static const Color primaryDim = Color(0xFF5B43B8);
  static const Color secondary = Color(0xFF34D399);
  static const Color accent = Color(0xFFC4B5FD);

  // Semantic colors
  static const Color error = Color(0xFFFF6B6B);
  static const Color errorBg = Color(0xFF3A1F2A);
  static const Color warning = Color(0xFFFBBF24);
  static const Color success = Color(0xFF4ADE80);
  static const Color info = Color(0xFF8EC8FF);

  // Status bar
  static const Color statusBar = Color(0xFF252131);

  // Chat specific
  static const Color userBubble = Color(0xFF252131);
  static const Color userBubbleBorder = Color(0xFF3A3148);
  static const Color assistantBg = Color(0xFF17141F);
  static const Color codeBlock = Color(0xFF17141F);
  static const Color codeBlockBorder = Color(0xFF2E2840);
  static const Color inlineCode = Color(0xFF2A2440);

  // Borders
  static const Color border = Color(0xFF2E2840);
  static const Color borderLight = Color(0xFF252131);
  static const Color borderFocus = Color(0xFF7C5CFF);

  // Scrollbar
  static const Color scrollbar = Color(0xFF3A3148);
  static const Color scrollbarHover = Color(0xFF4A4058);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Segoe UI',
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 40,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderFocus, width: 1),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: const TextStyle(fontSize: 13),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          padding: const EdgeInsets.all(6),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return AppColors.scrollbarHover;
          }
          return AppColors.scrollbar;
        }),
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(3),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        textStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          height: 1.6,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
        ),
        labelSmall: TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
