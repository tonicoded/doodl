import 'parsing.dart';

class GroupMemberCount {
  const GroupMemberCount({
    required this.code,
    required this.memberCount,
    required this.maxMembers,
  });

  final String code;
  final int memberCount;
  final int maxMembers;

  factory GroupMemberCount.fromMap(Map<String, dynamic> map) {
    return GroupMemberCount(
      code: map['code'].toString(),
      memberCount: parseInt(map['member_count']),
      maxMembers: parseInt(map['max_members'], fallback: 15),
    );
  }
}
