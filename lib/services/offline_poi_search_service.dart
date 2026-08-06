import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:trufi_core_search_locations/trufi_core_search_locations.dart';

/// A [SearchLocationService] that searches the bundled Sana'a POIs offline.
///
/// The app is offline-first and makes no network calls, so address search is
/// served entirely from the POI GeoJSON assets shipped with the app (the same
/// data the map's POI layers use). Matching is a case-insensitive substring
/// over each place's Arabic and English names plus its street.
class OfflinePoiSearchService implements SearchLocationService {
  OfflinePoiSearchService({
    required this.poiAssetPaths,
    this.biasLatitude,
    this.biasLongitude,
    this.maxResults = 25,
  });

  /// GeoJSON asset paths to index (FeatureCollections of Point features).
  final List<String> poiAssetPaths;

  /// Optional bias point: on equal relevance, nearer results rank first.
  final double? biasLatitude;
  final double? biasLongitude;

  /// Maximum number of results returned by [search].
  final int maxResults;

  List<_PoiEntry>? _entries;

  Future<List<_PoiEntry>> _loadEntries() async {
    final cached = _entries;
    if (cached != null) return cached;

    final entries = <_PoiEntry>[];
    for (final path in poiAssetPaths) {
      try {
        final raw = await rootBundle.loadString(path);
        final decoded = json.decode(raw) as Map<String, dynamic>;
        final features = decoded['features'] as List<dynamic>? ?? const [];
        for (final f in features) {
          final feature = f as Map<String, dynamic>;
          final geometry = feature['geometry'] as Map<String, dynamic>?;
          final position = _positionOf(geometry);
          if (position == null) continue;
          final (lon, lat) = position;

          final props =
              (feature['properties'] as Map<String, dynamic>?) ?? const {};
          final name = _firstNonEmpty([
            props['name'],
            props['name:ar'],
            props['name:en'],
          ]);
          if (name == null) continue; // unnamed POIs aren't searchable

          final id = '${props['id'] ?? feature['id'] ?? '$lat,$lon'}';
          final address = _firstNonEmpty([
            props['addr:street'],
            props['addr:city'],
            props['subcategory'],
            props['category'],
          ]);
          final haystack = _normalize(
            [
              props['name'],
              props['name:ar'],
              props['name:en'],
              // Latin transliteration added at data-generation time so latin
              // queries can find POIs that only carry Arabic names in OSM.
              props['name:latin'],
              props['addr:street'],
            ].whereType<String>().join(' '),
          );

          entries.add(
            _PoiEntry(
              id: id,
              name: name,
              address: address,
              latitude: lat,
              longitude: lon,
              haystack: haystack,
            ),
          );
        }
      } catch (_) {
        // A single malformed/missing POI file shouldn't break search.
        continue;
      }
    }

    _entries = entries;
    return entries;
  }

  @override
  Future<List<SearchLocation>> search(String query) async {
    final q = _normalize(query.trim());
    if (q.isEmpty) return const [];

    final entries = await _loadEntries();
    var matches = <_PoiEntry>[
      for (final e in entries)
        if (e.haystack.contains(q)) e,
    ];

    // Latin fallback: unvocalized Arabic yields consonant-skeleton
    // transliterations (التحرير → "al-thryr"), so a vocalized query like
    // "Tahrir" misses them; retry with vowels stripped on both sides
    // ("thrr" ⊂ "l-thrr"). Guarded to 3+ consonants to keep false
    // positives down, and only fired when the exact pass found nothing.
    if (matches.isEmpty && RegExp('[a-z]').hasMatch(q)) {
      final dq = _devowel(q);
      if (dq.length >= 3) {
        matches = <_PoiEntry>[
          for (final e in entries)
            if (_devowel(e.haystack).contains(dq)) e,
        ];
      }
    }

    int rank(_PoiEntry e) => _normalize(e.name).startsWith(q) ? 0 : 1;
    matches.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      if (biasLatitude != null && biasLongitude != null) {
        return _distanceSq(a).compareTo(_distanceSq(b));
      }
      return a.name.compareTo(b.name);
    });

    return [
      for (final e in matches.take(maxResults)) e.toSearchLocation(),
    ];
  }

  @override
  Future<SearchLocation?> reverse(double latitude, double longitude) async {
    final entries = await _loadEntries();
    if (entries.isEmpty) return null;

    _PoiEntry? nearest;
    var nearestSq = double.infinity;
    for (final e in entries) {
      final dLat = e.latitude - latitude;
      final dLon = e.longitude - longitude;
      final d = dLat * dLat + dLon * dLon;
      if (d < nearestSq) {
        nearestSq = d;
        nearest = e;
      }
    }

    // ~0.0015° ≈ 150 m: only snap to a POI that's genuinely close, otherwise
    // let the caller fall back to a generic "dropped pin" label.
    if (nearest == null || nearestSq > 0.0015 * 0.0015) return null;
    return nearest.toSearchLocation();
  }

  @override
  void dispose() {
    _entries = null;
  }

  double _distanceSq(_PoiEntry e) {
    final dLat = e.latitude - biasLatitude!;
    final dLon = e.longitude - biasLongitude!;
    return dLat * dLat + dLon * dLon;
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  /// Case folding plus Arabic normalization, applied to both the indexed
  /// haystack and the query so spelling variants match: diacritics and
  /// tatweel are stripped, alif variants (أ إ آ) unify to ا, ة to ه and
  /// ى to ي.
  static String _normalize(String s) {
    var t = s.toLowerCase();
    t = t.replaceAll(RegExp('[ً-ْٰـ]'), '');
    t = t.replaceAll(RegExp('[أإآ]'), 'ا');
    t = t.replaceAll('ة', 'ه');
    t = t.replaceAll('ى', 'ي');
    return t;
  }

  static String _devowel(String s) =>
      s.replaceAll(RegExp('[aeiouy]'), '');

  /// Representative (lon, lat) of a geometry. Points use their coordinate;
  /// Polygon/MultiPolygon use the outer-ring centroid — without this, every
  /// polygon POI (universities, squares, big mosques) was silently dropped
  /// from the index because its `coordinates` is a ring list, not a pair.
  static (double, double)? _positionOf(Map<String, dynamic>? geometry) {
    final type = geometry?['type'];
    final coords = geometry?['coordinates'] as List<dynamic>?;
    if (coords == null) return null;
    switch (type) {
      case 'Point':
        if (coords.length < 2) return null;
        return ((coords[0] as num).toDouble(), (coords[1] as num).toDouble());
      case 'Polygon':
        return _ringCentroid(coords.isEmpty ? null : coords[0]);
      case 'MultiPolygon':
        if (coords.isEmpty) return null;
        final first = coords[0] as List<dynamic>;
        return _ringCentroid(first.isEmpty ? null : first[0]);
      default:
        return null;
    }
  }

  static (double, double)? _ringCentroid(dynamic ring) {
    if (ring is! List || ring.isEmpty) return null;
    var lon = 0.0, lat = 0.0, n = 0;
    for (final p in ring) {
      if (p is List && p.length >= 2) {
        lon += (p[0] as num).toDouble();
        lat += (p[1] as num).toDouble();
        n++;
      }
    }
    if (n == 0) return null;
    return (lon / n, lat / n);
  }
}

class _PoiEntry {
  const _PoiEntry({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.haystack,
  });

  final String id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final String haystack;

  SearchLocation toSearchLocation() => SearchLocation(
    id: id,
    displayName: name,
    address: address,
    latitude: latitude,
    longitude: longitude,
  );
}
