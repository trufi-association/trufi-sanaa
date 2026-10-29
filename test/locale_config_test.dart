// Issue #15: Arabic is the default UI language. English stays available and
// installs that already chose a language keep it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trufi/main.dart' show localeConfig;
import 'package:trufi_core_utils/trufi_core_utils.dart' show LocaleManager;

void main() {
  test('Arabic comes first: the default locale and the MaterialApp fallback',
      () {
    expect(localeConfig.supportedLocales.first, const Locale('ar'));
    expect(localeConfig.defaultLocale, const Locale('ar'));
    expect(localeConfig.supportedLocales, contains(const Locale('en')));
    expect(localeConfig.supportedLocales, hasLength(2));
  });

  group('LocaleManager built from the app config', () {
    LocaleManager manager() => LocaleManager(
      defaultLocale: localeConfig.defaultLocale,
      supportedLocales: localeConfig.supportedLocales,
    );

    test('a fresh install starts in Arabic', () async {
      SharedPreferences.setMockInitialValues({});
      final m = manager();
      await pumpEventQueue();
      expect(m.currentLocale, const Locale('ar'));
    });

    test('an install that already chose English keeps it', () async {
      SharedPreferences.setMockInitialValues({'trufi_locale': 'en'});
      final m = manager();
      await pumpEventQueue();
      expect(m.currentLocale, const Locale('en'));
    });

    test('an install that chose Arabic stays in Arabic', () async {
      SharedPreferences.setMockInitialValues({'trufi_locale': 'ar'});
      final m = manager();
      await pumpEventQueue();
      expect(m.currentLocale, const Locale('ar'));
    });

    test('switching to English from the picker is persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final m = manager();
      await pumpEventQueue();
      m.setLocaleByCode('en');
      await pumpEventQueue();
      expect(m.currentLocale, const Locale('en'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('trufi_locale'), 'en');
    });
  });
}
