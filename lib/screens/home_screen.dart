import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/transacao.dart';
import '../services/database_service.dart';
import 'extrato_screen.dart';
import 'graficos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db  = DatabaseService();
  final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  List<String> _usuarios   = [];
  List<String> _categorias = [];
  String _usuarioAtual     = '';
  int    _mesAtual         = DateTime.now().month;
  final  _ano              = DateTime.now().year;

  double _receitas = 0, _despesas = 0, _saldo = 0;
  bool _carregando = true;
  bool _salvando   = false;

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

  // ── Menu Arquivo ─────────────────────────────────────────────

  Future<void> _menuAbrir() async {
    final ok = await _db.abrirArquivo(context);
    if (ok) {
      await _inicializar();
      _snack('Arquivo aberto: ${_db.caminhoAtual?.split('/').last}');
    } else {
      _snack('Nenhum arquivo selecionado.', erro: true);
    }
  }

  Future<void> _menuNovo() async {
    // Confirma se quer fechar o atual
    if (_db.arquivoAberto) {
      final ok = await showDialog<bool>(context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Novo arquivo'),
            content: const Text(
                'Deseja fechar o arquivo atual e criar um novo?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Confirmar')),
            ],
          ));
      if (ok != true) return;
    }
    await _db.fechar();
    final ok = await _db.novoArquivo();
    if (ok) {
      await _inicializar();
      _snack('Novo arquivo criado em Downloads!');
    }
  }

  Future<void> _menuSalvar() async {
    final ok = await _db.salvar();
    if (ok) {
      _snack('Arquivo salvo! ✅');
    } else {
      _snack('Erro ao salvar.', erro: true);
    }
  }

  Future<void> _menuSalvarComo() async {
    final caminho = await _db.salvarComo();
    if (caminho != null) {
      _snack('Salvo em: ${caminho.split('/').last} ✅');
    } else {
      _snack('Operação cancelada.', erro: true);
    }
  }

  Future<void> _menuFechar() async {
    final ok = await showDialog<bool>(context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Fechar arquivo'),
          content: const Text(
              'Deseja fechar o arquivo atual?\n\n'
              'Outra pessoa poderá abrir e editar.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Fechar')),
          ],
        ));
    if (ok == true) {
      await _db.fechar();
      await _inicializar();
      _snack('Arquivo fechado.');
    }
  }

  // ── Transações ───────────────────────────────────────────────

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
      await _db.atualizarTransacao(Transacao(
        id: _idEdicao, usuario: _usuarioAtual,
        descricao: desc, valor: valor,
        tipo: _tipoSel, categoria: _catSel, mesRef: _mesRef,
      ));
    } else {
      await _db.salvarTransacao(Transacao(
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
    _snack('Lançamento salvo!');
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
      title: Text(
        _db.arquivoAberto
            ? _db.caminhoAtual?.split('/').last ?? 'Gestor Financeiro'
            : 'Gestor Financeiro',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      actions: [
        // Menu Arquivo
        PopupMenuButton<String>(
          icon: const Icon(Icons.folder_open),
          tooltip: 'Arquivo',
          onSelected: (v) async {
            if (v == 'novo')       _menuNovo();
            if (v == 'abrir')      _menuAbrir();
            if (v == 'salvar')     _menuSalvar();
            if (v == 'salvarComo') _menuSalvarComo();
            if (v == 'fechar')     _menuFechar();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'novo',
                child: Row(children: [
                  Icon(Icons.add, size: 18), SizedBox(width: 8),
                  Text('Novo'),
                ])),
            const PopupMenuItem(value: 'abrir',
                child: Row(children: [
                  Icon(Icons.folder_open, size: 18), SizedBox(width: 8),
                  Text('Abrir'),
                ])),
            const PopupMenuItem(value: 'salvar',
                child: Row(children: [
                  Icon(Icons.save, size: 18), SizedBox(width: 8),
                  Text('Salvar'),
                ])),
            const PopupMenuItem(value: 'salvarComo',
                child: Row(children: [
                  Icon(Icons.save_as, size: 18), SizedBox(width: 8),
                  Text('Salvar como'),
                ])),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'fechar',
                child: Row(children: [
                  Icon(Icons.close, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Fechar', style: TextStyle(color: Colors.red)),
                ])),
          ],
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
            if (v == 'addUser') _dialogUsuario();
            else if (v == 'delUser') {
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
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // Banner quando nenhum arquivo está aberto
              if (!_db.arquivoAberto)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Nenhum arquivo aberto. Use o menu 📁 para Abrir ou Novo.',
                      style: GoogleFonts.poppins(fontSize: 12),
                    )),
                  ]),
                ),
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