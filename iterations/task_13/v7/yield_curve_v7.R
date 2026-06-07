# Task 13 v7 — clean, reusable spread-vs-recession chart.
#
# v7 vs v6: two changes. The goal is a chart that carries as little
# in-plot text/dots/noise as possible, so it can be reused across
# contexts with the narrative living in the title/caption, not on the plot.
#   (1) COLOR: below-zero (inverted) spread segments now render in
#       HERITAGE RED (#D92B2B) instead of copper. Inversions are the
#       point of the chart, and red is the intended signal for them.
#       The above-zero line stays alloy.
#   (2) STRIP IN-CHART NOISE: removed ALL annotation text and dots —
#       the "No recession yet" label and the red dot at the 2022 trough
#       are gone. The "2022 inversion, no recession yet" observation is
#       explained in the title/caption, not baked into the chart.
#
# What stays from v6:
#   * NBER recession bands behind everything, in pale quartz, with the
#     150-day minimum-width fix so all SIX bands (incl. the brief 2020
#     COVID recession) stay visible.
#   * Zero reference line.
#
# Data sources:
#   FRED T10Y2Y — 10Y-2Y Treasury spread (daily).
#   FRED USREC  — NBER recession indicator (monthly, 0 / 1).

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
})

source("design_system.R")
chart_family <- ""

spread <- read_csv("data/task_13/T10Y2Y.csv", show_col_types = FALSE) %>%
  rename(spread = value) %>%
  arrange(date) %>%
  mutate(
    sign = ifelse(spread < 0, "neg", "pos"),
    run  = cumsum(sign != lag(sign, default = first(sign)))
  )

usrec <- read_csv("data/task_13/USREC.csv", show_col_types = FALSE) %>%
  arrange(date) %>%
  mutate(prev = lag(value, default = 0))
rec_starts <- usrec %>% filter(value == 1, prev == 0) %>% pull(date)
rec_ends   <- usrec %>% filter(value == 0, prev == 1) %>% pull(date)
recessions <- tibble(start = rec_starts, end = rec_ends)

# --- minimum visible band width (retained from v6) ---------------------
# The 2020 recession is only ~2 months wide; against a ~50-year axis its
# rect collapses to an invisible sliver. Enforce a floor on the displayed
# width and centre any widened band on its true midpoint, so the rect
# still brackets the real recession dates while staying legible.
min_band_days <- 150
recessions <- recessions %>%
  mutate(
    width_days = as.numeric(end - start),
    mid        = start + (end - start) / 2,
    draw_start = if_else(width_days < min_band_days,
                         mid - (min_band_days / 2), start),
    draw_end   = if_else(width_days < min_band_days,
                         mid + (min_band_days / 2), end)
  )

p <- ggplot() +
  geom_rect(data = recessions,
            aes(xmin = draw_start, xmax = draw_end, ymin = -Inf, ymax = Inf),
            fill = pg_palette$quartz, alpha = 0.55) +
  geom_hline(yintercept = 0, color = pg_palette$alloy, linewidth = 0.45) +
  geom_line(data = spread %>% filter(sign == "pos"),
            aes(x = date, y = spread, group = run),
            color = pg_palette$alloy, linewidth = 0.35) +
  # Inversion emphasis — heritage red. The below-zero spread IS the story.
  geom_line(data = spread %>% filter(sign == "neg"),
            aes(x = date, y = spread, group = run),
            color = pg_palette$heritage_red, linewidth = 0.45) +
  scale_x_date(date_breaks = "10 years", date_labels = "%Y",
               expand = expansion(mult = c(0.02, 0.04))) +
  scale_y_continuous(breaks = seq(-3, 3, 1),
                     labels = function(x) paste0(x, " pp"),
                     limits = c(-2.8, 3.2),
                     expand = expansion(mult = c(0.01, 0.02))) +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = NULL) +
  theme_pg(base_family = chart_family) +
  theme(
    panel.grid.major.y = element_line(color = pg_palette$light_quartz,
                                      linewidth = 0.3),
    panel.grid.minor   = element_blank(),
    plot.margin        = margin(t = 8, r = 12, b = 8, l = 8)
  )

out_pdf <- "iterations/task_13/v7/yield_curve_v7.pdf"
ggsave(out_pdf, p, width = 26, height = 13, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
