import 'parsing.dart';

class GroupInvite {
  const GroupInvite({
    required this.inviteId,
    required this.groupCode,
    required this.inviterUsername,
    required this.status,
    required this.createdAt,
  });

  final String inviteId;
  final String groupCode;
  final String inviterUsername;
  final String status;
  final DateTime? createdAt;

  factory GroupInvite.fromMap(Map<String, dynamic> map) {
    return GroupInvite(
      inviteId: map['invite_id'].toString(),
      groupCode: map['group_code'].toString(),
      inviterUsername: map['inviter_username'].toString(),
      status: map['status'].toString(),
      createdAt: parseDateTime(map['created_at']),
    );
  }
}
