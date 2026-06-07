# Task 8 v13 — Partners Group 2024 income statement Sankey, Apple-style
# (cleaned up).
#
# v13 changes vs v12:
#   * Dropped the "Mgmt service revenues" subtotal at axis 2 — only 2
#     streams (Mgmt + Perf fees) flowed through it, the subtotal label
#     ended up buried inside the alluvium tangle, and the merge/split
#     across the subtotal created bad crossings. All four revenue
#     sources now flow directly into Revenue (one fewer axis).
#   * Inner subtotal labels (Revenue, Operating margin, Pre-tax profit,
#     Net profit) are now drawn ABOVE their stratum bars in **alloy**
#     for high contrast against the chart background — v12 had them in
#     copper-on-copper which read as low-contrast mush. Cascade is
#     still copper as a fill colour; only the text labels become alloy.
#   * Cost peel labels at axes 4-5 (Tax / D&A / Finance expense) get
#     vertical spacing nudges via per-stratum y-offsets so the three
#     small labels don't pile on top of each other.
#   * Source labels at axis 1 spread vertically — the smallest two
#     (Other op income, Finance income) get extra ymid offset so the
#     text doesn't collide.
#
# 6 axes (was 7 in v12):
#   1: Leaf revenue sources (Mgmt fees, Performance fees, Other op
#      income, Finance income)
#   2: Revenue (everything pools)
#   3: Operating margin (copper) / Operating costs (dark_stone)
#   4: Pre-tax profit (copper) / Other costs / Personnel (peel) /
#      Other op exp (peel)
#   5: Net profit (copper) / Tax (peel) / D&A (peel) / Finance
#      expense (peel) / [Personnel and Other op exp NA-terminate]
#   6: Dividend (copper bold) / Retained (light_quartz) / [all costs
#      NA-terminate]
#
# Palette (unchanged from v12):
#   Apple gray    -> alloy (sources, Revenue)
#   Apple green   -> copper (profit cascade)
#   Apple red     -> dark_stone (cost peels)
#   Final dividend punchline -> copper bold
#   Retained sliver -> light_quartz
#
# Data source: Partners Group Holding AG, Annual Report 2024,
#   Consolidated statement of profit or loss (page 39).
#   Local: data/task_08_pg/pg_income_statement_2024.csv

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
  library(ggalluvial)
})

source("design_system.R")
chart_family <- ""

# ---- Load + parse income statement ------------------------------------
is_raw <- read_csv("data/task_08_pg/pg_income_statement_2024.csv",
                   show_col_types = FALSE)

get <- function(name) {
  v <- is_raw %>% filter(line_item == name) %>% pull(chf_million)
  if (length(v) != 1) stop("Line item not found or duplicated: ", name)
  v
}

mgmt_fees    <- get("Management fees and other revenues")
perf_fees    <- get("Performance fees")
other_op_inc <- get("Other operating income")
finance_inc  <- get("Finance income")
personnel    <- abs(get("Personnel expenses"))
other_op_exp <- abs(get("Other operating expenses"))
da_amort     <- abs(get("Depreciation and amortization"))
finance_exp  <- abs(get("Finance expense"))
tax_exp      <- abs(get("Income tax expenses"))
profit       <- get("Profit for the period")
div_per_sh   <- get("Dividend per share (CHF)")
basic_eps    <- get("Basic earnings per share (CHF)")

weighted_basic_shares_m <- profit / basic_eps
dividend <- div_per_sh * weighted_basic_shares_m
retained <- profit - dividend

total_inflow      <- mgmt_fees + perf_fees + other_op_inc + finance_inc
operating_costs   <- personnel + other_op_exp
operating_margin  <- total_inflow - operating_costs
other_costs       <- da_amort + finance_exp
pretax_profit     <- operating_margin - other_costs

cat(sprintf("Total inflow:     %.1f CHF m\n", total_inflow))
cat(sprintf("Pre-tax profit:   %.1f CHF m  (reported: 1369.9)\n",
            pretax_profit))

# ---- Build path table -------------------------------------------------
sources <- tribble(
  ~src,               ~chf,
  "Mgmt fees",        mgmt_fees,
  "Performance fees", perf_fees,
  "Other op income",  other_op_inc,
  "Finance income",   finance_inc
)

destinations <- tribble(
  ~dest,             ~chf,
  "Personnel",       personnel,
  "Other op exp",    other_op_exp,
  "D&A",             da_amort,
  "Finance expense", finance_exp,
  "Tax",             tax_exp,
  "Dividend",        dividend,
  "Retained",        retained
)

paths <- crossing(src = sources$src, dest = destinations$dest) %>%
  left_join(sources      %>% rename(src_chf  = chf), by = "src") %>%
  left_join(destinations %>% rename(dest_chf = chf), by = "dest") %>%
  mutate(flow = src_chf * dest_chf / total_inflow)

# ---- Axis stratum assignment ------------------------------------------
ax3_for <- function(d) {
  if (d %in% c("Personnel", "Other op exp")) "Operating costs"
  else "Operating margin"
}
ax4_for <- function(d) {
  if (d == "Personnel")        "Personnel"
  else if (d == "Other op exp") "Other op exp"
  else if (d %in% c("D&A", "Finance expense")) "Other costs"
  else                          "Pre-tax profit"   # Tax / Dividend / Retained
}
ax5_for <- function(d) {
  if (d %in% c("Personnel", "Other op exp")) NA_character_
  else if (d %in% c("D&A", "Finance expense", "Tax")) d
  else                          "Net profit"        # Dividend / Retained
}
ax6_for <- function(d) {
  if (d %in% c("Dividend", "Retained")) d
  else NA_character_
}

paths <- paths %>%
  rowwise() %>%
  mutate(
    ax1 = src,
    ax2 = "Revenue",
    ax3 = ax3_for(dest),
    ax4 = ax4_for(dest),
    ax5 = ax5_for(dest),
    ax6 = ax6_for(dest)
  ) %>%
  ungroup()

# ---- Stratum factor levels (top to bottom at each axis) --------------
src_levels <- sources$src
ax2_levels <- "Revenue"
ax3_levels <- c("Operating margin", "Operating costs")
ax4_levels <- c("Pre-tax profit", "Other costs", "Personnel", "Other op exp")
ax5_levels <- c("Net profit", "Tax", "D&A", "Finance expense")
ax6_levels <- c("Dividend", "Retained")

paths <- paths %>%
  mutate(
    ax1 = factor(ax1, levels = src_levels),
    ax2 = factor(ax2, levels = ax2_levels),
    ax3 = factor(ax3, levels = ax3_levels),
    ax4 = factor(ax4, levels = ax4_levels),
    ax5 = factor(ax5, levels = ax5_levels),
    ax6 = factor(ax6, levels = ax6_levels),
    dest = factor(dest,
                  levels = c("Dividend", "Retained",
                             "Tax", "Finance expense", "D&A",
                             "Personnel", "Other op exp"))
  )

# ---- Colours ---------------------------------------------------------
all_fills <- c(
  # Inflow path: alloy (warm charcoal — neutral)
  "Mgmt fees"             = pg_palette$alloy,
  "Performance fees"      = pg_palette$alloy,
  "Other op income"       = pg_palette$alloy,
  "Finance income"        = pg_palette$alloy,
  "Revenue"               = pg_palette$alloy,
  # Profit path: copper (the portfolio accent)
  "Operating margin"      = pg_palette$copper,
  "Pre-tax profit"        = pg_palette$copper,
  "Net profit"            = pg_palette$copper,
  "Dividend"              = pg_palette$copper,
  # Cost path: dark_stone (warm gray, muted)
  "Operating costs"       = pg_palette$dark_stone,
  "Personnel"             = pg_palette$dark_stone,
  "Other op exp"          = pg_palette$dark_stone,
  "Other costs"           = pg_palette$dark_stone,
  "D&A"                   = pg_palette$dark_stone,
  "Finance expense"       = pg_palette$dark_stone,
  "Tax"                   = pg_palette$dark_stone,
  # Retained: light cream (the tiny "left over" sliver)
  "Retained"              = pg_palette$light_quartz
)

# ---- Helpers ---------------------------------------------------------
fmt_chf <- function(x) {
  ifelse(x >= 1000, sprintf("CHF %.2f bn", x / 1000),
                    sprintf("CHF %.0f m",  x))
}

# Y/Y growth rates (computed from page-39 2024 vs 2023 columns)
yoy <- c(
  "Mgmt fees"        = (mgmt_fees / 1487.2) - 1,
  "Performance fees" = (perf_fees /  369.4) - 1,
  "Other op income"  = (other_op_inc / 87.9) - 1,
  "Finance income"   = (finance_inc /  72.4) - 1,
  "Revenue"          = (total_inflow / (1487.2 + 369.4 + 87.9 + 72.4)) - 1,
  "Operating margin" = (operating_margin /
                          (1487.2 + 369.4 + 87.9 + 72.4 - 603.3 - 107.5)) - 1,
  "Operating costs"  = (operating_costs / (603.3 + 107.5)) - 1,
  "Pre-tax profit"   = (pretax_profit / 1208.6) - 1,
  "Net profit"       = (profit / 1003.4) - 1,
  "Personnel"        = (personnel / 603.3) - 1,
  "Other op exp"     = (other_op_exp / 107.5) - 1,
  "Other costs"      = (other_costs / (41.1 + 56.4)) - 1,
  "D&A"              = (da_amort / 41.1) - 1,
  "Finance expense"  = (finance_exp / 56.4) - 1,
  "Tax"              = (tax_exp / 205.2) - 1,
  "Dividend"         = (div_per_sh / 39.0) - 1
)

fmt_yoy <- function(name) {
  if (!name %in% names(yoy)) return("")
  sprintf("%+.0f%% Y/Y", 100 * yoy[[name]])
}

stratum_w <- 0.16

# ---- Base plot -------------------------------------------------------
p_base <- ggplot(paths,
                 aes(axis1 = ax1, axis2 = ax2, axis3 = ax3,
                     axis4 = ax4, axis5 = ax5, axis6 = ax6,
                     y = flow)) +
  geom_alluvium(aes(fill = dest),
                width = stratum_w, alpha = 0.78,
                knot.pos = 0.4, curve_type = "sigmoid",
                aes.bind = "alluvia") +
  geom_stratum(width = stratum_w,
               aes(fill = after_stat(stratum)),
               color = "white", linewidth = 0.25) +
  scale_fill_manual(values = all_fills, guide = "none") +
  scale_x_continuous(limits = c(0.5, 6.5), expand = c(0, 0)) +
  scale_y_continuous(expand = expansion(mult = c(0.04, 0.14))) +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = NULL) +
  theme_void(base_family = chart_family) +
  theme(plot.margin = margin(t = 10, r = 70, b = 8, l = 70))

# ---- Pull stratum positions for labels --------------------------------
gb <- ggplot_build(p_base)
strat_layer_idx <- which(sapply(gb$plot$layers,
                                function(l) inherits(l$stat,
                                                     "StatStratum")))[1]
strat_data <- gb$data[[strat_layer_idx]] %>%
  mutate(y_mid = (ymin + ymax) / 2)

top_y      <- max(strat_data$ymax)
gap_above  <- top_y * 0.025

# Inner subtotal labels — drawn ABOVE the stratum bar in alloy for
# contrast (v12 had these in copper, which fought the copper fill).
# Revenue (axis 2) sits highest of all subtotals because its stratum
# fills the entire vertical range; we still place the label above it.
inner_subtotals <- strat_data %>%
  filter((x == 2 & stratum == "Revenue") |
         (x == 3 & stratum == "Operating margin") |
         (x == 4 & stratum == "Pre-tax profit") |
         (x == 5 & stratum == "Net profit")) %>%
  mutate(
    x_lbl = x,
    y_lbl = pmin(ymax + gap_above, top_y * 1.07),
    label = sprintf("%s\n%s\n%s",
                    stratum, fmt_chf(count),
                    sapply(as.character(stratum), fmt_yoy)),
    color = pg_palette$alloy,
    face  = "bold"
  )

# Source labels (axis 1) — left of stratum, right-aligned.
ax1_labels <- strat_data %>%
  filter(x == 1) %>%
  mutate(
    x_lbl = 1 - stratum_w / 2 - 0.06,
    y_lbl = y_mid,
    label = sprintf("%s\n%s\n%s",
                    stratum, fmt_chf(count),
                    sapply(as.character(stratum), fmt_yoy)),
    color = pg_palette$alloy,
    face  = "plain"
  )

# Cost peels — right of stratum, left-aligned. Apply small vertical
# spacing nudges so adjacent small peels (D&A, Finance expense, Tax)
# don't overlap.
spread_y <- function(stratum_name, y) {
  case_when(
    stratum_name == "D&A"             ~ y - top_y * 0.02,
    stratum_name == "Finance expense" ~ y + top_y * 0.0,
    stratum_name == "Tax"             ~ y + top_y * 0.02,
    TRUE                              ~ y
  )
}

cost_peels <- strat_data %>%
  filter((x == 3 & stratum == "Operating costs") |
         (x == 4 & stratum %in% c("Other costs", "Personnel",
                                   "Other op exp")) |
         (x == 5 & stratum %in% c("D&A", "Finance expense", "Tax"))) %>%
  mutate(
    x_lbl = x + stratum_w / 2 + 0.05,
    y_lbl = spread_y(as.character(stratum), y_mid),
    label = sprintf("%s\n%s\n%s",
                    stratum, fmt_chf(count),
                    sapply(as.character(stratum), fmt_yoy)),
    color = pg_palette$alloy,
    face  = "plain"
  )

# Final allocation labels — right of stratum, left-aligned, BOLD.
# Dividend in copper (the punchline). Retained in alloy.
ax6_labels <- strat_data %>%
  filter(x == 6) %>%
  mutate(
    x_lbl = 6 + stratum_w / 2 + 0.05,
    y_lbl = y_mid,
    label = sprintf("%s\n%s\n%s",
                    stratum, fmt_chf(count),
                    sapply(as.character(stratum), fmt_yoy)),
    color = ifelse(stratum == "Dividend",
                   pg_palette$copper,
                   pg_palette$alloy),
    face  = "bold"
  )

# ---- Final plot ------------------------------------------------------
add_text <- function(plt, df, hjust, vjust = 0.5, size = 2.6) {
  if (nrow(df) == 0) return(plt)
  plt +
    geom_text(data = df,
              aes(x = x_lbl, y = y_lbl, label = label,
                  color = color, fontface = face),
              family = chart_family, size = size,
              hjust = hjust, vjust = vjust,
              lineheight = 0.95, inherit.aes = FALSE)
}

p <- p_base + scale_color_identity()
p <- add_text(p, ax1_labels,        hjust = 1)
p <- add_text(p, inner_subtotals,   hjust = 0.5, vjust = 0)
p <- add_text(p, cost_peels,        hjust = 0)
p <- add_text(p, ax6_labels,        hjust = 0)

out_pdf <- "iterations/task_08/v13/pg_income_sankey_v13.pdf"
ggsave(out_pdf, p, width = 36, height = 16, units = "cm",
       device = "pdf")
cat("\nSaved:", out_pdf, "\n")
