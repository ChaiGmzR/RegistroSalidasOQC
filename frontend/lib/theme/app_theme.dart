import 'package:flutter/material.dart';

class AppTheme {
  // Colores ILSAN - Para sidebar y header
  static const Color darkPrimary = Color(0xFF32323E);
  static const Color darkSecondary = Color(0xFF40424F);
  static const Color darkTertiary = Color(0xFF2c3e50);
  static const Color darkHeader = Color(0xFF172A46);
  static const Color borderColor = Color(0xFF20688C);
  static const Color hoverColor = Color(0xFF34334E);
  
  // Colores de acento
  static const Color accentBlue = Color(0xFF3498db);
  static const Color accentDarkBlue = Color(0xFF2980b9);
  static const Color accentPurple = Color(0xFF502696);
  static const Color accentPurpleLight = Color(0xFF8e44ad);
  static const Color accentOrange = Color(0xFFe67e22);
  static const Color accentRed = Color(0xFFe74c3c);
  static const Color accentGreen = Color(0xFF456636);
  static const Color accentGreenLight = Color(0xFF5a7c42);
  
  // Colores de texto para fondo claro
  static const Color textLight = Color(0xFFecf0f1);
  static const Color textGray = Color(0xFF95a5a6);
  static const Color textSecondary = Color(0xFFD3D3D3);
  static const Color textDark = Color(0xFF2c3e50);
  static const Color textMuted = Color(0xFF7f8c8d);

  // Colores para el contenido principal (fondo blanco)
  static const Color contentBackground = Color(0xFFFAFAFA);
  static const Color cardBackground = Colors.white;
  static const Color lightBorder = Color(0xFFE0E0E0);

  // Aliases para compatibilidad
  static const Color primaryColor = accentBlue;
  static const Color primaryDark = accentDarkBlue;
  static const Color accentColor = accentPurple;
  static const Color successColor = accentGreenLight;
  static const Color warningColor = accentOrange;
  static const Color errorColor = accentRed;

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: accentBlue,
      secondary: accentPurple,
      surface: cardBackground,
      error: accentRed,
      onPrimary: textLight,
      onSecondary: textLight,
      onSurface: textDark,
      onError: textLight,
    ),
    scaffoldBackgroundColor: contentBackground,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      backgroundColor: darkHeader,
      foregroundColor: textLight,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textLight,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      color: cardBackground,
      shadowColor: Colors.black.withOpacity(0.1),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentBlue,
        foregroundColor: textLight,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accentBlue,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: const BorderSide(color: accentBlue),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentBlue,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accentBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accentRed),
      ),
      labelStyle: const TextStyle(color: textMuted),
      hintStyle: const TextStyle(color: textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightBorder),
        ),
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(darkHeader),
      dataRowColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return accentBlue.withOpacity(0.1);
        }
        if (states.contains(WidgetState.hovered)) {
          return accentBlue.withOpacity(0.05);
        }
        return Colors.white;
      }),
      headingTextStyle: const TextStyle(
        color: textLight,
        fontWeight: FontWeight.w600,
      ),
      dataTextStyle: const TextStyle(
        color: textDark,
      ),
      dividerThickness: 1,
    ),
    dividerTheme: const DividerThemeData(
      color: lightBorder,
      thickness: 1,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accentPurple,
      foregroundColor: textLight,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cardBackground,
      titleTextStyle: const TextStyle(
        color: textDark,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: const TextStyle(
        color: textMuted,
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkHeader,
      contentTextStyle: const TextStyle(color: textLight),
      actionTextColor: accentBlue,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    iconTheme: const IconThemeData(
      color: textMuted,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: textDark,
      iconColor: textMuted,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: contentBackground,
      labelStyle: const TextStyle(color: textDark),
      side: const BorderSide(color: lightBorder),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: darkHeader,
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: const TextStyle(color: textLight),
    ),
  );

  // Estilos de texto comunes
  static const TextStyle headerStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textDark,
  );

  static const TextStyle subHeaderStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textDark,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 14,
    color: textDark,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 12,
    color: textMuted,
  );

  // Decoraciones de contenedores para contenido
  static BoxDecoration contentCardDecoration = BoxDecoration(
    color: cardBackground,
    borderRadius: BorderRadius.circular(8),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ],
  );

  // Decoración para header de sección (estilo ILSAN)
  static BoxDecoration sectionHeaderDecoration = const BoxDecoration(
    gradient: LinearGradient(
      colors: [darkHeader, borderColor],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(8),
      topRight: Radius.circular(8),
    ),
  );
}
