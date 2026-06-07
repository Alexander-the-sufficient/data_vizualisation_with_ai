# Task 8 v25 — Partners Group 2024 income statement Sankey, networkD3.
#
# v25 changes vs v23 (v24 abandoned — its high curvature created
# unintended S-shaped link bumps):
#   * Profit chain (Operating margin, Pre-tax profit, Net profit,
#     Dividend) shifted progressively UPWARD after the d3-sankey
#     layout pass, so each successive link Revenue → Op margin →
#     Pre-tax profit → Net profit → Dividend visibly arcs up rather
#     than running flat. Mirrors the Apple FY22 income-statement
#     Sankey reference (gross profit visibly above revenue, etc.).
#   * margin.top bumped 24 -> 80 so the upward shift doesn't clip
#     the SVG's top edge.
#   * Link <path> d-attributes recomputed in the onRender callback
#     after node y mutation. Path generator inlined (matches d3-sankey
#     v3's smooth Bezier — same one networkD3 uses internally).
#
# Everything else (data, node order, palette, inside-bar labels,
# Dividend bold-copper outside-right) is identical to v23.
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

operating_costs  <- personnel + other_op_exp
total_inflow     <- rev_pe + rev_pc + rev_infra + rev_re + rev_royalties +
                    other_op_inc + finance_inc
operating_margin <- total_inflow - operating_costs
other_costs      <- da_amort + finance_exp
pretax_profit    <- operating_margin - other_costs

fmt_chf <- function(x) {
  ifelse(x >= 1000, sprintf("CHF %.2f bn", x / 1000),
                    sprintf("CHF %.0f m",  x))
}

fmt_chf_compact <- function(x) {
  ifelse(x >= 1000, sprintf("%.2f bn", x / 1000),
                    sprintf("%.0f m",  x))
}

yoy <- list(
  Revenue            = total_inflow / (1487.2 + 369.4 + 87.9 + 72.4) - 1,
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

yoy_str_compact <- function(name) {
  vapply(name, function(n) {
    if (!n %in% names(yoy)) "" else
      sprintf("  %+.0f%%", 100 * yoy[[n]])
  }, character(1), USE.NAMES = FALSE)
}

nodes_def <- tribble(
  ~name,                ~value,             ~group,
  "Private equity",     rev_pe,             "source",
  "Infrastructure",     rev_infra,          "source",
  "Private credit",     rev_pc,             "source",
  "Real estate",        rev_re,             "source",
  "Other op income",    other_op_inc,       "source",
  "Finance income",     finance_inc,        "source",
  "Royalties",          rev_royalties,      "source",
  "Revenue",            total_inflow,       "source",
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

nodes_def <- nodes_def %>%
  mutate(
    display = case_when(
      name %in% names(yoy) ~ paste0(name, "  ",
                                     fmt_chf_compact(value),
                                     yoy_str_compact(name)),
      TRUE                  ~ paste0(name, "  ", fmt_chf_compact(value))
    )
  )

nodes_df <- data.frame(
  name  = nodes_def$display,
  group = nodes_def$group,
  stringsAsFactors = FALSE
)

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
  pg_palette$alloy,
  pg_palette$copper,
  pg_palette$dark_stone,
  pg_palette$light_quartz
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
  margin       = list(top = 80, right = 240, bottom = 24, left = 240)
)

# Post-render polish:
#   1. inside-bar subtotal labels (Apple style, white centred 3-line)
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

    var insideBar = ['Revenue', 'Operating margin', 'Operating costs',
                     'Pre-tax profit', 'Net profit'];

    // --- 1-3: label placement (unchanged from v23) ---
    d3.select(el).selectAll('.node text').each(function(d) {
      var t = d3.select(this);
      var raw = d.name || '';
      var parts = raw.split('  ').filter(function(s) { return s.length; });
      var name = parts[0] || '';

      if (insideBar.indexOf(name) !== -1) {
        t.text('');
        t.attr('x', d.dx / 2)
         .attr('y', d.dy / 2)
         .attr('text-anchor', 'middle')
         .attr('dy', '0')
         .style('font-weight', '600')
         .style('fill', '#FFFFFF');

        var lines = (parts.length === 3) ? [parts[0], parts[1], parts[2]] : parts;
        var n = lines.length;
        var firstDy = -(n - 1) * 0.55 + 'em';
        lines.forEach(function(line, i) {
          t.append('tspan')
            .attr('x', d.dx / 2)
            .attr('dy', i === 0 ? firstDy : '1.1em')
            .text(line);
        });
      } else if (d.x === minX) {
        t.attr('x', -6).attr('text-anchor', 'end');
      }
    });

    d3.select(el).selectAll('.link').style('stroke-opacity', 0.55);
    d3.select(el).selectAll('.node rect').style('stroke-width', 0);

    d3.select(el).selectAll('.node text').filter(function(d) {
      var name = (d.name || '').split('  ')[0];
      return insideBar.indexOf(name) === -1;
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
      if (name === 'Operating margin') return 25;
      if (name === 'Pre-tax profit')   return 50;
      if (name === 'Net profit')       return 75;
      if (name === 'Dividend')         return 75;
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

html_out <- "iterations/task_08/v25/pg_income_sankey_v25.html"
pdf_out  <- "iterations/task_08/v25/pg_income_sankey_v25.pdf"

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
