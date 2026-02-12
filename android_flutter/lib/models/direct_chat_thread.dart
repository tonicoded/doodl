import 'parsing.dart';

class DirectChatThread {
  const DirectChatThread({
    required this.code,
    required this.otherProfileId,
    required this.otherUsername,
    required this.otherAvatarUrl,
    required this.lastCreatedAt,
    required this.hasUnread,
    required this.streakCount,
  });

  final String code;
  final String otherProfileId;
  final String otherUsername;
  final String? otherAvatarUrl;
  final DateTime? lastCreatedAt;
  final bool hasUnread;
  final int streakCount;

  factory DirectChatThread.fromMap(Map<String, dynamic> map) {
    return DirectChatThread(
      code: map['code']?.toString() ?? '',
      otherProfileId: map['other_profile_id']?.toString() ?? '',
      otherUsername: map['other_username']?.toString() ?? '',
      otherAvatarUrl: parseString(map['other_avatar_url']),
      lastCreatedAt: parseDateTime(map['last_created_at']),
      hasUnread: (map['has_unread'] == true) ||
          (map['has_unread']?.toString() == 'true'),
      streakCount: int.tryParse(map['streak_count']?.toString() ?? '') ?? 0,
    );
  }
}
