# Task 12 — v5 → v6

## Why

v5 looked clean but three concrete issues surfaced during use:

1. **Sliders were choppy under drag.** Click-to-jump worked fine; drag did not. Each `input` event re-ran the heavy map cell (~177 country paths + ~1500 hex paths + 241 plate paths + 10 000 dot circles all torn down and rebuilt) at ~60 Hz, which throttled the slider thumb and made the page feel laggy.
2. **Year window with two side-by-side single-handle sliders was awkward.** Two thumbs that didn't share a track, no indication of the active window, and the shape conflicted with the magnitude slider's single-handle pattern next to it.
3. **The map was too monochrome.** Land and water shared the same `quartz` beige; only faint country borders distinguished them. Plate boundaries in `alloy` 1.0 px / 0.7 opacity vanished into the warm carpet.

## Changes

| Area | v5 | v6 |
|---|---|---|
| Year window UI | Two stacked-on-a-shared-row single-handle sliders, each with its own thumb | Single dual-handle range slider — one track, two thumbs, an `alloy` fill between them showing the active window. Soft clamp: a thumb pushed past the other parks against it instead of crossing |
| Slider drag | Re-rendered the heavy map cell on every `input` event (~60 Hz during drag) — choppy thumb | Debounced proxy: `input` events are batched into a single flush 120 ms after the user stops moving the slider. Map only rebuilds on settle. Readouts still update live during drag via direct DOM manipulation, so the user sees feedback at frame rate |
| Reset path | `dispatchEvent(new Event("input"))` on the inputs (debounced) | `dispatchEvent(new Event("t12:flush"))` — custom event the proxy handles for an immediate flush, so the map updates instantly on reset |
| Ocean | `quartz` (#D6D0C2) — same warm beige as land borders | `mediumQuartz` (#BAB3AB) — a stone-grey that's clearly cooler / darker than the land |
| Land fill | transparent (so ocean colour shows through) | `lightQuartz` (#ECEAE4) — a clear cream lighter than the ocean by ~15 % value |
| Land borders | `darkQuartz` 0.5 px / 0.7 opacity | `alloy` 0.4 px / 0.45 opacity (slightly thinner, slightly more saturated; reads as a quiet division line on the new land fill) |
| Plate boundaries | `alloy` 1.0 px / 0.7 opacity — washed out | `onyx` 1.1 px / 0.85 opacity — near-black on cream land, the strongest line on the map without dominating |
| Plate-on-zoom | scaled 0.7 → 0.9 with zoom | scaled 0.85 → 0.95 (already strong at world view; small bump on zoom keeps them legible against the dot layer) |
| Legend swatch | alloy line | onyx line, matching the new plate stroke |

## Why a debounced proxy beats other options

The map's *correct* state during a drag is the latest slider value, not the value at every keyframe along the way. Re-rendering for each intermediate value wastes work and chokes the slider. Three options to fix:

- **Throttle to 16 ms** — still ~60 rebuilds/sec; barely better.
- **Listen to `change` only (release)** — no preview during drag, breaks the dashboard feel.
- **Debounce to 120 ms** ✓ — drag feels smooth, map updates promptly on release.

Caveat: the readouts (`1980 – 2025`, `M5.0`) need to update *live* during the drag. Otherwise the slider would feel disconnected. Solution: the toolbar cell attaches its own `input` listeners directly to the source elements (not the debounced proxy) and updates the readout DOM imperatively. Listeners are removed via `invalidation.then(...)` so they don't accumulate across cell re-runs.

## Why a dual-handle slider over two single-handles

The previous side-by-side pair didn't visually communicate "this is one window with a start and an end." Two thumbs on the same track do, instantly. The fill between them tells the user "everything in here is selected." The pattern matches every modern dashboard's date-range control. Implementation:

- Two `<input type=range>` overlaid absolutely on the same track.
- `pointer-events: none` on the input itself, `pointer-events: auto` on the thumb pseudo-element — so each thumb can be grabbed even though the other input would normally cover it.
- A fill `<div>` positioned between the two thumbs as a percentage of the range, updated on every input event.
- A soft clamp keeps `min ≤ max` by parking the trailing thumb against the leading one when they meet.

## Why the colour change reads as "land vs water"

The brand palette is intentionally narrow and warm-neutral. Earlier versions used the warm bias for everything — land *and* water. v6 picks the two existing tokens with the largest value gap (`lightQuartz` ≈ 92 % luminance vs `mediumQuartz` ≈ 73 %) and assigns the lighter to land, the darker to ocean. That's an automatic ~15 % luminance step at the coastline, which the eye reads as a clear boundary even in greyscale. No new colours were added.

The plate-boundary colour bump from `alloy` to `onyx` is the same logic: take the existing token with the strongest contrast against the *cream land* (where the boundary has to remain readable) and use it. `onyx` reads as near-black on cream while `alloy` reads as muddy grey.

## Defensibility against the design system

- **No new colours.** All marks use existing PG palette tokens; the page remains brand-consistent and survives a greyscale test.
- **Heritage red still ≤ 10 % of ink.** Unchanged: dense hexes, callout ring, selected-country fill, USGS link, slider thumb on `:active`. The bumped plate boundaries are `onyx`, not red.
- **No double encoding.** Slider value → thumb position only. Slider window → fill width only. Slider readout → text only.
- **No chartjunk added.** The dual-track + fill div is data-bearing (it shows the active window). The land/ocean tone change is a basemap clarity choice, not decoration.

## Screenshots

- `v6_world_overview.png` — canonical hero. Cream land on stone-grey ocean, plate boundaries in onyx tracing the seismic carpet. Sumatra 2004 callout.
- `v6_year_2010.png` — year window narrowed to 2010–2025 via the dual-handle slider. Active fill clearly visible between thumbs; readout updated; map / histograms / year strip filtered.
- `v6_indonesia_2010.png` — year 2010–2025 + Indonesia clicked. Country card with stat tiles + inset; year strip shows pale-quartz backdrop carrying the 2004 Sumatra spike against the dark 2010+ window — the linked-views story is clear at a glance.
- `v6_mediterranean.png` — Mediterranean preset (k=4). North Anatolian Fault, Hellenic Trench, Zagros, Red Sea Rift all clearly visible as onyx lines through stone-grey ocean and cream land.
- `v6_japan.png` — Japan clicked; M9.1 Tōhoku callout retargets, Japan filled in heritage-red overlay, year strip 2011 spike clear.

## Verification (per CLAUDE.md `Browser verification` rule)

Verified live in Chromium via Playwright MCP against `npm run dev`:

1. ✅ Page loads, no console errors.
2. ✅ Dual-handle slider renders as one track + two thumbs + alloy fill between them; both thumbs interactive (pointer-events on the thumbs only).
3. ✅ Drag on the min thumb to 2010 → fill collapses to the right 33%, readout updates to "2010 – 2025" instantly, map / histograms / year strip update on settle.
4. ✅ Reset → dual-range thumbs snap to 1980 / 2025, fill fills the whole track, readout reverts, all dependent cells re-render.
5. ✅ Ocean now visually distinguishable from land at world view; continents read as cream silhouettes against stone-grey ocean.
6. ✅ Plate boundaries clearly visible in onyx — Mid-Atlantic Ridge, East Pacific Rise, Sunda Trench, North Anatolian Fault all readable without zooming.
7. ✅ Mediterranean preset → smooth zoom to k=4; plate boundaries crisp through the dot layer; chip in active state.
8. ✅ Indonesia + 2010 case still shows the linked-views story (2004 spike in pale backdrop, 2010+ in dark red overlay).
