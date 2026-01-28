import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides a simple PIN-protected vault for hiding files within the
/// application.  Files added to the vault are copied into a hidden
/// directory within the application's documents directory.  A hashed
/// PIN is persisted using [SharedPreferences]; PIN creation and
/// verification are handled within this service.
class VaultService {
  static const _pinKey = 'vault_pin_hash';

  /// Ensures the vault directory exists and returns its path.
  Future<String> _vaultDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final v = Directory('${dir.path}/.vault');
    if (!v.existsSync()) v.createSync(recursive: true);
    return v.path;
  }

  /// Hashes a PIN using SHA-256.  Hashing ensures the PIN is never
  /// stored in plaintext on the device.
  String _hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

  /// Returns whether a PIN has already been set for the vault.
  Future<bool> hasPin() async {
    final sp = await SharedPreferences.getInstance();
    return (sp.getString(_pinKey) ?? '').isNotEmpty;
  }

  /// Saves a new [pin] for the vault.  The PIN is hashed before
  /// storage.
  Future<void> setPin(String pin) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_pinKey, _hashPin(pin));
  }

  /// Verifies whether [pin] matches the stored PIN hash.  Returns
  /// `true` if the PIN is correct, otherwise `false`.
  Future<bool> verifyPin(String pin) async {
    final sp = await SharedPreferences.getInstance();
    final saved = sp.getString(_pinKey) ?? '';
    return saved == _hashPin(pin);
  }

  /// Adds [file] into the vault by copying it into the vault directory.
  /// Returns the new file created within the vault.  Note that
  /// duplicate file names will overwrite existing files.
  Future<File> addToVault(File file) async {
    final vdir = await _vaultDir();
    final name = file.uri.pathSegments.last;
    final target = File('$vdir/$name');
    return file.copy(target.path);
  }

  /// Lists all files currently in the vault.  Returns only files, not
  /// directories.  Note that this does not require the vault to be
  /// unlocked; unlocking is handled externally.
  Future<List<FileSystemEntity>> listVaultFiles() async {
    final vdir = await _vaultDir();
    return Directory(vdir).listSync().where((e) => e is File).toList();
  }
}