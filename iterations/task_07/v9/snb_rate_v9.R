# Task 7 v9 — SNB policy rate, 2000-2026 (data-ink pass).
# v9 cuts two annotations from v8 to push the data-ink ratio to the
#   canonical Tufte sparkline: label only first, last, min, and max.
#     * DROPPED "2007: 2.75%" — a secondary, muted LOCAL peak. Not an
#       extreme, not an endpoint; it added ink without advancing the
#       high -> negative -> back-to-zero story.
#     * DROPPED "1.75% Jun 2023" — a local hike, not the global maximum.
#       The line shape already shows the bump, and it sits at the same
#       height as the labelled 2000 start (both 1.75%), so the reader can
#       read its value off the start anchor. The brief 2023 hike now lives
#       only in the Quarto subtitle prose, not on the chart.
#   KEPT (these four are the only magnitude references — there is no
#   y-axis, so each label IS data-ink, not decoration):
#     * 1.75% Jan 2000  — left endpoint (start value)
#     * 3.50% pre-GFC high, Jun 2000 — the global maximum
#     * -0.75% trough, Jan 2015 — the global minimum (single red accent)
#     * 0.00% Mar 2026  — right endpoint (current value)
#
# v8 made the four interior callouts consistently offset with thin leaders;
#   v7 fixed the 3.50% max labelling; v6 alloy line; v5 added 2023 peak; v4
#   dropped inferred-event annotations; v3 palette migration. See v8 header.
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

# True series maximum is 3.50%, held Jun 2000 - Feb 2001 (a plateau).
# Anchor the peak marker at the plateau midpoint (~2000-10) so the dot
# lands on the visible high shoulder of the line, not on a sloping edge.
peak_date <- as.Date("2000-10-15")

# Four anchors only: two endpoints, the global max, the global min.
ann <- tibble::tribble(
  ~date,                  ~rate,  ~label,                          ~lbl_x,                   ~lbl_y,  ~role,
  as.Date("2000-01-15"),   1.75,  "1.75%  Jan 2000",               as.Date("1999-09-15"),     1.75,   "endpoint_left",
  peak_date,               3.50,  "3.50% pre-GFC high\nJun 2000",  peak_date,                 4.55,   "peak_above",
  as.Date("2015-01-15"),  -0.75,  "-0.75% trough\nJan 2015",       as.Date("2015-02-15"),    -1.55,   "trough",
  as.Date("2026-03-15"),   0.00,  "0.00%  Mar 2026",               as.Date("2026-06-15"),     0.00,   "endpoint_right"
)

# Leaders: thin short connector from each offset label back to its data
# point. `gap_y` is the breathing space left between the label glyph and
# the near end of the leader so the line never touches the text.
gap_y <- 0.18
leaders <- ann %>%
  filter(role %in% c("trough", "peak_above")) %>%
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
  geom_text(data = ann %>% filter(role == "peak_above"),
            aes(x = lbl_x, y = lbl_y, label = label),
            family = chart_family, size = 3.0,
            color = pg_palette$alloy,
            hjust = 0.5, vjust = 0,
            lineheight = 0.95) +
  geom_text(data = ann %>% filter(role == "trough"),
            aes(x = lbl_x, y = lbl_y, label = label),
            family = chart_family, size = 3.0,
            color = pg_palette$heritage_red,
            hjust = 0, vjust = 1, fontface = "bold",
            lineheight = 0.95) +
  scale_x_date(expand = expansion(mult = c(0.10, 0.12))) +
  scale_y_continuous(limits = c(-2.0, 4.9),
                     expand = expansion(mult = c(0, 0))) +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = NULL) +
  theme_void(base_family = chart_family) +
  theme(plot.margin = margin(t = 10, r = 30, b = 8, l = 30))

out_pdf <- "iterations/task_07/v9/snb_rate_v9.pdf"
ggsave(out_pdf, p, width = 28, height = 9, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
