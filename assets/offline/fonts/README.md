# Glyph PBFs

- **Latin/base ranges** (0-255 … 8448-8703): KlokanTech Noto Sans build
  (`klokantech/klokantech-gl-fonts`), served under the Roboto* fontstack
  names the style references.
- **Arabic ranges** (1536-1791, 1792-2047, 64256-64511, 64512-64767,
  64768-65023, 65024-65279): MapLibre's Noto Sans Regular build
  (`demotiles.maplibre.org/font/Noto Sans Regular/…`), replaced 2026-08-11
  because the KlokanTech build is missing 39 Arabic presentation forms —
  including U+FE8D (isolated alef), which every word starting with ال
  needs; without it the renderer drops letters (القحطمي → لقحطمي).
  Strict superset per range (+141 glyphs, −0). See trufi-sanaa#3 / PR #4.

The three fontstack folders carry identical PBFs per range on purpose:
the style's text-font stacks are single-font, and the offline engine maps
each folder to its stack name (see `fontMapping` in `lib/main.dart`).
