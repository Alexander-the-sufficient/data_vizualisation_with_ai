# Task 12 — v1 → v2

## Why

The v1 deploy used a 2-stop neutral hexbin ramp (`lightQuartz → alloy`). The Pacific Ring of Fire — the entire story of the chart — rendered as a slightly-darker-gray arc against a cream basemap. The histograms and year strip were all warm-gray as well. The page read as an undifferentiated wash of beige.

## Changes

| Element | v1 | v2 |
|---|---|---|
| Hexbin ramp | `lightQuartz → alloy` (2-stop neutral) | `quartz → copper → heritageRedDark` (3-stop sequential, sand → bronze → crimson) |
| Country stroke | `white` 0.4 px | `mediumQuartz` 0.4 px (warm separator) |
| Histogram fill | `darkStone` (gray) | `copper` (bronze) |
| Year-strip overlay | `darkStone` (gray) on `quartz` backdrop | `copper` (bronze) on `quartz` backdrop |
| Editorial callout | none | red ring + `M{x.x} · {year}` label on the highest-magnitude event in the current filter window |

## Defensibility against the design-system rules

- **Heritage Red ≤ ~10 % of ink**: Only the very densest hexes (Tonga, Japan, Indonesia trenches) hit `heritageRedDark` on the sqrt ramp. Plus the single editorial ring + label. Combined red ink is well under 10 %.
- **Single editorial callout**: The "M9.1 · 2004" / "M9.1 · 2011" ring is exactly the "single callout marking *the moment*" the design system reserves Heritage Red for.
- **No double encoding**: count is encoded by hex color only; size is fixed.
- **Colorblind**: the ramp is single-hue-warmth (sand → bronze → crimson) — passes deuteranopia simulation by construction (no red-green pairing); the lightness gradient is monotonic so it survives a grayscale test.
- **Story clarity**: the Ring of Fire now reads instantly as a continuous warm arc; the 2004 Sumatra / 2011 Tōhoku M9.1 callout names *the moment*.

## Screenshots

- `before_v1.png` — v1 baseline (washed-out gray)
- `after_v2_world.png` — v2, default 1980–2025 world view (Sumatra 2004 callout)
- `after_v2_with_detail_panel.png` — v2 with a hex clicked (Chagos Archipelago)
- `after_v2_tohoku_window.png` — v2 narrowed to 2011–2015 (Tōhoku 2011 callout, year-strip context)
