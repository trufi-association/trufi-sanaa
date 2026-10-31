const fs = require('fs');
const searchDataExport = require('osm-search-data-export');
const { pbfInput, jsonCompactOutput } = searchDataExport;

// Reads the sibling tool's PBF and writes the search index the app bundles
// as assets/search/search.json (streets + junctions). Compact format:
// rows are positional arrays described by the _fields header — it's what
// OfflineSearchDataService parses.
//
// POIs are excluded on purpose: the service never reads them (places are
// Photon's job by design) and they were 51% of the file (trufi-app#45).
// Two mechanisms are needed: the empty poiTypeTags whitelist drops the
// non-street WAYS with POI tags, while named NODES land in `pois`
// unconditionally — the output wrapper below strips those.
// out/ is ignored since #56 (the index lives in the app's assets), and the
// exporter refuses an output path whose directory does not exist.
fs.mkdirSync('./out', { recursive: true });
const outPath = './out/search.json';
const writeCompact = jsonCompactOutput({ outPath });
searchDataExport(
  pbfInput({ inPath: '../pbf-yemen-sanaa/out/sanaa.osm.pbf' }),
  (data) => {
    data.pois = [];
    writeCompact(data);
    dropUnusableStreetNames(outPath);
  },
  { poiTypeTags: [] },
);

// A few Sana'a highways carry an OSM `name` that is not a name: "." or a
// bare number ("3180", "801"). The exporter keeps them (it only asks for a
// non-empty tag), and in the app they rank first for any query that starts
// with a digit. Drop every street whose name has no letter in any script,
// together with its corner rows, and strip the directional marks
// (U+200E/U+200F) that some mappers paste inside a name ("شارع ‏الثلاثين"),
// which otherwise break prefix matching. Done on the compact file so the
// rule is one place and the exporter stays untouched.
function dropUnusableStreetNames(path) {
  const index = JSON.parse(fs.readFileSync(path, 'utf8'));
  const nameField = index._fields.streets.indexOf('name');
  const marks = /[\u200e\u200f]/g;
  const dropped = [];
  for (const [id, row] of Object.entries(index.streets)) {
    row[nameField] = row[nameField].replace(marks, '');
    if (!/\p{L}/u.test(row[nameField])) {
      dropped.push(`${id} "${row[nameField]}"`);
      delete index.streets[id];
    }
  }
  const alive = new Set(Object.keys(index.streets));
  for (const [id, corners] of Object.entries(index.streetJunctions)) {
    if (!alive.has(id)) { delete index.streetJunctions[id]; continue; }
    const kept = corners.filter(([other]) => alive.has(other));
    if (kept.length === 0) delete index.streetJunctions[id];
    else index.streetJunctions[id] = kept;
  }
  fs.writeFileSync(path, JSON.stringify(index));
  console.log(`dropped ${dropped.length} street(s) without a letter in the name: ${dropped.join(', ')}`);
}
