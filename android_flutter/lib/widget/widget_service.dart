import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WidgetService {
  WidgetService._();

  static const _channel = MethodChannel('doodl/widget');
  static const _kPath = 'widget_latest_path';
  static const _kSender = 'widget_latest_sender';
  static const _kUpdatedAt = 'widget_latest_updated_at_ms';

  static Future<bool> setLatestPngBytes(Uint8List pngBytes,
      {String? senderUsername}) async {
    if (!Platform.isAndroid) return false;
    if (pngBytes.isEmpty) return false;

    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/doodl_widget_latest.png');
      await file.writeAsBytes(pngBytes, flush: true);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPath, file.path);
      if (senderUsername != null && senderUsername.trim().isNotEmpty) {
        final u = senderUsername.trim().startsWith('@')
            ? senderUsername.trim()
            : '@${senderUsername.trim()}';
        await prefs.setString(_kSender, u);
      } else {
        await prefs.remove(_kSender);
      }
      await prefs.setInt(_kUpdatedAt, DateTime.now().millisecondsSinceEpoch);

      // Best-effort: ask native side to refresh widgets.
      unawaited(_channel.invokeMethod<void>('update'));
      return true;
    } catch (_) {
      // Best-effort only; never break the app if widget update fails.
      return false;
    }
  }

  static Future<bool> setLatestFromDataUrl(String dataUrl,
      {String? senderUsername}) async {
    final bytes = _decodeDataUrlToBytes(dataUrl);
    if (bytes == null) return false;
    return setLatestPngBytes(bytes, senderUsername: senderUsername);
  }

  static Uint8List? _decodeDataUrlToBytes(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;

    final comma = text.indexOf(',');
    if (comma != -1 && text.substring(0, comma).contains('base64')) {
      final b64 = text.substring(comma + 1);
      try {
        return base64Decode(b64);
      } catch (_) {
        return null;
      }
    }

    try {
      return base64Decode(text);
    } catch (_) {
      return null;
    }
  }
}
