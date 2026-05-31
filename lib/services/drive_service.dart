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
  static const _folderName = 'GestorFinanceiro';

  String? _fileId;
  String? _folderId;

  bool get isConnected => AuthService().isSignedIn;

  Future<drive.DriveApi?> _api() async {
    final client = await AuthService().getClient();
    return client != null ? drive.DriveApi(client) : null;
  }

  Future<String> get _localPath async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _fileName);
  }

  // ── Inicializa pasta e arquivo no Drive ──────────────────────
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
    final res = await api.files.list(
      q: "name='$_folderName' and "
         "mimeType='application/vnd.google-apps.folder' and "
         "trashed=false",
      spaces: 'drive', $fields: 'files(id)',
    );
    if (res.files != null && res.files!.isNotEmpty) {
      return res.files!.first.id!;
    }
    final pasta = drive.File()
      ..name     = _folderName
      ..mimeType = 'application/vnd.google-apps.folder';
    final criada = await api.files.create(pasta);
    return criada.id!;
  }

  Future<String?> _buscarArquivo(drive.DriveApi api) async {
    final res = await api.files.list(
      q: "name='$_fileName' and '$_folderId' in parents and trashed=false",
      spaces: 'drive', $fields: 'files(id)',
    );
    if (res.files != null && res.files!.isNotEmpty) {
      return res.files!.first.id;
    }
    return null;
  }

  // ── Download: Drive → local ──────────────────────────────────
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
      await File(await _localPath).writeAsBytes(bytes);
      debugPrint('Download OK: $_fileName');
      return true;
    } catch (e) {
      debugPrint('DriveService.download: $e');
      return false;
    }
  }

  // ── Upload: local → Drive ────────────────────────────────────
  Future<bool> upload() async {
    try {
      final api    = await _api();
      if (api == null) return false;
      final arquivo = File(await _localPath);
      if (!await arquivo.exists()) return false;
      final bytes  = await arquivo.readAsBytes();
      final media  = drive.Media(
        Stream.value(bytes), bytes.length, contentType: _mimeType);
      if (_fileId == null) {
        final meta = drive.File()
          ..name    = _fileName
          ..parents = [_folderId!];
        final criado = await api.files.create(meta, uploadMedia: media);
        _fileId = criado.id;
        debugPrint('Criado no Drive: $_fileId');
      } else {
        await api.files.update(
            drive.File(), _fileId!, uploadMedia: media);
        debugPrint('Atualizado no Drive: $_fileId');
      }
      return true;
    } catch (e) {
      debugPrint('DriveService.upload: $e');
      return false;
    }
  }

  String get linkPasta =>
      'https://drive.google.com/drive/folders/$_folderId';
}