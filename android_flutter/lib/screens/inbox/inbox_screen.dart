import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scribble/scribble.dart';

import '../../models/anonymous.dart';
import '../../models/direct_chat_thread.dart';
import '../../models/friend_request.dart';
import '../../models/group_invite.dart';
import '../../models/group_summary.dart';
import '../../models/onboarding.dart';
import '../../i18n/strings_provider.dart';
import '../../services/doodl_api.dart';
import '../../storage/inbox_seen_store.dart';
import '../../utils/data_url.dart';
import '../../widgets/doodle_tools.dart';
import '../../widgets/doodl_logo.dart';
import '../../widget/widget_service.dart';
import 'anon_compose_screen.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key, required this.onboarding});

  final OnboardingData onboarding;

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

enum _InboxMode { friends, groups, anon }

class _InboxScreenState extends ConsumerState<InboxScreen> {
  _InboxMode mode = _InboxMode.friends;

  bool loading = false;
  String? error;

  String query = '';

  List<DirectChatThread> chats = const [];
  List<FriendRequestRow> requests = const [];

  List<GroupSummaryRow> groups = const [];
  List<GroupInvite> invites = const [];
  final latestGroupAt = <String, DateTime?>{};

  AnonymousLink? anonLink;
  List<AnonymousDoodle> anonInbox = const [];
  bool anonLoading = false;

  int groupsBadge = 0;
  final Set<String> _openingThreads = <String>{};

  @override
  void initState() {
    super.initState();
    unawaited(refresh(force: true));
  }

  Future<void> refresh({required bool force}) async {
    if (loading && !force) return;
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final api = DoodlApi.shared;
      final pid = widget.onboarding.profileId;
      final code = widget.onboarding.pairingCode;

      final chatRows = await api.listDirectChats(
          profileId: pid, pairingCode: code, limit: 60);
      final nextChats = chatRows
          .map(DirectChatThread.fromMap)
          .where((t) => t.code.isNotEmpty)
          .toList();

      final reqRows = await api.listFriendRequests(
          profileId: pid, pairingCode: code, limit: 50);
      final nextReqs = reqRows
          .map(FriendRequestRow.fromMap)
          .where((r) => r.requestId.isNotEmpty)
          .toList();

      final groupRows =
          await api.listGroupsV2(profileId: pid, pairingCode: code, limit: 60);
      final nextGroups = groupRows
          .map(GroupSummaryRow.fromMap)
          .where((g) => g.code.isNotEmpty)
          .toList();

      final inviteRows = await api.listInvites(profileId: pid);
      final nextInvites = inviteRows.map(GroupInvite.fromMap).toList();

      // Badge for groups: pending invites + groups with unseen latest doodl.
      final nextLatestGroupAt = <String, DateTime?>{};
      int unseenGroups = 0;
      for (final g in nextGroups) {
        try {
          // Ignore your own doodls for "new" (Snapchat-like).
          final metas = await api.inboxDoodleMetas(
              code: g.code, requesterProfileId: pid, limit: 6);
          DateTime? createdAt;
          for (final m in metas) {
            final senderId = m['sender_profile_id']?.toString() ?? '';
            if (senderId.isEmpty || senderId == pid) continue;
            createdAt = _parseDate(m['created_at']);
            break;
          }
          nextLatestGroupAt[g.code] = createdAt;
          final lastSeen = await InboxSeenStore.lastSeenAt(g.code) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          if (createdAt != null && createdAt.isAfter(lastSeen))
            unseenGroups += 1;
        } catch (_) {
          nextLatestGroupAt[g.code] = null;
        }
      }
      final pendingInvites =
          nextInvites.where((i) => i.status.toLowerCase() == 'pending').length;

      if (!mounted) return;
      setState(() {
        chats = nextChats;
        requests = nextReqs;
        groups = nextGroups;
        invites = nextInvites;
        latestGroupAt
          ..clear()
          ..addAll(nextLatestGroupAt);
        groupsBadge = pendingInvites + unseenGroups;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }

    if (mode == _InboxMode.anon) {
      await refreshAnon(force: force);
    }
  }

  Future<void> refreshAnon({required bool force}) async {
    if (anonLoading && !force) return;
    setState(() => anonLoading = true);
    try {
      final api = DoodlApi.shared;
      final pid = widget.onboarding.profileId;
      final pairing = widget.onboarding.pairingCode;
      final linkRow =
          await api.getAnonymousLink(profileId: pid, pairingCode: pairing);
      final nextLink = linkRow == null ? null : AnonymousLink.fromMap(linkRow);
      final inboxRows = await api.anonymousInboxDoodles(
          profileId: pid, pairingCode: pairing, limit: 18);
      final nextInbox = inboxRows.map(AnonymousDoodle.fromMap).toList();
      if (!mounted) return;
      setState(() {
        anonLink = nextLink;
        anonInbox = nextInbox;
      });
    } catch (_) {
      // best effort
    } finally {
      if (mounted) setState(() => anonLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsBadge =
        chats.where((c) => c.hasUnread).length + requests.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
      children: [
        _topRow(),
        if (error != null) ...[
          const SizedBox(height: 10),
          _errorCard(error!),
        ],
        const SizedBox(height: 12),
        _modeTabs(friendsBadge: friendsBadge, groupsBadge: groupsBadge),
        const SizedBox(height: 12),
        if (mode != _InboxMode.anon) _searchBar(),
        if (mode == _InboxMode.friends) ..._friendsBody(),
        if (mode == _InboxMode.groups) ..._groupsBody(),
        if (mode == _InboxMode.anon) ..._anonBody(),
      ],
    );
  }

  Widget _topRow() {
    return SizedBox(
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _circleButton(
              icon: Icons.settings_rounded,
              filled: false,
              onTap: () => context.push('/settings'),
            ),
          ),
          const Center(child: DoodlLogo(height: 90)),
          Align(
            alignment: Alignment.centerRight,
            child: _circleButton(
              icon: Icons.person_add_alt_1_rounded,
              filled: true,
              onTap: () => _openAddFriend(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Text(
        msg,
        style:
            const TextStyle(fontWeight: FontWeight.w700, color: Colors.black87),
      ),
    );
  }

  Widget _modeTabs({required int friendsBadge, required int groupsBadge}) {
    final strings = ref.watch(stringsProvider);
    Widget tab({
      required _InboxMode value,
      required String label,
      required int badge,
    }) {
      final active = mode == value;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() => mode = value);
            if (value == _InboxMode.anon) {
              unawaited(refreshAnon(force: true));
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFFFFC00) : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.black.withOpacity(active ? 0.90 : 0.70))),
                if (badge > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.black.withOpacity(0.85)
                          : Colors.black.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$badge',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: active
                            ? const Color(0xFFFFFC00)
                            : Colors.black.withOpacity(0.70),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          tab(
              value: _InboxMode.friends,
              label: strings.friends,
              badge: friendsBadge),
          tab(
              value: _InboxMode.groups,
              label: strings.groups.toLowerCase(),
              badge: groupsBadge),
          tab(value: _InboxMode.anon, label: strings.anon, badge: 0),
        ],
      ),
    );
  }

  Widget _searchBar() {
    final strings = ref.watch(stringsProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        decoration: InputDecoration(
          hintText: mode == _InboxMode.friends
              ? strings.searchFriends
              : strings.searchGroups,
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: Colors.black.withOpacity(0.04),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
        ),
        onChanged: (v) => setState(() => query = v),
      ),
    );
  }

  List<Widget> _friendsBody() {
    if (loading && chats.isEmpty) {
      return const [
        Center(
            child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator()))
      ];
    }

    if (requests.isNotEmpty) {
      return [
        _requestsCard(),
        const SizedBox(height: 12),
        ..._chatList(),
      ];
    }
    return _chatList();
  }

  List<Widget> _chatList() {
    final strings = ref.watch(stringsProvider);
    final q = query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? chats
        : chats
            .where((t) => t.otherUsername.toLowerCase().contains(q))
            .toList();
    if (filtered.isEmpty) {
      return [
        const SizedBox(height: 10),
        _emptyCard(
          title: strings.addFriendsToStartTitle,
          subtitle: strings.addFriendsToStartSubtitle,
        ),
      ];
    }

    return [
      for (final thread in filtered) ...[
        _chatRow(thread),
        const SizedBox(height: 10),
      ]
    ];
  }

  Widget _requestsCard() {
    final strings = ref.watch(stringsProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.84),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.requests,
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.black.withOpacity(0.90))),
          const SizedBox(height: 10),
          for (final r in requests.take(6)) ...[
            _requestRow(r),
            const SizedBox(height: 10),
          ],
          if (requests.length > 6)
            Text('+${requests.length - 6} more',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _requestRow(FriendRequestRow r) {
    return Row(
      children: [
        _avatar(r.requesterAvatarUrl, initials: r.requesterUsername),
        const SizedBox(width: 10),
        Expanded(
            child: Text('@${r.requesterUsername}',
                style: const TextStyle(fontWeight: FontWeight.w900))),
        IconButton(
          onPressed: () => _respondRequest(r, accept: false),
          icon: const Icon(Icons.close_rounded),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: const Color(0xFFFFFC00)),
          onPressed: () => _respondRequest(r, accept: true),
          child:
              const Text('add', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  Future<void> _respondRequest(FriendRequestRow r,
      {required bool accept}) async {
    try {
      await DoodlApi.shared.respondFriendRequest(
        requestId: r.requestId,
        profileId: widget.onboarding.profileId,
        pairingCode: widget.onboarding.pairingCode,
        accept: accept,
      );
      if (!mounted) return;
      await refresh(force: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Widget _chatRow(DirectChatThread thread) {
    final time = _timeAgo(thread.lastCreatedAt);
    final strings = ref.watch(stringsProvider);
    final subtitle = thread.lastCreatedAt == null
        ? strings.noDoodlesYet
        : (thread.hasUnread ? strings.newDoodl : strings.opened);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onLongPress: () => _openFriendActions(thread),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.86),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 12)),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                _avatar(thread.otherAvatarUrl, initials: thread.otherUsername),
                if (thread.hasUnread)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
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
                  Row(
                    children: [
                      Text('@${thread.otherUsername}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: thread.hasUnread
                              ? Colors.blueAccent
                              : Colors.black54,
                        ),
                      ),
                      if (thread.streakCount > 0) ...[
                        const SizedBox(width: 8),
                        _streakBadge(thread.streakCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (time != null)
                  Text(time,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: Colors.black45)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _openThread(thread),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFC00).withOpacity(0.95),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black.withOpacity(0.10)),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.black),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFriendActions(DirectChatThread thread) async {
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
                Text('@${thread.otherUsername}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.person_remove_alt_1_rounded),
                  title: Text(strings.removeFriend),
                  onTap: () async {
                    Navigator.of(context).pop();
                    try {
                      await DoodlApi.shared.removeFriend(
                        profileId: widget.onboarding.profileId,
                        pairingCode: widget.onboarding.pairingCode,
                        friendProfileId: thread.otherProfileId,
                      );
                      if (mounted) unawaited(refresh(force: true));
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Remove failed: $e')));
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block_rounded),
                  title: Text(strings.blockUser),
                  onTap: () async {
                    Navigator.of(context).pop();
                    try {
                      await DoodlApi.shared.blockProfile(
                        profileId: widget.onboarding.profileId,
                        pairingCode: widget.onboarding.pairingCode,
                        blockedProfileId: thread.otherProfileId,
                      );
                      if (mounted) unawaited(refresh(force: true));
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
                        profileId: widget.onboarding.profileId,
                        pairingCode: widget.onboarding.pairingCode,
                        blockedProfileId: thread.otherProfileId,
                      );
                      if (mounted) unawaited(refresh(force: true));
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Unblock failed: $e')));
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _streakBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_fire_department_rounded,
              size: 14, color: Colors.deepOrange),
          const SizedBox(width: 3),
          Text('$count',
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
        ],
      ),
    );
  }

  List<Widget> _groupsBody() {
    if (loading && groups.isEmpty) {
      return const [
        Center(
            child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator()))
      ];
    }

    final pendingInvites =
        invites.where((i) => i.status.toLowerCase() == 'pending').toList();
    final q = query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? groups
        : groups
            .where((g) => _groupDisplayName(g).toLowerCase().contains(q))
            .toList();

    final children = <Widget>[];
    if (pendingInvites.isNotEmpty) {
      children.add(_invitesCard(pendingInvites));
      children.add(const SizedBox(height: 12));
    }

    children.add(_groupsHeader());
    children.add(const SizedBox(height: 10));

    if (filtered.isEmpty) {
      final strings = ref.watch(stringsProvider);
      children.add(_emptyCard(
          title: strings.noGroupsYet,
          subtitle: strings.createGroupAndInviteFriends));
      return children;
    }

    for (final g in filtered) {
      children.add(_groupRow(g));
      children.add(const SizedBox(height: 10));
    }
    return children;
  }

  Widget _groupsHeader() {
    final strings = ref.watch(stringsProvider);
    return Row(
      children: [
        Text(strings.groups.toLowerCase(),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const Spacer(),
        IconButton(
          onPressed: () => refresh(force: true),
          icon: const Icon(Icons.refresh_rounded),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: const Color(0xFFFFFC00)),
          onPressed: () => _createGroup(),
          child: const Text('+', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    );
  }

  Future<void> _createGroup() async {
    final strings = ref.read(stringsProvider);
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(strings.newGroup),
          content: TextField(
              controller: controller,
              decoration:
                  const InputDecoration(labelText: 'Group name (optional)')),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(strings.cancel)),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: Text(strings.create)),
          ],
        );
      },
    );
    if (name == null) return;
    try {
      await DoodlApi.shared.createGroupV2(
        profileId: widget.onboarding.profileId,
        pairingCode: widget.onboarding.pairingCode,
        displayName: name.trim().isEmpty ? null : name.trim(),
      );
      if (!mounted) return;
      await refresh(force: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Create failed: $e')));
    }
  }

  Widget _invitesCard(List<GroupInvite> pending) {
    final strings = ref.watch(stringsProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.84),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.invites,
              style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          for (final invite in pending) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_inviteTitle(invite),
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text('from @${invite.inviterUsername}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black54)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _respondInvite(invite, accept: false),
                  icon: const Icon(Icons.close_rounded),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: const Color(0xFFFFFC00)),
                  onPressed: () => _respondInvite(invite, accept: true),
                  child: Text(strings.join.toLowerCase(),
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  String _inviteTitle(GroupInvite invite) => invite.groupCode;

  Future<void> _respondInvite(GroupInvite invite,
      {required bool accept}) async {
    try {
      await DoodlApi.shared.respondInvite(
        inviteId: invite.inviteId,
        profileId: widget.onboarding.profileId,
        pairingCode: widget.onboarding.pairingCode,
        accept: accept,
      );
      if (!mounted) return;
      await refresh(force: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Invite failed: $e')));
    }
  }

  Widget _groupRow(GroupSummaryRow g) {
    final strings = ref.watch(stringsProvider);
    final code = g.code;
    final name = _groupDisplayName(g);
    final latest = latestGroupAt[code];
    return FutureBuilder<DateTime?>(
      future: InboxSeenStore.lastSeenAt(code),
      builder: (context, snapshot) {
        final lastSeen =
            snapshot.data ?? DateTime.fromMillisecondsSinceEpoch(0);
        final hasUnread = latest != null && latest.isAfter(lastSeen);
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openGroupDoodles(code: code, displayName: name),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.86),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 12)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.04),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black.withOpacity(0.10)),
                  ),
                  child:
                      const Icon(Icons.groups_rounded, color: Colors.black54),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 3),
                      Text('${g.memberCount} members',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black54)),
                    ],
                  ),
                ),
                if (hasUnread) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFC00).withOpacity(0.95),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.black.withOpacity(0.10)),
                    ),
                    child: Text(strings.newLabel,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 10),
                ],
                GestureDetector(
                  onTap: () => _openGroupDoodles(code: code, displayName: name),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFC00).withOpacity(0.95),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black.withOpacity(0.10)),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.black),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => context.push('/group/$code'),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.80),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black.withOpacity(0.10)),
                    ),
                    child: Icon(Icons.info_outline_rounded,
                        color: Colors.black.withOpacity(0.70)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _groupDisplayName(GroupSummaryRow g) {
    final name = (g.displayName ?? '').trim();
    return name.isEmpty ? g.code : name;
  }

  List<Widget> _anonBody() {
    final link = anonLink;
    final enabled = link?.isEnabled ?? false;
    final short = link?.shortCode ?? '';
    final url = short.isEmpty ? '' : 'https://doodl-me.com/h/$short';
    final strings = ref.watch(stringsProvider);

    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.86),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFC00).withOpacity(0.95),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black.withOpacity(0.10)),
              ),
              child:
                  const Icon(Icons.visibility_off_rounded, color: Colors.black),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      strings.lang == 'nl' ? 'stuur anoniem' : 'send anonymous',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(
                    strings.lang == 'nl'
                        ? 'stuur een doodl via @username'
                        : 'send a doodl by @username',
                    style: const TextStyle(
                        color: Colors.black54, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => refreshAnon(force: true),
              icon: const Icon(Icons.refresh_rounded),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: const Color(0xFFFFFC00),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) =>
                        AnonComposeScreen(onboarding: widget.onboarding),
                  ),
                );
              },
              child: Text(strings.send,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.86),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('receive anonymous doodls',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  SizedBox(height: 2),
                  Text('people can send you doodls via your link',
                      style: TextStyle(
                          color: Colors.black54, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Switch(
              value: enabled,
              onChanged: (v) async {
                try {
                  final res = await DoodlApi.shared.setAnonymousLinkEnabled(
                    profileId: widget.onboarding.profileId,
                    pairingCode: widget.onboarding.pairingCode,
                    enabled: v,
                  );
                  if (!mounted) return;
                  setState(() => anonLink = AnonymousLink.fromMap(res));
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Update failed: $e')));
                }
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (enabled && url.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.86),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.anonymousLink,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              SelectableText(url),
            ],
          ),
        ),
      const SizedBox(height: 12),
      if (anonLoading)
        const Center(
            child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator()))
      else if (anonInbox.isEmpty)
        _emptyCard(
            title: 'no anonymous doodls',
            subtitle: 'share your link to start.'),
      if (anonInbox.isNotEmpty) _anonGrid(),
    ];
  }

  Widget _anonGrid() {
    final items = anonInbox.take(18).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final doodle = items[i];
        final bytes = decodeDataUrlToBytes(doodle.contentBase64);
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => _SnapSequenceViewer(
                  snaps: [
                    _Snap(
                      id: doodle.id,
                      threadCode: '',
                      senderUsername: 'anon',
                      senderProfileId: '',
                      bytes: bytes,
                      createdAt: doodle.createdAt,
                    ),
                  ],
                  autoAdvanceSeconds: 10,
                  onFinished: (_) async {},
                  myProfileId: '',
                  myPairingCode: '',
                  allowReply: false,
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              color: Colors.white,
              child: Image.memory(bytes, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyCard({required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.80),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _circleButton(
      {required IconData icon,
      required bool filled,
      required VoidCallback onTap}) {
    final bg = filled ? Colors.black : Colors.white.withOpacity(0.80);
    final fg =
        filled ? const Color(0xFFFFFC00) : Colors.black.withOpacity(0.72);
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: fg),
        ),
      ),
    );
  }

  Widget _avatar(String? url, {required String initials}) {
    final text = _initials(initials);
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.06),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withOpacity(0.10)),
      ),
      child: ClipOval(
        child: url == null || url.isEmpty
            ? Center(
                child: Text(text,
                    style: const TextStyle(fontWeight: FontWeight.w900)))
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Center(
                    child: Text(text,
                        style: const TextStyle(fontWeight: FontWeight.w900))),
              ),
      ),
    );
  }

  String _initials(String username) {
    final cleaned = username.replaceAll('@', '').trim();
    if (cleaned.isEmpty) return '?';
    final parts = cleaned
        .split(RegExp(r'[_\\.\\s]+'))
        .where((e) => e.isNotEmpty)
        .toList();
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

  String? _timeAgo(DateTime? dt) {
    if (dt == null) return null;
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Future<void> _openThread(DirectChatThread thread) async {
    final code = thread.code.trim().toLowerCase();
    if (_openingThreads.contains(code)) return;
    _openingThreads.add(code);

    try {
      final lastSeen = await InboxSeenStore.lastSeenAt(code) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final api = DoodlApi.shared;
      final metas = await api.inboxDoodleMetas(
          code: code,
          requesterProfileId: widget.onboarding.profileId,
          limit: 18);
      final unseen = metas
          .where((m) =>
              m['sender_profile_id']?.toString() == thread.otherProfileId)
          .map((m) => _Meta(
                id: m['doodle_id']?.toString() ?? '',
                createdAt: _parseDate(m['created_at']),
              ))
          .where((m) =>
              m.id.isNotEmpty &&
              (m.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .isAfter(lastSeen))
          .toList()
        ..sort((a, b) => (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));

      if (unseen.isEmpty) {
        final strings = ref.watch(stringsProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings.noNewDoodl)));
        return;
      }

      final ids = unseen.map((m) => m.id).toList();
      final contents = await api.doodleContents(
          code: code,
          requesterProfileId: widget.onboarding.profileId,
          doodleIds: ids);

      final snaps = <_Snap>[];
      for (final meta in unseen) {
        final content = contents[meta.id];
        if (content == null) continue;
        final bytes = decodeDataUrlToBytes(content);
        snaps.add(_Snap(
          id: meta.id,
          threadCode: code,
          senderUsername: thread.otherUsername,
          senderProfileId: thread.otherProfileId,
          bytes: bytes,
          createdAt: meta.createdAt,
        ));
      }

      if (snaps.isEmpty) return;
      final newest = snaps
          .map((s) => s.createdAt ?? DateTime.now())
          .fold<DateTime>(DateTime.fromMillisecondsSinceEpoch(0),
              (a, b) => a.isAfter(b) ? a : b);
      final seenAt = newest.add(const Duration(microseconds: 1));

      // Snapchat-like: opening consumes the doodl even if the user backs out.
      await InboxSeenStore.markSeen(code, seenAt);
      if (mounted) unawaited(refresh(force: true));

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _SnapSequenceViewer(
            snaps: snaps,
            autoAdvanceSeconds: 10,
            onFinished: (finishedAll) async {
              // Re-assert seen timestamp (covers any race where `newest` changes).
              await InboxSeenStore.markSeen(code, seenAt);
              // Snapchat-like: once opened, mark as viewed (even if the user taps to close early).
              try {
                await api.threadDoodles(
                  code: code,
                  requesterProfileId: widget.onboarding.profileId,
                  requesterPairingCode: widget.onboarding.pairingCode,
                  senderProfileId: thread.otherProfileId,
                  limit: 1,
                );
              } catch (_) {
                // best effort
              }
              if (mounted) unawaited(refresh(force: true));
            },
            myProfileId: widget.onboarding.profileId,
            myPairingCode: widget.onboarding.pairingCode,
            allowReply: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Open failed: $e')));
    } finally {
      _openingThreads.remove(code);
    }
  }

  Future<void> _openAddFriend() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddFriendSheet(onboarding: widget.onboarding),
    );
    if (mounted) unawaited(refresh(force: true));
  }

  Future<void> _openGroupDoodles(
      {required String code, required String displayName}) async {
    final normalized = code.trim().toLowerCase();
    if (normalized.isEmpty) return;
    if (_openingThreads.contains(normalized)) return;
    _openingThreads.add(normalized);

    try {
      final lastSeen = await InboxSeenStore.lastSeenAt(normalized) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final api = DoodlApi.shared;
      final pid = widget.onboarding.profileId;
      final metas = await api.inboxDoodleMetas(
          code: normalized, requesterProfileId: pid, limit: 18);

      final unseen = metas
          .map((m) => _GroupMeta(
                id: m['doodle_id']?.toString() ?? '',
                createdAt: _parseDate(m['created_at']),
                senderUsername: m['sender_username']?.toString() ?? '',
                senderProfileId: m['sender_profile_id']?.toString() ?? '',
              ))
          // Ignore your own doodls (you shouldn't "receive" your own group doodls).
          .where((m) => m.id.isNotEmpty && m.senderProfileId != pid)
          .where((m) => (m.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .isAfter(lastSeen))
          .toList()
        ..sort((a, b) => (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));

      if (unseen.isEmpty) {
        final strings = ref.watch(stringsProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings.noNewDoodl)));
        return;
      }

      final ids = unseen.map((m) => m.id).toList();
      final contents = await api.doodleContents(
          code: normalized, requesterProfileId: pid, doodleIds: ids);

      final snaps = <_Snap>[];
      for (final meta in unseen) {
        final content = contents[meta.id];
        if (content == null) continue;
        snaps.add(
          _Snap(
            id: meta.id,
            threadCode: normalized,
            senderUsername:
                meta.senderUsername.isEmpty ? displayName : meta.senderUsername,
            senderProfileId: meta.senderProfileId,
            bytes: decodeDataUrlToBytes(content),
            createdAt: meta.createdAt,
          ),
        );
      }

      if (snaps.isEmpty) return;
      final newest = snaps
          .map((s) => s.createdAt ?? DateTime.now())
          .fold<DateTime>(DateTime.fromMillisecondsSinceEpoch(0),
              (a, b) => a.isAfter(b) ? a : b);
      final seenAt = newest.add(const Duration(microseconds: 1));

      await InboxSeenStore.markSeen(normalized, seenAt);
      if (mounted) unawaited(refresh(force: true));

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _SnapSequenceViewer(
            snaps: snaps,
            autoAdvanceSeconds: 10,
            onFinished: (_) async {
              await InboxSeenStore.markSeen(normalized, seenAt);
              if (mounted) unawaited(refresh(force: true));
            },
            myProfileId: widget.onboarding.profileId,
            myPairingCode: widget.onboarding.pairingCode,
            allowReply: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Open failed: $e')));
    } finally {
      _openingThreads.remove(normalized);
    }
  }
}

class _Meta {
  const _Meta({required this.id, required this.createdAt});
  final String id;
  final DateTime? createdAt;
}

class _GroupMeta {
  const _GroupMeta({
    required this.id,
    required this.createdAt,
    required this.senderUsername,
    required this.senderProfileId,
  });
  final String id;
  final DateTime? createdAt;
  final String senderUsername;
  final String senderProfileId;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final text = value.toString();
  return DateTime.tryParse(text)?.toLocal();
}

class _Snap {
  const _Snap({
    required this.id,
    required this.threadCode,
    required this.senderUsername,
    required this.senderProfileId,
    required this.bytes,
    required this.createdAt,
  });

  final String id;
  final String threadCode;
  final String senderUsername;
  final String senderProfileId;
  final Uint8List bytes;
  final DateTime? createdAt;
}

class _SnapSequenceViewer extends StatefulWidget {
  const _SnapSequenceViewer({
    required this.snaps,
    required this.autoAdvanceSeconds,
    required this.onFinished,
    required this.myProfileId,
    required this.myPairingCode,
    required this.allowReply,
  });

  final List<_Snap> snaps;
  final int autoAdvanceSeconds;
  final Future<void> Function(bool finishedAll) onFinished;
  final String myProfileId;
  final String myPairingCode;
  final bool allowReply;

  @override
  State<_SnapSequenceViewer> createState() => _SnapSequenceViewerState();
}

class _SnapSequenceViewerState extends State<_SnapSequenceViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  int index = 0;
  bool finishedAll = false;
  bool ready = false;
  bool _didStart = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.autoAdvanceSeconds),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _advance();
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.snaps.isEmpty) return;
    if (_didStart) return;
    _didStart = true;
    // Preload the first snap before starting the timer; prevents "black screen then it closes".
    unawaited(_prepareCurrentSnap(startTimer: true));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _prepareCurrentSnap({required bool startTimer}) async {
    if (widget.snaps.isEmpty) return;
    final snap = widget.snaps[index];

    setState(() => ready = false);

    try {
      await precacheImage(MemoryImage(snap.bytes), context);
    } catch (_) {
      // Best-effort; still show whatever Image.memory can decode.
    }

    if (!mounted) return;
    setState(() => ready = true);

    unawaited(
      WidgetService.setLatestPngBytes(
        snap.bytes,
        senderUsername: snap.senderUsername,
      ),
    );

    if (startTimer) controller.forward(from: 0);
  }

  void _advance() {
    if (index + 1 >= widget.snaps.length) {
      finishedAll = true;
      _close();
      return;
    }
    controller.stop();
    setState(() => index += 1);
    unawaited(_prepareCurrentSnap(startTimer: true));
  }

  Future<void> _close() async {
    await widget.onFinished(finishedAll);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final snap = widget.snaps[index];
    final strings = ProviderScope.containerOf(context).read(stringsProvider);

    return WillPopScope(
      onWillPop: () async {
        _close();
        return false;
      },
      child: GestureDetector(
        onTap: () {
          if (!ready) return;
          if (widget.snaps.length <= 1) {
            _close();
          } else {
            _advance();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 18),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            color: Colors.white,
                            child: Image.memory(
                              snap.bytes,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              gaplessPlayback: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!ready)
                  const Positioned.fill(
                    child: Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFFFFC00)),
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: AnimatedBuilder(
                          animation: controller,
                          builder: (context, _) {
                            return LinearProgressIndicator(
                              value: controller.value,
                              minHeight: 4,
                              backgroundColor: Colors.white.withOpacity(0.18),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFFFC00)),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _close,
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '@${snap.senderUsername}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16),
                          ),
                          const Spacer(),
                          Text(
                            '${index + 1}/${widget.snaps.length}',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_horiz_rounded,
                                color: Colors.white),
                            itemBuilder: (context) => [
                              if (snap.senderProfileId.isNotEmpty)
                                PopupMenuItem(
                                    value: 'block',
                                    child: Text(strings.blockUser)),
                              if (snap.senderProfileId.isNotEmpty)
                                PopupMenuItem(
                                    value: 'unblock',
                                    child: Text(strings.unblockUser)),
                              PopupMenuItem(
                                  value: 'report',
                                  child: Text(strings.reportDoodl)),
                            ],
                            onSelected: (value) async {
                              final api = DoodlApi.shared;
                              if (value == 'block' &&
                                  snap.senderProfileId.isNotEmpty) {
                                try {
                                  await api.blockProfile(
                                    profileId: widget.myProfileId,
                                    pairingCode: widget.myPairingCode,
                                    blockedProfileId: snap.senderProfileId,
                                  );
                                  if (context.mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(strings.blockUser)));
                                } catch (e) {
                                  if (context.mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text('Block failed: $e')));
                                }
                              } else if (value == 'unblock' &&
                                  snap.senderProfileId.isNotEmpty) {
                                try {
                                  await api.unblockProfile(
                                    profileId: widget.myProfileId,
                                    pairingCode: widget.myPairingCode,
                                    blockedProfileId: snap.senderProfileId,
                                  );
                                  if (context.mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content:
                                                Text(strings.unblockUser)));
                                } catch (e) {
                                  if (context.mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('Unblock failed: $e')));
                                }
                              } else if (value == 'report') {
                                try {
                                  await api.reportContent(
                                    profileId: widget.myProfileId,
                                    pairingCode: widget.myPairingCode,
                                    contentKind: 'group_doodle',
                                    contentId: snap.id,
                                    reason: null,
                                  );
                                  if (context.mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(strings.report)));
                                } catch (e) {
                                  if (context.mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('Report failed: $e')));
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.allowReply && snap.threadCode.isNotEmpty)
                  Positioned(
                    right: 18,
                    bottom: 24,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFFC00),
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => _openReplyComposer(context, snap),
                      icon: const Icon(Icons.send_rounded),
                      label: Text(
                        strings.reply,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openReplyComposer(BuildContext context, _Snap snap) async {
    if (!mounted) return;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReplyComposerSheet(
        threadCode: snap.threadCode,
        otherUsername: snap.senderUsername,
        myProfileId: widget.myProfileId,
        myPairingCode: widget.myPairingCode,
      ),
    );
  }
}

class _AddFriendSheet extends StatefulWidget {
  const _AddFriendSheet({required this.onboarding});

  final OnboardingData onboarding;

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
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
    debounce = Timer(const Duration(milliseconds: 240), () async {
      final q = controller.text.trim().toLowerCase().replaceAll('@', '');
      if (q.length < 2) {
        if (mounted) setState(() => results = const []);
        return;
      }
      setState(() => busy = true);
      try {
        final rows = await DoodlApi.shared.searchProfiles(
            query: q, excludeProfileId: widget.onboarding.profileId, limit: 12);
        if (!mounted) return;
        setState(() => results = rows);
      } finally {
        if (mounted) setState(() => busy = false);
      }
    });
  }

  Future<void> _sendRequest(String username) async {
    try {
      await DoodlApi.shared.sendFriendRequest(
        profileId: widget.onboarding.profileId,
        pairingCode: widget.onboarding.pairingCode,
        targetUsername: username,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('request sent to @$username')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ProviderScope.containerOf(context).read(stringsProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.90,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 20 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Text(strings.addFriend,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: '@username',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.04),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: busy
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final row = results[i];
                          final username = row['username']?.toString() ?? '';
                          final avatarUrl = row['avatar_url']?.toString();
                          return InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: username.isEmpty
                                ? null
                                : () => _sendRequest(username),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.86),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: Colors.black.withOpacity(0.08)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.06),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color:
                                              Colors.black.withOpacity(0.10)),
                                    ),
                                    child: ClipOval(
                                      child:
                                          avatarUrl == null || avatarUrl.isEmpty
                                              ? Center(
                                                  child: Text(
                                                    username.isEmpty
                                                        ? '?'
                                                        : username
                                                            .substring(0, 1)
                                                            .toUpperCase(),
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w900),
                                                  ),
                                                )
                                              : CachedNetworkImage(
                                                  imageUrl: avatarUrl,
                                                  fit: BoxFit.cover),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text('@$username',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w900)),
                                  ),
                                  const Icon(Icons.send_rounded,
                                      color: Colors.black54),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyComposerSheet extends StatefulWidget {
  const _ReplyComposerSheet({
    required this.threadCode,
    required this.otherUsername,
    required this.myProfileId,
    required this.myPairingCode,
  });

  final String threadCode;
  final String otherUsername;
  final String myProfileId;
  final String myPairingCode;

  @override
  State<_ReplyComposerSheet> createState() => _ReplyComposerSheetState();
}

class _ReplyComposerSheetState extends State<_ReplyComposerSheet> {
  final controller = ScribbleNotifier();
  final repaintKey = GlobalKey();
  bool sending = false;

  bool isEraser = false;
  double strokeWidth = 6;
  double brushOpacity = 1.0;
  Color selectedColor = Colors.black;
  DoodleBrushStyle brushStyle = DoodleBrushStyle.pen;
  DoodleTemplate template = DoodleTemplate.none;
  double templateOpacity = 0.26;

  @override
  void initState() {
    super.initState();
    brushOpacity = doodleDefaultOpacityForStyle(brushStyle);
    _applyBrush();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _applyBrush() {
    controller.setStrokeWidth(strokeWidth);
    if (isEraser) {
      controller.setEraser();
      return;
    }
    var c = selectedColor;
    controller.setColor(c.withOpacity(brushOpacity.clamp(0.05, 1.0)));
  }

  void _setBrushStyle(DoodleBrushStyle style) {
    setState(() {
      brushStyle = style;
      isEraser = false;
      strokeWidth = doodleDefaultWidthForStyle(style);
      brushOpacity = doodleDefaultOpacityForStyle(style);
    });
    _applyBrush();
  }

  void _setColor(Color c) {
    setState(() {
      selectedColor = c;
      isEraser = false;
    });
    _applyBrush();
  }

  void _setStrokeWidth(double v) {
    setState(() => strokeWidth = v);
    _applyBrush();
  }

  void _setOpacity(double v) {
    setState(() => brushOpacity = v);
    _applyBrush();
  }

  Future<Uint8List> _exportPng() async {
    final boundary =
        repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('canvas not ready');
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw Exception('export failed');
    return bytes.buffer.asUint8List();
  }

  Future<void> _openTools(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        var localIsEraser = isEraser;
        var localBrushStyle = brushStyle;
        var localColor = selectedColor;
        var localStrokeWidth = strokeWidth;
        var localOpacity = brushOpacity;
        var localTemplate = template;
        var localTemplateOpacity = templateOpacity;

        return StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: DoodleToolsSheet(
              isEraser: localIsEraser,
              brushStyle: localBrushStyle,
              selectedColor: localColor,
              strokeWidth: localStrokeWidth,
              opacity: localOpacity,
              template: localTemplate,
              templateOpacity: localTemplateOpacity,
              onEraserChanged: (value) {
                setSheetState(() => localIsEraser = value);
                setState(() => isEraser = value);
                _applyBrush();
              },
              onBrushStyleChanged: (style) {
                setSheetState(() => localBrushStyle = style);
                _setBrushStyle(style);
              },
              onColorChanged: (color) {
                setSheetState(() => localColor = color);
                _setColor(color);
              },
              onStrokeWidthChanged: (value) {
                setSheetState(() => localStrokeWidth = value);
                _setStrokeWidth(value);
              },
              onOpacityChanged: (value) {
                setSheetState(() => localOpacity = value);
                _setOpacity(value);
              },
              onTemplateChanged: (t) {
                setSheetState(() => localTemplate = t);
                setState(() => template = t);
              },
              onTemplateOpacityChanged: (value) {
                setSheetState(() => localTemplateOpacity = value);
                setState(() => templateOpacity = value);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _send() async {
    if (sending) return;
    setState(() => sending = true);
    try {
      final png = await _exportPng();
      final content = pngBytesToDataUrl(png);
      await DoodlApi.shared.createDoodle(
        code: widget.threadCode,
        senderProfileId: widget.myProfileId,
        senderPairingCode: widget.myPairingCode,
        contentBase64: content,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('sent')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Send failed: $e')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.92,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottomInset),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed:
                        sending ? null : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '@${widget.otherUsername}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: const Color(0xFFFFFC00),
                    ),
                    onPressed: sending ? null : _send,
                    child: Text(sending ? 'sending…' : 'send',
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border:
                              Border.all(color: Colors.black.withOpacity(0.10)),
                        ),
                        child: RepaintBoundary(
                          key: repaintKey,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Container(color: Colors.white),
                              ),
                              Positioned.fill(
                                child: DoodleTemplateOverlay(
                                  template: template,
                                  opacity: templateOpacity,
                                ),
                              ),
                              Scribble(notifier: controller),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Material(
                    color: Colors.white.withOpacity(0.9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                    child: InkWell(
                      onTap: () => _openTools(context),
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.brush_rounded,
                                size: 18,
                                color: Colors.black.withOpacity(0.78)),
                            const SizedBox(width: 8),
                            const Text('tools',
                                style: TextStyle(fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.86),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.black.withOpacity(0.08)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                            onPressed: () => controller.undo(),
                            icon: const Icon(Icons.undo_rounded)),
                        IconButton(
                            onPressed: () => controller.redo(),
                            icon: const Icon(Icons.redo_rounded)),
                        IconButton(
                            onPressed: () => controller.clear(),
                            icon: const Icon(Icons.delete_outline_rounded)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
