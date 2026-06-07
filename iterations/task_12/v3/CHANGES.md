# Task 12 — v2 → v3

## Why

Two issues with v2:

1. **Visible hex overlap.** v2's `Plot.hexbin({...}, {binWidth: 12, r: 8})` drew hexagonal marks of radius 8 px on a 12 px-spaced grid — the rendered hexes were larger than the bin spacing, so they bled into each other across the whole map. The world view read as a noisy, half-merged carpet rather than a tiled density surface. Fix requires either matching `r` to `binWidth/2` or switching to a hex-tiling library that handles the math.

2. **No real "interactive" beyond the click-on-hex.** v2 had click-to-select-hex (a 5° lat/lon grid lookup, approximate by design) but no pan, no zoom, and no per-country drill-down. The course definition expects more — and "I can see Japan is dense, but I can't drill into 'what happened in Japan'" was the immediate user feedback after the v2 deploy.

## Changes

| Element | v2 | v3 |
|---|---|---|
| Map library | `Plot.plot` with `Plot.hexbin` transform | Hand-rolled D3 SVG with `d3.geoEqualEarth`, `d3-hexbin` (NPM dep added), and `d3.zoom` |
| Hex tiling | `binWidth: 12, r: 8` (overlapping) | `d3-hexbin().radius(7)` (clean tiling, no gaps) |
| Pan / zoom | None — `regionFocus` dropdown only swapped projection rotation | Real `d3.zoom()` on the SVG: scroll-wheel zoom, drag pan, scaleExtent `[1, 32]` |
| Region focus | Dropdown (World / Pacific Ring / Mid-Atlantic Ridge) — projection rotation only | "Zoom to" button row (World / Ring of Fire / Mediterranean / Andes) — each preset is a `d3.zoomIdentity` translate+scale to a fixed center |
| Detail-panel input | `selectedHex` (5° lat/lon grid bucket of the most-recently-clicked hex) | `selectedCountry` (the GeoJSON Feature of the most-recently-clicked country) |
| Country–event index | Approximate 5° grid | Two-pass: (1) `d3.geoContains` against Natural Earth polygons, (2) USGS `place`-tail fallback for offshore events. Built once at load (~1.5 s for 77 k events × 177 countries). |
| Encoding at zoom | Same hexes everywhere | Crossfade around k=2: hexes carry the world-view density story; dots (top 10 000 events by magnitude) overlay above k≈1.5 so individual events are inspectable when zoomed in |
| Country selection style | n/a | Selected country gets `heritageRedDark` outline + `quartz` fill — the "single editorial callout" allowance from the design system |
| Reset scope | Year + magnitude + selectedHex | Year + magnitude + preset back to "world" + selectedCountry cleared |

## Why the place-tail fallback matters (Tōhoku edge case)

The 2011 M9.1 Tōhoku earthquake — the canonical "click on Japan, see this event" target — sat ~130 km east of Honshu, in the ocean. Pure point-in-polygon assignment puts it outside Japan's polygon, so a polygon-only index would miss it. With the place-tail fallback (`"off the east coast of Honshu, Japan"` → `Japan`), Japan's event count rises from 580 (polygon-only) → 5 697 (polygon + place-tail), and the M9.1 Tōhoku is the first row of Japan's detail panel. The fallback triggers similarly for Sumatra trench events, Vanuatu Trench events, and the Bonin Islands sequence. Events with neither a polygon match nor a recognisable place tail (mid-ocean ridges, Antarctic Peninsula sequences) remain visible on the map but are not selectable via country click — documented in the methods footer.

## Defensibility against the design-system rules

- **Heritage Red ≤ ~10 % of ink**: only the densest hexes hit `heritageRedDark` on the sqrt ramp; the M9.1 callout ring; the selected-country outline; the USGS event-page link colour. None of these exceed the 10 % budget on any frame.
- **No double encoding**: count is encoded by hex colour only (fixed radius); dots use only colour + small fixed radius.
- **Colorblind**: single-hue-warmth ramp (sand → bronze → crimson) passes deuteranopia by construction; lightness gradient is monotonic so it survives a grayscale test.
- **Story clarity**: world view still reads as the Pacific Ring of Fire arc; the country click + zoom drill-down is the new layer on top.

## Cell-by-cell delta

- **Cell 7**: dropdown → preset button row. Active preset shows in `alloy`. Clicking writes `presetState`.
- **Cell 8**: `selectedHex` → `selectedCountry`. Holds a GeoJSON Feature.
- **Cell 9a**: brand-new country index. Two-pass (polygon + place tail). Built once at load.
- **Cell 9b**: `filtered` unchanged; `eventsByCell` removed; `filteredByMagOnly` retained for the year strip.
- **Cell 10**: deleted (projection rotation no longer needed; zoom replaces it).
- **Cell 11**: rewritten from `Plot.plot` → `d3.create("svg")` with country layer, hex layer, dot layer, callout layer, and a `d3.zoom` controller. Encoding crossfade around k≈2.
- **Cell 14**: detail panel reads `selectedCountry`; intersects `eventsByCountry.get(id)` with the current filter window; sorts top-5 by magnitude.
- **Cell 15**: reset extends to `setPreset("world")` + `setSelectedCountry(null)`.

Cells 12 (magnitude histogram) and 13 (year strip) are untouched.

## Screenshots

- `v3_world_overview.png` — default world view at k=1, hexes tile cleanly with no overlap (compare to `iterations/task_12/v2/after_v2_world.png`)
- `v3_japan_clicked.png` — Japan clicked at world view; detail panel shows 5 697 events, top row Tōhoku 2011 M9.1 (recovered via place-tail fallback)
- `v3_mediterranean_zoom.png` — "Mediterranean" preset (k=4): hexes faded, individual event dots visible across Iran, Türkiye, Greece
- `v3_mediterranean_iran_clicked.png` — Mediterranean preset + Iran clicked: country outlined in `heritageRedDark`, panel shows Iran's top 5 (M7.7 Khash 2013, M7.4 Manjil 1990, …)

## Verification (per CLAUDE.md `Browser verification` rule)

Verified live in Chromium via Playwright MCP against the local dev server (`npm run dev`):

1. ✅ Page loads, no console errors (only a 404 for `/favicon.ico`).
2. ✅ 177 country paths rendered; 1 464 hex tiles (clean tiling); 10 000 dot samples ready in the dot layer with opacity 0.
3. ✅ Click Japan polygon → detail panel updates to "Japan · 5697 events", top row M9.1 Tōhoku 2011.
4. ✅ "Ring of Fire" preset → smooth zoom to k=2.2, hex opacity 0.4, dot opacity 0.7.
5. ✅ Synthetic wheel event → k=4, hex opacity 0.15, dots fully opaque.
6. ✅ "Reset all filters" → year sliders back to 1980/2025, magnitude back to 5.0, preset back to World, transform null (identity), selection cleared.
7. ✅ Mediterranean preset + Iran click → Iran outlined in `heritageRedDark`, panel shows 623 events with the canonical M7.7 Khash 2013 at the top.
