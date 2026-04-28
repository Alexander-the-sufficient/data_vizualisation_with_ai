# Task 5 v1 — Global battle-related deaths, 1989-2024 (B&W).
# Story: the four bloodiest years on record (UCDP series begins 1989) are
#   2022, 2021, 2023, and 2024 — all of the past four years.
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

# Annotations for major conflict spikes — kept few to preserve B&W cleanliness
ann <- tibble::tribble(
  ~year, ~deaths, ~label,
  1990,  yearly$deaths[yearly$year == 1990], "Gulf War,\nLiberia, Sri Lanka",
  1999,  yearly$deaths[yearly$year == 1999], "Eritrea-Ethiopia,\nKosovo",
  2014,  yearly$deaths[yearly$year == 2014], "Syria, Iraq (ISIS)",
  2022,  yearly$deaths[yearly$year == 2022], "Ukraine,\nEthiopia (Tigray)"
)

  # Manual annotations: geom_segment supports arrow.fill, ggrepel does not.
  # Each label gets a fixed position; the segment from label-end to data-point
  # uses a closed, black-filled arrowhead.
  ann_pos <- ann
  ann_pos$x_lbl <- c(1993,   2003,   2010,   2017)
  ann_pos$y_lbl <- c(130000, 110000, 150000, 285000)
  # Pull the arrow tip back from the data point by a small fraction of the
  # segment, leaving a visible gap between the arrowhead and the line.
  gap_frac <- 0.07
  ann_pos$x_tip <- ann_pos$year   + (ann_pos$x_lbl - ann_pos$year)   * gap_frac
  ann_pos$y_tip <- ann_pos$deaths + (ann_pos$y_lbl - ann_pos$deaths) * gap_frac

p <- ggplot(yearly, aes(x = year, y = deaths)) +
  geom_line(color = "black", linewidth = 0.7) +
  geom_segment(
    data = ann_pos,
    aes(x = x_lbl, y = y_lbl, xend = x_tip, yend = y_tip),
    color = "black", arrow.fill = "black", linewidth = 0.4,
    arrow = grid::arrow(length = grid::unit(2.2, "mm"),
                        angle = 22, type = "closed")
  ) +
  geom_text(
    data = ann_pos, aes(x = x_lbl, y = y_lbl, label = label),
    family = chart_family, color = "black", size = 3.1,
    lineheight = 0.95, vjust = -0.2, hjust = 0.5
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

out_pdf <- "iterations/task_05/v1/battle_deaths_v1.pdf"
ggsave(out_pdf, p, width = 26, height = 13, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
