import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'auth_service.dart';

/// Gerencia upload e download do gestorfinanceiro.db no Google Drive.
class DriveService {
  static final DriveService _instance = DriveService._internal();
  factory DriveService() => _instance;
  DriveService._internal();

  static const _fileName  = 'gestorfinanceiro.db';
  static const _mimeType  = 'application/x-sqlite3';
  static const _folderName = 'GestorFinanceiro';

  String? _fileId;   // ID do .db no Drive
  String? _folderId; // ID da pasta no Drive

  String? get fileId => _fileId;

  // ─────────────────────────────────────────────
  //  API helper
  // ─────────────────────────────────────────────

  Future<drive.DriveApi?> _api() async {
    final client = await AuthService().getClient();
    return client != null ? drive.DriveApi(client) : null;
  }

  Future<String> get _localPath async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _fileName);
  }

  // ─────────────────────────────────────────────
  //  INICIALIZAÇÃO — busca ou cria pasta + arquivo
  // ─────────────────────────────────────────────

  Future<bool> inicializar() async {
    try {
      final api = await _api();
      if (api == null) return false;

      _folderId = await _buscarOuCriarPasta(api);
      _fileId   = await _buscarArquivo(api);
      return true;
    } catch (e) {
      debugPrint('DriveService.inicializar: $e');
      return false;
    }
  }

  Future<String> _buscarOuCriarPasta(drive.DriveApi api) async {
    // Procura pasta "GestorFinanceiro"
    final res = await api.files.list(
      q: "name='$_folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    if (res.files != null && res.files!.isNotEmpty) {
      return res.files!.first.id!;
    }
    // Cria a pasta
    final pasta = drive.File()
      ..name     = _folderName
      ..mimeType = 'application/vnd.google-apps.folder';
    final criada = await api.files.create(pasta);
    return criada.id!;
  }

  Future<String?> _buscarArquivo(drive.DriveApi api) async {
    final res = await api.files.list(
      q: "name='$_fileName' and '$_folderId' in parents and trashed=false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    if (res.files != null && res.files!.isNotEmpty) {
      return res.files!.first.id;
    }
    return null; // Ainda não existe — será criado no primeiro upload
  }

  // ─────────────────────────────────────────────
  //  DOWNLOAD — Drive → local
  // ─────────────────────────────────────────────

  /// Baixa o .db do Drive para o armazenamento local do app.
  /// Retorna false se o arquivo ainda não existe no Drive (primeiro uso).
  Future<bool> download() async {
    if (_fileId == null) return false;
    try {
      final api = await _api();
      if (api == null) return false;

      final media = await api.files.get(
        _fileId!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = <int>[];
      await media.stream.forEach(bytes.addAll);

      final caminho = await _localPath;
      await File(caminho).writeAsBytes(bytes);
      debugPrint('Download concluído: $caminho');
      return true;
    } catch (e) {
      debugPrint('DriveService.download: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  //  UPLOAD — local → Drive
  // ─────────────────────────────────────────────

  /// Envia o .db local para o Drive (cria ou atualiza).
  Future<bool> upload() async {
    try {
      final api    = await _api();
      if (api == null) return false;

      final caminho = await _localPath;
      final arquivo = File(caminho);
      if (!await arquivo.exists()) return false;

      final bytes  = await arquivo.readAsBytes();
      final stream = Stream.value(bytes);
      final media  = drive.Media(stream, bytes.length, contentType: _mimeType);

      if (_fileId == null) {
        // Primeiro upload — cria o arquivo na pasta
        final meta = drive.File()
          ..name    = _fileName
          ..parents = [_folderId!];
        final criado = await api.files.create(meta, uploadMedia: media);
        _fileId = criado.id;
        debugPrint('Arquivo criado no Drive: $_fileId');
      } else {
        // Atualiza o arquivo existente
        await api.files.update(drive.File(), _fileId!, uploadMedia: media);
        debugPrint('Arquivo atualizado no Drive: $_fileId');
      }
      return true;
    } catch (e) {
      debugPrint('DriveService.upload: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  //  LINK para compartilhar
  // ─────────────────────────────────────────────

  String get linkPasta =>
      'https://drive.google.com/drive/folders/$_folderId';

  /// Compartilha a pasta com outro e-mail (permissão de editor)
  Future<bool> compartilharCom(String email) async {
    try {
      final api = await _api();
      if (api == null || _folderId == null) return false;
      final perm = drive.Permission()
        ..type         = 'user'
        ..role         = 'writer'
        ..emailAddress = email;
      await api.permissions.create(perm, _folderId!,
          sendNotificationEmail: true);
      return true;
    } catch (e) {
      debugPrint('DriveService.compartilharCom: $e');
      return false;
    }
  }
}