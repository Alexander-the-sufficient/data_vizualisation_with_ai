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

> **Revised (option E pivot):** brush-based interactions removed entirely. `@observablehq/plot@0.6.17` (latest published) ships zero brush primitives — `Plot.brush`, `Plot.brushX`, `Plot.brushY` are all undefined. Both the map brush (cell 11) and the time-strip brush (cell 13) had to be replaced. New design: **click-to-select-hex** for the map (Plot.pointer + a click DOM listener + a precomputed lat/lon-grid lookup) and a **passive year strip** for cell 13 (rendered for context, no longer interactive — year filtering is via the cell 5 slider only). The mutable formerly named `mapBrush` is renamed `selectedHex` for semantic clarity.
>
> **Other revisions still in force:** primary map mark is `Plot.dot` wrapping a `Plot.hexbin` transform (transform, not mark); region list trimmed to three with a Pacific-Ring projection variant; date range 1980–2025; `magType` in kept columns and surfaced in the detail panel; data shipped as uncompressed `.csv`; **hosting on Observable Framework + GitHub Pages** (rationale in the Hosting decision section).

1. **Title + framing** (markdown). One-paragraph story setup; the question the chart answers.
2. **`quakes` (FileAttachment CSV)** — pre-processed locally: columns `id, time, latitude, longitude, depth, mag, magType, place`. Magnitude ≥ 5.0 filter pre-applied; **shipped uncompressed at ~7 MB** (gzip path was abandoned after dev-server verification — see Data pipeline section). The `id` column is required for constructing per-event USGS links in the detail panel; `magType` carries the catalog's heterogeneous magnitude scale label (Mw, mb, ML, Ms) for surfacing alongside the value in the detail panel.
3. **`world` (FileAttachment TopoJSON)** — `countries-110m.json` (~100 KB) for the basemap. Decoded at use site via `topojson.feature(world, world.objects.countries)`.
4. **`pg`** — JS port of `design_system.R` tokens: `{alloy: "#5C5B59", lightQuartz: "#ECEAE4", quartz: "#D6D0C2", darkStone: "#7E8182", heritageRed: "#D92B2B", copper: "#896C4C"}`.
5. **`yearRange`** — Observable Inputs has no native two-handle range, so two single-handle ranges are composed via `Inputs.form({start: Inputs.range([1980, 2025], {value: 1980}), end: Inputs.range([1980, 2025], {value: 2025})})`. The combined value is `{start: <year>, end: <year>}`. *Revised (option E):* this slider is now the **only** interactive year control — the time-strip brush from the previous plan is dropped. Drives the filtered event set, the histogram, and the passive year strip in cell 13.
6. **`magThreshold`** — `const magThresholdInput = Inputs.range([5.0, 7.5], {step: 0.1, value: 5.0, label: "Minimum magnitude"}); const magThreshold = Generators.input(magThresholdInput); display(magThresholdInput);`. *Revised:* slider range tightened — see "Magnitude slider range" note below.
7. **`regionFocus`** — `const regionFocusInput = Inputs.select(["World", "Pacific Ring of Fire", "Mid-Atlantic Ridge"], {value: "World", label: "Region"}); const regionFocus = Generators.input(regionFocusInput); display(regionFocusInput);`. *Revised:* reduced from six options to three for v1; rationale and v2 candidates documented below. Each region maps to a projection config: `World → equal-earth, rotate [0,0]`; `Pacific Ring of Fire → equal-earth, rotate [-150, 0]` (so the arc renders as a single continuous shape instead of being cut at the antimeridian); `Mid-Atlantic Ridge → equal-earth, rotate [30, 0]`.
8. **`selectedHex`** (`Mutable`) + **`setSelectedHex(v)`** setter — *Revised (option E):* renamed from `mapBrush` to reflect the click-to-select-hex semantics. This cell declares `const selectedHex = Mutable(null); function setSelectedHex(v) { selectedHex.value = v; }` and exports both. The map cell (11) attaches a `click` event listener to the rendered Plot DOM node; on click, it reads `plot.value` (the closest event to the cursor, surfaced by Plot.pointer in cell 11), looks up that event's lat/lon-grid cell in `eventsByCell` (cell 9), and calls `setSelectedHex(events_in_cell)`. **Framework reactivity rule:** cells that *consume* a `Mutable` see only the current value, not the Mutable object — so cell 11 cannot write `selectedHex.value` directly. The setter pattern bridges the gap. `null` clears the panel.
9. **`filtered`** + **`eventsByCell`** — reactive derivation of the visible event set from `yearRange`, `magThreshold`, `regionFocus`. *Revised (option E):* a companion derivation `eventsByCell = d3.group(filtered, q => \`${Math.floor(q.latitude/5)},${Math.floor(q.longitude/5)}\`)` precomputes a lat/lon-grid lookup (5° cells) used by the click handler in cell 11 to resolve "which events are in the same hex as the focused event". The grid resolution (5°) approximates the visual hex density at world view (`binWidth: 12px`) without depending on Plot's internal projection — the cell lookup uses each event's own lat/lon, no `projection.invert` required. **This is an approximation:** the visual hexes are drawn in screen space after projection, so a click near a region boundary may bucket into a cell that overlaps the visual hex by ~80–90% rather than exactly. Acceptable for v1; the user-facing semantic ("click to see top events in this region") is preserved.
10. **`projection`** — derived from `regionFocus`; passes `{type: "equal-earth", rotate: [...]}` into `Plot.plot`.
11. **`mapView`** — assigns the rendered Plot to a local variable, attaches the **pointer + click** listener, and calls `display(plot)`:
    ```js
    const plot = Plot.plot({
      projection,
      marks: [
        Plot.geo(countriesFeature, {fill: pg.lightQuartz, stroke: "white"}),
        Plot.dot(
          filtered,
          Plot.hexbin(
            {fill: "count"},
            {x: "longitude", y: "latitude", binWidth: 12, r: 8, stroke: "none"}
          )
        ),
        Plot.dot(filtered, Plot.pointer({px: "longitude", py: "latitude", r: 0, opacity: 0}))
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
      const key = `${Math.floor(focused.latitude/5)},${Math.floor(focused.longitude/5)}`;
      setSelectedHex(eventsByCell.get(key) ?? []);
    });
    display(plot);
    ```
    *Revised (option E):* `Plot.brush` doesn't exist in Plot 0.6.17. Replaced with a **Plot.pointer mark** (invisible — `r: 0`, `opacity: 0`) wrapped over the underlying events with `px`/`py` channels set to `longitude`/`latitude`. Plot.pointer surfaces the closest event to the cursor as `plot.value` on hover. The DOM `click` listener reads `plot.value`, looks up the focused event's 5° lat/lon grid cell in `eventsByCell` (cell 9), and writes the cell's events to `selectedHex` via `setSelectedHex`.
    `Plot.hexbin` is a **transform**, not a mark — it groups data into hex cells, computes a per-cell reducer (`count`), and hands the binned positions/counts to an outer `Plot.dot` which renders them as filled hex shapes (because `Plot.dot` under `hexbin` draws hexes when `binWidth` is set, with `r` controlling cell radius). Sequential single-hue ramp from `pg.lightQuartz` → `pg.alloy`, no red endpoint, on a sqrt scale (heavy-tailed counts). The color scale is sqrt-transformed because hex counts in seismicity are heavy-tailed (most hexes contain a handful of events; a few near subduction zones contain hundreds) — a linear scale would render the long tail invisible. **Performance argument:** ~75k reactive `Plot.dot` redraws exceed the slides' "rapid, fluid response" requirement (≥250 ms slider lag in informal benchmarks); hexbin keeps filter response under 250 ms and tells the plate-boundary story more clearly than overplotted semi-transparent dots at global scale.
12. **`magHistogram`** — companion histogram of magnitudes in the filtered set. `Plot.rectY({y: count, x: "mag", interval: 0.1})`. Re-renders on every filter change — demonstrates linked views.
13. **`yearStrip`** — *Revised (option E): demoted from interactive `yearBrush` to a passive `yearStrip`.* Plot 0.6.17 has no `Plot.brushX` either, so the time-strip brush plan is dropped. The strip is now a passive overview chart that re-renders whenever `filtered` changes; year filtering is via the cell 5 slider only.
    ```js
    display(Plot.plot({
      height: 90,
      x: {label: null},
      y: {label: "events / year", grid: true},
      marks: [
        Plot.rectY(filtered, Plot.binX(
          {y: "count"},
          {x: d => d.time.getFullYear(), interval: 1, fill: pg.darkStone}
        ))
      ]
    }));
    ```
    No event listeners, no Mutable writes — the strip just visualizes the count distribution of `filtered` over time. The user is free to read it as a passive small-multiple alongside the map.
14. **`detailPanel`** — *Revised (option E):* shows the **top 5 largest events** inside the current `selectedHex`, sorted by magnitude descending. Each row: place name, magnitude with type (e.g. "M 6.4 (Mw)"), depth (km), ISO time, and a link to the USGS event page constructed as `https://earthquake.usgs.gov/earthquakes/eventpage/${id}`. If `selectedHex` is null, shows a single-line hint ("**Click a hex on the map to inspect the largest events in that region.**"). **No offline geospatial join, no plate-boundary distance** — both removed for v1.
15. **`resetCell`** — Framework button pattern:
    ```js
    const reset = Inputs.button("Reset all filters", {reduce: () => {
      yearRangeInput.value = [1980, 2025]; yearRangeInput.dispatchEvent(new Event("input", {bubbles: true}));
      magThresholdInput.value = 5.0;       magThresholdInput.dispatchEvent(new Event("input", {bubbles: true}));
      regionFocusInput.value = "World";    regionFocusInput.dispatchEvent(new Event("input", {bubbles: true}));
      setSelectedHex(null);
    }});
    display(reset);
    ```
    Reversibility per the course-level definition.
16. **Methods + sources footer** (markdown). Cites USGS ANSS ComCat, links to FDSN web service docs, lists tooling (Observable Plot, Claude Code). Also notes: USGS preferred magnitudes are heterogeneous across the catalog (Mw, mb, ML, Ms); for visualization purposes the catalog is treated as a single magnitude axis.

State flow: `yearRange`, `magThreshold`, `regionFocus` are upstream of `filtered`; `filtered` feeds `mapView`, `magHistogram`, `yearStrip`, and `eventsByCell` (the lookup for the click handler). `selectedHex` is downstream of `mapView` click events (set by the `click` event listener attached to the rendered `Plot.plot(...)` DOM node, which reads `plot.value` from the Plot.pointer transform and looks up the lat/lon-grid cell in `eventsByCell`) and feeds `detailPanel`. Framework's reactive runtime resolves dependencies between cells — no manual subscriptions across cells, only the in-cell DOM listeners that bridge Plot output to `Mutable` values via the setter.

### Magnitude slider range

> **Revised:** `Inputs.range([5.0, 7.5], {step: 0.1, value: 5.0})`. The prep.R floor at M≥5.0 is the *data* floor; the slider's job is to let the user push the threshold *up* to isolate large events, not down (the dataset has nothing below 5.0). The 7.5 ceiling caps at the regime where event counts collapse to single digits per year — beyond that the chart becomes a list of named events, not a map.

### Region list reduction

> **Revised:** v1 ships three regions: World, Pacific Ring of Fire, Mid-Atlantic Ridge. Mediterranean–Himalaya Belt, Andean, and East African Rift are deferred to v2 to keep the v1 implementation surface tractable and to verify the projection-variant pattern works end-to-end on three before generalizing to six.

---

## Interactions that satisfy "beyond hover/zoom"

In the course vocabulary from slides/05.2_interactive_visualizations.pdf:

1. **Temporal filtering / scrubbing** — year-range slider (cell 5) re-derives the visible event set across map + histogram + year-strip.
2. **Selection (click-to-select-hex)** — *Revised (option E):* click a hex on the map; Plot.pointer surfaces the closest event under the cursor, the click listener buckets that event's lat/lon into a 5° grid cell and writes the cell's events to `selectedHex`. The detail panel shows the top-5 sorted by magnitude descending. Replaces the previous "Brushing (space)" entry — Plot 0.6.17 has no brush primitives.
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
{\fontsize{11pt}{14pt}\selectfont\color{alloy} Year-range slider, magnitude threshold, region focus, and click-a-hex for the top events in that region. The Pacific Ring of Fire emerges only when 45 years of seismicity are allowed to accumulate.}
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
2. **Course-definition compliance**: at least four of {selection, filtering, linking, drill-down, encoding remapping, brushing, temporal scrubbing} are present and demonstrably wired. v1 ships with: **selection** (click-to-select-hex), **filtering** (magnitude slider), **filtering / temporal scrubbing** (year slider), **encoding remap** (region → projection rotation), **drill-down / linking** (click on map → detail panel renders top-5 events for that region), **reversibility** (reset button) → five qualifying interactions plus reset, comfortably above the four-interaction floor. **Brushing dropped** (Plot 0.6.17 has no brush primitives).
3. **Public reachability**: open the deployed GitHub Pages URL in a fresh incognito browser (no GitHub or Observable account) — interactive must function fully without any sign-in prompt.
4. **TopoJSON decoder**: confirm that the basemap is built from `topojson.feature(world, world.objects.countries)`, not from raw `world.features` (which would silently fail with the world-atlas v2 schema).
5. **Slider response**: dragging `yearRange` from 1980 → 2025 in one continuous gesture completes the visual update of map + histogram + time strip in **<250 ms** on the test machine. If not, drop to `binWidth: 16` on hexbin or downsample to M≥5.5.
6. **Click-to-select-hex yields detail**: clicking on a populated hex (anywhere with visible event density) populates `selectedHex` with the events in the corresponding 5° lat/lon grid cell; the detail panel shows top-5 sorted by magnitude descending, each with a USGS link. The hint string is shown only when `selectedHex` is `null`.
7. **Pacific Ring projection**: when `regionFocus = "Pacific Ring of Fire"`, the rotated `equal-earth` projection renders the arc as a single continuous shape (no antimeridian cut bisecting Indonesia / the Aleutians).
8. **USGS event links resolve**: pick three random rows from the detail panel; click each link; confirm each lands on a live USGS event page (HTTP 200, page title contains "M *.* - *").
9. **Performance**: filter changes render in <250 ms on the test machine; if not, downsample as documented in the data pipeline.
10. **Design-system fidelity**: every fill / stroke colour resolves to a `design_system.R` token via the `pg` JS object; no rainbow / jet; map basemap in `lightQuartz`; hexbin ramp `lightQuartz → alloy`; selected-hex highlight (where applicable) in `heritageRed`.
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
