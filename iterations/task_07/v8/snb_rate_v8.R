# Task 7 v8 — SNB policy rate, 2000-2026 (Tufte data-ink rigor).
# v8 fixes a callout-consistency problem in v7: the two high-side labels
#   ("3.50% pre-GFC high / Jun 2000" and "2007: 2.75%") sat RIGHT AGAINST
#   the data line (tiny ~0.12 vertical gap, leader length ~0), while the
#   other two callouts ("1.75% Jun 2023" and "-0.75% trough Jan 2015")
#   were pulled clearly OFF the line into open space with a visible thin
#   leader. v8 makes all four interior callouts consistent: the 3.50% and
#   the 2007/2.75% labels are now offset into clear space ABOVE their data
#   points, each connected back to its point by a thin short leader of the
#   same weight (linewidth 0.2, alloy) the Jun-2023 / trough callouts use.
#   The y-limit is raised (top to 4.9) so the lifted labels + their leaders
#   have headroom and nothing clips.
#
#   Everything else is kept exactly as in v7:
#     * 3.50% is the true pre-GFC HIGH marker (series maximum, held
#       Jun 2000 - Feb 2001), anchored at the plateau midpoint (~2000-10).
#     * 2007 (2.75%) stays a clearly-secondary, muted dark_stone landmark
#       — plainly "2007: 2.75%", no "peak" wording.
#     * the -0.75% Jan 2015 trough stays the single heritage-red accent
#       (the one preattentive cue for the most extreme value).
#     * the 1.75% Jan 2000 left-endpoint and 0.00% Mar 2026 right-endpoint
#       labels are unchanged.
#     * the data-ink-minimal sparkline: no axes, ticks, gridlines, border,
#       or legend.
#
# v7 fixed a factual/annotation error in v6 (v6 labelled the 2007 point as
#   "the pre-GFC peak"; the true series maximum is 3.50%). v6 switched the
#   line + endpoint/peak markers from onyx to alloy. v5 added the 1.75%
#   (Jun 2023) post-NIRP peak annotation. v4 dropped two inferred-event
#   annotations. v3 was the design-system palette migration.
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

# Label positions. The four INTERIOR callouts (peak high, 2007 landmark,
# Jun-2023 peak, Jan-2015 trough) are now all OFFSET from the line into
# clear space and connected by a thin leader — consistent treatment.
#   * 3.50% high: lifted to 4.55 (line top is 3.50) -> ~1.05 of headroom.
#   * 2007/2.75%: lifted to 3.35 (line top here 2.75) -> sits clearly above
#     the line but below the 3.50% label, preserving the visual hierarchy.
#   * 1.75% Jun 2023: 2.45 (unchanged in spirit; clear-space above).
#   * -0.75% trough: -1.55 (unchanged; clear-space below).
ann <- tibble::tribble(
  ~date,                  ~rate,  ~label,                          ~lbl_x,                   ~lbl_y,  ~role,
  as.Date("2000-01-15"),   1.75,  "1.75%  Jan 2000",               as.Date("1999-09-15"),     1.75,   "endpoint_left",
  peak_date,               3.50,  "3.50% pre-GFC high\nJun 2000",  peak_date,                 4.55,   "peak_above",
  as.Date("2007-09-15"),   2.75,  "2007: 2.75%",                   as.Date("2007-09-15"),     3.40,   "landmark_above",
  as.Date("2015-01-15"),  -0.75,  "-0.75% trough\nJan 2015",       as.Date("2015-02-15"),    -1.55,   "trough",
  as.Date("2023-06-15"),   1.75,  "1.75%  Jun 2023",               as.Date("2023-06-15"),     2.45,   "peak_above",
  as.Date("2026-03-15"),   0.00,  "0.00%  Mar 2026",               as.Date("2026-06-15"),     0.00,   "endpoint_right"
)

# Leaders: thin short connector from each offset label back to its data
# point. `gap_y` is the breathing space left between the label glyph and
# the near end of the leader so the line never touches the text.
gap_y <- 0.18
leaders <- ann %>%
  filter(role %in% c("event_above", "trough", "peak_above", "landmark_above")) %>%
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
            hjust = 0.5, vjust = 0,
            lineheight = 0.95) +
  geom_text(data = ann %>% filter(role == "landmark_above"),
            aes(x = lbl_x, y = lbl_y, label = label),
            family = chart_family, size = 2.7,
            color = pg_palette$dark_stone,
            hjust = 0.5, vjust = 0) +
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

out_pdf <- "iterations/task_07/v8/snb_rate_v8.pdf"
ggsave(out_pdf, p, width = 28, height = 9, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
