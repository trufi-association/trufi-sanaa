// The Arabic UI is this app's own layer on top of trufi-core, which ships
// en/es/de: tools/l10n/i18n/ar/*.arb -> `dart run trufi_core_utils:gen_extra_l10n`
// -> lib/l10n/l10n_ar.dart, registered through `L10n.delegates`. Flutter keeps
// the first delegate of each type whose `isSupported` answers true, so the
// contract that keeps both languages working is: every app delegate answers
// `ar` only (core's own delegates serve `en`), there is one delegate per
// namespace, and the generated classes load. This file also keeps
// `flutter test` meaningful in CI: package:test exits with 79 ("No tests
// were found") when no suite declares a test, which is what the empty
// placeholder it replaces produced.
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trufi/l10n/l10n.dart';
import 'package:trufi_core_about/l10n/about_localizations.dart';

void main() {
  const ar = Locale('ar');
  const en = Locale('en');
  final arabicScript = RegExp(r'[؀-ۿ]');

  test('L10n.delegates ships one Arabic-only delegate per namespace', () {
    expect(L10n.delegates, isNotEmpty);
    for (final delegate in L10n.delegates) {
      expect(delegate.isSupported(ar), isTrue, reason: '$delegate');
      // `en` must stay with trufi-core's delegates, which come after these.
      expect(delegate.isSupported(en), isFalse, reason: '$delegate');
    }
    final types = L10n.delegates.map((d) => d.type).toList();
    expect(
      types.toSet(),
      hasLength(types.length),
      reason: 'two delegates of one type: the second is never consulted',
    );
  });

  test('every Arabic delegate loads its generated class', () async {
    for (final delegate in L10n.delegates) {
      expect(await delegate.load(ar), isNotNull, reason: '$delegate');
    }
  });

  testWidgets(
    'under Locale(ar) a core namespace reads Arabic and lays out RTL',
    (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        Localizations(
          locale: ar,
          delegates: [...L10n.delegates, GlobalWidgetsLocalizations.delegate],
          child: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(
        AboutLocalizations.of(captured).aboutContact,
        matches(arabicScript),
      );
      expect(Directionality.of(captured), TextDirection.rtl);
    },
  );
}
