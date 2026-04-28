# Task 8 v1 — US Federal Budget Sankey, FY2025.
# Sankey is the canonical chart for flow data: where money comes from
# (six revenue sources + borrowing) and where it goes (nine spending
# functions). Two strata, balanced flows. The chart is the strongest
# answer to "is this the right chart type" because no forbidden type
# (bar/line/scatter/pie/etc.) can show source × destination flows
# simultaneously at scale-faithful widths.
#
# Source: U.S. Department of the Treasury, Bureau of the Fiscal Service,
# Monthly Treasury Statement, FY2025 final (record date 2025-09-30),
# MTS Table 9 ("Receipts and Outlays of the U.S. Government, by Function
# and Subfunction"), retrieved via the Fiscal Data API:
#   https://api.fiscaldata.treasury.gov/services/api/fiscal_service/
#     v1/accounting/mts/mts_table_9
# Local file: data/task_08/mts_table_9_fy2025.json.
#
# Numbers cross-check vs CBO Monthly Budget Review FY2025 final:
#   Outlays $7.01 T, Receipts $5.23 T, Deficit $1.78 T. ✓

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(ggalluvial)
})

source("design_system.R")

chart_family <- ""  # PDF-native fallback; see task_02 / task_05 / task_07 notes.

# ---- Numbers (billions of dollars, FY2025 final) -----------------------
# Receipts ($5,234.62 B) + Borrowing ($1,775 B) = Outlays ($7,009.97 B).
# Receipts collapsed to six sources for legibility; "Other receipts" =
# Excise + Estate & Gift + Miscellaneous (105.94 + 29.46 + 47.92 = 183.32).
sources <- tibble::tribble(
  ~source,                       ~amount,
  "Individual income tax",        2656,
  "Payroll tax",                  1748,
  "Corporate income tax",          452,
  "Customs duties",                195,
  "Other receipts",                183,
  "Borrowing",                    1776   # plug to 7010
)

# Uses: nine spending functions. "Other" = sum of the eleven small
# functions that each total < $150 B (International Affairs, Science,
# Energy, Natural Resources, Agriculture, Commerce/Housing, Community
# Dev, Education, Justice, General Govt, Undistributed Offsetting Rcpts).
uses <- tibble::tribble(
  ~use,                          ~amount,
  "Social Security",              1581,
  "Medicare",                      997,
  "Health (incl. Medicaid)",       979,
  "National Defense",              917,
  "Net Interest",                  970,
  "Income Security",               702,
  "Veterans benefits",             377,
  "Transportation",                146,
  "Other functions",               341
)

stopifnot(sum(sources$amount) == sum(uses$amount))
total <- sum(sources$amount)
cat("Total flow:", total, "B (FY2025 outlays)\n")

# ---- Build flow table --------------------------------------------------
# Each (source, use) flow = (source's share of total) × (use's amount).
# Money is fungible, so this is the honest visual rendering of "X% of
# the budget came from S and went to U". Row sums = source amounts;
# column sums = use amounts (verified below).
flows <- tidyr::expand_grid(
    source = sources$source,
    use    = uses$use
  ) %>%
  left_join(sources, by = "source") %>%
  rename(src_amt = amount) %>%
  left_join(uses, by = "use") %>%
  rename(use_amt = amount) %>%
  mutate(flow = src_amt * use_amt / total)

# Sanity checks
src_sum <- flows %>% group_by(source) %>% summarise(s = sum(flow), .groups = "drop")
use_sum <- flows %>% group_by(use)    %>% summarise(s = sum(flow), .groups = "drop")
stopifnot(all(abs(src_sum$s - sources$amount[match(src_sum$source, sources$source)]) < 0.01))
stopifnot(all(abs(use_sum$s - uses$amount[match(use_sum$use, uses$use)])         < 0.01))

# ---- Order the strata --------------------------------------------------
# Sources: largest at top, Borrowing pinned at the bottom (it's the
# regime-change item — visually distinct + Heritage Red).
src_order <- c(
  "Individual income tax", "Payroll tax", "Corporate income tax",
  "Customs duties", "Other receipts", "Borrowing"
)
# Uses: largest at top, "Other functions" pinned at the bottom.
use_order <- c(
  "Social Security", "Medicare", "Health (incl. Medicaid)",
  "Net Interest", "National Defense", "Income Security",
  "Veterans benefits", "Transportation", "Other functions"
)

flows <- flows %>%
  mutate(
    source = factor(source, levels = rev(src_order)),
    use    = factor(use,    levels = rev(use_order))
  )

# ---- Color scheme ------------------------------------------------------
# Bands colored by source. Heritage Red is reserved for "Borrowing" only —
# the single preattentive cue (per portfolio rule: red = the one thing the
# reader must see). Every other source is a neutral PG palette token.
src_colors <- c(
  "Individual income tax" = pg_palette$onyx,
  "Payroll tax"           = pg_palette$alloy,
  "Corporate income tax"  = pg_palette$copper,
  "Customs duties"        = pg_palette$dark_stone,
  "Other receipts"        = pg_palette$dark_quartz,
  "Borrowing"             = pg_palette$heritage_red
)

# Stratum bars: neutral onyx, label inside white. Net Interest gets a
# Heritage-Red stratum bar — the second preattentive cue, marking the
# story (interest > defense for the first time).
use_stratum_fill <- setNames(rep(pg_palette$onyx, length(use_order)), use_order)
use_stratum_fill["Net Interest"] <- pg_palette$heritage_red
src_stratum_fill <- setNames(rep(pg_palette$onyx, length(src_order)), src_order)
src_stratum_fill["Borrowing"]    <- pg_palette$heritage_red
stratum_fill <- c(src_stratum_fill, use_stratum_fill)

# ---- Plot --------------------------------------------------------------
# Stratum width 1/4 keeps the bars slim; alpha 0.55 lets overlapping
# bands separate visually without losing color identity.
fmt_b <- function(x) {
  ifelse(x >= 1000,
         sprintf("$%.2f T", x / 1000),
         sprintf("$%d B", round(x)))
}

# Label tibbles — value labels sit just outside the bars (right of source
# stratum, left of use stratum) so they read as "<NAME>  <VALUE>" pairs.
src_labels <- sources %>%
  mutate(source = factor(source, levels = rev(src_order))) %>%
  mutate(y_mid = {
    o <- match(source, rev(src_order))
    cum <- cumsum(amount[order(o)])
    midpoints <- cum - amount[order(o)] / 2
    midpoints[order(order(o))]
  })

use_labels <- uses %>%
  mutate(use = factor(use, levels = rev(use_order))) %>%
  mutate(y_mid = {
    o <- match(use, rev(use_order))
    cum <- cumsum(amount[order(o)])
    midpoints <- cum - amount[order(o)] / 2
    midpoints[order(order(o))]
  })

p <- ggplot(flows,
            aes(axis1 = source, axis2 = use, y = flow)) +
  geom_alluvium(aes(fill = source),
                width = 1/4, alpha = 0.55,
                knot.pos = 0.4, curve_type = "sigmoid") +
  geom_stratum(width = 1/4,
               aes(fill = after_stat(stratum)),
               color = NA) +
  scale_fill_manual(values = c(src_colors, stratum_fill),
                    guide = "none") +
  # Source labels (left side): name + value, right-aligned outside the bar.
  geom_text(data = src_labels,
            aes(x = 1 - 1/4/2 - 0.02, y = y_mid,
                label = paste0(source, "   ", fmt_b(amount))),
            inherit.aes = FALSE,
            family = chart_family, size = 3.0,
            color = pg_palette$alloy,
            hjust = 1, vjust = 0.5) +
  # Use labels (right side): name + value, left-aligned outside the bar.
  geom_text(data = use_labels,
            aes(x = 2 + 1/4/2 + 0.02, y = y_mid,
                label = paste0(fmt_b(amount), "   ", use)),
            inherit.aes = FALSE,
            family = chart_family, size = 3.0,
            color = pg_palette$alloy,
            hjust = 0, vjust = 0.5) +
  # Headline annotation — the story. Positioned to the right of the
  # Net Interest stratum, leader-free because the red bar carries the eye.
  annotate("text",
           x = 2 + 1/4/2 + 0.55,
           y = use_labels$y_mid[use_labels$use == "Net Interest"],
           label = "Net interest now exceeds\nthe defense budget.",
           family = chart_family, size = 3.1,
           color = pg_palette$heritage_red,
           fontface = "bold",
           hjust = 0, vjust = 0.5,
           lineheight = 0.95) +
  # Headline annotation #2 — the borrowing story.
  annotate("text",
           x = 1 - 1/4/2 - 0.55,
           y = use_labels$y_mid[1] -  # roughly aligned with bottom band
                use_labels$amount[use_labels$use == "Other functions"] / 2 -
                use_labels$amount[use_labels$use == "Transportation"] / 2,
           label = "$1 of every $4 spent\nwas borrowed.",
           family = chart_family, size = 3.1,
           color = pg_palette$heritage_red,
           fontface = "bold",
           hjust = 1, vjust = 0.5,
           lineheight = 0.95) +
  # Axis labels (the two columns).
  annotate("text", x = 1, y = total + 220,
           label = "WHERE IT CAME FROM",
           family = chart_family, size = 3.2, fontface = "bold",
           color = pg_palette$onyx, hjust = 0.5) +
  annotate("text", x = 2, y = total + 220,
           label = "WHERE IT WENT",
           family = chart_family, size = 3.2, fontface = "bold",
           color = pg_palette$onyx, hjust = 0.5) +
  scale_x_continuous(limits = c(-0.6, 3.6), expand = c(0, 0)) +
  scale_y_continuous(expand = expansion(mult = c(0.02, 0.07))) +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = NULL) +
  theme_void(base_family = chart_family) +
  theme(plot.margin = margin(t = 14, r = 14, b = 8, l = 14))

out_pdf <- "iterations/task_08/v1/budget_sankey_v1.pdf"
ggsave(out_pdf, p, width = 30, height = 17, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
