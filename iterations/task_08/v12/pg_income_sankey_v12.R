# Task 8 v12 — Partners Group 2024 income statement Sankey, Apple-style.
#
# v12 changes vs v11: rebuilt as a 7-axis Apple-FY22-style cascade with a
#   clean profit/cost split at "Revenue" (top branch = profit path,
#   bottom branch = cost path). v11's 5-axis version had the survival
#   cascade going downward through the chart and the cost peels labelled
#   awkwardly in the middle of the panel; the Apple structure puts the
#   profit/cost split horizontally at the centre and lets each branch
#   peel independently. Reference: Apple FY22 income statement Sankey
#   (the canonical income-statement-Sankey shape used by financial
#   analysts and viz blogs).
#
# Palette translation (Apple's semantic colours -> portfolio palette):
#   Apple gray (sources, Products subtotal, Revenue) -> alloy
#   Apple green (Gross profit, Op profit, Net profit) -> copper (the
#     portfolio's only chromatic accent)
#   Apple red (Cost of revenue, Op expenses, Tax, etc.)  -> dark_stone
#     (warm gray, distinctly muted vs. alloy and vs. copper). Heritage
#     red is reserved for source URLs / story callouts only.
#   Final dividend punchline -> copper bold
#   Retained earnings sliver -> light_quartz
#
# 7 axes:
#   1: Leaf revenue sources (Mgmt fees, Performance fees, Other op
#      income, Finance income)
#   2: Mgmt service revenues subtotal (Mgmt + Perf flow here);
#      Other op income and Finance income pass through unchanged
#   3: Revenue (everything pools)
#   4: Operating margin (copper) / Operating costs (dark_stone)
#   5: From Operating margin -> Pre-tax profit / Other costs
#      From Operating costs -> Personnel / Other op exp (peels)
#   6: From Pre-tax profit  -> Net profit / Tax (peel)
#      From Other costs     -> D&A / Finance expense (peels)
#      Personnel and Other op exp NA-terminate from ax5
#   7: From Net profit -> Dividend / Retained
#      All other costs NA-terminate
#
# Note on "Operating margin": this Sankey treats Finance income as a
#   fourth revenue stream (alongside Mgmt fees, Performance fees, and
#   Other op income), which lets the chart balance to the reported
#   Profit of CHF 1127.7 m exactly. As a result, "Operating margin" in
#   this chart equals reported EBITDA + Finance income = CHF 1478.3 m,
#   slightly higher than the reported EBITDA of CHF 1357.4 m. The
#   trade-off is that Finance income visibly enters the Sankey rather
#   than disappearing into a small reconciling item.
#
# Data source: Partners Group Holding AG, Annual Report 2024,
#   Consolidated statement of profit or loss (page 39). PDF and CSV in
#   data/task_08_pg/.

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
mgmt_svc_revenues <- mgmt_fees + perf_fees
operating_costs   <- personnel + other_op_exp
operating_margin  <- total_inflow - operating_costs
other_costs       <- da_amort + finance_exp
pretax_profit     <- operating_margin - other_costs

cat(sprintf("Total inflow:     %.1f CHF m\n", total_inflow))
cat(sprintf("Operating margin: %.1f CHF m\n", operating_margin))
cat(sprintf("Pre-tax profit:   %.1f CHF m  (reported: 1369.9)\n",
            pretax_profit))
cat(sprintf("Net profit:       %.1f CHF m  (reported: 1127.7)\n",
            pretax_profit - tax_exp))
cat(sprintf("Dividend (impl.): %.1f CHF m\n", dividend))
cat(sprintf("Retained (impl.): %.1f CHF m\n", retained))

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
ax2_for <- function(s) {
  if (s %in% c("Mgmt fees", "Performance fees")) "Mgmt service revenues"
  else s
}
ax4_for <- function(d) {
  if (d %in% c("Personnel", "Other op exp")) "Operating costs"
  else "Operating margin"
}
ax5_for <- function(d) {
  if (d == "Personnel")        "Personnel"
  else if (d == "Other op exp") "Other op exp"
  else if (d %in% c("D&A", "Finance expense")) "Other costs"
  else                          "Pre-tax profit"   # Tax / Dividend / Retained
}
ax6_for <- function(d) {
  if (d %in% c("Personnel", "Other op exp")) NA_character_
  else if (d %in% c("D&A", "Finance expense", "Tax")) d
  else                          "Net profit"        # Dividend / Retained
}
ax7_for <- function(d) {
  if (d %in% c("Dividend", "Retained")) d
  else NA_character_
}

paths <- paths %>%
  rowwise() %>%
  mutate(
    ax1 = src,
    ax2 = ax2_for(src),
    ax3 = "Revenue",
    ax4 = ax4_for(dest),
    ax5 = ax5_for(dest),
    ax6 = ax6_for(dest),
    ax7 = ax7_for(dest)
  ) %>%
  ungroup()

# ---- Stratum factor levels (top to bottom at each axis) --------------
src_levels <- sources$src                # 4 leaves, alloy
ax2_levels <- c("Mgmt service revenues", "Other op income", "Finance income")
ax3_levels <- "Revenue"
ax4_levels <- c("Operating margin", "Operating costs")
ax5_levels <- c("Pre-tax profit", "Other costs", "Personnel", "Other op exp")
ax6_levels <- c("Net profit", "Tax", "D&A", "Finance expense")
ax7_levels <- c("Dividend", "Retained")

paths <- paths %>%
  mutate(
    ax1 = factor(ax1, levels = src_levels),
    ax2 = factor(ax2, levels = ax2_levels),
    ax3 = factor(ax3, levels = ax3_levels),
    ax4 = factor(ax4, levels = ax4_levels),
    ax5 = factor(ax5, levels = ax5_levels),
    ax6 = factor(ax6, levels = ax6_levels),
    ax7 = factor(ax7, levels = ax7_levels),
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
  "Mgmt service revenues" = pg_palette$alloy,
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
  "Mgmt fees"             = (mgmt_fees    / 1487.2) - 1,
  "Performance fees"      = (perf_fees    /  369.4) - 1,
  "Other op income"       = (other_op_inc /   87.9) - 1,
  "Finance income"        = (finance_inc  /   72.4) - 1,
  "Mgmt service revenues" = ((mgmt_fees + perf_fees) / (1487.2 + 369.4)) - 1,
  "Revenue"               = (total_inflow / (1487.2 + 369.4 + 87.9 + 72.4)) - 1,
  "Operating margin"      = (operating_margin / (1487.2+369.4+87.9+72.4 - 603.3 - 107.5)) - 1,
  "Operating costs"       = (operating_costs / (603.3 + 107.5)) - 1,
  "Pre-tax profit"        = (pretax_profit / 1208.6) - 1,
  "Net profit"            = (profit / 1003.4) - 1,
  "Personnel"             = (personnel / 603.3) - 1,
  "Other op exp"          = (other_op_exp / 107.5) - 1,
  "Other costs"           = (other_costs / (41.1 + 56.4)) - 1,
  "D&A"                   = (da_amort / 41.1) - 1,
  "Finance expense"       = (finance_exp / 56.4) - 1,
  "Tax"                   = (tax_exp / 205.2) - 1,
  "Dividend"              = (div_per_sh / 39.0) - 1
)

fmt_yoy <- function(name) {
  if (!name %in% names(yoy)) return("")
  pct <- 100 * yoy[[name]]
  sprintf("%+.0f%% Y/Y", pct)
}

stratum_w <- 0.16

# ---- Base plot -------------------------------------------------------
p_base <- ggplot(paths,
                 aes(axis1 = ax1, axis2 = ax2, axis3 = ax3,
                     axis4 = ax4, axis5 = ax5, axis6 = ax6, axis7 = ax7,
                     y = flow)) +
  geom_alluvium(aes(fill = dest),
                width = stratum_w, alpha = 0.78,
                knot.pos = 0.4, curve_type = "sigmoid",
                aes.bind = "alluvia") +
  geom_stratum(width = stratum_w,
               aes(fill = after_stat(stratum)),
               color = "white", linewidth = 0.25) +
  scale_fill_manual(values = all_fills, guide = "none") +
  scale_x_continuous(limits = c(0.6, 7.4), expand = c(0, 0)) +
  scale_y_continuous(expand = expansion(mult = c(0.04, 0.10))) +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = NULL) +
  theme_void(base_family = chart_family) +
  theme(plot.margin = margin(t = 8, r = 70, b = 8, l = 70))

# ---- Pull stratum positions for labels --------------------------------
gb <- ggplot_build(p_base)
strat_layer_idx <- which(sapply(gb$plot$layers,
                                function(l) inherits(l$stat,
                                                     "StatStratum")))[1]
strat_data <- gb$data[[strat_layer_idx]] %>%
  mutate(y_mid = (ymin + ymax) / 2)

# Decide colour and weight per stratum at label time.
profit_strata <- c("Operating margin", "Pre-tax profit", "Net profit",
                   "Dividend")
cost_strata   <- c("Operating costs", "Other costs",
                   "Personnel", "Other op exp",
                   "D&A", "Finance expense", "Tax")

stratum_color <- function(s) {
  if (s == "Dividend")             pg_palette$copper
  else if (s %in% profit_strata)   pg_palette$copper
  else if (s == "Retained")        pg_palette$alloy
  else                              pg_palette$alloy
}
stratum_face <- function(s) {
  if (s %in% c("Dividend", "Retained")) "bold"
  else                                    "plain"
}

# Build a single label table covering every stratum on the chart, with
# its placement (left of, right of, or above the stratum bar) determined
# by axis position and stratum role.
all_labels <- strat_data %>%
  mutate(
    label = sprintf("%s\n%s\n%s",
                    stratum, fmt_chf(count),
                    sapply(as.character(stratum), fmt_yoy)),
    color = sapply(as.character(stratum), stratum_color),
    face  = sapply(as.character(stratum), stratum_face)
  )

# Axis 1 (leaf sources): label LEFT of stratum, right-aligned.
ax1_labels <- all_labels %>%
  filter(x == 1) %>%
  mutate(x_lbl = 1 - stratum_w / 2 - 0.07,
         hjust = 1)

# Axis 2 subtotal (Mgmt service revenues only): label LEFT.
# Other op income / Finance income at ax2 are already labelled at ax1
# (their values are unchanged and showing two labels close together
# would be redundant).
ax2_labels <- all_labels %>%
  filter(x == 2, stratum == "Mgmt service revenues") %>%
  mutate(x_lbl = 2 - stratum_w / 2 - 0.07,
         hjust = 1)

# Axis 3 (Revenue): label ABOVE the stratum (single big block, no
# room to put it sideways).
ax3_labels <- all_labels %>%
  filter(x == 3) %>%
  mutate(x_lbl = 3,
         y     = max(strat_data$ymax) * 1.04,
         hjust = 0.5)

# Axes 4-6 inner subtotals (profit-path nodes): label ABOVE the
# stratum.
inner_profit <- all_labels %>%
  filter((x == 4 & stratum == "Operating margin") |
         (x == 5 & stratum == "Pre-tax profit") |
         (x == 6 & stratum == "Net profit")) %>%
  mutate(x_lbl = x,
         y     = ymax + (max(strat_data$ymax) * 0.025),
         hjust = 0.5)

# Cost peels: label RIGHT of stratum, left-aligned.
cost_peel <- all_labels %>%
  filter((x == 4 & stratum == "Operating costs") |
         (x == 5 & stratum %in% c("Other costs", "Personnel",
                                   "Other op exp")) |
         (x == 6 & stratum %in% c("D&A", "Finance expense", "Tax"))) %>%
  mutate(x_lbl = x + stratum_w / 2 + 0.05,
         hjust = 0)

# Axis 7 final allocation: label RIGHT of stratum, left-aligned.
ax7_labels <- all_labels %>%
  filter(x == 7) %>%
  mutate(x_lbl = 7 + stratum_w / 2 + 0.05,
         hjust = 0)

# ---- Final plot ------------------------------------------------------
add_text <- function(plt, df, vjust = 0.5, size = 2.7) {
  if (nrow(df) == 0) return(plt)
  plt +
    geom_text(data = df,
              aes(x = x_lbl, y = y, label = label,
                  color = color, fontface = face, hjust = hjust),
              family = chart_family, size = size, vjust = vjust,
              lineheight = 0.95, inherit.aes = FALSE)
}

p <- p_base +
  scale_color_identity()
p <- add_text(p, ax1_labels)
p <- add_text(p, ax2_labels)
p <- add_text(p, ax3_labels,        vjust = 0)
p <- add_text(p, inner_profit,      vjust = 0)
p <- add_text(p, cost_peel)
p <- add_text(p, ax7_labels)

out_pdf <- "iterations/task_08/v12/pg_income_sankey_v12.pdf"
ggsave(out_pdf, p, width = 36, height = 16, units = "cm",
       device = "pdf")
cat("\nSaved:", out_pdf, "\n")
