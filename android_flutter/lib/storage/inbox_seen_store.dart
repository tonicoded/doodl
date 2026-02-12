import 'package:shared_preferences/shared_preferences.dart';

class InboxSeenStore {
  static String _key(String code) => 'inbox_seen.${code.trim().toLowerCase()}';

  static Future<DateTime?> lastSeenAt(String groupCode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_key(groupCode));
    if (value == null) return null;
    // Back-compat: older builds stored milliseconds.
    final micros = value < 20000000000000 ? value * 1000 : value;
    return DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true).toLocal();
  }

  static Future<void> markSeen(String groupCode, DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(groupCode), at.toUtc().microsecondsSinceEpoch);
  }
}
