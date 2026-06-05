import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Inicializa o banco abrindo automaticamente o último arquivo utilizado
  Future<Database> _initDatabase() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lastPath = prefs.getString('last_opened_db');

    String path;
    // Verifica se existe um histórico e se o arquivo realmente existe no celular
    if (lastPath != null && await File(lastPath).exists()) {
      path = lastPath;
    } else {
      // Se for a primeira vez ou o arquivo sumiu, cria no diretório interno seguro padrão
      var databasesPath = await getDatabasesPath();
      path = join(databasesPath, 'carteira.db');
      await prefs.setString('last_opened_db', path);
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // Substitua pela estrutura real das suas tabelas
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE movimentacoes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        descricao TEXT,
        valor REAL,
        tipo TEXT, -- 'receita' ou 'despesa'
        data TEXT
      )
    ''');
  }

  // FUNÇÃO SALVAR COMO: Cria uma cópia do banco atual na pasta escolhida pelo usuário
  Future<String?> salvarComo() async {
    // 1. Fecha o banco atual para garantir a integridade dos dados na cópia
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String currentPath = prefs.getString('last_opened_db') ?? join(await getDatabasesPath(), 'carteira.db');

    // 2. Abre o seletor para o usuário escolher onde salvar e com qual nome
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Salvar banco de dados como...',
      fileName: 'carteira.db',
      type: FileType.any,
    );

    if (outputFile != null) {
      File currentDbFile = File(currentPath);
      // Copia o arquivo atual para o novo destino
      await currentDbFile.copy(outputFile);
      
      // Define o novo caminho como o banco ativo do aplicativo
      await prefs.setString('last_opened_db', outputFile);
      
      // Reinicializa o banco no novo caminho
      await database;
      return outputFile;
    }

    // Se o usuário cancelou, reabre o banco no caminho antigo
    await database;
    return null;
  }

  // FUNÇÃO ABRIR: Seleciona um arquivo .db existente de qualquer pasta
  Future<bool> abrirArquivo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      String selectedPath = result.files.single.path!;

      // Fecha o banco de dados que estava ativo antes
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      // Salva a nova rota do arquivo no SharedPreferences para as próximas inicializações
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_opened_db', selectedPath);

      // Reabre o banco apontando para este arquivo importado
      await database;
      return true;
    }
    return false;
  }

  // Métodos de exemplo para testar se os dados estão persistindo de verdade
  Future<int> inserirMovimentacao(Map<String, dynamic> row) async {
    Database db = await database;
    return await db.insert('movimentacoes', row);
  }

  Future<List<Map<String, dynamic>>> listarMovimentacoes() async {
    Database db = await database;
    return await db.query('movimentacoes', orderBy: 'id DESC');
  }
}
