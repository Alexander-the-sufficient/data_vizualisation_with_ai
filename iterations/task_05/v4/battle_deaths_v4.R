# Task 5 v4 — Global battle-related deaths, 1989-2024 (B&W).
# v4 changes vs v3 — ANNOTATION LAYER ONLY (line, axes, theme unchanged):
#   * The portfolio headline is "the four deadliest years in 35 years of UCDP
#     records are all 2021-2024". v3's annotations marked 1990 / 1999 / 2014 /
#     2022 individually, so the chart did NOT visually support its own headline
#     (2014, in particular, is NOT in the top four — verified: the four highest
#     annual values are 2022=276,893; 2021=199,789; 2023=131,061; 2024=128,439;
#     #5 is 2014=115,972, below all four).
#   * v4 drops the four scattered decade callouts and instead makes the
#     2021-2024 cluster the single, visually dominant annotation: a black
#     marker on each of the four year-points at the right end of the line,
#     plus ONE label "2021-2024:\nthe four deadliest years on record" with a
#     leader to the cluster. This is exactly the story the headline tells.
#   * Each of the four marked points carries a small year tick label so the
#     reader can see the cluster is precisely the four most recent years.
# v3 changes vs v2: restored 1990 callout, repositioned 1999 leader.
# v2 changes vs v1: title rewording in Quarto (UCDP records start in 1989).
# Story: in 35 years of UCDP records, the four deadliest years are the four
#   most recent ones — 2021-2024 — peaking in 2022 (Ukraine + Tigray).
# Strict black-and-white aesthetic: only pure black on pure white.
# No greys, no semi-transparent fills, no shaded uncertainty bands.
#
# Source: UCDP (2025). Battle-Related Deaths Dataset, version 25.1.
#   Uppsala Conflict Data Program. https://ucdp.uu.se/downloads/

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(ggrepel)
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

# ---- Annotation layer (v4): the 2021-2024 cluster is the whole story ----
# The four year-points that ARE the four deadliest years on record. Values
# pulled from the aggregated data, never hand-typed.
cluster_years <- 2021:2024
cluster <- yearly %>% filter(year %in% cluster_years)

# Per-point year tick labels, nudged so they sit clear of the line/markers
# and clear of each other. 2021/2022 climb steeply, 2023/2024 fall.
cluster_lab <- cluster %>%
  mutate(
    x_txt = c(
      2021 - 0.4,   # 2021 to the left of its rising point
      2022,         # 2022 centred above the peak
      2023 - 0.5,   # 2023 nudged left of its point
      2024 - 0.4    # 2024 nudged left of its point (stays inside the panel)
    ),
    y_txt = c(
      deaths[year == 2021] - 20000,  # below the rising shoulder
      deaths[year == 2022] + 13000,  # above the peak
      deaths[year == 2023] + 20000,  # above the descent
      deaths[year == 2024] - 20000   # below the tail
    ),
    hjust_txt = c(1, 0.5, 1, 1)
  )

# Single dominant callout describing the cluster. The leader starts from the
# RIGHT edge of the label block (below the text) so it never crosses the words,
# and points into the four-point group (anchored just above the 2021 climb).
call_x_lbl <- 2008
call_y_lbl <- 250000   # top of the two-line label block (vjust = 1)
# Leader origin: to the right of and below the label text, clear of the glyphs.
call_x_arr <- 2014.5
call_y_arr <- 226000
call_x_tip <- 2020.5
call_y_tip <- yearly$deaths[yearly$year == 2021] + 4000

p <- ggplot(yearly, aes(x = year, y = deaths)) +
  geom_line(color = "black", linewidth = 0.7) +
  # Emphasize the four deadliest year-points: filled black markers.
  geom_point(
    data = cluster, aes(x = year, y = deaths),
    color = "black", fill = "black", shape = 21, size = 2.6, stroke = 0.6
  ) +
  # Per-point year tick labels so the cluster reads as 2021-2024 precisely.
  geom_text(
    data = cluster_lab, aes(x = x_txt, y = y_txt, label = year),
    family = chart_family, color = "black", size = 3.0,
    hjust = cluster_lab$hjust_txt, vjust = 0.5
  ) +
  # Leader from the single cluster callout into the four-point group. Origin is
  # below/right of the label text so the line never crosses the words.
  annotate(
    "segment", x = call_x_arr, y = call_y_arr, xend = call_x_tip, yend = call_y_tip,
    color = "black", arrow.fill = "black", linewidth = 0.4,
    arrow = grid::arrow(length = grid::unit(2.2, "mm"),
                        angle = 22, type = "closed")
  ) +
  # The one dominant label — exactly the headline's claim.
  annotate(
    "text", x = call_x_lbl, y = call_y_lbl,
    label = "2021-2024:\nthe four deadliest years on record",
    family = chart_family, color = "black", size = 3.6,
    lineheight = 0.95, hjust = 0, vjust = 1, fontface = "bold"
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

out_pdf <- "iterations/task_05/v4/battle_deaths_v4.pdf"
ggsave(out_pdf, p, width = 26, height = 13, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
