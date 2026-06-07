# Task 8 v24 — Partners Group 2024 income statement Sankey, networkD3.
#
# v24 changes vs v23:
#   * Replaced d3-sankey's default `sankeyLinkHorizontal()` link path
#     generator with a custom one that adds a deliberate downward dip
#     to the midpoint of every link. Default d3-sankey produces a flat
#     horizontal ribbon when source and target endpoints share the same
#     y position (which is the case for the top flow Private equity ->
#     Revenue -> Operating margin -> Pre-tax profit -> Net profit ->
#     Dividend, since the profit cascade is top-aligned at every
#     column). The user wanted visible curvature on every link, like
#     the Apple FY22 reference. The custom generator (in onRender JS)
#     pushes the bezier control points down by ~40 px, so even the
#     dominant top flow bends visibly while still flowing left-to-right.
#
# v23 changes vs v22 (preserved):
#   * Dividend label moved out of the inside-bar group. v22 put
#     Dividend's label inside its bar centred at d.dx/2, but Dividend
#     is at the chart's rightmost column, so the centred label
#     overflowed past the SVG's right edge and got clipped to "Divide".
#     v23 keeps Dividend's label OUTSIDE-RIGHT (in the right margin)
#     where Retained's label already sits, but renders it bold copper
#     so it still reads as the chart's punchline.
#   * insideBar list now: Revenue, Operating margin, Operating costs,
#     Pre-tax profit, Net profit. (Dividend removed.)
#
# v22 changes vs v21 (preserved):
#   * Cascade subtotal labels (Revenue / Operating margin / Operating
#     costs / Pre-tax profit / Net profit / Dividend) moved INSIDE
#     their stratum bars, centred horizontally and vertically, in
#     WHITE text. This is the Apple FY22 treatment — the colored bars
#     are tall enough to hold their own labels (each label converted
#     to a 3-line tspan format: name / value / Y/Y).
#   * Cost peels (Personnel, Other op exp, D&A, Finance expense, Tax)
#     and Retained keep their default outside-right placement; sources
#     keep outside-left. So no two label clusters share horizontal
#     space anymore.
#   * pageRanges = "1" passed to chromote::printToPDF to force a
#     single-page PDF. v21 had a blank page 2 from minor overflow.
#
# v21 changes vs v20 (preserved):
#   * Cost-peel labels in compact form ("Personnel  658 m").
#   * onRender zeroes body margin/padding to suppress Chrome's blank
#     leading page.
#
# v20 changes vs v18 (preserved):
#   * Inner-cascade subtotal labels in compact form ("1.48 bn  +13%").
#   * chromote::printToPDF directly with explicit paperWidth/paperHeight
#     so the PDF page matches the 1280 x 600 px widget exactly.
#   * Source-label-on-left and bold-subtotal JS callbacks.
#
# v18 changes vs v17 (preserved):
#   * sinksRight = FALSE so cost peels stop at their natural depth.
#   * iterations = 32 (d3-sankey relax pass) for crossing minimisation.
#
# Pipeline + data: identical to v16. Source: Partners Group Holding AG,
# Annual Report 2024 (income statement page 39, AuM by asset class
# page 16, performance fees by asset class page 25).

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

# Compact format for cascade subtotals (no "CHF" prefix to save width).
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

# Compact Y/Y for cascade labels: "+12%" instead of " (+12% Y/Y)".
yoy_str_compact <- function(name) {
  vapply(name, function(n) {
    if (!n %in% names(yoy)) "" else
      sprintf("  %+.0f%%", 100 * yoy[[n]])
  }, character(1), USE.NAMES = FALSE)
}

# Node order matters: at each x-column d3-sankey stacks nodes
# top-to-bottom in the order they appear in the data frame. Profit
# cascade nodes are listed FIRST (top), cost peels LAST (bottom).
nodes_def <- tribble(
  ~name,                ~value,             ~group,
  # Sources (column 1) — large strategies on top, small streams below.
  "Private equity",     rev_pe,             "source",
  "Infrastructure",     rev_infra,          "source",
  "Private credit",     rev_pc,             "source",
  "Real estate",        rev_re,             "source",
  "Other op income",    other_op_inc,       "source",
  "Finance income",     finance_inc,        "source",
  "Royalties",          rev_royalties,      "source",
  # Column 2: single Revenue node.
  "Revenue",            total_inflow,       "source",
  # Column 3: profit on top, cost on bottom.
  "Operating margin",   operating_margin,   "profit",
  "Operating costs",    operating_costs,    "cost",
  # Column 4: profit on top, then peels in size order.
  "Pre-tax profit",     pretax_profit,      "profit",
  "Other costs",        other_costs,        "cost",
  "Personnel",          personnel,          "cost",
  "Other op exp",       other_op_exp,       "cost",
  # Column 5.
  "Net profit",         profit,             "profit",
  "Tax",                tax_exp,            "cost",
  "D&A",                da_amort,           "cost",
  "Finance expense",    finance_exp,        "cost",
  # Column 6: terminal allocation.
  "Dividend",           dividend,           "profit",
  "Retained",           retained,           "retained"
)

nodes_def <- nodes_def %>%
  mutate(
    display = case_when(
      # Cascade subtotals: compact form ("1.48 bn  +13%") + Y/Y.
      name %in% names(yoy) ~ paste0(name, "  ",
                                     fmt_chf_compact(value),
                                     yoy_str_compact(name)),
      # All other nodes (sources, cost peels, Retained): also compact
      # ("Personnel  658 m") so they don't run into adjacent labels.
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

# iterations = 0 disables d3-sankey's relax pass so the manual node
# order is honoured.
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
  margin       = list(top = 24, right = 240, bottom = 24, left = 240)
)

# Post-render polish:
#   - Move source-column (leftmost) labels to the LEFT of their nodes
#     so they sit in the page margin instead of fighting the flows.
#   - Bold the inner-cascade subtotal labels.
#   - Bump link opacity from networkD3's 20% default to 0.55.
sn <- htmlwidgets::onRender(sn, "
  function(el, x) {
    // Zero out body padding/margin so Chrome's print-to-PDF doesn't
    // insert a blank first page or push content past paper boundaries.
    document.body.style.margin  = '0';
    document.body.style.padding = '0';
    document.documentElement.style.margin  = '0';
    document.documentElement.style.padding = '0';

    // Find the leftmost column (sources).
    var xs = [];
    d3.select(el).selectAll('.node').each(function(d) {
      if (typeof d.x !== 'undefined' && xs.indexOf(d.x) === -1) xs.push(d.x);
    });
    var minX = Math.min.apply(null, xs);

    // Cascade subtotal nodes that get INSIDE-BAR labels (Apple style).
    // Their bars are tall enough to hold a 3-line label.
    // Dividend deliberately excluded — its bar is at the rightmost
    // column, so a centred inside-bar label overflows the SVG.
    // Dividend gets bold copper outside-right (handled below).
    var insideBar = ['Revenue', 'Operating margin', 'Operating costs',
                     'Pre-tax profit', 'Net profit'];

    d3.select(el).selectAll('.node text').each(function(d) {
      var t = d3.select(this);
      var raw = d.name || '';
      var parts = raw.split('  ').filter(function(s) { return s.length; });
      var name = parts[0] || '';

      if (insideBar.indexOf(name) !== -1) {
        // Replace single-line text with a centred 3-line tspan stack
        // positioned INSIDE the stratum bar.
        t.text('');
        t.attr('x', d.dx / 2)
         .attr('y', d.dy / 2)
         .attr('text-anchor', 'middle')
         .attr('dy', '0')
         .style('font-weight', '600')
         .style('fill', '#FFFFFF');

        // Lines: name / value / yoy.
        var lines = [];
        if (parts.length === 3) {
          lines = [parts[0], parts[1], parts[2]];
        } else {
          lines = parts;
        }

        var n = lines.length;
        // First line shifted up so the stack is centred on d.dy/2.
        var firstDy = -(n - 1) * 0.55 + 'em';
        lines.forEach(function(line, i) {
          t.append('tspan')
            .attr('x', d.dx / 2)
            .attr('dy', i === 0 ? firstDy : '1.1em')
            .text(line);
        });
      } else if (d.x === minX) {
        // Source-column labels: outside-LEFT.
        t.attr('x', -6)
         .attr('text-anchor', 'end');
      }
      // Else: keep networkD3's default outside-right positioning.
    });

    // ---- Custom curvy link path generator -----------------------
    // d3-sankey's default sankeyLinkHorizontal() produces a flat
    // ribbon when source and target endpoints share the same y
    // (which is the case for the dominant top flow in a profit-
    // cascade Sankey). Override every link's path with a cubic
    // bezier whose midpoint is pushed downward by `bend` px, so
    // every flow visibly bends like the Apple FY22 reference.
    var bend = 45;  // px of midpoint downward dip
    d3.select(el).selectAll('.link').each(function(d) {
      var sx  = d.source.x + d.source.dx;     // right edge of source
      var tx  = d.target.x;                    // left edge of target
      var sy0 = d.source.y + d.sy;             // top of source slot
      var sy1 = sy0 + d.dy;                    // bottom of source slot
      var ty0 = d.target.y + d.ty;             // top of target slot
      var ty1 = ty0 + d.dy;                    // bottom of target slot

      // Bezier control points at 1/3 and 2/3 along x; their y is the
      // linear interpolation between source and target y, plus a
      // downward bend so the curve dips in the middle.
      var c1x = sx + (tx - sx) / 3;
      var c2x = sx + 2 * (tx - sx) / 3;
      var c1y0 = sy0 + (ty0 - sy0) / 3 + bend;
      var c2y0 = sy0 + 2 * (ty0 - sy0) / 3 + bend;
      var c1y1 = sy1 + (ty1 - sy1) / 3 + bend;
      var c2y1 = sy1 + 2 * (ty1 - sy1) / 3 + bend;

      var path =
        'M' + sx + ',' + sy0 +
        ' C' + c1x + ',' + c1y0 +
        ' '  + c2x + ',' + c2y0 +
        ' '  + tx  + ',' + ty0 +
        ' L' + tx  + ',' + ty1 +
        ' C' + c2x + ',' + c2y1 +
        ' '  + c1x + ',' + c1y1 +
        ' '  + sx  + ',' + sy1 +
        ' Z';

      d3.select(this).attr('d', path);
    });

    // Switch from stroke-based to fill-based ribbons (so opacity
    // doesn't depend on stroke-width, which the custom path doesn't
    // set).
    d3.select(el).selectAll('.link')
      .style('fill', function() {
        return d3.select(this).style('stroke');
      })
      .style('fill-opacity', 0.55)
      .style('stroke', 'none');

    d3.select(el).selectAll('.node rect')
      .style('stroke-width', 0);

    // Default text colour for outside-right + outside-left labels.
    d3.select(el).selectAll('.node text').filter(function(d) {
      var name = (d.name || '').split('  ')[0];
      return insideBar.indexOf(name) === -1;
    }).style('fill', '#5C5B59');

    // Dividend: bold copper for the punchline, even though it lives
    // outside-right with the cost peels.
    d3.select(el).selectAll('.node text').filter(function(d) {
      return (d.name || '').split('  ')[0] === 'Dividend';
    }).style('fill', '#896C4C').style('font-weight', '700');
  }
")

html_out <- "iterations/task_08/v24/pg_income_sankey_v24.html"
pdf_out  <- "iterations/task_08/v24/pg_income_sankey_v24.pdf"

saveWidget(sn, file = normalizePath(html_out, mustWork = FALSE),
           selfcontained = TRUE)

# Use chromote::printToPDF directly so we can pass explicit paper
# dimensions in inches matching the 1280 x 600 px widget. Without this
# Chrome defaults to letter/A4 and scales (and clips) the SVG.
widget_w_in <- 1280 / 96   # ~13.33"
widget_h_in <- 600  / 96   # ~6.25"

b <- chromote::ChromoteSession$new()
b$Page$navigate(paste0("file://", normalizePath(html_out)))
# Sleep instead of waiting on Page.loadEventFired (file:// URLs can fire
# before we register the listener). 2s is enough for networkD3's render
# + the onRender callback to complete.
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
