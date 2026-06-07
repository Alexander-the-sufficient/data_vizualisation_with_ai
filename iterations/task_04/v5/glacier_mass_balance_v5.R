# Task 4 v5 — Swiss glacier annual mass balance, 1956-2025.
# v5 changes vs v4: added two direct annotations on the bars themselves.
#   v4 had no point annotations — the story lived entirely in the title
#   and caption. Lecture 06 mistake #9 ("Wrong annotations: no annotations
#   at all") flagged this. The chart now anchors:
#     - 1994: first year of the unbroken negative-balance streak. 1993
#       was the last positive year on record (+0.007 m). The streak runs
#       1994-2025 = 32 years, matching the title.
#     - 2022: deepest annual loss in the entire series (-2.95 m w.e.),
#       1.5x worse than the next-worst year on record (2023, -2.00 m).
#   Two anchors only — the chart has 70 thin bars and over-annotation
#   would crowd the field. Both labels sit ABOVE the chart's negative
#   region (one near the top to mark the streak start, one above the
#   2022 trough) so they don't fight the bars for ink.
#
# v4 strategy: single-colour bars (alloy), let the data shape carry the
#   story.
#
# Source: GLAMOS (2025). Swiss Glacier Mass Balance, release 2025,
#   Glacier Monitoring Switzerland, doi:10.18750/massbalance.2025.r2025.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
})

source("design_system.R")

chart_family <- ""

mb_cols <- c(
  "glacier", "glacier_id",
  "date_start", "date_end_winter", "date_end",
  "Bw_mm_we", "Bs_mm_we", "Ba_mm_we",
  "ELA", "AAR", "area_km2", "h_min", "h_max", "observer"
)

raw <- read_csv(
  "data/task_04/massbalance_fixdate.csv",
  skip = 9,
  col_names = mb_cols,
  show_col_types = FALSE,
  na = c("", "NA")
)

mb <- raw %>%
  mutate(
    hydro_year = as.integer(format(as.Date(date_end), "%Y")),
    Ba_m_we    = as.numeric(Ba_mm_we) / 1000,
    area_km2   = as.numeric(area_km2)
  ) %>%
  filter(!is.na(Ba_m_we), !is.na(area_km2), area_km2 > 0)

swiss <- mb %>%
  group_by(hydro_year) %>%
  summarise(
    n_glaciers = n(),
    Ba_m_we    = sum(Ba_m_we * area_km2) / sum(area_km2),
    .groups    = "drop"
  ) %>%
  filter(n_glaciers >= 10, hydro_year >= 1956, hydro_year <= 2025) %>%
  arrange(hydro_year)

swiss <- swiss %>%
  mutate(highlight = hydro_year >= 2022)

# Minimum visible bar height — three years had near-zero mass balance
# (1956: +0.004, 1967: -0.0001, 1993: +0.007 m w.e.) that would render as
# invisible gaps. Render at minimum visible height (preserving sign) so
# every year produces a visible bar. Disclosed in the Quarto caption.
min_visible <- 0.05
swiss <- swiss %>%
  mutate(
    Ba_plot = case_when(
      abs(Ba_m_we) >= min_visible ~ Ba_m_we,
      Ba_m_we >= 0                ~  min_visible,
      TRUE                        ~ -min_visible
    )
  )

# Annotations — two anchors only. Both labels sit in the SPARSE upper
# region of the panel (y > 0) where there are no negative bars in the
# way, with a leader line dropping down to the data point. This mirrors
# both annotations in the same vertical band so the eye picks them up
# as a pair.
#   1994: leader anchored to the bar at y = -0.92, text starts at the
#         label x (hjust = 0, extends right).
#   2022: label sits in the upper-right corner (x = 2025), right-aligned
#         (hjust = 1) so it never extends past the right panel edge;
#         leader runs from the label anchor down to the bar tip at -2.95.
ann_streak <- tibble::tribble(
  ~x_data, ~y_data, ~x_lbl, ~y_lbl, ~label,
  1994,    -0.92,    1994,    0.55, "1994\nstreak begins\n(1993 last positive year)"
)
ann_worst <- tibble::tribble(
  ~x_data, ~y_data, ~x_lbl, ~y_lbl, ~label,
  2022,    -2.95,    2025,    0.55, "2022\nworst on record\n-2.95 m water equivalent"
)
ann <- dplyr::bind_rows(ann_streak, ann_worst)

p <- ggplot(swiss, aes(x = hydro_year, y = Ba_plot, fill = highlight)) +
  geom_col(width = 0.78) +
  geom_hline(yintercept = 0, color = pg_palette$onyx, linewidth = 0.9) +
  scale_fill_manual(
    values = c(`FALSE` = pg_palette$alloy, `TRUE` = pg_palette$alloy),
    guide  = "none"
  ) +
  # Leader segments from each annotated bar (x_data, y_data) to its label
  # anchor (x_lbl, y_lbl). The 1994 leader is vertical (same x). The 2022
  # leader is diagonal: from the bar tip up-and-right into the sparse
  # upper-right region.
  geom_segment(data = ann,
               aes(x = x_data, xend = x_lbl,
                   y = y_data, yend = y_lbl),
               color = pg_palette$alloy, linewidth = 0.25,
               inherit.aes = FALSE) +
  # 1994 label: left-aligned at x = 1994 (hjust = 0), text extends right
  # into the sparse positive region.
  geom_text(data = ann_streak,
            aes(x = x_lbl, y = y_lbl, label = label),
            inherit.aes = FALSE,
            family = chart_family, size = 3.0,
            color = pg_palette$alloy,
            hjust = 0, vjust = 0,
            lineheight = 0.95) +
  # 2022 label: right-aligned at x = 2025 (hjust = 1), so the right edge
  # of text sits at the chart's right margin — never overflows the panel.
  geom_text(data = ann_worst,
            aes(x = x_lbl, y = y_lbl, label = label),
            inherit.aes = FALSE,
            family = chart_family, size = 3.0,
            color = pg_palette$alloy,
            hjust = 1, vjust = 0,
            lineheight = 0.95) +
  scale_x_continuous(
    breaks = seq(1960, 2025, 10),
    expand = expansion(mult = c(0.01, 0.02))
  ) +
  scale_y_continuous(
    breaks = seq(-3, 1, 1),
    limits = c(-3.2, 1.4),
    expand = expansion(mult = c(0.02, 0.02))
  ) +
  labs(
    x = NULL,
    y = "Annual mass balance (m water equivalent)"
  ) +
  theme_pg(base_family = chart_family)

out_pdf <- "iterations/task_04/v5/glacier_mass_balance_v5.pdf"
ggsave(out_pdf, p, width = 26, height = 13, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
