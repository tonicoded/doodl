import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../routing/router.dart';
import '../theme/theme.dart';
import '../i18n/strings_provider.dart';

class DoodlApp extends ConsumerWidget {
  const DoodlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageCode = ref.watch(languageCodeProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'DOODL.',
      theme: buildDoodlTheme(),
      locale: Locale(languageCode),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
