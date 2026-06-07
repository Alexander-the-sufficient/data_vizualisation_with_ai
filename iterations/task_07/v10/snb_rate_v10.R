# Task 7 v10 — SNB policy rate, 2000-2026 (three-anchor sparkline).
# v10 drops the "3.50% pre-GFC high (Jun 2000)" callout that v9 still kept.
#   Rationale (user request, pushing data-ink further): three labelled
#   anchors are enough to calibrate the whole vertical scale, so the peaks
#   no longer need their own labels — the eye reads them by proportion:
#     * 1.75% Jan 2000 (start) and -0.75% Jan 2015 (trough) bracket the
#       0.00% baseline, fixing three reference heights.
#     * the 2000 peak sits at ~2x the start height -> ~3.5%;
#     * the 2023 bump sits at the same height as the start -> ~1.75%;
#     * the 2007 peak sits between them -> ~2.75%.
#   So the reader can gauge every high/low from start + trough + end alone.
#
#   KEPT (the three magnitude anchors — the only value references on an
#   axis-free sparkline, so each label IS data-ink):
#     * 1.75% Jan 2000 — left endpoint (start)
#     * -0.75% trough, Jan 2015 — global minimum (single red accent)
#     * 0.00% Mar 2026 — right endpoint (current value)
#   The pre-GFC high and the 2023 rebound now live only in the Quarto
#   subtitle prose, not on the chart. Top y-limit lowered 4.9 -> 3.9 since
#   the lifted 3.50% label no longer needs headroom.
#
# Lineage: v9 cut the 2007 landmark + 2023 hike labels; v8 made callouts
#   consistent with leaders; v7 fixed the 3.50% max labelling; see v9/v8.
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

# Three anchors only: two endpoints + the global minimum.
ann <- tibble::tribble(
  ~date,                  ~rate,  ~label,                          ~lbl_x,                   ~lbl_y,  ~role,
  as.Date("2000-01-15"),   1.75,  "1.75%  Jan 2000",               as.Date("1999-09-15"),     1.75,   "endpoint_left",
  as.Date("2015-01-15"),  -0.75,  "-0.75% trough\nJan 2015",       as.Date("2015-02-15"),    -1.55,   "trough",
  as.Date("2026-03-15"),   0.00,  "0.00%  Mar 2026",               as.Date("2026-06-15"),     0.00,   "endpoint_right"
)

# Leader: thin short connector from the offset trough label back to its
# data point. `gap_y` is the breathing space left between label and leader.
gap_y <- 0.18
leaders <- ann %>%
  filter(role == "trough") %>%
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
  geom_text(data = ann %>% filter(role == "trough"),
            aes(x = lbl_x, y = lbl_y, label = label),
            family = chart_family, size = 3.0,
            color = pg_palette$heritage_red,
            hjust = 0, vjust = 1, fontface = "bold",
            lineheight = 0.95) +
  scale_x_date(expand = expansion(mult = c(0.10, 0.12))) +
  scale_y_continuous(limits = c(-2.0, 3.9),
                     expand = expansion(mult = c(0, 0))) +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = NULL) +
  theme_void(base_family = chart_family) +
  theme(plot.margin = margin(t = 10, r = 30, b = 8, l = 30))

out_pdf <- "iterations/task_07/v10/snb_rate_v10.pdf"
ggsave(out_pdf, p, width = 28, height = 9, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
