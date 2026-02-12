import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/doodl_api.dart';
import '../../models/onboarding.dart';
import '../../storage/onboarding_storage.dart';
import '../../widgets/doodl_page.dart';
import '../../utils/codes.dart';
import '../../i18n/strings_provider.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  bool busy = false;

  Future<void> _promptAndCreateOrJoin({
    required bool create,
    required String profileId,
    required String pairingCode,
  }) async {
    late final String code;
    if (create) {
      code = generateShortCode();
    } else {
      final controller = TextEditingController();
      final result = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Join group'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Group code'),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Join'),
              ),
            ],
          );
        },
      );
      if (result == null) return;
      final normalized = result.trim().toLowerCase();
      if (normalized.isEmpty) return;
      code = normalized;
    }

    setState(() => busy = true);
    try {
      if (create) {
        await DoodlApi.shared.ensureGroup(
            code: code, profileId: profileId, pairingCode: pairingCode);
      } else {
        await DoodlApi.shared.joinGroup(
            code: code, profileId: profileId, pairingCode: pairingCode);
      }
      await OnboardingStorage.addJoinedCode(code);
      await OnboardingStorage.saveJoinedCode(code);
      if (!mounted) return;
      context.push('/group/$code');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Group failed: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DoodlPage(
      child: FutureBuilder(
        future: OnboardingStorage.load(),
        builder: (context, snapshot) {
          final onboarding = snapshot.data;
          if (onboarding == null) {
            final strings = ProviderScope.containerOf(context, listen: false)
                .read(stringsProvider);
            return Center(child: Text(strings.notSignedIn));
          }

          return Consumer(
            builder: (context, ref, _) {
              final strings = ref.watch(stringsProvider);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close),
                        ),
                        const SizedBox(width: 8),
                        Text(strings.groups,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w900)),
                        const Spacer(),
                        IconButton(
                          onPressed: busy
                              ? null
                              : () => _promptAndCreateOrJoin(
                                  create: false,
                                  profileId: onboarding.profileId,
                                  pairingCode: onboarding.pairingCode),
                          icon: const Icon(Icons.person_add_alt_1),
                          tooltip: strings.joinGroup,
                        ),
                        IconButton(
                          onPressed: busy
                              ? null
                              : () => _promptAndCreateOrJoin(
                                  create: true,
                                  profileId: onboarding.profileId,
                                  pairingCode: onboarding.pairingCode),
                          icon: const Icon(Icons.add),
                          tooltip: strings.newGroup,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder(
                      future: OnboardingStorage.loadJoinedCodes(),
                      builder: (context, codesSnap) {
                        final codes = codesSnap.data ?? const <String>[];
                        if (codes.isEmpty) {
                          return Center(child: Text(strings.noGroupsYet));
                        }
                        return FutureBuilder(
                          future: DoodlApi.shared.groupMemberCounts(
                              codes: codes,
                              requesterProfileId: onboarding.profileId),
                          builder: (context, countsSnap) {
                            final map = <String, Map<String, dynamic>>{};
                            for (final row in (countsSnap.data ??
                                const <Map<String, dynamic>>[])) {
                              map[row['code'].toString()] = row;
                            }
                            return ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              itemCount: codes.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final code = codes[i];
                                final row = map[code];
                                final memberCount = row?['member_count'];
                                final maxMembers = row?['max_members'] ?? 15;
                                final isActive =
                                    onboarding.joinedCode?.toLowerCase() ==
                                        code.toLowerCase();
                                return ListTile(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18)),
                                  tileColor: Colors.white.withOpacity(0.08),
                                  title: Text(code,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900)),
                                  subtitle: memberCount == null
                                      ? null
                                      : Text(
                                          '${memberCount.toString()}/$maxMembers members'),
                                  trailing: isActive
                                      ? const Icon(Icons.check_circle)
                                      : const Icon(Icons.chevron_right),
                                  onTap: () async {
                                    await OnboardingStorage.saveJoinedCode(
                                        code);
                                    final existing =
                                        await OnboardingStorage.load();
                                    if (existing != null) {
                                      await OnboardingStorage.save(
                                        OnboardingData(
                                          profileId: existing.profileId,
                                          username: existing.username,
                                          pairingCode: existing.pairingCode,
                                          avatarUrl: existing.avatarUrl,
                                          joinedCode: code,
                                          joinedCodes: existing.joinedCodes,
                                        ),
                                      );
                                    }
                                    if (!context.mounted) return;
                                    context.push('/group/$code');
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
