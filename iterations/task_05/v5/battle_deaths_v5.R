# Task 5 v5 — Global battle-related deaths, 1989-2024 (B&W, named peaks).
# v5 changes vs v4 — ANNOTATION LAYER ONLY (line, axes, theme unchanged):
#   * v4 collapsed the story into a single "2021-2024: the four deadliest
#     years on record" callout. The user found the older "named peaks" idea
#     more interesting (each spike labelled with the war behind it) — but the
#     OLD named labels were factually wrong (e.g. a "Gulf War" callout on the
#     early-90s peak, which was actually the Ethiopian civil war; and a
#     "top-four" claim attached to 2014, which is #5, not top-four).
#   * v5 restores named-conflict callouts at the three escalating peaks, using
#     CORRECT, fact-checked drivers, and drops the wrong claims entirely:
#       - 1999-2000 peak (1999 = 81,047 / 2000 = 78,671) -> "Eritrea-Ethiopia war"
#       - 2014 peak (115,972)                            -> "Syrian civil war & rise of IS"
#       - 2022 peak (276,893, the all-time high in the   -> "Tigray (Ethiopia) + Ukraine"
#         1989-2024 record)
#   * No "Gulf War" callout (the Gulf War was 1991, not 1990; the early-90s
#     peak was the Ethiopian civil war). That peak is left unlabelled.
#   * No "top-four" wording on 2014 (it is the 5th-deadliest year, not top-4).
#   * Each callout: a small WHITE-filled circle marker with a black border on
#     the peak point + a black leader line + a black label naming the conflict
#     (with the year). The escalating sequence is the story: each named war is
#     deadlier than the last, peaking in 2022.
# Story: three successive conflict surges, each deadlier than the last —
#   Eritrea-Ethiopia (1999-2000), Syria/IS (2014), and Tigray + Ukraine (2022),
#   the deadliest year in 35 years of UCDP records.
# Strict black-and-white aesthetic: only PURE BLACK on PURE WHITE.
#   No greys, no semi-transparent fills, no grey gridlines, no grey text.
#
# Source: UCDP (2025). Battle-Related Deaths Dataset, version 25.1.
#   Uppsala Conflict Data Program. https://ucdp.uu.se/downloads/

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
})

# Strict B&W theme — every chart element forced to pure black on white.
# Does NOT source design_system.R, since that palette includes greys.
chart_family <- ""

theme_bw_strict <- function(base_size = 11, base_family = "") {
  ggplot2::theme_minimal(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      plot.title             = ggplot2::element_blank(),
      plot.subtitle          = ggplot2::element_blank(),
      plot.caption           = ggplot2::element_blank(),
      axis.title             = ggplot2::element_text(size = 11, color = "black"),
      axis.title.y           = ggplot2::element_text(margin = ggplot2::margin(r = 8)),
      axis.text              = ggplot2::element_text(size = 10, color = "black"),
      axis.line.x            = ggplot2::element_line(color = "black", linewidth = 0.5),
      axis.line.y            = ggplot2::element_line(color = "black", linewidth = 0.5),
      axis.ticks             = ggplot2::element_line(color = "black", linewidth = 0.4),
      axis.ticks.length      = ggplot2::unit(3, "pt"),
      panel.grid.major       = ggplot2::element_blank(),
      panel.grid.minor       = ggplot2::element_blank(),
      plot.background        = ggplot2::element_rect(fill = "white", color = NA),
      panel.background       = ggplot2::element_rect(fill = "white", color = NA)
    )
}

raw <- read_csv(
  "data/task_05/BattleDeaths_v25_1_conf.csv",
  show_col_types = FALSE
)

# Aggregate global yearly battle-related deaths (best estimate)
yearly <- raw %>%
  group_by(year) %>%
  summarise(deaths = sum(bd_best, na.rm = TRUE), .groups = "drop") %>%
  arrange(year)

cat("Years:", min(yearly$year), "-", max(yearly$year), "\n")
cat("Top 5 deadliest years:\n")
yearly %>% arrange(desc(deaths)) %>% head(5) %>% print()

# ---- Annotation layer (v5): three named conflict peaks ----
# Peak POINTS are pulled from the aggregated data, never hand-typed. Only the
# conflict NAME strings are editorial overlays. The 1999-2000 surge peaks at
# 1999 (the higher of the two adjacent points), so we mark 1999.
peak_years <- c(1999, 2014, 2022)
peaks <- yearly %>% filter(year %in% peak_years)

# Per-peak callout geometry. Each callout has:
#   * a white-filled circle marker (black border) sitting on the peak point,
#   * a black leader segment from a label anchor to just outside the marker,
#   * a black, left/centre-aligned label naming the conflict + year.
# Label anchors chosen so text never crosses the line or another label, and
# leaders point cleanly into each peak.
callouts <- tribble(
  ~year, ~label,                            ~x_lbl, ~y_lbl, ~hjust, ~vjust, ~x_arr, ~y_arr, ~x_tip, ~y_tip,
  1999,  "Eritrea-Ethiopia war\n(1999-2000)", 1999,   135000, 0.5,    0,      1999,   126000, 1999,   88000,
  2014,  "Syrian civil war\n& rise of IS (2014)", 2009.5, 178000, 0,    0,      2012.4, 170000, 2013.7, 122000,
  2022,  "Tigray (Ethiopia)\n+ Ukraine (2022)", 2013,   285000, 0,      1,      2018.8, 277000, 2021.3, 277000
)

p <- ggplot(yearly, aes(x = year, y = deaths)) +
  geom_line(color = "black", linewidth = 0.7) +
  # Leaders from each label anchor into the peak marker. Drawn BEFORE the
  # markers so the white marker fill sits cleanly on top of the leader end.
  geom_segment(
    data = callouts,
    aes(x = x_arr, y = y_arr, xend = x_tip, yend = y_tip),
    inherit.aes = FALSE,
    color = "black", linewidth = 0.4
  ) +
  # Peak markers: small white-filled circle, black border, on each peak point.
  geom_point(
    data = peaks, aes(x = year, y = deaths),
    inherit.aes = FALSE,
    shape = 21, fill = "white", color = "black", size = 2.8, stroke = 0.7
  ) +
  # Named-conflict labels.
  geom_text(
    data = callouts,
    aes(x = x_lbl, y = y_lbl, label = label, hjust = hjust, vjust = vjust),
    inherit.aes = FALSE,
    family = chart_family, color = "black", size = 3.3,
    lineheight = 0.95, fontface = "bold"
  ) +
  scale_x_continuous(
    breaks = c(1990, 1995, 2000, 2005, 2010, 2015, 2020, 2024),
    expand = expansion(mult = c(0.02, 0.02))
  ) +
  scale_y_continuous(
    breaks = seq(0, 300000, 50000),
    labels = function(x) ifelse(x == 0, "0",
                                paste0(format(x / 1000, big.mark = ""), "k")),
    limits = c(0, 310000),
    expand = expansion(mult = c(0, 0.02))
  ) +
  labs(
    x = NULL,
    y = "Battle-related deaths per year"
  ) +
  theme_bw_strict(base_family = chart_family)

out_pdf <- "iterations/task_05/v5/battle_deaths_v5.pdf"
ggsave(out_pdf, p, width = 26, height = 13, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
