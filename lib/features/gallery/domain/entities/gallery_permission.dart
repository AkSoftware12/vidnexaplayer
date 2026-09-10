/// Outcome of the module's single permission gate.
///
/// The old `lib/Photo/image_album.dart` asked for permission separately on
/// every screen; the module asks once at its root and every page reads the
/// result from the controller.
enum GalleryPermission {
  granted,

  /// Android 14+ "selected photos only". Everything works, but only over the
  /// subset the user picked, so the UI offers a way to widen the selection.
  limited,

  denied;

  bool get canRead => this != GalleryPermission.denied;
}
