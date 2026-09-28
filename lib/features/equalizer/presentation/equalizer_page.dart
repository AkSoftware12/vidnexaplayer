import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../DarkMode/dark_mode.dart';
import '../../../NotifyListeners/LanguageProvider/equalizer_strings.dart';
import '../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../audio_effects_service.dart';
import '../domain/eq_models.dart';

import 'widgets/eq_band_slider.dart';
import 'widgets/eq_curve_painter.dart';
import 'widgets/preset_carousel.dart';
import 'widgets/profile_sheet.dart';
import 'widgets/visualizer_painter.dart';

/// Full-screen equalizer. The bottom sheet (`equalizer_sheet.dart`) renders the
/// SAME [EqualizerBody] in compact mode, so the two can never disagree.
class EqualizerPage extends StatefulWidget {
  const EqualizerPage({super.key, this.mediaType});

  /// Which player to edit. Null keeps whatever the service already has active —
  /// which is what the entry point in Settings wants.
  final MediaType? mediaType;

  @override
  State<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<EqualizerPage> {
  @override
  void initState() {
    super.initState();
    final service = context.read<AudioEffectsService>();
    // init() is idempotent; calling it here covers the case where the page is
    // the first thing in the app to touch the equalizer.
    service.init();
    final type = widget.mediaType;
    if (type != null) service.setActiveMediaType(type);
  }

  @override
  Widget build(BuildContext context) {
    final colors = EqColors.of(context);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: colors.text),
        title: Text(
          eqT(context, 'eq_title'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
        actions: [
          IconButton(
            tooltip: eqT(context, 'eq_my_profiles'),
            icon: Icon(Icons.bookmarks_outlined, size: 20, color: colors.text),
            onPressed: () => EqProfileSheet.show(
              context,
              accent: colors.accent,
              surface: colors.surface,
              card: colors.card,
              textColor: colors.text,
              subtleColor: colors.subtle,
            ),
          ),
        ],
      ),
      body: const SafeArea(
        top: false,
        child: EqualizerBody(compact: false),
      ),
    );
  }
}

/// Translates one equalizer string for the app's current language.
///
/// Every visible string in this feature goes through here; the models only ever
/// carry keys. Call it from a `build` — it watches the locale so the whole
/// equalizer re-renders when the user switches language.
String eqT(BuildContext context, String key) =>
    EqStrings.t(context.watch<LocaleProvider>().locale.languageCode, key);

/// Same lookup for event handlers (snackbars), where watching would assert.
String eqTOnce(BuildContext context, String key) => EqStrings.t(
      Provider.of<LocaleProvider>(context, listen: false).locale.languageCode,
      key,
    );

/// The equalizer's switch.
///
/// Exists because the default styling here painted the thumb AND the track in
/// the accent colour — on screen that is one solid purple pill with no readable
/// on/off state. The thumb must contrast against its own track: white on accent
/// when on, grey on a light track (with an outline) when off.
class EqSwitch extends StatelessWidget {
  const EqSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.colors,
  });

  final bool value;

  /// Null disables the switch, which also dims it.
  final ValueChanged<bool>? onChanged;
  final EqColors colors;

  @override
  Widget build(BuildContext context) {
    final offTrack =
        colors.isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
    final offThumb =
        colors.isDark ? const Color(0xFF94A3B8) : const Color(0xFFFFFFFF);

    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: colors.accent,
      inactiveThumbColor: offThumb,
      inactiveTrackColor: offTrack,
      // The outline only reads as a border while OFF; keeping it in the ON
      // state draws a dark ring around the accent pill.
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : colors.subtle.withValues(alpha: 0.45),
      ),
      trackOutlineWidth: const WidgetStatePropertyAll(1.4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Resolved colours for the equalizer UI, following the app's theme engine.
class EqColors {
  const EqColors({
    required this.accent,
    required this.surface,
    required this.card,
    required this.text,
    required this.subtle,
    required this.isDark,
  });

  final Color accent;
  final Color surface;
  final Color card;
  final Color text;
  final Color subtle;
  final bool isDark;

  factory EqColors.of(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Read the app's accent when the provider is in scope; fall back to the
    // ThemeData primary when the equalizer is shown from a route that is not
    // under the MultiProvider (e.g. a fullscreen player pushed with its own
    // navigator).
    //
    // `listen: false` deliberately. `context.watch` here would assert the
    // moment this is called from anywhere but a build method — which is what
    // opening the sheet from a button handler does. Reactivity is not lost:
    // the accent is baked into ThemeData, so the `Theme.of` above already
    // registers the dependency that rebuilds this on a theme change.
    final themeProvider = Provider.of<ThemeProvider?>(context, listen: false);
    final accent = themeProvider == null
        ? theme.colorScheme.primary
        : (isDark ? themeProvider.accent.onDarkSeed : themeProvider.accent.seed);

    return EqColors(
      accent: accent,
      surface: isDark ? const Color(0xFF0F172A) : Colors.white,
      card: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      text: isDark ? Colors.white : const Color(0xFF111827),
      subtle: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
      isDark: isDark,
    );
  }
}

/// The equalizer itself. Used full-screen and inside the bottom sheet.
class EqualizerBody extends StatelessWidget {
  const EqualizerBody({super.key, this.compact = false});

  /// Compact drops the advanced controls and offers "Open full equalizer".
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AudioEffectsService>();
    final colors = EqColors.of(context);
    // Editable whenever the device supports effects at all — NOT only while a
    // player is attached. The settings entry point exists so a curve can be set
    // up before playback, and it is re-pushed as soon as a player binds.
    final on = service.settings.enabled && !service.isDeviceUnsupported;

    return ListView(
      padding: EdgeInsets.only(
        bottom: compact ? 12 : MediaQuery.of(context).padding.bottom + 24,
      ),
      physics: const BouncingScrollPhysics(),
      children: [
        _MasterHeader(colors: colors, compact: compact),
        if (!service.isAvailable) _UnsupportedBanner(colors: colors),
        if (service.suggestion != null) _SuggestionChip(colors: colors),
        if (service.codecCompensationActive) _CodecNote(colors: colors),
        _CurvePanel(colors: colors, enabled: on),
        _BandRow(colors: colors, enabled: on),
        const SizedBox(height: 6),
        PresetCarousel(
          mediaType: service.activeMediaType,
          selectedId: service.settings.presetId,
          onSelect: service.applyPreset,
          onSelectProfile: service.applyProfile,
          profiles: service.profiles,
          accent: colors.accent,
          cardColor: colors.card,
          textColor: colors.text,
          subtleColor: colors.subtle,
          enabled: on,
        ),
        _ActionRow(colors: colors, enabled: on, compact: compact),
        if (!compact) ...[
          const SizedBox(height: 4),
          _AdvancedSection(colors: colors, enabled: on),
        ],
      ],
    );
  }
}

// ── header ──────────────────────────────────────────────────────────────────

class _MasterHeader extends StatelessWidget {
  const _MasterHeader({required this.colors, required this.compact});

  final EqColors colors;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AudioEffectsService>();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(18, compact ? 6 : 12, 12, 4),
          child: _titleRow(context, service),
        ),
        // Opened from a player, the media type is already known and fixed.
        // Opened from Settings it is not — and since video and music keep
        // SEPARATE settings (master switch included), the page has to say which
        // one is on and let the user turn on just one of them.
        if (!compact) _MediaTypeSelector(colors: colors),
      ],
    );
  }

  Widget _titleRow(BuildContext context, AudioEffectsService service) {
    return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      service.activeMediaType == MediaType.video
                          ? eqT(context, 'eq_video_audio')
                          : eqT(context, 'eq_media_music'),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                      label: eqT(context, service.outputDevice.labelKey),
                      icon: switch (service.outputDevice) {
                        OutputDevice.speaker => Icons.speaker_rounded,
                        OutputDevice.wired => Icons.headset_rounded,
                        OutputDevice.bluetooth => Icons.bluetooth_rounded,
                        OutputDevice.usb => Icons.usb_rounded,
                      },
                      colors: colors,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  service.isAvailable
                      ? eqT(context, service.engineLabelKey)
                      : eqT(context, 'eq_not_available'),
                  style: TextStyle(fontSize: 11, color: colors.subtle),
                ),
              ],
            ),
          ),
          EqSwitch(
            value: service.settings.enabled,
            colors: colors,
            onChanged: service.isDeviceUnsupported
                ? null
                : (v) => service.setEnabled(v),
          ),
        ],
    );
  }
}

/// Picks which player's equalizer is being edited, and shows the on/off state
/// of BOTH at a glance.
///
/// Video and music each keep their own [EqSettings], master switch included, so
/// "the equalizer is on" is never a single global fact. Reached from a player
/// that ambiguity does not exist; reached from Settings it does, and without
/// this row there is no way to tell which one you just switched on — or to turn
/// on only one of them.
class _MediaTypeSelector extends StatelessWidget {
  const _MediaTypeSelector({required this.colors});

  final EqColors colors;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AudioEffectsService>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 2),
      child: Row(
        children: [
          for (final type in MediaType.values) ...[
            Expanded(
              child: _Segment(
                type: type,
                selected: service.activeMediaType == type,
                enabled: service.settingsFor(type).enabled,
                colors: colors,
                onTap: () => service.setActiveMediaType(type),
              ),
            ),
            if (type != MediaType.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.type,
    required this.selected,
    required this.enabled,
    required this.colors,
    required this.onTap,
  });

  final MediaType type;

  /// Whether this is the type currently being edited.
  final bool selected;

  /// Whether THIS type's equalizer is switched on.
  final bool enabled;

  final EqColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const onColor = Color(0xFF16A34A);

    return Material(
      color: selected ? colors.accent.withValues(alpha: 0.12) : colors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? colors.accent
                  : colors.subtle.withValues(alpha: 0.22),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                type == MediaType.video
                    ? Icons.movie_rounded
                    : Icons.music_note_rounded,
                size: 15,
                color: selected ? colors.accent : colors.subtle,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  eqT(context,
                      type == MediaType.video ? 'eq_media_video' : 'eq_media_music'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? colors.accent : colors.text,
                  ),
                ),
              ),
              // The state dot is what makes this row worth the space: it says
              // which equalizer is live even while you are editing the other.
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: enabled ? onColor : Colors.transparent,
                  border: enabled
                      ? null
                      : Border.all(
                          color: colors.subtle.withValues(alpha: 0.55),
                          width: 1.2,
                        ),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                eqT(context, enabled ? 'eq_on' : 'eq_off'),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: enabled ? onColor : colors.subtle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon, required this.colors});

  final String label;
  final IconData icon;
  final EqColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: colors.accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: colors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnsupportedBanner extends StatelessWidget {
  const _UnsupportedBanner({required this.colors});

  final EqColors colors;

  @override
  Widget build(BuildContext context) {
    final reason = context.watch<AudioEffectsService>().unsupportedReason;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: Color(0xFFB45309)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              // Some MIUI / Samsung / Realme builds keep the audio effects for
              // their own system equalizer and refuse ours outright.
              eqT(context,
                  reason == 'device' ? 'eq_banner_device' : 'eq_banner_waiting'),
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: Color(0xFFB45309),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodecNote extends StatelessWidget {
  const _CodecNote({required this.colors});

  final EqColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
      child: Row(
        children: [
          Icon(Icons.auto_fix_high_rounded, size: 13, color: colors.accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              eqT(context, 'eq_codec_note'),
              style: TextStyle(fontSize: 10.5, color: colors.subtle),
            ),
          ),
        ],
      ),
    );
  }
}

// ── AI suggestion ───────────────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.colors});

  final EqColors colors;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AudioEffectsService>();
    final suggestion = service.suggestion;
    if (suggestion == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 2),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 16, color: colors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${eqT(context, 'eq_ai_suggests')} '
                  '${eqT(context, suggestion.preset?.nameKey ?? suggestion.presetId)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                Text(
                  suggestion.contentDetail != null
                      ? '${eqT(context, suggestion.contentLabelKey)}: '
                          '${suggestion.contentDetail}'
                      : '${eqT(context, suggestion.contentLabelKey)} '
                          '${eqT(context, 'eq_ai_detected')}',
                  style: TextStyle(fontSize: 10.5, color: colors.subtle),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: service.applySuggestion,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 30),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(eqT(context, 'eq_apply'),
                style: TextStyle(fontSize: 12, color: colors.accent)),
          ),
          IconButton(
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, color: colors.subtle),
            onPressed: service.dismissSuggestion,
          ),
        ],
      ),
    );
  }
}

// ── curve + spectrum ────────────────────────────────────────────────────────

class _CurvePanel extends StatelessWidget {
  const _CurvePanel({required this.colors, required this.enabled});

  final EqColors colors;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AudioEffectsService>();
    final showSpectrum = service.visualizerEnabled && service.supportsVisualizer;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = eqCurveHeightFor(constraints.maxWidth);
          return Column(
            children: [
              Container(
                height: height,
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (showSpectrum)
                      LiveVisualizer(
                        spectrum: service.spectrum,
                        color: colors.accent,
                        active: enabled,
                      ),
                    CustomPaint(
                      painter: EqCurvePainter(
                        gainsDb: service.viewGains,
                        minDb: EqGrid.minDb,
                        maxDb: EqGrid.maxDb,
                        lineColor: colors.accent,
                        fillColor: colors.accent,
                        gridColor: colors.subtle,
                        enabled: enabled,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              EqFrequencyLabels(
                labels: service.viewFrequencies.map(EqGrid.labelFor).toList(),
                color: colors.subtle,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── band sliders ────────────────────────────────────────────────────────────

class _BandRow extends StatelessWidget {
  const _BandRow({required this.colors, required this.enabled});

  final EqColors colors;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AudioEffectsService>();
    final gains = service.viewGains;
    final freqs = service.viewFrequencies;
    final caps = service.capabilities;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Row(
            children: [
              _BandModeToggle(colors: colors),
              const Spacer(),
              if (caps.isInterpolated)
                Flexible(
                  child: Text(
                    // Honest about what the hardware can do: a 10-band curve on
                    // a 5-band device is interpolated, not exact.
                    '${eqT(context, 'eq_interpolated_prefix')} '
                    '${caps.numberOfBands} '
                    '${eqT(context, 'eq_interpolated_suffix')}',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 9.5, color: colors.subtle),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              for (var i = 0; i < gains.length; i++)
                Expanded(
                  child: EqBandSlider(
                    label: EqGrid.labelFor(freqs[i]),
                    valueDb: gains[i],
                    minDb: EqGrid.minDb,
                    maxDb: EqGrid.maxDb,
                    onChanged: (v) => service.setBandGain(i, v),
                    accent: colors.accent,
                    trackColor: colors.subtle,
                    labelColor: colors.subtle,
                    enabled: enabled,
                    height: gains.length > 5 ? 130 : 150,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BandModeToggle extends StatelessWidget {
  const _BandModeToggle({required this.colors});

  final EqColors colors;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AudioEffectsService>();

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mode in EqBandMode.values)
            GestureDetector(
              onTap: () => service.setBandMode(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: service.bandMode == mode
                      ? colors.accent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  eqT(context,
                      mode == EqBandMode.five ? 'eq_band_5' : 'eq_band_10'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: service.bandMode == mode
                        ? Colors.white
                        : colors.subtle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── actions ─────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.colors,
    required this.enabled,
    required this.compact,
  });

  final EqColors colors;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final service = context.read<AudioEffectsService>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: enabled ? service.reset : null,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: Text(eqT(context, 'eq_reset'),
                  style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.text,
                side: BorderSide(color: colors.subtle.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: enabled ? () => _saveProfile(context, service) : null,
              icon: const Icon(Icons.bookmark_add_rounded, size: 16),
              label: Text(eqT(context, 'eq_save_profile'),
                  style: const TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                // Explicit: without it the label takes the theme's onSurface
                // and renders black on the accent fill.
                foregroundColor: Colors.white,
                disabledBackgroundColor: colors.accent.withValues(alpha: 0.35),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (compact) ...[
            const SizedBox(width: 10),
            IconButton(
              tooltip: eqT(context, 'eq_open_full'),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EqualizerPage(), settings: const RouteSettings(name: 'EqualizerScreen')),
                );
              },
              icon: Icon(Icons.open_in_full_rounded,
                  size: 18, color: colors.subtle),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveProfile(
      BuildContext context, AudioEffectsService service) async {
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eqT(ctx, 'eq_save_profile_title')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 32,
          decoration: InputDecoration(
            hintText: eqT(ctx, 'eq_profile_name_hint'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(eqT(ctx, 'eq_common_cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(eqT(ctx, 'eq_common_save')),
          ),
        ],
      ),
    );
    if (name == null) return;

    final profile = await service.saveProfile(name);
    messenger.showSnackBar(
      SnackBar(
          content: Text(
              '${eqTOnce(context, 'eq_profiles_saved')} "${profile.name}"')),
    );
  }
}

// ── advanced controls ───────────────────────────────────────────────────────

class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection({required this.colors, required this.enabled});

  final EqColors colors;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AudioEffectsService>();
    final s = service.settings;
    final caps = service.capabilities;
    final headphones = service.outputDevice.isHeadphoneLike;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(eqT(context, 'eq_section_effects'), colors),
          if (caps.hasBassBoost)
            EqValueSlider(
              title: eqT(context, 'eq_bass_boost'),
              icon: Icons.speaker_rounded,
              value: s.bassBoost.toDouble(),
              max: 1000,
              trailing: '${(s.bassBoost / 10).round()}%',
              onChanged: (v) => service.setBassBoost(v.round()),
              accent: colors.accent,
              titleColor: colors.text,
              subtitleColor: colors.subtle,
              enabled: enabled,
            ),
          if (caps.hasVirtualizer)
            EqValueSlider(
              title: '3D Surround',
              icon: Icons.surround_sound_rounded,
              value: s.virtualizer.toDouble(),
              max: 1000,
              trailing: '${(s.virtualizer / 10).round()}%',
              subtitle: eqT(context, 'eq_surround_sub'),
              warning: !headphones && s.virtualizer > 0
                  ? eqT(context, 'eq_surround_warning')
                  : null,
              onChanged: (v) => service.setVirtualizer(v.round()),
              accent: colors.accent,
              titleColor: colors.text,
              subtitleColor: colors.subtle,
              enabled: enabled,
            ),
          if (caps.hasLoudness)
            EqValueSlider(
              title: eqT(context, 'eq_volume_boost'),
              icon: Icons.volume_up_rounded,
              value: s.loudnessMb.toDouble(),
              max: 2000,
              trailing: '+${(s.loudnessMb / 100).toStringAsFixed(1)} dB',
              onChanged: (v) => service.setLoudness(v.round()),
              warning: s.loudnessMb > 1000
                  ? eqT(context, 'eq_volume_warning')
                  : null,
              accent: colors.accent,
              titleColor: colors.text,
              subtitleColor: colors.subtle,
              enabled: enabled,
            ),
          if (caps.hasReverb) _ReverbRow(colors: colors, enabled: enabled),

          const SizedBox(height: 10),
          _Header(eqT(context, 'eq_section_channels'), colors),
          _BalanceRow(colors: colors, enabled: enabled),
          _SwitchRow(
            title: eqT(context, 'eq_mono'),
            subtitle: eqT(context, 'eq_mono_sub'),
            icon: Icons.hearing_rounded,
            value: s.mono,
            onChanged: enabled ? service.setMono : null,
            colors: colors,
          ),
          _SwitchRow(
            title: eqT(context, 'eq_dialogue'),
            subtitle: eqT(context, 'eq_dialogue_sub'),
            icon: Icons.record_voice_over_rounded,
            value: s.dialogueDownmix,
            onChanged: enabled ? service.setDialogueDownmix : null,
            colors: colors,
          ),
          _SwitchRow(
            title: eqT(context, 'eq_night'),
            subtitle: eqT(context, 'eq_night_sub'),
            icon: Icons.bedtime_rounded,
            value: s.nightMode,
            onChanged: enabled ? service.setNightMode : null,
            colors: colors,
          ),

          const SizedBox(height: 10),
          _Header(eqT(context, 'eq_section_analysis'), colors),
          _SwitchRow(
            title: eqT(context, 'eq_spectrum'),
            subtitle: service.supportsVisualizer
                ? eqT(context, 'eq_spectrum_sub')
                : eqT(context, 'eq_spectrum_unavailable'),
            icon: Icons.graphic_eq_rounded,
            value: service.visualizerEnabled,
            onChanged: service.supportsVisualizer
                ? (v) => _toggleCapture(context, () => service.setVisualizerEnabled(v))
                : null,
            colors: colors,
          ),
          _SwitchRow(
            title: eqT(context, 'eq_auto'),
            subtitle: eqT(context, 'eq_auto_sub'),
            icon: Icons.auto_awesome_rounded,
            value: service.autoEqEnabled,
            onChanged: service.supportsVisualizer
                ? (v) => _toggleCapture(context, () => service.setAutoEqEnabled(v))
                : null,
            colors: colors,
          ),
          if (!service.hasAudioPermission)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                // Said plainly, because "this app wants the microphone" is
                // alarming and, here, misleading.
                eqT(context, 'eq_permission_note'),
                style: TextStyle(
                    fontSize: 10.5, height: 1.5, color: colors.subtle),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Shows the reason the toggle refused (permission denied), instead of the
  /// switch just snapping back with no explanation.
  Future<void> _toggleCapture(
      BuildContext context, Future<bool> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    // Resolved BEFORE the await — the context may be gone by the time the
    // permission dialog returns.
    final message = eqTOnce(context, 'eq_permission_denied');
    final ok = await action();
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.colors);

  final String title;
  final EqColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 13,
            decoration: BoxDecoration(
              color: colors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: colors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReverbRow extends StatelessWidget {
  const _ReverbRow({required this.colors, required this.enabled});

  final EqColors colors;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AudioEffectsService>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.blur_on_rounded, size: 16, color: colors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              eqT(context, 'eq_reverb'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<ReverbPreset>(
              value: service.settings.reverb,
              isDense: true,
              dropdownColor: colors.card,
              style: TextStyle(fontSize: 12.5, color: colors.text),
              onChanged: enabled
                  ? (v) => v == null ? null : service.setReverb(v)
                  : null,
              items: [
                for (final preset in ReverbPreset.values)
                  DropdownMenuItem(
                      value: preset,
                      child: Text(eqT(context, preset.labelKey))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.colors, required this.enabled});

  final EqColors colors;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AudioEffectsService>();
    final balance = service.settings.balance;
    final label = balance.abs() < 0.02
        ? eqT(context, 'eq_balance_centre')
        : '${balance < 0 ? 'L' : 'R'} ${(balance.abs() * 100).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.compare_arrows_rounded, size: 16, color: colors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                eqT(context, 'eq_balance'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: colors.accent,
            inactiveTrackColor: colors.subtle.withValues(alpha: 0.25),
            thumbColor: colors.accent,
            overlayColor: colors.accent.withValues(alpha: 0.12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: balance,
            min: -1,
            max: 1,
            // Snapping to the centre matters here: a balance stuck at 0.03 is
            // audible on headphones and impossible to correct by dragging.
            divisions: 20,
            onChanged: enabled ? service.setBalance : null,
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EqColors colors;

  @override
  Widget build(BuildContext context) {
    final dim = onChanged == null ? 0.4 : 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.accent.withValues(alpha: dim)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.text.withValues(alpha: dim),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.35,
                    color: colors.subtle.withValues(alpha: dim),
                  ),
                ),
              ],
            ),
          ),
          EqSwitch(value: value, onChanged: onChanged, colors: colors),
        ],
      ),
    );
  }
}
