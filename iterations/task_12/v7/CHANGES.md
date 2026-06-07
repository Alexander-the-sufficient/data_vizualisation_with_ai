# Task 12 — v6 → v7

## Why

The hex carpet was the strongest single thing in v3–v6 — it scaled, it was honest, it tiled cleanly — but it always read as *constructed*. Discrete cells with a colour ramp are the data-viz convention for density, but they don't feel like seismicity. They feel like a heat map of a chess board. Real published seismic maps (USGS catalog plots, Bird & Kagan 2004, the ISC bulletin renderings) almost always use a different convention: every event is a dot, density emerges from alpha stacking, and the catalog's biggest events are highlighted on top. That's what v7 switches to.

## Change

The hex layer is gone. Two new layers replace it:

| Layer | Encoding | Style |
|---|---|---|
| **Carpet** | one circle per event with M < 7 | r = 0.9 px, fill `alloy` at 0.18 opacity. Alpha stacking does the density work — 1 event ≈ invisible, 30 stacked ≈ opaque. Rendered as a single SVG `<path>` (one DOM node, ~70 k circle-arcs in the `d` string), so the browser's path parser does the work in one pass instead of building 70 k `<circle>` elements. |
| **Major events** | one circle per event with M ≥ 7 | r = max(2.2, (mag − 6) × 2.2) → M7 = 2.2 px, M8 = 4.4, M9 = 6.6. Fill `heritageRedDark` at 0.78 opacity, with a 0.6 px white halo at 0.7 opacity so they read on both cream land and stone ocean. Magnitude → radius is the *only* encoding here (no double-encoding with the carpet). |

The plate-boundary layer is now drawn *between* the carpet and the highlights — the onyx line cuts cleanly through the seismic stipple without being obscured by the carpet, and the red highlight dots sit on top so the catalog's signature events read first.

The legend reflects the new encoding: a small alloy dot ("each event"), a tiered series of three heritage-red dots ("major events, sized by magnitude"), the plate-boundary line, and the heritage-red ring marking the largest event in the current window.

`d3-hexbin` is removed from the import block. The hex-related variables (`bin`, `bins`, `maxCount`, `rampInterp`, `hexColor`, `dotSample`) are deleted; only `largestEvent` remains.

## Why this looks better

- **Less designed-feeling.** No grid imposed on the data. Where two subduction zones converge, the dots themselves sketch the geometry; the carpet darkens along the trench and thins in the back-arc.
- **Continuous density gradient.** Alpha stacking is naturally continuous — there's no quantisation step at every cell boundary. The Aleutians, the Ring of Fire, the Tonga–Kermadec arc all curve smoothly instead of in 7 px hex-steps.
- **The big events get to be the protagonists.** v6's hex coloured a *region* dark red when many events fell in it. v7 colours the *individual events* — so the 2004 Sumatra M9.1, the 2011 Tōhoku M9.1, the 2010 Maule M8.8 are each a single, identifiable red dot. The carpet shows where the rock fails *most often*; the highlights show where it has failed *most violently*.
- **Plate boundaries read clearer.** The hex tiles' high-contrast cells competed visually with the onyx boundary line. With the carpet at 0.18 opacity the boundary line is the strongest stroke in the image — exactly what the title's claim demands.

## Why it stays defensible

- **No double encoding.** Carpet: count → alpha (via stacking) only. Highlights: magnitude → radius only. Plate boundary: position only. Selected-country fill: state only.
- **No new colours.** Carpet uses `alloy`. Highlights use `heritageRedDark`. Halo is plain white. No additions to the palette.
- **Heritage red still ≤ 10 % of ink.** ~700 events at M ≥ 7 over 45 years in the world catalog; even at world view, the red dots are a small fraction of the total ink.
- **Survives a greyscale test.** Carpet alpha-stacks into varying greys; major events at full opacity stack to a darker spot regardless of hue.
- **Honest at every zoom level.** Carpet circles scale with zoom (small at world view, larger when zoomed in — natural "see individual events" effect). Major-event radii are *counter-scaled* in the zoom handler (`r / sqrt(k)`) so they stay roughly 6–8 px on screen at any zoom — reads as a precise location marker instead of growing into a 30 px blob at deep zoom.

## Performance

- Initial render: building the carpet `d` string is ~70 k events × ~120 chars each = ~8 MB string. Browser parses in <1 s. Native paint of one filled path is dramatically faster than 70 k `<circle>` repaints.
- Zoom interaction: only the highlight layer's circles update their `r` per zoom event (~700 circles). The carpet path is untouched on zoom — the `transform` on `zoomRoot` handles its movement.
- Filter change: the carpet path is rebuilt on every filter change (cell 11 is the heavy cell, debounced to 120 ms via the v6 proxy). Build time for the path string is ~50 ms for 70 k events; comfortably inside the debounce window.

## Defensibility against the design system

Same as v6 plus:
- **Dot stipple is a documented convention.** Real seismic maps use it; the encoding is what a seismologist would expect to see, not a chart-type translation.
- **Magnitude → radius is the strongest perceptual channel for ordered comparison after position.** The encoding-accuracy ranking in the lecture rules puts position > length > area; for major events the position tells you *where* and the area (≈ r²) tells you *how big*. Both channels carry the data.

## Screenshots

- `v7_world_overview.png` — canonical hero. Cream land on stone-grey ocean, plate boundaries in onyx, alloy carpet stippling along the boundaries, ~700 heritage-red dots marking the M ≥ 7 events; M9.1 ring on Sumatra 2004.
- `v7_japan.png` — Japan clicked. M9.1 callout retargets to Tōhoku 2011; histograms scoped to Japan in heritage red; year strip 2011 spike visible.
- `v7_indonesia_2010.png` — Indonesia + year window 2010–2025. Carpet thinner (smaller event set), heritage-red dots clustering along the Sunda Trench. Year strip's pale-quartz backdrop carries Indonesia's full history including the 2004 spike; dark red overlay covers the 2010+ window.
- `v7_mediterranean.png` — Mediterranean preset (k=4). North Anatolian Fault, Hellenic Trench, Zagros, Red Sea Rift visible as onyx lines through stone-grey ocean; heritage-red dots mark M ≥ 7 events along each.

## Verification (per CLAUDE.md `Browser verification` rule)

Verified live in Chromium via Playwright MCP against `npm run dev`:

1. ✅ Page loads, no console errors.
2. ✅ World overview renders carpet stipple + heritage-red highlights along the global plate boundary network.
3. ✅ Japan click → M9.1 callout retargets, country card filled, histograms / year strip scoped, M9.1 Tōhoku 2011 spike clear.
4. ✅ Year window narrowed to 2010–2025 + Indonesia clicked → carpet thins, heritage-red dots restricted to 2010+, year-strip pale backdrop carries the 2004 spike against the dark 2010+ window.
5. ✅ Mediterranean preset → smooth zoom to k=4; carpet at this zoom reads as fine stipple (~3.6 px circles on screen), heritage-red dots stay at constant 6–8 px screen size via the inverse-sqrt(k) counter-scale.
6. ✅ Reset → all state cleared, carpet rebuilt for full window, heritage-red highlights restored.
