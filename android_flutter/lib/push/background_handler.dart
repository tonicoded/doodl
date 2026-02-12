import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

import '../widget/widget_service.dart';

const _kWidgetPendingCode = 'widget_pending_code';
const _kWidgetPendingDoodleId = 'widget_pending_doodle_id';

const _kOnboardingProfileId = 'onboarding_profile_id';
const _kSupabaseUrl = 'doodl_supabase_url';
const _kSupabaseAnonKey = 'doodl_supabase_anon_key';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Required so plugins (shared_preferences) work in the background isolate.
  DartPluginRegistrant.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (_) {
    // ignore
  }

  try {
    final data = message.data;
    final kind = (data['kind'] ?? '').toString();
    if (kind != 'group') return;

    final code = (data['group_code'] ?? '').toString().trim();
    final doodleId = (data['doodle_id'] ?? '').toString().trim();
    final senderUsername = (data['sender_username'] ?? '').toString().trim();
    if (code.isEmpty || doodleId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    // Try to refresh the widget immediately, even in the background.
    // If anything fails (no onboarding, no network, etc.), fall back to storing a pending update.
    final ok = await _tryUpdateWidgetNow(
      prefs: prefs,
      groupCode: code,
      doodleId: doodleId,
      senderUsername: senderUsername.isEmpty ? null : senderUsername,
    );
    if (ok) return;

    await prefs.setString(_kWidgetPendingCode, code);
    await prefs.setString(_kWidgetPendingDoodleId, doodleId);
  } catch (_) {
    // ignore
  }
}

Future<bool> _tryUpdateWidgetNow({
  required SharedPreferences prefs,
  required String groupCode,
  required String doodleId,
  String? senderUsername,
}) async {
  final supabaseUrl = prefs.getString(_kSupabaseUrl)?.trim() ?? '';
  final anonKey = prefs.getString(_kSupabaseAnonKey)?.trim() ?? '';
  final profileId = prefs.getString(_kOnboardingProfileId)?.trim() ?? '';
  if (supabaseUrl.isEmpty || anonKey.isEmpty || profileId.isEmpty) return false;

  try {
    final content = await _fetchDoodleContent(
      supabaseUrl: supabaseUrl,
      anonKey: anonKey,
      groupCode: groupCode,
      requesterProfileId: profileId,
      doodleId: doodleId,
    );
    if (content == null || content.isEmpty) return false;

    return WidgetService.setLatestFromDataUrl(content,
        senderUsername: senderUsername);
  } catch (_) {
    return false;
  }
}

Future<String?> _fetchDoodleContent({
  required String supabaseUrl,
  required String anonKey,
  required String groupCode,
  required String requesterProfileId,
  required String doodleId,
}) async {
  final uri = Uri.parse('$supabaseUrl/rest/v1/rpc/doodle_contents_secure');
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 8);
  try {
    final req = await client.postUrl(uri);
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    req.headers.set('apikey', anonKey);
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $anonKey');

    req.add(
      utf8.encode(
        jsonEncode({
          'p_code': groupCode,
          'p_requester_profile_id': requesterProfileId,
          'p_doodle_ids': [doodleId],
        }),
      ),
    );

    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode < 200 || res.statusCode >= 300) return null;

    final decoded = jsonDecode(text);
    if (decoded is! List) return null;

    for (final row in decoded) {
      if (row is! Map) continue;
      final id = row['doodle_id']?.toString() ?? '';
      if (id != doodleId) continue;
      final content = row['content_base64']?.toString();
      if (content == null || content.trim().isEmpty) return null;
      return content.trim();
    }
    return null;
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, String>?> takeWidgetPending() async {
  final prefs = await SharedPreferences.getInstance();
  final code = prefs.getString(_kWidgetPendingCode);
  final doodleId = prefs.getString(_kWidgetPendingDoodleId);
  if (code == null || doodleId == null || code.isEmpty || doodleId.isEmpty)
    return null;
  await prefs.remove(_kWidgetPendingCode);
  await prefs.remove(_kWidgetPendingDoodleId);
  return {'code': code, 'doodleId': doodleId};
}
