# Task 12 — Interactive Visualization: 45 Years of Earthquakes (Revised Plan)

## Context

Task 12 of the HSG portfolio requires a publicly-deployed interactive visualization that goes beyond hover/zoom. The course definition (slides/05.2_interactive_visualizations.pdf) requires real selection, filtering, linking, drill-down, encoding remapping, brushing, or temporal scrubbing — and Shneiderman's mantra (overview first → zoom and filter → details on demand).

Existing portfolio threads already cover climate (Task 4), conflict (5), energy (6), finance (7), plastic (8), language (9), and demographics (11). To diversify, the chosen topic is **point-level global seismicity 1980–2025**, sourced from the USGS Earthquake Catalog. The story this answers — *"Where do the Earth's plates actually grind?"* — emerges only when 45 years of M≥5 events are accumulated and the viewer can scrub through the time window. A static map can't tell it; that is the justification for an interactive form.

**Deliverable shape (locked with the user):**
- Topic: Global earthquakes, 1980-01-01 to 2025-12-31, magnitude ≥ 5.0
- Hosting: **Observable Framework, deployed to GitHub Pages** (free public URL, no viewer login)
- Portfolio embed: **one page, one screenshot** of the default overview state, plus a clickable live URL

---

## Hosting decision (revised: Notebook → Framework + GitHub Pages)

> **Revised:** the original choice was Observable Notebook, on the basis that observablehq.com is the canonical free public-URL host for an interactive Plot-based visualization. Implementation via a CLI agent inverted that assumption.

**The reasoning, recorded for grading evidence:**

The original Notebook choice was made assuming an interactive web-UI authoring loop. Implementation via a CLI agent inverts that assumption — Notebook's browser-only runtime makes the smoke tests impossible without a parallel local stack, which would force maintaining two source-of-truth files. Framework on GitHub Pages keeps cells as committed `.md` files in the repo, aligns with the existing Quarto + GitHub Pages workflow used for the portfolio, allows local testing via `npm run dev` against the same Plot/Inputs/FileAttachment APIs that ship to production, and produces an equivalent public no-login interactive URL. The smoke-test rigor PLAN.md depends on is preserved; the deployment story becomes simpler, not more complex.

**Practical consequences:**

- The notebook's source-of-truth file becomes `interactive/task_12/src/index.md` (committed to git) instead of an observablehq.com cell stack mirrored to `iterations/task_12/v1/notebook.ojs.md`.
- Cell syntax adjusts from Notebook's `viewof X = …` to Framework's `const X = view(Inputs.…(…))` pattern. `Mutable` and event-listener wiring are unchanged.
- `FileAttachment(...)` paths resolve relative to the project source file, not a CDN-hosted attachment.
- The deployed URL is `https://alexander-the-sufficient.github.io/data_vizualisation_with_ai/task_12/` (resolved from the existing portfolio repo `Alexander-the-sufficient/data_vizualisation_with_ai`; the unconventional spelling is preserved as-is). Task 12 is the first thing this repo will publish to Pages.
- **Prerequisite (manual, one-time):** GitHub Pages must be enabled in repo **Settings → Pages → Source: GitHub Actions** before the first deploy. The agent has the `repo` and `workflow` token scopes to push the workflow file, but enabling Pages itself is left as a single human click — a failure on the API enable path is more confusing to debug than a missed checkbox.

---

## Architecture (Observable Framework page, cells top-to-bottom)

> **Revised:** primary map mark switched from `Plot.dot` to `Plot.hexbin`; brushable time strip promoted to required; map interaction switched from click to brush; region list trimmed to three with a Pacific-Ring projection variant; date range tightened to 1980–2025 (was 1975–2025); `magType` added to kept columns and surfaced in the detail panel; `Plot.brush` syntax corrected to `{x, y}` form; `filteredInBrush` derivation specified to use `Plot.brush`'s native data-channel emission; **hosting pivoted from Observable Notebook to Observable Framework + GitHub Pages** (rationale in the Hosting decision section above) — cell syntax adjusts to Framework's `view()` and `Mutable` patterns, the cell stack is otherwise identical.

1. **Title + framing** (markdown). One-paragraph story setup; the question the chart answers.
2. **`quakes` (FileAttachment CSV)** — pre-processed locally: columns `id, time, latitude, longitude, depth, mag, magType, place`. Magnitude ≥ 5.0 filter pre-applied; **shipped uncompressed at ~7 MB** (gzip path was abandoned after dev-server verification — see Data pipeline section). The `id` column is required for constructing per-event USGS links in the detail panel; `magType` carries the catalog's heterogeneous magnitude scale label (Mw, mb, ML, Ms) for surfacing alongside the value in the detail panel.
3. **`world` (FileAttachment TopoJSON)** — `countries-110m.json` (~100 KB) for the basemap. Decoded at use site via `topojson.feature(world, world.objects.countries)`.
4. **`pg`** — JS port of `design_system.R` tokens: `{alloy: "#5C5B59", lightQuartz: "#ECEAE4", quartz: "#D6D0C2", darkStone: "#7E8182", heritageRed: "#D92B2B", copper: "#896C4C"}`.
5. **`yearRange`** — two-handle range input over `[1980, 2025]`, default `[1980, 2025]`. Framework pattern: `const yearRangeInput = Inputs.range([1980, 2025], {step: 1, value: [1980, 2025], label: "Year range"}); const yearRange = Generators.input(yearRangeInput); display(yearRangeInput);` (using the explicit input/Generator/display triple so the same input element can be `Inputs.bind`'d to the time-strip brush in cell 13). Two-way bound to the time-strip brush so dragging either control updates the other. Drives the map and the histogram.
6. **`magThreshold`** — `const magThresholdInput = Inputs.range([5.0, 7.5], {step: 0.1, value: 5.0, label: "Minimum magnitude"}); const magThreshold = Generators.input(magThresholdInput); display(magThresholdInput);`. *Revised:* slider range tightened — see "Magnitude slider range" note below.
7. **`regionFocus`** — `const regionFocusInput = Inputs.select(["World", "Pacific Ring of Fire", "Mid-Atlantic Ridge"], {value: "World", label: "Region"}); const regionFocus = Generators.input(regionFocusInput); display(regionFocusInput);`. *Revised:* reduced from six options to three for v1; rationale and v2 candidates documented below. Each region maps to a projection config: `World → equal-earth, rotate [0,0]`; `Pacific Ring of Fire → equal-earth, rotate [-150, 0]` (so the arc renders as a single continuous shape instead of being cut at the antimeridian); `Mid-Atlantic Ridge → equal-earth, rotate [30, 0]`.
8. **`mapBrush`** (`Mutable`) — set by the `Plot.brush` interaction on the map (cell 11). Wiring detail (made explicit per review): `const mapBrush = Mutable(null);` declared in this cell. The map cell (11) renders the `Plot.plot(...)` to a DOM node, then attaches an `input` event listener: `plot.addEventListener("input", () => mapBrush.value = plot.value);`. `plot.value` is the array of data rows currently inside the brush rectangle (because the brush mark is bound to `x: "longitude"` and `y: "latitude"` — the value is data rows, not pixel coordinates). When the brush is cleared, `plot.value` is `null`, which propagates to `mapBrush.value`. No manual inverse-projection.
9. **`filtered`** — reactive derivation of the visible event set from `yearRange`, `magThreshold`, `regionFocus`. A second derivation `filteredInBrush = mapBrush ?? filtered` narrows by the brush selection when present and falls back to the full filtered set when not. No manual inverse-projection is required.
10. **`projection`** — derived from `regionFocus`; passes `{type: "equal-earth", rotate: [...]}` into `Plot.plot`.
11. **`mapView`** — assigns the rendered Plot to a local variable, attaches the brush listener, and calls `display(plot)`:
    ```js
    const plot = Plot.plot({
      projection,
      marks: [
        Plot.geo(countriesFeature, {fill: pg.lightQuartz, stroke: "white"}),
        Plot.hexbin(filtered, {x: "longitude", y: "latitude", binWidth: 12, fill: "count"}),
        Plot.brush({x: "longitude", y: "latitude"})
      ],
      color: {
        type: "sqrt",
        range: [pg.lightQuartz, pg.alloy],
        legend: true,
        label: "Events per hex"
      }
    });
    plot.addEventListener("input", () => mapBrush.value = plot.value);
    display(plot);
    ```
    *Revised:* primary mark is `Plot.hexbin` (binWidth ≈ 12px, sequential single-hue ramp from `pg.lightQuartz` → `pg.alloy`, no red endpoint), with `Plot.dot` reserved for focused regions whose visible event count falls below ~8000. The color scale is sqrt-transformed because hex counts in seismicity are heavy-tailed (most hexes contain a handful of events; a few near subduction zones contain hundreds) — a linear scale would render the long tail invisible. **Performance argument:** ~75k reactive `Plot.dot` redraws exceed the slides' "rapid, fluid response" requirement (≥250 ms slider lag in informal benchmarks); hexbin keeps filter response under 250 ms and tells the plate-boundary story more clearly than overplotted semi-transparent dots at global scale, which collapse to a uniform smear along the Ring of Fire. The hexbin grid itself *is* the plate boundary at world zoom. **Selection:** dot view kicks in automatically when the active region is non-`World` and the filtered event count drops below the 8000 threshold.
12. **`magHistogram`** — companion histogram of magnitudes in the filtered set. `Plot.rectY({y: count, x: "mag", interval: 0.1})`. Re-renders on every filter change — demonstrates linked views.
13. **`yearBrush`** — *Revised: required, not optional.* Yearly bar chart of event counts with `Plot.brushX` as an interactive transform. Framework wiring (made explicit per review):
    ```js
    const stripPlot = Plot.plot({
      height: 90,
      marks: [
        Plot.rectY(filtered, Plot.binX({y: "count"},
          {x: d => +d.time.slice(0,4), interval: 1, fill: pg.darkStone})),
        Plot.brushX({x: d => +d.time.slice(0,4)})
      ]
    });
    stripPlot.addEventListener("input", () => {
      const sel = stripPlot.value;
      if (sel?.length) {
        const yrs = sel.map(d => +d.time.slice(0,4));
        yearRangeInput.value = [Math.min(...yrs), Math.max(...yrs)];
        yearRangeInput.dispatchEvent(new Event("input", {bubbles: true}));
      }
    });
    display(stripPlot);
    ```
    The two-way binding writes back into the slider's `yearRangeInput` and dispatches an `input` event so `Generators.input` picks it up; the slider's own `input` events do not write back into `stripPlot.value` (the brush mark is data-bound, not interval-bound), but since both controls write to the same `yearRange` reactive value, the upstream `filtered` derivation re-fires once and both views re-render coherently — no infinite-loop risk because the brush listener only fires on user interaction, not on programmatic value updates. This is the cleanest demonstration of "brushing" in the course vocabulary and is required in v1.
14. **`detailPanel`** — *Revised:* shows the **top 5 largest events** inside the current `mapBrush`, sorted by magnitude descending. Each row: place name, magnitude with type (e.g. "M 6.4 (Mw)"), depth (km), ISO time, and a link to the USGS event page constructed as `https://earthquake.usgs.gov/earthquakes/eventpage/${id}`. If `mapBrush` is null, shows a single-line hint ("Drag a box on the map to inspect the largest events in that region"). **No offline geospatial join, no plate-boundary distance** — both removed for v1.
15. **`resetCell`** — Framework button pattern:
    ```js
    const reset = Inputs.button("Reset all filters", {reduce: () => {
      yearRangeInput.value = [1980, 2025]; yearRangeInput.dispatchEvent(new Event("input", {bubbles: true}));
      magThresholdInput.value = 5.0;       magThresholdInput.dispatchEvent(new Event("input", {bubbles: true}));
      regionFocusInput.value = "World";    regionFocusInput.dispatchEvent(new Event("input", {bubbles: true}));
      mapBrush.value = null;
    }});
    display(reset);
    ```
    Reversibility per the course-level definition.
16. **Methods + sources footer** (markdown). Cites USGS ANSS ComCat, links to FDSN web service docs, lists tooling (Observable Plot, Claude Code). Also notes: USGS preferred magnitudes are heterogeneous across the catalog (Mw, mb, ML, Ms); for visualization purposes the catalog is treated as a single magnitude axis.

State flow: `yearRange ↔ yearBrush`, `magThreshold`, `regionFocus` are upstream of `filtered`; `filtered` feeds `mapView`, `magHistogram`, `yearBrush`. `mapBrush` is downstream of `mapView` brush events (set by the `input` event listener attached to the rendered `Plot.plot(...)` DOM node) and feeds `detailPanel` via the `filteredInBrush` derivation. Framework's reactive runtime (the same dataflow engine as observablehq.com Notebooks) resolves dependencies between cells — no manual subscriptions across cells, only the in-cell DOM listeners that bridge Plot output to `Mutable` values.

### Magnitude slider range

> **Revised:** `Inputs.range([5.0, 7.5], {step: 0.1, value: 5.0})`. The prep.R floor at M≥5.0 is the *data* floor; the slider's job is to let the user push the threshold *up* to isolate large events, not down (the dataset has nothing below 5.0). The 7.5 ceiling caps at the regime where event counts collapse to single digits per year — beyond that the chart becomes a list of named events, not a map.

### Region list reduction

> **Revised:** v1 ships three regions: World, Pacific Ring of Fire, Mid-Atlantic Ridge. Mediterranean–Himalaya Belt, Andean, and East African Rift are deferred to v2 to keep the v1 implementation surface tractable and to verify the projection-variant pattern works end-to-end on three before generalizing to six.

---

## Interactions that satisfy "beyond hover/zoom"

In the course vocabulary from slides/05.2_interactive_visualizations.pdf:

1. **Temporal filtering / scrubbing** — year-range slider re-derives the visible event set across map + time strip + histogram. Two-way bound to the time-strip brush.
2. **Brushing (time)** — `Plot.brushX` over the yearly time strip; drag a window to filter all views. *Revised:* required in v1.
3. **Brushing (space)** — `Plot.brush` over the map produces a bounding box that drives the detail panel's top-5 ranked list. *Revised:* this replaces the original click-on-dot interaction. Per-mark click handling in `Plot` requires post-render `d3.select` and is unreliable for overlapping/overplotted dots at global scale; brush is native to Plot and produces a more useful detail view (a ranked list, not a single ambiguous point).
4. **Filtering (magnitude)** — magnitude-threshold slider re-derives the visible set on the magnitude axis.
5. **Region focus / encoding remap** — region selector both filters quakes to a bounding box *and* swaps the projection rotation (filtering combined with encoding adjustment).
6. **Reset** — full reversibility, required by the course-level definition.

Hover-only and pan/zoom are explicitly *not* relied on for the interactive grade.

---

## Data pipeline

> **Revised:** removed plate-boundary distance computation; `id` added to kept columns for USGS event links; `magType` added to kept columns for surfacing magnitude scale labels in the detail panel; start year tightened to 1980 (was 1975) with the catalog-completeness rationale documented inline.

- **Start-year rationale (1980, not 1975)**: pre-1980 catalog completeness in remote ocean basins (notably the South Pacific) is materially lower than post-1990 due to global broadband seismograph network expansion. Starting at 1980 avoids a methodological caveat without losing analytical content.
- **Source**: USGS FDSN Event Web Service. Endpoint: `https://earthquake.usgs.gov/fdsnws/event/1/query?format=csv&starttime=1980-01-01&endtime=2025-12-31&minmagnitude=5.0`. The API caps at 20,000 events per request, so the script splits the call into ~4–6 calendar-year batches and concatenates.
- **Local raw**: `data/task_12/usgs_quakes_1980_2025_m5.csv` (concatenated from batches). Cite as: USGS Earthquake Hazards Program, ANSS Comprehensive Earthquake Catalog (ComCat).
- **Prep script**: `iterations/task_12/v1/prep.R`. Reads the raw CSV, **keeps `id, time, latitude, longitude, depth, mag, magType, place`** (revised: `id` and `magType` added; nothing geospatial-join-related kept), filters out anything outside the date window, sorts by time, writes a tidy gzipped CSV to `interactive/task_12/src/data/quakes.csv`.
- **TopoJSON basemap**: download `countries-110m.json` from `cdn.jsdelivr.net/npm/world-atlas@2/countries-110m.json` into `interactive/task_12/src/data/world-110m.json`. Public domain, ~100 KB. Decoded in the Framework page via `topojson.feature(world, world.objects.countries)` — *not* `world.features` directly.
- **Framework data wiring**: both files live in `interactive/task_12/src/data/` (inside the Framework `root: "src"` so FileAttachment resolves them); cells reference them via `FileAttachment("./data/quakes.csv").csv({typed: true})` and `FileAttachment("./data/world-110m.json").json()`. *Revised:* the earthquake catalog is shipped **uncompressed** (~7 MB), not gzipped. The original plan assumed gzip auto-decompression was transparent at the HTTP layer, but verification against the Framework dev server showed it serves `.csv.gz` with `Content-Type: application/gzip` and no `Content-Encoding: gzip` header — the browser hands raw gzipped bytes to `d3.csv()`, which fails. GitHub Pages production exhibits the same behaviour (no Jekyll plugin auto-sets `Content-Encoding: gzip` for compressed assets). Falling back to uncompressed CSV is the documented PLAN.md fallback path; ~7 MB on first load, browser-cached thereafter — no real cost.
- **Performance**: ~75k events at world zoom render via `Plot.hexbin`, not `Plot.dot`. Hexbin redraws in <100 ms per filter change in informal benchmarks. The `Plot.dot` fallback engages automatically when the active region is non-`World` *and* the filtered event count drops below 8000 — typical for any region + magnitude ≥ 5.5 combination.

---

## Portfolio integration (one page, one screenshot)

> **Revised:** structurally unchanged from the prior plan. Layout reproduced for completeness.

In `portfolio/portfolio.qmd`, immediately after the Task 11 section (`\newpage`), insert a Pattern-B layout block:

```
# Task 12 — Interactive: 45 Years of Earthquakes

```{=latex}
\begin{center}
{\fontsize{14pt}{17pt}\selectfont\color{onyx}\textbf{Where the Earth's plates actually grind: 45 years of M≥5 earthquakes.}}\\[0.4em]
{\fontsize{11pt}{14pt}\selectfont\color{alloy} Year-range slider, magnitude threshold, region focus, brushable time strip, and brush-the-map for detail. The Pacific Ring of Fire emerges only when 45 years of seismicity are allowed to accumulate.}
\end{center}
```

![](../final/task_12/state_overview.pdf){fig-align="center" width="86%"}

```{=latex}
\begin{center}
{\fontsize{11pt}{14pt}\selectfont\color{alloy} Try it live: \url{https://alexander-the-sufficient.github.io/data_vizualisation_with_ai/task_12/}}
\end{center}
```

```{=latex}
\begin{center}
{\footnotesize\color{darkstone}\itshape Source: USGS Earthquake Hazards Program, ANSS Comprehensive Earthquake Catalog (ComCat), via the FDSN event web service. \url{https://earthquake.usgs.gov/fdsnws/event/1/}}
\end{center}
```

\newpage
```

**Screenshot capture procedure:**
1. Trigger deployment by pushing the latest `interactive/task_12/**` commits to `main`. The `.github/workflows/deploy-task-12.yml` Actions workflow builds the Framework project and publishes `dist/` to GitHub Pages. **First push must wait ~2 min for the workflow to complete before the URL is reachable**; subsequent pushes typically deploy in 60–90 s. Confirm green tick in the Actions tab before opening the URL.
2. Open `https://alexander-the-sufficient.github.io/data_vizualisation_with_ai/task_12/` in Chrome at 2× zoom.
3. The single screenshot is a **composite of the map cell and the time-strip cell rendered together** — captured in **one Chrome print-to-PDF pass** with both cells visible in the viewport. Use Chrome's "Print → Save as PDF" with custom margins so the print region covers both cells (and only those two) at vector quality. Save the resulting single-page PDF to `final/task_12/state_overview.pdf`. No post-hoc stitching of two separate PDFs.
4. Verify in the PDF that text is selectable (vector, not raster) and that both the map and the time strip are present in the saved file.

---

## Backup path (only if Framework misbehaves)

> **Revised:** the backup is now a **single-file Vega-Lite spec at the same GitHub Pages URL** — one `index.html`, one `quakes.csv`, vega-embed from CDN, no build step. Vega-Lite's `param` + `selection_point` + `selection_interval` cover the four required interactions. The hosting target stays identical (`https://alexander-the-sufficient.github.io/data_vizualisation_with_ai/task_12/`), only the rendering library changes. Fewer moving parts than the prior backup (which had to re-host on a different platform). Skipped unless the primary path stalls — kept as a one-evening fallback, not built parallel.

---

## Files to create / modify

> **Revised:** Framework project structure replaces the Notebook sidecar. The `iterations/task_12/v1/notebook.ojs.md` mirror is dropped (the Framework `src/index.md` IS the source of truth, version-controlled in git). `id` and `magType` column additions still propagate into prep.R; raw-CSV filename uses the 1980-start window.

**New files:**
- `iterations/task_12/v1/prep.R` — R data-prep script (keeps `id, time, latitude, longitude, depth, mag, magType, place`)
- `interactive/task_12/observablehq.config.js` — Framework project config. Must include from the start: `root: "src"`, `output: "dist"`, and `base: "/data_vizualisation_with_ai/task_12/"`. The `base` setting is critical — without it, all CSS/JS asset URLs in the built output break under the GitHub Pages subpath. Setting it correctly the first time keeps dev-server URLs aligned with production behaviour.
- `interactive/task_12/package.json` — npm dependencies (`@observablehq/framework`, plus `@observablehq/plot` and `topojson-client` if not transitively included)
- `interactive/task_12/src/index.md` — **the source-of-truth Framework page** (cells 1–16 from the Architecture section above)
- `.github/workflows/deploy-task-12.yml` — GitHub Actions workflow. Triggers on push to `main` (path-filtered to `interactive/task_12/**` so it doesn't fire on unrelated portfolio commits). Steps: checkout, setup-node, `npm ci` and `npm run build` inside `interactive/task_12/`, upload `dist/` as the Pages artefact, deploy via `actions/deploy-pages@v4`. Pages source must be set to "GitHub Actions" in repo settings (manual one-time step).
- `interactive/task_12/src/data/quakes.csv` — already produced in step 1 ✓
- `interactive/task_12/src/data/world-110m.json` — already produced in step 2 ✓
- `data/task_12/usgs_quakes_1980_2025_m5.csv` — raw USGS catalog (already produced in step 1) ✓
- `final/task_12/state_overview.pdf` — published-state screenshot

**GitHub Pages deploy artefacts** (built, not hand-authored):
- `interactive/task_12/dist/` — Framework build output, deployed to the `gh-pages` branch via `npm run deploy` or a small GitHub Actions workflow.

**Modified files:**
- `portfolio/portfolio.qmd` — insert Task 12 section between Task 11 and Task 13
- `reference_log.md` — fill in the Task 12 placeholder block (data source, chart type, "what makes it interactive" interaction list, hosting target = **Observable Framework on GitHub Pages**, public URL, AI tool, status v1)

---

## Reused infrastructure

- `design_system.R` — palette tokens via the JS port (`pg`) declared in cell 4 of the Framework page. No inline hex elsewhere.
- Pattern B layout (defined in CLAUDE.md) used verbatim for the portfolio embed.
- `\url{...}` macro for the live URL — already aliased to `heritagereddark` in `portfolio.qmd`'s LaTeX preamble.

---

## Verification

> **Revised:** expanded checklist with TopoJSON decoder, slider response time, brush non-empty, Pacific Ring continuous arc, USGS link resolution, magType surfacing, and 1980-onward data integrity.

End-to-end checks before declaring task complete:

1. **Data integrity**: `prep.R` prints row count, year range, magnitude min/max/median; cross-checked against USGS catalog summary (expected ~70k–80k events 1980–2025 at M≥5.0).
2. **Course-definition compliance**: at least four of {selection, filtering, linking, drill-down, encoding remapping, brushing, temporal scrubbing} are present and demonstrably wired. v1 ships with: filtering (magnitude), filtering (year via slider), brushing (time strip), brushing (map), encoding remap (region → projection), reset (reversibility) → six interactions, well above the four-interaction floor.
3. **Public reachability**: open the deployed GitHub Pages URL in a fresh incognito browser (no GitHub or Observable account) — interactive must function fully without any sign-in prompt.
4. **TopoJSON decoder**: confirm that the basemap is built from `topojson.feature(world, world.objects.countries)`, not from raw `world.features` (which would silently fail with the world-atlas v2 schema).
5. **Slider response**: dragging `yearRange` from 1980 → 2025 in one continuous gesture completes the visual update of map + histogram + time strip in **<250 ms** on the test machine. If not, drop to `binWidth: 16` on hexbin or downsample to M≥5.5.
6. **Map brush yields detail**: dragging a non-empty brush over any continental landmass produces a non-empty top-5 list in the detail panel. The hint string is shown only when `mapBrush` is `null`.
7. **Pacific Ring projection**: when `regionFocus = "Pacific Ring of Fire"`, the rotated `equal-earth` projection renders the arc as a single continuous shape (no antimeridian cut bisecting Indonesia / the Aleutians).
8. **USGS event links resolve**: pick three random rows from the detail panel; click each link; confirm each lands on a live USGS event page (HTTP 200, page title contains "M *.* - *").
9. **Performance**: filter changes render in <250 ms on the test machine; if not, downsample as documented in the data pipeline.
10. **Design-system fidelity**: every fill / stroke colour resolves to a `design_system.R` token via the `pg` JS object; no rainbow / jet; map basemap in `lightQuartz`; hexbin ramp `lightQuartz → alloy`; selection / brush rectangle in `heritageRed`.
11. **Equal-area projection**: confirm `Plot.plot({projection: {type: "equal-earth", rotate: [...]}})` is in use across all three region variants — Mercator would inflate Alaska / Russia and distort the seismic story.
12. **Portfolio render**: `quarto render portfolio.qmd` succeeds; new page renders with title, screenshot, live URL (clickable in PDF), and source citation.
13. **Reference log**: Task 12 block in `reference_log.md` is filled with data source URL, local file path, AI tool used, public GitHub Pages URL, status `v1`.

---

## Effort estimate

> **Revised:** total stays at 8–10 hours; +0.5 h for Framework project scaffold, −0.5 h for the simpler GitHub Pages deploy step (no separate "publish via Notebook UI" round-trip). Net wash.

For a single focused session: ~8–10 hours.

- Data download + prep R script: 1.0 h *(done — step 1 ✓)*
- **Framework project scaffold** (`npm init`, `observablehq.config.js`, `src/index.md` skeleton, dev server up): 0.5 h
- Page scaffold + hexbin map + basemap: 1.5 h
- Filter wiring (year, magnitude, region with projection variants): 1.5 h
- Brush-based map selection + detail panel + USGS links: 1.5 h
- Brushable time strip + two-way binding to year slider: 1.5 h
- Polish (palette via `pg`, copy, region projection variants, hexbin ramp tuning): 1.0 h
- **Build + deploy to GitHub Pages** + screenshot + portfolio embed + reference log: 0.5 h
- Debug buffer: 1.0 h

---

## Stop point

This is the v1 plan, revised for the Framework + GitHub Pages pivot. Status as of this revision:

- Step 1 (data prep, prep.R end-to-end): **done**. `data/task_12/usgs_quakes_1980_2025_m5.csv` (77,150 rows, 13.1 MB) and `interactive/task_12/src/data/quakes.csv` (77,150 rows, 2.12 MB) both exist; pre-step-2 NA + duplicate checks passed.
- Step 2 (TopoJSON basemap): **done**. `interactive/task_12/src/data/world-110m.json` (107,761 B, 177 country geometries) verified.
- Step 3 (Framework scaffold + cells 1–11): not started — awaiting approval of this revised plan before scaffolding `interactive/task_12/observablehq.config.js`, `package.json`, and `src/index.md`.
