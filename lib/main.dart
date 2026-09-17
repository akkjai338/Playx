import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const PlayXApp());
}

class PlayXApp extends StatelessWidget {
  const PlayXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlayX Video Player',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3B82F6),
        scaffoldBackgroundColor: const Color(0xFF0B1220),
        cardTheme: CardTheme(color: const Color(0xFF121D31), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFF121D31), border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFF3B82F6))), contentPadding: const EdgeInsets.symmetric(vertical: 16)),
        navigationBarTheme: const NavigationBarThemeData(backgroundColor: Color(0xFF0F192B)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          elevation: 0,
        ),
      ),
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3B82F6),
      ),
      home: const HomeScreen(),
    );
  }
}
