import 'parsing.dart';

class Doodle {
  const Doodle({
    required this.doodleId,
    required this.contentBase64,
    required this.senderUsername,
    required this.createdAt,
    this.senderProfileId,
  });

  final String doodleId;
  final String contentBase64;
  final String senderUsername;
  final DateTime? createdAt;
  final String? senderProfileId;

  factory Doodle.fromInboxMap(Map<String, dynamic> map) {
    return Doodle(
      doodleId: map['doodle_id'].toString(),
      senderProfileId: parseString(map['sender_profile_id']),
      contentBase64: map['content_base64'].toString(),
      senderUsername: map['sender_username'].toString(),
      createdAt: parseDateTime(map['created_at']),
    );
  }

  factory Doodle.fromThreadMap(Map<String, dynamic> map) {
    return Doodle(
      doodleId: map['doodle_id'].toString(),
      contentBase64: map['content_base64'].toString(),
      senderUsername: map['sender_username'].toString(),
      createdAt: parseDateTime(map['created_at']),
    );
  }
}
