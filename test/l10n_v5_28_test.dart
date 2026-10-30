// trufi-core v5.28.0 adds 54 localization members (nearby lines, lines
// along a street, saved routes, live ETA, coordinates search, the
// same-name notice of saved places). The generated lib/l10n/l10n_ar.dart
// extends core's abstract classes, so a missing one breaks the build, and
// one left empty in the ARB renders as '' in the UI: these tests pin that
// every new key is translated and that the parameterised ones carry their
// placeholder.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trufi/l10n/l10n_ar.dart';

void main() {
  final arabicScript = RegExp(r'[؀-ۿ]');

  const newKeys = <String, List<String>>{
    'home_screen': [
      'saveRoute',
      'saveRouteName',
      'buttonSave',
      'routeSaved',
      'routeAlreadySaved',
      'etaArrivesIn',
      'etaUnavailable',
      'etaLoading',
      'etaRefresh',
      'etaRefreshCooldown',
      'etaUpdated',
    ],
    'saved_places': [
      'placeNameInUse',
      'menuSavedRoutes',
      'noRoutesSaved',
      'noRoutesSavedHint',
      'savedRoutesSection',
      'routeOrigin',
      'routeDestination',
      'distanceMeters',
      'distanceKilometers',
      'durationMinutes',
      'durationHoursMinutes',
      'renameRoute',
      'routeName',
      'swapDirection',
      'removeRoute',
      'removeRouteConfirmation',
      'routeAlreadySaved',
      'errorLoadingRoutes',
    ],
    'transport_list': [
      'menuNearbyLines',
      'nearbyAnchorYourLocation',
      'nearbyAnchorPinned',
      'nearbyAnchorDefault',
      'nearbyAnchorAlongStreet',
      'nearbyUseMyLocation',
      'nearbyMovePinHint',
      'nearbyRadiusChip',
      'nearbyLinesInRadius',
      'nearbyAtDistance',
      'nearbyPassesAtDistance',
      'nearbyStopName',
      'nearbyTowards',
      'nearbySelectedLine',
      'nearbyEmptyTitle',
      'nearbyEmptyInRadius',
      'nearbyUnavailableTitle',
      'nearbyUnavailableHint',
      'nearbyLoadingData',
      'nearbyFooterNote',
      'nearbyOpenDetails',
      'nearbyClearSelection',
      'nearbyClose',
    ],
    'search_locations': ['linesAlongStreet', 'goToCoordinates'],
  };

  test(
    'every v5.28.0 key is translated in tools/l10n/i18n/ar (none empty)',
    () {
      var count = 0;
      for (final entry in newKeys.entries) {
        final arb =
            jsonDecode(
                  File(
                    'tools/l10n/i18n/ar/${entry.key}.arb',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        for (final key in entry.value) {
          expect(arb[key], isA<String>(), reason: '${entry.key}.$key');
          expect(
            arb[key] as String,
            matches(arabicScript),
            reason: '${entry.key}.$key',
          );
          count++;
        }
      }
      expect(count, 54);
    },
  );

  test('the generated Arabic classes render the new members with their '
      'placeholders', () {
    final transport = TransportListLocalizationsAr();
    expect(transport.menuNearbyLines, matches(arabicScript));
    expect(
      transport.nearbyLinesInRadius(12, 300),
      allOf(contains('12'), contains('300')),
    );
    expect(
      transport.nearbyRadiusChip(300, 8),
      allOf(contains('300'), contains('8')),
    );
    expect(transport.nearbyAnchorAlongStreet('شارع تعز'), contains('شارع تعز'));
    expect(
      transport.nearbyStopName('شارع تعز و شارع بينون'),
      contains('شارع تعز'),
    );

    final search = SearchLocationsLocalizationsAr();
    expect(search.linesAlongStreet('شارع تعز'), contains('شارع تعز'));
    expect(
      search.goToCoordinates('15.28064, 44.2443'),
      contains('15.28064, 44.2443'),
    );

    final saved = SavedPlacesLocalizationsAr();
    expect(saved.menuSavedRoutes, matches(arabicScript));
    expect(
      saved.removeRouteConfirmation('المنزل ← العمل'),
      contains('المنزل ← العمل'),
    );
    expect(
      saved.routeAlreadySaved('المنزل ← العمل'),
      contains('المنزل ← العمل'),
    );
    expect(
      saved.durationHoursMinutes(1, 15),
      allOf(contains('1'), contains('15')),
    );

    final home = HomeScreenLocalizationsAr();
    expect(home.routeSaved('المنزل ← العمل'), contains('المنزل ← العمل'));
    expect(home.etaArrivesIn(4), contains('4'));
    expect(home.etaRefreshCooldown(7), contains('7'));
    expect(home.etaUpdated('10:32'), contains('10:32'));
  });
}
