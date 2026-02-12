import 'package:flutter/widgets.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'push/background_handler.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register FCM background handler early (Android).
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Make Supabase config available to Android background services (widget updater).
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('doodl_supabase_url', AppConfig.supabaseUrl);
    await prefs.setString('doodl_supabase_anon_key', AppConfig.supabaseAnonKey);
  } catch (_) {
    // ignore
  }

  if (AppConfig.supabaseUrl.isNotEmpty &&
      AppConfig.supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }
}
