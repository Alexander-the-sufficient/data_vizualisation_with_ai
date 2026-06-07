# Task 8 v11 — Partners Group 2024 income statement Sankey, 5 stages.
#
# Topic pivot from global plastic waste (v10) to Partners Group's own
# 2024 P&L. Reasons:
#   * The whole portfolio is built on Partners Group's brand system, so
#     a chart *about* Partners Group closes the loop on the design.
#   * An income statement gives a Sankey natural divergence + convergence:
#     three revenue streams converge into total revenue; total revenue
#     diverges into operating costs + EBITDA; EBITDA diverges into
#     financing items + tax + net profit; net profit diverges into
#     dividend + retained earnings. Five stages, none of them artificial.
#   * The story is sharp: of the CHF 1.13 bn that survives as profit,
#     97% is proposed as dividend — Partners Group is essentially a
#     dividend machine.
#
# Story: of CHF 2.26 bn of total cash inflow in 2024, half (CHF 1.13 bn)
#   survives as profit; the board proposes paying out CHF 1.09 bn of that
#   (97%) as the CHF 42.00/share dividend. Only CHF 36 m is retained.
#
# Chart structure: 5-stage Sankey via ggalluvial axis1..axis5.
#   axis 1 — Revenue source (4 nodes)
#   axis 2 — Total cash inflow (1 node)
#   axis 3 — After operating costs (3 nodes: Personnel / Other op exp /
#     "Operating margin" continuation)
#   axis 4 — Profit waterfall (6 nodes: Personnel/OOpEx echo + D&A +
#     Finance expense + Tax + "Net profit")
#   axis 5 — Final allocation (7 nodes: cost echoes + Dividend + Retained)
#
# ggalluvial requires every path to span every axis. Cost flows that
# "exit" at axis 3 or axis 4 echo the same label across subsequent
# axes — visually they appear as horizontal bands extending to the
# right edge of the chart, which matches the income-statement reading
# order ("personnel paid here, doesn't reach the bottom line").
#
# Colour discipline:
#   * Dividend = COPPER. The single accent. The chart's punchline.
#   * Retained earnings = LIGHT QUARTZ (cream). Barely visible —
#     conveying "almost nothing left" without needing words.
#   * Personnel (largest cost) = ALLOY (warm charcoal, the workhorse).
#   * Other costs = warm-neutral ramp (dark_stone / dark_quartz /
#     medium_quartz) graded roughly by size.
#   * Source strata + Total revenue + transitional "Operating margin" /
#     "Net profit" strata pick colours that visually trace the
#     surviving cash through to the dividend.
#
# Data source: Partners Group Holding AG, Annual Report 2024,
#   Consolidated statement of profit or loss, page 39.
#   PDF: https://www.partnersgroup.com/~/media/files/p/partnersgroup/
#        universal/shareholders/reports-and-presentations/2025/
#        annual-report-2024.pdf
#   Local: data/task_08_pg/pg_annual_report_2024.pdf
#   Extracted CSV: data/task_08_pg/pg_income_statement_2024.csv

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

# Implied weighted-average basic shares = profit / basic EPS, in millions.
# Total proposed dividend = div_per_sh * shares. The split into Dividend
# vs Retained earnings is then derived from the profit total.
weighted_basic_shares_m <- profit / basic_eps
dividend <- div_per_sh * weighted_basic_shares_m
retained <- profit - dividend

# Total cash inflow = total revenues + finance income.
total_inflow <- mgmt_fees + perf_fees + other_op_inc + finance_inc

# Sanity check: outflows should sum to total inflow (within rounding).
outflows_sum <- personnel + other_op_exp + da_amort + finance_exp +
                tax_exp + dividend + retained
cat(sprintf("Total inflow:  %.1f CHF m\n", total_inflow))
cat(sprintf("Sum outflows:  %.1f CHF m\n", outflows_sum))
cat(sprintf("Residual:      %.2f CHF m  (rounding)\n",
            total_inflow - outflows_sum))
cat(sprintf("Implied shares (basic, weighted, m): %.3f\n",
            weighted_basic_shares_m))
cat(sprintf("Total dividend (proposed): %.1f CHF m\n", dividend))
cat(sprintf("Retained earnings:         %.1f CHF m\n", retained))

# ---- Build path table -------------------------------------------------
# Each path is one CHF flow: source × destination, value pro-rated.
# axis1 = source, axis5 = destination, axis2-4 = transitional labels.

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

# Cross-join sources × destinations and pro-rate flow.
paths <- crossing(src = sources$src, dest = destinations$dest) %>%
  left_join(sources       %>% rename(src_chf = chf),  by = "src") %>%
  left_join(destinations  %>% rename(dest_chf = chf), by = "dest") %>%
  mutate(flow = src_chf * dest_chf / total_inflow)

cat(sprintf("\nPaths: %d  | Total flow: %.1f CHF m\n",
            nrow(paths), sum(paths$flow)))

# ---- Axis label assignment -------------------------------------------
# axis2 always = "Total revenue".
# axis3: Personnel and Other op exp peel off here; everything else
#        carries on as "Operating margin".
# axis4: D&A, Finance expense, Tax peel off here; Dividend + Retained
#        carry on as "Net profit".
# axis5: Dividend or Retained.
#
# Rather than echo terminated cost flows as horizontal bands across
# subsequent axes, NA out the axes AFTER the cost has peeled off. The
# cost band visually ends at its peel-off axis, eliminating the
# crossings that the echoed bands cause and leaving the survival
# cascade unobscured.

ax3_for <- function(d) {
  if (d %in% c("Personnel", "Other op exp")) d
  else "Operating margin"
}
ax4_for <- function(d) {
  if (d %in% c("Personnel", "Other op exp")) NA_character_
  else if (d %in% c("D&A", "Finance expense", "Tax")) d
  else "Net profit"
}
ax5_for <- function(d) {
  if (d %in% c("Personnel", "Other op exp",
               "D&A", "Finance expense", "Tax")) NA_character_
  else d
}

paths <- paths %>%
  rowwise() %>%
  mutate(
    ax1 = src,
    ax2 = "Total revenue",
    ax3 = ax3_for(dest),
    ax4 = ax4_for(dest),
    ax5 = ax5_for(dest)
  ) %>%
  ungroup()

# ---- Order strata at each axis (drives vertical position) ------------
# Heaviest band at the top reads top-down. Sources by size, costs in
# stable income-statement order, allocations in story order
# (Dividend large + bold first, Retained second).

# Stratum factor levels per axis. With NA-termination, each axis only
# sees the strata of the flows still alive at that axis. Survival
# cascade (Operating margin / Net profit / Dividend) is listed first
# so it stays at the top edge of the chart; cost peels stack below.
src_levels  <- sources$src                       # by descending chf
ax2_levels  <- "Total revenue"
ax3_levels  <- c("Operating margin", "Personnel", "Other op exp")
ax4_levels  <- c("Net profit", "Tax", "Finance expense", "D&A")
ax5_levels  <- c("Dividend", "Retained")

paths <- paths %>%
  mutate(
    ax1 = factor(ax1, levels = src_levels),
    ax2 = factor(ax2, levels = ax2_levels),
    ax3 = factor(ax3, levels = ax3_levels),
    ax4 = factor(ax4, levels = ax4_levels),
    ax5 = factor(ax5, levels = ax5_levels),
    dest = factor(dest, levels = c(ax5_levels,
                                   "Personnel", "Other op exp",
                                   "D&A", "Finance expense", "Tax"))
  )

# ---- Colours ---------------------------------------------------------
# Single fill scale shared between alluvium fill (= dest) and stratum
# fill (= stratum name). Names that appear at multiple axes get one
# entry. Names only appearing as transitional strata get their own.

all_fills <- c(
  # axis 1 sources — neutral upstream, not the story
  "Management fees & other rev." = pg_palette$alloy,
  "Performance fees"             = pg_palette$alloy,
  "Other operating income"       = pg_palette$alloy,
  "Finance income"               = pg_palette$alloy,
  # axis 2 — total inflow
  "Total revenue"                = pg_palette$alloy,
  # axis 3 transitional — the surviving margin
  "Operating margin"             = pg_palette$copper,
  # axis 4 transitional — surviving net profit
  "Net profit"                   = pg_palette$copper,
  # cost destinations (in size order: Personnel largest)
  "Personnel"                    = pg_palette$alloy,
  "Tax"                          = pg_palette$dark_stone,
  "Other op exp"                 = pg_palette$dark_quartz,
  "Finance expense"              = pg_palette$medium_quartz,
  "D&A"                          = pg_palette$medium_quartz,
  # final allocation
  "Dividend"                     = pg_palette$copper,
  "Retained"                     = pg_palette$light_quartz
)

# ---- Helpers ---------------------------------------------------------
fmt_chf <- function(x) {
  ifelse(x >= 1000,
         sprintf("CHF %.2f bn", x / 1000),
         sprintf("CHF %.0f m", x))
}

stratum_w <- 0.18

# ---- Base plot -------------------------------------------------------
p_base <- ggplot(paths,
                 aes(axis1 = ax1, axis2 = ax2, axis3 = ax3,
                     axis4 = ax4, axis5 = ax5,
                     y = flow)) +
  geom_alluvium(aes(fill = dest),
                width = stratum_w, alpha = 0.78,
                knot.pos = 0.4, curve_type = "sigmoid",
                aes.bind = "alluvia") +
  geom_stratum(width = stratum_w,
               aes(fill = after_stat(stratum)),
               color = "white", linewidth = 0.25) +
  scale_fill_manual(values = all_fills, guide = "none") +
  scale_x_continuous(limits = c(0.6, 5.4), expand = c(0, 0)) +
  scale_y_continuous(expand = expansion(mult = c(0.05, 0.18))) +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = NULL) +
  theme_void(base_family = chart_family) +
  theme(plot.margin = margin(t = 22, r = 80, b = 14, l = 80))

# ---- Pull stratum positions for labels --------------------------------
gb <- ggplot_build(p_base)
strat_layer_idx <- which(sapply(gb$plot$layers,
                                function(l) inherits(l$stat,
                                                     "StatStratum")))[1]
strat_data <- gb$data[[strat_layer_idx]] %>%
  mutate(y_mid = (ymin + ymax) / 2)

# Axis 1 labels (left of stratum, source name + amount)
ax1_labels <- strat_data %>%
  filter(x == 1) %>%
  transmute(x = 1 - stratum_w / 2 - 0.05,
            y = y_mid,
            label = paste0(stratum, "   ", fmt_chf(count)))

# Right-side labels for terminating cost peels at each axis (3, 4) plus
# the final allocation strata at axis 5. Labels sit immediately right
# of the stratum bar where the flow terminates, so each cost gets a
# label at its peel-off point rather than echoing across.
total_flow <- sum(paths$flow)

cost_peel_labels <- strat_data %>%
  filter((x == 3 & stratum %in% c("Personnel", "Other op exp")) |
         (x == 4 & stratum %in% c("D&A", "Finance expense", "Tax"))) %>%
  transmute(x = x + stratum_w / 2 + 0.05,
            y = y_mid,
            label = sprintf("%s  %s  (%.0f%%)",
                            fmt_chf(count), stratum,
                            100 * count / total_flow),
            color = pg_palette$alloy,
            face  = "plain")

allocation_labels <- strat_data %>%
  filter(x == 5) %>%
  transmute(x = 5 + stratum_w / 2 + 0.05,
            y = y_mid,
            label = sprintf("%s  %s  (%.0f%%)",
                            fmt_chf(count), stratum,
                            100 * count / total_flow),
            color = ifelse(stratum == "Dividend",
                           pg_palette$copper,
                           pg_palette$alloy),
            face  = "bold")

right_labels <- bind_rows(cost_peel_labels, allocation_labels)

# Above each axis: a 3-line column subheader: bold uppercase axis name,
# then the cascade-node name + its CHF amount on lines 2-3 (only for the
# axes that have a meaningful single "surviving cash" node — axes 2/3/4).
# Axes 1 and 5 are headers only (their breakdown is in the side labels).
top_y <- max(strat_data$ymax) * 1.08

column_headers <- tibble(
  x     = 1:5,
  label = c("REVENUE SOURCE", "TOTAL INFLOW",
            "AFTER OP. COST", "PROFIT WATERFALL",
            "ALLOCATION")
)

cascade_subheaders <- bind_rows(
  strat_data %>% filter(x == 2) %>%
    transmute(x = x,
              label = paste0(stratum, "\n", fmt_chf(count)),
              color = pg_palette$alloy),
  strat_data %>% filter(x == 3, stratum == "Operating margin") %>%
    transmute(x = x,
              label = paste0(stratum, "\n", fmt_chf(count)),
              color = pg_palette$copper),
  strat_data %>% filter(x == 4, stratum == "Net profit") %>%
    transmute(x = x,
              label = paste0(stratum, "\n", fmt_chf(count)),
              color = pg_palette$copper)
)

# ---- Final plot ------------------------------------------------------
p <- p_base +
  geom_text(data = ax1_labels,
            aes(x = x, y = y, label = label),
            family = chart_family, size = 2.9,
            color = pg_palette$alloy,
            hjust = 1, vjust = 0.5,
            inherit.aes = FALSE) +
  geom_text(data = right_labels,
            aes(x = x, y = y, label = label,
                color = color, fontface = face),
            family = chart_family, size = 3.0,
            hjust = 0, vjust = 0.5,
            inherit.aes = FALSE) +
  scale_color_identity() +
  # Column header (line 1): bold uppercase axis name
  geom_text(data = column_headers,
            aes(x = x, y = top_y * 1.10, label = label),
            family = chart_family, size = 2.6, fontface = "bold",
            color = pg_palette$onyx,
            hjust = 0.5, vjust = 0,
            inherit.aes = FALSE) +
  # Column subheader (lines 2-3 of the header block): the surviving
  # cash-cascade node name + its amount, ABOVE the strata.
  geom_text(data = cascade_subheaders,
            aes(x = x, y = top_y, label = label, color = color),
            family = chart_family, size = 2.9, fontface = "bold",
            hjust = 0.5, vjust = 0,
            lineheight = 1.0,
            inherit.aes = FALSE)

out_pdf <- "iterations/task_08/v11/pg_income_sankey_v11.pdf"
ggsave(out_pdf, p, width = 36, height = 15, units = "cm",
       device = "pdf")
cat("\nSaved:", out_pdf, "\n")
