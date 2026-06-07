# Task 7 v6 — SNB policy rate, 2000-2026 (Tufte data-ink rigor).
# v6 changes vs v5: switched the data line and the endpoint/peak markers
#   from `pg_palette$onyx` (#000000) to `pg_palette$alloy` (#5C5B59 warm
#   charcoal). The design system reserves Onyx for page-level title text
#   and the rare structural element where black needs to recede; chart
#   marks are not on that list. Other charts in the portfolio (steel,
#   glaciers, inaugural, plastic, energy) use alloy for their primary
#   ink, so this change brings task 7 into cross-portfolio consistency
#   (lecture 06 mistake #10 — sizes/colors varying without reason).
#   Heritage Red is still used exactly once (the -0.75% trough) as the
#   single preattentive cue for the most extreme value in the series.
#   Lecture 06 mistake #5 fix: red stays an accent, not a default.
#
# v5 changes vs v4: added a fifth annotation at the post-NIRP peak
#   (1.75% Jun 2023). Without it the upward swing between the Sep 2022
#   exit and the Mar 2026 cut had no labelled extreme — the eye saw the
#   line peak at ~1.75% but the value wasn't anchored.
#
# v4 changes vs v3: dropped two of the six annotations. Regime-change
#   events were inferred from the line shape; only data extremes and
#   endpoints kept.
#
# v3 changes vs v2: design-system palette migration only.
#
# Sparkline-style: no axes, no ticks, no gridlines, no border, no legend.
#
# Source: Swiss National Bank, "Official rates of the SNB" cube `snboffzisa`,
# data portal data.snb.ch. Splice: LIBOR target band mid (UG0+OG0)/2 for
# pre-Jun-2019 + SNB Leitzins (LZ) for Jun-2019 onward.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(ggplot2)
})

source("design_system.R")

chart_family <- ""

raw <- read_delim(
  "data/task_07/snboffzisa.csv",
  delim = ";",
  skip  = 3,
  col_types = cols(Date = col_character(),
                   D0   = col_character(),
                   Value = col_character()),
  show_col_types = FALSE
) %>%
  mutate(date  = as.Date(paste0(Date, "-15")),
         Value = suppressWarnings(as.numeric(Value)))

band_mid <- raw %>%
  filter(D0 %in% c("UG0", "OG0")) %>%
  select(date, D0, Value) %>%
  pivot_wider(names_from = D0, values_from = Value) %>%
  mutate(rate = (UG0 + OG0) / 2) %>%
  filter(!is.na(rate), date < as.Date("2019-06-01")) %>%
  select(date, rate)

leitzins <- raw %>%
  filter(D0 == "LZ", !is.na(Value), date >= as.Date("2019-06-01")) %>%
  select(date, rate = Value)

policy <- bind_rows(band_mid, leitzins) %>%
  arrange(date) %>%
  filter(date >= as.Date("2000-01-01"))

cat("Series rows:", nrow(policy),
    " range:", as.character(min(policy$date)), "to",
                as.character(max(policy$date)), "\n")
cat("Trough:", min(policy$rate),
    " peak:", max(policy$rate), "\n")

ann <- tibble::tribble(
  ~date,                  ~rate,  ~label,                       ~lbl_x,                   ~lbl_y,  ~role,
  as.Date("2000-01-15"),   1.75,  "1.75%  Jan 2000",            as.Date("1999-09-15"),     1.75,   "endpoint_left",
  as.Date("2007-09-15"),   2.75,  "2.75%  Sep 2007",            as.Date("2007-09-15"),     3.30,   "peak_above",
  as.Date("2015-01-15"),  -0.75,  "-0.75% trough\nJan 2015",    as.Date("2015-02-15"),    -1.55,   "trough",
  as.Date("2023-06-15"),   1.75,  "1.75%  Jun 2023",            as.Date("2023-06-15"),     2.40,   "peak_above",
  as.Date("2026-03-15"),   0.00,  "0.00%  Mar 2026",            as.Date("2026-06-15"),     0.00,   "endpoint_right"
)

gap_y <- 0.18
leaders <- ann %>%
  filter(role %in% c("event_above", "trough", "peak_above")) %>%
  mutate(x = date, xend = date, y = rate,
         yend = lbl_y - ifelse(lbl_y > rate, gap_y, -gap_y))

p <- ggplot(policy, aes(x = date, y = rate)) +
  annotate("segment",
           x = min(policy$date), xend = max(policy$date),
           y = 0, yend = 0,
           color = pg_palette$dark_quartz, linewidth = 0.25) +
  geom_segment(data = leaders,
               aes(x = x, xend = xend, y = y, yend = yend),
               color = pg_palette$alloy, linewidth = 0.2,
               inherit.aes = FALSE) +
  geom_line(color = pg_palette$alloy, linewidth = 0.55) +
  geom_point(data = ann %>% filter(!role %in% c("trough")),
             aes(x = date, y = rate),
             color = pg_palette$alloy, size = 1.3) +
  geom_point(data = ann %>% filter(role == "trough"),
             aes(x = date, y = rate),
             color = pg_palette$heritage_red, size = 1.7) +
  geom_text(data = ann %>% filter(role == "endpoint_left"),
            aes(x = lbl_x, y = lbl_y, label = label),
            family = chart_family, size = 3.0,
            color = pg_palette$alloy,
            hjust = 1, vjust = 0.5) +
  geom_text(data = ann %>% filter(role == "endpoint_right"),
            aes(x = lbl_x, y = lbl_y, label = label),
            family = chart_family, size = 3.0,
            color = pg_palette$alloy,
            hjust = 0, vjust = 0.5) +
  geom_text(data = ann %>% filter(role == "event_above"),
            aes(x = lbl_x, y = lbl_y, label = label),
            family = chart_family, size = 2.9,
            color = pg_palette$alloy,
            hjust = 0.5, vjust = 0,
            lineheight = 0.95) +
  geom_text(data = ann %>% filter(role == "peak_above"),
            aes(x = lbl_x, y = lbl_y, label = label),
            family = chart_family, size = 3.0,
            color = pg_palette$alloy,
            hjust = 0.5, vjust = 0) +
  geom_text(data = ann %>% filter(role == "trough"),
            aes(x = lbl_x, y = lbl_y, label = label),
            family = chart_family, size = 3.0,
            color = pg_palette$heritage_red,
            hjust = 0, vjust = 1, fontface = "bold",
            lineheight = 0.95) +
  scale_x_date(expand = expansion(mult = c(0.10, 0.12))) +
  scale_y_continuous(limits = c(-2.0, 3.7),
                     expand = expansion(mult = c(0, 0))) +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = NULL) +
  theme_void(base_family = chart_family) +
  theme(plot.margin = margin(t = 8, r = 30, b = 8, l = 30))

out_pdf <- "iterations/task_07/v6/snb_rate_v6.pdf"
ggsave(out_pdf, p, width = 28, height = 9, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
