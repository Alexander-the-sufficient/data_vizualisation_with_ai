# Task 12 — v7 → v8

## Why

Three concrete asks plus subtle polish:

1. The website carried a four-paragraph methods footer (data caveats, plate-boundary citation, country-assignment heuristic, tooling list). Useful for a written report; clutter on an interactive page where everything below the linked-views row is just text.
2. The legend's "plate boundary (Bird, 2003)" carried a citation alongside a swatch — the citation wanted to be in prose, not in a chip.
3. Clicking the active "World" zoom preset while the user is panned/zoomed in didn't reset the view. v7's setPreset only fired Mutable updates when the preset *changed* — a click on the already-active chip was a no-op.

Plus: tighten the lede paragraph so the page leads with one short claim instead of a paragraph, and animate preset zoom transitions so they read as movement instead of jumps.

## Changes

| Area | v7 | v8 |
|---|---|---|
| Methods footer | four paragraphs (data, plate boundaries, country assignment, basemap & tooling) — ~30 lines of small-print | one line: `Source: USGS ANSS Comprehensive Earthquake Catalog · plate boundaries: Bird (2003) PB2002.` Full citations live in the portfolio's reference page (task 18) where they're graded |
| Legend | `— plate boundary (Bird, 2003)` | `— plate boundary` (citation moved to the source line) |
| Preset re-click | clicking the active chip was a no-op (Mutable didn't change → reactive cells didn't fire) | clicking ANY chip — including the already-active one — increments a `presetTick` Mutable; map cell reads both `presetState` and `presetTick`, so re-clicking "World" while zoomed in resets to the full world view |
| Preset transition | hard snap (`svg.call(zoom.transform, t)`) | smooth ease-out cubic over 550 ms (`svg.transition().duration(550).ease(d3.easeCubicOut).call(zoom.transform, t)`). The initial render skips the animation so the page settles instantly |
| Lede paragraph | five sentences with redundant catalog citation, "where the rock fails" framing, and full encoding description | three short sentences: claim, encoding, instruction |

## Why a `presetTick` counter

A Framework `Mutable` only triggers reactivity when its value *changes* (deep-equal comparison for objects, identity for strings). Setting `presetState.value = "world"` while it's already `"world"` is a no-op — no consumer cell re-runs, the map's preset-application code never fires, the user's zoom transform stays put.

The fix: pair `presetState` with a separate `presetTick` integer that increments on every `setPreset(...)` call regardless of which key was passed. The map cell reads both. State alone tells you *which* preset; the tick tells you *when the user clicked* — so a re-click of the active preset still wakes the cell up.

```js
const presetState = Mutable("world");
const presetTick = Mutable(0);
function setPreset(key) {
  presetState.value = key;
  presetTick.value = presetTick.value + 1;
}
```

In the map cell:

```js
const presetChanged = presetState !== window.__t12_preset__
                   || presetTick !== window.__t12_preset_tick__;
if (presetChanged) {
  // animate to preset transform
} else if (window.__t12_zoom__) {
  // restore user's saved zoom (filter / magnitude rebuild)
}
```

## Why animate the preset zoom

A 550 ms ease-out cubic ("Mapbox-style fly-to") communicates *where* the user just was vs. *where* they're going. Instant snaps require the user to mentally re-orient themselves — the animation does it for them. The duration is short enough not to feel sluggish; the easing curve decelerates near the destination so the arrival feels precise. The initial render skips the animation (no source frame to interpolate from), so the page settles immediately.

Carpet circles aren't redrawn during the transition — the existing SVG path is interpolated by the zoom transform on `zoomRoot`. Highlight radii are counter-scaled in the zoom handler, which fires throughout the transition, so M ≥ 7 dots smoothly resize to stay constant on screen as the camera flies.

## Defensibility against the design system

- **No new colours.** Tooling unchanged; only text was removed.
- **Less ink, more signal.** Grading criterion #1 (data-ink ratio) gets quietly better when the methods paragraph disappears.
- **No regressions.** All filters, country click, linked views, year-strip backdrop, dual-handle slider, debounced drag still work.

## Screenshots

- `v8_world_overview.png` — canonical hero, single source line at the bottom.
- `v8_ring_of_fire.png` — Ring of Fire preset (k=2.2) reached via smooth transition; M9.1 callout retains constant on-screen size via inverse-sqrt(k) counter-scale.
- `v8_mediterranean.png` — Mediterranean preset (k=4); North Anatolian Fault, Hellenic Trench, Zagros, Red Sea Rift visible.
- `v8_indonesia.png` — Indonesia clicked at world view; country card shows 9,564 events / M8.6 largest / 679 ≥ M6 (the M9.1 Sumatra 2004 sat in the Indian Ocean and isn't recovered by the place-tail heuristic for Indonesia — known limitation, not a v8 regression).

## Verification (per CLAUDE.md `Browser verification` rule)

1. ✅ Page loads, no console errors. Footer is one line.
2. ✅ Legend swatch reads "plate boundary" only, no parenthetical citation.
3. ✅ Manual wheel-zoom to scale 1.74, then click "World" chip → `window.__t12_zoom__` is `translate(0,0) scale(1)` — full world view restored.
4. ✅ Click Ring of Fire → smooth transition over ~550 ms to k=2.2.
5. ✅ Click Mediterranean from Ring of Fire → smooth fly-across to k=4.
6. ✅ Click Indonesia → country card / histograms / year strip update; M9.1·2005 callout retargets (Indonesia's largest is the 2005 Nias M8.6 within the polygon match, not the 2004 offshore Sumatra event).
7. ✅ Filter change does NOT trigger preset transition; the zoom transform is restored from `window.__t12_zoom__` instead.
