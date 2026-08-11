import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:trufi_core_about/trufi_core_about.dart';
import 'package:trufi_core_home_screen/trufi_core_home_screen.dart';
import 'package:trufi_core_maps/trufi_core_maps.dart';
import 'package:trufi_core_navigation/trufi_core_navigation.dart';
import 'package:trufi_core_poi_layers/trufi_core_poi_layers.dart';
import 'package:trufi_core_routing/trufi_core_routing.dart'
    show
        RoutingEngineManager,
        IRoutingProvider,
        TrufiPlannerProvider,
        TrufiPlannerConfig;
import 'package:trufi_core_saved_places/trufi_core_saved_places.dart';
import 'package:trufi_core_search_locations/trufi_core_search_locations.dart';
import 'package:trufi_core_settings/trufi_core_settings.dart';
import 'package:trufi_core_transport_list/trufi_core_transport_list.dart';
import 'package:trufi_core_ui/trufi_core_ui.dart';
import 'package:trufi_core_utils/trufi_core_utils.dart' show OverlayManager;

import 'l10n/l10n.dart';
import 'services/offline_poi_search_service.dart';

// ============ CONFIGURATION ============
// Sana'a, Yemen (Amanat Al Asimah). This is an OFFLINE-FIRST build: the transit
// data (GTFS), map tiles (MBTiles) and points of interest are all bundled as
// assets, and the app makes no network calls. The bundled community transport
// data comes from OpenStreetMap (mapped by the Sana'a community).
const _defaultCenter = LatLng(15.3470, 44.2050);
const _appName = "Trufi Sana'a";
const _deepLinkScheme = 'trufiapp';
const _cityName = "Sana'a";
const _countryName = 'Yemen';
const _emailContact = 'info@trufi-association.org';

// POI GeoJSON assets, also used by the offline address search below.
const _poiAssetPaths = <String>[
  'assets/pois/education.geojson',
  'assets/pois/emergency.geojson',
  'assets/pois/finance.geojson',
  'assets/pois/food.geojson',
  'assets/pois/government.geojson',
  'assets/pois/healthcare.geojson',
  'assets/pois/recreation.geojson',
  'assets/pois/religion.geojson',
  'assets/pois/shopping.geojson',
  'assets/pois/tourism.geojson',
  'assets/pois/transport.geojson',
];

// Routing engines: offline only.
final List<IRoutingProvider> _routingEngines = [
  // Offline routing from the bundled Sana'a GTFS feed (mobile only).
  if (!kIsWeb)
    TrufiPlannerProvider(
      config: const TrufiPlannerConfig.local(
        gtfsAsset: 'assets/routing/sanaa.gtfs.zip',
        // OTP parity (~20 min access walk; Cochabamba prod uses
        // accessEgress.maxDuration 20m). The 800 m default leaves most of
        // Sana'a's periphery unplannable: 33% of the served area is within
        // 800 m of a stop vs 48% within 1500 m (issue #2). Note the core
        // suppresses transfer options whenever a direct exists, so a far
        // direct boarding can replace short-walk transfer alternatives —
        // deliberate core behavior (one fare per ride) this radius amplifies.
        maxWalkingDistance: 1500,
      ),
    ),
];

// Map engines: offline only (Sana'a MBTiles). No online tile servers.
final List<ITrufiMapEngine> _mapEngines = [
  if (!kIsWeb)
    OfflineMapLibreEngine(
      engineId: 'offline_osm_liberty',
      displayName: 'Standard (offline)',
      displayDescription: 'Standard offline map',
      config: OfflineMapConfig(
        mbtilesAsset: 'assets/offline/sanaa.mbtiles',
        styleAsset: 'assets/offline/styles/osm-liberty/style.json',
        spritesAssetDir: 'assets/offline/styles/osm-liberty/',
        fontsAssetDir: 'assets/offline/fonts/',
        fontMapping: {
          'RobotoRegular': 'Roboto Regular',
          'RobotoMedium': 'Roboto Medium',
          'RobotoCondensedItalic': 'Roboto Condensed Italic',
        },
        fontRanges: [
          '0-255',
          '256-511',
          '512-767',
          '768-1023',
          '1024-1279',
          '1280-1535',
          // Arabic block + Arabic Supplement. Without these, no Arabic map
          // label can render at all ("Failed to load glyph range 1536-1791")
          // — and Sana'a is labeled in Arabic everywhere. Glyphs come from
          // Klokantech Noto Sans (Roboto has no Arabic coverage).
          '1536-1791',
          '1792-2047',
          '8192-8447',
          '8448-8703',
          // Arabic Presentation Forms A/B: MapLibre's text shaping requests
          // these for joined (cursive) letterforms.
          '64256-64511',
          '64512-64767',
          '64768-65023',
          '65024-65279',
        ],
      ),
    ),
];
// ========================================

void main() {
  runTrufiApp(
    AppConfiguration(
      appName: _appName,
      deepLinkScheme: _deepLinkScheme,
      // English UI by default, with Arabic (RTL) available in settings.
      // Arabic for all screens is provided APP-SIDE via extraLocalizationsDelegates
      // (see lib/l10n/), so this app uses the official trufi-core — no fork.
      // To default to Arabic, put Locale('ar') first in supportedLocales.
      localeConfig: const TrufiLocaleConfig(
        supportedLocales: [Locale('en'), Locale('ar')],
        defaultLocaleIndex: 0,
      ),
      // Pin routing to midday so the offline planner returns results regardless
      // of when the app is opened; the time picker stays hidden.
      routingTimeOverride: const TimeOfDay(hour: 12, minute: 0),
      extraLocalizationsDelegates: [
        // Arabic for all trufi-core screens — provided app-side (lib/l10n/),
        // so this app uses official trufi-core (no fork) for the language.
        ...L10n.delegates,
      ],
      themeConfig: TrufiThemeConfig(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E88E5)),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E88E5),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
      ),
      providers: [
        ChangeNotifierProvider(
          create: (_) => MapEngineManager(
            engines: _mapEngines,
            defaultCenter: _defaultCenter,
            // Open zoomed into central Sana'a so the street grid is visible.
            defaultZoom: 14,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => RoutingEngineManager(engines: _routingEngines),
        ),
        ChangeNotifierProvider(
          create: (_) => OverlayManager(
            managers: [
              OnboardingManager(
                overlayBuilder: (onComplete) =>
                    OnboardingSheet(onComplete: onComplete),
              ),
              // No privacy-consent overlay: this is an offline-first build that
              // collects and transmits nothing, so a data-collection consent
              // prompt would be misleading.
            ],
          ),
        ),
        BlocProvider(
          create: (_) => SearchLocationsCubit(
            // Offline-first: search the bundled Sana'a POIs, no network.
            searchLocationService: OfflinePoiSearchService(
              poiAssetPaths: _poiAssetPaths,
              biasLatitude: _defaultCenter.latitude,
              biasLongitude: _defaultCenter.longitude,
            ),
          ),
        ),
      ],
      screens: [
        HomeScreenTrufiScreen(
          config: HomeScreenConfig(
            appName: _appName,
            deepLinkScheme: _deepLinkScheme,
            poiLayersManager: POILayersManager(assetsBasePath: 'assets/pois'),
          ),
          onStartNavigation: (context, itinerary, locationService) {
            NavigationScreen.showFromItinerary(
              context,
              itinerary: itinerary,
              locationService: locationService,
              mapEngineManager: MapEngineManager.read(context),
            );
          },
          onRouteTap: (context, routeCode) {
            TransportDetailScreen.show(context, routeCode: routeCode);
          },
        ),
        SavedPlacesTrufiScreen(),
        TransportListTrufiScreen(),
        SettingsTrufiScreen(),
        AboutTrufiScreen(
          config: AboutScreenConfig(
            appName: _appName,
            cityName: _cityName,
            countryName: _countryName,
            emailContact: _emailContact,
          ),
        ),
      ],
    ),
  );
}
