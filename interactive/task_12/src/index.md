---
title: "Where the Earth's plates grind"
toc: false
---

# Where the Earth's plates grind

45 years of M≥5 earthquakes from the USGS ANSS catalog, 1980–2025. Drag the year and magnitude controls, switch the projection focus, click a hex on the map for the top events in that region. *Magnitude histogram, passive year strip, detail panel and reset button arrive in step 4 of the v1 build.*

```js
// Cell 2 — load the earthquake catalog (typed: true coerces lat/lon/depth/mag
// to numbers and time to a Date).
const quakes = await FileAttachment("./data/quakes.csv").csv({typed: true});
```

```js
// Cell 3 — TopoJSON basemap, decoded via topojson-client per PLAN.md
// verification step 4.
import * as topojsonClient from "npm:topojson-client";
const world = await FileAttachment("./data/world-110m.json").json();
const countriesFeature = topojsonClient.feature(world, world.objects.countries);
```

```js
// Cell 4 — design-system tokens (JS port of design_system.R). No inline hex
// elsewhere on the page; every fill / stroke / brush colour resolves here.
const pg = {
  alloy:        "#5C5B59",
  lightQuartz:  "#ECEAE4",
  quartz:       "#D6D0C2",
  darkStone:    "#7E8182",
  heritageRed:  "#D92B2B",
  copper:       "#896C4C"
};
```

## Controls

```js
// Cell 5 — year range. Observable Inputs has no two-handle range, so we
// compose two single-handle ranges via Inputs.form. The combined value is
// {start: <year>, end: <year>}. Two-way binding to the time-strip brush
// (cell 13, step 4) writes back to yearRangeInput.value.
const yearRangeInput = Inputs.form({
  start: Inputs.range([1980, 2025], {step: 1, value: 1980, label: "Start year"}),
  end:   Inputs.range([1980, 2025], {step: 1, value: 2025, label: "End year"})
});
const yearRange = Generators.input(yearRangeInput);
display(yearRangeInput);
```

```js
// Cell 6 — magnitude threshold. Slider goes from M5.0 (the catalog floor)
// to M7.5 (where event counts collapse to single digits / year). The slider
// only pushes the threshold up; nothing below 5.0 exists in the catalog.
const magThresholdInput = Inputs.range([5.0, 7.5], {step: 0.1, value: 5.0, label: "Minimum magnitude"});
const magThreshold = Generators.input(magThresholdInput);
display(magThresholdInput);
```

```js
// Cell 7 — region focus. Drives the projection rotation in cell 10. v1 ships
// three options; Mediterranean–Himalaya, Andean, East African Rift come in v2.
const regionFocusInput = Inputs.select(
  ["World", "Pacific Ring of Fire", "Mid-Atlantic Ridge"],
  {value: "World", label: "Region"}
);
const regionFocus = Generators.input(regionFocusInput);
display(regionFocusInput);
```

## State derivations

```js
// Cell 8 — mutable selectedHex (renamed from mapBrush per option E pivot).
// Plot 0.6.17 has no brush primitives, so the design switched to
// click-to-select-hex: the click listener in cell 11 reads plot.value
// (the closest event to the cursor, surfaced by Plot.pointer), buckets it
// into a 5° lat/lon grid cell, and writes that cell's events here.
//
// Framework rule: cells that *consume* a Mutable read only the current
// value, not the Mutable object — they cannot write `.value`. The setter
// pattern is what lets cell 11 push updates here.
const selectedHex = Mutable(null);
function setSelectedHex(v) { selectedHex.value = v; }
```

```js
// Cell 9 — derive `filtered` from yearRange + magThreshold. Region focus
// only rotates the projection (cell 10) — it doesn't filter the data, so
// the user can see what's outside the focus too.
//
// `eventsByCell` precomputes a lat/lon-grid lookup keyed by 5° cells —
// used by the click handler in cell 11 to resolve "what events are in the
// same hex as the focused event". 5° approximates the visual hex density
// at world view (`binWidth: 12px`) without depending on Plot's internal
// projection. This is an approximation: the visual hexes are drawn in
// screen space after projection, so a click near a region boundary may
// bucket into a cell that overlaps the visual hex by ~80–90% rather than
// exactly. Acceptable for v1.
const filtered = quakes.filter(q => {
  const yr = q.time.getFullYear();
  return yr >= yearRange.start && yr <= yearRange.end && q.mag >= magThreshold;
});

const BIN_DEG = 5;
const cellKey = q =>
  `${Math.floor(q.latitude / BIN_DEG)},${Math.floor(q.longitude / BIN_DEG)}`;
const eventsByCell = d3.group(filtered, cellKey);
```

```js
// Cell 10 — projection config. Pacific Ring rotates the Atlantic out of
// view so the Pacific arc renders as a single continuous shape across the
// antimeridian. Mid-Atlantic Ridge centres on the Atlantic basin.
const projection = (() => {
  switch (regionFocus) {
    case "Pacific Ring of Fire": return {type: "equal-earth", rotate: [-150, 0]};
    case "Mid-Atlantic Ridge":   return {type: "equal-earth", rotate: [ 30, 0]};
    default:                     return {type: "equal-earth", rotate: [  0, 0]};
  }
})();
```

## Map

```js
// Cell 11 — mapView (option E: Plot.pointer + click → setSelectedHex).
//
// Plot.hexbin is a *transform*, not a mark — it groups data into hex
// cells, computes a per-cell reducer (count), and hands the binned
// positions/counts to an outer Plot.dot which renders the hexes.
// Sequential lightQuartz → alloy ramp on a sqrt scale (heavy-tailed
// counts; linear would render the long tail invisible).
//
// The interaction layer is a second, invisible Plot.dot wrapped in
// Plot.pointer: it tracks the closest event to the cursor (using px/py
// channels for lat/lon target positions) and surfaces that event as
// plot.value. The click listener reads plot.value and buckets the focused
// event's lat/lon into the 5° grid (cell 9) to look up the events in the
// same region. Plot 0.6.17 has no brush primitives, so this is the
// option-E replacement for the original brush-based selection.
const plot = Plot.plot({
  width: 1100,
  height: 540,
  projection,
  marks: [
    Plot.geo(countriesFeature, {fill: pg.lightQuartz, stroke: "white", strokeWidth: 0.4}),
    Plot.dot(
      filtered,
      Plot.hexbin(
        {fill: "count"},
        {x: "longitude", y: "latitude", binWidth: 12, r: 8, stroke: "none"}
      )
    ),
    // Invisible pointer-tracking layer over individual events.
    Plot.dot(
      filtered,
      Plot.pointer({px: "longitude", py: "latitude", r: 0, opacity: 0})
    )
  ],
  color: {
    type: "sqrt",
    range: [pg.lightQuartz, pg.alloy],
    legend: true,
    label: "Events per hex"
  }
});
plot.addEventListener("click", () => {
  const focused = plot.value;
  if (!focused) { setSelectedHex(null); return; }
  const key = `${Math.floor(focused.latitude / 5)},${Math.floor(focused.longitude / 5)}`;
  setSelectedHex(eventsByCell.get(key) ?? []);
});
display(plot);
```

```js
// Smoke-test debug strip. Confirms the reactive chain wires through and
// surfaces the brush state. Removed in step 5 polish.
display(html`<details style="font-size:0.85rem;color:#7E8182">
  <summary>Debug</summary>
  <ul>
    <li><code>quakes.length</code>: ${quakes.length.toLocaleString()}</li>
    <li><code>filtered.length</code>: ${filtered.length.toLocaleString()}</li>
    <li><code>eventsByCell.size</code>: ${eventsByCell.size.toLocaleString()} (5° lat/lon cells)</li>
    <li><code>selectedHex</code>: ${selectedHex == null ? "null (no hex clicked)" : `${selectedHex.length} events in selected cell`}</li>
    <li><code>regionFocus</code>: ${regionFocus} → rotate ${JSON.stringify(projection.rotate)}</li>
    <li><code>yearRange</code>: ${yearRange.start}–${yearRange.end} · <code>magThreshold</code>: ${magThreshold.toFixed(1)}</li>
  </ul>
</details>`);
```

---

*Cells 12–15 (magnitude histogram, brushable year-strip with two-way binding, detail panel with USGS event links, reset button) — incoming in step 4.*
