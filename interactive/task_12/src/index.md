---
title: "Plate boundaries draw themselves"
toc: false
---

<style>
  /* ---------- Brand tokens (CSS custom properties so CSS rules can use them) ---------- */
  :root {
    --t12-alloy: #5C5B59;
    --t12-onyx: #1A1A1A;
    --t12-light-quartz: #ECEAE4;
    --t12-quartz: #D6D0C2;
    --t12-medium-quartz: #BAB3AB;
    --t12-dark-quartz: #ACA39A;
    --t12-dark-stone: #7E8182;
    --t12-copper: #896C4C;
    --t12-heritage-red: #D92B2B;
    --t12-heritage-red-dark: #830011;
    --t12-bg: #F1EEE7;
    --t12-card-shadow: 0 1px 3px rgba(28, 24, 18, 0.06), 0 8px 24px rgba(28, 24, 18, 0.08);
    --t12-radius: 8px;
  }

  /* ---------- Page background — a hint of cream so white cards lift ---------- */
  body { background: var(--t12-bg); }
  #observablehq-main { padding-bottom: 3rem; max-width: none; }
  #observablehq-main > h1, #observablehq-main > h2, #observablehq-main > .t12-lede { max-width: none; }
  #observablehq-main > h1:first-of-type { margin-top: 0.4em; }
  #observablehq-main h1 { font-size: 2.1rem; letter-spacing: -0.01em; color: var(--t12-onyx); margin-bottom: 0.15em; }
  #observablehq-main h2 { font-size: 1.05rem; font-weight: 600; color: var(--t12-alloy); text-transform: uppercase; letter-spacing: 0.08em; margin: 2.4em 0 0.9em; padding-bottom: 0.5em; border-bottom: 1px solid var(--t12-light-quartz); }
  #observablehq-main p { color: var(--t12-alloy); }

  /* ---------- Subtitle / lede ---------- */
  .t12-lede { font-size: 1.02rem; line-height: 1.55; color: var(--t12-alloy); max-width: 880px; margin: 0 0 1.4em; }
  .t12-lede strong { color: var(--t12-onyx); font-weight: 600; }
  .t12-eyebrow { font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.1em; color: var(--t12-dark-stone); font-weight: 600; margin: 0 0 0.55em; display: block; }

  /* ---------- Toolbar — top-bar layout for the controls ---------- */
  .t12-toolbar { display: grid; grid-template-columns: 1.4fr 1fr 1.6fr auto; gap: 1.6rem; padding: 1.05em 1.3em; background: #FFFFFF; border-radius: var(--t12-radius); box-shadow: var(--t12-card-shadow); margin: 0 0 1.2em; align-items: end; }
  .t12-toolbar-segment { display: flex; flex-direction: column; min-width: 0; }
  .t12-toolbar-segment.actions { align-items: flex-end; justify-content: flex-end; }
  .t12-value-readout { font-variant-numeric: tabular-nums; font-size: 0.95rem; color: var(--t12-onyx); font-weight: 500; margin-top: 0.2em; }
  .t12-value-readout .sep { color: var(--t12-dark-stone); margin: 0 0.25em; }

  /* ---------- Single-handle range slider (magnitude) ---------- */
  /* Only targets descendants of the magnitude segment, NOT the dual-range.
     Drops the hover transform that was making drag feel snappy. */
  .t12-mag input[type="range"] { -webkit-appearance: none; appearance: none; width: 100%; height: 24px; background: transparent; padding: 0; margin: 0; outline: none; cursor: pointer; }
  .t12-mag input[type="range"]::-webkit-slider-runnable-track { height: 4px; background: var(--t12-light-quartz); border-radius: 2px; border: none; }
  .t12-mag input[type="range"]::-moz-range-track { height: 4px; background: var(--t12-light-quartz); border-radius: 2px; border: none; }
  .t12-mag input[type="range"]::-webkit-slider-thumb { -webkit-appearance: none; appearance: none; height: 16px; width: 16px; border-radius: 50%; background: var(--t12-alloy); margin-top: -6px; border: 2px solid #FFFFFF; box-shadow: 0 1px 3px rgba(28, 24, 18, 0.3); }
  .t12-mag input[type="range"]::-moz-range-thumb { height: 16px; width: 16px; border-radius: 50%; background: var(--t12-alloy); border: 2px solid #FFFFFF; box-shadow: 0 1px 3px rgba(28, 24, 18, 0.3); }
  .t12-mag input[type="range"]:hover::-webkit-slider-thumb { background: var(--t12-copper); }
  .t12-mag input[type="range"]:hover::-moz-range-thumb { background: var(--t12-copper); }
  .t12-mag input[type="range"]:active::-webkit-slider-thumb { background: var(--t12-heritage-red-dark); }
  .t12-mag input[type="range"]:active::-moz-range-thumb { background: var(--t12-heritage-red-dark); }

  /* Hide Inputs.range / Inputs.form internal labels + number boxes. */
  .t12-toolbar input[type="number"],
  .t12-toolbar input[type="text"],
  .t12-toolbar output,
  .t12-toolbar form label { display: none !important; }
  .t12-toolbar form { padding: 0; margin: 0; }
  .t12-toolbar form > div { width: 100%; padding: 0; margin: 0; }
  .t12-toolbar input[type="range"] { width: 100%; }

  /* ---------- Dual-handle range slider for the year window ---------- */
  /* Two `<input type=range>` overlaid on a single track. Each input is
     `pointer-events: none`; only the thumbs are interactive. A fill div
     between the two thumbs visualizes the active window. */
  .t12-dual-range { position: relative; height: 24px; width: 100%; padding: 0; margin: 0; }
  .t12-dual-track {
    position: absolute; top: 10px; left: 0; right: 0;
    height: 4px; background: var(--t12-light-quartz); border-radius: 2px; pointer-events: none;
  }
  .t12-dual-fill {
    position: absolute; top: 10px;
    height: 4px; background: var(--t12-alloy); border-radius: 2px; pointer-events: none;
  }
  .t12-dual-input {
    position: absolute; top: 0; left: 0;
    width: 100%; height: 24px; margin: 0; padding: 0;
    -webkit-appearance: none; appearance: none;
    background: transparent; outline: none;
    pointer-events: none;
  }
  .t12-dual-input::-webkit-slider-runnable-track { height: 4px; background: transparent; border: none; }
  .t12-dual-input::-moz-range-track { height: 4px; background: transparent; border: none; }
  .t12-dual-input::-webkit-slider-thumb {
    -webkit-appearance: none; appearance: none;
    pointer-events: auto;
    height: 16px; width: 16px; border-radius: 50%;
    background: var(--t12-alloy); border: 2px solid #FFFFFF;
    box-shadow: 0 1px 3px rgba(28, 24, 18, 0.3);
    cursor: grab; margin-top: -6px;
    position: relative; z-index: 2;
  }
  .t12-dual-input::-moz-range-thumb {
    pointer-events: auto;
    height: 16px; width: 16px; border-radius: 50%;
    background: var(--t12-alloy); border: 2px solid #FFFFFF;
    box-shadow: 0 1px 3px rgba(28, 24, 18, 0.3);
    cursor: grab;
  }
  .t12-dual-input:active::-webkit-slider-thumb { background: var(--t12-heritage-red-dark); cursor: grabbing; }
  .t12-dual-input:active::-moz-range-thumb { background: var(--t12-heritage-red-dark); cursor: grabbing; }
  .t12-dual-input:hover::-webkit-slider-thumb { background: var(--t12-copper); }
  .t12-dual-input:hover::-moz-range-thumb { background: var(--t12-copper); }

  /* ---------- Preset chip buttons ---------- */
  .t12-chips { display: flex; flex-wrap: wrap; gap: 0.4rem; }
  .t12-chip { padding: 5px 12px; font-size: 0.82rem; font-family: inherit; background: #FFFFFF; color: var(--t12-alloy); border: 1px solid var(--t12-medium-quartz); border-radius: 999px; cursor: pointer; transition: all 0.15s; line-height: 1.3; }
  .t12-chip:hover { border-color: var(--t12-alloy); color: var(--t12-onyx); }
  .t12-chip.is-active { background: var(--t12-alloy); border-color: var(--t12-alloy); color: #FFFFFF; }

  /* ---------- Reset button ---------- */
  .t12-reset { font-family: inherit; font-size: 0.82rem; padding: 6px 12px; background: transparent; color: var(--t12-dark-stone); border: 1px solid var(--t12-light-quartz); border-radius: 4px; cursor: pointer; transition: all 0.15s; white-space: nowrap; }
  .t12-reset:hover { color: var(--t12-heritage-red-dark); border-color: var(--t12-heritage-red-dark); }
  .t12-reset[disabled] { opacity: 0.45; cursor: default; }
  .t12-reset[disabled]:hover { color: var(--t12-dark-stone); border-color: var(--t12-light-quartz); }

  /* ---------- Map frame ---------- */
  .t12-map-card { background: #FFFFFF; border-radius: var(--t12-radius); padding: 6px; box-shadow: var(--t12-card-shadow); }
  .t12-map-card svg { display: block; border-radius: calc(var(--t12-radius) - 2px); }
  .t12-legend-row { display: flex; flex-wrap: wrap; gap: 1.5rem; align-items: center; padding: 0.9em 0.4em 0; font-size: 0.82rem; color: var(--t12-dark-stone); }
  .t12-legend-group { display: flex; align-items: center; gap: 0.45rem; }
  .t12-legend-group strong { color: var(--t12-alloy); font-weight: 600; }
  .t12-legend-swatch { display: inline-block; width: 14px; height: 14px; border-radius: 2px; vertical-align: middle; }
  .t12-legend-line { display: inline-block; width: 22px; height: 0; border-top: 1.4px solid var(--t12-onyx); opacity: 0.85; }
  .t12-legend-dot { display: inline-block; width: 10px; height: 10px; border: 1.6px solid var(--t12-heritage-red); border-radius: 50%; }
  .t12-legend-carpet { display: inline-block; width: 4px; height: 4px; border-radius: 50%; background: var(--t12-alloy); opacity: 0.55; vertical-align: middle; }
  .t12-legend-major-sm { display: inline-block; width: 5px; height: 5px; border-radius: 50%; background: var(--t12-heritage-red-dark); border: 0.5px solid #FFFFFF; vertical-align: middle; opacity: 0.85; }
  .t12-legend-major-md { display: inline-block; width: 8px; height: 8px; border-radius: 50%; background: var(--t12-heritage-red-dark); border: 0.5px solid #FFFFFF; vertical-align: middle; opacity: 0.85; margin-left: 2px; }
  .t12-legend-major-lg { display: inline-block; width: 12px; height: 12px; border-radius: 50%; background: var(--t12-heritage-red-dark); border: 0.5px solid #FFFFFF; vertical-align: middle; opacity: 0.85; margin-left: 2px; }

  /* ---------- Country detail card ---------- */
  .t12-country-card { background: #FFFFFF; border-radius: var(--t12-radius); padding: 1.4rem 1.6rem; box-shadow: var(--t12-card-shadow); }
  .t12-country-card-header { display: flex; align-items: baseline; justify-content: space-between; gap: 1rem; margin-bottom: 1.1em; }
  .t12-country-name { font-size: 1.4rem; font-weight: 600; color: var(--t12-onyx); letter-spacing: -0.005em; }
  .t12-country-sub { font-size: 0.85rem; color: var(--t12-dark-stone); }
  .t12-clear-link { font-size: 0.78rem; color: var(--t12-dark-stone); background: none; border: none; cursor: pointer; padding: 4px 8px; border-radius: 3px; font-family: inherit; transition: all 0.15s; }
  .t12-clear-link:hover { color: var(--t12-heritage-red-dark); background: var(--t12-light-quartz); }

  .t12-stat-row { display: flex; gap: 0.7rem; margin-bottom: 1.2em; flex-wrap: wrap; }
  .t12-stat-tile { flex: 1; min-width: 140px; background: var(--t12-bg); border-left: 3px solid var(--t12-copper); padding: 0.65em 1em; border-radius: 0 4px 4px 0; }
  .t12-stat-tile.accent { border-left-color: var(--t12-heritage-red-dark); }
  .t12-stat-label { font-size: 0.66rem; color: var(--t12-dark-stone); text-transform: uppercase; letter-spacing: 0.08em; font-weight: 600; }
  .t12-stat-value { font-size: 1.45rem; font-weight: 600; color: var(--t12-onyx); font-variant-numeric: tabular-nums; line-height: 1.1; margin-top: 3px; }
  .t12-stat-sub { font-size: 0.72rem; color: var(--t12-dark-stone); margin-top: 2px; font-variant-numeric: tabular-nums; }

  .t12-detail-body { display: grid; grid-template-columns: 240px 1fr; gap: 1.4rem; align-items: start; }
  .t12-inset-cap { font-size: 0.7rem; color: var(--t12-dark-stone); margin-top: 0.35em; text-align: center; font-style: italic; }
  .t12-event-table { border-collapse: collapse; font-size: 0.88rem; width: 100%; }
  .t12-event-table th { font-weight: 600; color: var(--t12-alloy); text-align: left; border-bottom: 1.2px solid var(--t12-alloy); padding: 6px 12px 6px 0; font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.05em; }
  .t12-event-table td { padding: 8px 12px 8px 0; border-bottom: 1px solid var(--t12-light-quartz); color: var(--t12-alloy); }
  .t12-event-table td.num { font-variant-numeric: tabular-nums; }
  .t12-event-table tr:last-child td { border-bottom: none; }
  .t12-event-table a { color: var(--t12-heritage-red); text-decoration: none; font-size: 0.82rem; }
  .t12-event-table a:hover { text-decoration: underline; }

  /* ---------- Empty state ---------- */
  .t12-empty { background: transparent; padding: 2.6em 1.6em; border-radius: var(--t12-radius); border: 1px solid var(--t12-light-quartz); color: var(--t12-dark-stone); font-style: italic; font-size: 0.95rem; line-height: 1.55; max-width: 700px; margin: 0 auto; text-align: center; }
  .t12-empty .icon { display: block; font-style: normal; font-size: 1.6em; opacity: 0.55; margin-bottom: 0.3em; }

  /* ---------- Linked-views grid ---------- */
  .t12-panels { display: grid; grid-template-columns: 1fr 1fr; gap: 1.2rem; }
  .t12-panel-card { background: #FFFFFF; border-radius: var(--t12-radius); padding: 1.1rem 1.3rem 0.9rem; box-shadow: var(--t12-card-shadow); }
  .t12-panel-title { font-size: 0.95rem; font-weight: 600; color: var(--t12-onyx); margin: 0 0 0.05em; }
  .t12-panel-meta { font-size: 0.78rem; color: var(--t12-dark-stone); margin-bottom: 0.4em; }
  .t12-panel-meta .scope { color: var(--t12-heritage-red-dark); font-weight: 500; }

  /* ---------- Methods footer ---------- */
  .t12-methods { margin-top: 2.4em; padding-top: 1.4em; border-top: 1px solid var(--t12-light-quartz); font-size: 0.82rem; color: var(--t12-dark-stone); line-height: 1.55; }
  .t12-methods p { margin: 0 0 0.85em; max-width: 880px; color: var(--t12-dark-stone); }
  .t12-methods strong { color: var(--t12-alloy); font-weight: 600; }
  .t12-methods a { color: var(--t12-heritage-red); }

  /* Animate the country highlight + callout subtly */
  .zoom-root .selected-country-fill { transition: opacity 0.25s ease; }
  .zoom-root .callout text, .zoom-root .callout circle { transition: opacity 0.25s ease; }
  .zoom-root .country { transition: stroke 0.15s, stroke-width 0.15s; }
  .zoom-root .country:hover { stroke: var(--t12-alloy); stroke-width: 0.9; }

  @media (max-width: 1024px) {
    .t12-toolbar { grid-template-columns: 1fr 1fr; gap: 1.2rem 1.4rem; }
    .t12-toolbar-segment.actions { grid-column: 1 / -1; flex-direction: row; gap: 0.7rem; align-items: center; }
    .t12-panels { grid-template-columns: 1fr; }
    .t12-detail-body { grid-template-columns: 1fr; }
  }

  /* ---------- Print mode (used by Chrome's --print-to-pdf for the
     portfolio's vector embed) — strip the page down to just the map
     and its legend. The page size is shorter than A4 landscape so the
     resulting PDF has no empty space below the legend; the portfolio's
     LaTeX layout scales it to the available frame height. ---------- */
  @media print {
    @page { size: 297mm 170mm; margin: 8mm; }
    html, body, #observablehq-center, #observablehq-main {
      background: white !important;
      margin: 0 !important;
      padding: 0 !important;
      max-width: none !important;
    }
    #observablehq-header, #observablehq-footer, #observablehq-toc { display: none !important; }
    /* Hide every top-level block in #observablehq-main that does NOT
       contain the map card (toolbar, country detail, distribution,
       methods footer, title, lede). */
    #observablehq-main > *:not(:has(.t12-map-card)) { display: none !important; }
    /* Reset the map-card block's chrome for print. */
    .t12-map-card {
      box-shadow: none !important;
      background: transparent !important;
      padding: 0 !important;
      border-radius: 0 !important;
    }
    .t12-map-card svg {
      width: 100% !important;
      height: auto !important;
      max-width: none !important;
      display: block !important;
      cursor: default !important;
    }
    .t12-legend-row {
      padding: 8px 0 0 !important;
      gap: 1.2rem !important;
      font-size: 9pt !important;
    }
  }
</style>

# Plate boundaries draw themselves

<p class="t12-lede"><strong>75,000 M ≥ 5 earthquakes, 1980–2025</strong>, drawn one dot per event. Where dots stack, the carpet darkens; M ≥ 7 events appear in heritage red, sized by magnitude. Plate boundaries are overlaid in dark grey. Click a country to filter every panel.</p>

```js
// Cell 2 — load the earthquake catalog. {typed: true} coerces lat/lon/
// depth/mag to numbers and time to a Date.
const quakes = await FileAttachment("./data/quakes.csv").csv({typed: true});
```

```js
// Cell 3 — TopoJSON basemap + plate boundaries (Bird 2003 / PB2002).
import * as topojsonClient from "npm:topojson-client";
const world = await FileAttachment("./data/world-110m.json").json();
const countriesFeature = topojsonClient.feature(world, world.objects.countries);
const plateBoundaries = await FileAttachment("./data/plate_boundaries.json").json();
```

```js
// Cell 4 — design-system tokens (mirrors the CSS custom properties for
// JS-side consumers like d3 fills / Plot fills).
const pg = {
  alloy:           "#5C5B59",
  onyx:            "#1A1A1A",
  bg:              "#FAF8F4",
  lightQuartz:     "#ECEAE4",
  quartz:          "#D6D0C2",
  mediumQuartz:    "#BAB3AB",
  darkQuartz:      "#ACA39A",
  darkStone:       "#7E8182",
  heritageRed:     "#D92B2B",
  heritageRedDark: "#830011",
  copper:          "#896C4C"
};
```

```js
// Cell 5a — debounced wrapper around a slider element. The map cell is
// heavy (countries + hexes + plates + dot sample + zoom controller), so
// re-running it on every `input` event during a drag stutters the
// thumb. The wrapper exposes a proxy element with the source's value
// but only dispatches its own `input` events after `delay` ms idle (or
// immediately on `change` / programmatic flush). Generators.input
// listens on the proxy, so the heavy cell only re-renders on debounced
// flushes — sliders feel smooth.
function makeDebouncedProxy(source, delay = 120) {
  const proxy = document.createElement("div");
  Object.defineProperty(proxy, "value", {
    configurable: true,
    get: () => source.value,
    set: (v) => { source.value = v; }
  });
  let timer;
  const flush = () => {
    clearTimeout(timer);
    timer = null;
    proxy.dispatchEvent(new Event("input", {bubbles: false}));
  };
  source.addEventListener("input", () => {
    clearTimeout(timer);
    timer = setTimeout(flush, delay);
  });
  source.addEventListener("change", flush);
  // Reset / programmatic update can dispatch this custom event for an
  // immediate flush bypassing the debounce.
  source.addEventListener("t12:flush", flush);
  return proxy;
}
```

```js
// Cell 5b — dual-handle range slider for the year window. Two
// `<input type=range>` overlaid on a shared track; only the thumbs are
// interactive (`pointer-events: auto` on the thumb, `none` on the
// input itself, so each thumb can be grabbed without the other input
// stealing the event). A fill `<div>` between the two thumbs renders
// the active window. Returns an element whose `.value` is
// `{start, end}` and that dispatches `input` events on every change —
// matching what the rest of the page expects.
function makeDualRange(min, max, initialStart, initialEnd) {
  const wrap = html`<div class="t12-dual-range">
    <div class="t12-dual-track"></div>
    <div class="t12-dual-fill"></div>
    <input type="range" class="t12-dual-input t12-dual-input-min" min="${min}" max="${max}" value="${initialStart}" step="1">
    <input type="range" class="t12-dual-input t12-dual-input-max" min="${min}" max="${max}" value="${initialEnd}" step="1">
  </div>`;
  const lo = wrap.querySelector(".t12-dual-input-min");
  const hi = wrap.querySelector(".t12-dual-input-max");
  const fill = wrap.querySelector(".t12-dual-fill");

  const update = (changed) => {
    let a = +lo.value, b = +hi.value;
    // Soft clamp: a thumb pushed past the other parks against it
    // instead of crossing — the user can keep dragging the same thumb
    // and the other one is dragged along.
    if (a > b) {
      if (changed === "lo") { hi.value = a; b = a; }
      else                  { lo.value = b; a = b; }
    }
    const range = max - min;
    fill.style.left = ((Math.min(a, b) - min) / range * 100) + "%";
    fill.style.right = (100 - ((Math.max(a, b) - min) / range) * 100) + "%";
    wrap.value = {start: Math.min(a, b), end: Math.max(a, b)};
  };

  lo.addEventListener("input", () => { update("lo"); wrap.dispatchEvent(new Event("input", {bubbles: false})); });
  hi.addEventListener("input", () => { update("hi"); wrap.dispatchEvent(new Event("input", {bubbles: false})); });
  lo.addEventListener("change", () => wrap.dispatchEvent(new Event("change", {bubbles: false})));
  hi.addEventListener("change", () => wrap.dispatchEvent(new Event("change", {bubbles: false})));
  // Programmatic .value setter (used by the reset button).
  Object.defineProperty(wrap, "_setValue", {
    configurable: true,
    value: (v) => { lo.value = v.start; hi.value = v.end; update("lo"); }
  });
  update();
  return wrap;
}

const yearRangeInput = makeDualRange(1980, 2025, 1980, 2025);
const yearRangeProxy = makeDebouncedProxy(yearRangeInput, 120);
const yearRange = Generators.input(yearRangeProxy);
```

```js
// Cell 6 — magnitude threshold (single-handle Inputs.range, debounced
// the same way the year window is).
const magThresholdInput = Inputs.range([5.0, 7.5], {step: 0.1, value: 5.0, label: ""});
const magThresholdProxy = makeDebouncedProxy(magThresholdInput, 120);
const magThreshold = Generators.input(magThresholdProxy);
```

```js
// Cell 7 — preset state + setter (chip row built in cell 12).
//
// `presetTick` is a click counter that increments on every chip click,
// even when the user clicks the chip that's already active. The map
// cell reads the tick alongside `presetState`, so a click on the
// active "World" chip while the user is zoomed in still triggers a
// re-application of the preset transform — i.e. snaps back to the
// full world view. Without this, clicking "World" while presetState
// already === "world" wouldn't change any reactive value and the
// zoom would stay where the user dragged it.
const presets = {
  world:  {label: "World",         center: [  0,   0], k: 1.0},
  ring:   {label: "Ring of Fire",  center: [165,   0], k: 2.2},
  med:    {label: "Mediterranean", center: [ 40,  35], k: 4.0},
  andes:  {label: "Andes",         center: [-70, -20], k: 3.5}
};
const presetState = Mutable("world");
const presetTick = Mutable(0);
function setPreset(key) {
  presetState.value = key;
  presetTick.value = presetTick.value + 1;
}
```

```js
// Cell 8 — selectedCountry mutable + setter.
const selectedCountry = Mutable(null);
function setSelectedCountry(v) { selectedCountry.value = v; }
```

```js
// Cell 9a — one-time country index (geometric pass + place-tail
// fallback for offshore subduction events). See v3/CHANGES.md.
const countryBounds = countriesFeature.features.map(f => ({
  feature: f,
  bounds: d3.geoBounds(f)
}));
const countryIdByName = new Map();
for (const cb of countryBounds) {
  const name = cb.feature.properties && cb.feature.properties.name;
  if (name) countryIdByName.set(name.toLowerCase(), cb.feature.id);
}
const placeAliases = new Map([
  ["usa",                    "840"],
  ["united states",          "840"],
  ["u.s. virgin islands",    "850"],
  ["british virgin islands", "092"],
  ["macedonia",              "807"],
  ["czech republic",         "203"]
]);
const eventsByCountry = new Map();
function assign(q, id) {
  if (!eventsByCountry.has(id)) eventsByCountry.set(id, []);
  eventsByCountry.get(id).push(q);
}
for (const q of quakes) {
  const lon = q.longitude, lat = q.latitude;
  let assigned = null;
  for (const cb of countryBounds) {
    const [[minLon, minLat], [maxLon, maxLat]] = cb.bounds;
    const inLon = minLon > maxLon
      ? (lon >= minLon || lon <= maxLon)
      : (lon >= minLon && lon <= maxLon);
    if (!inLon || lat < minLat || lat > maxLat) continue;
    if (d3.geoContains(cb.feature, [lon, lat])) {
      assigned = cb.feature.id;
      break;
    }
  }
  if (assigned == null && q.place) {
    let tail = q.place.split(",").pop().trim().toLowerCase();
    if (tail.endsWith(" region")) tail = tail.slice(0, -" region".length).trim();
    if (countryIdByName.has(tail)) assigned = countryIdByName.get(tail);
    else if (placeAliases.has(tail)) assigned = placeAliases.get(tail);
  }
  if (assigned != null) assign(q, assigned);
}
```

```js
// Cell 9b — derived event sets (filters + country scope).
const filtered = quakes.filter(q => {
  const yr = q.time.getFullYear();
  return yr >= yearRange.start && yr <= yearRange.end && q.mag >= magThreshold;
});
const filteredByMagOnly = quakes.filter(q => q.mag >= magThreshold);
const inCountryIds = !selectedCountry ? null
  : new Set((eventsByCountry.get(selectedCountry.id) || []).map(q => q.id));
const filteredCountry = !inCountryIds ? filtered : filtered.filter(q => inCountryIds.has(q.id));
const filteredCountryByMagOnly = !inCountryIds ? filteredByMagOnly : filteredByMagOnly.filter(q => inCountryIds.has(q.id));
```

```js
// Cell 10 — reset button (built; the toolbar inserts it). The button is
// disabled when state already equals defaults — clearer affordance than
// always showing it as active.
const isDefault = yearRange.start === 1980 && yearRange.end === 2025
  && magThreshold === 5.0 && presetState === "world" && selectedCountry == null;
const resetButton = (() => {
  const btn = html`<button class="t12-reset">Reset all</button>`;
  btn.disabled = isDefault;
  btn.onclick = () => {
    yearRangeInput._setValue({start: 1980, end: 2025});
    yearRangeInput.dispatchEvent(new Event("t12:flush"));
    magThresholdInput.value = 5.0;
    magThresholdInput.dispatchEvent(new Event("t12:flush"));
    setPreset("world");
    setSelectedCountry(null);
  };
  return btn;
})();
```

```js
// Cell 11 — D3 zoomable SVG map. Heavy cell — re-renders on filter /
// magnitude / preset change. selectedCountry is updated by cell 11b
// without rebuilding the SVG (preserves zoom transform across clicks).
//
// Layer order: ocean rect · countries · hex layer · plate layer · dot
// layer · highlight layer (mutated by 11b).
//
// Zoom-preservation hack: window.__t12_zoom__ stores the last applied
// transform. A Framework Mutable can't be used because reading it in
// this cell would re-render on every pan event.

const width = 1240, height = 580;
const projection = d3.geoEqualEarth().fitSize([width, height], {type: "Sphere"});
const pathFn = d3.geoPath(projection);

const projected = filtered
  .map(q => {
    const xy = projection([q.longitude, q.latitude]);
    return xy ? {q, x: xy[0], y: xy[1]} : null;
  })
  .filter(Boolean);

// Dot density encoding (replaces v6's hex bins). Two tiers:
//   carpet  — every event with M < 7 rendered as a 0.9 px alloy
//             circle at 0.18 fill-opacity. The seismic carpet emerges
//             organically from alpha stacking: 1 event ≈ invisible,
//             50 stacked ≈ near-black. No fixed grid, no discrete
//             tiles — the data itself draws the plate boundaries.
//   highlights — every event with M ≥ 7 rendered as a heritage-red
//                circle sized by magnitude (M7 = 2.5 px, M9 = 7.5 px),
//                85 % opacity, with a thin white halo so they read on
//                both land and ocean.
//
// At world view this gives the classic "scientist's seismicity map"
// look (cf. Bird & Kagan 2004, USGS catalog plots): a dark stipple
// along subduction zones and ridges, a few brilliant dots marking the
// catalog's biggest events. Density is read from local opacity, not
// from binned counts.
const carpetThreshold = 7.0;
const carpetEvents = projected.filter(d => d.q.mag < carpetThreshold);
const highlightEvents = projected.filter(d => d.q.mag >= carpetThreshold);
const largestEvent = filtered.length === 0 ? null : filtered.reduce((a, b) => a.mag >= b.mag ? a : b);

// Ocean: medium-quartz stone-grey (cooler / darker than land).
// Land: light-quartz cream (lighter than ocean by ~15% value).
// The ~15% value difference is what makes the map readable as
// land vs. water without breaking the warm-neutral brand palette.
const svg = d3.create("svg")
  .attr("viewBox", [0, 0, width, height])
  .attr("preserveAspectRatio", "xMidYMid meet")
  .style("width", "100%")
  .style("height", "auto")
  .style("max-width", `${width}px`)
  .style("background", pg.mediumQuartz)
  .style("cursor", "grab");

svg.append("rect")
  .attr("class", "ocean")
  .attr("width", width).attr("height", height)
  .attr("fill", "transparent")
  .on("click", () => setSelectedCountry(null));

const zoomRoot = svg.append("g").attr("class", "zoom-root");

const countriesG = zoomRoot.append("g").attr("class", "countries");
countriesG.selectAll("path.country")
  .data(countriesFeature.features)
  .join("path")
  .attr("class", "country")
  .attr("d", pathFn)
  .attr("fill", pg.lightQuartz)
  .attr("stroke", pg.alloy)
  .attr("stroke-width", 0.4)
  .attr("stroke-opacity", 0.45)
  .attr("vector-effect", "non-scaling-stroke")
  .style("cursor", "pointer")
  .on("click", (event, d) => { event.stopPropagation(); setSelectedCountry(d); });

// Carpet layer — small alloy dots, alpha-stacked. Drawn from a single
// SVG <path> with one circle-arc command per event. ~70 k events
// rendered as one DOM node is dramatically cheaper than 70 k <circle>
// elements; the browser's path parser is fast and the GPU rasterizes
// the result in one pass.
const carpetLayer = zoomRoot.append("g").attr("class", "carpet").style("pointer-events", "none");
const carpetR = 0.9;
const carpetD = carpetEvents.map(d => {
  const x = d.x.toFixed(1), y = d.y.toFixed(1);
  return `M${x},${y}m-${carpetR},0a${carpetR},${carpetR} 0 1,0 ${carpetR * 2},0a${carpetR},${carpetR} 0 1,0 ${-carpetR * 2},0`;
}).join("");
carpetLayer.append("path")
  .attr("d", carpetD)
  .attr("fill", pg.alloy)
  .attr("fill-opacity", 0.18);

// Plate boundaries — onyx 1.1 px on the lighter land background pops
// without dominating; this is what makes the title's claim
// ("plate boundaries draw themselves") legible at first glance.
// Drawn ABOVE the carpet so the boundary line cuts cleanly through
// the seismic stipple.
const plateLayer = zoomRoot.append("g").attr("class", "plates").style("pointer-events", "none");
plateLayer.selectAll("path.plate")
  .data(plateBoundaries.features)
  .join("path")
  .attr("class", "plate")
  .attr("d", pathFn)
  .attr("fill", "none")
  .attr("stroke", pg.onyx)
  .attr("stroke-width", 1.1)
  .attr("stroke-opacity", 0.85)
  .attr("stroke-linejoin", "round")
  .attr("vector-effect", "non-scaling-stroke");

// Highlights layer — M ≥ 7 events as larger heritage-red circles with
// a thin white halo so they read on both cream land and stone ocean.
// Magnitude → radius is the only encoding here (single channel, no
// double-encoding with the carpet which uses count→opacity-stacking).
const highlightLayer = zoomRoot.append("g").attr("class", "highlights").style("pointer-events", "none");
highlightLayer.selectAll("circle.major")
  .data(highlightEvents)
  .join("circle")
  .attr("class", "major")
  .attr("cx", d => d.x)
  .attr("cy", d => d.y)
  .attr("r", d => Math.max(2.2, (d.q.mag - 6) * 2.2))
  .attr("fill", pg.heritageRedDark)
  .attr("fill-opacity", 0.78)
  .attr("stroke", "#FFFFFF")
  .attr("stroke-width", 0.6)
  .attr("stroke-opacity", 0.7)
  .attr("vector-effect", "non-scaling-stroke");

const highlightG = zoomRoot.append("g").attr("class", "highlight").style("pointer-events", "none");
highlightG.append("path").attr("class", "selected-country-fill")
  .attr("fill", pg.heritageRed).attr("fill-opacity", 0.18)
  .attr("stroke", pg.heritageRedDark).attr("stroke-width", 1.6)
  .attr("vector-effect", "non-scaling-stroke");

const calloutG = zoomRoot.append("g").attr("class", "callout").style("pointer-events", "none");
calloutG.append("circle").attr("class", "callout-ring")
  .attr("r", 11).attr("fill", "none")
  .attr("stroke", pg.heritageRed).attr("stroke-width", 1.6)
  .attr("vector-effect", "non-scaling-stroke");
calloutG.append("text").attr("class", "callout-label")
  .attr("text-anchor", "middle")
  .attr("font-size", 11).attr("font-weight", 600)
  .attr("fill", pg.heritageRedDark)
  .attr("stroke", "#FFFFFF").attr("stroke-width", 3).attr("paint-order", "stroke");

const zoom = d3.zoom()
  .scaleExtent([1, 32])
  .on("zoom", (ev) => {
    const k = ev.transform.k;
    zoomRoot.attr("transform", ev.transform);
    // Highlights are kept at constant on-screen size by counter-scaling
    // their radii with the zoom level. Without this, an M9 dot that's
    // 6.6 px at world view balloons to 26 px at k=4 — too big.
    // Carpet dots are small enough (0.9 px base) that letting them
    // scale naturally with zoom is fine — at k=4 the carpet is 3.6 px
    // which still reads as a stipple, not blobs.
    highlightLayer.selectAll("circle.major")
      .attr("r", d => Math.max(2.2, (d.q.mag - 6) * 2.2) / Math.max(1, Math.sqrt(k)));
    window.__t12_zoom__ = ev.transform;
  });
svg.call(zoom);

// Decide between (a) applying a preset transform with a smooth
// transition (presetState OR presetTick changed since last render) and
// (b) snapping back the user's last pan/zoom (filter / magnitude
// rebuild — preset hasn't changed). The tick check is what makes
// re-clicking the active chip reset the zoom.
const lastPreset = window.__t12_preset__;
const lastTick = window.__t12_preset_tick__;
const presetChanged = presetState !== lastPreset || presetTick !== lastTick;
if (presetChanged) {
  const ap = presets[presetState] || presets.world;
  let t;
  if (ap.k !== 1) {
    const xy = projection(ap.center);
    t = d3.zoomIdentity
      .translate(width / 2 - ap.k * xy[0], height / 2 - ap.k * xy[1])
      .scale(ap.k);
  } else {
    t = d3.zoomIdentity;
  }
  // Pre-set the new SVG to the user's last saved transform BEFORE
  // starting the transition, so the fly-to interpolates from where
  // they were rather than from identity. Without this the heavy-cell
  // rebuild produces a fresh SVG at identity (= world view), and the
  // transition reads as "reset to world, then zoom in" instead of
  // "smoothly travel from current view to target."
  if (lastTick === undefined) {
    // First render of the session — apply preset instantly.
    svg.call(zoom.transform, t);
  } else {
    if (window.__t12_zoom__) {
      svg.call(zoom.transform, window.__t12_zoom__);
    }
    // Mapbox-style ease-out cubic, 550 ms.
    svg.transition().duration(550).ease(d3.easeCubicOut).call(zoom.transform, t);
  }
  window.__t12_preset__ = presetState;
  window.__t12_preset_tick__ = presetTick;
  window.__t12_zoom__ = t;
} else if (window.__t12_zoom__) {
  svg.call(zoom.transform, window.__t12_zoom__);
}

const mapSvg = svg.node();
const mapContext = {svg, projection, largestEvent, pathFn};
```

```js
// Cell 11b — light-touch update layer. Mutates the rendered SVG when
// selectedCountry changes. Does NOT rebuild the SVG; user's pan + zoom
// are preserved across country selections.
{
  const sel = d3.select(mapSvg);
  sel.select("path.selected-country-fill")
    .attr("d", selectedCountry ? mapContext.pathFn(selectedCountry) : null);

  const target = (() => {
    if (selectedCountry && filteredCountry.length > 0) {
      return filteredCountry.reduce((a, b) => a.mag >= b.mag ? a : b);
    }
    return mapContext.largestEvent;
  })();
  if (target) {
    const xy = mapContext.projection([target.longitude, target.latitude]);
    if (xy) {
      sel.select("circle.callout-ring")
        .attr("cx", xy[0]).attr("cy", xy[1])
        .style("display", null);
      sel.select("text.callout-label")
        .attr("x", xy[0]).attr("y", xy[1] - 18)
        .style("display", null)
        .text(`M${target.mag.toFixed(1)} · ${target.time.getUTCFullYear()}`);
    } else {
      sel.select("circle.callout-ring").style("display", "none");
      sel.select("text.callout-label").style("display", "none");
    }
  } else {
    sel.select("circle.callout-ring").style("display", "none");
    sel.select("text.callout-label").style("display", "none");
  }
}
```

```js
// Cell 12 — preset chip row (depends on presetState so the active chip
// re-renders).
const presetChips = html`<div class="t12-chips">
  ${Object.entries(presets).map(([key, p]) => {
    const btn = html`<button class="t12-chip ${presetState === key ? "is-active" : ""}">${p.label}</button>`;
    btn.onclick = () => setPreset(key);
    return btn;
  })}
</div>`;
```

```js
// Cell 13 — country detail card. Empty state when no country selected;
// otherwise: stat tiles, inset map, top-5 events. Restyled with white
// surface + soft shadow + brand typography.
const countryCard = (() => {
  if (selectedCountry == null) {
    return html`<div class="t12-empty">
      <span class="icon">⌖</span>
      <strong style="color:${pg.alloy};font-weight:600">Click a country</strong> on the map to filter every panel below to that country's events.
      The histogram and the year strip will redraw to its scope, and the largest-event callout retargets to the country's biggest event in the active window.
    </div>`;
  }

  const name = (selectedCountry.properties && selectedCountry.properties.name) || `Country ${selectedCountry.id}`;
  const events = filteredCountry.slice().sort((a, b) => b.mag - a.mag);

  const clearBtn = html`<button class="t12-clear-link" title="Clear country selection">✕ clear</button>`;
  clearBtn.onclick = () => setSelectedCountry(null);

  if (events.length === 0) {
    return html`<div class="t12-country-card">
      <div class="t12-country-card-header">
        <div>
          <div class="t12-country-name">${name}</div>
          <div class="t12-country-sub">no events at the current filter settings</div>
        </div>
        ${clearBtn}
      </div>
    </div>`;
  }
  const top5 = events.slice(0, 5);
  const largest = events[0];
  const sixPlus = events.filter(q => q.mag >= 6).length;

  // Inset map — fit the country bounds into a 220×170 box.
  const insetW = 240, insetH = 180;
  const insetProj = d3.geoEqualEarth().fitSize([insetW - 20, insetH - 20], selectedCountry);
  const insetPath = d3.geoPath(insetProj);
  const insetSvg = d3.create("svg")
    .attr("viewBox", `0 0 ${insetW} ${insetH}`)
    .attr("width", insetW).attr("height", insetH)
    .style("background", pg.bg)
    .style("border-radius", "4px")
    .style("display", "block");
  const insetG = insetSvg.append("g").attr("transform", "translate(10,10)");
  insetG.append("path")
    .attr("d", insetPath(selectedCountry))
    .attr("fill", pg.lightQuartz)
    .attr("stroke", pg.alloy).attr("stroke-width", 0.7)
    .attr("vector-effect", "non-scaling-stroke");
  insetG.selectAll("circle")
    .data(top5)
    .join("circle")
    .attr("cx", q => insetProj([q.longitude, q.latitude]) ? insetProj([q.longitude, q.latitude])[0] : -100)
    .attr("cy", q => insetProj([q.longitude, q.latitude]) ? insetProj([q.longitude, q.latitude])[1] : -100)
    .attr("r", q => Math.max(2.2, (q.mag - 4.5) * 2.2))
    .attr("fill", pg.heritageRed).attr("fill-opacity", 0.55)
    .attr("stroke", pg.heritageRedDark).attr("stroke-width", 0.9);

  return html`<div class="t12-country-card">
    <div class="t12-country-card-header">
      <div>
        <div class="t12-country-name">${name}</div>
        <div class="t12-country-sub">${events.length.toLocaleString()} events in this filter window · top 5 by magnitude shown</div>
      </div>
      ${clearBtn}
    </div>
    <div class="t12-stat-row">
      <div class="t12-stat-tile">
        <div class="t12-stat-label">Events</div>
        <div class="t12-stat-value">${events.length.toLocaleString()}</div>
        <div class="t12-stat-sub">M ≥ ${magThreshold.toFixed(1)}</div>
      </div>
      <div class="t12-stat-tile accent">
        <div class="t12-stat-label">Largest</div>
        <div class="t12-stat-value">M${largest.mag.toFixed(1)}</div>
        <div class="t12-stat-sub">${largest.time.toISOString().slice(0,10)}</div>
      </div>
      <div class="t12-stat-tile">
        <div class="t12-stat-label">M ≥ 6</div>
        <div class="t12-stat-value">${sixPlus.toLocaleString()}</div>
        <div class="t12-stat-sub">${(100 * sixPlus / events.length).toFixed(0)}% of total</div>
      </div>
    </div>
    <div class="t12-detail-body">
      <div>
        ${insetSvg.node()}
        <div class="t12-inset-cap">top 5 events · circle area ∝ magnitude</div>
      </div>
      <table class="t12-event-table">
        <thead><tr><th>Place</th><th>M</th><th>Date</th><th></th></tr></thead>
        <tbody>${top5.map(q => html`<tr>
          <td>${q.place}</td>
          <td class="num">${q.mag.toFixed(1)}</td>
          <td class="num">${q.time.toISOString().slice(0,10)}</td>
          <td><a href="https://earthquake.usgs.gov/earthquakes/eventpage/${q.id}" target="_blank" rel="noopener">USGS ↗</a></td>
        </tr>`)}</tbody>
      </table>
    </div>
  </div>`;
})();
```

```js
// Cell 14 — magnitude histogram, restyled to match the brand. Plot's
// `style` option carries font + color; transparent background sits on
// the panel card.
const plotStyle = {
  background: "transparent",
  color: pg.alloy,
  fontFamily: "inherit",
  fontSize: "11px",
  overflow: "visible"
};
const magHist = Plot.plot({
  width: 600,
  height: 200,
  marginLeft: 50,
  marginBottom: 36,
  marginRight: 8,
  marginTop: 8,
  style: plotStyle,
  x: {label: "Magnitude →", labelAnchor: "right", labelOffset: 28, ticks: 6, tickSize: 0},
  y: {label: null, grid: true, ticks: 4, tickSize: 0},
  marks: [
    Plot.rectY(filteredCountry, Plot.binX(
      {y: "count"},
      {x: "mag", interval: 0.1, fill: selectedCountry ? pg.heritageRedDark : pg.copper, insetLeft: 0.4, insetRight: 0.4}
    )),
    Plot.ruleY([0], {stroke: pg.alloy, strokeWidth: 0.6})
  ]
});
```

```js
// Cell 15 — year strip (pale backdrop = full-history at mag threshold,
// dark overlay = year window).
const yearStrip = Plot.plot({
  width: 600,
  height: 200,
  marginLeft: 50,
  marginBottom: 30,
  marginRight: 8,
  marginTop: 8,
  style: plotStyle,
  x: {label: null, tickFormat: "d", ticks: 6, tickSize: 0},
  y: {label: null, grid: true, ticks: 4, tickSize: 0},
  marks: [
    Plot.rectY(filteredCountryByMagOnly, Plot.binX(
      {y: "count"},
      {x: d => d.time.getFullYear(), interval: 1, fill: pg.quartz, insetLeft: 0.5, insetRight: 0.5}
    )),
    Plot.rectY(filteredCountry, Plot.binX(
      {y: "count"},
      {x: d => d.time.getFullYear(), interval: 1, fill: selectedCountry ? pg.heritageRedDark : pg.copper, insetLeft: 0.5, insetRight: 0.5}
    )),
    Plot.ruleY([0], {stroke: pg.alloy, strokeWidth: 0.6})
  ]
});
```

```js
// Cell 16 — toolbar (single-row control panel above the map).
//
// The value readouts ("1980 – 2025" / "M5.0") update live during drag
// via direct DOM manipulation, NOT via Framework reactivity. This is
// the whole point of the debounced proxy: cells that read `yearRange`
// or `magThreshold` only re-run after the slider settles, while
// readouts here stay synced to every input event so the user gets
// frame-rate feedback. Listeners are cleaned up on invalidation so
// they don't accumulate across cell re-runs.
const yearReadout = html`<div class="t12-value-readout"><span></span><span class="sep"> – </span><span></span></div>`;
const magReadout = html`<div class="t12-value-readout"></div>`;

function syncYearReadout() {
  const v = yearRangeInput.value;
  const spans = yearReadout.querySelectorAll("span");
  spans[0].textContent = v.start;
  spans[2].textContent = v.end;
}
function syncMagReadout() {
  magReadout.textContent = `M${(+magThresholdInput.value).toFixed(1)}`;
}
yearRangeInput.addEventListener("input", syncYearReadout);
yearRangeInput.addEventListener("t12:flush", syncYearReadout);
magThresholdInput.addEventListener("input", syncMagReadout);
magThresholdInput.addEventListener("t12:flush", syncMagReadout);
syncYearReadout();
syncMagReadout();
invalidation.then(() => {
  yearRangeInput.removeEventListener("input", syncYearReadout);
  yearRangeInput.removeEventListener("t12:flush", syncYearReadout);
  magThresholdInput.removeEventListener("input", syncMagReadout);
  magThresholdInput.removeEventListener("t12:flush", syncMagReadout);
});

display(html`<div class="t12-toolbar">
  <div class="t12-toolbar-segment">
    <span class="t12-eyebrow">Year window</span>
    ${yearRangeInput}
    ${yearReadout}
  </div>
  <div class="t12-toolbar-segment t12-mag">
    <span class="t12-eyebrow">Minimum magnitude</span>
    ${magThresholdInput}
    ${magReadout}
  </div>
  <div class="t12-toolbar-segment">
    <span class="t12-eyebrow">Zoom presets</span>
    ${presetChips}
  </div>
  <div class="t12-toolbar-segment actions">
    ${resetButton}
  </div>
</div>`);
```

```js
// Cell 17 — map + legend, wrapped in a card frame.
display(html`<div class="t12-map-card">
  ${mapSvg}
</div>
<div class="t12-legend-row">
  <div class="t12-legend-group">
    <span class="t12-legend-carpet"></span>
    <strong>each event</strong>
    <span>M < 7, alpha-stacked</span>
  </div>
  <div class="t12-legend-group">
    <span class="t12-legend-major-sm"></span>
    <span class="t12-legend-major-md"></span>
    <span class="t12-legend-major-lg"></span>
    <strong>major events</strong>
    <span>M ≥ 7, sized by magnitude</span>
  </div>
  <div class="t12-legend-group">
    <span class="t12-legend-line"></span>
    <strong>plate boundary</strong>
  </div>
  <div class="t12-legend-group">
    <span class="t12-legend-dot"></span>
    <span>largest event in window</span>
  </div>
</div>`);
```

## Country detail

```js
// Cell 18 — country card display.
display(countryCard);
```

## Distribution

```js
// Cell 19 — linked-views grid. Each chart in its own white card.
const countrySuffix = !selectedCountry ? null : selectedCountry.properties.name;
display(html`<div class="t12-panels">
  <div class="t12-panel-card">
    <div class="t12-panel-title">Magnitude distribution</div>
    <div class="t12-panel-meta">${countrySuffix
      ? html`<span class="scope">${countrySuffix}</span> · M ≥ ${magThreshold.toFixed(1)}, ${yearRange.start}–${yearRange.end}`
      : html`world · M ≥ ${magThreshold.toFixed(1)}, ${yearRange.start}–${yearRange.end}`}</div>
    ${magHist}
  </div>
  <div class="t12-panel-card">
    <div class="t12-panel-title">Events per year</div>
    <div class="t12-panel-meta">${countrySuffix
      ? html`<span class="scope">${countrySuffix}</span> · pale = all years, dark = ${yearRange.start}–${yearRange.end}`
      : html`world · pale = all years, dark = ${yearRange.start}–${yearRange.end}`}</div>
    ${yearStrip}
  </div>
</div>`);
```

```js
// Cell 20 — single-line source footer. The full data citations,
// methods, and tooling list live in the portfolio's reference page
// (task 18), not on the website.
display(html`<div class="t12-methods">
  <p>Source:
    <a href="https://earthquake.usgs.gov/fdsnws/event/1/" target="_blank" rel="noopener">USGS ANSS Comprehensive Earthquake Catalog</a>
    · plate boundaries: Bird (2003) PB2002.</p>
</div>`);
```
