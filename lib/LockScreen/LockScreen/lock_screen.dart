import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../service/vault_service.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

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
    final has = await vault.hasPin();
    if (!has) {
      await _setPinFlow();
    }
    setState(() => loading = false);
  }

  Future<void> _setPinFlow() async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GlassDialog(
        title: "Set Vault PIN",
        subtitle: "Create a 4–6 digit PIN to protect your files.",
        icon: Icons.shield_rounded,
        child: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            decoration: _inputDeco("Enter 4–6 digit PIN", Icons.password_rounded),
            validator: (v) {
              final t = (v ?? "").trim();
              if (t.length < 4) return "Minimum 4 digits required";
              if (t.length > 6) return "Maximum 6 digits allowed";
              return null;
            },
          ),
        ),
        primaryText: "Save PIN",
        onPrimary: () async {
          if (!(formKey.currentState?.validate() ?? false)) return;
          await vault.setPin(ctrl.text.trim());
          if (mounted) Navigator.pop(context);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("PIN set successfully")),
            );
          }
        },
        secondaryText: null,
        onSecondary: null,
      ),
    );
  }

  Future<void> _unlockFlow() async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _GlassDialog(
        title: "Unlock Vault",
        subtitle: "Enter your PIN to access secured files.",
        icon: Icons.lock_open_rounded,
        child: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            decoration: _inputDeco("Enter PIN", Icons.lock_rounded),
            validator: (v) {
              final t = (v ?? "").trim();
              if (t.isEmpty) return "PIN required";
              if (t.length < 4) return "Wrong PIN length";
              return null;
            },
          ),
        ),
        primaryText: "Unlock",
        onPrimary: () async {
          if (!(formKey.currentState?.validate() ?? false)) return;
          final v = await vault.verifyPin(ctrl.text.trim());
          if (!mounted) return;
          Navigator.pop(context, v);
        },
        secondaryText: "Cancel",
        onSecondary: () => Navigator.pop(context, false),
      ),
    );

    if (ok == true) {
      unlocked = true;
      await _refresh();
      if (mounted) setState(() {});
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Wrong PIN")),
        );
      }
    }
  }

  Future<void> _refresh() async {
    setState(() => busy = true);
    files = await vault.listVaultFiles();
    if (mounted) setState(() => busy = false);
  }

  Future<void> _addFile() async {
    final res = await FilePicker.platform.pickFiles();
    final path = res?.files.single.path;
    if (path == null) return;

    setState(() => busy = true);
    await vault.addToVault(File(path));
    await _refresh();
    if (mounted) setState(() => busy = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Added to vault")),
      );
    }
  }

  Future<void> _restoreFile(File vaultFile) async {
    if (busy) return;
    setState(() => busy = true);

    // 1) try restore to original
    String? restored = await vault.restoreFromVault(vaultFile: vaultFile);

    // 2) fallback: ask directory
    if (restored == null) {
      final dirPath = await FilePicker.platform.getDirectoryPath();
      if (dirPath != null) {
        restored = await vault.restoreFromVault(
          vaultFile: vaultFile,
          targetDir: Directory(dirPath),
        );
      }
    }

    if (!mounted) return;
    setState(() => busy = false);

    if (restored != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Restored to: $restored")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Restore cancelled / failed")),
      );
    }
  }

  Future<void> _deleteVaultFile(File vaultFile) async {
    if (busy) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete file?"),
        content: const Text("This will remove the file from vault."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => busy = true);
    await vault.deleteFromVault(vaultFile);
    await _refresh();
    if (!mounted) return;
    setState(() => busy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Deleted from vault")),
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
    if (lower.endsWith(".mp4") || lower.endsWith(".mkv") || lower.endsWith(".mov")) {
      return Icons.video_file_rounded;
    }
    if (lower.endsWith(".mp3") || lower.endsWith(".wav") || lower.endsWith(".aac")) {
      return Icons.audio_file_rounded;
    }
    if (lower.endsWith(".pdf")) return Icons.picture_as_pdf_rounded;
    if (lower.endsWith(".zip") || lower.endsWith(".rar")) return Icons.folder_zip_rounded;
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
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
                  title: "Vault",
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
              child: const _PillBadge(
                icon: Icons.sync_rounded,
                text: "Syncing…",
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
                  label: "Add File",
                  onTap: busy ? null : _addFile,
                ),
              ),
              const SizedBox(width: 10),
              _IconButtonGlass(
                icon: Icons.refresh_rounded,
                onTap: busy ? null : _refresh,
                tooltip: "Refresh",
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
      fillColor: Colors.white.withOpacity(0.95),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
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
                  unlocked ? "Secured files unlocked" : "Locked • Enter PIN to access",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
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
              tooltip: "Add",
              onTap: busy ? null : onAdd,
            ),
            const SizedBox(width: 8),
            _TopIcon(
              icon: Icons.refresh_rounded,
              tooltip: "Refresh",
              onTap: busy ? null : onRefresh,
            ),
          ] else ...[
            const _PillBadge(icon: Icons.lock_rounded, text: "Locked"),
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
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withOpacity(0.75)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
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
                      color: const Color(0xFF0A1AFF).withOpacity(0.10),
                    ),
                    child: const Icon(Icons.lock_rounded, color: Color(0xFF0A1AFF), size: 28),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Vault Locked",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Your files are protected with a PIN.\nUnlock to view and manage them.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.black.withOpacity(0.65),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: onUnlock,
                      icon: const Icon(Icons.lock_open_rounded),
                      label: const Text(
                        "Unlock Vault",
                        style: TextStyle(fontWeight: FontWeight.w700),
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
    if (files.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
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
                    color: Colors.black.withOpacity(0.04),
                  ),
                  child: const Icon(Icons.folder_off_rounded, size: 28),
                ),
                const SizedBox(height: 10),
                const Text(
                  "No files in vault",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  "Tap “Add File” to secure your photos, videos, PDFs, and more.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black.withOpacity(0.65), fontWeight: FontWeight.w500),
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
          border: Border.all(color: Colors.black.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ListView.separated(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          itemCount: files.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.black.withOpacity(0.06)),
          itemBuilder: (ctx, i) {
            final entity = files[i];
            final f = File(entity.path);
            final name = f.uri.pathSegments.isNotEmpty ? f.uri.pathSegments.last : f.path;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.black.withOpacity(0.04),
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
                style: TextStyle(color: Colors.black.withOpacity(0.55), fontWeight: FontWeight.w500),
              ),
              trailing: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: Colors.black.withOpacity(0.55)),
                onSelected: (v) async {
                  if (busy) return;
                  if (v == "restore") await onRestore(f);
                  if (v == "delete") await onDelete(f);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: "restore",
                    child: Row(
                      children: [
                        Icon(Icons.restore_rounded),
                        SizedBox(width: 10),
                        Text("Restore"),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: "delete",
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded),
                        SizedBox(width: 10),
                        Text("Delete from Vault"),
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
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
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
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
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

  const _PrimaryButton({required this.icon, required this.label, required this.onTap});

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
              ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade500])
              : const LinearGradient(
            colors: [Color(0xFF0A1AFF), Color(0xFF010071)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A1AFF).withOpacity(0.25),
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
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
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

  const _IconButtonGlass({required this.icon, required this.onTap, required this.tooltip});

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
                color: Colors.white.withOpacity(0.75),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
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
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.75)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
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
                        color: const Color(0xFF0A1AFF).withOpacity(0.10),
                      ),
                      child: Icon(icon, color: const Color(0xFF0A1AFF)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(color: Colors.black.withOpacity(0.60), fontWeight: FontWeight.w500),
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
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: BorderSide(color: Colors.black.withOpacity(0.10)),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(primaryText, style: const TextStyle(fontWeight: FontWeight.w900)),
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
