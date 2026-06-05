import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/transacao.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;
  String? _caminhoAtual;

  static const List<String> categoriasPadrao = [
    'Alimentação', 'Transporte', 'Lazer', 'Saúde', 'Moradia', 'Outros'
  ];
  static const List<String> usuariosPadrao = ['Lidiane', 'Junior'];

  bool get arquivoAberto => _db != null;
  String? get caminhoAtual => _caminhoAtual;

  // ─────────────────────────────────────────────
  //  ABRIR / CRIAR / FECHAR
  // ─────────────────────────────────────────────

  /// Inicializa o banco na pasta de dados do app (invisível ao usuário).
  /// Usado apenas internamente como fallback — o usuário usa Abrir/SalvarComo.
  Future<void> _inicializarInterno() async {
    final dir    = await getApplicationDocumentsDirectory();
    final caminho = p.join(dir.path, 'carteira_interna.db');

    _caminhoAtual = caminho;
    _db = await openDatabase(caminho, version: 1, onCreate: _criar);
  }

  /// Abre um arquivo .db existente via seletor de arquivos
  Future<bool> abrirArquivo(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return false;

      final caminho = result.files.single.path!;
      if (!caminho.endsWith('.db')) return false;

      await _db?.close();
      _db = null;
      _caminhoAtual = caminho;
      _db = await openDatabase(caminho, version: 1, onCreate: _criar);
      return true;
    } catch (e) {
      debugPrint('abrirArquivo erro: $e');
      return false;
    }
  }

  /// Faz o checkpoint do WAL e copia o banco para Downloads com o nome escolhido.
  /// Retorna o caminho de destino ou null em caso de cancelamento/erro.
  Future<String?> salvarComo() async {
    try {
      if (_db == null || _caminhoAtual == null) return null;

      // 1. Força o SQLite a gravar tudo no arquivo principal (sai do modo WAL)
      await _db!.execute('PRAGMA wal_checkpoint(TRUNCATE)');

      // 2. Monta destino na pasta Downloads (sempre acessível sem permissão extra)
      final downloads = Directory('/storage/emulated/0/Download');
      final pastaBase = await downloads.exists()
          ? downloads
          : await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();

      // Garante que o destino tenha extensão .db
      final destino = p.join(pastaBase.path, 'carteira.db');

      // 3. Copia o arquivo atual (já com dados) para o destino
      await File(_caminhoAtual!).copy(destino);

      return destino;
    } catch (e) {
      debugPrint('salvarComo erro: $e');
      return null;
    }
  }

  /// Confirma que o banco está salvo (SQLite é transacional, sempre salva).
  Future<bool> salvar() async {
    try {
      if (_db == null || _caminhoAtual == null) return false;
      await _db!.execute('PRAGMA wal_checkpoint(TRUNCATE)');
      return await File(_caminhoAtual!).exists();
    } catch (e) {
      return false;
    }
  }

  /// Fecha o arquivo atual
  Future<void> fechar() async {
    await _db?.close();
    _db = null;
    _caminhoAtual = null;
  }

  Future<void> _criar(Database db, int _) async {
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
    await db.execute('CREATE TABLE usuarios   (nome TEXT UNIQUE)');
    await db.execute('CREATE TABLE categorias (nome TEXT UNIQUE)');
    for (final u in usuariosPadrao) {
      await db.insert('usuarios', {'nome': u},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    for (final c in categoriasPadrao) {
      await db.insert('categorias', {'nome': c},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  /// Getter do banco: usa o banco já aberto ou inicializa o interno como fallback.
  Future<Database> get db async {
    if (_db != null) return _db!;
    await _inicializarInterno();
    return _db!;
  }

  // ─────────────────────────────────────────────
  //  USUÁRIOS
  // ─────────────────────────────────────────────

  Future<List<String>> buscarUsuarios() async {
    final d = await db;
    return (await d.query('usuarios'))
        .map((r) => r['nome'] as String).toList();
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
      await d.delete('usuarios',   where: 'nome=?',    whereArgs: [nome]);
      await d.delete('transacoes', where: 'usuario=?', whereArgs: [nome]);
      return true;
    } catch (_) { return false; }
  }

  // ─────────────────────────────────────────────
  //  CATEGORIAS
  // ─────────────────────────────────────────────

  Future<List<String>> buscarCategorias() async {
    final d = await db;
    return (await d.query('categorias', orderBy: 'nome ASC'))
        .map((r) => r['nome'] as String).toList();
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
    return (await d.query('transacoes',
        where: 'usuario=? AND mes_ref=?',
        whereArgs: [usuario, mesRef]))
        .map(Transacao.fromMap).toList();
  }

  Future<List<Transacao>> buscarTodas(String usuario) async {
    final d = await db;
    return (await d.query('transacoes',
        where: 'usuario=?', whereArgs: [usuario], orderBy: 'id ASC'))
        .map(Transacao.fromMap).toList();
  }

  Future<Transacao?> buscarPorDescricaoEMes(
      String usuario, String desc, String mesRef) async {
    final d   = await db;
    final res = await d.query('transacoes',
        where: 'usuario=? AND descricao=? AND mes_ref=?',
        whereArgs: [usuario, desc, mesRef]);
    return res.isEmpty ? null : Transacao.fromMap(res.first);
  }

  Future<void> salvarTransacao(Transacao t) async {
    final d = await db;
    await d.insert('transacoes', t.toMap());
  }

  Future<void> atualizarTransacao(Transacao t) async {
    final d = await db;
    await d.update('transacoes', t.toMap(),
        where: 'id=?', whereArgs: [t.id]);
  }

  Future<void> deletarTransacao(int id) async {
    final d = await db;
    await d.delete('transacoes', where: 'id=?', whereArgs: [id]);
  }

  Map<String, double> calcularSaldo(List<Transacao> lista) {
    double rec = 0, desp = 0;
    for (final t in lista) {
      if (t.tipo == 'Receita') rec  += t.valor;
      else                     desp += t.valor;
    }
    return {'receitas': rec, 'despesas': desp, 'saldo': rec - desp};
  }
}
