# Task 13 v1 — raw 10Y and 2Y Treasury yields, two lines on the same axes.
#
# First draft of the yield-curve chart. The viewer has to mentally subtract
# one line from the other to see the inversion story — which makes this a
# natural first step on the iteration ladder: a chart that *shows* the data
# but doesn't *tell* the story.
#
# Data source: FRED (Federal Reserve Bank of St. Louis).
#   DGS10 — 10-year constant-maturity Treasury yield (daily).
#   DGS2  — 2-year constant-maturity Treasury yield (daily).
# Both downloaded via the API helper at data/task_13/fetch_fred.R.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
})

source("design_system.R")
chart_family <- ""

dgs10 <- read_csv("data/task_13/DGS10.csv", show_col_types = FALSE) %>%
  mutate(series = "10-year")
dgs2  <- read_csv("data/task_13/DGS2.csv",  show_col_types = FALSE) %>%
  mutate(series = "2-year")
yields <- bind_rows(dgs10, dgs2)

p <- ggplot(yields, aes(x = date, y = value, color = series)) +
  geom_line(linewidth = 0.35, alpha = 0.85) +
  scale_color_manual(values = c("10-year" = pg_palette$alloy,
                                "2-year"  = pg_palette$dark_quartz)) +
  scale_x_date(date_breaks = "10 years", date_labels = "%Y",
               expand = expansion(mult = c(0.01, 0.04))) +
  scale_y_continuous(breaks = seq(0, 16, 2),
                     labels = function(x) paste0(x, "%"),
                     limits = c(0, 16.5),
                     expand = expansion(mult = c(0.01, 0.02))) +
  labs(x = NULL, y = NULL, color = NULL) +
  theme_pg(base_family = chart_family) +
  theme(
    legend.position  = c(0.85, 0.85),
    legend.text      = element_text(size = 10, color = pg_palette$alloy),
    legend.key       = element_blank(),
    panel.grid.major.y = element_line(color = pg_palette$light_quartz,
                                      linewidth = 0.3),
    panel.grid.minor   = element_blank()
  )

out_pdf <- "iterations/task_13/v1/yield_curve_v1.pdf"
ggsave(out_pdf, p, width = 26, height = 13, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
