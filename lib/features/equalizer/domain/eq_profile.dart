import 'dart:convert';

import 'eq_models.dart';

/// A user-saved EQ curve ("Mera Bass", "Late Night", "Gym").
///
/// A profile stores the whole [EqSettings] value, not just the band gains, so
/// restoring one brings back bass boost / virtualizer / night mode with it —
/// otherwise "Gym" would sound different depending on what the user had toggled
/// last.
class EqProfile {
  const EqProfile({
    required this.id,
    required this.name,
    required this.settings,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final EqSettings settings;
  final DateTime createdAt;
  final DateTime updatedAt;

  EqProfile copyWith({
    String? name,
    EqSettings? settings,
    DateTime? updatedAt,
  }) =>
      EqProfile(
        id: id,
        name: name ?? this.name,
        settings: settings ?? this.settings,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        // presetId is meaningless once saved — the profile IS the identity.
        'settings': settings.copyWith(presetId: id).toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory EqProfile.fromJson(Map<dynamic, dynamic> json) {
    final now = DateTime.now();
    return EqProfile(
      id: json['id'] as String? ?? now.microsecondsSinceEpoch.toString(),
      name: (json['name'] as String? ?? 'Profile').trim(),
      settings: EqSettings.fromJson(
        (json['settings'] as Map?) ?? const <String, dynamic>{},
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? now,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? now,
    );
  }

  // ── share / import ───────────────────────────────────────────────────────

  static const String _magic = 'vidnexa.eq';
  static const int _schema = 1;

  /// One-line JSON the user can share over WhatsApp / a text file.
  String toShareString() => jsonEncode({
        'app': _magic,
        'schema': _schema,
        'profile': toJson(),
      });

  /// Parses a shared profile. Returns null for anything that is not ours or
  /// is malformed — pasted text is untrusted input, so this never throws.
  static EqProfile? tryParseShareString(String raw) {
    try {
      final decoded = jsonDecode(raw.trim());
      if (decoded is! Map) return null;
      if (decoded['app'] != _magic) return null;
      if ((decoded['schema'] as num?)?.toInt() != _schema) return null;
      final body = decoded['profile'];
      if (body is! Map) return null;

      final parsed = EqProfile.fromJson(body);
      // Imported profiles get a fresh id so they cannot silently overwrite one
      // the user already has under the same generated id.
      return EqProfile(
        id: newId(),
        name: parsed.name.isEmpty ? 'Imported' : parsed.name,
        settings: parsed.settings,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static String newId() =>
      'p${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
}
