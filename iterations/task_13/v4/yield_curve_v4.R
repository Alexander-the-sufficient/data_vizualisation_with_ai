# Task 13 v4 — final: spread coloured red below zero, lag annotations,
# 2022 inversion called out as the open case.
#
# v4 vs v3: three additions, each load-bearing.
#   (1) Below-zero portions of the line are heritage red — inversions are
#       now preattentive, the reader spots them in <250 ms instead of
#       having to scan for dips below the zero line.
#   (2) Lag labels between each inversion and the next recession ("17 mo",
#       "20 mo", "34 mo", "24 mo", "6 mo") — the *length* of the warning
#       window is part of the story, not just the existence of it.
#   (3) The 2022 inversion is annotated as the open case: deepest since
#       the Volcker era, dis-inverted Sep 2024, no recession yet.
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

# Inversion-to-recession lag annotations. Each pair is "first day the
# spread went below zero, looking back from the recession start" → "the
# recession start". Lags computed in Bash earlier; kept as text labels
# here, not derived inside the chart, so the annotations are stable when
# the data is refreshed.
lag_ann <- tibble::tribble(
  ~inv_start,           ~rec_start,           ~label,
  as.Date("1978-08-18"), as.Date("1980-02-01"), "17 mo",
  as.Date("1988-12-13"), as.Date("1990-08-01"), "20 mo",
  as.Date("1998-05-26"), as.Date("2001-04-01"), "34 mo",
  as.Date("2005-12-27"), as.Date("2008-01-01"), "24 mo",
  as.Date("2019-08-27"), as.Date("2020-03-01"), "6 mo"
) %>%
  mutate(mid = as.Date((as.numeric(inv_start) + as.numeric(rec_start)) / 2,
                       origin = "1970-01-01"))

# 2022 inversion: deepest single-day reading, dis-inversion date.
deepest_22 <- tibble(date = as.Date("2023-07-03"), spread = -1.08)
disinv_22  <- as.Date("2024-09-06")

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
  # Lag labels above the chart, one per recession pair, with leader
  # segments down to the inversion-start dates so the reader can trace
  # each label to its anchor.
  geom_segment(data = lag_ann,
               aes(x = inv_start, xend = inv_start, y = 2.6, yend = 0.05),
               color = pg_palette$dark_quartz, linewidth = 0.25,
               linetype = "dotted") +
  geom_label(data = lag_ann,
             aes(x = inv_start, y = 2.85, label = label),
             family = chart_family, size = 2.7,
             color = pg_palette$alloy,
             fill = "white", linewidth = 0, label.r = unit(0, "pt"),
             label.padding = unit(c(1, 2.5, 1, 2.5), "pt"),
             hjust = 0.5, vjust = 0.5) +
  # 2022 open case: red dot at the deepest reading, dashed leader to the
  # callout above.
  geom_point(data = deepest_22, aes(x = date, y = spread),
             color = pg_palette$heritage_red, size = 1.6) +
  annotate("segment",
           x = as.Date("2023-07-03"), xend = as.Date("2023-07-03"),
           y = -1.05, yend = -2.05,
           color = pg_palette$heritage_red, linewidth = 0.25,
           linetype = "dotted") +
  annotate("label",
           x = as.Date("2023-07-03"), y = -2.30,
           label = "Open case:\n30-month inversion,\ndeepest since 1981,\ndis-inverted Sep 2024",
           family = chart_family, size = 2.7,
           color = pg_palette$heritage_red,
           fill = "white", linewidth = 0, label.r = unit(0, "pt"),
           label.padding = unit(c(2, 3, 2, 3), "pt"),
           hjust = 0.5, vjust = 1, lineheight = 1.0,
           fontface = "bold") +
  scale_x_date(date_breaks = "10 years", date_labels = "%Y",
               expand = expansion(mult = c(0.02, 0.04))) +
  scale_y_continuous(breaks = seq(-3, 3, 1),
                     labels = function(x) paste0(x, " pp"),
                     limits = c(-3.6, 3.4),
                     expand = expansion(mult = c(0.01, 0.04))) +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = NULL) +
  theme_pg(base_family = chart_family) +
  theme(
    panel.grid.major.y = element_line(color = pg_palette$light_quartz,
                                      linewidth = 0.3),
    panel.grid.minor   = element_blank(),
    plot.margin        = margin(t = 18, r = 12, b = 8, l = 8)
  )

out_pdf <- "iterations/task_13/v4/yield_curve_v4.pdf"
ggsave(out_pdf, p, width = 26, height = 13, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
