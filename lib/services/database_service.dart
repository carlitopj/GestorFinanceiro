import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/transacao.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  static const List<String> categoriasPadrao = [
    'Alimentação', 'Transporte', 'Lazer', 'Saúde', 'Moradia', 'Outros'
  ];
  static const List<String> usuariosPadrao = ['Lidiane', 'Junior'];

  // ─────────────────────────────────────────────
  //  INICIALIZAÇÃO
  // ─────────────────────────────────────────────

  Future<Database> get db async {
    _db ??= await _inicializar();
    return _db!;
  }

  Future<Database> _inicializar() async {
    final dir    = await getApplicationDocumentsDirectory();
    final caminho = p.join(dir.path, 'financas.db');
    return await openDatabase(
      caminho,
      version: 1,
      onCreate: _criarTabelas,
    );
  }

  Future<void> _criarTabelas(Database db, int version) async {
    await db.execute('''
      CREATE TABLE transacoes (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario   TEXT,
        descricao TEXT,
        valor     REAL,
        tipo      TEXT,
        categoria TEXT,
        mes_ref   TEXT
      )
    ''');
    await db.execute(
        'CREATE TABLE usuarios (nome TEXT UNIQUE)');
    await db.execute(
        'CREATE TABLE categorias (nome TEXT UNIQUE)');

    // Dados padrão
    for (final u in usuariosPadrao) {
      await db.insert('usuarios', {'nome': u},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    for (final c in categoriasPadrao) {
      await db.insert('categorias', {'nome': c},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ─────────────────────────────────────────────
  //  USUÁRIOS
  // ─────────────────────────────────────────────

  Future<List<String>> buscarUsuarios() async {
    final d = await db;
    final res = await d.query('usuarios');
    return res.map((r) => r['nome'] as String).toList();
  }

  Future<bool> adicionarUsuario(String nome) async {
    try {
      final d = await db;
      await d.insert('usuarios', {'nome': nome},
          conflictAlgorithm: ConflictAlgorithm.ignore);
      return true;
    } catch (_) { return false; }
  }

  Future<bool> excluirUsuario(String nome) async {
    try {
      final d = await db;
      await d.delete('usuarios', where: 'nome=?', whereArgs: [nome]);
      await d.delete('transacoes', where: 'usuario=?', whereArgs: [nome]);
      return true;
    } catch (_) { return false; }
  }

  // ─────────────────────────────────────────────
  //  CATEGORIAS
  // ─────────────────────────────────────────────

  Future<List<String>> buscarCategorias() async {
    final d = await db;
    final res = await d.query('categorias', orderBy: 'nome ASC');
    return res.map((r) => r['nome'] as String).toList();
  }

  Future<bool> adicionarCategoria(String nome) async {
    try {
      final d = await db;
      await d.insert('categorias', {'nome': nome},
          conflictAlgorithm: ConflictAlgorithm.ignore);
      return true;
    } catch (_) { return false; }
  }

  Future<bool> excluirCategoria(String nome) async {
    try {
      final d = await db;
      await d.delete('categorias', where: 'nome=?', whereArgs: [nome]);
      return true;
    } catch (_) { return false; }
  }

  // ─────────────────────────────────────────────
  //  TRANSAÇÕES
  // ─────────────────────────────────────────────

  Future<List<Transacao>> buscarPorMes(String usuario, String mesRef) async {
    final d = await db;
    final res = await d.query('transacoes',
        where: 'usuario=? AND mes_ref=?', whereArgs: [usuario, mesRef]);
    return res.map(Transacao.fromMap).toList();
  }

  Future<List<Transacao>> buscarTodas(String usuario) async {
    final d = await db;
    final res = await d.query('transacoes',
        where: 'usuario=?', whereArgs: [usuario], orderBy: 'id ASC');
    return res.map(Transacao.fromMap).toList();
  }

  Future<Transacao?> buscarPorDescricaoEMes(
      String usuario, String descricao, String mesRef) async {
    final d = await db;
    final res = await d.query('transacoes',
        where: 'usuario=? AND descricao=? AND mes_ref=?',
        whereArgs: [usuario, descricao, mesRef]);
    return res.isEmpty ? null : Transacao.fromMap(res.first);
  }

  Future<int> salvar(Transacao t) async {
    final d = await db;
    return d.insert('transacoes', t.toMap());
  }

  Future<bool> atualizar(Transacao t) async {
    try {
      final d = await db;
      await d.update('transacoes', t.toMap(),
          where: 'id=?', whereArgs: [t.id]);
      return true;
    } catch (_) { return false; }
  }

  Future<bool> deletar(int id) async {
    try {
      final d = await db;
      await d.delete('transacoes', where: 'id=?', whereArgs: [id]);
      return true;
    } catch (_) { return false; }
  }

  // ─────────────────────────────────────────────
  //  SALDO
  // ─────────────────────────────────────────────

  Map<String, double> calcularSaldo(List<Transacao> lista) {
    double rec = 0, desp = 0;
    for (final t in lista) {
      if (t.tipo == 'Receita') rec  += t.valor;
      else                     desp += t.valor;
    }
    return {'receitas': rec, 'despesas': desp, 'saldo': rec - desp};
  }

  // ─────────────────────────────────────────────
  //  COMPARTILHAR / IMPORTAR .db
  // ─────────────────────────────────────────────

  /// Compartilha o arquivo financas.db via WhatsApp, e-mail, Drive, etc.
  Future<void> compartilharDb(BuildContext context) async {
    final dir    = await getApplicationDocumentsDirectory();
    final arquivo = File(p.join(dir.path, 'financas.db'));
    if (!await arquivo.exists()) return;
    await Share.shareXFiles(
      [XFile(arquivo.path)],
      subject: 'Gestor Financeiro — financas.db',
      text: 'Arquivo de dados do Gestor Financeiro',
    );
  }

  /// Importa um .db externo — substitui o banco atual
  Future<bool> importarDb(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return false;

      final origem = File(result.files.single.path!);
      final dir    = await getApplicationDocumentsDirectory();
      final destino = p.join(dir.path, 'financas.db');

      // Fecha o banco atual antes de substituir
      await _db?.close();
      _db = null;

      await origem.copy(destino);

      // Reabre o banco
      _db = await _inicializar();
      return true;
    } catch (e) {
      debugPrint('Erro ao importar: $e');
      return false;
    }
  }
}
