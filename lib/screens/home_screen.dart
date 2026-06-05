import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/transacao.dart';
import '../services/auth_service.dart';
import '../services/drive_service.dart';
import '../services/database_service.dart';
import 'extrato_screen.dart';
import 'graficos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db    = DatabaseService();
  final _auth  = AuthService();
  final _drive = DriveService();
  final _fmt   = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  List<String> _usuarios   = [];
  List<String> _categorias = [];
  String _usuarioAtual     = '';
  int    _mesAtual         = DateTime.now().month;
  final  _ano              = DateTime.now().year;

  double _receitas = 0, _despesas = 0, _saldo = 0;
  bool _carregando    = true;
  bool _salvando      = false;
  bool _sincronizando = false;

  final _descCtrl  = TextEditingController();
  final _valorCtrl = TextEditingController();
  String _tipoSel  = 'Despesa';
  String _catSel   = 'Outros';
  int?   _idEdicao;

  final _meses = const [
    'Janeiro','Fevereiro','Março','Abril','Maio','Junho',
    'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro'
  ];

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  String get _mesRef =>
      '${_mesAtual.toString().padLeft(2, '0')}/$_ano';

  Future<void> _inicializar() async {
    setState(() => _carregando = true);
    _usuarios   = await _db.buscarUsuarios();
    _categorias = await _db.buscarCategorias();
    if (_usuarios.isNotEmpty)   _usuarioAtual = _usuarios.first;
    if (_categorias.isNotEmpty) {
      _catSel = _categorias.contains('Outros')
          ? 'Outros' : _categorias.first;
    }
    await _carregarSaldo();
    setState(() => _carregando = false);
  }

  Future<void> _carregarSaldo() async {
    final lista = await _db.buscarPorMes(_usuarioAtual, _mesRef);
    final s     = _db.calcularSaldo(lista);
    setState(() {
      _receitas = s['receitas']!;
      _despesas = s['despesas']!;
      _saldo    = s['saldo']!;
    });
  }

  // ── Google Drive ─────────────────────────────────────────────

  Future<void> _loginDrive() async {
    setState(() => _sincronizando = true);
    final user = await _auth.signIn();
    if (user == null) {
      _snack('Login cancelado.', erro: true);
      setState(() => _sincronizando = false);
      return;
    }
    _snack('Conectado como ${_auth.email}');
    await _drive.inicializar();
    await _sincronizar(silencioso: true);
    setState(() => _sincronizando = false);
  }

  Future<void> _sincronizar({bool silencioso = false}) async {
    if (!_auth.isSignedIn) { _loginDrive(); return; }
    setState(() => _sincronizando = true);
    final baixou = await _drive.download();
    if (baixou) {
      await _db.reabrir();
      await _inicializar();
      if (!silencioso) _snack('Dados sincronizados do Drive!');
    } else {
      if (!silencioso) _snack('Nenhum dado novo no Drive.');
    }
    setState(() => _sincronizando = false);
  }

  Future<void> _verificarExistente(String desc) async {
    if (desc.length < 2) return;
    final t = await _db.buscarPorDescricaoEMes(
        _usuarioAtual, desc, _mesRef);
    if (t != null) {
      setState(() {
        _idEdicao = t.id;
        _tipoSel  = t.tipo;
        _catSel   = t.categoria;
      });
      _valorCtrl.text =
          t.valor.toStringAsFixed(2).replaceAll('.', ',');
    }
  }

  Future<void> _salvar() async {
    final desc = _descCtrl.text.trim();
    final valorStr = _valorCtrl.text
        .replaceAll('R\$', '').replaceAll(' ', '')
        .replaceAll('.', '').replaceAll(',', '.');
    final valor = double.tryParse(valorStr);
    if (desc.isEmpty || valor == null) {
      _snack('Preencha descrição e valor corretamente.', erro: true);
      return;
    }
    setState(() => _salvando = true);
    if (_idEdicao != null) {
      await _db.atualizar(Transacao(
        id: _idEdicao, usuario: _usuarioAtual,
        descricao: desc, valor: valor,
        tipo: _tipoSel, categoria: _catSel, mesRef: _mesRef,
      ));
    } else {
      await _db.salvar(Transacao(
        usuario: _usuarioAtual, descricao: desc, valor: valor,
        tipo: _tipoSel, categoria: _catSel, mesRef: _mesRef,
      ));
    }
    _descCtrl.clear(); _valorCtrl.clear();
    _idEdicao = null;  _tipoSel = 'Despesa';
    _catSel = _categorias.contains('Outros')
        ? 'Outros' : _categorias.first;
    setState(() => _salvando = false);
    await _carregarSaldo();

    if (_auth.isSignedIn) {
      final uploadOk = await _drive.upload();
      _snack(uploadOk
          ? 'Salvo e enviado ao Drive! ✅'
          : 'Salvo localmente. Falha no Drive ❌');
    } else {
      _snack('Lançamento salvo localmente!');
    }
  }

  void _preencherEdicao(Transacao t) {
    _descCtrl.text  = t.descricao;
    _valorCtrl.text = t.valor.toStringAsFixed(2).replaceAll('.', ',');
    setState(() {
      _idEdicao = t.id; _tipoSel = t.tipo; _catSel = t.categoria;
    });
    _snack('Editando: ${t.descricao}');
  }

  void _snack(String msg, {bool erro = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: erro ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Dialogs ──────────────────────────────────────────────────

  void _dialogDrive() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.cloud, color: Color(0xFF2C3E50)),
        const SizedBox(width: 8),
        const Text('Google Drive'),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_auth.isSignedIn) ...[
          const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 8),
          Text('Conectado como:\n${_auth.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          Text('Arquivo: carteira.db\nPasta: GestorFinanceiro',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              Clipboard.setData(
                  ClipboardData(text: _drive.linkPasta));
              Navigator.pop(ctx);
              _snack('Link copiado!');
            },
            child: const Text('📋 Copiar link da pasta',
                style: TextStyle(color: Colors.blue, fontSize: 13)),
          ),
        ] else ...[
          const Icon(Icons.cloud_off, color: Colors.grey, size: 48),
          const SizedBox(height: 8),
          const Text(
            'Conecte ao Google Drive para sincronizar '
            'o carteira.db automaticamente.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13),
          ),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar')),
        if (_auth.isSignedIn) ...[
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_download, size: 16),
            label: const Text('Sincronizar'),
            onPressed: () { Navigator.pop(ctx); _sincronizar(); },
          ),
          TextButton(
            onPressed: () async {
              await _auth.signOut();
              Navigator.pop(ctx);
              setState(() {});
              _snack('Desconectado do Drive.');
            },
            child: const Text('Sair', style: TextStyle(color: Colors.red)),
          ),
        ] else
          ElevatedButton.icon(
            icon: const Icon(Icons.login, size: 16),
            label: const Text('Entrar com Google'),
            onPressed: () { Navigator.pop(ctx); _loginDrive(); },
          ),
      ],
    ));
  }

  void _dialogUsuario() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Novo Usuário'),
      content: TextField(controller: ctrl,
          decoration: const InputDecoration(
              labelText: 'Nome', border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar')),
        ElevatedButton(onPressed: () async {
          final nome = ctrl.text.trim();
          if (nome.isEmpty) return;
          await _db.adicionarUsuario(nome);
          _usuarios = await _db.buscarUsuarios();
          setState(() => _usuarioAtual = nome);
          await _carregarSaldo();
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Adicionar')),
      ],
    ));
  }

  void _dialogCategoria() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Nova Categoria'),
      content: TextField(controller: ctrl,
          decoration: const InputDecoration(
              labelText: 'Nome', border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar')),
        ElevatedButton(onPressed: () async {
          final nome = ctrl.text.trim();
          if (nome.isEmpty) return;
          final fmt =
              nome[0].toUpperCase() + nome.substring(1).toLowerCase();
          await _db.adicionarCategoria(fmt);
          _categorias = await _db.buscarCategorias();
          setState(() => _catSel = fmt);
          if (ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('Adicionar')),
      ],
    ));
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F6F8),
    appBar: AppBar(
      title: Text('Gestor Financeiro',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      actions: [
        // Ícone Drive — verde se conectado, cinza se não
        _sincronizando
            ? const Padding(padding: EdgeInsets.all(14),
                child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)))
            : IconButton(
                icon: Icon(Icons.cloud,
                    color: _auth.isSignedIn
                        ? Colors.greenAccent : Colors.white54),
                tooltip: _auth.isSignedIn
                    ? 'Drive conectado' : 'Conectar ao Drive',
                onPressed: _dialogDrive,
              ),
        IconButton(
          icon: const Icon(Icons.bar_chart),
          tooltip: 'Gráficos',
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => GraficosScreen(
                  usuario: _usuarioAtual, mesRef: _mesRef))),
        ),
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'addUser') {
              _dialogUsuario();
            } else if (v == 'delUser') {
              if (_usuarios.length <= 1) {
                _snack('Não é possível excluir o único usuário.',
                    erro: true);
                return;
              }
              final ok = await showDialog<bool>(context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Confirmar'),
                    content: Text(
                        'Excluir $_usuarioAtual e todos os lançamentos?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Excluir'),
                      ),
                    ],
                  ));
              if (ok == true) {
                await _db.excluirUsuario(_usuarioAtual);
                _usuarios = await _db.buscarUsuarios();
                setState(() => _usuarioAtual = _usuarios.first);
                await _carregarSaldo();
              }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'addUser', child: Text('+ Novo Usuário')),
            PopupMenuItem(value: 'delUser', child: Text('− Excluir Usuário')),
          ],
        ),
      ],
    ),
    body: _carregando
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () => _sincronizar(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _cardSaldo(),
                const SizedBox(height: 16),
                _seletores(),
                const SizedBox(height: 16),
                _formLancamento(),
                const SizedBox(height: 12),
                _botaoExtrato(),
                const SizedBox(height: 24),
              ]),
            ),
          ),
  );

  Widget _cardSaldo() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: _saldo >= 0
            ? [const Color(0xFF27AE60), const Color(0xFF2ECC71)]
            : [const Color(0xFFE74C3C), const Color(0xFFC0392B)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [BoxShadow(
          color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
    ),
    child: Column(children: [
      Text('${_meses[_mesAtual - 1]} $_ano',
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
      const SizedBox(height: 4),
      Text(_fmt.format(_saldo),
          style: GoogleFonts.poppins(color: Colors.white,
              fontSize: 34, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text('Saldo do mês',
          style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12)),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _miniCard('Receitas', _receitas),
        _miniCard('Despesas', _despesas),
      ]),
    ]),
  );

  Widget _miniCard(String label, double valor) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(children: [
      Text(label, style: GoogleFonts.poppins(
          color: Colors.white70, fontSize: 12)),
      Text(_fmt.format(valor), style: GoogleFonts.poppins(
          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
    ]),
  );

  Widget _seletores() => Row(children: [
    Expanded(child: DropdownButtonFormField<String>(
      value: _usuarioAtual.isEmpty ? null : _usuarioAtual,
      decoration: _decor('Usuário'),
      items: _usuarios.map((u) =>
          DropdownMenuItem(value: u, child: Text(u))).toList(),
      onChanged: (v) async {
        if (v != null) {
          setState(() => _usuarioAtual = v);
          await _carregarSaldo();
        }
      },
    )),
    const SizedBox(width: 12),
    Expanded(child: DropdownButtonFormField<int>(
      value: _mesAtual,
      decoration: _decor('Mês'),
      items: List.generate(12, (i) =>
          DropdownMenuItem(value: i + 1, child: Text(_meses[i]))),
      onChanged: (v) async {
        if (v != null) {
          setState(() => _mesAtual = v);
          await _carregarSaldo();
        }
      },
    )),
  ]);

  Widget _formLancamento() => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Text(_idEdicao != null ? 'Editando Lançamento' : 'Novo Lançamento',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        TextField(controller: _descCtrl,
            decoration: _decor('Descrição do item'),
            onChanged: _verificarExistente),
        const SizedBox(height: 10),
        TextField(controller: _valorCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: _decor('Valor (R\$ 0,00)')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            value: _categorias.contains(_catSel) ? _catSel : null,
            decoration: _decor('Categoria'),
            items: _categorias.map((c) =>
                DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _catSel = v);
            },
          )),
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFF2980B9)),
            onPressed: _dialogCategoria, tooltip: 'Nova categoria'),
          IconButton(
            icon: const Icon(Icons.remove_circle, color: Color(0xFFE74C3C)),
            tooltip: 'Excluir categoria',
            onPressed: () async {
              if (['Outros', 'Alimentação'].contains(_catSel)) {
                _snack('Esta categoria não pode ser excluída.', erro: true);
                return;
              }
              await _db.excluirCategoria(_catSel);
              _categorias = await _db.buscarCategorias();
              setState(() => _catSel = _categorias.first);
            }),
        ]),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _tipoSel,
          decoration: _decor('Tipo'),
          items: ['Despesa', 'Receita'].map((t) =>
              DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _tipoSel = v);
          },
        ),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _salvando ? null : _salvar,
            icon: _salvando
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_idEdicao != null
                ? 'Atualizar Lançamento' : 'Salvar Lançamento'),
          ),
        ),
        if (_idEdicao != null)
          TextButton(
            onPressed: () => setState(() {
              _idEdicao = null;
              _descCtrl.clear(); _valorCtrl.clear();
              _tipoSel = 'Despesa';
            }),
            child: const Text('Cancelar edição',
                style: TextStyle(color: Colors.grey)),
          ),
      ]),
    ),
  );

  Widget _botaoExtrato() => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      icon: const Icon(Icons.list_alt),
      label: Text('Ver Extrato de ${_meses[_mesAtual - 1]}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ExtratoScreen(
          usuario: _usuarioAtual, mesRef: _mesRef,
          onEditar: _preencherEdicao, onAtualizar: _carregarSaldo,
        ),
      )),
    ),
  );

  InputDecoration _decor(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}