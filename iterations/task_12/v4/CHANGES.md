# Task 12 — v3 → v4

## Why

v3 was technically clean (zoom worked, hex tiling was clean, country click resolved offshore events) but visually flat:

1. **Story not asserted.** Title was a question — "Where the Earth's plates grind?" — and the chart didn't answer it because plate boundaries weren't drawn. The hex carpet showed *seismicity*, but the geological *frame* was missing, so the alignment between events and tectonic boundaries had to be inferred. With no boundary overlay, the reveal landed on viewers who already knew where the boundaries were.
2. **Page was a vertical stack of equal-weight blocks.** Sliders → presets → reset → map → empty country panel → histogram → year strip. The map should dominate; instead it competed with everything above and below it for screen real estate.
3. **Click-a-country yielded a 5-row table.** No spatial confirmation, no scope summary, no visual anchor in the country itself. The interaction was correct but felt anticlimactic — and the histogram + year strip didn't react at all to the country selection (Shneiderman: linked views).
4. **Map background `lightQuartz` + low-end ramp `quartz` washed out at world view.** Beige-on-beige; only the densest hexes carried any ink.

## Changes

| Element | v3 | v4 |
|---|---|---|
| Title | "Where the Earth's plates grind" (a question) | "Plate boundaries draw themselves" (a claim, with the answer in the subtitle) |
| Plate-boundary overlay | none | Bird (2003) PB2002 LineString GeoJSON, drawn over the hex carpet in `alloy` 1.0 px non-scaling stroke at 0.7 opacity |
| Page layout | single column, sliders above map | 280 px sidebar (controls + how-to-read) + 1 fr map column, then 1 fr country card, then 1 fr / 1 fr histogram + year strip |
| Map background | `lightQuartz` (#ECEAE4) | `quartz` (#D6D0C2) — the low end of the hex ramp (`lightQuartz`) now sits at the bg level so low-density hexes recede; only mid- and high-density cells take ink |
| Hex ramp | `quartz` → `copper` → `heritageRedDark` | `lightQuartz` → `copper` → `heritageRedDark` |
| Country borders | `mediumQuartz` 0.5 px | `darkQuartz` 0.5 px @ 0.7 opacity (a hair quieter against the darker bg) |
| Linked views | filters only | country click also filters histogram + year strip; pale-quartz backdrop on year strip shows the country's all-years distribution at the magnitude threshold, dark overlay shows the year-window subset |
| Country detail | 5-row table | stat tiles (events, largest M, M ≥ 6 share) + inset country map with top-5 events as red circles sized by magnitude + condensed event list |
| Selected-country style | `quartz` fill + `heritageRedDark` outline | `heritageRed` fill at 0.18 opacity (visible at world view without dominating) + `heritageRedDark` outline 1.6 px |
| Largest-event callout | always the global largest in window | retargets to the country's largest event when a country is selected |
| Map architecture | single cell — country click rebuilt the whole SVG and lost zoom | split into cell 11 (heavy, rebuilds on filter / preset change) and cell 11b (light, mutates highlight + callout in place); zoom transform persisted across rebuilds via `window.__t12_zoom__` and `__t12_preset__` |

## What "linked views" buys

In v3, clicking Japan filled the table beneath the map — but the histogram and year strip kept showing the global distribution. The v4 wiring scopes both Plot panels to the country's events when one is selected:

- **Magnitude distribution** switches from copper to `heritageRedDark` and shows only the country's events under the active filter window.
- **Year strip** does the same for the year overlay; the pale `quartz` backdrop layer becomes the country's *all-years* distribution at the current magnitude threshold, so narrowing the year window draws a clear "this fraction of this country's seismic history" rectangle.

The Indonesia + 2010–2025 view is the demo case: dark red overlay on the right of the year strip, pale on the left containing the 2004 Sumatra spike; the country card shows M7.8 (2010) as the largest in-window event with the Sumatra/Sunda Trench geometry visible in the inset map.

## Why a split-cell map architecture

Observable Framework re-runs a cell whenever its dependencies change. v3's map cell read `selectedCountry`, so a country click triggered a full SVG rebuild — discarding the user's zoom transform. The fix was to take `selectedCountry` *out* of the heavy cell and put it in a light cell (11b) that mutates the existing SVG in place via D3 selections.

Cell 11 (heavy): builds countries, hexes, plates, dots, zoom controller, callout shell. Reads `filtered`, `magThreshold`, `presetState`. Re-renders only when those change.

Cell 11b (light): updates `path.selected-country-fill` and the `circle.callout-ring` / `text.callout-label` based on `selectedCountry` and the country-scoped `filteredCountry`. Does not touch any other layer.

Zoom transform persistence uses `window.__t12_zoom__` because a Framework Mutable read in cell 11 would re-render on every pan event. A window-level global is read once on render and written on every zoom event without triggering reactivity. The companion `window.__t12_preset__` lets cell 11 distinguish "preset just changed → apply preset transform" from "same preset, restoring the user's pan."

## Layout discovery (and the `<p>` trap)

First v4 attempt put the layout grid directly in markdown:

```
<div style="display:grid;grid-template-columns:280px 1fr">
<div>${yearRangeInput}…</div>
<div>${mapSvg}…</div>
</div>
```

Map column rendered at 640 px instead of 1072 px. Diagnosis: Framework's typography CSS caps `<p>` width at 640 px, and Markdown wraps a standalone `${node}` interpolation in a `<p>` element. Fix: move the layout into a JS code block and call `display(html\`<div…>…</div>\`)`. The `display()` path inserts the node directly under `#observablehq-main` (max-width: none) without a paragraph wrapper. Same fix applied to the histogram + year-strip grid.

## Defensibility against the design system

- Heritage Red still ≤ 10 % of ink: only the densest hexes; the M9.1 callout ring; the selected-country fill at 0.18 opacity; the USGS link colour. The plate-boundary overlay is `alloy`, not red — keeps the red budget intact.
- No double encoding: count → hex colour only; magnitude → dot or inset-circle radius only.
- Colorblind: warm sand-to-crimson ramp passes deuteranopia by construction; plate-boundary line is grey so its information channel doesn't depend on hue.
- Story clarity: subtitle states the answer ("45 years of seismicity trace those boundaries from the data alone"); the boundary overlay is the visual proof.

## Screenshots

- `v4_world_overview.png` — default world view; plate boundaries visible across Mid-Atlantic Ridge, East Pacific Rise, Andes, Pacific Ring, Mediterranean–Himalaya belt; hex density piles up exactly along the boundaries
- `v4_japan_clicked.png` — Japan click at world view; M9.1 callout retargets to Tōhoku 2011, country card shows 5,697 events / 501 ≥ M6, year strip overlay scoped to Japan with the unmistakable 2011 spike
- `v4_indonesia_2010plus.png` — Indonesia + year window narrowed to 2010–2025; year strip shows pale-quartz backdrop (Indonesia's full 1980–2025 history at M ≥ 5, including the 2004 spike) overlaid by the dark 2010–2025 window
- `v4_mediterranean_preset.png` — Mediterranean preset (k=4); hexes faded out, individual event dots visible across the Hellenic Trench, North Anatolian Fault, Zagros; Japan card persists from the prior selection
- `v4_ring_of_fire.png` — Ring of Fire preset (k=2.2); SE Asia / Indonesia / Vanuatu / Marianas trench arcs all visible; Sumatra 2004 callout

## Verification (per CLAUDE.md `Browser verification` rule)

Verified live in Chromium via Playwright MCP against `npm run dev`:

1. ✅ Page loads, no console errors (only `/favicon.ico` 404).
2. ✅ Plate-boundaries GeoJSON loads (241 LineString features), drawn as 241 `<path class="plate">` elements.
3. ✅ Map column renders at 1072 px (full grid cell), not 640 px.
4. ✅ Click Japan → callout retargets to Tōhoku 2011 M9.1; histogram switches to heritageRedDark and shows Japan's distribution; year strip shows the 2011 spike.
5. ✅ Click "Mediterranean" preset → smooth zoom to k=4 over the Med basin; Japan card persists from the prior click (preset doesn't clear country selection).
6. ✅ Reset → all filters cleared, year sliders back to 1980/2025, no country selected, world view restored.
7. ✅ Year-window narrow + Indonesia click → year strip pale-quartz backdrop visible (2004 Sumatra spike shows in the pale layer; dark layer covers only 2010–2025).
8. ✅ Manual wheel-zoom to k=8, then click Italy → `window.__t12_zoom__` transform is byte-identical before and after the click; Italy highlight applied without map rebuild.
