import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

const _languageKey = 'selected_language';

enum AppLanguage {
  english('English', 'en'),
  hindi('हिंदी', 'hi'),
  telugu('తెలుగు', 'te'),
  tamil('தமிழ்', 'ta');

  final String displayName;
  final String code;

  const AppLanguage(this.displayName, this.code);
}

class LanguageNotifier extends StateNotifier<AppLanguage> {
  final Box<dynamic> _box;

  LanguageNotifier(this._box) : super(AppLanguage.english) {
    _loadLanguage();
  }

  void _loadLanguage() {
    final savedLanguageCode = _box.get(_languageKey);
    if (savedLanguageCode != null) {
      state = AppLanguage.values.firstWhere(
        (lang) => lang.code == savedLanguageCode,
        orElse: () => AppLanguage.english,
      );
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    await _box.put(_languageKey, language.code);
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, AppLanguage>(
  (ref) {
    throw UnimplementedError('languageProvider must be overridden');
  },
);
