# Trufi Sana'a App

An **offline-first** public-transport app for **Sana'a, Yemen (Amanat Al Asimah)**, built on the
modern Trufi Core (v5) architecture. It is a fork of
[`trufi-association/trufi-app`](https://github.com/trufi-association/trufi-app) relocated entirely to
Sana'a.

The app works **completely offline** and makes **no network calls**: the transit data (GTFS), the
map tiles (MBTiles), the points of interest, and address search are all bundled as assets. This fits
Sana'a well — the network is relatively stable, route changes are infrequent, and connectivity can be
limited.

> **Community data.** The bundled Sana'a transport network, map and POIs come from OpenStreetMap,
> mapped on the ground by the Sana'a community. See the proposal discussion
> [trufi-core#912](https://github.com/trufi-association/trufi-core/discussions/912).

## ✨ Features

- **Offline maps** — 4 MapLibre styles (OSM Liberty, OSM Bright, Dark Matter, Fiord Color) rendered
  from a bundled Sana'a `.mbtiles`.
- **Offline routing** — public-transport trip planning from a bundled Sana'a GTFS feed.
- **Offline search** — address/place search over the bundled POIs (Arabic & English names), no
  geocoding server.
- **POI layers** — 11 categories of points of interest (healthcare, education, food, government, …).
- **Step-by-step navigation** for public-transport trips.
- **Saved places** and a full **transport route list**.

## 🌐 Offline-first by design

| Feature | This app |
|---|---|
| Map tiles | Bundled `assets/offline/sanaa.mbtiles` (offline) |
| Routing | Bundled `assets/routing/sanaa.gtfs.zip` (offline GTFS) |
| Address search | Local POIs (`OfflinePoiSearchService`), no server |
| Online tile servers / OTP / Photon | **Removed** |
| Network calls | **None** |

## 📱 App identifiers

- **Android applicationId / iOS bundle id**: `app.trufi.sanaa`
- **Display name**: Trufi Sana'a
- **Default map center**: `15.3694, 44.1910` (Sana'a)
- **Deep link scheme**: `trufiapp://` (custom scheme; works offline, no domain/App Links)

## 🌍 Languages

The UI ships in **Arabic** (RTL, the default) and **English**. A fresh install starts in Arabic and
the onboarding sheet lists Arabic first; English can be picked there or later in Settings, and an
install that already chose a language keeps it. Map and place content (POIs, street and place
names) is in Arabic, with English names where OpenStreetMap has them.

Arabic for every trufi-core screen is provided **app-side**: the translations live in
[`tools/l10n/i18n/ar/`](tools/l10n/i18n/ar/) and are generated into [`lib/l10n/`](lib/l10n/) with
`dart run trufi_core_utils:gen_extra_l10n` (see [`tools/l10n/README.md`](tools/l10n/README.md)), so
the app uses the official trufi-core packages — no fork.

## 📂 Asset structure

```
assets/
├── routing/
│   └── sanaa.gtfs.zip               # GTFS for offline routing
├── offline/
│   ├── sanaa.mbtiles                # Offline map tiles
│   ├── styles/                      # MapLibre styles (osm-bright/liberty/dark-matter/fiord-color)
│   └── fonts/                       # Glyph PBFs for the styles
└── pois/                            # POIs as GeoJSON (Arabic & English names) + metadata.json
    ├── education.geojson  emergency.geojson  finance.geojson  food.geojson
    ├── government.geojson healthcare.geojson recreation.geojson religion.geojson
    └── shopping.geojson   tourism.geojson    transport.geojson
```

## 🚀 Development

### Requirements

- Flutter SDK (3.x)
- Android SDK (Android) / Xcode (iOS)

### Run

```bash
flutter pub get
flutter gen-l10n        # generates lib/l10n/app_localizations*.dart
flutter run --debug     # Android / iOS
```

> Web is not a target of this offline build (offline MBTiles/GTFS are mobile-only).

## 🔗 Relationship to upstream

This fork tracks `trufi-association/trufi-core` packages (pulled via git in `pubspec.yaml`) and only
changes the **app shell** for Sana'a: city center & branding, offline-only engines, an offline POI
search service, removal of all `*.trufi.app` online endpoints and the original city's data, and
English/Arabic localization setup.

## 📞 Contact

- Email: <info@trufi-association.org>
- Website: <https://www.trufi-association.org>

## 📄 License

Copyright © Trufi Association. Same license as the upstream Trufi app.
