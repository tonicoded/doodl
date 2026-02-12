import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/onboarding.dart';
import '../services/doodl_api.dart';
import '../widget/widget_service.dart';
import 'background_handler.dart';

class PushService {
  PushService._();

  static final PushService instance = PushService._();

  bool _initialized = false;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<RemoteMessage>? _openedSub;

  Future<void> ensureRegistered(OnboardingData onboarding) async {
    if (!Platform.isAndroid) return;
    if (_initialized) return;
    _initialized = true;

    try {
      await Firebase.initializeApp();
    } catch (_) {
      // Ignore double-initialize and allow the app to run without push if Firebase isn't configured.
    }

    try {
      final messaging = FirebaseMessaging.instance;

      // Android 13+ requires runtime permission for notifications.
      await messaging.requestPermission();

      final token = await messaging.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await _upsertToken(onboarding, token);
      }

      // If a push arrived while the app was closed, we store the doodle id/code and
      // update the widget on next launch.
      final pending = await takeWidgetPending();
      if (pending != null) {
        final code = pending['code'] ?? '';
        final doodleId = pending['doodleId'] ?? '';
        if (code.isNotEmpty && doodleId.isNotEmpty) {
          try {
            final contents = await DoodlApi.shared.doodleContents(
              code: code,
              requesterProfileId: onboarding.profileId,
              doodleIds: [doodleId],
            );
            final content = contents[doodleId];
            if (content != null && content.isNotEmpty) {
              unawaited(WidgetService.setLatestFromDataUrl(content));
            }
          } catch (_) {
            // ignore
          }
        }
      }

      _tokenSub = messaging.onTokenRefresh.listen((t) async {
        if (t.trim().isEmpty) return;
        await _upsertToken(onboarding, t);
      });

      _messageSub ??= FirebaseMessaging.onMessage.listen((message) async {
        await _maybeUpdateWidgetFromMessage(onboarding, message);
      });
      _openedSub ??=
          FirebaseMessaging.onMessageOpenedApp.listen((message) async {
        await _maybeUpdateWidgetFromMessage(onboarding, message);
      });
    } catch (_) {
      // Best-effort only; never block app startup.
    }
  }

  Future<void> dispose() async {
    await _tokenSub?.cancel();
    _tokenSub = null;
    await _messageSub?.cancel();
    _messageSub = null;
    await _openedSub?.cancel();
    _openedSub = null;
  }

  static Future<void> _upsertToken(
      OnboardingData onboarding, String token) async {
    await DoodlApi.shared.upsertFcmDevice(
      profileId: onboarding.profileId,
      pairingCode: onboarding.pairingCode,
      fcmToken: token,
    );
  }

  static Future<void> _maybeUpdateWidgetFromMessage(
      OnboardingData onboarding, RemoteMessage message) async {
    try {
      final data = message.data;
      final kind = (data['kind'] ?? '').toString();
      if (kind != 'group') return;

      final code = (data['group_code'] ?? '').toString().trim();
      final doodleId = (data['doodle_id'] ?? '').toString().trim();
      final senderUsername = (data['sender_username'] ?? '').toString().trim();
      if (code.isEmpty || doodleId.isEmpty) return;

      final contents = await DoodlApi.shared.doodleContents(
        code: code,
        requesterProfileId: onboarding.profileId,
        doodleIds: [doodleId],
      );
      final content = contents[doodleId];
      if (content == null || content.isEmpty) return;

      // Updating the widget is best-effort; ignore failures.
      // The widget will still refresh when the user opens a snap.
      unawaited(WidgetService.setLatestFromDataUrl(content,
          senderUsername: senderUsername.isEmpty ? null : senderUsername));
    } catch (_) {
      // ignore
    }
  }
}
