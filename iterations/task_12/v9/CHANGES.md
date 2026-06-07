# Task 12 — v8 → v9

## Why

v8 added a 550 ms ease-out-cubic transition on preset zoom changes, but the transition appeared to "reset to world view, then zoom to the preset" instead of flying directly from the user's current view.

## Diagnosis

The map cell (cell 11) reads `presetState` and `presetTick`. When the user clicks a preset chip, both increment, the cell re-runs, and a fresh SVG is built — at the default zoom-identity transform. The transition is then started on the fresh SVG. Because the SVG was created at identity, the transition's interpolator captured identity as the source, and the user saw a fly-from-identity instead of a fly-from-where-they-were.

## Fix

Before starting the transition, sync the new SVG to the user's last saved zoom transform (`window.__t12_zoom__`). This bumps the SVG's internal `__zoom` state up to the user's previous view *before* the transition's first frame samples it. The transition then interpolates from the saved transform to the preset target — i.e. flies from where the user actually was, not from identity.

```js
if (lastTick === undefined) {
  // First render of the session — apply preset instantly.
  svg.call(zoom.transform, t);
} else {
  if (window.__t12_zoom__) {
    svg.call(zoom.transform, window.__t12_zoom__);  // ← sync to user's view
  }
  svg.transition().duration(550).ease(d3.easeCubicOut).call(zoom.transform, t);
}
```

The `svg.call(zoom.transform, ...)` call is synchronous: it sets `svg.__zoom` and writes the `transform` attribute on `zoomRoot`. By the time `display(mapSvg)` (in cell 17) attaches the SVG to the DOM, the transform attribute is already at the saved value — the user never sees identity.

## Verification

Verified in Chromium via Playwright by zooming the SVG to scale 1.74 over Indonesia, then clicking the Andes chip, then sampling the `zoom-root`'s `transform` attribute at frames 0 / 100 / 300 / 600 ms:

| Time | Transform |
|---|---|
| Before click | `translate(-716, -235) scale(1.741)` |
| Immediately after click | `translate(-716, -235) scale(1.741)` ← **same as before, no flash** |
| +100 ms | `translate(-521, -268) scale(1.726)` |
| +300 ms | `translate(-589, -788) scale(2.889)` |
| +600 ms (done) | `translate(-762, -1033) scale(3.500)` ← Andes preset target |

The transition smoothly interpolates from Indonesia to Andes; the user never sees a reset to world view.

## Edge cases handled

- **First render of the session** (`lastTick === undefined`): the preset is applied instantly via `svg.call(zoom.transform, t)`, no transition. The page settles in one frame.
- **Filter or magnitude change (preset unchanged)**: cell 11 rebuilds, `presetChanged` is false, so the saved `window.__t12_zoom__` is restored without animation. Same as previous versions.
- **Re-clicking the active preset while panned away**: tick increments → `presetChanged` is true → the new SVG syncs to saved zoom → transition flies back to preset. v8's "click World to reset zoom" behavior is preserved.

## Screenshots

- `v9_andes_after_transition.png` — Andes preset reached via fly-to from a prior Indonesia-area view; major M ≥ 7 events along the Andean subduction zone in heritage red, plate boundary in onyx.
