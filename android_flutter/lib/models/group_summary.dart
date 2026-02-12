import 'parsing.dart';

class GroupSummaryRow {
  const GroupSummaryRow({
    required this.code,
    required this.displayName,
    required this.ownerProfileId,
    required this.memberCount,
    required this.createdAt,
  });

  final String code;
  final String? displayName;
  final String? ownerProfileId;
  final int memberCount;
  final DateTime? createdAt;

  factory GroupSummaryRow.fromMap(Map<String, dynamic> map) {
    return GroupSummaryRow(
      code: map['code']?.toString() ?? '',
      displayName: parseString(map['display_name']),
      ownerProfileId: parseString(map['owner_profile_id']),
      memberCount: int.tryParse(map['member_count']?.toString() ?? '') ?? 0,
      createdAt: parseDateTime(map['created_at']),
    );
  }
}
