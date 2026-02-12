import 'parsing.dart';

class FriendRequestRow {
  const FriendRequestRow({
    required this.requestId,
    required this.requesterProfileId,
    required this.requesterUsername,
    required this.requesterAvatarUrl,
    required this.createdAt,
  });

  final String requestId;
  final String requesterProfileId;
  final String requesterUsername;
  final String? requesterAvatarUrl;
  final DateTime? createdAt;

  factory FriendRequestRow.fromMap(Map<String, dynamic> map) {
    return FriendRequestRow(
      requestId: map['request_id']?.toString() ?? '',
      requesterProfileId: map['requester_profile_id']?.toString() ?? '',
      requesterUsername: map['requester_username']?.toString() ?? '',
      requesterAvatarUrl: parseString(map['requester_avatar_url']),
      createdAt: parseDateTime(map['created_at']),
    );
  }
}
