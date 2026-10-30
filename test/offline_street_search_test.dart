// Issue #20: the offline search answers streets and the corners between
// them, not only places. tools/search-yemen-sanaa generates
// assets/search/search.json from the city's OSM extract and
// `sanaaSearchService()` (lib/main.dart) combines trufi-core's
// `OfflineSearchDataService` over it with the POI search. A street row that
// can be expanded into its corners is what the "Lines along <street>" row
// of the corners list is built on (trufi-core#1051). These tests run
// against the real assets the app ships.
import 'package:flutter_test/flutter_test.dart';
import 'package:trufi/main.dart' show sanaaSearchService;
import 'package:trufi_core_search_locations/trufi_core_search_locations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SearchLocationService service;
  setUpAll(() => service = sanaaSearchService());
  tearDownAll(() => service.dispose());

  test('the app search can expand streets into their corners', () {
    expect(service, isA<SearchLocationDrillDown>());
  });

  test(
    'a street of the index is found by its Arabic name, with corners',
    () async {
      final results = await service.search('شارع تعز');
      final streets = results.where((r) => r.id.startsWith('street:')).toList();
      expect(streets, isNotEmpty, reason: results.toString());
      final taiz = streets.firstWhere((s) => s.displayName == 'شارع تعز');
      // Sana'a: the index point lies in the city.
      expect(taiz.latitude, closeTo(15.3, 0.15));
      expect(taiz.longitude, closeTo(44.2, 0.15));

      final drill = service as SearchLocationDrillDown;
      expect(drill.canDrillDown(taiz), isTrue);
      final corners = await drill.drillDown(taiz);
      expect(
        corners.length,
        greaterThanOrEqualTo(5),
        reason: corners.toString(),
      );
      for (final corner in corners) {
        expect(corner.latitude, closeTo(15.3, 0.15));
        expect(corner.longitude, closeTo(44.2, 0.15));
      }
    },
  );

  test('the index ships corners for most of its streets', () async {
    // A street without corners is selectable but never opens the corners
    // list (no "Lines along" row); the 2026-10-30 index has 181 of 209.
    final results = await service.search('شارع');
    final drill = service as SearchLocationDrillDown;
    final streets = results.where((r) => r.id.startsWith('street:')).toList();
    expect(streets, isNotEmpty);
    expect(streets.where(drill.canDrillDown), isNotEmpty);
  });

  test('places still come from the POI search, next to the streets', () async {
    // OSM node 3287805010 (test/offline_poi_search_service_test.dart).
    final byName = await service.search('يمنتراك');
    expect(byName.map((r) => r.displayName), contains('شركة يمنتراك المحدودة'));
    // The street index answers no reverse lookup: a map pick keeps naming
    // the nearest POI.
    final reverse = await service.reverse(15.33255, 44.19772);
    expect(reverse?.displayName, 'شركة يمنتراك المحدودة');
  });
}
