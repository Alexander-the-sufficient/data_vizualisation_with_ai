# Task 12 — v4 → v5

## Why

v4 had the right architecture (split-cell map, plate-boundary overlay, linked views) but the surface still felt like a research notebook: stock Observable Inputs widgets with native browser sliders and visible numeric input boxes; a 280-px sidebar that compressed the map; flat blocks butted against each other with no visual hierarchy; default Plot styling on the histograms. Asked for an aesthetic + UX pass.

## Changes

| Area | v4 | v5 |
|---|---|---|
| Layout | 280-px sidebar + map column | Single horizontal toolbar above a full-width map; map gets the entire content width |
| Sliders | Stock browser `<input type=range>` with the framework's number-box readouts | Custom-styled tracks (`light-quartz` 4 px) and thumbs (`alloy` 14 px circle, white border, 1 px shadow); hover → `copper`; active → `heritage-red-dark`; framework's number boxes hidden via CSS |
| Year window | Two stacked sliders | Two side-by-side sliders sharing a row, with a single "1980 – 2025" tabular-figures readout below |
| Buttons | Default browser style (`Inputs.button`) | Pill-shaped chips for presets (rounded 999 px, 1 px medium-quartz border, alloy fill when active); ghost `Reset all` button that's disabled when state already equals defaults |
| Surfaces | Map sat directly on the page background | Every block (toolbar, map, country card, each chart panel) sits on a white card with `0 1px 3px / 0 8px 24px` shadow stack; page background warmed to `#F1EEE7` so the cards lift |
| Country detail card | Single block with table + inset | White card; header with country name + sub + ✕-clear control; three stat tiles with 3-px copper / heritage-red-dark left-border accents; inset map; cleaned-up event table with uppercase column heads |
| Empty state | Dashed-border placeholder | Centered italic prose with a faint crosshair glyph; light hairline border instead of dashed |
| Linked-views row | Plain `<h3>` titles | Each chart in its own white card; bold title + meta line ("`Indonesia` · M ≥ 5.0, 2010–2025") with the country name in heritage red |
| Plot styling | Default theme | Custom `style: {color: alloy, fontFamily: inherit, fontSize: 11px}`; tick marks removed (`tickSize: 0`); rule colour and weight pulled to `alloy` 0.6 px; uniform 8 px top/right margins |
| Section headers | `## Inspect a country` (default h2) | Restyled as small uppercase eyebrow labels (0.08 em letter-spacing) with a hairline rule below — feel like dashboard sections, not document headings |
| Country highlight | None on hover | Country path stroke transitions to alloy / 0.9 px on hover; selected-country fill fades in over 250 ms |
| Reset affordance | Always active | Disabled and dimmed when current state equals defaults; visually clear that nothing is dirty |

## Why a top toolbar instead of a sidebar

The sidebar competed with the map for screen real estate. A 1240 px-wide map at world-view is the centerpiece — it deserves the whole content column. Moving the controls to a single 64-px-tall toolbar above the map gives the map a 540 px-tall canvas and reads as "the thing you do" + "the thing you look at" rather than "left margin of controls / right blob of map."

The toolbar also organizes the controls semantically: filter (year, magnitude), navigation (zoom presets), and reset. Each segment has an uppercase eyebrow label and a single readout — no redundant stock framework labels.

## CSS plumbing notes

Two non-obvious bits.

1. **Hashed Inputs class names.** Observable Inputs in this Framework version uses dynamic class hashes like `inputs-3a86ea` rather than the documented `observablehq-input`. v5's CSS targets by structure (`.t12-toolbar input[type="number"]`, `.t12-toolbar form > div`) instead of by class name, so it survives across Inputs versions.

2. **Inputs.form composes via a `<div>` of sibling `<form>`s.** The dual-handle year window uses `Inputs.form({start, end})`, which renders as `<div><form>start</form><form>end</form></div>`. The CSS flexes that inner `<div>` so the two ranges sit side-by-side, instead of the default vertical stack:

   ```css
   .t12-toolbar .dual-range > div { display: flex; flex-direction: row; gap: 0.8rem; }
   .t12-toolbar .dual-range > div > form { flex: 1; min-width: 0; }
   ```

3. **htl interpolation gotcha.** First v5 attempt used `<button class="t12-reset" ${isDefault ? "disabled" : ""}>` — htl raised "invalid binding" because attribute-name interpolation in tag bodies isn't supported. Fixed by setting `btn.disabled = isDefault` after construction.

## Defensibility against the design system

- **No new colours.** All UI surfaces use the existing PG palette tokens (`alloy`, `quartz`, `light-quartz`, `copper`, `heritage-red`, `heritage-red-dark`, plus a slightly warmed page bg `#F1EEE7` between `light-quartz` and white). The page is still legible in greyscale.
- **Heritage red still ≤ 10% of ink.** Used only in: the densest hexes; the M-callout ring; the selected-country fill (0.18 opacity); USGS link colour; the heritage-red-dark left border on the "Largest" stat tile and the country-scoped histograms; reset-button hover. None of these dominate visually.
- **No double encoding.** Magnitude → stat-tile value or circle radius (one channel). Count → hex colour or bar height (one channel).
- **No chartjunk added.** The shadow + radius + page bg are surface-level affordances; the data-bearing marks (hexes, plate lines, dots, bars) are unchanged. Tick marks were *removed* from the histograms; the value labels remain.
- **Story still asserts itself.** Title and subtitle unchanged from v4; the boundary overlay still does the work.

## Screenshots

- `v5_world_overview.png` — canonical hero. Toolbar at top, full-width map, plate boundaries traced by hex density, empty country-detail prompt, side-by-side histogram + year strip.
- `v5_japan.png` — Japan clicked. Country card filled in with stat tiles + inset + event list; histograms scoped to Japan in heritage red; year strip's 2011 spike clearly visible; M9.1 callout retargets to Tōhoku.
- `v5_indonesia_2010.png` — linked-views demo. Year window narrowed to 2010–2025, Indonesia clicked; year strip's pale-quartz backdrop carries the 2004 Sumatra spike alongside the dark 2010+ window — the sharpest demonstration of the linked-view design.
- `v5_mediterranean.png` — Mediterranean preset (k=4). Hex carpet faded out, individual event dots visible across the Hellenic Trench / North Anatolian Fault / Zagros; chip in active state.

## Verification (per CLAUDE.md `Browser verification` rule)

Verified live in Chromium via Playwright MCP against `npm run dev`:

1. ✅ Page loads, no console errors.
2. ✅ Toolbar renders with custom slider thumbs (alloy on white, `copper` on hover); year window shows two ranges side-by-side; framework number boxes hidden.
3. ✅ Reset-all button disabled at default state, enabled and clickable as soon as any control is dirty.
4. ✅ Click Japan → country card with `Japan` heading, ✕-clear control, three stat tiles (Events 5,697 / Largest M9.1 / M ≥ 6: 501); inset map of Japan with five red event circles; histograms switch to heritage-red-dark with `Japan` scope label; year strip 2011 spike visible.
5. ✅ Year start → 2010 + click Indonesia → year strip's pale-quartz backdrop carries the full 1980–2025 history (2004 spike on the left), dark red overlay covers only 2010–2025.
6. ✅ Mediterranean preset → smooth zoom to k=4; chip becomes active (alloy fill, white text); Indonesia card persists from previous selection (preset doesn't clear country).
7. ✅ Reset → all state cleared; reset button returns to disabled.
8. ✅ ✕-clear control on country card clears `selectedCountry` without resetting filters or zoom.
