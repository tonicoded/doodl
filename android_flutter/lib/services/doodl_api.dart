import 'package:supabase_flutter/supabase_flutter.dart';

class DoodlApi {
  DoodlApi(this.client);

  final SupabaseClient client;

  static DoodlApi get shared => DoodlApi(Supabase.instance.client);

  String _cleanString(dynamic value) =>
      value.toString().replaceAll('"', '').trim();

  List<Map<String, dynamic>> _asListOfMaps(dynamic value) {
    if (value is List) {
      return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> createProfile({
    required String username,
    required String pairingCode,
    String? avatarUrl,
  }) async {
    final res = await client.rpc(
      'create_profile_secure',
      params: {
        'p_username': username.toLowerCase(),
        'p_pairing_code': pairingCode.toLowerCase(),
        'p_avatar_url': avatarUrl,
      },
    );
    // Supabase RPC returns List<dynamic> for table results.
    if (res is List && res.isNotEmpty && res.first is Map) {
      return Map<String, dynamic>.from(res.first as Map);
    }
    throw Exception('profile create failed');
  }

  Future<void> updateAvatar({
    required String profileId,
    required String pairingCode,
    required String avatarUrl,
  }) async {
    await client.rpc(
      'update_avatar_secure',
      params: {
        'p_profile_id': profileId,
        'p_profile_pairing_code': pairingCode.toLowerCase().trim(),
        'p_avatar_url': avatarUrl,
      },
    );
  }

  Future<void> deleteProfile({
    required String profileId,
    required String pairingCode,
  }) async {
    await client.rpc(
      'delete_profile_secure',
      params: {
        'p_profile_id': profileId,
        'p_profile_pairing_code': pairingCode.toLowerCase().trim(),
      },
    );
  }

  Future<void> upsertFcmDevice({
    required String profileId,
    required String pairingCode,
    required String fcmToken,
  }) async {
    await client.rpc(
      'upsert_profile_fcm_device_secure',
      params: {
        'p_profile_id': profileId,
        'p_profile_pairing_code': pairingCode.toLowerCase().trim(),
        'p_fcm_token': fcmToken.trim(),
      },
    );
  }

  Future<void> updateUsername({
    required String profileId,
    required String pairingCode,
    required String newUsername,
  }) async {
    await client.rpc(
      'update_username_secure',
      params: {
        'p_profile_id': profileId,
        'p_profile_pairing_code': pairingCode.toLowerCase().trim(),
        'p_new_username': newUsername.toLowerCase().trim(),
      },
    );
  }

  Future<String?> fetchProfileId({
    required String username,
    required String pairingCode,
  }) async {
    final res = await client.rpc(
      'fetch_profile_id_secure',
      params: {
        'p_username': username.toLowerCase(),
        'p_pairing_code': pairingCode.toLowerCase(),
      },
    );
    if (res == null) return null;
    return _cleanString(res);
  }

  Future<List<Map<String, dynamic>>> searchProfiles({
    required String query,
    String? excludeProfileId,
    int limit = 10,
  }) async {
    final res = await client.rpc(
      'search_profiles_secure',
      params: {
        'p_query': query.toLowerCase().trim(),
        'p_limit': limit.clamp(1, 20),
        'p_exclude_profile_id': excludeProfileId,
      },
    );
    return _asListOfMaps(res);
  }

  // MARK: - Friends / direct chats

  Future<String> sendFriendRequest({
    required String profileId,
    required String pairingCode,
    required String targetUsername,
  }) async {
    final res = await client.rpc(
      'send_friend_request_secure',
      params: {
        'p_profile_id': profileId,
        'p_profile_pairing_code': pairingCode.toLowerCase().trim(),
        'p_target_username': targetUsername.toLowerCase().trim(),
      },
    );
    return _cleanString(res);
  }

  Future<List<Map<String, dynamic>>> listFriendRequests({
    required String profileId,
    required String pairingCode,
    int limit = 50,
  }) async {
    final res = await client.rpc(
      'list_friend_requests_secure',
      params: {
        'p_profile_id': profileId,
        'p_profile_pairing_code': pairingCode.toLowerCase().trim(),
        'p_limit': limit.clamp(1, 200),
      },
    );
    return _asListOfMaps(res);
  }

  Future<Map<String, dynamic>> respondFriendRequest({
    required String requestId,
    required String profileId,
    required String pairingCode,
    required bool accept,
  }) async {
    final res = await client.rpc(
      'respond_friend_request_secure',
      params: {
        'p_request_id': requestId,
        'p_profile_id': profileId,
        'p_profile_pairing_code': pairingCode.toLowerCase().trim(),
        'p_accept': accept,
      },
    );
    final rows = _asListOfMaps(res);
    if (rows.isEmpty) throw Exception('request respond failed');
    return rows.first;
  }

  Future<List<Map<String, dynamic>>> listDirectChats({
    required String profileId,
    required String pairingCode,
    int limit = 60,
  }) async {
    final res = await client.rpc(
      'list_direct_chats_secure_v2',
      params: {
        'p_profile_id': profileId,
        'p_profile_pairing_code': pairingCode.toLowerCase().trim(),
        'p_limit': limit.clamp(1, 200),
      },
    );
    return _asListOfMaps(res);
  }

  Future<void> removeFriend({
    required String profileId,
    required String pairingCode,
    required String friendProfileId,
  }) async {
    await client.rpc(
      'remove_friend_secure',
      params: {
        'p_profile_id': profileId,
        'p_profile_pairing_code': pairingCode.toLowerCase().trim(),
        'p_friend_profile_id': friendProfileId,
      },
    );
  }

  // MARK: - Groups

  Future<String> ensureGroup({
    required String code,
    required String profileId,
    required String pairingCode,
  }) async {
    final res = await client.rpc(
      'ensure_group_secure',
      params: {
        'p_code': code.toLowerCase().trim(),
        'p_profile_id': profileId,
        'p_profile_pairing_code': pairingCode.toLowerCase().trim(),
      },
    );
    return _cleanString(res);
  }

  Future<void> joinGroup({
    required String code,
    required String profileId,
    required String pairingCode,
  }) async {
    await client.rpc(
      'join_group_secure',
      params: {
        'p_code': code.toLowerCase().trim(),
        'p_profile_id': profileId,
        'p_profile_pairing_code': pairingCode.toLowerCase().trim(),
      },
    );
  }

  Future<void> leaveGroup({
    required String code,
    required String profileId,
    required String pairingCode,
  }) async {
    await client.rpc(
      'leave_group_secure',
      params: {
        'p_code': code.toLowerCase().trim(),
        'p_profile_id': profileId,
        'p_profile_pairing_code': pairingCode.toLowerCase().trim(),
      },
    );
  }

  Future<String?> fetchGroupOwner({
    required String code,
  }) async {
    final res = await client.rpc(
      'fetch_group_owner_secure',
      params: {'p_code': code.toLowerCase().trim()},
    );
    final owner = _cleanString(res);
    if (owner.isEmpty) return null;
    return owner;
  }

  Future<String> removeMember({
    required String code,
    required String requesterProfileId,
    required String requesterPairingCode,
    required String memberProfileId,
  }) async {
    final res = await client.rpc(
      'remove_member_secure',
      params: {
        'p_code': code.toLowerCase().trim(),
        'p_requester_profile_id': requesterProfileId,
        'p_requester_pairing_code': requesterPairingCode.toLowerCase().trim(),
        'p_member_profile_id': memberProfileId,
      },
    );
    return _cleanString(res);
  }

  Future<List<Map<String, dynamic>>> groupMembers({
    required String code,
    required String requesterProfileId,
  }) async {
    final res = await client.rpc(
      'group_members_secure',
      params: {
        'p_code': code.toLowerCase().trim(),
        'requester_profile_id': requesterProfileId,
      },
    );
    return _asListOfMaps(res);
  }

  Future<List<Map<String, dynamic>>> groupMemberCounts({
    required List<String> codes,
    required String requesterProfileId,
  }) async {
    final res = await client.rpc(
      'group_member_counts_secure',
      params: {
        'p_codes': codes.map((e) => e.toLowerCase().trim()).toList(),
        'p_requester_profile_id': requesterProfileId,
      },
    );
    return _asListOfMaps(res);
  }

  Future<List<Map<String, dynamic>>> listGroupsV2({
    required String profileId,
    required String pairingCode,
    int limit = 50,
  }) async {
    final res = await client.rpc(
      'list_groups_v2_secure',
      params: {
        'p_profile_id': profileId,
        'p_profile_pairing_code': pairingCode.toLowerCase().trim(),
        'p_limit': limit.clamp(1, 200),
      },
    );
    return _asListOfMaps(res);
  }

  Future<Map<String, dynamic>> createGroupV2({
    required String profileId,
    required String pairingCode,
    String? displayName,
  }) async {
    final res = await client.rpc(
      'create_group_v2_secure',
      params: {
        'p_profile_id': profileId,
        'p_profile_pairing_code': pairingCode.toLowerCase().trim(),
        'p_display_name': displayName,
      },
    );
    final rows = _asListOfMaps(res);
    if (rows.isEmpty) throw Exception('group create failed');
    return rows.first;
  }

  // MARK: - Invites

  Future<String> inviteToGroup({
    required String groupCode,
    required String inviterProfileId,
    required String invitedUsername,
  }) async {
    final res = await client.rpc(
      'invite_to_group_secure',
      params: {
        'p_group_code': groupCode.toLowerCase().trim(),
        'p_inviter_profile_id': inviterProfileId,
        'p_invited_username': invitedUsername.toLowerCase().trim(),
      },
    );
    return _cleanString(res);
  }

  Future<List<Map<String, dynamic>>> listInvites({
    required String profileId,
  }) async {
    final res = await client.rpc(
      'list_invites_secure',
      params: {'p_profile_id': profileId},
    );
    return _asListOfMaps(res);
  }

  Future<String> respondInvite({
    required String inviteId,
    required String profileId,
    required String pairingCode,
    required bool accept,
  }) async {
    final res = await client.rpc(
      'respond_invite_secure',
      params: {
        'p_invite_id': inviteId,
        'p_profile_id': profileId,
        'p_profile_pairing_code': pairingCode.toLowerCase().trim(),
        'p_accept': accept,
      },
    );
    return _cleanString(res);
  }

  // MARK: - Doodles

  Future<String> createDoodle({
    required String code,
    required String senderProfileId,
    required String senderPairingCode,
    required String contentBase64,
  }) async {
    final res = await client.rpc(
      'create_doodle_secure',
      params: {
        'p_code': code.toLowerCase().trim(),
        'p_sender_profile_id': senderProfileId,
        'p_content_base64': contentBase64,
        'p_sender_pairing_code': senderPairingCode.toLowerCase().trim(),
      },
    );
    return _cleanString(res);
  }

  Future<List<Map<String, dynamic>>> inboxDoodles({
    required String code,
    required String requesterProfileId,
    int limit = 50,
  }) async {
    final res = await client.rpc(
      'inbox_doodles_secure',
      params: {
        'p_code': code.toLowerCase().trim(),
        'p_requester_profile_id': requesterProfileId,
        'p_limit': limit.clamp(1, 200),
      },
    );
    return _asListOfMaps(res);
  }

  Future<List<Map<String, dynamic>>> inboxSenders({
    required String code,
    required String requesterProfileId,
  }) async {
    final res = await client.rpc(
      'inbox_senders_secure',
      params: {
        'p_code': code.toLowerCase().trim(),
        'p_requester_profile_id': requesterProfileId,
      },
    );
    return _asListOfMaps(res);
  }

  Future<List<Map<String, dynamic>>> inboxDoodleMetas({
    required String code,
    required String requesterProfileId,
    int limit = 50,
  }) async {
    final res = await client.rpc(
      'inbox_doodle_metas_secure',
      params: {
        'p_code': code.toLowerCase().trim(),
        'p_requester_profile_id': requesterProfileId,
        'p_limit': limit.clamp(1, 200),
      },
    );
    return _asListOfMaps(res);
  }

  Future<Map<String, String>> doodleContents({
    required String code,
    required String requesterProfileId,
    required List<String> doodleIds,
  }) async {
    final res = await client.rpc(
      'doodle_contents_secure',
      params: {
        'p_code': code.toLowerCase().trim(),
        'p_requester_profile_id': requesterProfileId,
        'p_doodle_ids': doodleIds,
      },
    );
    final rows = _asListOfMaps(res);
    final map = <String, String>{};
    for (final row in rows) {
      final id = row['doodle_id']?.toString() ?? '';
      final content = row['content_base64']?.toString();
      if (id.isNotEmpty && content != null && content.isNotEmpty) {
        map[id] = content;
      }
    }
    return map;
  }

  Future<List<Map<String, dynamic>>> threadDoodles({
    required String code,
    required String requesterProfileId,
    required String requesterPairingCode,
    required String senderProfileId,
    int limit = 200,
  }) async {
    final res = await client.rpc(
      'thread_doodles_secure',
      params: {
        'p_code': code.toLowerCase().trim(),
        'p_requester_profile_id': requesterProfileId,
        'p_requester_pairing_code': requesterPairingCode.toLowerCase().trim(),
        'p_sender_profile_id': senderProfileId,
        'p_limit': limit.clamp(1, 400),
      },
    );
    return _asListOfMaps(res);
  }

  // MARK: - Anonymous

  Future<Map<String, dynamic>> setAnonymousLinkEnabled({
    required String profileId,
    required String pairingCode,
    required bool enabled,
  }) async {
    final res = await client.rpc(
      'set_anonymous_link_enabled_secure',
      params: {
        'p_profile_id': profileId,
        'p_profile_pairing_code': pairingCode.toLowerCase().trim(),
        'p_enabled': enabled,
      },
    );
    final rows = _asListOfMaps(res);
    if (rows.isEmpty) throw Exception('anonymous link update failed');
    return rows.first;
  }

  Future<Map<String, dynamic>?> getAnonymousLink({
    required String profileId,
    required String pairingCode,
  }) async {
    final res = await client.rpc(
      'get_anonymous_link_secure',
      params: {
        'p_profile_id': profileId,
        'p_profile_pairing_code': pairingCode.toLowerCase().trim(),
      },
    );
    final rows = _asListOfMaps(res);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<bool> anonymousLinkIsEnabledPublic({
    required String shortCode,
  }) async {
    final res = await client.rpc(
      'anonymous_link_is_enabled_public',
      params: {'p_short_code': shortCode.toLowerCase().trim()},
    );
    if (res is bool) return res;
    return _cleanString(res) == 'true';
  }

  Future<String> submitAnonymousDoodle({
    required String shortCode,
    required String contentBase64,
    String? senderFingerprint,
  }) async {
    final res = await client.rpc(
      'submit_anonymous_doodle',
      params: {
        'p_short_code': shortCode.toLowerCase().trim(),
        'p_content_base64': contentBase64,
        'p_sender_fingerprint': senderFingerprint,
      },
    );
    return _cleanString(res);
  }

  Future<List<Map<String, dynamic>>> anonymousInboxDoodles({
    required String profileId,
    required String pairingCode,
    int limit = 50,
  }) async {
    final res = await client.rpc(
      'anonymous_inbox_doodles_secure',
      params: {
        'p_profile_id': profileId,
        'p_profile_pairing_code': pairingCode.toLowerCase().trim(),
        'p_limit': limit.clamp(1, 200),
      },
    );
    return _asListOfMaps(res);
  }

  Future<List<Map<String, dynamic>>> searchAnonymousReceivers({
    required String requesterProfileId,
    required String requesterPairingCode,
    required String query,
    int limit = 12,
  }) async {
    final res = await client.rpc(
      'search_anonymous_receivers_secure',
      params: {
        'p_requester_profile_id': requesterProfileId,
        'p_requester_pairing_code': requesterPairingCode.toLowerCase().trim(),
        'p_query': query.toLowerCase().trim(),
        'p_limit': limit.clamp(1, 20),
      },
    );
    return _asListOfMaps(res);
  }

  Future<String> submitAnonymousDoodleToProfile({
    required String senderProfileId,
    required String senderPairingCode,
    required String recipientProfileId,
    required String contentBase64,
    String? senderFingerprint,
  }) async {
    final res = await client.rpc(
      'submit_anonymous_doodle_to_profile_secure',
      params: {
        'p_sender_profile_id': senderProfileId,
        'p_sender_pairing_code': senderPairingCode.toLowerCase().trim(),
        'p_recipient_profile_id': recipientProfileId,
        'p_content_base64': contentBase64,
        'p_sender_fingerprint': senderFingerprint,
      },
    );
    return _cleanString(res);
  }

  // MARK: - Moderation (App Store UGC compliance)

  Future<void> blockProfile({
    required String profileId,
    required String pairingCode,
    required String blockedProfileId,
  }) async {
    await client.rpc(
      'block_profile_secure',
      params: {
        'p_profile_id': profileId,
        'p_profile_pairing_code': pairingCode.toLowerCase().trim(),
        'p_blocked_profile_id': blockedProfileId,
      },
    );
  }

  Future<void> unblockProfile({
    required String profileId,
    required String pairingCode,
    required String blockedProfileId,
  }) async {
    await client.rpc(
      'unblock_profile_secure',
      params: {
        'p_profile_id': profileId,
        'p_profile_pairing_code': pairingCode.toLowerCase().trim(),
        'p_blocked_profile_id': blockedProfileId,
      },
    );
  }

  Future<String> reportContent({
    required String profileId,
    required String pairingCode,
    required String contentKind, // 'group_doodle' | 'anonymous_doodle'
    required String contentId,
    String? reason,
  }) async {
    final res = await client.rpc(
      'report_content_secure',
      params: {
        'p_profile_id': profileId,
        'p_profile_pairing_code': pairingCode.toLowerCase().trim(),
        'p_content_kind': contentKind,
        'p_content_id': contentId,
        'p_reason': reason,
      },
    );
    return _cleanString(res);
  }
}
