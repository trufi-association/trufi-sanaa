import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trufi/main.dart' show sanaaPlannerConfig;
import 'package:trufi_core_routing/trufi_core_routing.dart';

/// Issue #21: from جامع المرور the line شميلة ⟵ بينون (route 20023104)
/// vanished from the results although its first stop is 1 381 m away,
/// inside the 1 500 m walk radius. The planner only boards at the 150
/// stops nearest to the origin and in that neighbourhood the 150th stop
/// is 1 188 m away, so the line could not be boarded at all; the planner
/// answered with a 14 that drops the rider 1.5 km from the destination.
/// Plans the reporter's two trips against the bundled feed with the app's
/// exact configuration and with the old pool, through the same provider
/// the app wires.
/// The app's config with the previous pool of 150, the planner's default.
const oldPool = TrufiPlannerConfig.local(
  gtfsAsset: 'assets/routing/sanaa.gtfs.zip',
  maxWalkingDistance: 1500,
  maxTransfers: 4,
  maxStopCandidates: 150,
  persistIndex: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // POIs of assets/pois (the screenshots' origins) and the reporter's
  // "Selected Location, 15.295…" next to the route's last stops.
  const hotel = LatLng(15.3133526, 44.2355717); // فندق تونس الحديث
  const mosque = LatLng(15.3178359, 44.2308792); // جامع المرور
  const destination = LatLng(15.2952, 44.2275);
  const theRoute = '20023104'; // 7  شميلة ⟵ بينون

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

  List<String> routesOf(Itinerary it) => [
    for (final leg in it.legs)
      if (leg.transitLeg) leg.route?.gtfsId ?? leg.route?.id ?? '?',
  ];

  bool mentions(List<Itinerary> its, String routeId) =>
      its.any((it) => routesOf(it).contains(routeId));

  test('the app plans with every stop within 1 500 m (pool of 600)', () {
    expect(sanaaPlannerConfig.isLocal, isTrue);
    expect(sanaaPlannerConfig.maxWalkingDistance, 1500);
    expect(sanaaPlannerConfig.maxTransfers, 4);
    // No stop of this feed has more than 520 neighbours within 1 500 m.
    expect(sanaaPlannerConfig.maxStopCandidates, 600);
  });

  test(
    'near origin (hotel): the line is the first result either way',
    () async {
      for (final config in [sanaaPlannerConfig, oldPool]) {
        final its = await planWith(config, hotel, destination);
        expect(its, isNotEmpty);
        expect(routesOf(its.first), [
          theRoute,
        ], reason: 'pool ${config.maxStopCandidates}');
      }
    },
  );

  test('far origin (mosque): the line is offered as a direct ride', () async {
    final its = await planWith(sanaaPlannerConfig, mosque, destination);
    expect(
      mentions(its, theRoute),
      isTrue,
      reason: its.map(routesOf).toString(),
    );
    final direct = its.firstWhere((it) => routesOf(it).contains(theRoute));
    expect(routesOf(direct), [theRoute]);
  });

  test('regression: with the old pool of 150 the line disappears', () async {
    // Same config but for the pool, so the comparison stays honest if the
    // app's radius or transfer limit ever changes.
    expect(oldPool.maxWalkingDistance, sanaaPlannerConfig.maxWalkingDistance);
    expect(oldPool.maxTransfers, sanaaPlannerConfig.maxTransfers);
    final its = await planWith(oldPool, mosque, destination);
    expect(its, isNotEmpty);
    expect(
      mentions(its, theRoute),
      isFalse,
      reason: its.map(routesOf).toString(),
    );
  });
}
