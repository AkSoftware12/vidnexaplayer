import 'dart:async';

import 'package:docman/docman.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../NotifyListeners/LanguageProvider/profile_strings.dart';
import '../../Utils/app_palette.dart';
import '../../VideoPLayer/4kPlayer/4k_player.dart';
import '../service/vault_service.dart';
import '../../WhatsNew/whats_new.dart';

/// Brand gradient of the vault: the lock screen behind the keypad, and the
/// header once it is open.
const _kVaultTop = Color(0xFF1E1B4B);
const _kVaultBottom = Color(0xFF4338CA);
const _kAccent = Color(0xFF6366F1);

enum _Stage { loading, createPin, confirmPin, locked, unlocked }

enum _Filter { all, photos, videos, docs }

/// The private vault: a PIN (and optionally fingerprint) gate in front of a
/// grid of hidden photos, videos and documents.
///
/// The PIN is typed on an in-screen keypad rather than in a dialog, and the
/// fingerprint prompt opens by itself when that unlock is switched on. The
/// vault locks again whenever the app goes to the background, except while
/// it has sent the user somewhere on purpose (a picker, a delete prompt, a
/// document viewer).
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with WidgetsBindingObserver {
  final vault = VaultService();

  _Stage _stage = _Stage.loading;

  // ── PIN entry ──
  String _pin = '';
  String _firstPin = '';
  bool _shake = false;

  /// Digits in the saved PIN; null for one saved before that was recorded,
  /// in which case an Unlock button submits it instead.
  int? _pinLength;

  /// Shown under the dots: "Wrong PIN", "PINs didn't match"…
  String? _error;

  /// True while changing the PIN from inside the open vault, so Back on the
  /// keypad returns to the vault instead of leaving it.
  bool _changingPin = false;
  int _failedAttempts = 0;
  DateTime? _lockedOutUntil;
  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 1);
  static const int _minPin = 4;
  static const int _maxPin = 6;

  // ── Fingerprint ──
  bool _bioAvailable = false;
  bool _bioEnabled = false;
  bool _bioPromptOpen = false;

  // ── Contents ──
  List<VaultItem> _items = const [];
  _Filter _filter = _Filter.all;
  final Set<String> _selected = {};
  String? _progress;

  /// > 0 while the app has deliberately left the foreground (system picker,
  /// delete prompt, external viewer), so that is not mistaken for the user
  /// leaving and the vault does not lock under them.
  int _away = 0;

  String get _lang => context.read<LocaleProvider>().locale.languageCode;
  String _t(String key) => ProfileStrings.t(_lang, key);

  @override
  void initState() {
    super.initState();
    WhatsNew.instance.markSeen(NewFeature.vault);
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Set when the app really went to the background, so the fingerprint sheet
  /// re-opens on return. Not set by the sheet itself: on some phones it
  /// pauses the activity, and re-prompting on that resume would re-open the
  /// sheet every time the user cancelled it.
  bool _backgrounded = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_bioPromptOpen && _away == 0) {
      _backgrounded = true;
      // A PIN change in progress counts as open: leaving it must lock too.
      if (_stage == _Stage.unlocked || _changingPin) {
        setState(() {
          _stage = _Stage.locked;
          _changingPin = false;
          _pin = '';
          _firstPin = '';
          _error = null;
          _selected.clear();
          _items = const [];
        });
      }
    }
    if (state == AppLifecycleState.resumed && _backgrounded) {
      _backgrounded = false;
      if (_stage == _Stage.locked) _promptBiometric();
    }
  }

  /// Runs [action] with auto-lock held off.
  Future<T> _whileAway<T>(Future<T> Function() action) async {
    _away++;
    try {
      return await action();
    } finally {
      // A tick later: the "resumed" event for the return trip can arrive
      // after the awaited call has already completed.
      Future<void>.delayed(const Duration(milliseconds: 600), () => _away--);
    }
  }

  Future<void> _boot() async {
    try {
      _bioAvailable = await vault.biometricAvailable();
      _bioEnabled = _bioAvailable && await vault.biometricEnabled();
      final hasPin = await vault.hasPin();
      _pinLength = await vault.pinLength();
      if (!mounted) return;
      setState(() => _stage = hasPin ? _Stage.locked : _Stage.createPin);
      if (hasPin) _promptBiometric();
    } catch (e) {
      debugPrint('Vault boot failed: $e');
      if (mounted) setState(() => _stage = _Stage.locked);
    }
  }

  // ───────────────────────── unlock ─────────────────────────

  /// Opens the system fingerprint sheet straight away when that unlock is on,
  /// instead of waiting for a tap. Cancelling leaves the keypad usable.
  Future<void> _promptBiometric() async {
    if (!_bioEnabled || !_bioAvailable || _bioPromptOpen) return;
    if (_stage != _Stage.locked) return;
    _bioPromptOpen = true;
    // After the first frame, so the sheet opens over the lock screen.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    final ok = await vault.authenticateBiometric(_t('lock_bio_reason'));
    // Held a moment longer: the resume that follows the sheet closing must
    // not count as coming back from the background.
    Future<void>.delayed(
        const Duration(milliseconds: 500), () => _bioPromptOpen = false);
    if (ok && mounted && _stage == _Stage.locked) await _onUnlocked();
  }

  /// Guards the PIN check against a second digit landing while the first
  /// check is still hashing.
  bool _checking = false;

  Future<void> _onDigit(String d) async {
    if (_progress != null || _checking || _shake) return;
    HapticFeedback.selectionClick();

    if (_stage == _Stage.locked && _isLockedOut()) return;
    if (_pin.length >= _maxPin) return;
    setState(() {
      _pin += d;
      _error = null;
    });

    switch (_stage) {
      case _Stage.locked:
        // Checked the moment the saved PIN's length is reached. A PIN from
        // before that length was stored waits for the Unlock button.
        if (_pinLength != null && _pin.length == _pinLength) {
          await _submitPin();
        }
      case _Stage.confirmPin:
        if (_pin.length == _firstPin.length) await _finishConfirm();
      default:
        break;
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty || _checking) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  bool _isLockedOut() {
    final until = _lockedOutUntil;
    if (until == null || DateTime.now().isAfter(until)) return false;
    final secs = until.difference(DateTime.now()).inSeconds + 1;
    setState(() => _error =
        _t('lock_too_many_attempts').replaceAll('{secs}', '$secs'));
    return true;
  }

  /// Checks the typed PIN. A miss always says so — the old keypad only spoke
  /// up after six digits, so a wrong four-digit PIN just sat there and looked
  /// like the screen had frozen.
  Future<void> _submitPin() async {
    if (_pin.length < _minPin || _checking) return;
    if (_isLockedOut()) return;
    _checking = true;
    try {
      if (await vault.verifyPin(_pin)) {
        // An old PIN has no stored length; saving it again records one, so
        // from now on it unlocks without the button.
        if (_pinLength == null) {
          await vault.setPin(_pin);
          _pinLength = _pin.length;
        }
        await _onUnlocked();
        return;
      }

      _failedAttempts++;
      final left = _maxAttempts - _failedAttempts;
      if (left <= 0) {
        _failedAttempts = 0;
        _lockedOutUntil = DateTime.now().add(_lockoutDuration);
        _error = _t('lock_too_many_wrong');
      } else {
        _error = _t('lock_wrong_pin_left').replaceAll('{left}', '$left');
      }
      await _rejectPin();
    } finally {
      _checking = false;
    }
  }

  Future<void> _rejectPin() async {
    HapticFeedback.heavyImpact();
    setState(() => _shake = true);
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    setState(() {
      _shake = false;
      _pin = '';
    });
  }

  void _createNext() {
    if (_pin.length < _minPin) return;
    setState(() {
      _firstPin = _pin;
      _pin = '';
      _error = null;
      _stage = _Stage.confirmPin;
    });
  }

  Future<void> _finishConfirm() async {
    if (_pin != _firstPin) {
      setState(() => _error = _t('lock_pin_mismatch'));
      await _rejectPin();
      if (!mounted) return;
      setState(() {
        _firstPin = '';
        _stage = _Stage.createPin;
      });
      return;
    }
    await vault.setPin(_pin);
    _pinLength = _pin.length;
    _snack(_t(_changingPin ? 'lock_pin_changed' : 'lock_pin_set_success'));
    await _onUnlocked();
  }

  /// From inside the open vault: set a new PIN, entered twice.
  void _changePin() {
    setState(() {
      _changingPin = true;
      _pin = '';
      _firstPin = '';
      _error = null;
      _selected.clear();
      _stage = _Stage.createPin;
    });
  }

  /// Back on the keypad: out of a PIN change returns to the vault, anything
  /// else leaves the screen.
  void _keypadBack() {
    if (_changingPin) {
      setState(() {
        _changingPin = false;
        _pin = '';
        _firstPin = '';
        _error = null;
        _stage = _Stage.unlocked;
      });
      return;
    }
    Navigator.maybePop(context);
  }

  Future<void> _onUnlocked() async {
    _failedAttempts = 0;
    _lockedOutUntil = null;
    setState(() {
      _pin = '';
      _firstPin = '';
      _error = null;
      _changingPin = false;
      _stage = _Stage.unlocked;
    });
    await _refresh();
  }

  Future<void> _toggleBiometric() async {
    final turnOn = !_bioEnabled;
    if (turnOn) {
      _bioPromptOpen = true;
      final ok = await vault.authenticateBiometric(_t('lock_bio_reason'));
      _bioPromptOpen = false;
      if (!ok) return;
    }
    await vault.setBiometricEnabled(turnOn);
    if (!mounted) return;
    setState(() => _bioEnabled = turnOn);
    _snack(_t(turnOn ? 'lock_bio_on' : 'lock_bio_off'));
  }

  void _lockNow() {
    setState(() {
      _stage = _Stage.locked;
      _selected.clear();
      _items = const [];
    });
  }

  // ───────────────────────── contents ─────────────────────────

  Future<void> _refresh() async {
    try {
      final items = await vault.listItems();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      debugPrint('Vault listing failed: $e');
    }
  }

  List<VaultItem> get _visible => switch (_filter) {
        _Filter.all => _items,
        _Filter.photos =>
          _items.where((i) => i.kind == VaultKind.image).toList(),
        _Filter.videos =>
          _items.where((i) => i.kind == VaultKind.video).toList(),
        _Filter.docs => _items
            .where((i) =>
                i.kind == VaultKind.document || i.kind == VaultKind.audio)
            .toList(),
      };

  Future<void> _showAddSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddSheet(t: _t),
    );
    if (choice == 'media') await _addMedia();
    if (choice == 'docs') await _addDocuments();
  }

  Future<void> _addMedia() async {
    final picked = await Navigator.push<List<AssetEntity>>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'VaultMediaPicker'),
        builder: (_) => _VaultMediaPicker(t: _t),
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    if (!await _confirmHide(picked.length, gallery: true)) return;

    final result = await _whileAway(
      () => vault.hideAssets(picked, onProgress: _setProgress),
    );
    _afterHide(result);
  }

  Future<void> _addDocuments() async {
    final docs = await _whileAway(() async {
      try {
        return await DocMan.pick.documents(limit: 30);
      } catch (_) {
        return <DocumentFile>[];
      }
    });
    if (docs.isEmpty || !mounted) return;
    if (!await _confirmHide(docs.length, gallery: false)) return;

    final result = await _whileAway(
      () => vault.hideDocuments(docs, onProgress: _setProgress),
    );
    _afterHide(result);
  }

  /// Says what hiding does before Android's own prompt does it.
  ///
  /// For gallery items Android words that prompt "Allow … to delete?" — its
  /// text, not ours, and the only way an app without All-files access may
  /// take another app's photo out of the gallery. Read cold, it looks like
  /// the file is about to be destroyed; it is not, the vault copy is already
  /// made and Unhide puts it back.
  Future<bool> _confirmHide(int count, {required bool gallery}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.visibility_off_rounded, color: _kAccent),
        title: Text(
          _t('lock_hide_confirm_title').replaceAll('{count}', '$count'),
        ),
        content: Text(
          _t(gallery ? 'lock_hide_confirm_body' : 'lock_hide_docs_confirm_body'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t('lock_cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t('lock_hide')),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _setProgress(int done, int total) {
    if (!mounted) return;
    setState(() {
      _progress = _t('lock_hiding')
          .replaceAll('{done}', '$done')
          .replaceAll('{total}', '$total');
    });
  }

  Future<void> _afterHide(VaultHideResult r) async {
    setState(() => _progress = null);
    await _refresh();
    if (r.hidden == 0) {
      _snack(_t('lock_hidden_none'));
    } else if (r.notRemoved > 0) {
      _snack(_t('lock_hidden_partial')
          .replaceAll('{count}', '${r.hidden}')
          .replaceAll('{kept}', '${r.notRemoved}'));
    } else {
      _snack(_t('lock_hidden_ok').replaceAll('{count}', '${r.hidden}'));
    }
  }

  List<VaultItem> get _selectedItems =>
      _items.where((i) => _selected.contains(i.file.path)).toList();

  Future<void> _restoreSelected() async {
    final items = _selectedItems;
    if (items.isEmpty) return;
    var ok = 0;
    for (var i = 0; i < items.length; i++) {
      setState(() => _progress = '${i + 1} / ${items.length}');
      if (await _whileAway(() => vault.restore(items[i]))) ok++;
    }
    setState(() {
      _progress = null;
      _selected.clear();
    });
    await _refresh();
    final failed = items.length - ok;
    _snack(failed == 0
        ? _t('lock_restored_ok').replaceAll('{count}', '$ok')
        : _t('lock_restore_partial')
            .replaceAll('{count}', '$ok')
            .replaceAll('{failed}', '$failed'));
  }

  void _toggleSelect(VaultItem item) {
    setState(() {
      if (!_selected.remove(item.file.path)) _selected.add(item.file.path);
    });
  }

  Future<void> _open(VaultItem item) async {
    if (_selected.isNotEmpty) {
      _toggleSelect(item);
      return;
    }
    switch (item.kind) {
      case VaultKind.image:
        final photos = _visible.where((i) => i.kind == VaultKind.image).toList();
        await Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'VaultPhotoViewer'),
            builder: (_) => _VaultImageViewer(
              items: photos,
              initial: photos.indexOf(item),
            ),
          ),
        );
      case VaultKind.video:
        await Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'VaultVideoPlayer'),
            builder: (_) => FullScreenVideoPlayerFixed(
              initialUrl: Uri.file(item.file.path).toString(),
            ),
          ),
        );
      default:
        // Handed to whichever app opens the type, through the docman
        // plugin's FileProvider — the vault file itself never leaves the
        // app's private folder.
        final opened = await _whileAway(() async {
          try {
            final doc = await DocumentFile(uri: item.file.path).get();
            return doc != null && await doc.open();
          } catch (_) {
            return false;
          }
        });
        if (!opened) _snack(_t('lock_open_failed'));
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ───────────────────────── build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    context.watch<LocaleProvider>();

    return PopScope(
      canPop: _selected.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selected.isNotEmpty) setState(_selected.clear);
      },
      // Every stage has the dark gradient behind the status bar, so its
      // icons are always the light set.
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: switch (_stage) {
          _Stage.loading => const Scaffold(
              backgroundColor: _kVaultTop,
              body:
                  Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
          _Stage.unlocked => _buildVault(),
          _ => _buildKeypadScreen(),
        },
      ),
    );
  }

  Widget _buildKeypadScreen() {
    final creating = _stage == _Stage.createPin;
    final confirming = _stage == _Stage.confirmPin;
    final title = creating
        ? _t(_changingPin ? 'lock_new_pin' : 'lock_create_pin')
        : confirming
            ? _t('lock_confirm_pin')
            : _t('lock_unlock_vault_title');
    final locked = _stage == _Stage.locked;

    // Dots: as many as the saved PIN when unlocking (so the user sees when
    // it will be checked), as many as the first entry when confirming, and
    // otherwise four growing to six as digits are typed.
    final slots = confirming
        ? _firstPin.length
        : locked && _pinLength != null
            ? _pinLength!
            : (_pin.length < _minPin ? _minPin : _pin.length);

    // The button under the dots: Next while creating; Unlock only for an old
    // PIN of unknown length, which cannot be checked automatically.
    final Widget? button = creating && _pin.length >= _minPin
        ? _pillButton(_t('onboard_next'), _createNext)
        : locked && _pinLength == null && _pin.length >= _minPin
            ? _pillButton(_t('lock_unlock_button'), _submitPin)
            : null;
    final sub = creating
        ? _t('lock_create_pin_sub')
        : confirming
            ? _t('lock_confirm_pin_sub')
            : _t('lock_unlock_vault_sub');
    final showBio = _stage == _Stage.locked && _bioEnabled && _bioAvailable;

    return Scaffold(
      backgroundColor: _kVaultTop,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_kVaultTop, _kVaultBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _keypadBack,
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                ),
              ),
              const Spacer(flex: 2),
              Container(
                height: 76,
                width: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: Icon(
                  creating || confirming
                      ? Icons.shield_rounded
                      : Icons.lock_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  sub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 26),
              _PinDots(length: _pin.length, slots: slots, shake: _shake),
              const SizedBox(height: 14),
              // Fixed height either way, so the keypad does not jump when a
              // message or the button appears.
              SizedBox(
                height: 22,
                child: _error == null
                    ? null
                    : Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              SizedBox(height: 44, child: button),
              const Spacer(flex: 3),
              _Keypad(
                onDigit: _onDigit,
                onBackspace: _onBackspace,
                onBiometric: showBio ? _promptBiometric : null,
                biometricLabel: _t('lock_use_fingerprint'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillButton(String label, VoidCallback onPressed) => FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _kVaultTop,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          shape: const StadiumBorder(),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  Widget _buildVault() {
    final visible = _visible;
    final selecting = _selected.isNotEmpty;

    return Scaffold(
      backgroundColor: AppPalette.surface,
      floatingActionButton: selecting || _progress != null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
              onPressed: _showAddSheet,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                _t('lock_add'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
      body: Column(
        children: [
          _VaultHeader(
            title: _t('lock_vault_title'),
            subtitle: _t('lock_items_count')
                .replaceAll('{count}', '${_items.length}'),
            selectedLabel: selecting
                ? _t('lock_selected')
                    .replaceAll('{count}', '${_selected.length}')
                : null,
            onBack: () => Navigator.maybePop(context),
            onClearSelection: () => setState(_selected.clear),
            onSelectAll: () => setState(() {
              _selected
                ..clear()
                ..addAll(visible.map((i) => i.file.path));
            }),
            onRestore: _restoreSelected,
            onChangePin: _changePin,
            onLock: _lockNow,
            onBiometric: _bioAvailable ? _toggleBiometric : null,
            biometricOn: _bioEnabled,
            t: _t,
          ),
          if (_progress != null) _ProgressBanner(text: _progress!),
          _UninstallNote(text: _t('lock_uninstall_warning')),
          _FilterBar(
            filter: _filter,
            onChanged: (f) => setState(() => _filter = f),
            t: _t,
          ),
          Expanded(
            child: visible.isEmpty
                ? _EmptyVault(
                    title: _t('lock_no_files_title'),
                    body: _t('lock_empty_body'),
                  )
                : RefreshIndicator(
                    color: _kAccent,
                    onRefresh: _refresh,
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: visible.length,
                      itemBuilder: (_, i) {
                        final item = visible[i];
                        return _VaultTile(
                          item: item,
                          selected: _selected.contains(item.file.path),
                          selecting: selecting,
                          onTap: () => _open(item),
                          onLongPress: () => _toggleSelect(item),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════ keypad ═════════════════════════

class _PinDots extends StatelessWidget {
  const _PinDots({
    required this.length,
    required this.slots,
    required this.shake,
  });

  final int length;
  final int slots;
  final bool shake;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 80),
      offset: shake ? const Offset(0.04, 0) : Offset.zero,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < slots; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              height: 16,
              width: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: shake
                    ? Colors.redAccent
                    : i < length
                        ? Colors.white
                        : Colors.transparent,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onBiometric,
    required this.biometricLabel,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Null hides the fingerprint key.
  final VoidCallback? onBiometric;
  final String biometricLabel;

  @override
  Widget build(BuildContext context) {
    Widget key(Widget child, VoidCallback? onTap, {String? semantic}) =>
        Semantics(
          button: true,
          label: semantic,
          child: SizedBox(
            height: 70,
            width: 70,
            child: onTap == null
                ? const SizedBox.shrink()
                : Material(
                    color: Colors.white.withValues(alpha: 0.10),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onTap,
                      child: Center(child: child),
                    ),
                  ),
          ),
        );

    Widget digit(String d) => key(
          Text(
            d,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),
          () => onDigit(d),
          semantic: d,
        );

    Widget row(List<Widget> keys) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: keys,
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        children: [
          row([digit('1'), digit('2'), digit('3')]),
          row([digit('4'), digit('5'), digit('6')]),
          row([digit('7'), digit('8'), digit('9')]),
          row([
            key(
              const Icon(Icons.fingerprint_rounded,
                  color: Colors.white, size: 32),
              onBiometric,
              semantic: biometricLabel,
            ),
            digit('0'),
            key(
              const Icon(Icons.backspace_outlined,
                  color: Colors.white, size: 24),
              onBackspace,
            ),
          ]),
        ],
      ),
    );
  }
}

// ═════════════════════════ open vault ═════════════════════════

class _VaultHeader extends StatelessWidget {
  const _VaultHeader({
    required this.title,
    required this.subtitle,
    required this.selectedLabel,
    required this.onBack,
    required this.onClearSelection,
    required this.onSelectAll,
    required this.onRestore,
    required this.onChangePin,
    required this.onLock,
    required this.onBiometric,
    required this.biometricOn,
    required this.t,
  });

  final String title;
  final String subtitle;

  /// Non-null while items are selected: the header turns into the action bar.
  final String? selectedLabel;
  final VoidCallback onBack;
  final VoidCallback onClearSelection;
  final VoidCallback onSelectAll;
  final VoidCallback onRestore;
  final VoidCallback onChangePin;
  final VoidCallback onLock;
  final VoidCallback? onBiometric;
  final bool biometricOn;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    final selecting = selectedLabel != null;

    Widget action(IconData icon, String tip, VoidCallback onTap) => IconButton(
          tooltip: tip,
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white),
        );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kVaultTop, _kVaultBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
          child: Row(
            children: [
              IconButton(
                onPressed: selecting ? onClearSelection : onBack,
                icon: Icon(
                  selecting ? Icons.close_rounded : Icons.arrow_back_rounded,
                  color: Colors.white,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedLabel ?? title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (!selecting)
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (selecting) ...[
                action(Icons.select_all_rounded, t('lock_filter_all'),
                    onSelectAll),
                // Unhide only. The vault has no delete: things leave it by
                // being put back, never by being destroyed.
                action(Icons.visibility_rounded, t('lock_restore'), onRestore),
              ] else ...[
                if (onBiometric != null)
                  action(
                    biometricOn
                        ? Icons.fingerprint_rounded
                        : Icons.fingerprint_outlined,
                    t(biometricOn ? 'lock_bio_turn_off' : 'lock_bio_turn_on'),
                    onBiometric!,
                  ),
                action(Icons.password_rounded, t('lock_change_pin'),
                    onChangePin),
                action(Icons.lock_rounded, t('lock_locked_badge'), onLock),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Hidden files live in the app's private folder, which Android wipes on
/// uninstall or "Clear data". Said up front, where it can still be acted on.
class _UninstallNote extends StatelessWidget {
  const _UninstallNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFD97706), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: AppPalette.textH,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBanner extends StatelessWidget {
  const _ProgressBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _kAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: AppPalette.textH,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.onChanged,
    required this.t,
  });

  final _Filter filter;
  final ValueChanged<_Filter> onChanged;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    final labels = {
      _Filter.all: t('lock_filter_all'),
      _Filter.photos: t('lock_filter_photos'),
      _Filter.videos: t('lock_filter_videos'),
      _Filter.docs: t('lock_filter_docs'),
    };
    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        children: [
          for (final e in labels.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(e.value),
                selected: filter == e.key,
                onSelected: (_) => onChanged(e.key),
                showCheckmark: false,
                selectedColor: _kAccent,
                backgroundColor: AppPalette.card,
                side: BorderSide(
                  color: filter == e.key ? _kAccent : AppPalette.border,
                ),
                labelStyle: TextStyle(
                  color: filter == e.key ? Colors.white : AppPalette.textH,
                  fontWeight: FontWeight.w600,
                ),
                shape: const StadiumBorder(),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyVault extends StatelessWidget {
  const _EmptyVault({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 84,
              width: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kAccent.withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.shield_moon_rounded,
                  color: _kAccent, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppPalette.textH,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppPalette.textS, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _VaultTile extends StatelessWidget {
  const _VaultTile({
    required this.item,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
  });

  final VaultItem item;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: selected ? 0.92 : 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _preview(),
              if (item.kind == VaultKind.video)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: _Badge(
                    icon: Icons.play_arrow_rounded,
                    text: item.duration == null ? null : _fmt(item.duration!),
                  ),
                ),
              if (selecting)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    height: 22,
                    width: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? _kAccent
                          : Colors.black.withValues(alpha: 0.25),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 14)
                        : null,
                  ),
                ),
              if (selected)
                Container(color: _kAccent.withValues(alpha: 0.18)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview() {
    final thumb = item.thumb;
    final showImage = thumb != null || item.kind == VaultKind.image;
    if (showImage) {
      return Image.file(
        thumb ?? item.file,
        fit: BoxFit.cover,
        cacheWidth: 320,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _iconTile(),
      );
    }
    return _iconTile();
  }

  Widget _iconTile() {
    final (icon, colors) = switch (item.kind) {
      VaultKind.video => (
          Icons.movie_rounded,
          const [Color(0xFFA855F7), Color(0xFF6366F1)]
        ),
      VaultKind.audio => (
          Icons.music_note_rounded,
          const [Color(0xFFF472B6), Color(0xFFEC4899)]
        ),
      VaultKind.image => (
          Icons.image_rounded,
          const [Color(0xFFFBBF24), Color(0xFFF97316)]
        ),
      VaultKind.document => _docLook(item.name),
    };
    final ext = item.name.contains('.')
        ? item.name.split('.').last.toUpperCase()
        : '';
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 30),
          if (ext.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              ext,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            item.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 10,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  static (IconData, List<Color>) _docLook(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => (
          Icons.picture_as_pdf_rounded,
          const [Color(0xFFF87171), Color(0xFFDC2626)]
        ),
      'doc' || 'docx' || 'odt' || 'rtf' || 'txt' => (
          Icons.description_rounded,
          const [Color(0xFF60A5FA), Color(0xFF2563EB)]
        ),
      'xls' || 'xlsx' || 'csv' || 'ods' => (
          Icons.table_chart_rounded,
          const [Color(0xFF34D399), Color(0xFF059669)]
        ),
      'ppt' || 'pptx' || 'odp' => (
          Icons.slideshow_rounded,
          const [Color(0xFFFB923C), Color(0xFFEA580C)]
        ),
      'zip' || 'rar' || '7z' => (
          Icons.folder_zip_rounded,
          const [Color(0xFFA8A29E), Color(0xFF57534E)]
        ),
      _ => (
          Icons.insert_drive_file_rounded,
          const [Color(0xFF94A3B8), Color(0xFF475569)]
        ),
    };
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, this.text});

  final IconData icon;
  final String? text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          if (text != null) ...[
            const SizedBox(width: 2),
            Text(
              text!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddSheet extends StatelessWidget {
  const _AddSheet({required this.t});

  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    Widget option(IconData icon, List<Color> colors, String title, String sub,
            String value) =>
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: colors),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppPalette.textH,
            ),
          ),
          subtitle: Text(sub, style: TextStyle(color: AppPalette.textS)),
          onTap: () => Navigator.pop(context, value),
        );

    return Container(
      decoration: BoxDecoration(
        color: AppPalette.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: AppPalette.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            option(
              Icons.photo_library_rounded,
              const [Color(0xFFA855F7), Color(0xFF6366F1)],
              t('lock_add_media'),
              t('lock_add_media_sub'),
              'media',
            ),
            option(
              Icons.description_rounded,
              const [Color(0xFFF87171), Color(0xFFDC2626)],
              t('lock_add_docs'),
              t('lock_add_docs_sub'),
              'docs',
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════ photo viewer ═════════════════════════

/// Swipeable, zoomable viewer over the vault's photos. Reads the vault files
/// directly; nothing is copied out of the private folder to show them.
class _VaultImageViewer extends StatefulWidget {
  const _VaultImageViewer({required this.items, required this.initial});

  final List<VaultItem> items;
  final int initial;

  @override
  State<_VaultImageViewer> createState() => _VaultImageViewerState();
}

class _VaultImageViewerState extends State<_VaultImageViewer> {
  late final PageController _pages =
      PageController(initialPage: widget.initial < 0 ? 0 : widget.initial);
  late int _index = widget.initial < 0 ? 0 : widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_index + 1} / ${widget.items.length}',
          style: const TextStyle(fontSize: 15),
        ),
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: widget.items.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image.file(
              widget.items[i].file,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_rounded,
                color: Colors.white54,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════ media picker ═════════════════════════

/// Multi-select picker over the phone's photos and videos.
///
/// In-app rather than the system picker because hiding needs the gallery
/// item itself — its id to delete it by, its folder to restore it to, its
/// thumbnail — where the system picker hands back a cache copy that deleting
/// does nothing to (which is exactly why the old vault never hid anything).
class _VaultMediaPicker extends StatefulWidget {
  const _VaultMediaPicker({required this.t});

  final String Function(String) t;

  @override
  State<_VaultMediaPicker> createState() => _VaultMediaPickerState();
}

class _VaultMediaPickerState extends State<_VaultMediaPicker> {
  static const _pageSize = 90;

  /// "Recent" (everything) first, then each folder — Camera, Screenshots,
  /// WhatsApp Images…
  List<AssetPathEntity> _albums = const [];
  final Map<String, int> _albumCounts = {};
  AssetPathEntity? _album;

  final List<AssetEntity> _assets = [];

  /// Keyed by id and holding the asset itself, so a pick survives switching
  /// to another folder whose grid no longer contains it.
  final Map<String, AssetEntity> _picked = {};

  bool _loading = true;
  bool _denied = false;
  bool _loadingMore = false;
  bool _end = false;
  int _page = 0;

  /// Bumped on every folder switch, so a page still loading for the folder
  /// just left is dropped rather than appended to the new one.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final perm = await PhotoManager.requestPermissionExtend();
    if (!perm.hasAccess) {
      if (mounted) {
        setState(() {
          _denied = true;
          _loading = false;
        });
      }
      return;
    }
    final paths = await PhotoManager.getAssetPathList(type: RequestType.common);
    _albums = paths;
    if (paths.isNotEmpty) await _openAlbum(paths.first);
    if (mounted) setState(() => _loading = false);

    // Counts after the grid is up: each one is a query, and the first
    // screen of photos matters more than the numbers on the chips.
    for (final a in paths) {
      final n = await a.assetCountAsync;
      if (!mounted) return;
      setState(() => _albumCounts[a.id] = n);
    }
  }

  Future<void> _openAlbum(AssetPathEntity album) async {
    _generation++;
    setState(() {
      _album = album;
      _assets.clear();
      _page = 0;
      _end = false;
      _loadingMore = false;
    });
    await _more();
  }

  Future<void> _more() async {
    final album = _album;
    if (album == null || _loadingMore || _end) return;
    final gen = _generation;
    _loadingMore = true;
    final batch = await album.getAssetListPaged(page: _page, size: _pageSize);
    if (gen != _generation) return;
    _page++;
    _end = batch.length < _pageSize;
    _loadingMore = false;
    if (mounted) setState(() => _assets.addAll(batch));
  }

  void _toggle(AssetEntity a) => setState(() {
        if (_picked.remove(a.id) == null) _picked[a.id] = a;
      });

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final t = widget.t;
    final count = _picked.length;

    return Scaffold(
      backgroundColor: AppPalette.surface,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        foregroundColor: AppPalette.textH,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          t('lock_picker_title'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        bottom: _albums.length < 2
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                    children: [
                      for (final a in _albums)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              _albumCounts[a.id] == null
                                  ? a.name
                                  : '${a.name}  ${_albumCounts[a.id]}',
                            ),
                            selected: _album?.id == a.id,
                            onSelected: (_) => _openAlbum(a),
                            showCheckmark: false,
                            selectedColor: _kAccent,
                            backgroundColor: AppPalette.card,
                            side: BorderSide(
                              color: _album?.id == a.id
                                  ? _kAccent
                                  : AppPalette.border,
                            ),
                            labelStyle: TextStyle(
                              color: _album?.id == a.id
                                  ? Colors.white
                                  : AppPalette.textH,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: const StadiumBorder(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _kAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: count == 0
                  ? null
                  : () => Navigator.pop(context, _picked.values.toList()),
              icon: const Icon(Icons.lock_rounded),
              label: Text(
                t('lock_picker_hide').replaceAll('{count}', '$count'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kAccent))
          : _denied || _assets.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _denied
                          ? t('lock_picker_no_access')
                          : t('lock_picker_empty'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppPalette.textS),
                    ),
                  ),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.pixels > n.metrics.maxScrollExtent - 600) {
                      _more();
                    }
                    return false;
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.all(4),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: _assets.length,
                    itemBuilder: (_, i) {
                      final a = _assets[i];
                      final on = _picked.containsKey(a.id);
                      return GestureDetector(
                        onTap: () => _toggle(a),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _AssetThumb(asset: a),
                            if (a.type == AssetType.video)
                              const Positioned(
                                left: 4,
                                bottom: 4,
                                child: _Badge(icon: Icons.play_arrow_rounded),
                              ),
                            if (on)
                              Container(
                                color: _kAccent.withValues(alpha: 0.35),
                              ),
                            Positioned(
                              top: 5,
                              right: 5,
                              child: Container(
                                height: 22,
                                width: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: on
                                      ? _kAccent
                                      : Colors.black.withValues(alpha: 0.25),
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                                child: on
                                    ? const Icon(Icons.check_rounded,
                                        color: Colors.white, size: 14)
                                    : null,
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

/// Gallery thumbnail, cached for the picker's lifetime so scrolling back up
/// does not decode the same cells again.
class _AssetThumb extends StatefulWidget {
  const _AssetThumb({required this.asset});

  final AssetEntity asset;

  @override
  State<_AssetThumb> createState() => _AssetThumbState();
}

class _AssetThumbState extends State<_AssetThumb> {
  static final Map<String, Uint8List> _cache = {};

  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _cache[widget.asset.id];
    if (_bytes == null) _load();
  }

  Future<void> _load() async {
    try {
      final b = await widget.asset
          .thumbnailDataWithSize(const ThumbnailSize.square(240), quality: 80);
      if (b == null || !mounted) return;
      if (_cache.length > 600) _cache.clear();
      _cache[widget.asset.id] = b;
      setState(() => _bytes = b);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final b = _bytes;
    if (b == null) return ColoredBox(color: AppPalette.raised);
    return Image.memory(b, fit: BoxFit.cover, gaplessPlayback: true);
  }
}
