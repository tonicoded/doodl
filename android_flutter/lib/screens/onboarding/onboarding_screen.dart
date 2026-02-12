import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/onboarding.dart';
import '../../i18n/strings_provider.dart';
import '../../services/doodl_api.dart';
import '../../storage/onboarding_storage.dart';
import '../../utils/codes.dart';
import '../../widgets/doodl_logo.dart';
import '../../widgets/doodl_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final usernameController = TextEditingController();
  bool busy = false;

  int step = 0; // 0 welcome, 1 username, 2 avatar

  String? createdProfileId;
  String? createdPairingCode;
  String? selectedAvatarPublicUrl;

  @override
  void dispose() {
    usernameController.dispose();
    super.dispose();
  }

  Future<void> _goDashboard() async {
    if (!mounted) return;
    context.go('/dashboard');
  }

  Future<void> _createAccount() async {
    final username = usernameController.text.trim().toLowerCase();
    if (username.length < 2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a username')));
      return;
    }
    setState(() => busy = true);
    try {
      final pairingCode = generateShortCode();
      final row = await DoodlApi.shared
          .createProfile(username: username, pairingCode: pairingCode);
      final profileId = row['id'].toString();

      createdProfileId = profileId;
      createdPairingCode =
          (row['pairing_code']?.toString() ?? pairingCode).toLowerCase();

      // iOS logic: your own group is your pairing code.
      await DoodlApi.shared.ensureGroup(
          code: createdPairingCode!,
          profileId: profileId,
          pairingCode: createdPairingCode!);

      // Save session now so the rest of the app works even if onboarding is closed.
      await OnboardingStorage.save(
        OnboardingData(
          profileId: profileId,
          username: username,
          pairingCode: createdPairingCode!,
          avatarUrl: row['avatar_url']?.toString(),
          joinedCode: createdPairingCode!,
          joinedCodes: [createdPairingCode!],
        ),
      );

      setState(() => step = 2); // avatar screen
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Create failed: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _pickAvatar() async {
    final profileId = createdProfileId;
    final pairingCode = createdPairingCode;
    if (profileId == null || pairingCode == null) return;

    setState(() => busy = true);
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
      selectedAvatarPublicUrl = publicUrl;
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Avatar updated')));
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Avatar failed: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _welcome() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const Spacer(),
          const Center(child: DoodlLogo(height: 110)),
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, _) {
              return Text(
                ref.watch(stringsProvider).quickDoodlesWithFriends,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.black.withOpacity(0.80),
                    fontSize: 16,
                    fontWeight: FontWeight.w800),
              );
            },
          ),
          const Spacer(),
          Consumer(
            builder: (context, ref, _) {
              final strings = ref.watch(stringsProvider);
              return FilledButton(
                onPressed: busy ? null : () => setState(() => step = 1),
                child: Text(strings.start),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _username() {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: busy ? null : () => setState(() => step = 0),
                icon: const Icon(Icons.arrow_back),
              ),
              const Spacer(),
              const DoodlLogo(height: 44),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 24),
          Consumer(
            builder: (context, ref, _) {
              final strings = ref.watch(stringsProvider);
              return Text(strings.pickAUsername,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900));
            },
          ),
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, _) {
              final strings = ref.watch(stringsProvider);
              return TextField(
                controller: usernameController,
                enabled: !busy,
                decoration: InputDecoration(
                  labelText: strings.username,
                  hintText: 'e.g. anthony',
                  filled: true,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, _) {
              final strings = ref.watch(stringsProvider);
              return FilledButton(
                onPressed: busy ? null : _createAccount,
                child: busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(strings.continueText),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const Center(child: DoodlLogo(height: 56)),
          const SizedBox(height: 24),
          Consumer(
            builder: (context, ref, _) {
              final strings = ref.watch(stringsProvider);
              return Text(strings.addProfilePhoto,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900));
            },
          ),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              final strings = ref.watch(stringsProvider);
              return Text(
                strings.optionalChangeLater,
                style: TextStyle(
                    color: Colors.black.withOpacity(0.62),
                    fontWeight: FontWeight.w700),
              );
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: CircleAvatar(
              radius: 56,
              backgroundColor: Colors.black.withOpacity(0.06),
              backgroundImage: selectedAvatarPublicUrl == null
                  ? null
                  : NetworkImage(selectedAvatarPublicUrl!),
              child: selectedAvatarPublicUrl == null
                  ? const Icon(Icons.person, size: 44)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Consumer(
            builder: (context, ref, _) {
              final strings = ref.watch(stringsProvider);
              return FilledButton.icon(
                onPressed: busy ? null : _pickAvatar,
                icon: const Icon(Icons.photo),
                label: Text(busy ? strings.loading : strings.choosePhoto),
              );
            },
          ),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              final strings = ref.watch(stringsProvider);
              return FilledButton(
                onPressed: busy ? null : _goDashboard,
                child: Text(strings.continueText),
              );
            },
          ),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              final strings = ref.watch(stringsProvider);
              return TextButton(
                onPressed: busy ? null : _goDashboard,
                child: Text(strings.skip),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: OnboardingStorage.load(),
      builder: (context, snapshot) {
        final existing = snapshot.data;
        if (existing != null && step == 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/dashboard');
          });
        }

        return DoodlPage(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: switch (step) {
              0 => _welcome(),
              1 => _username(),
              _ => _avatar(),
            },
          ),
        );
      },
    );
  }
}
