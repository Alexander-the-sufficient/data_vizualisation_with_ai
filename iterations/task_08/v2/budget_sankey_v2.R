# Task 8 v2 — US Federal Budget Sankey, FY2025.
#
# Changes from v1:
#   * Stratum y-positions now extracted from ggplot_build() so labels
#     are guaranteed to align with the rendered bars (v1 had labels
#     pinned at hand-computed y-values that didn't match ggalluvial's
#     internal level ordering).
#   * Color scheme reduced from six source-hues to a one-color story:
#     Heritage Red marks the two storied flows (Borrowing on the in-
#     side, Net Interest on the out-side); every other flow is dark
#     quartz neutral. Removes v1's visual chaos and isolates the story.
#   * Both story callouts anchor to the actual stratum mid-y values.
#
# Source: U.S. Department of the Treasury, Bureau of the Fiscal Service,
# Monthly Treasury Statement, FY2025 final (record date 2025-09-30),
# MTS Table 9, retrieved via the Fiscal Data API:
#   https://api.fiscaldata.treasury.gov/services/api/fiscal_service/
#     v1/accounting/mts/mts_table_9
# Local file: data/task_08/mts_table_9_fy2025.json.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(ggalluvial)
})

source("design_system.R")

chart_family <- ""  # PDF-native fallback; see task_07 notes.

# ---- Numbers (billions of dollars, FY2025 final) -----------------------
sources <- tibble::tribble(
  ~source,                       ~amount,
  "Individual income tax",        2656,
  "Payroll tax",                  1748,
  "Corporate income tax",          452,
  "Customs duties",                195,
  "Other receipts",                183,
  "Borrowing",                    1776
)

uses <- tibble::tribble(
  ~use,                          ~amount,
  "Social Security",              1581,
  "Medicare",                      997,
  "Health (incl. Medicaid)",       979,
  "Net Interest",                  970,
  "National Defense",              917,
  "Income Security",               702,
  "Veterans benefits",             377,
  "Transportation",                146,
  "Other functions",               341
)

stopifnot(sum(sources$amount) == sum(uses$amount))
total <- sum(sources$amount)
cat("Total flow:", total, "B (FY2025 outlays)\n")

# ---- Build flow table --------------------------------------------------
flows <- tidyr::expand_grid(
    source = sources$source,
    use    = uses$use
  ) %>%
  left_join(sources, by = "source") %>%
  rename(src_amt = amount) %>%
  left_join(uses, by = "use") %>%
  rename(use_amt = amount) %>%
  mutate(flow = src_amt * use_amt / total)

# Sanity check: row sums = source amounts; col sums = use amounts.
src_check <- flows %>% group_by(source) %>% summarise(s = sum(flow), .groups = "drop") %>%
  left_join(sources, by = "source") %>% mutate(diff = s - amount)
use_check <- flows %>% group_by(use) %>% summarise(s = sum(flow), .groups = "drop") %>%
  left_join(uses, by = "use") %>% mutate(diff = s - amount)
stopifnot(all(abs(src_check$diff) < 0.01))
stopifnot(all(abs(use_check$diff) < 0.01))

# ---- Order strata so the largest sits at the TOP -----------------------
# stat_stratum stacks factor levels with level 1 at the TOP (high y) and
# the last level at the BOTTOM. So the editorial top-to-bottom order IS
# the factor level order — no reversal.
src_levels_top_first <- c(
  "Individual income tax", "Payroll tax", "Corporate income tax",
  "Customs duties", "Other receipts", "Borrowing"
)
use_levels_top_first <- c(
  "Social Security", "Medicare", "Health (incl. Medicaid)",
  "Net Interest", "National Defense", "Income Security",
  "Veterans benefits", "Transportation", "Other functions"
)
flows <- flows %>%
  mutate(
    source = factor(source, levels = src_levels_top_first),
    use    = factor(use,    levels = use_levels_top_first)
  )

# ---- Color scheme (story-driven) ---------------------------------------
# One neutral stone for every "ordinary" flow. Heritage Red marks the
# two flows the reader must see immediately:
#   * In-side:  every band that originates from "Borrowing".
#   * Out-side: every band that terminates at "Net Interest".
flows <- flows %>%
  mutate(storyflow = factor(case_when(
    source == "Borrowing"     ~ "Borrowing",
    use    == "Net Interest"  ~ "Net Interest",
    TRUE                      ~ "Other"
  ), levels = c("Other", "Net Interest", "Borrowing")))

# Sort so the gray flows draw first and red flows draw on top —
# preattentive emphasis. ggalluvial draws rows in input order.
flows <- flows %>% arrange(storyflow)

flow_colors <- c(
  "Other"        = pg_palette$dark_quartz,
  "Net Interest" = pg_palette$heritage_red,
  "Borrowing"    = pg_palette$heritage_red
)

# Stratum bars: dark for everything; red for the two story strata.
stratum_fill <- setNames(
  rep(pg_palette$onyx,
      length(src_levels_top_first) + length(use_levels_top_first)),
  c(src_levels_top_first, use_levels_top_first)
)
stratum_fill["Borrowing"]    <- pg_palette$heritage_red
stratum_fill["Net Interest"] <- pg_palette$heritage_red

# ---- Helpers -----------------------------------------------------------
fmt_b <- function(x) {
  ifelse(x >= 1000,
         sprintf("$%.2f T", x / 1000),
         sprintf("$%d B", round(x)))
}

# ---- Base plot (no labels yet — we need rendered stratum positions) ----
stratum_w <- 1/4

p_base <- ggplot(flows,
                 aes(axis1 = source, axis2 = use, y = flow)) +
  geom_alluvium(aes(fill = storyflow),
                width = stratum_w, alpha = 0.75,
                knot.pos = 0.4, curve_type = "sigmoid") +
  geom_stratum(width = stratum_w,
               aes(fill = after_stat(stratum)),
               color = NA) +
  scale_fill_manual(values = c(flow_colors, stratum_fill),
                    guide = "none") +
  scale_x_continuous(limits = c(-0.6, 3.6), expand = c(0, 0)) +
  scale_y_continuous(expand = expansion(mult = c(0.02, 0.07))) +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = NULL) +
  theme_void(base_family = chart_family) +
  theme(plot.margin = margin(t = 14, r = 14, b = 8, l = 14))

# ---- Pull actual stratum positions from the rendered build ------------
gb <- ggplot_build(p_base)
strat_layer_idx <- which(sapply(gb$plot$layers,
                                function(l) inherits(l$stat, "StatStratum")))[1]
strat_data <- gb$data[[strat_layer_idx]] %>%
  mutate(y_mid = (ymin + ymax) / 2)

src_pos <- strat_data %>% filter(x == 1)
use_pos <- strat_data %>% filter(x == 2)

src_labels <- src_pos %>%
  transmute(
    x  = 1 - stratum_w / 2 - 0.02,
    y  = y_mid,
    label = paste0(stratum, "   ", fmt_b(count))
  )

use_labels <- use_pos %>%
  transmute(
    x  = 2 + stratum_w / 2 + 0.02,
    y  = y_mid,
    label = paste0(fmt_b(count), "   ", stratum)
  )

borrowing_y    <- src_pos$y_mid[src_pos$stratum == "Borrowing"]
net_interest_y <- use_pos$y_mid[use_pos$stratum == "Net Interest"]

# ---- Final plot with labels + callouts --------------------------------
p <- p_base +
  geom_text(data = src_labels, aes(x = x, y = y, label = label),
            family = chart_family, size = 3.0, color = pg_palette$alloy,
            hjust = 1, vjust = 0.5, inherit.aes = FALSE) +
  geom_text(data = use_labels, aes(x = x, y = y, label = label),
            family = chart_family, size = 3.0, color = pg_palette$alloy,
            hjust = 0, vjust = 0.5, inherit.aes = FALSE) +
  # Column headers
  annotate("text", x = 1, y = total + 250,
           label = "WHERE IT CAME FROM",
           family = chart_family, size = 3.2, fontface = "bold",
           color = pg_palette$onyx, hjust = 0.5) +
  annotate("text", x = 2, y = total + 250,
           label = "WHERE IT WENT",
           family = chart_family, size = 3.2, fontface = "bold",
           color = pg_palette$onyx, hjust = 0.5) +
  # Story callouts — anchored to actual stratum y-positions.
  annotate("text",
           x = 1 - stratum_w / 2 - 0.55,
           y = borrowing_y,
           label = "$1 of every $4 spent\nwas borrowed.",
           family = chart_family, size = 3.1,
           color = pg_palette$heritage_red,
           fontface = "bold",
           hjust = 1, vjust = 0.5,
           lineheight = 0.95) +
  annotate("text",
           x = 2 + stratum_w / 2 + 0.55,
           y = net_interest_y,
           label = "Net interest now exceeds\nthe defense budget.",
           family = chart_family, size = 3.1,
           color = pg_palette$heritage_red,
           fontface = "bold",
           hjust = 0, vjust = 0.5,
           lineheight = 0.95)

out_pdf <- "iterations/task_08/v2/budget_sankey_v2.pdf"
ggsave(out_pdf, p, width = 30, height = 17, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
cat("Borrowing y    =", borrowing_y, "\n")
cat("Net Interest y =", net_interest_y, "\n")
