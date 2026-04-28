# Design system helpers for portfolio charts.
#
# Partners Group palette (April 2026 redesign, v4 — actual brand fidelity).
# Hex values pulled from the production stylesheet at
# `partnersgroup.com/en/stylesheets/shared/variables.css`. Earlier portfolio
# attempts were *inspired by* the brand but never used the real hex codes;
# this revision aligns 1:1 with the company's current site CSS.
#
# Colour discipline (rule, not aesthetic preference): the palette is wide
# enough that **red and black are accents only**, never primary chart fills.
# Earlier portfolio charts leaned on the pairing for emphasis and the result
# read as alarmist — red carries danger semantics that don't always fit the
# data. From v4 onward:
#   * Heritage Red `#D92B2B` is reserved for source-URL links, single
#     callouts ("the moment"), and rare highlights of *extreme* data points
#     (e.g. the SNB trough, the four worst glacier years). Never a fill for
#     more than ~10% of the chart's ink.
#   * Onyx `#000000` is reserved for the page-level title, structural
#     stratum bars where black needs to recede (Sankey), and one
#     semantically-loaded fill (Coal in the energy mix — coal IS black).
#   * Everything else uses the warm-neutral ramp: alloy / dark_stone /
#     dark_quartz / medium_quartz / copper-bronze. These are the "grays
#     and beiges" the brand actually leads with.
#
# Token names from the legacy system (heritage_red, copper, onyx, alloy,
# the _quartz and _stone families) are stable handles — chart scripts run
# unchanged across palette migrations. design_system.md describes each
# token's current visual identity and the role it plays in the system.
#
# Typography: chart-internal text falls back to PDF-native Helvetica until
# cairo + showtext are wired up locally (XQuartz install). Page-level text
# (titles, subtitles, captions, body) is set to IBM Plex Sans by Quarto at
# PDF assembly time. Partners Group's actual brand face is Neue Haas
# Grotesk (Adobe Typekit); IBM Plex Sans is the open-source stand-in.

pg_palette <- list(
  # Primary accent — bright red. Used for links, single callouts, extreme
  # highlights. Never as a fill color for more than ~10% of the chart's ink.
  heritage_red     = "#D92B2B",  # PG --heritage-red (logo, primary links)
  heritage_red_dk  = "#830011",  # PG --heritage-red-hover (deeper crimson)

  # Text / structural marks. Onyx is pure black per the PG site; reserve
  # for titles + structural stratum bars + the one semantically-black fill
  # (coal). Alloy is the warm charcoal that does most of the work.
  onyx             = "#000000",  # PG --onyx, --dark
  alloy            = "#5C5B59",  # PG --alloy (body text, warm charcoal)

  # Secondary accent — warm bronze. The only non-red, non-neutral hue in
  # the palette. Used as the "qualitative companion" in categorical charts
  # and as the highlight color when red would be too alarming.
  copper           = "#896C4C",  # PG --copper (warm bronze)

  # Quartz family — warm beige neutrals (the "in-between" colors that
  # should dominate analytical content). Sequential ramp from light cream
  # at #ECEAE4 down to deeper taupe at #ACA39A.
  light_quartz     = "#ECEAE4",  # PG --light-quartz (soft cream panel fill)
  quartz           = "#D6D0C2",  # PG --quartz (warm sand, hero gradient base)
  medium_quartz    = "#BAB3AB",  # PG --medium-quartz (muted taupe)
  dark_quartz      = "#ACA39A",  # PG --dark-quartz (deeper taupe)

  # Stone family — neutral warm-cool grays. Slightly cooler than the
  # quartz family; used where a calm, non-warm neutral is wanted.
  stone            = "#C4C6C1",  # PG --stone (cool-warm gray, dividers)
  medium_stone     = "#A4A4A5",  # PG --medium-stone (mid neutral gray)
  dark_stone       = "#7E8182",  # PG --dark-stone (secondary text)

  # Background utilities
  grey             = "#F6F6F6",  # PG --grey (page background utility)
  white            = "#FFFFFF"
)

# Qualitative palette (max 5) — for categorical / unordered variables.
# Red and black are deliberately excluded; this palette never produces a
# "thick red bar" or "wall of black." Five distinguishable hues across the
# warm-neutral and bronze accent space. Lightness gaps (Lab L*): alloy 37 →
# copper 47 → dark_stone 53 → dark_quartz 68 → light_quartz 92. The
# copper-to-dark_stone gap is small in lightness but the warm/cool hue
# distinction keeps them separable in colour rendering. A truly
# colourblind-safe sequential ramp is available via pg_seq_palette below.
pg_qual_palette <- c(
  pg_palette$alloy,        # #5C5B59 — warm charcoal (darkest)
  pg_palette$copper,       # #896C4C — warm bronze (the accent hue)
  pg_palette$dark_stone,   # #7E8182 — neutral warm gray
  pg_palette$dark_quartz,  # #ACA39A — deeper taupe
  pg_palette$medium_quartz # #BAB3AB — light taupe
)

# Sequential palette — light cream at the low end up to warm charcoal at
# the high end. Avoids the red endpoint that the legacy ramp had — keeps
# magnitude encoding in lightness only, no danger semantics.
pg_seq_palette <- c(
  pg_palette$light_quartz, # #ECEAE4
  pg_palette$quartz,       # #D6D0C2
  pg_palette$medium_quartz,# #BAB3AB
  pg_palette$dark_quartz,  # #ACA39A
  pg_palette$dark_stone,   # #7E8182
  pg_palette$alloy         # #5C5B59
)

# ggplot2 theme. Default base_family = "IBM Plex Sans"; chart scripts
# override with chart_family <- "" until cairo + showtext are local.
theme_pg <- function(base_size = 11, base_family = "IBM Plex Sans") {
  ggplot2::theme_minimal(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      plot.title             = ggplot2::element_text(size = 14, face = "bold",
                                                     color = pg_palette$onyx,
                                                     margin = ggplot2::margin(b = 6)),
      plot.subtitle          = ggplot2::element_text(size = 11,
                                                     color = pg_palette$alloy,
                                                     margin = ggplot2::margin(b = 12)),
      plot.caption           = ggplot2::element_text(size = 8,
                                                     color = pg_palette$dark_stone,
                                                     hjust = 0,
                                                     margin = ggplot2::margin(t = 12)),
      plot.caption.position  = "plot",
      plot.title.position    = "plot",
      axis.title             = ggplot2::element_text(size = 11, color = pg_palette$alloy),
      axis.title.y           = ggplot2::element_text(margin = ggplot2::margin(r = 8)),
      axis.text              = ggplot2::element_text(size = 10, color = pg_palette$alloy),
      axis.line.x            = ggplot2::element_line(color = pg_palette$alloy, linewidth = 0.3),
      axis.ticks             = ggplot2::element_blank(),
      panel.grid.major.y     = ggplot2::element_line(color = pg_palette$light_quartz,
                                                     linewidth = 0.3),
      panel.grid.major.x     = ggplot2::element_blank(),
      panel.grid.minor       = ggplot2::element_blank(),
      plot.background        = ggplot2::element_rect(fill = "white", color = NA),
      panel.background       = ggplot2::element_rect(fill = "white", color = NA)
    )
}
