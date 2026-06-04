import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
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

  // Chave da conta de serviço — injetada pelo workflow
  static const _serviceAccountJson = String.fromEnvironment(
      'SERVICE_ACCOUNT_JSON', defaultValue: '');

  bool get isConnected => AuthService().isSignedIn;

  Future<String> get _localPath async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _fileName);
  }

  // ── API com conta do usuário (para download) ─────────────────
  Future<drive.DriveApi?> _userApi() async {
    final client = await AuthService().getClient();
    return client != null ? drive.DriveApi(client) : null;
  }

  // ── API com conta de serviço (para upload) ───────────────────
  Future<drive.DriveApi?> _serviceApi() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/service_account.json');
      debugPrint('service_account.json tamanho: ${jsonStr.length}');
      debugPrint('service_account.json inicio: ${jsonStr.substring(0, jsonStr.length > 50 ? 50 : jsonStr.length)}');
      if (jsonStr.trim().isEmpty || jsonStr.trim() == '{}') {
        debugPrint('service_account.json vazio ou inválido');
        return null;
      }
      final credentials = ServiceAccountCredentials.fromJson(
          json.decode(jsonStr));
      final client = await clientViaServiceAccount(
          credentials, [drive.DriveApi.driveFileScope]);
      return drive.DriveApi(client);
    } catch (e) {
      debugPrint('_serviceApi erro: $e');
      return null;
    }
  }

  Future<bool> inicializar() async {
    final api = await _userApi();
    if (api == null) return false;
    debugPrint('DriveService inicializado. fileId: $_fileIdFixo');
    return true;
  }

  // ── Download: usa conta do usuário ───────────────────────────
  Future<bool> download() async {
    try {
      final api = await _userApi();
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

  // ── Upload: usa conta de serviço ─────────────────────────────
  Future<bool> upload() async {
    try {
      final api = await _serviceApi();
      if (api == null) {
        debugPrint('Upload: conta de serviço não disponível');
        return false;
      }
      final arquivo = File(await _localPath);
      if (!await arquivo.exists()) return false;
      final bytes = await arquivo.readAsBytes();
      final media = drive.Media(
          Stream.value(bytes), bytes.length, contentType: _mimeType);
      await api.files.update(
          drive.File(), _fileIdFixo, uploadMedia: media);
      debugPrint('Upload OK via conta de serviço');
      return true;
    } catch (e) {
      debugPrint('Upload erro: $e');
      return false;
    }
  }

  String get linkPasta =>
      'https://drive.google.com/drive/folders/$_pastaId';
}