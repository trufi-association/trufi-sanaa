// Issue #17: places present in OSM were missing from the offline search
// because the POI extraction only covered the extractor's default tag set.
// These tests run against the real assets the app ships (assets/pois/).
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:trufi/main.dart' show poiAssetPaths;
import 'package:trufi/services/offline_poi_search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfflinePoiSearchService service;
  setUpAll(() {
    service = OfflinePoiSearchService(
      poiAssetPaths: poiAssetPaths,
      biasLatitude: 15.3470,
      biasLongitude: 44.2050,
    );
  });
  tearDownAll(() => service.dispose());

  test('the search indexes every category the POI layers ship', () async {
    final metadata =
        json.decode(await rootBundle.loadString('assets/pois/metadata.json'))
            as Map<String, dynamic>;
    final categories = (metadata['categories'] as List<dynamic>).map(
      (c) => (c as Map<String, dynamic>)['name'] as String,
    );
    expect(
      poiAssetPaths.toSet(),
      categories.map((c) => 'assets/pois/$c.geojson').toSet(),
      reason: 'poiAssetPaths in lib/main.dart must list every category file',
    );
  });

  test('finds the office reported in #17 by its Arabic and English names',
      () async {
    // OSM node 3287805010: office=company, name=شركة يمنتراك المحدودة,
    // name:en=YemenTrack LLC, 15.33255 N 44.19772 E.
    final byArabic = await service.search('يمنتراك');
    expect(byArabic, isNotEmpty, reason: 'office=company must be indexed');
    final hit = byArabic.first;
    expect(hit.displayName, 'شركة يمنتراك المحدودة');
    expect(hit.latitude, closeTo(15.33255, 0.0005));
    expect(hit.longitude, closeTo(44.19772, 0.0005));

    final byEnglish = await service.search('yementrack');
    expect(byEnglish.map((p) => p.id), contains(hit.id));
  });

  test('indexes the tag families the default categories left out', () async {
    // One example per family added in tools/pois-yemen-sanaa/categories.json.
    const examples = <(String, String)>[
      ('مركز العزاني التجاري', 'shop=clothes'),
      ('صالة ليالي الشرق', 'amenity=events_venue'),
      ('محطة بشرى مأرب', 'amenity=fuel'),
      ('الفاخرللخياطة', 'craft=tailor'),
      ('معهد يالي', 'office=educational_institution'),
      ('سفارة جمهورية ألمانيا الاتحادية', 'office=diplomatic'),
    ];
    for (final (name, tag) in examples) {
      final results = await service.search(name);
      expect(
        results.map((p) => p.displayName),
        contains(name),
        reason: '$tag should be in the search index',
      );
    }
  });

  test('still finds the landmarks of the original categories', () async {
    final babAlYaman = await service.search('باب اليمن');
    expect(babAlYaman, isNotEmpty);
    final tahrir = await service.search('tahrir');
    expect(tahrir, isNotEmpty);
    expect(tahrir.first.displayName, contains('التحرير'));
  });
}
