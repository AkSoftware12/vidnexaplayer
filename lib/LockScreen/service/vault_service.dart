import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Result of adding a file to the vault.
class VaultAddResult {
  const VaultAddResult({required this.vaultPath, required this.originalRemoved});

  final String vaultPath;

  /// `false` when the copy succeeded but the original could not be deleted
  /// (e.g. scoped-storage restrictions) — the caller should tell the user the
  /// file is still visible in the gallery.
  final bool originalRemoved;
}

class VaultService {
  // ---------------- PIN STORE ----------------
  // The PIN is stored as a salted SHA-256 hash. The previous implementation
  // wrote the raw digits to `vault_pin.txt`, so anyone with file access (adb
  // backup, root, a file manager) could read it straight out.

  Future<File> _pinFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'vault_pin.json'));
  }

  /// Legacy plaintext file, migrated away from on first use.
  Future<File> _legacyPinFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'vault_pin.txt'));
  }

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt::${pin.trim()}')).toString();

  String _newSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  Future<bool> hasPin() async {
    if (await (await _pinFile()).exists()) return true;
    return (await _legacyPinFile()).exists();
  }

  Future<void> setPin(String pin) async {
    final salt = _newSalt();
    final f = await _pinFile();
    await f.writeAsString(jsonEncode({'salt': salt, 'hash': _hash(pin, salt)}));

    // Remove any leftover plaintext PIN.
    final legacy = await _legacyPinFile();
    if (await legacy.exists()) {
      try {
        await legacy.delete();
      } catch (_) {}
    }
  }

  Future<bool> verifyPin(String pin) async {
    final f = await _pinFile();

    if (await f.exists()) {
      try {
        final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        final salt = data['salt'] as String?;
        final hash = data['hash'] as String?;
        if (salt == null || hash == null) return false;
        return _hash(pin, salt) == hash;
      } catch (_) {
        return false;
      }
    }

    // One-time migration from the old plaintext file.
    final legacy = await _legacyPinFile();
    if (!await legacy.exists()) return false;

    final saved = (await legacy.readAsString()).trim();
    if (saved != pin.trim()) return false;

    await setPin(pin);
    return true;
  }

  // ---------------- VAULT FOLDER ----------------
  Future<Directory> _vaultDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final v = Directory(p.join(dir.path, "vault"));
    if (!await v.exists()) await v.create(recursive: true);
    return v;
  }

  Future<File> _indexFile() async {
    final v = await _vaultDir();
    final f = File(p.join(v.path, "vault_index.json"));
    if (!await f.exists()) {
      await f.writeAsString(jsonEncode({}));
    }
    return f;
  }

  Future<Map<String, dynamic>> _readIndex() async {
    try {
      final f = await _indexFile();
      final m = jsonDecode(await f.readAsString());
      if (m is Map<String, dynamic>) return m;
      if (m is Map) return m.cast<String, dynamic>();
    } catch (_) {
      // Corrupted index — start fresh rather than blocking the whole vault.
    }
    return {};
  }

  Future<void> _writeIndex(Map<String, dynamic> data) async {
    final f = await _indexFile();
    await f.writeAsString(jsonEncode(data));
  }

  // ---------------- LIST ----------------
  /// Async directory listing — `listSync()` blocked the UI thread on large
  /// vaults.
  Future<List<File>> listVaultFiles() async {
    final v = await _vaultDir();
    final entities = await v.list(followLinks: false).toList();

    return entities
        .whereType<File>()
        .where((f) => p.basename(f.path) != 'vault_index.json')
        .toList();
  }

  // ---------------- ADD ----------------
  /// Moves [src] into the vault.
  ///
  /// The old version only *copied*, leaving the original in place — so
  /// "hiding" a video left it fully visible in the gallery and doubled the
  /// storage it used.
  Future<VaultAddResult> addToVault(File src) async {
    final v = await _vaultDir();
    final name = p.basename(src.path);

    final safeName = await _uniqueName(v.path, name);
    final dest = File(p.join(v.path, safeName));

    await src.copy(dest.path);

    // Only delete the original once the copy is verifiably complete.
    var originalRemoved = false;
    try {
      final srcLen = await src.length();
      final destLen = await dest.length();
      if (srcLen == destLen) {
        await src.delete();
        originalRemoved = true;
      }
    } catch (_) {
      // Scoped storage may forbid deleting — surfaced via `originalRemoved`.
    }

    final idx = await _readIndex();
    idx[safeName] = {
      "originalPath": src.path,
      "addedAt": DateTime.now().toIso8601String(),
    };
    await _writeIndex(idx);

    return VaultAddResult(
      vaultPath: dest.path,
      originalRemoved: originalRemoved,
    );
  }

  Future<String> _uniqueName(String dir, String name) async {
    var candidate = name;
    var i = 1;
    while (await File(p.join(dir, candidate)).exists()) {
      final base = p.basenameWithoutExtension(name);
      final ext = p.extension(name);
      candidate = "${base}_$i$ext";
      i++;
    }
    return candidate;
  }

  // ---------------- RESTORE ----------------
  /// Moves a vault file back out to [originalPath] when possible, otherwise to
  /// [targetDir]. Returns the restored path, or null on failure.
  Future<String?> restoreFromVault({
    required File vaultFile,
    Directory? targetDir,
    bool overwrite = false,
  }) async {
    if (!await vaultFile.exists()) return null;

    final fileName = p.basename(vaultFile.path);
    final idx = await _readIndex();
    final meta = idx[fileName];

    String? originalPath;
    if (meta is Map) {
      originalPath = meta["originalPath"]?.toString();
    }

    String destPath;

    if (originalPath != null && originalPath.trim().isNotEmpty) {
      destPath = originalPath.trim();
      final parent = Directory(p.dirname(destPath));
      if (!await parent.exists()) {
        if (targetDir == null) return null;
        destPath = p.join(targetDir.path, fileName);
      }
    } else {
      if (targetDir == null) return null;
      destPath = p.join(targetDir.path, fileName);
    }

    var destFile = File(destPath);

    if (await destFile.exists()) {
      if (overwrite) {
        await destFile.delete();
      } else {
        final safe = await _uniqueName(
          destFile.parent.path,
          p.basename(destFile.path),
        );
        destFile = File(p.join(destFile.parent.path, safe));
      }
    }

    if (!await destFile.parent.exists()) {
      await destFile.parent.create(recursive: true);
    }

    await vaultFile.copy(destFile.path);

    // Remove the vault copy so restoring does not leave a duplicate behind.
    try {
      await vaultFile.delete();
      final index = await _readIndex();
      index.remove(fileName);
      await _writeIndex(index);
    } catch (_) {
      // Keep the restored file even if cleanup failed.
    }

    return destFile.path;
  }

  // ---------------- DELETE ----------------
  Future<void> deleteFromVault(File vaultFile) async {
    final fileName = p.basename(vaultFile.path);

    if (await vaultFile.exists()) {
      await vaultFile.delete();
    }

    final idx = await _readIndex();
    idx.remove(fileName);
    await _writeIndex(idx);
  }
}
