# Task 13 v3 — spread + NBER recession bands.
#
# v3 vs v2: adds the second half of the story. The spread alone shows
# inversions; the recession-band overlay shows what came next. Once both
# layers are on the chart, the reader can see for themselves that every
# recession was preceded by a dip below zero.
#
# Recession bands are pale quartz fills in the background; the spread line
# sits on top in alloy. No annotations yet — the visual coincidence does
# the work.
#
# Data sources:
#   FRED T10Y2Y — 10Y-2Y Treasury spread (daily).
#   FRED USREC  — NBER recession indicator (monthly, 0 = expansion, 1 = recession).

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

usrec <- read_csv("data/task_13/USREC.csv", show_col_types = FALSE) %>%
  arrange(date) %>%
  mutate(prev = lag(value, default = 0))

rec_starts <- usrec %>% filter(value == 1, prev == 0) %>% pull(date)
rec_ends   <- usrec %>% filter(value == 0, prev == 1) %>% pull(date)
recessions <- tibble(start = rec_starts, end = rec_ends)

p <- ggplot() +
  geom_rect(data = recessions,
            aes(xmin = start, xmax = end, ymin = -Inf, ymax = Inf),
            fill = pg_palette$quartz, alpha = 0.55) +
  geom_hline(yintercept = 0, color = pg_palette$alloy, linewidth = 0.45) +
  geom_line(data = spread, aes(x = date, y = spread),
            color = pg_palette$alloy, linewidth = 0.35) +
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

out_pdf <- "iterations/task_13/v3/yield_curve_v3.pdf"
ggsave(out_pdf, p, width = 26, height = 13, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
