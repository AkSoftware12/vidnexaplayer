import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class VaultService {
  // ---------------- PIN STORE (simple demo) ----------------
  // NOTE: production me SharedPreferences / secure_storage use karo.
  Future<File> _pinFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'vault_pin.txt'));
  }

  Future<bool> hasPin() async {
    final f = await _pinFile();
    return f.exists();
  }

  Future<void> setPin(String pin) async {
    final f = await _pinFile();
    await f.writeAsString(pin);
  }

  Future<bool> verifyPin(String pin) async {
    final f = await _pinFile();
    if (!await f.exists()) return false;
    final saved = (await f.readAsString()).trim();
    return saved == pin.trim();
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
    final f = await _indexFile();
    final raw = await f.readAsString();
    final m = jsonDecode(raw);
    if (m is Map<String, dynamic>) return m;
    if (m is Map) return m.cast<String, dynamic>();
    return {};
  }

  Future<void> _writeIndex(Map<String, dynamic> data) async {
    final f = await _indexFile();
    await f.writeAsString(jsonEncode(data));
  }

  // ---------------- LIST ----------------
  Future<List<FileSystemEntity>> listVaultFiles() async {
    final v = await _vaultDir();
    final list = v
        .listSync()
        .where((e) => e is File)
        .toList();

    // hide index file
    list.removeWhere((e) => p.basename(e.path) == "vault_index.json");
    return list;
  }

  // ---------------- ADD ----------------
  Future<void> addToVault(File src) async {
    final v = await _vaultDir();
    final name = p.basename(src.path);

    final safeName = await _uniqueName(v.path, name);
    final dest = File(p.join(v.path, safeName));

    await src.copy(dest.path);

    final idx = await _readIndex();
    idx[safeName] = {
      "originalPath": src.path,
      "addedAt": DateTime.now().toIso8601String(),
    };
    await _writeIndex(idx);
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
  /// Restore vault file to originalPath if possible,
  /// else restore to selected folder (targetDir required).
  /// Returns restored path, or null if failed/cancelled.
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

    // try original path first
    if (originalPath != null && originalPath.trim().isNotEmpty) {
      destPath = originalPath.trim();
      final parent = Directory(p.dirname(destPath));
      if (!await parent.exists()) {
        // original folder missing -> fallback to targetDir
        if (targetDir == null) return null;
        destPath = p.join(targetDir.path, fileName);
      }
    } else {
      // no original info -> require targetDir
      if (targetDir == null) return null;
      destPath = p.join(targetDir.path, fileName);
    }

    var destFile = File(destPath);

    // if exists
    if (await destFile.exists()) {
      if (overwrite) {
        await destFile.delete();
      } else {
        final safe = await _uniqueName(destFile.parent.path, p.basename(destFile.path));
        destFile = File(p.join(destFile.parent.path, safe));
      }
    }

    // ensure parent exists
    if (!await destFile.parent.exists()) {
      await destFile.parent.create(recursive: true);
    }

    await vaultFile.copy(destFile.path);
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
