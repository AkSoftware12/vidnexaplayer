import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../NotifyListeners/LanguageProvider/profile_strings.dart';
import '../../Utils/app_palette.dart';
import '../service/vault_service.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

/// Distinguishes "wrong PIN" from "user cancelled" — the old flow treated a
/// dismissed dialog as a failed unlock and told the user their PIN was wrong.
enum _UnlockOutcome { success, wrongPin, cancelled }

class _VaultScreenState extends State<VaultScreen> {
  final vault = VaultService();

  bool unlocked = false;
  bool loading = true;
  bool busy = false;
  List<FileSystemEntity> files = [];

  // Theme-ish colors (premium vault)
  static const _c1 = Color(0xFF0A1AFF);
  static const _c2 = Color(0xFF010071);

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() => loading = true);
    try {
      final has = await vault.hasPin();
      if (!mounted) return;
      if (!has) {
        await _setPinFlow();
      }
    } catch (e) {
      debugPrint('Vault boot failed: $e');
    }
    if (!mounted) return;
    setState(() => loading = false);
  }

  /// First-run PIN setup.
  ///
  /// The dialog owns its TextEditingController (see [_PinEntryDialog]). It
  /// used to be created here and disposed right after `showDialog` returned,
  /// while the dialog's exit animation was still rebuilding the TextField —
  /// which threw "TextEditingController was used after being disposed" and
  /// replaced the field with a ~100000px error box (the RenderFlex overflow).
  Future<void> _setPinFlow() async {
    final lang = context.read<LocaleProvider>().locale.languageCode;
    String tr(String key) => ProfileStrings.t(lang, key);

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PinEntryDialog<bool>(
        title: tr('lock_set_pin_title'),
        subtitle: tr('lock_set_pin_sub'),
        icon: Icons.shield_rounded,
        primaryText: tr('lock_save_pin'),
        decoration:
        _inputDeco(tr('lock_enter_pin_hint'), Icons.password_rounded),
        validator: (v) {
          final t = (v ?? "").trim();
          if (t.length < 4) return tr('lock_min_digits');
          if (t.length > 6) return tr('lock_max_digits');
          return null;
        },
        onSubmit: (pin) async {
          await vault.setPin(pin);
          return true;
        },
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('lock_pin_set_success'))),
      );
    }
  }

  /// Wrong-PIN attempts since the last success, used for a simple lockout.
  int _failedAttempts = 0;
  DateTime? _lockedOutUntil;

  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 1);

  Future<void> _unlockFlow() async {
    final lang = context.read<LocaleProvider>().locale.languageCode;
    String tr(String key) => ProfileStrings.t(lang, key);

    final lockedUntil = _lockedOutUntil;
    if (lockedUntil != null && DateTime.now().isBefore(lockedUntil)) {
      final secs = lockedUntil.difference(DateTime.now()).inSeconds;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('lock_too_many_attempts').replaceAll('{secs}', '$secs'),
          ),
        ),
      );
      return;
    }

    final result = await showDialog<_UnlockOutcome>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _PinEntryDialog<_UnlockOutcome>(
        title: tr('lock_unlock_vault_title'),
        subtitle: tr('lock_unlock_vault_sub'),
        icon: Icons.lock_open_rounded,
        primaryText: tr('lock_unlock'),
        secondaryText: tr('lock_cancel'),
        cancelValue: _UnlockOutcome.cancelled,
        decoration: _inputDeco(tr('lock_enter_pin_short'), Icons.lock_rounded),
        validator: (v) {
          final t = (v ?? "").trim();
          if (t.isEmpty) return tr('lock_pin_required');
          if (t.length < 4) return tr('lock_wrong_pin_length');
          return null;
        },
        onSubmit: (pin) async => await vault.verifyPin(pin)
            ? _UnlockOutcome.success
            : _UnlockOutcome.wrongPin,
      ),
    );

    // `null` means the barrier was tapped / back was pressed.
    final outcome = result ?? _UnlockOutcome.cancelled;

    if (!mounted) return;

    switch (outcome) {
      case _UnlockOutcome.success:
        _failedAttempts = 0;
        _lockedOutUntil = null;
        unlocked = true;
        await _refresh();
        if (mounted) setState(() {});

      case _UnlockOutcome.wrongPin:
        _failedAttempts++;
        if (_failedAttempts >= _maxAttempts) {
          _lockedOutUntil = DateTime.now().add(_lockoutDuration);
          _failedAttempts = 0;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('lock_too_many_wrong'))),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('lock_wrong_pin'))),
          );
        }

      case _UnlockOutcome.cancelled:
      // Tapping outside or pressing Cancel is not a failed attempt — the old
      // code showed "Wrong PIN" for both.
        break;
    }
  }

  Future<void> _refresh() async {
    if (mounted) setState(() => busy = true);
    try {
      final list = await vault.listVaultFiles();
      if (!mounted) return;
      setState(() {
        files = list;
        busy = false;
      });
    } catch (e) {
      debugPrint('Vault listing failed: $e');
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _addFile() async {
    final res = await FilePicker.pickFiles();
    // `.single` throws if the platform ever hands back more (or fewer) than
    // exactly one file — some Android file providers do that even without
    // `allowMultiple` set. `.first` degrades gracefully instead of crashing.
    final path =
    (res != null && res.files.isNotEmpty) ? res.files.first.path : null;
    if (path == null || !mounted) return;

    setState(() => busy = true);

    final lang = context.read<LocaleProvider>().locale.languageCode;
    String message;
    try {
      final result = await vault.addToVault(File(path));
      message = result.originalRemoved
          ? ProfileStrings.t(lang, 'lock_moved_to_vault')
      // The file is hidden in the vault but the original could not be
      // deleted, so be honest that it is still in the gallery.
          : ProfileStrings.t(lang, 'lock_copied_to_vault');
    } catch (e) {
      message = ProfileStrings.t(lang, 'lock_could_not_add')
          .replaceAll('{error}', '$e');
    }

    await _refresh();
    if (!mounted) return;

    setState(() => busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restoreFile(File vaultFile) async {
    if (busy) return;
    setState(() => busy = true);

    // 1) try restore to original
    String? restored = await vault.restoreFromVault(vaultFile: vaultFile);

    // 2) fallback: ask directory
    if (restored == null) {
      final dirPath = await FilePicker.getDirectoryPath();
      if (dirPath != null) {
        restored = await vault.restoreFromVault(
          vaultFile: vaultFile,
          targetDir: Directory(dirPath),
        );
      }
    }

    if (!mounted) return;
    setState(() => busy = false);

    final lang = context.read<LocaleProvider>().locale.languageCode;
    if (restored != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ProfileStrings.t(lang, 'lock_restored_to')
                .replaceAll('{path}', restored),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(ProfileStrings.t(lang, 'lock_restore_cancelled'))),
      );
    }
  }

  Future<void> _deleteVaultFile(File vaultFile) async {
    if (busy) return;

    final lang = context.read<LocaleProvider>().locale.languageCode;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ProfileStrings.t(lang, 'lock_delete_file_title')),
        content: Text(ProfileStrings.t(lang, 'lock_delete_file_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(ProfileStrings.t(lang, 'lock_cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(ProfileStrings.t(lang, 'lock_delete')),
          ),
        ],
      ),
    );

    if (ok != true) return;
    if (!mounted) return;

    setState(() => busy = true);
    await vault.deleteFromVault(vaultFile);
    await _refresh();
    if (!mounted) return;
    setState(() => busy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ProfileStrings.t(lang, 'lock_deleted_from_vault'))),
    );
  }

  IconData _iconFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith(".jpg") ||
        lower.endsWith(".jpeg") ||
        lower.endsWith(".png") ||
        lower.endsWith(".webp")) {
      return Icons.image_rounded;
    }
    if (lower.endsWith(".mp4") ||
        lower.endsWith(".mkv") ||
        lower.endsWith(".mov")) {
      return Icons.video_file_rounded;
    }
    if (lower.endsWith(".mp3") ||
        lower.endsWith(".wav") ||
        lower.endsWith(".aac")) {
      return Icons.audio_file_rounded;
    }
    if (lower.endsWith(".pdf")) return Icons.picture_as_pdf_rounded;
    if (lower.endsWith(".zip") || lower.endsWith(".rar")) {
      return Icons.folder_zip_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final safeTop = MediaQuery.of(context).padding.top;
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    String t(String key) => ProfileStrings.t(lang, key);

    return Scaffold(
      backgroundColor: AppPalette.surface,
      body: Stack(
        children: [
          // Background gradient
          Container(
            height: 240 + safeTop,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_c1, _c2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                _VaultAppBar(
                  title: t('lock_vault_title'),
                  unlocked: unlocked,
                  busy: busy,
                  onAdd: unlocked ? _addFile : null,
                  onRefresh: unlocked ? _refresh : null,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : !unlocked
                        ? _LockedView(onUnlock: _unlockFlow)
                        : _UnlockedView(
                      files: files,
                      busy: busy,
                      iconFor: _iconFor,
                      onRestore: _restoreFile,
                      onDelete: _deleteVaultFile,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Small busy overlay
          if (busy && unlocked)
            Positioned(
              right: 16,
              top: safeTop + 70,
              child: _PillBadge(
                icon: Icons.sync_rounded,
                text: t('lock_syncing'),
              ),
            ),
        ],
      ),

      // Bottom actions
      bottomNavigationBar: unlocked
          ? SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: _PrimaryButton(
                  icon: Icons.add_rounded,
                  label: t('lock_add_file'),
                  onTap: busy ? null : _addFile,
                ),
              ),
              const SizedBox(width: 10),
              _IconButtonGlass(
                icon: Icons.refresh_rounded,
                onTap: busy ? null : _refresh,
                tooltip: t('lock_refresh'),
              ),
            ],
          ),
        ),
      )
          : null,
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppPalette.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppPalette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _c1, width: 1.4),
      ),
    );
  }
}

class _VaultAppBar extends StatelessWidget {
  final String title;
  final bool unlocked;
  final bool busy;
  final VoidCallback? onAdd;
  final VoidCallback? onRefresh;

  const _VaultAppBar({
    required this.title,
    required this.unlocked,
    required this.busy,
    this.onAdd,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    String t(String key) => ProfileStrings.t(lang, key);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unlocked
                      ? t('lock_secured_unlocked')
                      : t('lock_locked_enter_pin'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (unlocked) ...[
            _TopIcon(
              icon: Icons.add_rounded,
              tooltip: t('lock_add'),
              onTap: busy ? null : onAdd,
            ),
            const SizedBox(width: 8),
            _TopIcon(
              icon: Icons.refresh_rounded,
              tooltip: t('lock_refresh'),
              onTap: busy ? null : onRefresh,
            ),
          ] else ...[
            _PillBadge(icon: Icons.lock_rounded, text: t('lock_locked_badge')),
          ],
        ],
      ),
    );
  }
}

class _LockedView extends StatelessWidget {
  final VoidCallback onUnlock;
  const _LockedView({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    String t(String key) => ProfileStrings.t(lang, key);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppPalette.card.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppPalette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0A1AFF).withValues(alpha: 0.10),
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: Color(0xFF0A1AFF), size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t('lock_vault_locked_title'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t('lock_vault_locked_body'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppPalette.textB,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: onUnlock,
                      icon: const Icon(Icons.lock_open_rounded),
                      label: Text(
                        t('lock_unlock_vault_button'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnlockedView extends StatelessWidget {
  final List<FileSystemEntity> files;
  final bool busy;
  final IconData Function(String) iconFor;

  final Future<void> Function(File file) onRestore;
  final Future<void> Function(File file) onDelete;

  const _UnlockedView({
    required this.files,
    required this.busy,
    required this.iconFor,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    String t(String key) => ProfileStrings.t(lang, key);
    if (files.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppPalette.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppPalette.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppPalette.raised,
                  ),
                  child: const Icon(Icons.folder_off_rounded, size: 28),
                ),
                const SizedBox(height: 10),
                Text(
                  t('lock_no_files_title'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  t('lock_no_files_body'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppPalette.textB, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ListView.separated(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          itemCount: files.length,
          separatorBuilder: (_, __) => Divider(
              height: 1, color: Colors.black.withValues(alpha: 0.06)),
          itemBuilder: (ctx, i) {
            final entity = files[i];
            final f = File(entity.path);
            final name = f.uri.pathSegments.isNotEmpty
                ? f.uri.pathSegments.last
                : f.path;

            return ListTile(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.black.withValues(alpha: 0.04),
                ),
                child: Icon(iconFor(name)),
              ),
              title: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                f.path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w500),
              ),
              trailing: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    color: Colors.black.withValues(alpha: 0.55)),
                onSelected: (v) async {
                  if (busy) return;
                  if (v == "restore") await onRestore(f);
                  if (v == "delete") await onDelete(f);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: "restore",
                    child: Row(
                      children: [
                        const Icon(Icons.restore_rounded),
                        const SizedBox(width: 10),
                        Text(t('lock_restore')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: "delete",
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline_rounded),
                        const SizedBox(width: 10),
                        Text(t('lock_delete_from_vault')),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _TopIcon({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PillBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _PrimaryButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: onTap == null
              ? LinearGradient(
              colors: [Colors.grey.shade400, Colors.grey.shade500])
              : const LinearGradient(
            colors: [Color(0xFF0A1AFF), Color(0xFF010071)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A1AFF).withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconButtonGlass extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  const _IconButtonGlass(
      {required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 50,
              width: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(18),
                border:
                Border.all(color: Colors.black.withValues(alpha: 0.06)),
              ),
              child: Icon(icon),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final String? secondaryText;
  final VoidCallback? onSecondary;
  final String primaryText;
  final VoidCallback onPrimary;

  const _GlassDialog({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    required this.primaryText,
    required this.onPrimary,
    required this.secondaryText,
    required this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFF0A1AFF).withValues(alpha: 0.10),
                      ),
                      child: Icon(icon, color: const Color(0xFF0A1AFF)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.60),
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                child,
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (secondaryText != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onSecondary,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            side: BorderSide(
                                color: Colors.black.withValues(alpha: 0.10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            secondaryText!,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: onPrimary,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(primaryText,
                            style:
                            const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// PIN entry dialog that owns its own controller and form key.
///
/// The controller used to be created by the caller and disposed as soon as
/// `showDialog` returned — but the dialog's exit animation keeps rebuilding
/// the TextField for a few more frames, which threw "TextEditingController
/// was used after being disposed". Owning it here means it is disposed only
/// after the route (and its animation) is fully gone.
class _PinEntryDialog<T> extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String primaryText;
  final String? secondaryText;
  final T? cancelValue;
  final InputDecoration decoration;
  final String? Function(String?) validator;
  final Future<T> Function(String pin) onSubmit;

  const _PinEntryDialog({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryText,
    required this.decoration,
    required this.validator,
    required this.onSubmit,
    this.secondaryText,
    this.cancelValue,
  });

  @override
  State<_PinEntryDialog<T>> createState() => _PinEntryDialogState<T>();
}

class _PinEntryDialogState<T> extends State<_PinEntryDialog<T>> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  /// Guards against a double tap on the primary button running the PIN
  /// check (or the PIN save) twice.
  bool _submitting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _submitting = true;
    try {
      final value = await widget.onSubmit(_ctrl.text.trim());
      if (!mounted) return;
      Navigator.pop(context, value);
    } finally {
      _submitting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GlassDialog(
      title: widget.title,
      subtitle: widget.subtitle,
      icon: widget.icon,
      primaryText: widget.primaryText,
      onPrimary: _submit,
      secondaryText: widget.secondaryText,
      onSecondary: widget.secondaryText == null
          ? null
          : () => Navigator.pop(context, widget.cancelValue),
      child: Form(
        key: _formKey,
        child: TextFormField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          decoration: widget.decoration,
          validator: widget.validator,
        ),
      ),
    );
  }
}