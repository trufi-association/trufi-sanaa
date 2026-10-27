// Issue #15: the map strings follow the UI language too. trufi-core ships
// the `maps` namespace in de/en/es only, so without an app-side Arabic ARB
// the onboarding map card, the online/offline chips, the map settings header
// and the choose-on-map screen stayed in English inside the Arabic UI. The
// Arabic comes from tools/l10n/i18n/ar/maps.arb through L10n.delegates, and
// the offline engine takes its name from that namespace instead of a
// hardcoded English `displayName`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trufi/l10n/l10n.dart';
import 'package:trufi/main.dart' show localeConfig, mapEngines;
import 'package:trufi_core_maps/l10n/maps_localizations.dart';
import 'package:trufi_core_ui/trufi_core_ui.dart'
    show fallbackLocalizationsDelegates;

/// Pumps a MaterialApp with the delegate order of core's `_TrufiMaterialApp`
/// (app delegates first, then core's, then the fallback layer that serves
/// the default language) and returns a context below it. Only the maps
/// delegate of `L10n.delegates` is registered: the other app delegates are
/// Arabic-only and, without their core counterparts, the `en` pump would
/// trip the framework's "locale not supported by all delegates" warning.
Future<BuildContext> pumpIn(WidgetTester tester, Locale locale) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: localeConfig.supportedLocales,
      localizationsDelegates: [
        ...L10n.delegates.where((d) => d.type == MapsLocalizations),
        ...MapsLocalizations.localizationsDelegates,
        ...fallbackLocalizationsDelegates(
          [MapsLocalizations.delegate],
          fallbackLocale: localeConfig.defaultLocale,
        ),
      ],
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pump();
  return captured;
}

void main() {
  test('the app ships an Arabic delegate for the maps namespace', () {
    final maps = L10n.delegates.where((d) => d.type == MapsLocalizations);
    expect(maps, hasLength(1));
    expect(maps.single.isSupported(const Locale('ar')), isTrue);
    expect(maps.single.isSupported(const Locale('en')), isFalse);
  });

  test('tools/l10n/i18n/ar/maps.arb translates every key (none left empty)',
      () {
    final arb =
        jsonDecode(File('tools/l10n/i18n/ar/maps.arb').readAsStringSync())
            as Map<String, dynamic>;
    final keys = arb.keys.where((k) => !k.startsWith('@')).toList();
    expect(keys, hasLength(20));
    for (final key in keys) {
      expect(arb[key], isA<String>());
      expect((arb[key] as String).trim(), isNotEmpty, reason: key);
    }
  });

  testWidgets('in Arabic the map strings and the offline engine are Arabic',
      (tester) async {
    final context = await pumpIn(tester, const Locale('ar'));
    final l10n = MapsLocalizations.of(context);
    expect(l10n.online, 'متصل');
    expect(l10n.offline, 'غير متصل');
    expect(l10n.mapSettings, 'إعدادات الخريطة');
    expect(l10n.chooseOnMap, 'اختر على الخريطة');
    expect(l10n.confirmLocation, 'تأكيد الموقع');
    expect(l10n.errorLoadingOfflineMap, 'خطأ في تحميل الخريطة بدون إنترنت');

    final engine = mapEngines.single;
    expect(engine.localizedName(context), 'خريطة بدون إنترنت');
    expect(
      engine.localizedDescription(context),
      'خريطة تعمل بالكامل بدون إنترنت',
    );
  });

  testWidgets('in English the offline engine uses core\'s default name',
      (tester) async {
    final context = await pumpIn(tester, const Locale('en'));
    expect(MapsLocalizations.of(context).mapSettings, 'Map Settings');
    final engine = mapEngines.single;
    expect(engine.localizedName(context), 'Offline Map');
    expect(engine.localizedDescription(context), 'Fully offline map');
  });
}
