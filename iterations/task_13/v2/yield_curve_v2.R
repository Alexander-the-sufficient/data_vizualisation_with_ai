# Task 13 v2 — single-series spread (10Y minus 2Y).
#
# v2 vs v1: the two-line v1 forced the viewer to do the subtraction by eye.
# v2 plots the spread directly (FRED's T10Y2Y series), so inversions become
# the only thing the reader needs to see: any time the line dips below zero,
# the curve is inverted.
#
# Zero line emphasised in alloy because it is the only threshold that
# matters — above = normal, below = inverted.
#
# Data source: FRED T10Y2Y (daily, %).

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
})

source("design_system.R")
chart_family <- ""

spread <- read_csv("data/task_13/T10Y2Y.csv", show_col_types = FALSE) %>%
  rename(spread = value)

p <- ggplot(spread, aes(x = date, y = spread)) +
  geom_hline(yintercept = 0, color = pg_palette$alloy, linewidth = 0.45) +
  geom_line(color = pg_palette$alloy, linewidth = 0.35) +
  scale_x_date(date_breaks = "10 years", date_labels = "%Y",
               expand = expansion(mult = c(0.01, 0.04))) +
  scale_y_continuous(breaks = seq(-3, 3, 1),
                     labels = function(x) paste0(x, " pp"),
                     limits = c(-2.8, 3.2),
                     expand = expansion(mult = c(0.01, 0.02))) +
  labs(x = NULL, y = NULL) +
  theme_pg(base_family = chart_family) +
  theme(
    panel.grid.major.y = element_line(color = pg_palette$light_quartz,
                                      linewidth = 0.3),
    panel.grid.minor   = element_blank()
  )

out_pdf <- "iterations/task_13/v2/yield_curve_v2.pdf"
ggsave(out_pdf, p, width = 26, height = 13, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
