import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../i18n/strings_provider.dart';
import '../../models/onboarding.dart';
import '../../services/doodl_api.dart';
import '../../storage/onboarding_storage.dart';
import '../../widgets/doodl_page.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _avatarBusy = false;

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    return DoodlPage(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
              ),
              const SizedBox(width: 8),
              Text(
                strings.settings,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder(
            future: OnboardingStorage.load(),
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data == null) return const SizedBox.shrink();
              return Card(
                child: ListTile(
                  leading: _profileAvatar(data.avatarUrl, data.username),
                  title: Text(strings.addProfilePhoto),
                  subtitle: Text(strings.optionalChangeLater),
                  trailing: _avatarBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right),
                  onTap: _avatarBusy
                      ? null
                      : () => _pickAndUploadAvatar(
                            profileId: data.profileId,
                            pairingCode: data.pairingCode,
                          ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder(
            future: OnboardingStorage.load(),
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data == null) return const SizedBox.shrink();
              return Card(
                child: ListTile(
                  title: Text('@${data.username}'),
                  subtitle: Text(strings.profile),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _changeUsernameDialog(
                    current: data.username,
                    profileId: data.profileId,
                    pairingCode: data.pairingCode,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: Text(strings.language),
              trailing: const Icon(Icons.chevron_right),
              onTap: _languageSheet,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: Text(strings.terms),
                  subtitle: const Text('doodl-me.com/terms'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {},
                ),
                const Divider(height: 0),
                ListTile(
                  title: Text(strings.privacy),
                  subtitle: const Text('doodl-me.com/privacy'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: Colors.red.withOpacity(0.12),
            child: ListTile(
              title: Text(strings.logout),
              subtitle: Text(strings.removesDeviceSession),
              trailing: const Icon(Icons.logout),
              onTap: () async {
                await OnboardingStorage.clear();
                if (!context.mounted) return;
                context.go('/onboarding');
              },
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder(
            future: OnboardingStorage.load(),
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data == null) return const SizedBox.shrink();
              return Card(
                color: Colors.red.withOpacity(0.18),
                child: ListTile(
                  title: Text(strings.deleteAccount),
                  subtitle: Text(strings.removesProfileGroups),
                  trailing: const Icon(Icons.delete_forever),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text(strings.deleteAccountConfirmTitle),
                          content: Text(strings.deleteAccountConfirmBody),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: Text(strings.cancel)),
                            FilledButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: Text(strings.delete)),
                          ],
                        );
                      },
                    );
                    if (confirm != true) return;
                    try {
                      await DoodlApi.shared.deleteProfile(
                          profileId: data.profileId,
                          pairingCode: data.pairingCode);
                    } catch (_) {}
                    await OnboardingStorage.clear();
                    if (!context.mounted) return;
                    context.go('/onboarding');
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _changeUsernameDialog({
    required String current,
    required String profileId,
    required String pairingCode,
  }) async {
    final strings = ref.read(stringsProvider);
    final controller = TextEditingController(text: current);
    final next = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(strings.changeUsername),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: strings.username),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(strings.cancel)),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: Text(strings.save)),
          ],
        );
      },
    );
    // Delay disposal to avoid "used after dispose" during route pop animations.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (next == null) return;
    final newUsername = next.trim().toLowerCase();
    if (newUsername.isEmpty || newUsername == current) return;

    try {
      await DoodlApi.shared.updateUsername(
          profileId: profileId,
          pairingCode: pairingCode,
          newUsername: newUsername);
      final existing = await OnboardingStorage.load();
      if (existing != null) {
        await OnboardingStorage.save(
          OnboardingData(
            profileId: existing.profileId,
            username: newUsername,
            pairingCode: existing.pairingCode,
            avatarUrl: existing.avatarUrl,
            joinedCode: existing.joinedCode,
            joinedCodes: existing.joinedCodes,
          ),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(stringsProvider).saved)));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Username failed: $e')));
    }
  }

  Widget _profileAvatar(String? url, String username) {
    final trimmed = username.trim();
    final initials = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
    if (url != null && url.trim().isNotEmpty) {
      return CircleAvatar(
          backgroundImage: NetworkImage(url),
          backgroundColor: Colors.black.withOpacity(0.05));
    }
    return CircleAvatar(
      backgroundColor: Colors.black.withOpacity(0.08),
      child: Text(initials,
          style: const TextStyle(
              fontWeight: FontWeight.w900, color: Colors.black)),
    );
  }

  Future<void> _pickAndUploadAvatar({
    required String profileId,
    required String pairingCode,
  }) async {
    setState(() => _avatarBusy = true);
    try {
      final picker = ImagePicker();
      final image =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final client = Supabase.instance.client;
      final path = '$profileId/avatar.jpg';
      await client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions:
                const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      final publicUrl = client.storage.from('avatars').getPublicUrl(path);
      await DoodlApi.shared.updateAvatar(
          profileId: profileId, pairingCode: pairingCode, avatarUrl: publicUrl);

      final existing = await OnboardingStorage.load();
      if (existing != null) {
        await OnboardingStorage.save(
          OnboardingData(
            profileId: existing.profileId,
            username: existing.username,
            pairingCode: existing.pairingCode,
            avatarUrl: publicUrl,
            joinedCode: existing.joinedCode,
            joinedCodes: existing.joinedCodes,
          ),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(stringsProvider).saved)));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Avatar failed: $e')));
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _languageSheet() async {
    final strings = ref.read(stringsProvider);
    final current = ref.read(languageCodeProvider);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(strings.language,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _languageRow(
                  code: 'en', label: '🇺🇸 English', selected: current == 'en'),
              const SizedBox(height: 8),
              _languageRow(
                  code: 'nl',
                  label: '🇳🇱 Nederlands',
                  selected: current == 'nl'),
              const SizedBox(height: 8),
              _languageRow(
                  code: 'es', label: '🇪🇸 Español', selected: current == 'es'),
              const SizedBox(height: 8),
              _languageRow(
                  code: 'de', label: '🇩🇪 Deutsch', selected: current == 'de'),
            ],
          ),
        );
      },
    );
  }

  Widget _languageRow(
      {required String code, required String label, required bool selected}) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tileColor: Colors.white.withOpacity(0.08),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: selected ? const Icon(Icons.check_circle) : null,
      onTap: () async {
        await ref.read(languageCodeProvider.notifier).setLanguage(code);
        if (mounted) Navigator.of(context).pop();
        setState(() {});
      },
    );
  }
}
