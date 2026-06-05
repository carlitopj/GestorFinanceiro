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
  String? _caminhoAtual; // Caminho do arquivo aberto

  static const List<String> categoriasPadrao = [
    'Alimentação', 'Transporte', 'Lazer', 'Saúde', 'Moradia', 'Outros'
  ];
  static const List<String> usuariosPadrao = ['Lidiane', 'Junior'];

  bool get arquivoAberto => _db != null;
  String? get caminhoAtual => _caminhoAtual;

  // ─────────────────────────────────────────────
  //  ABRIR / CRIAR / FECHAR
  // ─────────────────────────────────────────────

  /// Abre um arquivo .db existente via seletor de arquivos
  Future<bool> abrirArquivo(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return false;

      final caminho = result.files.single.path!;
      if (!caminho.endsWith('.db')) {
        return false;
      }

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

  /// Cria um novo arquivo .db na pasta Downloads
  Future<bool> novoArquivo() async {
    try {
      final dir = await getExternalStorageDirectory();
      final downloads = Directory('/storage/emulated/0/Download');
      final pasta = await downloads.exists() ? downloads : dir!;
      final caminho = p.join(pasta.path, 'carteira.db');

      await _db?.close();
      _db = null;
      _caminhoAtual = caminho;
      _db = await openDatabase(caminho, version: 1, onCreate: _criar);
      return true;
    } catch (e) {
      debugPrint('novoArquivo erro: $e');
      return false;
    }
  }

  /// Salva o arquivo atual em outro local via seletor
  Future<String?> salvarComo() async {
    try {
      if (_caminhoAtual == null) return null;

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Salvar carteira.db',
        fileName: 'carteira.db',
        type: FileType.any,
      );
      if (result == null) return null;

      // Copia o arquivo atual para o destino escolhido
      final origem  = File(_caminhoAtual!);
      await origem.copy(result);
      return result;
    } catch (e) {
      debugPrint('salvarComo erro: $e');
      return null;
    }
  }

  /// Salva no caminho atual (sobrescreve)
  Future<bool> salvar() async {
    try {
      if (_db == null || _caminhoAtual == null) return false;
      // SQLite já salva automaticamente — apenas confirma que o arquivo existe
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

  Future<Database> get db async {
    if (_db != null) return _db!;
    // Se não há arquivo aberto, cria um padrão
    await novoArquivo();
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