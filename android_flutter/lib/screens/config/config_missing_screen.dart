import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/doodl_logo.dart';
import '../../widgets/doodl_page.dart';
import '../../i18n/strings_provider.dart';

class ConfigMissingScreen extends ConsumerWidget {
  const ConfigMissingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return DoodlPage(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Center(child: DoodlLogo(height: 44)),
            const SizedBox(height: 12),
            Text(
              'Android setup is not finished.\n\nFill in `android_flutter/lib/config.dart` with your Supabase keys, then restart the app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 16,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {},
              child: Text(strings.ok),
            ),
          ],
        ),
      ),
    );
  }
}
