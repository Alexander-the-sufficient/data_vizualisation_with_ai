# Task 8 v15 — Partners Group 2024 income statement Sankey, Apple-style,
# revenue broken down by INVESTMENT STRATEGY.
#
# v15 changes vs v14:
#   * Left-side source nodes switched from income-statement lines (Mgmt
#     fees, Performance fees, Other op income, Finance income) to
#     INVESTMENT STRATEGIES (Private equity, Private credit,
#     Infrastructure, Real estate, Royalties) plus "Other op income"
#     and "Finance income" as the two firm-level streams that aren't
#     strategy-tied.
#   * Per-strategy revenue is computed as: management-fees-pro-rated-
#     by-AuM-share + performance-fees-by-strategy. Performance fees by
#     asset class are published in the report (page 25); management
#     fees by asset class are NOT published, so the AuM-pro-rata is an
#     analyst-style approximation. Disclosed in the chart's source
#     caption.
#   * Numerical breakdown (CHF m, 2024):
#       Private equity     1103.4   (mgmt 768 + perf 335)
#       Infrastructure      391.3   (mgmt 271 + perf 120)
#       Private credit      360.9   (mgmt 312 + perf  49)
#       Real estate         161.5   (mgmt 154 + perf   7)
#       Royalties             2.0   (mgmt   2 + perf   0; new asset class
#                                    launched 2024, USD 0.2 bn AuM)
#       Other op income     117.3   (firm-level, not strategy-tied)
#       Finance income      120.9   (firm-level, not strategy-tied)
#       --------------------------
#       Total              2257.3
#   * Cascade from Revenue rightward is IDENTICAL to v14 — the user
#     explicitly asked to keep that structure. Same colours, same
#     stratum names, same NA-termination of cost peels.
#   * Y/Y growth rates removed from source-stratum labels (per-strategy
#     mgmt fees not published for 2023, so honest Y/Y can't be
#     computed). Y/Y stays on the inner subtotals (Revenue, Operating
#     margin, Pre-tax profit, Net profit) and Dividend.
#
# Data source: Partners Group Holding AG, Annual Report 2024.
#   - Income-statement lines: page 39 (Consolidated statement of profit
#     or loss).
#   - AuM by asset class:    page 16.
#   - Performance fees by asset class: page 25.
#   Local CSV: data/task_08_pg/pg_income_statement_2024.csv

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

# AuM by strategy (USD bn) and Performance fees by strategy (CHF m)
aum_pe        <- get("AuM Private equity (USD bn)")
aum_pc        <- get("AuM Private credit (USD bn)")
aum_infra     <- get("AuM Infrastructure (USD bn)")
aum_re        <- get("AuM Real estate (USD bn)")
aum_royalties <- get("AuM Royalties (USD bn)")
aum_total     <- get("AuM total (USD bn)")

perf_pe        <- get("Performance fees Private equity")
perf_pc        <- get("Performance fees Private credit")
perf_infra     <- get("Performance fees Infrastructure")
perf_re        <- get("Performance fees Real estate")
perf_royalties <- get("Performance fees Royalties")

# Per-strategy revenue = (management fees pro-rated by AuM share) +
# performance fees by strategy. Mgmt fees by strategy aren't published;
# this is the standard analyst approximation.
strategy_rev <- function(aum, perf) {
  mgmt_fees * (aum / aum_total) + perf
}

rev_pe        <- strategy_rev(aum_pe,        perf_pe)
rev_pc        <- strategy_rev(aum_pc,        perf_pc)
rev_infra     <- strategy_rev(aum_infra,     perf_infra)
rev_re        <- strategy_rev(aum_re,        perf_re)
rev_royalties <- strategy_rev(aum_royalties, perf_royalties)

weighted_basic_shares_m <- profit / basic_eps
dividend <- div_per_sh * weighted_basic_shares_m
retained <- profit - dividend

total_inflow      <- mgmt_fees + perf_fees + other_op_inc + finance_inc
operating_costs   <- personnel + other_op_exp
operating_margin  <- total_inflow - operating_costs
other_costs       <- da_amort + finance_exp
pretax_profit     <- operating_margin - other_costs

cat(sprintf("Sum of strategy revenues:   %.1f CHF m\n",
            rev_pe + rev_pc + rev_infra + rev_re + rev_royalties))
cat(sprintf("Mgmt fees + Perf fees:      %.1f CHF m\n",
            mgmt_fees + perf_fees))
cat(sprintf("Total inflow:               %.1f CHF m\n", total_inflow))

# ---- Build path table -------------------------------------------------
sources <- tribble(
  ~src,                ~chf,
  "Private equity",    rev_pe,
  "Infrastructure",    rev_infra,
  "Private credit",    rev_pc,
  "Real estate",       rev_re,
  "Other op income",   other_op_inc,
  "Finance income",    finance_inc,
  "Royalties",         rev_royalties
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

# ---- Axis stratum assignment (identical to v14) ----------------------
ax3_for <- function(d) {
  if (d %in% c("Personnel", "Other op exp")) "Operating costs"
  else "Operating margin"
}
ax4_for <- function(d) {
  if (d == "Personnel")        "Personnel"
  else if (d == "Other op exp") "Other op exp"
  else if (d %in% c("D&A", "Finance expense")) "Other costs"
  else                          "Pre-tax profit"
}
ax5_for <- function(d) {
  if (d %in% c("Personnel", "Other op exp")) NA_character_
  else if (d %in% c("D&A", "Finance expense", "Tax")) d
  else                          "Net profit"
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
  # All 7 source streams: alloy (warm charcoal — neutral inflow)
  "Private equity"   = pg_palette$alloy,
  "Infrastructure"   = pg_palette$alloy,
  "Private credit"   = pg_palette$alloy,
  "Real estate"      = pg_palette$alloy,
  "Other op income"  = pg_palette$alloy,
  "Finance income"   = pg_palette$alloy,
  "Royalties"        = pg_palette$alloy,
  "Revenue"          = pg_palette$alloy,
  # Profit cascade: copper
  "Operating margin" = pg_palette$copper,
  "Pre-tax profit"   = pg_palette$copper,
  "Net profit"       = pg_palette$copper,
  "Dividend"         = pg_palette$copper,
  # Cost peels: dark_stone
  "Operating costs"  = pg_palette$dark_stone,
  "Personnel"        = pg_palette$dark_stone,
  "Other op exp"     = pg_palette$dark_stone,
  "Other costs"      = pg_palette$dark_stone,
  "D&A"              = pg_palette$dark_stone,
  "Finance expense"  = pg_palette$dark_stone,
  "Tax"              = pg_palette$dark_stone,
  # Retained: light cream sliver
  "Retained"         = pg_palette$light_quartz
)

fmt_chf <- function(x) {
  ifelse(x >= 1000, sprintf("CHF %.2f bn", x / 1000),
                    sprintf("CHF %.0f m",  x))
}

# Y/Y growth rates — only computed for items where 2023 comparable
# values are published (income-statement lines + dividend per share).
yoy <- c(
  "Revenue"          = (total_inflow / (1487.2 + 369.4 + 87.9 + 72.4)) - 1,
  "Operating margin" = (operating_margin /
                          (1487.2 + 369.4 + 87.9 + 72.4 - 603.3 - 107.5)) - 1,
  "Pre-tax profit"   = (pretax_profit / 1208.6) - 1,
  "Net profit"       = (profit / 1003.4) - 1,
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
  scale_y_continuous(expand = expansion(mult = c(0.20, 0.14))) +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = NULL) +
  theme_void(base_family = chart_family) +
  theme(plot.margin = margin(t = 10, r = 70, b = 8, l = 110))

gb <- ggplot_build(p_base)
strat_layer_idx <- which(sapply(gb$plot$layers,
                                function(l) inherits(l$stat,
                                                     "StatStratum")))[1]
strat_data <- gb$data[[strat_layer_idx]] %>%
  mutate(y_mid = (ymin + ymax) / 2)

top_y    <- max(strat_data$ymax)
gap_top  <- top_y * 0.025
gap_bot  <- top_y * 0.05

# Inner subtotals (Revenue, Operating margin, Pre-tax profit, Net profit)
inner_subtotals <- strat_data %>%
  filter((x == 2 & stratum == "Revenue") |
         (x == 3 & stratum == "Operating margin") |
         (x == 4 & stratum == "Pre-tax profit") |
         (x == 5 & stratum == "Net profit")) %>%
  mutate(
    x_lbl = x,
    y_lbl = pmin(ymax + gap_top, top_y * 1.08),
    label = sprintf("%s\n%s\n%s",
                    stratum, fmt_chf(count),
                    sapply(as.character(stratum), fmt_yoy)),
    color = pg_palette$alloy,
    face  = "bold"
  )

# Compact 1-line label for sources / cost peels / Retained.
fmt_compact <- function(name, count) {
  sprintf("%s  %s", name, fmt_chf(count))
}

# Inline sources: PE, Infrastructure, Private credit (the three
# largest at ~16-49% of inflow each). Real estate (7%) is borderline
# but still gets an inline label since its bar is tall enough.
inline_sources <- c("Private equity", "Infrastructure",
                    "Private credit", "Real estate")

ax1_inline <- strat_data %>%
  filter(x == 1, as.character(stratum) %in% inline_sources) %>%
  mutate(
    x_lbl = 1 - stratum_w / 2 - 0.06,
    y_lbl = y_mid,
    label = fmt_compact(as.character(stratum), count),
    color = pg_palette$alloy,
    face  = "plain"
  )

# Leader-line labels for the three smallest source streams (Other op
# income 5%, Finance income 5%, Royalties 0.1%).
leader_sources <- c("Other op income", "Finance income", "Royalties")

ax1_leader <- strat_data %>%
  filter(x == 1, as.character(stratum) %in% leader_sources) %>%
  mutate(
    x_anchor = 1 - stratum_w / 2,
    y_anchor = y_mid,
    x_lbl    = 1 - stratum_w / 2 - 0.10,
    y_lbl    = case_when(
      as.character(stratum) == "Other op income" ~ -gap_bot * 1.0,
      as.character(stratum) == "Finance income"  ~ -gap_bot * 2.4,
      as.character(stratum) == "Royalties"       ~ -gap_bot * 3.8,
      TRUE                                       ~ 0
    ),
    label = fmt_compact(as.character(stratum), count),
    color = pg_palette$alloy,
    face  = "plain"
  )

# Cost peels at axes 3, 4 (inline). Tax at axis 5 (inline, biggest peel).
cost_peels_inline <- strat_data %>%
  filter((x == 3 & stratum == "Operating costs") |
         (x == 4 & stratum %in% c("Other costs", "Personnel",
                                   "Other op exp")) |
         (x == 5 & stratum == "Tax")) %>%
  mutate(
    x_lbl = x + stratum_w / 2 + 0.05,
    y_lbl = y_mid,
    label = fmt_compact(as.character(stratum), count),
    color = pg_palette$alloy,
    face  = "plain"
  )

# Smallest cost peels at axis 5 (D&A, Finance expense): leader lines.
peel_leader <- strat_data %>%
  filter(x == 5, as.character(stratum) %in% c("D&A", "Finance expense")) %>%
  mutate(
    x_anchor = 5 + stratum_w / 2,
    y_anchor = y_mid,
    x_lbl    = 5 + stratum_w / 2 + 0.18,
    y_lbl    = case_when(
      as.character(stratum) == "D&A"             ~ -gap_bot * 1.4,
      as.character(stratum) == "Finance expense" ~ -gap_bot * 2.6,
      TRUE                                       ~ 0
    ),
    label = fmt_compact(as.character(stratum), count),
    color = pg_palette$alloy,
    face  = "plain"
  )

# Final allocation labels at axis 6.
ax6_dividend <- strat_data %>%
  filter(x == 6, stratum == "Dividend") %>%
  mutate(
    x_lbl = 6 + stratum_w / 2 + 0.06,
    y_lbl = y_mid,
    label = sprintf("%s\n%s\n%s",
                    stratum, fmt_chf(count),
                    sapply(as.character(stratum), fmt_yoy)),
    color = pg_palette$copper,
    face  = "bold"
  )

ax6_retained <- strat_data %>%
  filter(x == 6, stratum == "Retained") %>%
  mutate(
    x_lbl = 6 + stratum_w / 2 + 0.06,
    y_lbl = y_mid,
    label = fmt_compact(as.character(stratum), count),
    color = pg_palette$alloy,
    face  = "bold"
  )

# ---- Final plot ------------------------------------------------------
add_text <- function(plt, df, hjust, vjust = 0.5, size = 2.5) {
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

# Leader segments (drawn before labels so labels paint over leaders).
if (nrow(ax1_leader) > 0) {
  p <- p +
    geom_segment(data = ax1_leader,
                 aes(x = x_anchor, xend = x_lbl + 0.02,
                     y = y_anchor, yend = y_lbl + top_y * 0.012),
                 color = pg_palette$alloy, linewidth = 0.2,
                 inherit.aes = FALSE)
}
if (nrow(peel_leader) > 0) {
  p <- p +
    geom_segment(data = peel_leader,
                 aes(x = x_anchor, xend = x_lbl - 0.02,
                     y = y_anchor, yend = y_lbl + top_y * 0.012),
                 color = pg_palette$alloy, linewidth = 0.2,
                 inherit.aes = FALSE)
}

p <- add_text(p, ax1_inline,        hjust = 1)
p <- add_text(p, ax1_leader,        hjust = 1)
p <- add_text(p, inner_subtotals,   hjust = 0.5, vjust = 0)
p <- add_text(p, cost_peels_inline, hjust = 0)
p <- add_text(p, peel_leader,       hjust = 0)
p <- add_text(p, ax6_dividend,      hjust = 0)
p <- add_text(p, ax6_retained,      hjust = 0)

out_pdf <- "iterations/task_08/v15/pg_income_sankey_v15.pdf"
ggsave(out_pdf, p, width = 36, height = 16, units = "cm",
       device = "pdf")
cat("\nSaved:", out_pdf, "\n")
