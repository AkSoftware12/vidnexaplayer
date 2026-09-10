import 'dart:convert';

/// One push notification, kept after it was delivered so the in-app
/// Notifications screen has something to show.
///
/// Firebase hands a message to the app once and forgets it; the system tray
/// entry disappears the moment it is swiped. Persisting them here is what
/// turns "you got a push" into a list the user can come back to.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.imageUrl,
    this.readAt,
    this.data = const {},
  });

  /// Firebase's `messageId` when there is one, otherwise the arrival time.
  /// Used to avoid storing the same push twice — a message can reach both the
  /// background handler and `getInitialMessage` when the app is opened by
  /// tapping it.
  final String id;

  final String title;
  final String body;
  final String? imageUrl;

  final int receivedAt;

  /// When the user actually saw it. Null means still unread, which is what
  /// drives the NEW badge.
  final int? readAt;

  final Map<String, String> data;

  bool get isUnread => readAt == null;

  DateTime get receivedDate => DateTime.fromMillisecondsSinceEpoch(receivedAt);

  /// How long a read notification is kept before it disappears on its own.
  static const Duration keepAfterRead = Duration(hours: 24);

  /// True once this has been read and the keep-window has passed.
  ///
  /// Unread notifications never expire — something the user has not seen yet
  /// should not vanish before they get a chance to look at it.
  bool isExpired(DateTime now) {
    final seen = readAt;
    if (seen == null) return false;
    return now
            .difference(DateTime.fromMillisecondsSinceEpoch(seen))
            .compareTo(keepAfterRead) >
        0;
  }

  AppNotification copyWith({int? readAt}) => AppNotification(
    id: id,
    title: title,
    body: body,
    imageUrl: imageUrl,
    receivedAt: receivedAt,
    readAt: readAt ?? this.readAt,
    data: data,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'imageUrl': imageUrl,
    'receivedAt': receivedAt,
    'readAt': readAt,
    'data': data,
  };

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
    id: map['id'] as String? ?? '',
    title: map['title'] as String? ?? '',
    body: map['body'] as String? ?? '',
    imageUrl: map['imageUrl'] as String?,
    receivedAt: map['receivedAt'] as int? ?? 0,
    readAt: map['readAt'] as int?,
    data:
        (map['data'] as Map?)?.map(
          (key, value) => MapEntry('$key', '$value'),
        ) ??
        const {},
  );

  String encode() => jsonEncode(toMap());

  static AppNotification? decode(String raw) {
    try {
      return AppNotification.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A row written by an older build, or corrupt. Dropping one entry beats
      // losing the whole list.
      return null;
    }
  }
}
