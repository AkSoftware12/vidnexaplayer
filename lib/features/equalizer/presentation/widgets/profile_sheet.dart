import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../NotifyListeners/LanguageProvider/equalizer_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../audio_effects_service.dart';
import '../../domain/eq_models.dart';
import '../../domain/eq_profile.dart';

/// Localised lookup for this sheet. Watches the locale so the whole sheet
/// re-renders when the app language changes.
String _t(BuildContext context, String key) =>
    EqStrings.t(context.watch<LocaleProvider>().locale.languageCode, key);

/// Same, for event handlers where watching would assert.
String _tOnce(BuildContext context, String key) => EqStrings.t(
      Provider.of<LocaleProvider>(context, listen: false).locale.languageCode,
      key,
    );

/// Manage saved profiles: apply, rename, duplicate, delete, set as default,
/// bind to an output route, and share/import as JSON.
class EqProfileSheet extends StatelessWidget {
  const EqProfileSheet({
    super.key,
    required this.accent,
    required this.surface,
    required this.card,
    required this.textColor,
    required this.subtleColor,
  });

  final Color accent;
  final Color surface;
  final Color card;
  final Color textColor;
  final Color subtleColor;

  static Future<void> show(
    BuildContext context, {
    required Color accent,
    required Color surface,
    required Color card,
    required Color textColor,
    required Color subtleColor,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EqProfileSheet(
        accent: accent,
        surface: surface,
        card: card,
        textColor: textColor,
        subtleColor: subtleColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AudioEffectsService>();
    final profiles = service.profiles;
    final bindings = service.deviceBindings();

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: subtleColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 6),
              child: Row(
                children: [
                  Icon(Icons.bookmarks_rounded, size: 18, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _t(context, 'eq_my_profiles'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _t(context, 'eq_profiles_import'),
                    icon: Icon(Icons.download_rounded,
                        size: 20, color: subtleColor),
                    onPressed: () => _import(context, service),
                  ),
                ],
              ),
            ),
            Expanded(
              child: profiles.isEmpty
                  ? _empty(context)
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                      itemCount: profiles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _ProfileTile(
                        profile: profiles[i],
                        isDefault: service.defaultProfileId == profiles[i].id,
                        isActive: service.settings.presetId == profiles[i].id,
                        boundDevices: [
                          for (final e in bindings.entries)
                            if (e.value == profiles[i].id) e.key,
                        ],
                        accent: accent,
                        card: card,
                        textColor: textColor,
                        subtleColor: subtleColor,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_border_rounded, size: 40, color: subtleColor),
              const SizedBox(height: 12),
              Text(
                _t(context, 'eq_profiles_empty_title'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _t(context, 'eq_profiles_empty_sub'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.5, color: subtleColor),
              ),
            ],
          ),
        ),
      );

  Future<void> _import(
      BuildContext context, AudioEffectsService service) async {
    final messenger = ScaffoldMessenger.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(_tOnce(context, 'eq_profiles_clipboard_empty'))),
      );
      return;
    }
    final imported = await service.importProfile(text);
    messenger.showSnackBar(
      SnackBar(
        content: Text(imported == null
            ? _tOnce(context, 'eq_profiles_import_failed')
            : '${_tOnce(context, 'eq_profiles_imported')} "${imported.name}"'),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.isDefault,
    required this.isActive,
    required this.boundDevices,
    required this.accent,
    required this.card,
    required this.textColor,
    required this.subtleColor,
  });

  final EqProfile profile;
  final bool isDefault;
  final bool isActive;
  final List<OutputDevice> boundDevices;
  final Color accent;
  final Color card;
  final Color textColor;
  final Color subtleColor;

  @override
  Widget build(BuildContext context) {
    final service = context.read<AudioEffectsService>();

    return Material(
      color: card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => service.applyProfile(profile),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? accent
                  : subtleColor.withValues(alpha: 0.18),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDefault ? Icons.star_rounded : Icons.graphic_eq_rounded,
                  size: 17,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _summary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: subtleColor),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 19, color: subtleColor),
                onSelected: (value) => _onAction(context, service, value),
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'apply',
                      child: Text(_t(context, 'eq_menu_apply'))),
                  PopupMenuItem(
                      value: 'overwrite',
                      child: Text(_t(context, 'eq_menu_overwrite'))),
                  PopupMenuItem(
                      value: 'rename',
                      child: Text(_t(context, 'eq_menu_rename'))),
                  PopupMenuItem(
                      value: 'duplicate',
                      child: Text(_t(context, 'eq_menu_duplicate'))),
                  PopupMenuItem(
                    value: 'default',
                    child: Text(_t(context,
                        isDefault ? 'eq_menu_clear_default' : 'eq_menu_set_default')),
                  ),
                  PopupMenuItem(
                      value: 'device',
                      child: Text(_t(context, 'eq_menu_auto_apply'))),
                  PopupMenuItem(
                      value: 'export',
                      child: Text(_t(context, 'eq_menu_share'))),
                  PopupMenuItem(
                      value: 'delete',
                      child: Text(_t(context, 'eq_menu_delete'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _summary(BuildContext context) {
    final parts = <String>[];
    if (boundDevices.isNotEmpty) {
      parts.add(boundDevices.map((d) => _t(context, d.labelKey)).join(', '));
    }
    if (isDefault) parts.add(_t(context, 'eq_default'));
    final s = profile.settings;
    if (s.bassBoost > 0) {
      parts.add('${_t(context, 'eq_bass_short')} ${(s.bassBoost / 10).round()}%');
    }
    if (s.nightMode) parts.add(_t(context, 'eq_preset_night'));
    if (parts.isEmpty) {
      final peak = s.gainsDb.fold<double>(0, (m, g) => g.abs() > m.abs() ? g : m);
      parts.add(peak.abs() < 0.05
          ? _t(context, 'eq_flat')
          : '${_t(context, 'eq_peak')} ${peak > 0 ? '+' : ''}'
              '${peak.toStringAsFixed(1)} dB');
    }
    return parts.join(' · ');
  }

  Future<void> _onAction(
    BuildContext context,
    AudioEffectsService service,
    String action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    switch (action) {
      case 'apply':
        await service.applyProfile(profile);
      case 'overwrite':
        await service.updateProfile(profile);
        messenger.showSnackBar(
          SnackBar(
              content: Text(
                  '${_tOnce(context, 'eq_profiles_updated')} "${profile.name}"')),
        );
      case 'rename':
        final name = await _promptName(context, profile.name);
        if (name != null) await service.renameProfile(profile, name);
      case 'duplicate':
        await service.duplicateProfile(profile);
      case 'default':
        await service.setDefaultProfile(isDefault ? null : profile);
      case 'device':
        if (context.mounted) await _pickDevice(context, service);
      case 'export':
        await SharePlus.instance.share(
          ShareParams(
            text: service.exportProfile(profile),
            subject:
                '${_tOnce(context, 'eq_share_subject')} — ${profile.name}',
          ),
        );
      case 'delete':
        final ok = await _confirmDelete(context);
        if (ok == true) await service.deleteProfile(profile);
    }
  }

  Future<String?> _promptName(BuildContext context, String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t(ctx, 'eq_rename_title')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 32,
          decoration: InputDecoration(hintText: _t(ctx, 'eq_rename_hint')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_t(ctx, 'eq_common_cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(_t(ctx, 'eq_common_save')),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
              '${_t(ctx, 'eq_common_delete')} "${profile.name}"?'),
          content: Text(
              _t(ctx, 'eq_delete_body')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(_t(ctx, 'eq_common_cancel'))),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(_t(ctx, 'eq_common_delete'),
                  style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

  /// Binds this profile to one or more output routes, so it applies the moment
  /// headphones go in.
  Future<void> _pickDevice(
      BuildContext context, AudioEffectsService service) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t(ctx, 'eq_menu_auto_apply')),
        content: StatefulBuilder(
          builder: (ctx, setLocal) {
            final bindings = service.deviceBindings();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final device in OutputDevice.values)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(_t(ctx, device.labelKey),
                        style: const TextStyle(fontSize: 13.5)),
                    subtitle: bindings[device] != null &&
                            bindings[device] != profile.id
                        ? Text(_t(ctx, 'eq_device_used_by_other'),
                            style: TextStyle(fontSize: 11))
                        : null,
                    value: bindings[device] == profile.id,
                    onChanged: (checked) async {
                      await service.bindProfileToDevice(
                        device,
                        checked == true ? profile.id : null,
                      );
                      setLocal(() {});
                    },
                  ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_t(ctx, 'eq_common_done'))),
        ],
      ),
    );
  }
}
