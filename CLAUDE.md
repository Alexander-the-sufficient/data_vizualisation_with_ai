# Data Visualization with AI Copilots — Portfolio Workspace

## Project purpose

This directory is the workspace for the graded portfolio in the HSG course *"From Prompt to Plot – Data Visualization with AI Copilots"* (6th semester, instructor: Peter H. Gruber). The single deliverable is a PDF portfolio. This CLAUDE.md is the task anchor derived from [portfolio_task.pdf](portfolio_task.pdf) (dated 2026-04-09) and must be consulted before any work on individual visualizations, critiques, or the write-up sections. Slide content and additional course material will be added later — keep this file focused on the task brief.

## Deliverable format (hard constraints)

- **PDF**, **A4 landscape**
- **15–25 pages** excluding cover and references
- **Max upload size 20 MB** (compress via https://www.ilovepdf.com/compress_pdf if needed)
- **First page: title page with student name**
- **Last page: reference page** containing
  - Sources for all datasets
  - Sources for third-party plots (the "good" and "bad" examples)
  - All software used: AI tools, Python/R packages, web services (Flourish, Datawrapper, etc.)
  - Disclosure of generative-AI use **for each individual graph**
- No program code is submitted
- Submission and deadline: **see Canvas** (not specified in the brief — look this up)

## Grading metric (decreasing order of importance)

Criteria are weighted in the order below. Originality of sources cannot compensate for choosing the wrong chart type.

1. **Appropriateness of the chosen visualization type**
2. **Conformity to the rules of data visualization** (no overclutter, no double encoding, etc.)
3. **Statistical and economic correctness**
4. **Detailed quality** — i.e. visible iterations
5. **Relevance / story**
6. **Consistency of the entire portfolio** (topic, design)
7. **Difficulty and breadth of the portfolio**
8. **Quality and originality of resources**

> **Everything you submit will be graded.** Additional work can *improve or reduce* the grade — weak extras hurt. Do not pad.

## Work and tool rules

- **Work individually.**
- **Generative AI is expected for creating graphs.**
- **Generative AI is NOT permitted for writing the short texts** (the 100–150 word critiques, the optional process description, and the tool/inspiration write-ups must be human-written).
- Any software is allowed: Python, R, Adobe Illustrator, Inkscape, Flourish, Datawrapper, etc. Python/R output may be post-processed in a vector editor.
- Beyond annotations on visualizations, **text is only required where a task explicitly demands it**.

## The 18 portfolio sections (fixed order)

The portfolio must present tasks 1–13 in this sequence. Additional own visualizations go at the end (task 14). Tasks 15–18 follow. **Do not reorder.**

1. **Bad/manipulative visualization** — find one (not from class) + write a **100–150 word critique**.
2. **Improved version of the bad visualization** from task 1.
3. **Particularly good visualization** — find one (not from class) + write a **100–150 word critique**.
4. **Climate-change visualization.**
5. **Black-and-white visualization** — no grey levels at all.
6. **Visualization where color is an important aesthetic.**
7. **Visualization that rigorously maximizes Tufte's data-ink ratio** (look up the concept).
8. **Visualization that is none of**: map, bar chart, scatter plot, pie chart, doughnut chart, line chart, box plot, density plot, histogram, radar chart.
9. **Visualization of textual data.**
10. **Hand-drawn visualization** — plain or graph paper; scan with university photocopier or take a very clean photo.
11. **Data map.**
12. **Interactive visualization** — **must be publicly deployed**; usable in a standard web browser with no install and no account; document with screenshot(s) and the public URL in the portfolio. Apply the strict class definition of "interactive" — **simple hover or zoom does NOT qualify.**
13. **Documented creation process of one visualization** — idea → hand sketch → several versions → final; up to 150 words of explanation optional.
14. *Optional:* additional visualizations by you. Extras only at the end, and only if they add value (see grading note above).
15. **Favorite classical (non-AI) data-viz tools** — free-form text (Python/R packages, software, websites, cheat sheets, books, …).
16. **Favorite AI data-viz tools** — free-form text (models, websites, orchestration software, …).
17. **Favorite inspiration resources** — free-form text (data sources, news outlets, blogs, …).
18. **Reference page** — sources for all data, sources for the "good" and "bad" plots, all tools, generative-AI disclosure per graph.

## Pitfalls to watch

- **Order is enforced** for tasks 1–13. Only task 14 (optional extras) may appear after 13, before tasks 15–18.
- **Do not exceed the page limit** (25 pages of content). Extras are not free — weak filler can lower the grade.
- **Tasks 1 and 3** must NOT reuse any visualization shown in class.
- **Task 12** must have a live public URL before submission (no login, no install). Build with this hosting requirement in mind from the start.
- **Per-graph generative-AI disclosure** belongs on the reference page — track which AI tool produced which graph throughout the process, not at the end.
- **Human-written text only** for the two critiques (tasks 1, 3), the process narrative (task 13), and the three write-ups (tasks 15–17). Do not draft these with AI.
- Task 5's "no grey levels" is strict — black and white only, no tinted greys from anti-aliasing or semi-transparent strokes.
- Task 7 (data-ink ratio) is a design discipline: strip every non-data mark. It is a concept to *apply rigorously*, not just nod at.

## Visualization rules (from lecture slides)

Actionable directives distilled from `slides/*.pdf`. Apply these whenever generating, refining, or critiquing a chart.

### Story & narrative

- **Every chart answers a clear question and tells a story.** If the viewer can't summarize the point in one sentence, the chart has failed — no matter how pretty.
- Decide the story *before* the chart type. The chart type serves the story, not the other way around.
- **Title states the answer**, not the topic: "US raw steel production has been essentially flat since 2021" (answer) beats "US steel production 2021–2025" (topic).
- Sort order, annotations, color emphasis, and framing all exist to make the story land faster. Every design choice either supports the story or is noise.
- No story → don't ship the chart. Find a sharper question or different data.

### Chart-type selection

- Match chart to task before drawing anything: distribution, comparison, part-of-whole, trend, correlation, ranking, spatial.
- Bar chart → categorical comparison, **must start at zero**.
- Line chart → time series / ordered continuous. Zero-baseline is NOT required; show the relevant range honestly.
- Histogram → one continuous variable, **equal-width bins, no gaps** between bars. Label the bin width.
- Pie chart → only for 2–5 categories with intuitive proportions. Otherwise use a stacked bar or a bar chart.
- Scatter plot → two continuous variables. Add a fit line / confidence band only when it adds meaning. Use jitter or hexbin when overplotted.
- Dot plot > bar chart for ranked comparisons (less ink, no forced zero).
- Box plot / density curve → distribution summaries; pair with raw points for small n.
- Avoid: 3D charts, dual-axis charts (unless both axes are separately justified and clearly labeled), novelty chart types.

### Perception & visual encodings

- Encoding-accuracy ranking (most → least accurate): **position on aligned scale > length > angle/slope > area > volume > color hue**. Use the most accurate channel for the most important variable.
- **Never double-encode** a single variable on two channels (e.g. color *and* size for the same value) unless redundancy is deliberately needed for accessibility.
- Use **preattentive attributes** (position, hue, size, orientation, motion) to carry the main message — they are processed in <250 ms.
- Respect Gestalt principles: proximity = grouping, similarity = category, continuity = sequence, figure-ground = salience.
- Area is poorly estimated — avoid area as the primary encoding for precise magnitude comparison.

### Truthfulness (non-negotiable)

- Keep the **lie factor ≈ 1**: visual effect must match the data effect. Any axis truncation, aspect-ratio choice, or transformation that exaggerates differences is deceptive.
- Bar charts: **axis starts at zero**, always (ratio scale).
- Label every transformation explicitly (log scale, % change, index, moving average, z-score, …).
- Show uncertainty where it exists: error bars, confidence bands, shaded intervals. Do not hide it.
- Dual axes are deception-prone; avoid unless both scales are independently meaningful and labeled.
- Spurious precision in tick labels is a red flag — round appropriately.

### Data completeness (no missing data, no perceived gaps)

- **Every data point in the series must be visibly rendered.** A chart that *looks* like it has gaps is perceived as missing data even when the underlying values are all present. Near-zero values that render invisibly count as missing perceptually.
- Before finalizing any chart, verify: (1) every expected year / category / bin is present in the data, and (2) every point produces a visible mark in the render. Check the output PDF, not just the dataframe.
- Fixes when near-zero or tiny values render invisibly:
  1. **Overlay a small point marker** (`geom_point`) at every data point so no bar/line/column can disappear. Preferred — preserves magnitudes exactly.
  2. **Thicken the zero baseline** so near-zero bars visually sit on a continuous line rather than looking like gaps.
  3. **Minimum visible bar height** — last resort only, and only with caption disclosure, since it distorts magnitude.
- If data is *genuinely* missing (e.g. no observations for certain years), either interpolate/smooth **with explicit disclosure** in the caption (note the method: linear interpolation, LOESS, moving average, …) or pick a different chart / different time window that avoids the gap. **Do not ship a chart with unexplained visual gaps.**

### Data-ink ratio / clutter (Tufte)

- **Maximize data-ink, minimize non-data-ink.** Every non-data mark must earn its place.
- Remove: chart borders, heavy gridlines, 3D effects, shadows, gradients, decorative icons, redundant legends, duplicate labels.
- Gridlines are acceptable only if subtle and directly aid reading.
- Prefer **direct labels on lines/bars** over legends when feasible.
- Tick marks on round numbers (1, 2, 5, 10, 25, 50, 100, …); aim for 4–8 ticks per axis.

### Color

- Pick the palette type to match the variable type **before** choosing hues:
  - **Qualitative** (categorical, unordered) → distinct hues, max 5–7 categories.
  - **Sequential** (ordered magnitude) → single hue, increasing saturation/lightness.
  - **Diverging** (bipolar around a neutral midpoint) → two hues meeting at neutral.
- Use **perceptually uniform** colormaps (viridis, cividis, magma). **Never use rainbow/jet** — perceptually non-uniform and colorblind-unfriendly.
- Test palettes under **color-blindness simulation** (deuteranopia / protanopia). Red-green alone is unusable for ~8% of viewers.
- A good palette survives a **grayscale test** — if it collapses, the encoding is too weak.
- **Color consistency across the portfolio**: the same category gets the same color on every chart.

### Data maps

- **Choropleth maps must be normalized** (per capita, per km², % of population, …). Never choropleth raw counts.
- Pick the projection to match the story: **equal-area for area-based comparisons**, conformal for shape. Avoid Mercator for area comparisons (high-latitude distortion).
- Large regions dominate unfairly — consider **grid/hex maps or cartograms** when geographic area is not the variable of interest.
- Use **dot-distribution** for point-level data, **proportional symbols** when magnitude + location both matter, **heat/density maps** for concentration.
- Include scale bar, north arrow (if relevant), clear color legend, and data source on every map.

### Standard tasks — quick pointers

- **Ranking**: horizontal bars, sorted descending; category labels left-aligned.
- **Parts-of-whole**: stacked bar > pie for >5 categories or similar-sized slices; treemap for hierarchical parts.
- **Time series**: line; multiple series get distinct colors and direct labels; reorder to avoid crossings where possible.
- **Correlation**: scatter; for many pairs, correlation heatmap with diverging palette.
- **Distribution**: histogram, density, or box plot; overlay raw points for small n.

### Interactive visualizations (task 12)

- Apply **Shneiderman's mantra**: *overview first → zoom and filter → details on demand*. Do not open with details.
- Each interaction must serve a real analytical question — selection, filtering, aggregation, reordering, linking, drill-down, temporal scrubbing. **Hover and zoom alone do NOT count as interactive** in this course.
- Response time <100 ms feels instantaneous; lag kills the experience.
- Linked views: selection in one view updates all others.
- Actions must be reversible (undo / reset).
- Must be publicly deployed: no login, no install, works in a standard browser.

### Annotation & labeling

- **Title states the message**, not the chart type. One sentence.
- Axis labels include units.
- Direct-label data series where space allows.
- Annotate outliers, key events, and the one or two points the reader must see.
- Every chart needs a visible **data source** (bottom of chart or on the reference page).

### Hand-drawn viz (task 10)

- Pick paper type deliberately (plain vs. graph) — graph paper enforces scale; plain paper is looser.
- Fix the scale *before* drawing: units per square, axis range ending at a round number above the max.
- Match aspect ratio to the story: landscape for gradual change, portrait for large differences.
- Pick the color scheme before the pen touches paper; don't improvise hues.

### Workflow & iteration

- Workflow is **sketch → iterate → proof**. A sketch promoted to proof without revision inherits all its approximations.
- Every submitted chart should show evidence of deliberate choice: axis range, palette, chart type, annotation. If you can't defend a choice, change it.
- Consistency across the portfolio (topic, palette, typography, chart style) is graded — treat it as a single document, not 13+ isolated charts.

### Instructor emphasis (what gets graded hardest)

Gruber repeats and bolds these — treat as priorities:

1. **Data-ink ratio** (Tufte) — ruthlessly remove non-data ink.
2. **Lie factor** — visual effect ≈ data effect. No axis truncation on bars, no misleading aspect ratios.
3. **Chart-type appropriateness** — wrong chart for the task is the #1 grading criterion.
4. **No double encoding.**
5. **Choropleth normalization** — never raw counts on maps.
6. **Zero baseline for bar charts** (ratio scale). Non-negotiable.
7. **Preattentive attributes** used deliberately for the main message.
8. **No 3D, no dual-axis, no chartjunk.**
9. **Color-blindness-safe, perceptually uniform palettes.**
10. **Iteration visible** — sketch → refine → proof. "Done when revised."
11. **Defensibility** — every design choice must have a reason.
12. **Story clarity** — grading criterion #5. Every chart answers a specific question; the title states the answer, not the topic.

## Workflow (Claude Code operating rules)

### Repo layout

- `data/` — raw data sources (CSV, JSON, geojson, …)
- `iterations/<task_n>/v1…vN/` — versioned drafts per task. Iteration is graded (criterion #4), so every meaningful revision gets a new `vN`.
- `final/` — shipping assets (PDF or SVG — see Export format rule) pulled into the portfolio.
- `interactive/` — task 12 deployable (Observable notebook source, or static HTML + assets).
- `portfolio/` — Quarto source + the assembled A4-landscape PDF.

### Design system

Palette, typography, and chart defaults live in [design_system.md](design_system.md). **Every chart consumes tokens from there. No inline color constants.**

**Partners Group palette (April 2026 redesign, v4 — actual brand fidelity).** Hex values pulled directly from the production stylesheet at `partnersgroup.com/en/stylesheets/shared/variables.css`. Earlier portfolio attempts were *inspired by* the brand but never used the real hex codes; v4 aligns 1:1 with the company's site CSS. The system is dominated by warm-neutral grays and beiges (the quartz / stone families). IBM Plex Sans is the open-source stand-in for the brand's actual face (Neue Haas Grotesk).

**Color discipline (rule, not aesthetic preference): red and black are accents only, never primary chart fills.** The palette is wide enough that this constraint never forces a compromise. From v4 onward:

- **Heritage Red `#D92B2B`** is reserved for source-URL links, single callouts marking *the moment* of a chart's story, and rare highlights of *extreme* data points (e.g. the SNB trough, the four worst glacier years). Never a fill for more than ~10% of the chart's ink.
- **Onyx `#000000`** is reserved for page-level title text and the rare structural element where black needs to recede (e.g. Sankey strata when given an outline). Never a default fill for body text or chart marks.
- **Everything else** uses the warm-neutral ramp: alloy `#5C5B59` (warm charcoal — workhorse default), dark_stone `#7E8182` (warm gray), dark_quartz `#ACA39A` (taupe), medium_quartz `#BAB3AB` (light taupe), quartz `#D6D0C2` (warm sand), light_quartz `#ECEAE4` (cream). Plus copper `#896C4C` (warm bronze) as the only colored accent — the qualitative companion when a single non-neutral hue is needed for the chart's story.

The point isn't "avoid red" — it's "let red mean something." When red appears, the reader should know it was deliberate.

Token names from the legacy system (`heritage_red`, `copper`, `onyx`, `alloy`, the `_quartz` and `_stone` families) are stable handles — chart scripts run unchanged across palette migrations. Hex values changed; names did not.

### Reference log

Every AI-assisted graph gets a [reference_log.md](reference_log.md) entry **at the moment of creation**, not at submission. Task 18 (the reference page) is assembled directly from this file.

### Default tech stack (locked)

- **Static charts**: R + ggplot2 (primary). Tidyverse for data wrangling. `showtext` to load Inter / IBM Plex Sans. Post-process in Inkscape / Illustrator where needed.
- **Interactive (task 12)**: Observable notebook — free, public URL, no viewer account required. Fallback: static HTML on Vercel / Netlify with Vega-Lite or R `htmlwidgets` (plotly / leaflet).
- **PDF assembly**: Quarto in A4 landscape.
- Do not introduce a new library without stating the need in plain English first.

### Export format (hard rule — vector only)

Every visualization in the final PDF must retain quality under zoom — that means **vector format (PDF or SVG), never PNG or JPG** for anything code- or tool-generated.

- **R + ggplot2**: `ggsave("chart.pdf", plot, width = ..., height = ..., device = cairo_pdf)`. `cairo_pdf` is required for correct embedding of Inter / IBM Plex Sans loaded via `showtext`.
- **Python + matplotlib**: `plt.savefig("chart.pdf")` or `plt.savefig("chart.svg")`.
- **Web tools** (Datawrapper, Flourish, Observable, Vega-Lite): export as SVG or PDF, not PNG.
- **Inkscape / Illustrator**: save as PDF or SVG after post-processing.

**Exceptions (raster permitted)**:
- Task 10 (hand-drawn): scan at ≥ 600 DPI.
- Task 12 (interactive): screenshots at 2× / Retina scale.
- Tasks 1 and 3 (third-party good/bad examples): use whatever the source provides; prefer the highest-resolution version available.

### Portfolio page layouts (Quarto)

Two page patterns are established in [portfolio/portfolio.qmd](portfolio/portfolio.qmd). Reuse them verbatim for consistency (grading criterion #6).

**Pattern A — third-party image + critique side-by-side** (tasks 1, 3, and any future "find a viz + critique" task):
- Two LaTeX `minipage`s in a raw-LaTeX block: image left (`0.52\textwidth`), critique right (`0.44\textwidth`), `\hfill` between.
- Image: `\includegraphics[width=\linewidth,height=0.78\textheight,keepaspectratio]{...}`. The height cap prevents portrait images from eating the page.
- Source line directly under the image: `{\footnotesize\color{darkstone}\itshape Source: \url{...}}`.
- Critique text flows as normal markdown between the opening and closing raw-LaTeX blocks.

**Pattern B — own chart, centered** (tasks 2, 4+, anything the student produces):
- Title (14 pt bold Onyx) and subtitle (11 pt Alloy) in a centered raw-LaTeX block above the image.
- Chart image centered at ~85% width: `![](path.pdf){fig-align="center" width="85%"}`.
- Source line centered below in the same `{\footnotesize\color{darkstone}\itshape Source: \url{...}}` style.

**Separation of concerns (hard rule)**
- Title, subtitle, and source citation live in **Quarto**, not in the R chart.
- The R chart renders only: bars/marks, axes, axis labels. No `title`, `subtitle`, or `caption` in `labs()`.
- Why: the chart asset stays reusable, and typography/citation text can be edited without regenerating the PDF.

**URL style**
- Always wrap URLs in `\url{...}`. Renders deep crimson (`heritagereddark` `#830011` — the brand's hover variant, more readable at small text size than the brighter primary red), stays clickable in the final PDF, line-wraps cleanly.

**Pagination**
- Every task section starts with `# Task N — <title>` and ends with `\newpage` before the next task.

### Hard guardrails

1. **Every chart's data comes from a downloaded source file. No hand-typed numbers, ever.**
   - Before writing any chart code, locate and download the authoritative source file (CSV / XLSX / JSON / API response) into `data/task_<n>/`. The chart script must read from that file at runtime.
   - **Never** transcribe numbers from a webpage, PDF, news article, or memory into a `tribble()`, `c(...)`, or any in-script literal. If the source publishes only an HTML table, scrape it to a CSV first and commit the CSV — the *script reads the CSV*. If the source is a public API, save the raw API response (JSON) to `data/task_<n>/` and read from disk; do not bake API values into the script.
   - **Annotation overlays are exempt** — `tribble()` is OK for label text, event names, callout positions, and other editorial overlays that exist for visual storytelling. Any *measured value* (counts, amounts, rates, percentages, dates of observations) must come from the file.
   - When the source file changes, the chart updates with it — that's the whole point.
   - **How to download**: `curl -sL <url> -o data/task_<n>/<file>` is the default. WebSearch / WebFetch help locate the URL; the actual download is a Bash one-liner. No "Chrome MCP" is wired up in this environment despite earlier mentions — use curl + the Treasury / Eurostat / UN / World Bank / Our World in Data / GLAMOS / etc. open-data endpoints directly.
   - **`reference_log.md` must list the exact local file path** plus the URL it came from. The `Status: vN` line is incomplete without this.
2. **Claude does NOT draft the written text** for tasks 1 (critique), 3 (critique), 13 (process note), 15, 16, 17 (tool / inspiration write-ups). Outline bullets only on explicit request. Human-written text is mandated by the brief.
3. **Claude logs AI use in `reference_log.md` at graph-creation time** — tool / model + one-line prompt summary. Not retroactively.
4. **Every chart is saved versioned** (`v1.pdf`, `v2.pdf`, …). Never overwrite a previous version — iteration visibility is graded.

### Pre-submit checklist

Before moving any chart into `final/`, verify against the 11 instructor-emphasis rules listed above (lie factor, zero-baseline for bars, no double encoding, grayscale + colorblind-safe palette, choropleth normalization, data source visible, no chartjunk, etc.). Also verify the export format: every chart in `final/` is PDF or SVG (exceptions: hand-drawn scan, interactive screenshot, third-party images). If any check fails, fix or explicitly justify in `reference_log.md` notes.

### Task 12 deployment (live URL)

The interactive at https://alexander-the-sufficient.github.io/data_vizualisation_with_ai/task_12/ is **not** redeployed automatically when you save files locally. The dev server (`npm run dev` in `interactive/task_12/`) is for local previews only — the live site runs from GitHub Pages and only refreshes after a commit + push to `main`.

**To make local changes go live:**

1. Stage only the v11-relevant files — never `git add -A`:
   - `interactive/task_12/src/**` (the project source)
   - `interactive/task_12/src/data/quakes.csv` (only if data was regenerated)
   - `iterations/task_12/v<N>/**` (the iteration audit folder)
   - `reference_log.md` (the v<N> entry)
2. Commit with the project's "task 12 vN: <imperative summary>" style (see `git log --oneline`).
3. `git push origin main`.
4. The `.github/workflows/deploy-task-12.yml` Action triggers on path-filtered pushes to `main` matching `interactive/task_12/**`. It runs `observable build`, wraps `dist/` inside `_site/task_12/` so the artifact lands at the `/task_12/` subpath, and deploys to Pages. Typical end-to-end is ~2 minutes; check `gh run list --workflow=deploy-task-12.yml --limit 1` for status.
5. Hard-reload the live URL (cache-busted screenshot embeds in the portfolio PDF use a `?v=N` query string when needed).

**What does NOT trigger a redeploy**: edits outside `interactive/task_12/**` and the workflow file itself (e.g. `reference_log.md` only, `iterations/task_12/v<N>/**` only). Those still belong in the same commit for traceability, but you also need at least one source file change to trigger the deploy. If a deploy is needed without source changes, run `gh workflow run deploy-task-12.yml` to fire it manually.

**Cadence**: every meaningfully-shippable iteration of task 12 (each `v<N>`) gets its own commit and push so the public URL stays current with the iteration history. Don't batch multiple iterations into one commit — iteration visibility is graded (criterion #4) and a single commit collapses the history.

## Open items (to revisit)

- Canvas submission deadline (not in the task brief).
- Slide context from lectures — to be added later by the user; integrate into this CLAUDE.md or a sibling file once provided.
- R `theme_pg()` + `scale_*_pg()` helper — build when the first chart lands.
