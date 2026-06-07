# Design System — Portfolio

Shared palette, typography, and chart defaults for every visualization in this portfolio. Grading criterion #6 (consistency of the entire portfolio) depends on this. **Every chart consumes tokens from here. No inline color constants.**

## Source

Partners Group palette (April 2026 redesign, **v4 — actual brand fidelity**). Hex values pulled directly from the production stylesheet at `partnersgroup.com/en/stylesheets/shared/variables.css`. Earlier portfolio attempts (Editorial Earth in v3, Cool Slate in v2, Editorial Red in v1) were *inspired by* the brand but never used the real hex codes. v4 aligns 1:1 with the company's current site CSS.

## Color discipline (rule, not aesthetic preference)

The palette is intentionally wide so that **red and black are accents only, never primary chart fills**. Earlier portfolio drafts used Heritage Red and Onyx as default fills and the result read alarmist — red carries danger semantics that don't always fit the data, and large black blocks dominate the page.

From v4 onward:

- **Heritage Red `#D92B2B`** is reserved for: source-URL links, a single callout marking *the moment* of a chart's story, and rare highlights of *extreme* data points (e.g. the SNB trough, the four worst glacier years). Never a fill for more than ~10% of the chart's ink.
- **Onyx `#000000`** is reserved for: page-level title text, structural stratum bars where black needs to recede (Sankey), and one semantically-loaded fill (Coal in the energy mix — coal is genuinely black). Never use as the default for body text or chart marks.
- **Everything else** uses the warm-neutral ramp: alloy / dark_stone / dark_quartz / medium_quartz / copper-bronze. These are the "grays and beiges" the brand actually leads with on the website.

The point isn't "avoid red" — it's "let red mean something." When red appears, the reader should know it was deliberate.

## Primary palette

| Token | Hex | RGB | Role |
|---|---|---|---|
| Heritage Red | `#D92B2B` | 217, 43, 43 | **Bright red — accent only**. Source URLs, single callouts, extreme-value highlights. Never a default fill. |
| Heritage Red Dark | `#830011` | 131, 0, 17 | Deeper crimson — link hover state, emphasised text in the rare cases red is doubled. |
| Onyx | `#000000` | 0, 0, 0 | Pure black — accent only. Page titles, structural Sankey strata, the single semantic Coal fill. |
| Alloy | `#5C5B59` | 92, 91, 89 | **Warm charcoal — workhorse neutral**. Body text, axis lines, the default dark fill on bars and lines. |
| Copper | `#896C4C` | 137, 108, 76 | **Warm bronze — secondary accent / qualitative companion**. The only non-red, non-neutral hue. |
| Light Quartz | `#ECEAE4` | 236, 234, 228 | Soft cream — gridlines, panel washes, low-emphasis fill. |
| Quartz | `#D6D0C2` | 214, 208, 194 | Warm sand — hero-area gradient base, callout fills. |
| Medium Quartz | `#BAB3AB` | 186, 179, 171 | Muted taupe — categorical neutral, light fill. |
| Dark Quartz | `#ACA39A` | 172, 163, 154 | Deeper taupe — categorical neutral. |
| Stone | `#C4C6C1` | 196, 198, 193 | Cool-warm gray — dividers, subtle backgrounds. |
| Medium Stone | `#A4A4A5` | 164, 164, 165 | Mid neutral gray. |
| Dark Stone | `#7E8182` | 126, 129, 130 | Warm gray — secondary text, source-line caption color. |
| Grey | `#F6F6F6` | 246, 246, 246 | Page-background utility. |
| White | `#FFFFFF` | 255, 255, 255 | Page background. |

## Qualitative palette (max 5 categories)

For categorical / unordered variables. **Red and black deliberately excluded** so this palette never produces a "thick red bar" or "wall of black."

1. Alloy — `#5C5B59` *(warm charcoal — darkest)*
2. Copper — `#896C4C` *(warm bronze — the accent hue)*
3. Dark Stone — `#7E8182` *(neutral warm gray)*
4. Dark Quartz — `#ACA39A` *(deeper taupe)*
5. Medium Quartz — `#BAB3AB` *(light taupe)*

Lightness gaps (Lab L*): 37 → 47 → 53 → 68 → 73. The copper-to-dark_stone gap is small in lightness but the warm/cool hue distinction keeps them separable in color rendering. For grayscale-strict charts use `pg_seq_palette` instead.

If more than 5 categories are genuinely needed, reconsider the chart — the reader can't distinguish more anyway. If a 5-category encoding has one category that is *semantically loaded* (e.g. Coal → black), substituting the loaded color for one of the slots above is allowed; document the swap in the chart's notes.

## Sequential palette

For ordered / magnitude variables (e.g. choropleth with continuous data). Pure lightness ramp from cream up to warm charcoal — no red endpoint, no danger semantics.

`#ECEAE4` (Light Quartz) → `#D6D0C2` (Quartz) → `#BAB3AB` (Medium Quartz) → `#ACA39A` (Dark Quartz) → `#7E8182` (Dark Stone) → `#5C5B59` (Alloy)

## Diverging palette

For bipolar data (gains/losses, above/below average). The brand has no natural diverging axis (only one accent hue), so use **copper ↔ light_quartz ↔ alloy**: warm bronze on one end, cream midpoint, warm charcoal on the other. If the data has a *truly extreme* pole that warrants alarm semantics (e.g. catastrophic-loss vs gain), heritage_red can replace the warm-charcoal end — but flag the choice in the chart's notes.

`#896C4C` (Copper) ↔ `#ECEAE4` (Light Quartz, midpoint) ↔ `#5C5B59` (Alloy)

## Typography

**Page-level text (Quarto-rendered):**
- **Headlines / body / captions / source lines**: IBM Plex Sans (Regular 400, Medium 500, Bold 700). Open-source stand-in for the brand's actual face — Neue Haas Grotesk (Adobe Typekit kit `zwy1nua`).
- **Optional editorial flourish**: IBM Plex Serif for portfolio cover or section dividers — not required.
- **Code / numeric tabular**: IBM Plex Mono — not currently used.

Install via Homebrew:
```
brew install --cask font-ibm-plex-sans font-ibm-plex-serif font-ibm-plex-mono
```

**Chart-internal text:**
- Default `base_family` in `theme_pg()` is `"IBM Plex Sans"`, but each chart script overrides with `chart_family <- ""` (PDF-native Helvetica fallback) until cairo + showtext are wired up locally.
- To upgrade to true IBM Plex Sans rendering inside charts: install XQuartz (`brew install --cask xquartz`), then in scripts set `chart_family <- "IBM Plex Sans"` + `device = cairo_pdf` in `ggsave`.

## Chart defaults

- **Title**: 14 pt, weight 700, color Onyx `#000000`. One sentence — states the message, not the chart type.
- **Subtitle / axis titles**: 11 pt, weight 500, color Alloy `#5C5B59`.
- **Tick labels**: 10 pt, weight 400, color Alloy `#5C5B59`.
- **Data source caption**: 8 pt, color Dark Stone `#7E8182`.
- **Axis lines**: Alloy `#5C5B59`, 0.3 pt.
- **Gridlines**: Light Quartz `#ECEAE4`, only where they aid reading. Default off; turn on for dense numeric charts.
- **Default chart fill (single-series)**: Alloy `#5C5B59`. Not Onyx.
- **Highlight color (small subset of marks)**: Copper `#896C4C` for soft emphasis, Heritage Red `#D92B2B` for *extreme* values where danger semantics fit (worst-case data, alarm).
- **Direct labels on bars / lines preferred over legends** whenever feasible.
- **Background**: White `#FFFFFF`. Use Light Quartz `#ECEAE4` only for panel fills or callout boxes.
- **Aspect ratio**: 16:9 landscape default (matches A4-landscape pages). Portrait only when the data demands it.

## Accessibility contract

Every palette used must pass, in order:

1. **Grayscale test** — if two categories collapse to the same gray, reject.
2. **Deuteranopia simulation** — red-green distinguishability.
3. **Protanopia simulation** — alternative red-green deficiency.

The qualitative palette above passes the grayscale test (lightness gaps ≥ 5 between every adjacent pair) and is colorblind-safe by construction (no red-green pairing). The sequential palette is a pure lightness ramp and passes trivially. The diverging palette mixes one warm-cool axis (copper ↔ alloy) — verify per-chart since adjacency depends on the data distribution.

## ggplot2 helpers (`design_system.R`)

- `pg_palette` — named list of every token.
- `pg_qual_palette` — vector of 5 qualitative colors (red/black excluded).
- `pg_seq_palette` — vector of 6 sequential colors.
- `theme_pg(base_size, base_family)` — ggplot2 theme applying the chart defaults above.

Chart scripts should always `source("design_system.R")` and pull tokens from the palette object. No inline hex constants outside this file.
