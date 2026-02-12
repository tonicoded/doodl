import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/preferences_store.dart';
import 'strings.dart';

final languageCodeProvider =
    StateNotifierProvider<LanguageCodeNotifier, String>((ref) {
  return LanguageCodeNotifier();
});

class LanguageCodeNotifier extends StateNotifier<String> {
  LanguageCodeNotifier() : super('en') {
    _load();
  }

  Future<void> _load() async {
    state = await PreferencesStore.loadLanguage();
  }

  Future<void> setLanguage(String code) async {
    state = code;
    await PreferencesStore.saveLanguage(code);
  }
}

final stringsProvider = Provider<AppStrings>((ref) {
  final code = ref.watch(languageCodeProvider);
  return AppStrings(code);
});
