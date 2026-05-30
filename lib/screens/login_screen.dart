import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/drive_service.dart';
import '../services/database_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool   _carregando = false;
  String _status     = '';

  Future<void> _login() async {
    setState(() { _carregando = true; _status = 'Entrando com Google...'; });

    final user = await AuthService().signIn();
    if (user == null) {
      setState(() { _carregando = false; _status = 'Login cancelado.'; });
      return;
    }

    setState(() => _status = 'Conectando ao Google Drive...');
    await DriveService().inicializar();

    setState(() => _status = 'Sincronizando dados...');
    final baixou = await DriveService().download();
    if (baixou) await DatabaseService().reabrir();

    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF2C3E50),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet,
                  size: 72, color: Colors.white),
            ),
            const SizedBox(height: 32),
            Text('Gestor Financeiro',
                style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 8),
            Text('Seus dados salvos automaticamente\nno Google Drive',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                    fontSize: 14, color: Colors.white60)),
            const SizedBox(height: 48),
            _beneficio(Icons.cloud_sync,  'Sincronização automática'),
            _beneficio(Icons.folder_shared, 'Compartilhe gestorfinanceiro.db'),
            _beneficio(Icons.devices,     'Acesse de qualquer celular'),
            const SizedBox(height: 48),
            if (_carregando) ...[
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(_status,
                  style: GoogleFonts.poppins(
                      color: Colors.white60, fontSize: 13)),
            ] else
              _botaoGoogle(),
            if (_status == 'Login cancelado.' && !_carregando) ...[
              const SizedBox(height: 16),
              Text(_status,
                  style: GoogleFonts.poppins(
                      color: Colors.redAccent, fontSize: 13)),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _beneficio(IconData icon, String texto) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(icon, color: Colors.greenAccent, size: 20),
      const SizedBox(width: 12),
      Text(texto,
          style: GoogleFonts.poppins(
              color: Colors.white70, fontSize: 14)),
    ]),
  );

  Widget _botaoGoogle() => InkWell(
    onTap: _login,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8)
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.login, size: 24, color: Colors.blue),
        const SizedBox(width: 12),
        Text('Entrar com Google',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.black87)),
      ]),
    ),
  );
}