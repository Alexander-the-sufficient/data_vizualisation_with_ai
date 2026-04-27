---
title: "Where the Earth's plates grind"
toc: false
---

# Where the Earth's plates grind

45 years of M≥5 earthquakes from the USGS ANSS catalog, 1980–2025. Drag the year and magnitude controls, switch the projection focus, and click a hex on the map to inspect the largest events in that region.

```js
// Cell 2 — load the earthquake catalog. {typed: true} coerces lat/lon/
// depth/mag to numbers and time to a Date.
const quakes = await FileAttachment("./data/quakes.csv").csv({typed: true});
```

```js
// Cell 3 — TopoJSON basemap, decoded via topojson-client.
import * as topojsonClient from "npm:topojson-client";
const world = await FileAttachment("./data/world-110m.json").json();
const countriesFeature = topojsonClient.feature(world, world.objects.countries);
```

```js
// Cell 4 — design-system tokens (JS port of design_system.R).
// No inline hex anywhere else; every fill / stroke / link colour
// resolves through this object.
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
// Cell 5 — year range. Observable Inputs has no two-handle range, so
// two single-handle ranges are composed via Inputs.form. Combined value
// is {start: <year>, end: <year>}.
const yearRangeInput = Inputs.form({
  start: Inputs.range([1980, 2025], {step: 1, value: 1980, label: "Start year"}),
  end:   Inputs.range([1980, 2025], {step: 1, value: 2025, label: "End year"})
});
const yearRange = Generators.input(yearRangeInput);
display(yearRangeInput);
```

```js
// Cell 6 — magnitude threshold. Slider goes from M5.0 (the catalog
// floor) to M7.5 (where event counts collapse to single digits / year).
const magThresholdInput = Inputs.range([5.0, 7.5], {step: 0.1, value: 5.0, label: "Minimum magnitude"});
const magThreshold = Generators.input(magThresholdInput);
display(magThresholdInput);
```

```js
// Cell 7 — region focus. Drives the projection rotation in cell 10. v1
// ships three options; Mediterranean–Himalaya, Andean, East African
// Rift come in v2.
const regionFocusInput = Inputs.select(
  ["World", "Pacific Ring of Fire", "Mid-Atlantic Ridge"],
  {value: "World", label: "Region"}
);
const regionFocus = Generators.input(regionFocusInput);
display(regionFocusInput);
```

```js
// Cell 15 — reset button. Restores all four pieces of state to defaults
// and clears the selected hex. Each input is updated by writing its
// .value and dispatching an "input" event so Generators.input picks up
// the change. The Inputs.form for yearRange takes a {start, end} value.
display(Inputs.button("Reset all filters", {reduce: () => {
  yearRangeInput.value = {start: 1980, end: 2025};
  yearRangeInput.dispatchEvent(new Event("input", {bubbles: true}));
  magThresholdInput.value = 5.0;
  magThresholdInput.dispatchEvent(new Event("input", {bubbles: true}));
  regionFocusInput.value = "World";
  regionFocusInput.dispatchEvent(new Event("input", {bubbles: true}));
  setSelectedHex(null);
}}));
```

```js
// Cell 8 — mutable selectedHex. Set by the click listener on the map
// (cell 11). Plot 0.6.17 has no brush primitives, so the design uses
// click-to-select-hex: the listener reads plot.value (closest event to
// cursor, surfaced by Plot.pointer), buckets it into a 5° lat/lon grid
// cell, and writes that cell's events here.
//
// Framework rule: cells that *consume* a Mutable see only the current
// value, not the Mutable object — they cannot write `.value`. The
// setter pattern bridges the gap.
const selectedHex = Mutable(null);
function setSelectedHex(v) { selectedHex.value = v; }
```

```js
// Cell 9 — derive `filtered` from yearRange + magThreshold. Region
// focus only rotates the projection (cell 10); it doesn't filter the
// data. `eventsByCell` precomputes a 5° lat/lon-grid lookup used by
// the click handler in cell 11 to resolve "what events are in the same
// region as the focused event". 5° approximates the visual hex density
// at world view (binWidth: 12px) without depending on Plot's internal
// projection — an approximation, but cheap and reliable.
const filtered = quakes.filter(q => {
  const yr = q.time.getFullYear();
  return yr >= yearRange.start && yr <= yearRange.end && q.mag >= magThreshold;
});

const filteredByMagOnly = quakes.filter(q => q.mag >= magThreshold);

const BIN_DEG = 5;
const cellKey = q =>
  `${Math.floor(q.latitude / BIN_DEG)},${Math.floor(q.longitude / BIN_DEG)}`;
const eventsByCell = d3.group(filtered, cellKey);
```

```js
// Cell 10 — projection config. Pacific Ring rotates the Atlantic out of
// view so the Pacific arc renders as a continuous shape across the
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
// Cell 11 — mapView. Plot.hexbin is a *transform* (not a mark) — it
// groups data into hex cells, computes a per-cell count reducer, and
// hands the binned positions to an outer Plot.dot which renders them.
// Sequential lightQuartz → alloy ramp on a sqrt scale (heavy-tailed
// counts; linear would render the long tail invisible).
//
// The interaction layer is a second, invisible Plot.dot wrapped in
// Plot.pointer (px/py channels for lat/lon target positions) — it
// surfaces the closest event to the cursor as plot.value. The click
// listener buckets that event's lat/lon into the 5° grid and writes
// the cell's events to selectedHex via setSelectedHex.
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

## Selected hex — top events

```js
// Cell 14 — detailPanel. Reads selectedHex (the array of events in the
// 5° lat/lon cell of the most recently clicked hex). Top 5 by magnitude
// descending; each row links to the canonical USGS event page.
display(html`<div style="margin: 1em 0">
  ${selectedHex == null
    ? html`<p style="color:${pg.darkStone};font-style:italic">
        Click a hex on the map to inspect the largest events in that region.
      </p>`
    : selectedHex.length === 0
      ? html`<p style="color:${pg.darkStone};font-style:italic">
          No events in that cell at the current filter settings.
        </p>`
      : html`<table style="border-collapse:collapse;font-size:0.95rem;width:100%;max-width:980px">
          <thead>
            <tr style="border-bottom:1.5px solid ${pg.alloy};text-align:left;color:${pg.alloy}">
              <th style="padding:6px 12px 6px 0;font-weight:600">Place</th>
              <th style="padding:6px 12px;font-weight:600">Magnitude</th>
              <th style="padding:6px 12px;font-weight:600">Depth</th>
              <th style="padding:6px 12px;font-weight:600">Date</th>
              <th style="padding:6px 0 6px 12px;font-weight:600">USGS</th>
            </tr>
          </thead>
          <tbody>
            ${selectedHex
              .slice()
              .sort((a, b) => b.mag - a.mag)
              .slice(0, 5)
              .map(q => html`<tr style="border-bottom:1px solid ${pg.lightQuartz}">
                <td style="padding:8px 12px 8px 0">${q.place}</td>
                <td style="padding:8px 12px;font-variant-numeric:tabular-nums">M ${q.mag.toFixed(1)} <span style="color:${pg.darkStone};font-size:0.85em">(${q.magType})</span></td>
                <td style="padding:8px 12px;font-variant-numeric:tabular-nums">${q.depth} km</td>
                <td style="padding:8px 12px;font-variant-numeric:tabular-nums">${q.time.toISOString().slice(0,10)}</td>
                <td style="padding:8px 0 8px 12px"><a href="https://earthquake.usgs.gov/earthquakes/eventpage/${q.id}" target="_blank" rel="noopener" style="color:${pg.heritageRed}">event ↗</a></td>
              </tr>`)}
          </tbody>
        </table>`}
</div>`);
```

## Magnitude distribution

```js
// Cell 12 — magHistogram. Plot.binX with interval 0.1 buckets the
// filtered events by magnitude; Plot.rectY renders the count per bucket.
// Single solid pg.darkStone fill (no gradient — this is a count
// distribution, not a magnitude-encoded view). Re-renders on every
// filter change.
display(Plot.plot({
  height: 180,
  marginLeft: 50,
  x: {label: "Magnitude →", labelAnchor: "right"},
  y: {label: "↑ events", grid: true},
  marks: [
    Plot.rectY(filtered, Plot.binX(
      {y: "count"},
      {x: "mag", interval: 0.1, fill: pg.darkStone}
    )),
    Plot.ruleY([0], {stroke: pg.alloy})
  ]
}));
```

## Events per year

```js
// Cell 13 — passive year strip with grayed-context backdrop. The pale
// (pg.quartz) bars show the full 1980–2025 distribution at the current
// magnitude threshold; the dark (pg.darkStone) bars overlay the
// currently-selected year window. When yearRange covers all 45 years
// the two layers coincide (only dark visible). When the slider is
// narrowed, the backdrop gives the user instant context — "is my slice
// the busy half or the quiet half of the catalog?".
display(Plot.plot({
  height: 110,
  marginLeft: 50,
  x: {label: null, tickFormat: "d"},
  y: {label: "↑ events / year", grid: true},
  marks: [
    Plot.rectY(filteredByMagOnly, Plot.binX(
      {y: "count"},
      {x: d => d.time.getFullYear(), interval: 1, fill: pg.quartz}
    )),
    Plot.rectY(filtered, Plot.binX(
      {y: "count"},
      {x: d => d.time.getFullYear(), interval: 1, fill: pg.darkStone}
    )),
    Plot.ruleY([0], {stroke: pg.alloy})
  ]
}));
```

---

```js
// Cell 16 — methods + sources footer.
display(html`<div style="margin: 2em 0 1em; font-size: 0.85rem; color: ${pg.darkStone}; line-height: 1.5">
  <p><strong style="color:${pg.alloy}">Data.</strong>
    USGS Earthquake Hazards Program, Advanced National Seismic System (ANSS) Comprehensive Earthquake Catalog (ComCat).
    Queried via the FDSN event web service:
    <a href="https://earthquake.usgs.gov/fdsnws/event/1/" target="_blank" rel="noopener" style="color:${pg.heritageRed}">earthquake.usgs.gov/fdsnws/event/1/</a>.
    All events with magnitude ≥ 5.0 between 1980-01-01 and 2025-12-31 (~75,000 events).
    USGS preferred magnitudes are heterogeneous across the catalog (Mw, mb, ML, Ms);
    for visualization purposes the catalog is treated as a single magnitude axis.
    Pre-1980 catalog completeness in remote ocean basins is materially lower than post-1990
    due to broadband seismograph network expansion — starting at 1980 avoids that caveat
    without losing analytical content.
    A small fraction (~2%) of place names from the upstream feed contain a literal "?" where a
    non-ASCII character was lost during USGS ingestion (e.g. "?funato" for "Ōfunato"); these are
    preserved unchanged here.</p>
  <p><strong style="color:${pg.alloy}">Basemap.</strong>
    Natural Earth countries, 110m resolution, decoded from <a href="https://github.com/topojson/world-atlas" target="_blank" rel="noopener" style="color:${pg.heritageRed}">world-atlas</a> TopoJSON via topojson-client. Equal-Earth projection.</p>
  <p><strong style="color:${pg.alloy}">Tooling.</strong>
    Built with <a href="https://observablehq.com/framework" target="_blank" rel="noopener" style="color:${pg.heritageRed}">Observable Framework</a>,
    <a href="https://observablehq.com/plot/" target="_blank" rel="noopener" style="color:${pg.heritageRed}">Observable Plot</a>,
    and <a href="https://d3js.org/" target="_blank" rel="noopener" style="color:${pg.heritageRed}">D3</a>.
    Cell scaffold and iteration assistance from
    <a href="https://www.anthropic.com/claude-code" target="_blank" rel="noopener" style="color:${pg.heritageRed}">Claude Code</a>
    (Opus 4.7, with the Playwright and Context7 MCP servers).
    Deployed to GitHub Pages via Actions.</p>
</div>`);
```
