import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/equipment_provider.dart';
import 'providers/session_provider.dart';
import 'screens/splash_screen.dart';

class ShotLogApp extends StatelessWidget {
  const ShotLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => EquipmentProvider()),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
      ],
      child: MaterialApp(
        title: 'ShotLog',
        theme: _buildTheme(),
        home: const SplashScreen(),
      ),
    );
  }

  ThemeData _buildTheme() {
    const accent = Color(0xFFE87722);
    const bg = Color(0xFF1A1210);
    const card = Color(0xFF261E1A);
    const border = Color(0xFF33281F);
    const textPrimary = Color(0xFFF0EAE5);
    const textSecondary = Color(0xFF7A6E68);
    const chipText = Color(0xFFC89A6A);
    const navBg = Color(0xFF201610);

    final cs = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: accent,
      onPrimary: const Color(0xFF1A0A00),
      surface: bg,
      onSurface: textPrimary,
      surfaceContainerHighest: navBg,
      surfaceContainerHigh: card,
      surfaceContainer: card,
      surfaceContainerLow: bg,
      onSurfaceVariant: textSecondary,
      outline: border,
      outlineVariant: const Color(0xFF4A3528),
      secondary: chipText,
      secondaryContainer: border,
      onSecondaryContainer: chipText,
      error: const Color(0xFFFF6B6B),
      errorContainer: const Color(0xFF8B1A1A),
    );

    return ThemeData(
      colorScheme: cs,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.all(border),
        labelStyle: const TextStyle(color: chipText, fontSize: 12),
        side: const BorderSide(color: Color(0xFF4A3528)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
        iconTheme: IconThemeData(color: textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: const DividerThemeData(color: border, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBg,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        height: 56,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? accent
                : textSecondary,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? accent
                : textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
    );
  }
}
