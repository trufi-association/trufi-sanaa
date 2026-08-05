#!/usr/bin/env python3
"""Adds a `name:latin` transliteration to POI features that have no latin text.

The offline search matches plain substrings over the indexed names, so a POI
whose OSM entry only carries an Arabic `name` is unfindable with a latin
query ("Tahrir" vs "ميدان التحرير"). This script writes a romanized
`name:latin` (simple, deterministic mapping — not a linguistic
transliteration) for every named feature that lacks `name:en`/latin text,
and the search service indexes it.

Usage: python3 tools/pois-enrich-latin.py   (run from the app root; edits
assets/pois/*.geojson in place, idempotent)
"""
import json
import glob
import re
import sys
import os

AR2LAT = {
    'ا': 'a', 'أ': 'a', 'إ': 'i', 'آ': 'a', 'ء': "'", 'ؤ': "'", 'ئ': "'",
    'ب': 'b', 'ت': 't', 'ث': 'th', 'ج': 'j', 'ح': 'h', 'خ': 'kh',
    'د': 'd', 'ذ': 'dh', 'ر': 'r', 'ز': 'z', 'س': 's', 'ش': 'sh',
    'ص': 's', 'ض': 'd', 'ط': 't', 'ظ': 'z', 'ع': "'", 'غ': 'gh',
    'ف': 'f', 'ق': 'q', 'ك': 'k', 'ل': 'l', 'م': 'm', 'ن': 'n',
    'ه': 'h', 'ة': 'a', 'و': 'w', 'ي': 'y', 'ى': 'a', 'ٱ': 'a',
    '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
    '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
}
DIACRITICS = re.compile('[ً-ْٰـ]')
HAS_LATIN = re.compile('[A-Za-z]')
HAS_ARABIC = re.compile('[؀-ۿ]')

# Nombres ingleses reales de lugares muy conocidos (los que un tester
# escribe primero). La transliteración cubre la cola larga.
WELL_KNOWN = {
    'ميدان التحرير': 'Tahrir Square',
    'باب اليمن': 'Bab al-Yaman',
    'فرزة باب اليمن': 'Bab al-Yaman Bus Station',
    'جامعة صنعاء': "Sana'a University",
    'جامع الصالح': 'Al Saleh Mosque',
    'الجامع الكبير': "Great Mosque of Sana'a",
    'مطار صنعاء الدولي': "Sana'a International Airport",
    'شارع حدة': 'Hadda Street',
    'شارع الزبيري': 'Al-Zubairi Street',
    'سوق الملح': 'Souq al-Milh (Salt Market)',
    'دار الحجر': 'Dar al-Hajar',
    'حديقة السبعين': 'Al-Sabeen Park',
    'ميدان السبعين': 'Al-Sabeen Square',
    'المتحف الوطني': 'National Museum',
    'المتحف الحربي': 'Military Museum',
}

# El artículo "ال" al inicio de palabra se translitera "al-"
AL_PREFIX = re.compile(r'\bال')


def transliterate(text: str) -> str:
    t = DIACRITICS.sub('', text)
    t = AL_PREFIX.sub('al×', t)  # marcador temporal para el guion
    out = []
    for ch in t:
        out.append(AR2LAT.get(ch, ch))
    r = ''.join(out).replace('×', '-')
    r = re.sub(r'\s+', ' ', r).strip()
    return r


def main() -> int:
    base = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
    files = sorted(glob.glob(os.path.join(base, 'assets/pois/*.geojson')))
    if not files:
        print('no geojson files found', file=sys.stderr)
        return 1
    total = added = 0
    for path in files:
        data = json.load(open(path, encoding='utf-8'))
        changed = False
        for feat in data.get('features', []):
            props = feat.setdefault('properties', {})
            name = props.get('name') or props.get('name:ar') or ''
            if not name:
                continue
            total += 1
            known = WELL_KNOWN.get(name.strip())
            if known and not props.get('name:en'):
                props['name:en'] = known
                added += 1
                changed = True
            existing = ' '.join(
                str(props.get(k) or '') for k in ('name', 'name:en', 'name:latin')
            )
            if HAS_LATIN.search(existing):
                continue  # ya se puede encontrar con una query latina
            if not HAS_ARABIC.search(name):
                continue
            latin = transliterate(name)
            if latin and HAS_LATIN.search(latin):
                props['name:latin'] = latin
                added += 1
                changed = True
        if changed:
            json.dump(
                data, open(path, 'w', encoding='utf-8'),
                ensure_ascii=False, separators=(',', ':'),
            )
    print(f'named features: {total} · name:latin added: {added}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
