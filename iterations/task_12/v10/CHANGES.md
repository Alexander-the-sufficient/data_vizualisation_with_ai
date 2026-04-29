# Task 12 — v9 → v10

## Why

Without pan bounds, dragging the map continuously translated the
content past the viewport edges into empty cream space — there was
nothing visually anchoring the user inside the map's content rectangle.

## Changes

Added `extent` and `translateExtent` to the `d3.zoom` controller, both
set to `[[0, 0], [width, height]]`. d3 now clamps user-driven pan/zoom
so the visible window always lies inside the world's `[0,0]–[1240,580]`
rectangle. At zoom 1, panning is a no-op (the world fills the
viewport); at deeper zoom levels, the camera "pushes back" against
the world edges.

Programmatic `zoom.transform(...)` calls (the preset transitions and
the saved-zoom restore on filter changes) bypass d3's interaction
clamp, so the preset transform code clamps manually with the same
math d3 uses internally:

```js
tx = Math.max(width  * (1 - ap.k), Math.min(0, tx));
ty = Math.max(height * (1 - ap.k), Math.min(0, ty));
```

Effect on each preset:
- **World** (k = 1): identity, no change.
- **Mediterranean** (k = 4, lon 40°): target `tx = -2343`, bounds `[-3720, 0]` → no clamp.
- **Andes** (k = 3.5, lon -70°): target `tx = -762`, bounds `[-3100, 0]` → no clamp.
- **Ring of Fire** (k = 2.2, lon 165°): target `tx = -1998`, bounds `[-1488, 0]` → **clamped to -1488**. The view now sits with the world's right edge flush against the viewport's right edge, showing the Asia-Pacific arm of the ring (Japan, Philippines, Indonesia, Australia/Vanuatu) without empty cream past the dateline. The Americas arm of the ring is reachable via the Andes preset.

## Verification

Verified in Chromium via Playwright:

| Action | Transform |
|---|---|
| Drag 500 px right at k=1 | `translate(0,0) scale(1)` (no-op) |
| Wheel-zoom in to k=2 | `translate(-620,-289) scale(2)` (within bounds) |
| Drag 5000 px past edge at k=2 | unchanged (clamped) |
| Click "Ring of Fire" | `k=2.20 tx=-1488 ty=-348` (clamped from -1998) |
| Click "Mediterranean" | `k=4.00 tx=-2343 ty=-267` (no clamp) |
| Click "Andes" | `k=3.50 tx=-762 ty=-1034` (no clamp) |
| Click "World" | `k=1.00 tx=0 ty=0` (identity) |

## Screenshot

`v10_ring_clamped.png` — Ring of Fire preset with bounds applied: Sumatra
trench / Java / Philippines / Indonesia / Australian arc visible, the
dateline edge of the world flush with the viewport's right edge, no
empty cream past it.
