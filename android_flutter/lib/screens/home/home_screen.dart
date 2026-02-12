import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/onboarding.dart';
import '../../storage/onboarding_storage.dart';
import '../../push/push_service.dart';
import '../../widgets/doodl_page.dart';
import '../../widgets/tutorial_modal.dart';
import '../inbox/inbox_screen.dart';
import '../doodle/doodle_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tabIndex = 1;
  bool _didPromptTutorial = false;
  bool _didRegisterPush = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OnboardingData?>(
      future: OnboardingStorage.load(),
      builder: (context, snapshot) {
        final onboarding = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return const DoodlPage(
              child: Center(child: CircularProgressIndicator()));
        }
        if (onboarding == null) {
          // Back to onboarding if storage is missing.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/onboarding');
          });
          return const DoodlPage(child: SizedBox.shrink());
        }

        if (!_didRegisterPush) {
          _didRegisterPush = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(PushService.instance.ensureRegistered(onboarding));
          });
        }

        if (!_didPromptTutorial) {
          _didPromptTutorial = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final shown = await OnboardingStorage.isTutorialShown();
            if (!context.mounted) return;
            if (!shown) {
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => const TutorialModal(),
              );
            }
          });
        }

        return DoodlPage(
          safeArea: false,
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: IndexedStack(
                    index: tabIndex,
                    children: [
                      InboxScreen(onboarding: onboarding),
                      DoodleScreen(onboarding: onboarding),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: _BottomNav(
                    index: tabIndex,
                    onSelect: (i) => setState(() => tabIndex = i),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget item({
      required int i,
      required IconData icon,
      required bool isCenter,
    }) {
      final active = i == index;
      final bg =
          active ? const Color(0xFFFFFC00) : Colors.white.withOpacity(0.70);
      final fg = active
          ? Colors.black.withOpacity(0.90)
          : Colors.black.withOpacity(0.60);
      final size = isCenter ? 56.0 : 44.0;

      return GestureDetector(
        onTap: () => onSelect(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black.withOpacity(0.10), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(active ? 0.14 : 0.06),
                blurRadius: active ? 18 : 14,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(icon, color: fg, size: isCenter ? 28 : 22),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.black.withOpacity(0.10), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              item(i: 0, icon: Icons.inbox_rounded, isCenter: false),
              item(i: 1, icon: Icons.edit_rounded, isCenter: true),
            ],
          ),
        ),
      ),
    );
  }
}
