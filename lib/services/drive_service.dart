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

  static const _fileName   = 'carteira.db';
  static const _mimeType   = 'application/x-sqlite3';
  static const _fileIdFixo = '1KK_irgegsSfXtuknfRPZI3YA5fwDrao6';
  static const _pastaId    = '1cz9LygQEFTfYdle09HWJ-OrYvDs0QJr3';

  // E-mails que podem fazer upload
  static const _emailsProprietarios = [
    'carlitopj@gmail.com',
    'nutlidis@gmail.com',
  ];

  bool get isConnected => AuthService().isSignedIn;
  bool get isProprietario =>
      _emailsProprietarios.contains(AuthService().email);

  Future<drive.DriveApi?> _api() async {
    final client = await AuthService().getClient();
    return client != null ? drive.DriveApi(client) : null;
  }

  Future<String> get _localPath async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _fileName);
  }

  Future<bool> inicializar() async {
    final api = await _api();
    if (api == null) return false;
    debugPrint('DriveService OK. Proprietário: $isProprietario');
    return true;
  }

  // ── Download: qualquer usuário pode baixar ───────────────────
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
      debugPrint('Download OK');
      return true;
    } catch (e) {
      debugPrint('Download erro: $e');
      return false;
    }
  }

  // ── Upload: apenas o proprietário pode enviar ────────────────
  Future<bool> upload() async {
    if (!isProprietario) {
      debugPrint('Upload bloqueado: usuário não é proprietário');
      return false;
    }
    try {
      final api = await _api();
      if (api == null) return false;
      final arquivo = File(await _localPath);
      if (!await arquivo.exists()) return false;
      final bytes = await arquivo.readAsBytes();
      final media = drive.Media(
          Stream.value(bytes), bytes.length, contentType: _mimeType);
      await api.files.update(
          drive.File(), _fileIdFixo, uploadMedia: media);
      debugPrint('Upload OK');
      return true;
    } catch (e) {
      debugPrint('Upload erro: $e');
      return false;
    }
  }

  String get linkPasta =>
      'https://drive.google.com/drive/folders/$_pastaId';
}