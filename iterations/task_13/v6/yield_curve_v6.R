# Task 13 v6 — final: visible 2020 band + red dialed back to one accent.
#
# v6 vs v5: two fixes.
#   (1) 2020 COVID-recession band rendered too thin to see. The NBER
#       recession was only ~2 months (61 days) against a ~50-year x-axis,
#       so its rect was a near-zero-width sliver — but the headline rests
#       on the reader seeing all SIX recession bands ("every US recession
#       since 1976 was preceded by an inverted yield curve"). Fix: enforce
#       a minimum visible width on the recession rectangles (a floor on
#       xmax - xmin), widening only the bands that fall under the floor and
#       keeping each centred on its true midpoint so the displayed span
#       still brackets the actual recession dates.
#   (2) Red overuse / cross-portfolio inconsistency. v5 filled EVERY
#       below-zero (inverted) segment of the spread line in heritage red,
#       so red read as a routine series colour — whereas elsewhere in the
#       portfolio (e.g. Task 7) heritage red is a rare single accent. Fix:
#       the inversion emphasis now renders in COPPER (the palette's
#       qualitative companion), and heritage red is reserved for the ONE
#       storytelling moment the title is about — the 2022 inversion's
#       "open case / no recession yet" dot + label.
#
# What stays from v5:
#   * NBER recession bands behind everything, in pale quartz.
#   * Zero reference line.
#   * One short label at the 2022 trough ("No recession yet").
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

# --- Fix (1): guarantee a minimum visible band width -------------------
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

# 2022 inversion: deepest single-day reading.
deepest_22 <- tibble(date = as.Date("2023-07-03"), spread = -1.08)

p <- ggplot() +
  geom_rect(data = recessions,
            aes(xmin = draw_start, xmax = draw_end, ymin = -Inf, ymax = Inf),
            fill = pg_palette$quartz, alpha = 0.55) +
  geom_hline(yintercept = 0, color = pg_palette$alloy, linewidth = 0.45) +
  geom_line(data = spread %>% filter(sign == "pos"),
            aes(x = date, y = spread, group = run),
            color = pg_palette$alloy, linewidth = 0.35) +
  # Inversion emphasis — copper, the palette's qualitative companion.
  # Red is NOT used here: it is reserved for the single 2022 callout below.
  geom_line(data = spread %>% filter(sign == "neg"),
            aes(x = date, y = spread, group = run),
            color = pg_palette$copper, linewidth = 0.45) +
  # 2022 open case (the one red moment): dot at the deepest reading + label.
  geom_point(data = deepest_22, aes(x = date, y = spread),
             color = pg_palette$heritage_red, size = 1.8) +
  annotate("text",
           x = as.Date("2023-07-03"), y = -1.55,
           label = "No recession yet",
           family = chart_family, size = 3.0,
           color = pg_palette$heritage_red,
           hjust = 0.5, vjust = 0,
           fontface = "bold") +
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

out_pdf <- "iterations/task_13/v6/yield_curve_v6.pdf"
ggsave(out_pdf, p, width = 26, height = 13, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
