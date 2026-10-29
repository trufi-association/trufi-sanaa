/**
 * Sana'a POI extractor.
 *
 * Runs trufi-server-poi_extractor as a library over the Sana'a PBF with the
 * categories in ./categories.json — the extractor's defaults plus the tag
 * sets the Sana'a community actually uses (office=*, craft=*, the whole
 * shop=* range, wedding halls, fuel stations, institutes, …; see README.md).
 * Output goes to ./out/; the resulting files are what gets shipped to
 * assets/pois/ (map POI layers + the offline search index).
 *
 * Why a script and not `poi-extractor -c categories.json`: the CLI's custom
 * categories loader calls `require('fs')` from an ES module, so the file
 * silently fails to load and the defaults are used instead (upstream bug in
 * loadCategories, src/categories.ts).
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { extractFromPBF, configureIcons } from 'trufi-server-poi_extractor';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const PBF_FILE = path.join(__dirname, '..', 'pbf-yemen-sanaa', 'out', 'sanaa.osm.pbf');
const OUT_DIR = path.join(__dirname, 'out');
const CATEGORIES_FILE = path.join(__dirname, 'categories.json');

if (!fs.existsSync(PBF_FILE)) {
  throw new Error(
    `PBF file not found: ${PBF_FILE}\n` +
      `Generate it with the sibling tool: cd ../pbf-yemen-sanaa && docker compose up --build`,
  );
}

const categories = JSON.parse(fs.readFileSync(CATEGORIES_FILE, 'utf-8'));

// The npm package does not ship the extractor's icons/ folder (its `files`
// list leaves it out), so every maki SVG this config references lives in
// ./icons/maki — the upstream set plus the ones added for Sana'a.
configureIcons({ iconsDir: path.join(__dirname, 'icons') });

fs.rmSync(OUT_DIR, { recursive: true, force: true });

console.log("Extracting POIs for Sana'a...");
const { metadata, poisByCategory } = await extractFromPBF({
  inputFile: PBF_FILE,
  outputDir: OUT_DIR,
  categories,
  verbose: true,
});

// ── Post-processing ────────────────────────────────────────────────────
// 1. Arabic labels. The extractor only emits displayName:en/es/de; the `ar`
//    labels in categories.json are added here so the layer picker is Arabic
//    in the Arabic UI (trufi_core_poi_layers reads any `displayName:<lang>`).
// 2. The GeoJSON files are written minified: that is how the committed
//    assets look (tools/pois-enrich-latin.py rewrites them that way) and it
//    keeps the diff about data, not whitespace.
function withArabic(entry, config) {
  const out = {};
  for (const [key, value] of Object.entries(entry)) {
    out[key] = value;
    if (key === 'displayName:de' && config?.displayName?.ar) {
      out['displayName:ar'] = config.displayName.ar;
    }
  }
  return out;
}
metadata.categories = metadata.categories.map((category) => {
  const config = categories[category.name];
  const withSubs = withArabic(category, config);
  if (withSubs.subcategories) {
    withSubs.subcategories = withSubs.subcategories.map((sub) =>
      withArabic(sub, config?.subcategories?.find((s) => s.name === sub.name)),
    );
  }
  return withSubs;
});
fs.writeFileSync(path.join(OUT_DIR, 'metadata.json'), JSON.stringify(metadata, null, 2));

for (const [name, pois] of Object.entries(poisByCategory)) {
  fs.writeFileSync(
    path.join(OUT_DIR, `${name}.geojson`),
    JSON.stringify({ type: 'FeatureCollection', features: pois }),
  );
}

// ── Report ─────────────────────────────────────────────────────────────
console.log('');
console.log('POIs per category (named / total):');
for (const category of metadata.categories) {
  const pois = poisByCategory[category.name];
  const named = pois.filter((p) => p.properties.name).length;
  console.log(`  ${category.name.padEnd(12)} ${String(named).padStart(5)} / ${String(pois.length).padStart(5)}`);
  for (const sub of category.subcategories ?? []) {
    const subPois = pois.filter((p) => p.properties.subcategory === sub.name);
    const subNamed = subPois.filter((p) => p.properties.name).length;
    console.log(`    ${sub.name.padEnd(16)} ${String(subNamed).padStart(5)} / ${String(subPois.length).padStart(5)}`);
  }
}
console.log(`  total        ${String(metadata.total).padStart(5)}`);
console.log('');
console.log(`Done. Output in ${OUT_DIR}`);
