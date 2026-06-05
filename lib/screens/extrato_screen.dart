import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/transacao.dart';
import '../services/database_service.dart';

class ExtratoScreen extends StatefulWidget {
  final String usuario;
  final String mesRef;
  final Function(Transacao) onEditar;
  final Future<void> Function() onAtualizar;

  const ExtratoScreen({
    super.key,
    required this.usuario,
    required this.mesRef,
    required this.onEditar,
    required this.onAtualizar,
  });

  @override
  State<ExtratoScreen> createState() => _ExtratoScreenState();
}

class _ExtratoScreenState extends State<ExtratoScreen> {
  final _db  = DatabaseService();
  final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  List<Transacao> _transacoes = [];
  List<Transacao> _filtradas  = [];
  bool _carregando  = true;
  String _filtroTipo = 'Todos';
  String _ordenarPor = 'Descrição';
  bool   _ordemAsc   = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    _transacoes = await _db.buscarPorMes(widget.usuario, widget.mesRef);
    _aplicarFiltros();
    setState(() => _carregando = false);
  }

  void _aplicarFiltros() {
    var lista = [..._transacoes];
    if (_filtroTipo != 'Todos') {
      lista = lista.where((t) => t.tipo == _filtroTipo).toList();
    }
    lista.sort((a, b) {
      int cmp;
      switch (_ordenarPor) {
        case 'Valor':     cmp = a.valor.compareTo(b.valor); break;
        case 'Tipo':      cmp = a.tipo.compareTo(b.tipo); break;
        case 'Categoria': cmp = a.categoria.compareTo(b.categoria); break;
        default:          cmp = a.descricao.toLowerCase().compareTo(b.descricao.toLowerCase());
      }
      return _ordemAsc ? cmp : -cmp;
    });
    setState(() => _filtradas = lista);
  }

  Future<void> _excluir(Transacao t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Excluir "${t.descricao}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok == true && t.id != null) {
      await _db.deletarTransacao(t.id!);
      await _carregar();
      await widget.onAtualizar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Lançamento excluído!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _editarEVoltar(Transacao t) {
    widget.onEditar(t);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s    = _db.calcularSaldo(_transacoes);
    final rec  = s['receitas']!;
    final desp = s['despesas']!;
    final sal  = s['saldo']!;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Text('Extrato — ${widget.mesRef}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _carregar),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // Resumo
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  _resumoCard('Receitas', rec,  Colors.green),
                  const SizedBox(width: 8),
                  _resumoCard('Despesas', desp, Colors.red),
                  const SizedBox(width: 8),
                  _resumoCard('Saldo', sal,
                      sal >= 0 ? Colors.green : Colors.red),
                ]),
              ),
              // Filtros
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(children: [
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _filtroTipo,
                    decoration: _decor('Filtrar'),
                    items: ['Todos', 'Receita', 'Despesa'].map((t) =>
                        DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) {
                      if (v != null) { _filtroTipo = v; _aplicarFiltros(); }
                    },
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _ordenarPor,
                    decoration: _decor('Ordenar'),
                    items: ['Descrição', 'Valor', 'Tipo', 'Categoria'].map((t) =>
                        DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) {
                      if (v != null) { _ordenarPor = v; _aplicarFiltros(); }
                    },
                  )),
                  IconButton(
                    icon: Icon(_ordemAsc
                        ? Icons.arrow_upward
                        : Icons.arrow_downward),
                    onPressed: () {
                      setState(() => _ordemAsc = !_ordemAsc);
                      _aplicarFiltros();
                    },
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${_filtradas.length} lançamento(s)',
                      style: GoogleFonts.poppins(
                          color: Colors.grey, fontSize: 12)),
                ),
              ),
              // Lista
              Expanded(child: _filtradas.isEmpty
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inbox, size: 64, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text('Nenhum lançamento encontrado',
                            style: GoogleFonts.poppins(color: Colors.grey)),
                      ]))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _filtradas.length,
                      itemBuilder: (_, i) => _cardTransacao(_filtradas[i]),
                    )),
            ]),
    );
  }

  Widget _resumoCard(String label, double valor, Color cor) =>
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.1),
          border: Border.all(color: cor.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Text(label,
              style: GoogleFonts.poppins(fontSize: 11, color: cor)),
          Text(_fmt.format(valor),
              style: GoogleFonts.poppins(
                  fontSize: 12, fontWeight: FontWeight.bold, color: cor)),
        ]),
      ));

  Widget _cardTransacao(Transacao t) {
    final isReceita = t.tipo == 'Receita';
    final cor       = isReceita ? Colors.green : Colors.red;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cor.withOpacity(0.3)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cor.withOpacity(0.1),
          child: Icon(
              isReceita ? Icons.arrow_upward : Icons.arrow_downward,
              color: cor, size: 18),
        ),
        title: Text(t.descricao,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text('${t.categoria}  •  ${t.tipo}',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
        trailing: Text(_fmt.format(t.valor),
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold, color: cor, fontSize: 14)),
        onTap: () => _opcoes(t),
      ),
    );
  }

  void _opcoes(Transacao t) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(t.descricao,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          Text(_fmt.format(t.valor),
              style: GoogleFonts.poppins(
                  fontSize: 22,
                  color: t.tipo == 'Receita' ? Colors.green : Colors.red)),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.blue),
            title: const Text('Editar lançamento'),
            onTap: () { Navigator.pop(context); _editarEVoltar(t); },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Excluir lançamento'),
            onTap: () { Navigator.pop(context); _excluir(t); },
          ),
          ListTile(
            leading: const Icon(Icons.cancel, color: Colors.grey),
            title: const Text('Cancelar'),
            onTap: () => Navigator.pop(context),
          ),
        ]),
      ),
    );
  }

  InputDecoration _decor(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  );
}
