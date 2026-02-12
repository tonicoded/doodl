import 'parsing.dart';

class InboxSender {
  const InboxSender({
    required this.profileId,
    required this.username,
    required this.avatarUrl,
    required this.unreadCount,
    required this.lastCreatedAt,
  });

  final String profileId;
  final String username;
  final String? avatarUrl;
  final int unreadCount;
  final DateTime? lastCreatedAt;

  factory InboxSender.fromMap(Map<String, dynamic> map) {
    return InboxSender(
      profileId: map['sender_profile_id'].toString(),
      username: map['sender_username'].toString(),
      avatarUrl: parseString(map['sender_avatar_url']),
      unreadCount: parseInt(map['unread_count']),
      lastCreatedAt: parseDateTime(map['last_created_at']),
    );
  }
}
