import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GestorFinanceiroApp());
}

class GestorFinanceiroApp extends StatelessWidget {
  const GestorFinanceiroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestor Financeiro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C3E50),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2C3E50),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2C3E50),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 14),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}