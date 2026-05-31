import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  GoogleSignInAccount? _user;
  AuthClient? _client;

  GoogleSignInAccount? get user => _user;
  bool get isSignedIn          => _user != null;
  String get displayName       => _user?.displayName ?? '';
  String get email             => _user?.email ?? '';

  Future<GoogleSignInAccount?> signIn() async {
    try {
      _user   = await _googleSignIn.signIn();
      _client = _user != null
          ? await _googleSignIn.authenticatedClient() : null;
      return _user;
    } catch (_) { return null; }
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      _user   = await _googleSignIn.signInSilently();
      _client = _user != null
          ? await _googleSignIn.authenticatedClient() : null;
      return _user;
    } catch (_) { return null; }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _user = null; _client = null;
  }

  Future<AuthClient?> getClient() async {
    if (_client != null) return _client;
    if (_user != null) {
      _client = await _googleSignIn.authenticatedClient();
    }
    return _client;
  }
}