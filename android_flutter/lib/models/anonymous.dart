import 'parsing.dart';

class AnonymousLink {
  const AnonymousLink({
    required this.shortCode,
    required this.isEnabled,
  });

  final String shortCode;
  final bool isEnabled;

  factory AnonymousLink.fromMap(Map<String, dynamic> map) {
    return AnonymousLink(
      shortCode: map['short_code'].toString(),
      isEnabled: parseBool(map['is_enabled']),
    );
  }
}

class AnonymousDoodle {
  const AnonymousDoodle({
    required this.id,
    required this.contentBase64,
    required this.senderFingerprint,
    required this.createdAt,
  });

  final String id;
  final String contentBase64;
  final String? senderFingerprint;
  final DateTime? createdAt;

  factory AnonymousDoodle.fromMap(Map<String, dynamic> map) {
    return AnonymousDoodle(
      id: map['id'].toString(),
      contentBase64: map['content_base64'].toString(),
      senderFingerprint: parseString(map['sender_fingerprint']),
      createdAt: parseDateTime(map['created_at']),
    );
  }
}
