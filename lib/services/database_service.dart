import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/transacao.dart';
import 'drive_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  static const List<String> categoriasPadrao = [
    'Alimentação', 'Transporte', 'Lazer', 'Saúde', 'Moradia', 'Outros'
  ];
  static const List<String> usuariosPadrao = ['Lidiane', 'Junior'];

  Future<Database> get db async {
    _db ??= await _abrir();
    return _db!;
  }

  Future<Database> _abrir() async {
    final dir     = await getApplicationDocumentsDirectory();
    final caminho = p.join(dir.path, 'carteira.db');
    return openDatabase(caminho, version: 1, onCreate: _criar);
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

  /// Fecha e reabre o banco — necessário após download do Drive
  Future<void> reabrir() async {
    await _db?.close();
    _db = null;
    _db = await _abrir();
  }

  /// Sincroniza para o Drive após cada escrita
  Future<void> _sync() async {
    if (DriveService().isConnected) await DriveService().upload();
  }

  // ── Usuários ─────────────────────────────────────────────────

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
      await _sync();
      return true;
    } catch (_) { return false; }
  }

  Future<bool> excluirUsuario(String nome) async {
    try {
      final d = await db;
      await d.delete('usuarios',   where: 'nome=?',    whereArgs: [nome]);
      await d.delete('transacoes', where: 'usuario=?', whereArgs: [nome]);
      await _sync();
      return true;
    } catch (_) { return false; }
  }

  // ── Categorias ───────────────────────────────────────────────

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
      await _sync();
      return true;
    } catch (_) { return false; }
  }

  Future<bool> excluirCategoria(String nome) async {
    try {
      final d = await db;
      await d.delete('categorias', where: 'nome=?', whereArgs: [nome]);
      await _sync();
      return true;
    } catch (_) { return false; }
  }

  // ── Transações ───────────────────────────────────────────────

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

  Future<void> salvar(Transacao t) async {
    final d = await db;
    await d.insert('transacoes', t.toMap());
    await _sync();
  }

  Future<void> atualizar(Transacao t) async {
    final d = await db;
    await d.update('transacoes', t.toMap(),
        where: 'id=?', whereArgs: [t.id]);
    await _sync();
  }

  Future<void> deletar(int id) async {
    final d = await db;
    await d.delete('transacoes', where: 'id=?', whereArgs: [id]);
    await _sync();
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