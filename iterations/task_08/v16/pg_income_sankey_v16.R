# Task 8 v16 — Partners Group 2024 income statement Sankey, networkD3
# (Apple-FY22 D3 bezier rendering).
#
# v16 changes vs v15: complete rewrite using `networkD3::sankeyNetwork`,
# which produces the smooth D3 bezier-flow rendering that the Apple
# FY22 reference image is built from. ggalluvial (used through v15) drew
# rectangular alpha-stacked alluvia that stayed visibly "boxy" no matter
# the polish; the user explicitly asked for the smooth, organic-curve
# look only achievable through D3-Sankey.
#
# Pipeline:
#   1. Build nodes + links data frames from the same CSV as v15.
#   2. Render with sankeyNetwork() into an HTML widget.
#   3. Inject custom CSS / a tiny JS onRender callback so:
#        - link fill = destination-node colour (Apple-style profit/cost
#          tinting), not the default 50%-grey of vanilla networkD3.
#        - node colours follow the portfolio palette (alloy / copper /
#          dark_stone / light_quartz).
#   4. Save the widget as a self-contained HTML file.
#   5. Use chromote (via webshot2) to print the HTML to a vector PDF.
#      Chrome's Print-to-PDF preserves the underlying SVG paths as
#      vectors, so the resulting PDF zooms cleanly in the portfolio.
#
# Data and layout (axes / nodes / link values) are identical to v15:
#   - 7 source streams (Private equity, Infrastructure, Private credit,
#     Real estate, Other op income, Finance income, Royalties) feeding
#     into Revenue.
#   - Revenue splits Operating margin / Operating costs.
#   - Operating margin -> Pre-tax profit (continues) + Other costs (D&A
#     + Finance expense, peels off).
#   - Operating costs -> Personnel + Other op exp.
#   - Pre-tax profit -> Net profit (continues) + Tax (peels).
#   - Other costs -> D&A + Finance expense (peels).
#   - Net profit -> Dividend (the punchline) + Retained.
#
# Source: Partners Group Holding AG, Annual Report 2024.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(networkD3)
  library(htmlwidgets)
  library(webshot2)
})

source("design_system.R")

# ---- Load data -------------------------------------------------------
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

strategy_rev <- function(aum, perf) mgmt_fees * (aum / aum_total) + perf

rev_pe        <- strategy_rev(aum_pe,        perf_pe)
rev_pc        <- strategy_rev(aum_pc,        perf_pc)
rev_infra     <- strategy_rev(aum_infra,     perf_infra)
rev_re        <- strategy_rev(aum_re,        perf_re)
rev_royalties <- strategy_rev(aum_royalties, perf_royalties)

shares_m <- profit / basic_eps
dividend <- div_per_sh * shares_m
retained <- profit - dividend

operating_costs  <- personnel + other_op_exp
operating_margin <- (rev_pe + rev_pc + rev_infra + rev_re + rev_royalties +
                     other_op_inc + finance_inc) - operating_costs
other_costs      <- da_amort + finance_exp
pretax_profit    <- operating_margin - other_costs

# ---- Build helpers ----------------------------------------------------
fmt_chf <- function(x) {
  ifelse(x >= 1000, sprintf("CHF %.2f bn", x / 1000),
                    sprintf("CHF %.0f m",  x))
}

# Y/Y for the four cascade subtotals + Dividend (only items with
# published 2023 comparators).
yoy <- list(
  Revenue            = (rev_pe + rev_pc + rev_infra + rev_re + rev_royalties +
                          other_op_inc + finance_inc) /
                       (1487.2 + 369.4 + 87.9 + 72.4) - 1,
  `Operating margin` = operating_margin /
                       (1487.2 + 369.4 + 87.9 + 72.4 - 603.3 - 107.5) - 1,
  `Pre-tax profit`   = pretax_profit / 1208.6 - 1,
  `Net profit`       = profit / 1003.4 - 1,
  Dividend           = div_per_sh / 39.0 - 1
)
yoy_str <- function(name) {
  vapply(name, function(n) {
    if (!n %in% names(yoy)) "" else
      sprintf(" (%+.0f%% Y/Y)", 100 * yoy[[n]])
  }, character(1), USE.NAMES = FALSE)
}

# ---- Nodes table ------------------------------------------------------
# Group classifies each node: "source" -> alloy, "profit" -> copper,
# "cost" -> dark_stone, "retained" -> light_quartz. Group also drives
# link colour (link inherits its target node's group).
nodes_def <- tribble(
  ~name,                ~value,             ~group,
  "Private equity",     rev_pe,             "source",
  "Infrastructure",     rev_infra,          "source",
  "Private credit",     rev_pc,             "source",
  "Real estate",        rev_re,             "source",
  "Other op income",    other_op_inc,       "source",
  "Finance income",     finance_inc,        "source",
  "Royalties",          rev_royalties,      "source",
  "Revenue",            NA_real_,           "source",
  "Operating margin",   operating_margin,   "profit",
  "Operating costs",    operating_costs,    "cost",
  "Pre-tax profit",     pretax_profit,      "profit",
  "Other costs",        other_costs,        "cost",
  "Personnel",          personnel,          "cost",
  "Other op exp",       other_op_exp,       "cost",
  "Net profit",         profit,             "profit",
  "Tax",                tax_exp,            "cost",
  "D&A",                da_amort,           "cost",
  "Finance expense",    finance_exp,        "cost",
  "Dividend",           dividend,           "profit",
  "Retained",           retained,           "retained"
)

# Display name = base name + value (+ Y/Y for subtotals where defined).
nodes_def <- nodes_def %>%
  mutate(
    display = case_when(
      name == "Revenue" ~ paste0(name, "  ", fmt_chf(rev_pe + rev_pc + rev_infra + rev_re + rev_royalties + other_op_inc + finance_inc), yoy_str(name)),
      name %in% names(yoy) ~ paste0(name, "  ", fmt_chf(value), yoy_str(name)),
      TRUE                  ~ paste0(name, "  ", fmt_chf(value))
    )
  )

nodes_df <- data.frame(
  name  = nodes_def$display,
  group = nodes_def$group,
  stringsAsFactors = FALSE
)

# ---- Links table ------------------------------------------------------
# 0-indexed source / target into nodes_df.
idx <- function(nm) which(nodes_def$name == nm) - 1L

links_def <- tribble(
  ~src,                 ~tgt,                ~val,
  "Private equity",     "Revenue",           rev_pe,
  "Infrastructure",     "Revenue",           rev_infra,
  "Private credit",     "Revenue",           rev_pc,
  "Real estate",        "Revenue",           rev_re,
  "Other op income",    "Revenue",           other_op_inc,
  "Finance income",     "Revenue",           finance_inc,
  "Royalties",          "Revenue",           rev_royalties,
  "Revenue",            "Operating margin",  operating_margin,
  "Revenue",            "Operating costs",   operating_costs,
  "Operating margin",   "Pre-tax profit",    pretax_profit,
  "Operating margin",   "Other costs",       other_costs,
  "Operating costs",    "Personnel",         personnel,
  "Operating costs",    "Other op exp",      other_op_exp,
  "Pre-tax profit",     "Net profit",        profit,
  "Pre-tax profit",     "Tax",               tax_exp,
  "Other costs",        "D&A",               da_amort,
  "Other costs",        "Finance expense",   finance_exp,
  "Net profit",         "Dividend",          dividend,
  "Net profit",         "Retained",          retained
)

# Each link inherits its TARGET node's group, so flows landing in the
# profit cascade read copper, flows into cost peels read dark_stone,
# flows into Retained read light_quartz, and the strategy->Revenue
# bundle reads alloy. This is the Apple FY22 colour treatment.
target_group <- setNames(nodes_def$group, nodes_def$name)

links_df <- data.frame(
  source = sapply(links_def$src, idx),
  target = sapply(links_def$tgt, idx),
  value  = links_def$val,
  group  = unname(target_group[links_def$tgt]),
  stringsAsFactors = FALSE
)

# ---- Colour scale (D3 ordinal) ---------------------------------------
# Domain order is reused for both nodes (via nodes$group) and links
# (via links$group).
colour_scale <- sprintf(
  paste0("d3.scaleOrdinal()",
         ".domain(['source','profit','cost','retained'])",
         ".range(['%s','%s','%s','%s'])"),
  pg_palette$alloy,
  pg_palette$copper,
  pg_palette$dark_stone,
  pg_palette$light_quartz
)

# ---- Build widget -----------------------------------------------------
sn <- sankeyNetwork(
  Links        = links_df,
  Nodes        = nodes_df,
  Source       = "source",
  Target       = "target",
  Value        = "value",
  NodeID       = "name",
  NodeGroup    = "group",
  LinkGroup    = "group",
  colourScale  = JS(colour_scale),
  fontSize     = 12,
  fontFamily   = "IBM Plex Sans, Inter, Helvetica, sans-serif",
  nodeWidth    = 14,
  nodePadding  = 16,
  iterations   = 32,
  sinksRight   = TRUE,
  width        = 1280,
  height       = 720,
  margin       = list(top = 30, right = 220, bottom = 30, left = 220)
)

# ---- Style polish via post-render JavaScript -------------------------
# Default networkD3 link fill is 20% alpha; bump to 0.55 so the
# Apple-style colour reads cleanly. Also widen the per-link stroke to
# zero (we want filled bands, not hairlines).
sn <- htmlwidgets::onRender(sn, "
  function(el, x) {
    d3.select(el)
      .selectAll('.link')
        .style('stroke-opacity', 0.55)
        .style('stroke-width', function(d) { return Math.max(1, d.dy); });
    d3.select(el)
      .selectAll('.node rect')
        .style('stroke-width', 0);
    d3.select(el)
      .selectAll('.node text')
        .style('font-weight', '500')
        .style('fill', '#5C5B59');
  }
")

# ---- Save HTML + render to PDF ---------------------------------------
html_out <- "iterations/task_08/v16/pg_income_sankey_v16.html"
pdf_out  <- "iterations/task_08/v16/pg_income_sankey_v16.pdf"

saveWidget(sn, file = normalizePath(html_out, mustWork = FALSE),
           selfcontained = TRUE)

# webshot2 uses headless Chrome's print-to-PDF, which preserves SVG as
# vector geometry in the resulting PDF.
webshot2::webshot(
  url         = paste0("file://", normalizePath(html_out)),
  file        = normalizePath(pdf_out, mustWork = FALSE),
  vwidth      = 1280,
  vheight     = 720,
  zoom        = 2,
  delay       = 1.0
)

cat("Saved HTML:", html_out, "\n")
cat("Saved PDF: ", pdf_out, "\n")
