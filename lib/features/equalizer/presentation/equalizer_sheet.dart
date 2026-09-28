import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../audio_effects_service.dart';
import '../domain/eq_models.dart';
import 'equalizer_page.dart';

/// Quick-access equalizer, opened from over the player.
///
/// Renders the SAME [EqualizerBody] as the full page in compact mode, so the
/// two views can never drift apart. Every change applies instantly and nothing
/// here touches playback — the sheet can be opened and dismissed mid-scene.
Future<void> showEqualizerSheet(
  BuildContext context, {
  required MediaType mediaType,
}) async {
  final service = context.read<AudioEffectsService>();
  await service.init();
  await service.setActiveMediaType(mediaType);

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    // The player sits behind a barrier the user can tap to dismiss, so the
    // video stays visible while they adjust — that is the whole point of the
    // sheet over the full page.
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (sheetContext) => ChangeNotifierProvider<AudioEffectsService>.value(
      value: service,
      // The colours MUST be resolved inside a build, not out here: EqColors.of
      // watches the theme provider, and `context.watch` from an event handler
      // (which is all this function is) throws.
      child: Builder(
        builder: (context) {
          final colors = EqColors.of(context);
          return DraggableScrollableSheet(
            // 60%, not 78%: the compact body ends at the Reset / Save row, so a
            // taller sheet just added dead white space under it. Dragging up
            // still expands to maxChildSize.
            initialChildSize: 0.60,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, controller) => Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.subtle.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: PrimaryScrollController(
                      controller: controller,
                      child: const EqualizerBody(compact: true),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// Opens the full-screen equalizer, carrying the service across navigators.
Future<void> openEqualizerPage(
  BuildContext context, {
  MediaType? mediaType,
}) {
  final service = context.read<AudioEffectsService>();
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: 'EqualizerScreen'),
      builder: (_) => ChangeNotifierProvider<AudioEffectsService>.value(
        value: service,
        child: EqualizerPage(mediaType: mediaType),
      ),
    ),
  );
}
