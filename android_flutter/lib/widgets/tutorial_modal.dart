import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/strings_provider.dart';
import '../storage/onboarding_storage.dart';

class TutorialModal extends ConsumerStatefulWidget {
  const TutorialModal({super.key});

  @override
  ConsumerState<TutorialModal> createState() => _TutorialModalState();
}

class _TutorialModalState extends ConsumerState<TutorialModal> {
  final controller = PageController();
  int index = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingStorage.setTutorialShown();
    if (mounted) Navigator.of(context).pop();
  }

  void _next() {
    if (index >= 2) {
      _finish();
      return;
    }
    controller.nextPage(
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final isNl = strings.lang == 'nl';
    final pages = [
      _Page(
        icon: Icons.person_add_alt_1_rounded,
        title: isNl ? 'vrienden toevoegen' : 'add friends',
        body: isNl
            ? 'tik op “vriend toevoegen” en zoek op @username.'
            : 'tap the add friend button and search by @username.',
      ),
      _Page(
        icon: Icons.edit_rounded,
        title: isNl ? 'stuur doodls' : 'send doodls',
        body: isNl
            ? 'teken snel iets en stuur met één tik.'
            : 'draw something quick and send it in one tap.',
      ),
      _Page(
        icon: Icons.inbox_rounded,
        title: isNl ? 'open één keer' : 'open once',
        body: isNl
            ? 'doodls openen 10 seconden fullscreen — zoals snaps.'
            : 'doodls open fullscreen for 10 seconds — like snaps.',
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(isNl ? 'welkom bij DOODL.' : 'welcome to DOODL.',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 18)),
                const Spacer(),
                TextButton(
                  onPressed: _finish,
                  child: Text(strings.skip.toLowerCase()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: PageView(
                controller: controller,
                onPageChanged: (i) => setState(() => index = i),
                children: [for (final p in pages) _pageCard(p)],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == index ? 18 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == index
                          ? Colors.black
                          : Colors.black.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: const Color(0xFFFFFC00)),
                onPressed: _next,
                child: Text(
                    index >= 2
                        ? (isNl ? 'let’s go' : 'let’s go')
                        : (isNl ? 'volgende' : 'next'),
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageCard(_Page p) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFC00),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withOpacity(0.10)),
            ),
            child: Icon(p.icon, color: Colors.black, size: 30),
          ),
          const SizedBox(height: 14),
          Text(p.title,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            p.body,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black.withOpacity(0.62),
                height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _Page {
  const _Page({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
}
