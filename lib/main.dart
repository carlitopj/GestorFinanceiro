import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/auth_service.dart';
import 'services/drive_service.dart';
import 'services/database_service.dart';
<parameter name="content">import 'screens/home_screen.dart';

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
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Iniciando...';

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    // Tenta login silencioso (sessão anterior)
    final user = await AuthService().signInSilently();
    if (user != null) {
      _set('Conectando ao Google Drive...');
      final ok = await DriveService().inicializar();
      if (ok) {
        _set('Sincronizando dados...');
        final baixou = await DriveService().download();
        if (baixou) await DatabaseService().reabrir();
      }
    }
    _ir(const HomeScreen());
  }

  void _set(String msg) {
    if (mounted) setState(() => _status = msg);
  }

  void _ir(Widget tela) {
    if (mounted) Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => tela));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF2C3E50),
    body: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.account_balance_wallet,
            size: 80, color: Colors.white),
        const SizedBox(height: 16),
        Text('Gestor Financeiro',
            style: GoogleFonts.poppins(
                fontSize: 26, fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 40),
        const CircularProgressIndicator(color: Colors.white),
        const SizedBox(height: 16),
        Text(_status, style: GoogleFonts.poppins(
            color: Colors.white60, fontSize: 13)),
      ],
    )),
  );
}