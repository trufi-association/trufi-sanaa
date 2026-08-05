/**
 * Sana'a GTFS generator.
 *
 * Uses trufi-gtfs-builder as a library. Output goes to ./out/.
 * The resulting gtfs.zip is what gets shipped to:
 *   - trufi-app/assets/routing/sanaa.gtfs.zip (offline routing in the APK)
 *
 * Starting point: the upstream Cochabamba config
 * (trufi-app/tools/gtfs-bolivia-cochabamba/index.ts) adapted to Sana'a.
 *
 * The values below mirror the parameters of the currently bundled Sana'a feed
 * (Asia/Aden timezone, all-day frequency service every 5 min, bus routes from
 * OSM). Sana'a-specific tweaks live here — adjust them here, not in upstream.
 */

import { osmToGtfs, OSMOverpassDownloader, OSMPBFReader } from 'trufi-gtfs-builder';
import * as path from 'path';
import * as fs from 'fs';

type DataSource = 'overpass' | 'pbf';

const DATA_SOURCE: DataSource = 'pbf';

const PBF_FILE = path.join(__dirname, '..', 'pbf-yemen-sanaa', 'out', 'sanaa.osm.pbf');

const BOUNDING_BOX = {
  south: 15.161991,
  west: 44.023938,
  north: 15.642149,
  east: 44.399674,
};

function getOsmDataGetter() {
  if (DATA_SOURCE === 'pbf') {
    if (!fs.existsSync(PBF_FILE)) {
      throw new Error(
        `PBF file not found: ${PBF_FILE}\n` +
        `Generate it with the sibling tool: cd ../pbf-yemen-sanaa && docker compose up --build`,
      );
    }
    return new OSMPBFReader(PBF_FILE);
  }
  return new OSMOverpassDownloader(BOUNDING_BOX);
}

async function main() {
  console.log(`Generating GTFS for Sana'a (source: ${DATA_SOURCE})...`);

  await osmToGtfs({
    outputFiles: {
      outputDir: path.join(__dirname, 'out'),
      gtfs: true,
      gtfsZip: true,
      readme: true,
      log: true,
      stops: true,
      routes: false,
      trufiTPData: false,
    },
    geojsonOptions: {
      osmDataGetter: getOsmDataGetter(),
      // Public-transport relation types to convert. Sana'a's network is bus +
      // shared minibuses/taxis; widen this list if other modes get mapped.
      transformTypes: ['bus', 'share_taxi', 'minibus'],
      // Despite the name, the builder KEEPS a route when this returns true and
      // skips it when false (it does `if (!skipRoute(r)) continue`). Returning
      // true keeps every route in the bbox; to drop a problematic relation,
      // return false for its id, e.g. `(r) => ![123, 456].includes(r.id)`
      // (which is how Cochabamba prunes a handful of broken relations).
      skipRoute: () => true,
    },
    gtfsOptions: {
      // One GTFS route per OSM relation: Sana'a's ~194 lines share only 4
      // refs (157 use "7"), and grouping by ref collapsed them into 4 routes
      // — the route list showed 192 identical rows. See issue #1.
      routePerRelation: true,
      agencyTimezone: 'Asia/Aden',
      agencyUrl: 'https://www.trufi-association.org/',
      cityName: 'sanaa',
      // All-day service every 5 minutes — matches the bundled feed's
      // calendar (Mo-Su) and frequencies (06:00-23:00, headway 300 s).
      defaultCalendar: () => 'Mo-Su 06:00-23:00',
      frequencyHeadway: () => 300,
      vehicleSpeed: () => 30,
      // Sana'a bus relations generally have no physical stops mapped in OSM, so
      // stops are synthesized from the route geometry (a stop per shape node,
      // segment-merged + gap-filled at `fakeStopsGapThreshold` density) and
      // named after the nearest streets.
      stopsConfig: () => ({ mode: 'fakeStops' }),
      fakeStopsGapThreshold: 100,
      stopNameBuilder: (stops: string[] | undefined) => {
        if (!stops || stops.length === 0) {
          stops = ['غير مسماة']; // "unnamed" (ar)
        }
        return stops.join(' و '); // "and" (ar)
      },
      feed: {
        publisherName: 'Trufi Association',
        publisherUrl: 'https://www.trufi-association.org/',
        lang: 'ar',
        version: '1.0',
        contactEmail: 'info@trufi-association.org',
        contactUrl: 'https://www.trufi-association.org/',
        startDate: '20240101',
        endDate: '20271231',
        id: 'sanaa',
      },
    },
  });

  console.log(`Done. Output in ${path.join(__dirname, 'out')}`);
}

main().catch((err) => {
  console.error('GTFS generation failed:', err);
  process.exit(1);
});
