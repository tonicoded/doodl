import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/strings_provider.dart';
import '../../models/group_summary.dart';
import '../../models/onboarding.dart';
import '../../services/doodl_api.dart';
import '../../storage/onboarding_storage.dart';
import '../../widgets/doodl_page.dart';

class GroupScreen extends ConsumerStatefulWidget {
  const GroupScreen({super.key, required this.groupCode});

  final String groupCode;

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  OnboardingData? onboarding;
  bool booting = true;

  bool loading = false;
  String? error;

  GroupSummaryRow? group;
  List<_Member> members = const [];
  String? ownerProfileId;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final data = await OnboardingStorage.load();
    if (!mounted) return;
    setState(() {
      onboarding = data;
      booting = false;
    });
    if (data != null) {
      unawaited(_refresh(force: false));
    }
  }

  Future<void> _refresh({required bool force}) async {
    if (loading && !force) return;
    final data = onboarding;
    if (data == null) return;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = DoodlApi.shared;
      final results = await Future.wait([
        api.listGroupsV2(
            profileId: data.profileId,
            pairingCode: data.pairingCode,
            limit: 100),
        api.groupMembers(
            code: widget.groupCode, requesterProfileId: data.profileId),
        api.fetchGroupOwner(code: widget.groupCode),
      ]);

      final groupRows = (results[0] as List).cast<Map<String, dynamic>>();
      final memberRows = (results[1] as List).cast<Map<String, dynamic>>();
      final ownerId = results[2] as String?;

      final normalized = widget.groupCode.trim().toLowerCase();
      final found = groupRows
          .map(GroupSummaryRow.fromMap)
          .where((g) => g.code.trim().toLowerCase() == normalized)
          .toList();
      final nextGroup = found.isEmpty ? null : found.first;

      final nextMembers = memberRows.map(_Member.fromMap).toList()
        ..sort((a, b) =>
            a.username.toLowerCase().compareTo(b.username.toLowerCase()));

      if (!mounted) return;
      setState(() {
        group = nextGroup;
        members = nextMembers;
        ownerProfileId = ownerId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String get _displayName {
    final name = (group?.displayName ?? '').trim();
    if (name.isNotEmpty) return name;
    return ref.read(stringsProvider).group;
  }

  Future<void> _openInvite() async {
    final data = onboarding;
    if (data == null) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
          child: _InviteMemberSheet(
            groupCode: widget.groupCode,
            myProfileId: data.profileId,
            onInvited: () {
              if (context.mounted) Navigator.of(context).pop();
              if (mounted) unawaited(_refresh(force: true));
            },
          ),
        );
      },
    );
  }

  Future<void> _leaveGroup() async {
    final data = onboarding;
    if (data == null) return;
    final strings = ref.read(stringsProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(strings.leaveGroup),
          content: Text(strings.deleteAccountConfirmBody),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(strings.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(strings.leaveGroup),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    try {
      await DoodlApi.shared.leaveGroup(
        code: widget.groupCode,
        profileId: data.profileId,
        pairingCode: data.pairingCode,
      );
      await OnboardingStorage.removeJoinedCode(widget.groupCode);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Leave failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);

    if (booting) {
      return const DoodlPage(child: Center(child: CircularProgressIndicator()));
    }
    if (onboarding == null) {
      return DoodlPage(child: Center(child: Text(strings.notSignedIn)));
    }

    return DoodlPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _topBar(),
          const SizedBox(height: 12),
          _headerCard(),
          if (error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withOpacity(0.10)),
              ),
              child: Text(error!,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
          const SizedBox(height: 12),
          _membersCard(),
        ],
      ),
    );
  }

  Widget _topBar() {
    final strings = ref.watch(stringsProvider);
    return Row(
      children: [
        IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
        IconButton(
          onPressed: loading ? null : () => _refresh(force: true),
          icon: const Icon(Icons.refresh_rounded),
          tooltip: strings.loading,
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: const Color(0xFFFFFC00)),
          onPressed: _openInvite,
          child: const Icon(Icons.person_add_alt_1_rounded),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          itemBuilder: (context) => [
            PopupMenuItem(value: 'leave', child: Text(strings.leaveGroup)),
          ],
          onSelected: (v) {
            if (v == 'leave') unawaited(_leaveGroup());
          },
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.more_horiz_rounded),
          ),
        ),
      ],
    );
  }

  Widget _headerCard() {
    final subtitle =
        '${members.length}/15 ${ref.watch(stringsProvider).members.toLowerCase()}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_displayName,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _membersCard() {
    final strings = ref.watch(stringsProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.86),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(strings.members,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const Spacer(),
              if (loading)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 10),
          if (!loading && members.isEmpty)
            Text(
              strings.noGroupsYet,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Colors.black54),
            )
          else
            Column(
              children: [
                for (final m in members) ...[
                  _memberRow(m),
                  const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _memberRow(_Member m) {
    final initials = _initials(m.username);
    final data = onboarding;
    final isMe = data != null && m.profileId == data.profileId;
    final isOwner = data != null &&
        ownerProfileId != null &&
        ownerProfileId == data.profileId;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onLongPress:
          isMe ? null : () => _openMemberActions(member: m, canRemove: isOwner),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black.withOpacity(0.10)),
                ),
                child: ClipOval(
                  child: m.avatarUrl == null || m.avatarUrl!.isEmpty
                      ? Center(
                          child: Text(initials,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)))
                      : CachedNetworkImage(
                          imageUrl: m.avatarUrl!, fit: BoxFit.cover),
                ),
              ),
              if (m.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@${m.username}',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (m.streakCount > 0) ...[
                      const Icon(Icons.local_fire_department_rounded,
                          size: 14, color: Colors.deepOrange),
                      const SizedBox(width: 3),
                      Text('${m.streakCount}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 12)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!isMe)
            Icon(Icons.more_horiz_rounded,
                color: Colors.black.withOpacity(0.35)),
        ],
      ),
    );
  }

  Future<void> _openMemberActions(
      {required _Member member, required bool canRemove}) async {
    final data = onboarding;
    if (data == null) return;
    final strings = ref.read(stringsProvider);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('@${member.username}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.block_rounded),
                  title: Text(strings.blockUser),
                  onTap: () async {
                    Navigator.of(context).pop();
                    try {
                      await DoodlApi.shared.blockProfile(
                        profileId: data.profileId,
                        pairingCode: data.pairingCode,
                        blockedProfileId: member.profileId,
                      );
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(strings.blockUser)));
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Block failed: $e')));
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lock_open_rounded),
                  title: Text(strings.unblockUser),
                  onTap: () async {
                    Navigator.of(context).pop();
                    try {
                      await DoodlApi.shared.unblockProfile(
                        profileId: data.profileId,
                        pairingCode: data.pairingCode,
                        blockedProfileId: member.profileId,
                      );
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(strings.unblockUser)));
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Unblock failed: $e')));
                    }
                  },
                ),
                if (canRemove) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.person_remove_alt_1_rounded,
                        color: Colors.red),
                    title: Text(strings.removeFromGroup,
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.w800)),
                    onTap: () async {
                      Navigator.of(context).pop();
                      try {
                        await DoodlApi.shared.removeMember(
                          code: widget.groupCode,
                          requesterProfileId: data.profileId,
                          requesterPairingCode: data.pairingCode,
                          memberProfileId: member.profileId,
                        );
                        if (mounted) unawaited(_refresh(force: true));
                      } catch (e) {
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Remove failed: $e')));
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _initials(String username) {
    final cleaned = username.replaceAll('@', '').trim();
    if (cleaned.isEmpty) return '?';
    final parts =
        cleaned.split(RegExp(r'[_\.\s]+')).where((e) => e.isNotEmpty).toList();
    final first = parts.isEmpty ? cleaned : parts.first;
    final second = parts.length > 1
        ? parts[1]
        : cleaned.length > 1
            ? cleaned[1]
            : '';
    final a = first.isNotEmpty ? first[0] : '?';
    final b = second.isNotEmpty ? second[0] : '';
    return ('$a$b').toUpperCase();
  }
}

class _Member {
  const _Member({
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

  factory _Member.fromMap(Map<String, dynamic> row) {
    return _Member(
      profileId: row['profile_id']?.toString() ?? '',
      username: row['username']?.toString() ?? '',
      avatarUrl: row['avatar_url']?.toString(),
      streakCount: (row['streak_count'] is int)
          ? row['streak_count'] as int
          : int.tryParse('${row['streak_count']}') ?? 0,
      isOnline: row['is_online'] == true,
    );
  }
}

class _InviteMemberSheet extends ConsumerStatefulWidget {
  const _InviteMemberSheet({
    required this.groupCode,
    required this.myProfileId,
    required this.onInvited,
  });

  final String groupCode;
  final String myProfileId;
  final VoidCallback onInvited;

  @override
  ConsumerState<_InviteMemberSheet> createState() => _InviteMemberSheetState();
}

class _InviteMemberSheetState extends ConsumerState<_InviteMemberSheet> {
  final controller = TextEditingController();
  Timer? debounce;
  bool busy = false;
  List<Map<String, dynamic>> results = const [];

  @override
  void initState() {
    super.initState();
    controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    debounce?.cancel();
    controller.removeListener(_onChanged);
    controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 250), () async {
      final q = controller.text.trim().toLowerCase().replaceAll('@', '');
      if (q.length < 2) {
        if (mounted) setState(() => results = const []);
        return;
      }
      try {
        final rows = await DoodlApi.shared.searchProfiles(
            query: q, excludeProfileId: widget.myProfileId, limit: 12);
        if (!mounted) return;
        setState(() => results = rows);
      } catch (_) {}
    });
  }

  Future<void> _invite(String username) async {
    setState(() => busy = true);
    try {
      await DoodlApi.shared.inviteToGroup(
        groupCode: widget.groupCode,
        inviterProfileId: widget.myProfileId,
        invitedUsername: username,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invited')));
      widget.onInvited();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Invite failed: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.invite,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: strings.searchUsername,
            filled: true,
          ),
        ),
        const SizedBox(height: 12),
        if (busy) const LinearProgressIndicator(minHeight: 2),
        SizedBox(
          height: 360,
          child: results.isEmpty
              ? Center(child: Text(strings.typeToSearch))
              : ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, i) {
                    final row = results[i];
                    final username = (row['username'] ?? '').toString();
                    final avatarUrl = (row['avatar_url'] ?? '').toString();
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.06),
                        backgroundImage: avatarUrl.isEmpty
                            ? null
                            : CachedNetworkImageProvider(avatarUrl),
                        child: avatarUrl.isEmpty
                            ? Text(username.isEmpty
                                ? '?'
                                : username.substring(0, 1).toUpperCase())
                            : null,
                      ),
                      title: Text('@$username'),
                      trailing: FilledButton(
                        onPressed: busy ? null : () => _invite(username),
                        child: Text(strings.invite),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
