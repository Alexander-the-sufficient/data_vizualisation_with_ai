# Task 8 v30 — Partners Group 2024 income statement Sankey, networkD3.
#
# v30 changes vs v29 (ACCOUNTING CORRECTNESS PASS):
#   v29 conflated Finance income (120.9 m) into "Revenue" and lumped
#   D&A + Finance expense into a single "Other costs" intermediate.
#   That produced a non-standard "Operating margin 1.48 bn" label —
#   PG actually reports EBITDA = 1,357.4 m and EBIT = 1,308.8 m, neither
#   of which appeared on the chart. v30 rebuilds the cascade to match
#   PG's reported income-statement structure (annual report page 39):
#
#     Revenue (operating: 2,135.6 m)
#       splits into  EBITDA (1,357.4) + Operating costs (778.2)
#     EBITDA splits into  EBIT (1,308.8) + D&A (48.6)
#     EBIT splits into    -> Profit before tax (1,249.0 of EBIT survives)
#                         -> Finance expense (59.8 m peeled)
#     Finance income (120.9, separate source) -> Profit before tax
#     Profit before tax (1,369.9) splits into  Net profit (1,127.7) + Tax (242.2)
#     Net profit splits into  Dividend (1,091.3) + Retained (36.4)
#
#   Every node label now matches a line PG actually reports. Finance
#   income enters the chart as its own column-1 source (separate from
#   the operating-revenue funnel) and its link snakes to Profit before
#   tax. D&A and Finance expense peel at the correct stages instead of
#   bundling.
#
#   Knock-on changes:
#     * Upward staircase extended from 4 profit-chain nodes (Op margin,
#       Pre-tax, Net profit, Dividend) to 5 (EBITDA, EBIT, PBT, Net
#       profit, Dividend); shift step reduced from 25 to 20 px to keep
#       the max shift (Dividend) at 100 — same as v29.
#     * "Other costs" node deleted.
#     * Above-bar labels now: Revenue / EBITDA / EBIT / Profit before
#       tax / Net profit. Below-bar: Operating costs. Sources, cost
#       peels, Dividend (outside-right), Retained unchanged.
#
# v29 changes vs v28:
#   * Dividend's upward shift increased 75 -> 100 px so the terminal
#     Net profit -> Dividend link arcs upward by ~25 px.
#
# v28 changes vs v27:
#   * Heritage red removed. Cost group reverts to a warm-neutral.
#     Final palette is editorial / minimalist with copper as the only
#     colored element (the story accent):
#       - source   -> dark_quartz `#ACA39A` (warm taupe, recedes)
#       - profit   -> copper       `#896C4C` (warm bronze)
#       - cost     -> dark_stone   `#7E8182` (warm gray, neutral mass)
#       - retained -> light_quartz `#ECEAE4` (cream sliver)
#     Lightness ramp: cost ~ profit (mid) > source (light) > retained
#     (lightest), so copper still reads as the eye-catching element
#     even though it shares L* with cost — they're separated by hue.
#   * Y/Y growth percentages dropped from cascade subtotal labels.
#     Display is now "Name  value" (no `+12%` suffix). User rationale:
#     fewer numbers per label, cleaner read. Removes the entire `yoy`
#     list / `yoy_str_compact` helper.
#   * "Other costs" label moves from default outside-right to ABOVE
#     its bar, joining the cascade subtotals. v27 had its outside-right
#     placement crossed by the small D&A and Finance expense peels
#     exiting Other costs's right side; the gap above (between
#     Pre-tax profit's bottom and Other costs's top, widened by the
#     profit-chain upward shift) is empty and a clean home for the label.
#
# Layout primitives (upward staircase on profit chain, link-path
# recomputation, source-outside-left, cost-peels-outside-right, Dividend
# bold-copper outside-right) are unchanged from v25/v26/v27.
#
# Source: Partners Group Holding AG, Annual Report 2024 (income
# statement page 39, AuM by asset class page 16, performance fees
# by asset class page 25).

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(networkD3)
  library(htmlwidgets)
  library(chromote)
  library(jsonlite)
})

source("design_system.R")

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

operating_costs   <- personnel + other_op_exp
operating_revenue <- rev_pe + rev_pc + rev_infra + rev_re + rev_royalties +
                     other_op_inc                          # excludes finance income
ebitda            <- operating_revenue - operating_costs   # ~ 1,357.4 m (PG p.39)
ebit              <- ebitda - da_amort                     # ~ 1,308.8 m
ebit_to_pbt       <- ebit - finance_exp                    # the part of EBIT that survives finance expense
pretax_profit     <- ebit_to_pbt + finance_inc             # ~ 1,369.9 m

fmt_chf <- function(x) {
  ifelse(x >= 1000, sprintf("CHF %.2f bn", x / 1000),
                    sprintf("CHF %.0f m",  x))
}

fmt_chf_compact <- function(x) {
  ifelse(x >= 1000, sprintf("%.2f bn", x / 1000),
                    sprintf("%.0f m",  x))
}

nodes_def <- tribble(
  ~name,                  ~value,             ~group,
  # Column 1 — sources (operating revenue + finance income).
  "Private equity",       rev_pe,             "source",
  "Infrastructure",       rev_infra,          "source",
  "Private credit",       rev_pc,             "source",
  "Real estate",          rev_re,             "source",
  "Other op income",      other_op_inc,       "source",
  "Finance income",       finance_inc,        "source",
  "Royalties",            rev_royalties,      "source",
  # Column 2 — operating revenue funnel.
  "Revenue",              operating_revenue,  "source",
  # Column 3 — EBITDA / Operating costs split.
  "EBITDA",               ebitda,             "profit",
  "Operating costs",      operating_costs,    "cost",
  # Column 4 — EBIT / D&A split (D&A peels from EBITDA).
  "EBIT",                 ebit,               "profit",
  "D&A",                  da_amort,           "cost",
  # Column 4 (also) — operating-cost peels.
  "Personnel",            personnel,          "cost",
  "Other op exp",         other_op_exp,       "cost",
  # Column 5 — Profit before tax (EBIT survives finance expense; finance income joins).
  "Profit before tax",    pretax_profit,      "profit",
  "Finance expense",      finance_exp,        "cost",
  # Column 6 — Net profit / Tax split.
  "Net profit",           profit,             "profit",
  "Tax",                  tax_exp,            "cost",
  # Column 7 — Dividend / Retained terminal split.
  "Dividend",             dividend,           "profit",
  "Retained",             retained,           "retained"
)

nodes_def <- nodes_def %>%
  mutate(display = paste0(name, "  ", fmt_chf_compact(value)))

nodes_df <- data.frame(
  name  = nodes_def$display,
  group = nodes_def$group,
  stringsAsFactors = FALSE
)

idx <- function(nm) which(nodes_def$name == nm) - 1L

links_def <- tribble(
  ~src,                  ~tgt,                  ~val,
  # Operating revenue: 6 strategies + Other op income flow into Revenue.
  # Finance income is a SEPARATE source feeding Profit before tax.
  "Private equity",      "Revenue",             rev_pe,
  "Infrastructure",      "Revenue",             rev_infra,
  "Private credit",      "Revenue",             rev_pc,
  "Real estate",         "Revenue",             rev_re,
  "Other op income",     "Revenue",             other_op_inc,
  "Royalties",           "Revenue",             rev_royalties,
  # Revenue splits: EBITDA + Operating costs.
  "Revenue",             "EBITDA",              ebitda,
  "Revenue",             "Operating costs",     operating_costs,
  # Operating costs splits into Personnel + Other op exp.
  "Operating costs",     "Personnel",           personnel,
  "Operating costs",     "Other op exp",        other_op_exp,
  # EBITDA splits: EBIT + D&A.
  "EBITDA",              "EBIT",                ebit,
  "EBITDA",              "D&A",                 da_amort,
  # EBIT splits: the part that survives finance expense flows to PBT,
  # the rest peels off as Finance expense.
  "EBIT",                "Profit before tax",   ebit_to_pbt,
  "EBIT",                "Finance expense",     finance_exp,
  # Finance income joins PBT directly (skips the operating funnel).
  "Finance income",      "Profit before tax",   finance_inc,
  # PBT splits: Net profit + Tax.
  "Profit before tax",   "Net profit",          profit,
  "Profit before tax",   "Tax",                 tax_exp,
  # Net profit splits: Dividend + Retained.
  "Net profit",          "Dividend",            dividend,
  "Net profit",          "Retained",            retained
)

target_group <- setNames(nodes_def$group, nodes_def$name)

links_df <- data.frame(
  source = sapply(links_def$src, idx),
  target = sapply(links_def$tgt, idx),
  value  = links_def$val,
  group  = unname(target_group[links_def$tgt]),
  stringsAsFactors = FALSE
)

colour_scale <- sprintf(
  paste0("d3.scaleOrdinal()",
         ".domain(['source','profit','cost','retained'])",
         ".range(['%s','%s','%s','%s'])"),
  pg_palette$dark_quartz,    # source   — warm taupe (#ACA39A)
  pg_palette$copper,         # profit   — warm bronze (#896C4C, the accent)
  pg_palette$dark_stone,     # cost     — warm gray   (#7E8182)
  pg_palette$light_quartz    # retained — cream sliver (#ECEAE4)
)

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
  fontSize     = 13,
  fontFamily   = "IBM Plex Sans, Inter, Helvetica, sans-serif",
  nodeWidth    = 14,
  nodePadding  = 14,
  iterations   = 32,
  sinksRight   = FALSE,
  width        = 1280,
  height       = 600,
  margin       = list(top = 120, right = 240, bottom = 60, left = 240)
)

# Post-render polish:
#   1. cascade subtotal labels placed ABOVE (or BELOW for Op costs)
#      their bars — outside the bar, so flows are not covered
#   2. source-column labels outside-LEFT
#   3. Dividend bold copper outside-right
#   4. profit-chain nodes shifted UP and link paths recomputed so
#      Revenue -> Op margin -> Pre-tax -> Net profit visibly arcs up
sn <- htmlwidgets::onRender(sn, "
  function(el, x) {
    document.body.style.margin  = '0';
    document.body.style.padding = '0';
    document.documentElement.style.margin  = '0';
    document.documentElement.style.padding = '0';

    var xs = [];
    d3.select(el).selectAll('.node').each(function(d) {
      if (typeof d.x !== 'undefined' && xs.indexOf(d.x) === -1) xs.push(d.x);
    });
    var minX = Math.min.apply(null, xs);

    // Cascade subtotals — labelled OUTSIDE the bar, multi-line stacked.
    // Above the bar (text settles above the rect's top edge):
    var aboveBar = ['Revenue', 'EBITDA', 'EBIT', 'Profit before tax',
                    'Net profit'];
    // Below the bar (text settles below the rect's bottom edge):
    var belowBar = ['Operating costs'];

    var lineHeight = 14;  // px @ fontSize 13
    var gap        = 6;   // px between bar edge and text

    d3.select(el).selectAll('.node text').each(function(d) {
      var t = d3.select(this);
      var raw = d.name || '';
      var parts = raw.split('  ').filter(function(s) { return s.length; });
      var name = parts[0] || '';
      var isAbove = aboveBar.indexOf(name) !== -1;
      var isBelow = belowBar.indexOf(name) !== -1;

      if (isAbove || isBelow) {
        var lines = (parts.length === 3) ? [parts[0], parts[1], parts[2]] : parts;
        var n = lines.length;

        // Position the FIRST baseline:
        //   above: first baseline is (n-1) line-heights up from the
        //          last baseline, which sits gap px above the bar top.
        //   below: first baseline sits gap+lineHeight px below bar bottom
        //          so the cap-line clears the rect by ~gap.
        var firstY = isAbove
          ? -gap - (n - 1) * lineHeight
          :  d.dy + gap + lineHeight;

        t.text('');
        t.attr('x', d.dx / 2)
         .attr('y', firstY)
         .attr('text-anchor', 'middle')
         .attr('dy', '0')
         .style('font-weight', '600')
         .style('fill', '#5C5B59');

        lines.forEach(function(line, i) {
          t.append('tspan')
            .attr('x', d.dx / 2)
            .attr('dy', i === 0 ? '0' : '1.1em')
            .text(line);
        });
      } else if (d.x === minX) {
        t.attr('x', -6).attr('text-anchor', 'end');
      }
      // Else: keep networkD3's default outside-right.
    });

    d3.select(el).selectAll('.link').style('stroke-opacity', 0.55);
    d3.select(el).selectAll('.node rect').style('stroke-width', 0);

    // All non-cascade labels in alloy.
    d3.select(el).selectAll('.node text').filter(function(d) {
      var name = (d.name || '').split('  ')[0];
      return aboveBar.indexOf(name) === -1 && belowBar.indexOf(name) === -1;
    }).style('fill', '#5C5B59');

    d3.select(el).selectAll('.node text').filter(function(d) {
      return (d.name || '').split('  ')[0] === 'Dividend';
    }).style('fill', '#896C4C').style('font-weight', '700');

    // --- 4: profit-chain upward staircase ---
    // Each successive profit node shifts up another 25 px, so the
    // links Revenue -> Op margin, Op margin -> Pre-tax profit,
    // Pre-tax profit -> Net profit each arc upward by 25 px.
    // Dividend matches Net profit so the terminal Net profit -> Dividend
    // link stays horizontal (Retained, the small cost-style peel,
    // continues downward off Net profit).
    function profitShift(name) {
      if (name === 'EBITDA')              return 20;
      if (name === 'EBIT')                return 40;
      if (name === 'Profit before tax')   return 60;
      if (name === 'Net profit')          return 80;
      if (name === 'Dividend')            return 100;
      return 0;
    }

    d3.select(el).selectAll('.node').each(function(d) {
      var n = (d.name || '').split('  ')[0];
      var s = profitShift(n);
      if (s) d.y = d.y - s;
    });

    d3.select(el).selectAll('.node').attr('transform', function(d) {
      return 'translate(' + d.x + ',' + d.y + ')';
    });

    // d3-sankey v3 smooth-Bezier link path. Reads d.source.y and
    // d.target.y dynamically, so the mutated y values above flow
    // through automatically.
    function linkPath(d) {
      var x0 = d.source.x + d.source.dx,
          x1 = d.target.x,
          xMid = (x0 + x1) / 2,
          y0 = d.source.y + d.sy + d.dy / 2,
          y1 = d.target.y + d.ty + d.dy / 2;
      return 'M' + x0 + ',' + y0 +
             'C' + xMid + ',' + y0 +
             ' ' + xMid + ',' + y1 +
             ' ' + x1 + ',' + y1;
    }
    d3.select(el).selectAll('.link').attr('d', linkPath);
  }
")

html_out <- "iterations/task_08/v30/pg_income_sankey_v30.html"
pdf_out  <- "iterations/task_08/v30/pg_income_sankey_v30.pdf"

saveWidget(sn, file = normalizePath(html_out, mustWork = FALSE),
           selfcontained = TRUE)

widget_w_in <- 1280 / 96
widget_h_in <- 600  / 96

b <- chromote::ChromoteSession$new()
b$Page$navigate(paste0("file://", normalizePath(html_out)))
Sys.sleep(2.0)

pdf_data <- b$Page$printToPDF(
  paperWidth        = widget_w_in,
  paperHeight       = widget_h_in,
  marginTop         = 0,
  marginBottom      = 0,
  marginLeft        = 0,
  marginRight       = 0,
  printBackground   = TRUE,
  preferCSSPageSize = FALSE,
  pageRanges        = "1"
)
writeBin(jsonlite::base64_dec(pdf_data$data), pdf_out)
b$close()

cat("Saved HTML:", html_out, "\n")
cat("Saved PDF: ", pdf_out, "\n")
