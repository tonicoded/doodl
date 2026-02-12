import 'parsing.dart';

class GroupMember {
  const GroupMember({
    required this.profileId,
    required this.username,
    required this.avatarUrl,
    required this.streakCount,
    required this.isOnline,
  });

  final String profileId;
  final String username;
  final String? avatarUrl;
  final int streakCount;
  final bool isOnline;

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      profileId: map['profile_id'].toString(),
      username: map['username'].toString(),
      avatarUrl: parseString(map['avatar_url']),
      streakCount: parseInt(map['streak_count']),
      isOnline: parseBool(map['is_online']),
    );
  }
}
