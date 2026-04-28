# Task 7 v4 — SNB policy rate, 2000-2026 (Tufte data-ink rigor).
# v4 changes vs v3: dropped two of the six annotations.
#   * "NIRP introduced Dec 2014" — removed. The line itself shows a
#     sharp downward step at end-2014 from positive to negative
#     territory; calling it out adds redundant ink for an event the
#     shape already conveys.
#   * "Exit Sep 2022" — removed. Same reason: the line jumps visibly
#     from -0.25% to +0.50% in September 2022, and the upward break
#     is self-evident. The label sat above the zero line which read
#     visually awkward (NIRP exit annotated *above* the negative-rate
#     story).
#   The four remaining anchors are all data extremes or endpoints of
#   the visible series: start (Jan 2000, 1.75%), pre-GFC peak (Sep 2007,
#   2.75%), trough (Jan 2015, -0.75%), end (Mar 2026, 0.00%). Tufte's
#   rule: every label should mark a data fact the eye can't read off
#   the line. Regime-change events are inferred from the shape;
#   extremes are not.
#
# v3 changes vs v2: design-system palette migration only. The trough dot
#   and label still pull from `pg_palette$heritage_red`, which under the
#   v4 palette is now the actual PG brand red (#D92B2B) instead of v3's
#   deep sage. The trough is one observation out of 315 (~0.3% of the
#   chart's ink) and is the most extreme value in the series — the
#   canonical "highlight one extreme value in red" usage that the new
#   colour discipline explicitly endorses.
#
# v2 changes vs v1:
#   * Added pre-GFC peak (2.75% Sep 2007) as an inline-above anchor so the
#     chart's full vertical range earns a label, and the post-NIRP +1.75%
#     bump reads as a partial recovery to a lower-high (not an all-time peak).
#   * Title/subtitle rewritten in the Quarto file (the previous wording
#     implied a continuous below-zero stretch ending at zero, which the line
#     contradicts — the rate hiked to +1.75% between exit and the 2026 cut).
#
# Sparkline-style: no axes, no ticks, no gridlines, no border, no legend.
# The line + 6 annotations carry every piece of information.
# Heritage Red is used exactly once (the -0.75% trough) as the single
# preattentive cue. Faint zero reference is the only non-line ink, and
# it is data-relevant: the rate crosses zero twice.
#
# Source: Swiss National Bank, "Official rates of the SNB" cube `snboffzisa`,
# data portal data.snb.ch. Splice: LIBOR target band mid (UG0+OG0)/2 for
# pre-Jun-2019 + SNB Leitzins (LZ) for Jun-2019 onward. The SNB itself
# treats this as one continuous policy-rate history.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(ggplot2)
})

source("design_system.R")

chart_family <- ""  # PDF-native fallback; see task_02 / task_05 notes.

# Read the SNB CSV. The file has 3 metadata rows + a UTF-8 BOM above
# the actual column header (`Date;D0;Value`), so skip = 3 lets readr
# pick up the header on the next line.
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

# Splice the two series.
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

# Annotation table. Each row corresponds to a single data point on the line.
# Endpoint labels sit inline with the data value (Tufte's sparkline pattern):
# label x-offset is to the left of the start point and to the right of the
# end point, label y is the rate value itself, so the labels never overlap
# the line. Event and trough labels sit off the line, anchored by faint
# leader segments. Five annotations, each one earns its place:
#   - start anchor (where the chart begins)
#   - NIRP introduction (regime change)
#   - trough (extreme value, the story)
#   - exit from negative rates (regime change)
#   - end anchor (where the chart ends)
ann <- tibble::tribble(
  ~date,                  ~rate,  ~label,                       ~lbl_x,                   ~lbl_y,  ~role,
  as.Date("2000-01-15"),   1.75,  "1.75%  Jan 2000",            as.Date("1999-09-15"),     1.75,   "endpoint_left",
  as.Date("2007-09-15"),   2.75,  "2.75%  Sep 2007",            as.Date("2007-09-15"),     3.30,   "peak_above",
  as.Date("2015-01-15"),  -0.75,  "-0.75% trough\nJan 2015",    as.Date("2015-02-15"),    -1.55,   "trough",
  as.Date("2026-03-15"),   0.00,  "0.00%  Mar 2026",            as.Date("2026-06-15"),     0.00,   "endpoint_right"
)

# Faint leader lines from data point to label. Stop the leader short of
# the label (gap_y) so the leader and text don't kiss.
gap_y <- 0.18
leaders <- ann %>%
  filter(role %in% c("event_above", "trough", "peak_above")) %>%
  mutate(x = date, xend = date, y = rate,
         yend = lbl_y - ifelse(lbl_y > rate, gap_y, -gap_y))

p <- ggplot(policy, aes(x = date, y = rate)) +
  # 1) Faint zero reference. The rate crosses this twice — data-relevant.
  #    Drawn only over the data range so it doesn't strike through the
  #    end-of-series label that sits at y = 0.
  annotate("segment",
           x = min(policy$date), xend = max(policy$date),
           y = 0, yend = 0,
           color = pg_palette$dark_quartz, linewidth = 0.25) +
  # 2) Leader lines (very thin, alloy gray) from data point to off-line labels.
  geom_segment(data = leaders,
               aes(x = x, xend = xend, y = y, yend = yend),
               color = pg_palette$alloy, linewidth = 0.2,
               inherit.aes = FALSE) +
  # 3) The data line.
  geom_line(color = pg_palette$onyx, linewidth = 0.55) +
  # 4) Markers at annotated points (small filled dots).
  geom_point(data = ann %>% filter(!role %in% c("trough")),
             aes(x = date, y = rate),
             color = pg_palette$onyx, size = 1.3) +
  geom_point(data = ann %>% filter(role == "trough"),
             aes(x = date, y = rate),
             color = pg_palette$heritage_red, size = 1.7) +
  # 5) Endpoint label, left side (start of series). hjust = 1 right-aligns
  #    the text so it sits to the LEFT of lbl_x, clearing the rising line.
  geom_text(data = ann %>% filter(role == "endpoint_left"),
            aes(x = lbl_x, y = lbl_y, label = label),
            family = chart_family, size = 3.0,
            color = pg_palette$alloy,
            hjust = 1, vjust = 0.5) +
  # 6) Endpoint label, right side (end of series). hjust = 0 left-aligns
  #    the text so it sits to the RIGHT of the end point.
  geom_text(data = ann %>% filter(role == "endpoint_right"),
            aes(x = lbl_x, y = lbl_y, label = label),
            family = chart_family, size = 3.0,
            color = pg_palette$alloy,
            hjust = 0, vjust = 0.5) +
  # 7) Event labels above the line (NIRP intro, exit).
  geom_text(data = ann %>% filter(role == "event_above"),
            aes(x = lbl_x, y = lbl_y, label = label),
            family = chart_family, size = 2.9,
            color = pg_palette$alloy,
            hjust = 0.5, vjust = 0,
            lineheight = 0.95) +
  # 7b) Pre-GFC peak label (above the line).
  geom_text(data = ann %>% filter(role == "peak_above"),
            aes(x = lbl_x, y = lbl_y, label = label),
            family = chart_family, size = 3.0,
            color = pg_palette$alloy,
            hjust = 0.5, vjust = 0) +
  # 8) Trough label (red, the single preattentive emphasis).
  geom_text(data = ann %>% filter(role == "trough"),
            aes(x = lbl_x, y = lbl_y, label = label),
            family = chart_family, size = 3.0,
            color = pg_palette$heritage_red,
            hjust = 0, vjust = 1, fontface = "bold",
            lineheight = 0.95) +
  # Coordinate system: pad x generously on both sides for inline labels,
  # pad y enough that off-line callouts don't clip.
  # `clip = "off"` lets endpoint labels extend past the panel bounds
  # without being cut by ggplot's default panel clipping.
  scale_x_date(expand = expansion(mult = c(0.10, 0.12))) +
  scale_y_continuous(limits = c(-2.0, 3.7),
                     expand = expansion(mult = c(0, 0))) +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = NULL) +
  theme_void(base_family = chart_family) +
  # Generous side margins because clip = "off" lets labels reach the page edge.
  theme(plot.margin = margin(t = 8, r = 30, b = 8, l = 30))

out_pdf <- "iterations/task_07/v4/snb_rate_v4.pdf"
ggsave(out_pdf, p, width = 28, height = 9, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
