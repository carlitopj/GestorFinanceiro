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

  // ID fixo da pasta compartilhada do dono
  static const _pastaCompartilhadaId = '1cz9LygQEFTfYdle09HWJ-OrYvDs0QJr3';

  String? _fileId;

  bool get isConnected => AuthService().isSignedIn;

  Future<drive.DriveApi?> _api() async {
    final client = await AuthService().getClient();
    return client != null ? drive.DriveApi(client) : null;
  }

  Future<String> get _localPath async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _fileName);
  }

  // ── Inicializa — busca o carteira.db na pasta compartilhada ──
  Future<bool> inicializar() async {
    try {
      final api = await _api();
      if (api == null) return false;
      _fileId = await _buscarArquivo(api);
      debugPrint('DriveService inicializado. fileId: $_fileId');
      return true;
    } catch (e) {
      debugPrint('DriveService.inicializar: $e');
      return false;
    }
  }

  Future<String?> _buscarArquivo(drive.DriveApi api) async {
    final res = await api.files.list(
      q: "name='$_fileName' and "
         "'$_pastaCompartilhadaId' in parents and "
         "trashed=false",
      spaces: 'drive',
      $fields: 'files(id)',
    );
    if (res.files != null && res.files!.isNotEmpty) {
      return res.files!.first.id;
    }
    return null;
  }

  // ── Download: pasta compartilhada → local ────────────────────
  Future<bool> download() async {
    if (_fileId == null) {
      debugPrint('Nenhum arquivo encontrado na pasta compartilhada.');
      return false;
    }
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

  // ── Upload: local → pasta compartilhada ──────────────────────
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
        // Cria o arquivo na pasta compartilhada
        final meta = drive.File()
          ..name    = _fileName
          ..parents = [_pastaCompartilhadaId];
        final criado = await api.files.create(meta, uploadMedia: media);
        _fileId = criado.id;
        debugPrint('Criado na pasta compartilhada: $_fileId');
      } else {
        // Atualiza o arquivo existente
        await api.files.update(
            drive.File(), _fileId!, uploadMedia: media);
        debugPrint('Atualizado na pasta compartilhada: $_fileId');
      }
      return true;
    } catch (e) {
      debugPrint('DriveService.upload: $e');
      return false;
    }
  }

  String get linkPasta =>
      'https://drive.google.com/drive/folders/$_pastaCompartilhadaId';
}