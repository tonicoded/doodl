import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config.dart';
import '../screens/config/config_missing_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/group/groups_screen.dart';
import '../screens/group/group_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final needsConfig =
      AppConfig.supabaseUrl.isEmpty || AppConfig.supabaseAnonKey.isEmpty;
  return GoRouter(
    initialLocation: needsConfig ? '/config' : '/onboarding',
    routes: [
      GoRoute(
        path: '/config',
        builder: (context, state) => const ConfigMissingScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/groups',
        builder: (context, state) => const GroupsScreen(),
      ),
      GoRoute(
        path: '/group/:code',
        builder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return GroupScreen(groupCode: code);
        },
      ),
    ],
  );
});
