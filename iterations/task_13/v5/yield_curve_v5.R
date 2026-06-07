# Task 13 v5 — final: cleaner annotations.
#
# v5 vs v4: removed the row of cryptic "17 mo / 20 mo / 34 mo / 24 mo /
#   6 mo" lag labels above the chart — without an explanatory header they
#   read as orphan numbers, and the recession-band overlay already tells
#   the inversion-precedes-recession story by visual coincidence. Replaced
#   the four-line open-case callout with one short red label at the 2022
#   trough ("No recession yet"), since the verbose multi-line box at the
#   bottom-right read as a footnote pasted on the chart.
#
# What stays from v4:
#   * Below-zero portions of the line in heritage red (preattentive).
#   * NBER recession bands in pale quartz.
#   * Red dot marking the deepest 2022 reading.
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

# 2022 inversion: deepest single-day reading.
deepest_22 <- tibble(date = as.Date("2023-07-03"), spread = -1.08)

p <- ggplot() +
  geom_rect(data = recessions,
            aes(xmin = start, xmax = end, ymin = -Inf, ymax = Inf),
            fill = pg_palette$quartz, alpha = 0.55) +
  geom_hline(yintercept = 0, color = pg_palette$alloy, linewidth = 0.45) +
  geom_line(data = spread %>% filter(sign == "pos"),
            aes(x = date, y = spread, group = run),
            color = pg_palette$alloy, linewidth = 0.35) +
  geom_line(data = spread %>% filter(sign == "neg"),
            aes(x = date, y = spread, group = run),
            color = pg_palette$heritage_red, linewidth = 0.40) +
  # 2022 open case: red dot at the deepest reading + one-line label.
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

out_pdf <- "iterations/task_13/v5/yield_curve_v5.pdf"
ggsave(out_pdf, p, width = 26, height = 13, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
