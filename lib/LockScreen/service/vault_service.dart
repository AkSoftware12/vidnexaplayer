import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:docman/docman.dart';
import 'package:file_picker/file_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../DirectoryFolder/media_store/media_store.dart';

/// What a vault entry is, which decides how it is previewed, opened and put
/// back.
enum VaultKind { image, video, audio, document }

/// One hidden file.
class VaultItem {
  const VaultItem({
    required this.file,
    required this.kind,
    required this.addedAt,
    this.thumb,
    this.duration,
    this.relativePath,
  });

  final File file;
  final VaultKind kind;
  final DateTime addedAt;

  /// Small JPEG saved when the item was hidden. Null for documents, and for
  /// items hidden before thumbnails existed.
  final File? thumb;

  /// Videos only.
  final Duration? duration;

  /// Gallery folder the item came from (`DCIM/Camera/`), so a restore puts it
  /// back where it was.
  final String? relativePath;

  String get name => p.basename(file.path);
}

/// Outcome of hiding a batch.
class VaultHideResult {
  const VaultHideResult({required this.hidden, required this.notRemoved});

  /// Moved into the vault and gone from where they were.
  final int hidden;

  /// Copied, but the original could not be deleted (the user refused the
  /// system prompt, or the provider does not allow it). Those copies are
  /// taken back out of the vault, so nothing ends up in two places.
  final int notRemoved;
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

  /// How many digits the PIN has, so the keypad can check it the moment that
  /// many are typed — and say "wrong" right then — instead of waiting for six.
  /// Null for a PIN saved before the length was stored.
  Future<int?> pinLength() async {
    try {
      final f = await _pinFile();
      if (!await f.exists()) return null;
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return (data['len'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  Future<void> setPin(String pin) async {
    final salt = _newSalt();
    final f = await _pinFile();
    await f.writeAsString(jsonEncode({
      'salt': salt,
      'hash': _hash(pin, salt),
      'len': pin.trim().length,
    }));

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

  // ---------------- BIOMETRIC UNLOCK ----------------
  // Opt-in, and only ever a shortcut: the PIN stays the key and is always
  // offered when the fingerprint/face check fails or is cancelled. Android
  // runs the check itself and hands back only yes/no — nothing biometric is
  // stored here, just whether the user switched the shortcut on.

  final LocalAuthentication _auth = LocalAuthentication();

  static const String _prefsBiometricKey = 'vault_biometric_enabled';

  /// Whether this device has a fingerprint/face sensor with something enrolled.
  Future<bool> biometricAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> biometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsBiometricKey) ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsBiometricKey, enabled);
  }

  /// Shows the system fingerprint/face prompt. `false` on failure, cancel, or
  /// any error, so the caller falls back to the PIN.
  Future<bool> authenticateBiometric(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }

  // ---------------- VAULT FOLDER ----------------
  // Both folders live in the app's private documents directory: no other app,
  // the gallery or a file manager can see inside without root.

  Future<Directory> _vaultDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final v = Directory(p.join(dir.path, 'vault'));
    if (!await v.exists()) await v.create(recursive: true);
    return v;
  }

  /// Thumbnails sit beside the vault rather than in it, so a listing of the
  /// vault is exactly the hidden files.
  Future<Directory> _thumbDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final t = Directory(p.join(dir.path, 'vault_thumbs'));
    if (!await t.exists()) await t.create(recursive: true);
    return t;
  }

  Future<File> _thumbFor(String name) async =>
      File(p.join((await _thumbDir()).path, '$name.jpg'));

  Future<File> _indexFile() async {
    final v = await _vaultDir();
    final f = File(p.join(v.path, 'vault_index.json'));
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
  /// Every hidden file, newest first.
  ///
  /// Items hidden by the old version have no `kind` in the index; theirs is
  /// worked out from the extension.
  Future<List<VaultItem>> listItems() async {
    final v = await _vaultDir();
    final idx = await _readIndex();
    final entities = await v.list(followLinks: false).toList();

    final items = <VaultItem>[];
    for (final f in entities.whereType<File>()) {
      final name = p.basename(f.path);
      if (name == 'vault_index.json') continue;

      final meta = idx[name] is Map ? (idx[name] as Map) : const {};
      final kind = _kindFrom(meta['kind']?.toString()) ?? kindOf(name);
      final thumb = await _thumbFor(name);
      final seconds = (meta['durationSec'] as num?)?.toInt();

      items.add(VaultItem(
        file: f,
        kind: kind,
        addedAt: DateTime.tryParse(meta['addedAt']?.toString() ?? '') ??
            (await f.lastModified()),
        thumb: await thumb.exists() ? thumb : null,
        duration: seconds == null ? null : Duration(seconds: seconds),
        relativePath: meta['relativePath']?.toString(),
      ));
    }

    items.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return items;
  }

  static VaultKind? _kindFrom(String? s) =>
      VaultKind.values.where((k) => k.name == s).firstOrNull;

  static VaultKind kindOf(String name) {
    final ext = p.extension(name).toLowerCase().replaceFirst('.', '');
    const images = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif', 'bmp'};
    const videos = {'mp4', 'mkv', 'mov', 'avi', '3gp', 'webm', 'm4v', 'ts'};
    const audio = {'mp3', 'wav', 'aac', 'm4a', 'ogg', 'opus', 'flac', 'amr'};
    if (images.contains(ext)) return VaultKind.image;
    if (videos.contains(ext)) return VaultKind.video;
    if (audio.contains(ext)) return VaultKind.audio;
    return VaultKind.document;
  }

  // ---------------- HIDE ----------------
  /// Hides gallery items.
  ///
  /// Copies every asset in, then asks Android to delete the originals in one
  /// go — on Android 11+ that is the system "Allow … to delete?" prompt, which
  /// is the only way an app without All-files access may remove another app's
  /// media. Anything the user does not let go of is taken back out of the
  /// vault: a "hidden" photo still sitting in the gallery is worse than no
  /// change at all.
  Future<VaultHideResult> hideAssets(
    List<AssetEntity> assets, {
    void Function(int done, int total)? onProgress,
  }) async {
    final copied = <String, String>{}; // asset id -> vault file name

    for (var i = 0; i < assets.length; i++) {
      final asset = assets[i];
      try {
        final name = await _copyAsset(asset);
        if (name != null) copied[asset.id] = name;
      } catch (_) {
        // Skip this one; the rest still go in.
      }
      onProgress?.call(i + 1, assets.length);
    }

    if (copied.isEmpty) {
      return VaultHideResult(hidden: 0, notRemoved: assets.length);
    }

    List<String> deleted;
    try {
      deleted = await PhotoManager.editor.deleteWithIds(copied.keys.toList());
    } catch (_) {
      deleted = const [];
    }

    final kept = copied.keys.where((id) => !deleted.contains(id)).toList();
    for (final id in kept) {
      await _removeFromVault(copied[id]!);
    }

    return VaultHideResult(
      hidden: copied.length - kept.length,
      notRemoved: assets.length - (copied.length - kept.length),
    );
  }

  Future<String?> _copyAsset(AssetEntity asset) async {
    final src = await asset.originFile ?? await asset.file;
    if (src == null) return null;

    final v = await _vaultDir();
    final original = asset.title?.isNotEmpty == true
        ? asset.title!
        : p.basename(src.path);
    final name = await _uniqueName(v.path, original);
    final dest = File(p.join(v.path, name));
    await src.copy(dest.path);

    if (await dest.length() != await src.length()) {
      await dest.delete();
      return null;
    }

    // The thumbnail is taken now, from the gallery's own cache — once the
    // original is gone there is nothing to ask for one.
    try {
      final Uint8List? bytes = await asset.thumbnailDataWithSize(
        const ThumbnailSize.square(320),
        quality: 85,
      );
      if (bytes != null) await (await _thumbFor(name)).writeAsBytes(bytes);
    } catch (_) {}

    final idx = await _readIndex();
    idx[name] = {
      'kind': asset.type == AssetType.video ? 'video' : 'image',
      'relativePath': asset.relativePath,
      'durationSec': asset.type == AssetType.video ? asset.duration : null,
      'addedAt': DateTime.now().toIso8601String(),
    };
    await _writeIndex(idx);
    return name;
  }

  /// Hides documents picked through the system picker.
  ///
  /// The provider decides whether a picked document may be deleted; when it
  /// may not, the copy is taken back out, as for gallery items.
  Future<VaultHideResult> hideDocuments(
    List<DocumentFile> docs, {
    void Function(int done, int total)? onProgress,
  }) async {
    var hidden = 0;
    for (var i = 0; i < docs.length; i++) {
      final doc = docs[i];
      try {
        final name = await _copyDocument(doc);
        if (name != null) {
          final removed = doc.canDelete && await doc.delete();
          if (removed) {
            hidden++;
          } else {
            await _removeFromVault(name);
          }
        }
      } catch (_) {}
      onProgress?.call(i + 1, docs.length);
    }
    return VaultHideResult(hidden: hidden, notRemoved: docs.length - hidden);
  }

  Future<String?> _copyDocument(DocumentFile doc) async {
    // Streamed to a cache file by the platform rather than read into memory,
    // so a large PDF does not have to fit in the heap.
    final cached = await doc.cache();
    if (cached == null) return null;

    final v = await _vaultDir();
    final name = await _uniqueName(v.path, doc.name);
    final dest = File(p.join(v.path, name));
    try {
      await cached.rename(dest.path);
    } catch (_) {
      await cached.copy(dest.path);
      await cached.delete();
    }

    final idx = await _readIndex();
    idx[name] = {
      'kind': kindOf(name).name,
      'addedAt': DateTime.now().toIso8601String(),
    };
    await _writeIndex(idx);
    return name;
  }

  Future<String> _uniqueName(String dir, String name) async {
    var candidate = name;
    var i = 1;
    while (await File(p.join(dir, candidate)).exists()) {
      final base = p.basenameWithoutExtension(name);
      final ext = p.extension(name);
      candidate = '${base}_$i$ext';
      i++;
    }
    return candidate;
  }

  // ---------------- RESTORE ----------------
  /// Puts an item back, with no questions asked. Photos and videos go into
  /// the gallery, into the folder they came from when Android allows it;
  /// documents go to Download/Vidnexa/ and audio to Music/Vidnexa/. Only if
  /// that fails (Android 9 and older without the storage grant) is the user
  /// asked where to save. True once it is out and gone from the vault.
  Future<bool> restore(VaultItem item) async {
    final saved = switch (item.kind) {
      VaultKind.image => await _restoreMedia(item, video: false),
      VaultKind.video => await _restoreMedia(item, video: true),
      _ => await MediaStoreRepo.instance
                  .saveToShared(item.file.path, item.name) !=
              null ||
          await _restoreToPickedLocation(item),
    };
    if (saved) await _removeFromVault(item.name);
    return saved;
  }

  Future<bool> _restoreMedia(VaultItem item, {required bool video}) async {
    final fallback = video ? 'Movies/Vidnexa/' : 'Pictures/Vidnexa/';
    // The original folder first; Android refuses some (another app's
    // Android/media/… folder), so the app's own folder is the fallback.
    for (final folder in {item.relativePath, fallback}) {
      if (folder == null || folder.isEmpty) continue;
      try {
        if (video) {
          await PhotoManager.editor.saveVideo(
            item.file,
            title: item.name,
            relativePath: folder,
          );
        } else {
          await PhotoManager.editor.saveImageWithPath(
            item.file.path,
            title: item.name,
            relativePath: folder,
          );
        }
        return true;
      } catch (_) {}
    }
    return false;
  }

  Future<bool> _restoreToPickedLocation(VaultItem item) async {
    try {
      final path = await FilePicker.saveFile(
        fileName: item.name,
        bytes: await item.file.readAsBytes(),
      );
      return path != null;
    } catch (_) {
      return false;
    }
  }

  // ---------------- REMOVE ----------------
  // Internal only. The vault deliberately has no "delete" for the user: an
  // item leaves it by being unhidden, never by being destroyed.
  Future<void> _removeFromVault(String name) async {
    final v = await _vaultDir();
    final f = File(p.join(v.path, name));
    if (await f.exists()) await f.delete();

    final thumb = await _thumbFor(name);
    if (await thumb.exists()) await thumb.delete();

    final idx = await _readIndex();
    idx.remove(name);
    await _writeIndex(idx);
  }
}
