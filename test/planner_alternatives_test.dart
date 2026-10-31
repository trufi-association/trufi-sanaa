// Issue #16: the planner returned a single card for most trips. One of the
// two reasons is a planner rule: as soon as a direct line exists, every
// one-change itinerary is dropped, although it was computed (the other is
// the list's grouping by the first bus's short name, untouched here).
// trufi-core#1043 makes that rule optional and the app switches it off
// (`directsHideTransfers: false` in `sanaaPlannerConfig`): the one-change
// options follow the direct lines. Trips that only plan with two or more
// changes are searched exactly as before. Planned against the bundled
// feed through the same provider the app wires.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trufi/main.dart' show sanaaPlannerConfig;
import 'package:trufi_core_routing/trufi_core_routing.dart';

/// The app's config with the core default: a direct line hides the
/// one-change itineraries.
const directsHide = TrufiPlannerConfig.local(
  gtfsAsset: 'assets/routing/sanaa.gtfs.zip',
  maxWalkingDistance: 1500,
  maxTransfers: 4,
  maxStopCandidates: 600,
  directsHideTransfers: true,
  persistIndex: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // POIs of assets/pois: the hotel of issue #21 and Tahrir Square
  // (OSM node 4811192021); the trip of issue #16's reopening, from the
  // Dar Salm roundabout to the Hasaba hypermarket.
  const hotel = LatLng(15.3133526, 44.2355717); // فندق تونس الحديث
  const tahrirSquare = LatLng(15.3540162, 44.2059055); // ميدان التحرير
  const darSalm = LatLng(15.28064, 44.24430); // جولة دار سلم
  const hasaba = LatLng(15.37844, 44.20752); // الحصبه هايبر ماركت

  Future<List<Itinerary>> planWith(
    TrufiPlannerConfig config,
    LatLng from,
    LatLng to,
  ) async {
    final provider = TrufiPlannerProvider(config: config);
    final plan = await provider.fetchPlan(
      from: RoutingLocation(position: from, description: 'from'),
      to: RoutingLocation(position: to, description: 'to'),
      dateTime: DateTime(2026, 9, 28, 9),
    );
    expect(plan.type, isNot('PLANNER_ERROR'));
    return plan.itineraries ?? const [];
  }

  List<String> busesOf(Itinerary it) => [
    for (final leg in it.legs)
      if (leg.transitLeg) leg.route?.gtfsId ?? leg.route?.id ?? '?',
  ];

  test('the app lists the one-change options after the direct lines', () {
    expect(sanaaPlannerConfig.directsHideTransfers, isFalse);
    // The rest of the config is the one the comparison below relies on.
    expect(
      directsHide.maxWalkingDistance,
      sanaaPlannerConfig.maxWalkingDistance,
    );
    expect(directsHide.maxTransfers, sanaaPlannerConfig.maxTransfers);
    expect(directsHide.maxStopCandidates, sanaaPlannerConfig.maxStopCandidates);
  });

  test('hotel -> Tahrir Square: direct lines first, then one change', () async {
    final its = await planWith(sanaaPlannerConfig, hotel, tahrirSquare);
    final buses = its.map(busesOf).toList();
    final directs = buses.where((b) => b.length == 1).toList();
    final oneChange = buses.where((b) => b.length == 2).toList();
    expect(directs, isNotEmpty, reason: buses.toString());
    expect(oneChange, isNotEmpty, reason: buses.toString());
    expect(buses.any((b) => b.length > 2), isFalse, reason: buses.toString());
    // Ordering: every direct itinerary precedes every one-change one.
    final lastDirect = buses.lastIndexWhere((b) => b.length == 1);
    final firstChange = buses.indexWhere((b) => b.length == 2);
    expect(lastDirect, lessThan(firstChange), reason: buses.toString());
  });

  test(
    'regression: with the core default the same trip shows the directs only',
    () async {
      final hidden = await planWith(directsHide, hotel, tahrirSquare);
      final shown = await planWith(sanaaPlannerConfig, hotel, tahrirSquare);
      expect(
        hidden.map(busesOf).every((b) => b.length == 1),
        isTrue,
        reason: hidden.map(busesOf).toString(),
      );
      // The direct lines are the same rows in the same order; the app only
      // appends the one-change bucket.
      expect(
        shown.map(busesOf).where((b) => b.length == 1).toList(),
        hidden.map(busesOf).toList(),
      );
    },
  );

  test(
    'a trip that needs two changes (issue #16) is planned as before',
    () async {
      final shown = await planWith(sanaaPlannerConfig, darSalm, hasaba);
      final hidden = await planWith(directsHide, darSalm, hasaba);
      expect(shown, isNotEmpty);
      expect(
        shown.map(busesOf).every((b) => b.length == 3),
        isTrue,
        reason: shown.map(busesOf).toString(),
      );
      expect(shown.map(busesOf).toList(), hidden.map(busesOf).toList());
    },
  );
}
