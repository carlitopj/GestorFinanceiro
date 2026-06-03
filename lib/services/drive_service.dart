import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'auth_service.dart';

class DriveService {
  static final DriveService _instance = DriveService._internal();
  factory DriveService() => _instance;
  DriveService._internal();

  static const _fileName  = 'carteira.db';
  static const _mimeType  = 'application/x-sqlite3';

  // ID fixo do arquivo carteira.db — todos usam esse mesmo arquivo
  static const _fileIdFixo = '1KK_irgegsSfXtuknfRPZI3YA5fwDrao6';

  // ID fixo da pasta compartilhada
  static const _pastaId = '1cz9LygQEFTfYdle09HWJ-OrYvDs0QJr3';

  bool get isConnected => AuthService().isSignedIn;

  Future<drive.DriveApi?> _api() async {
    final client = await AuthService().getClient();
    return client != null ? drive.DriveApi(client) : null;
  }

  Future<String> get _localPath async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _fileName);
  }

  // Inicialização simples — o ID já é fixo, não precisa buscar
  Future<bool> inicializar() async {
    final api = await _api();
    if (api == null) return false;
    debugPrint('DriveService inicializado. fileId fixo: $_fileIdFixo');
    return true;
  }

  // ── Download: arquivo fixo → local ───────────────────────────
  Future<bool> download() async {
    try {
      final api = await _api();
      if (api == null) return false;
      final media = await api.files.get(
        _fileIdFixo,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      final bytes = <int>[];
      await media.stream.forEach(bytes.addAll);
      await File(await _localPath).writeAsBytes(bytes);
      debugPrint('Download OK: $_fileName');
      return true;
    } catch (e) {
      debugPrint('DriveService.download: $e');
      return false;
    }
  }

  // ── Upload: local → mesmo arquivo fixo no Drive ───────────────
  Future<bool> upload() async {
    try {
      final api    = await _api();
      if (api == null) return false;
      final arquivo = File(await _localPath);
      if (!await arquivo.exists()) return false;
      final bytes  = await arquivo.readAsBytes();
      final media  = drive.Media(
        Stream.value(bytes), bytes.length, contentType: _mimeType);

      // Sempre atualiza o arquivo fixo — nunca cria um novo
      await api.files.update(
          drive.File(), _fileIdFixo, uploadMedia: media);
      debugPrint('Atualizado arquivo fixo: $_fileIdFixo');
      return true;
    } catch (e) {
      debugPrint('DriveService.upload: $e');
      return false;
    }
  }

  String get linkPasta =>
      'https://drive.google.com/drive/folders/$_pastaId';
}