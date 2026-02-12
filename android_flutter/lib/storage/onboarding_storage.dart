import 'package:shared_preferences/shared_preferences.dart';
import '../models/onboarding.dart';
import 'dart:convert';

class OnboardingStorage {
  static const _kProfileId = 'onboarding_profile_id';
  static const _kUsername = 'onboarding_username';
  static const _kPairingCode = 'onboarding_pairing_code';
  static const _kAvatarUrl = 'onboarding_avatar_url';
  static const _kJoinedCode = 'onboarding_joined_code';
  static const _kJoinedCodes = 'onboarding_joined_codes';
  static const _kTutorialShown = 'onboarding_tutorial_shown_v1';

  static Future<OnboardingData?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final profileId = prefs.getString(_kProfileId);
    final username = prefs.getString(_kUsername);
    final pairingCode = prefs.getString(_kPairingCode);
    if (profileId == null || username == null || pairingCode == null)
      return null;

    final joinedCodes = loadJoinedCodesSync(prefs);
    return OnboardingData(
      profileId: profileId,
      username: username,
      pairingCode: pairingCode,
      avatarUrl: prefs.getString(_kAvatarUrl),
      joinedCode: prefs.getString(_kJoinedCode),
      joinedCodes: joinedCodes,
    );
  }

  static Future<void> save(OnboardingData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProfileId, data.profileId);
    await prefs.setString(_kUsername, data.username);
    await prefs.setString(_kPairingCode, data.pairingCode);
    if (data.avatarUrl != null) {
      await prefs.setString(_kAvatarUrl, data.avatarUrl!);
    } else {
      await prefs.remove(_kAvatarUrl);
    }
    if (data.joinedCode != null) {
      await prefs.setString(_kJoinedCode, data.joinedCode!);
    } else {
      await prefs.remove(_kJoinedCode);
    }
    await saveJoinedCodes(data.joinedCodes);
  }

  static List<String> loadJoinedCodesSync(SharedPreferences prefs) {
    final raw = prefs.getString(_kJoinedCodes);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final items = decoded
            .map((e) => e.toString().trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toSet();
        return items.toList()..sort();
      }
    }
    final single = prefs.getString(_kJoinedCode)?.trim().toLowerCase();
    if (single != null && single.isNotEmpty) return [single];
    return const [];
  }

  static Future<List<String>> loadJoinedCodes() async {
    final prefs = await SharedPreferences.getInstance();
    return loadJoinedCodesSync(prefs);
  }

  static Future<void> saveJoinedCodes(List<String> codes) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = codes
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    await prefs.setString(_kJoinedCodes, jsonEncode(cleaned));
  }

  static Future<void> saveJoinedCode(String? code) async {
    final prefs = await SharedPreferences.getInstance();
    final c = code?.trim().toLowerCase();
    if (c == null || c.isEmpty) {
      await prefs.remove(_kJoinedCode);
    } else {
      await prefs.setString(_kJoinedCode, c);
    }
  }

  static Future<void> addJoinedCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final current = loadJoinedCodesSync(prefs);
    final next = {...current, code.trim().toLowerCase()}
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort();
    await prefs.setString(_kJoinedCodes, jsonEncode(next));
    await prefs.setString(_kJoinedCode, code.trim().toLowerCase());
  }

  static Future<void> removeJoinedCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = code.trim().toLowerCase();
    final current = loadJoinedCodesSync(prefs);
    final next = current.where((c) => c != normalized).toList();
    await prefs.setString(_kJoinedCodes, jsonEncode(next));
    final active = prefs.getString(_kJoinedCode)?.trim().toLowerCase();
    if (active == normalized) {
      await prefs.remove(_kJoinedCode);
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kProfileId);
    await prefs.remove(_kUsername);
    await prefs.remove(_kPairingCode);
    await prefs.remove(_kAvatarUrl);
    await prefs.remove(_kJoinedCode);
    await prefs.remove(_kJoinedCodes);
    await prefs.remove(_kTutorialShown);
  }

  static Future<bool> isTutorialShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kTutorialShown) ?? false;
  }

  static Future<void> setTutorialShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTutorialShown, true);
  }
}
