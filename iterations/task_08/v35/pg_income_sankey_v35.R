# Task 8 v35 — Partners Group 2024 income statement Sankey, networkD3.
#
# v35 = v34 EXACTLY, with ONE change: the Retained earnings node + link are
#   recoloured from light_quartz (#ECEAE4, a near-white cream that rendered
#   almost invisible against the white page at 0.55 stroke-opacity) to
#   medium_quartz (#BAB3AB, a muted taupe). The 36 m retained sliver now has
#   enough contrast to read clearly while staying a light, "minor leftover"
#   neutral — distinct from copper (Dividend), dark_stone (cost) and
#   dark_quartz (source). Topology, values, every other colour: byte-for-byte
#   v34.
#
# v34 = v33 aesthetics + the NET-FINANCE topology change.
#
# v34 changes vs v33 (NET-FINANCE — keeps the EBITDA/EBIT/PBT cascade):
#   v31-v33 showed finance income (+120.9) and finance expense (-59.8) as two
#   separate flows around the EBIT -> PBT bridge: finance expense peeled off
#   EBIT, finance income joined PBT as an inflow. Both crowded the mid-chart
#   region and the inflow-at-the-end read awkwardly.
#
#   v34 NETS them into a SINGLE inflow. The two PG-reported line items combine
#   to a net financial result of +61.1 m (120.9 income - 59.8 expense), which
#   is exactly the bridge from EBIT (1,308.8) to PBT (1,369.9). So:
#     * the full EBIT (1,308.8) flows straight into PBT — no finance-expense
#       peel, no ebit_to_pbt remainder;
#     * one 'Net finance income' node (+61.1) joins PBT as a short, distinct
#       taupe tributary rising into PBT's bottom (the v33 tributary treatment,
#       now uncluttered because the finance-expense peel is gone);
#     * its two-line label 'Net finance income / 61 m' sits just below the
#       tributary, in open space.
#   This declutters the whole middle and leaves a single clean inflow instead
#   of an income inflow + an expense peel. The 121 / 60 gross split is no
#   longer drawn; it is disclosed in the chart subtitle and this log.
#
#   Everything else — the Revenue -> EBITDA -> EBIT -> PBT -> Net profit ->
#   Dividend cascade, every other value, palette, cascade labels, copper
#   Dividend, no heritage red — is identical to v33.
#
# Accounting-correct topology (CHF m), PG AR2024 p.39:
#   Revenue (operating 2,135.6 = PE/Infra/PC/RE/Royalties + Other op inc,
#     EXCLUDING finance income)
#       -> EBITDA (1,357.4) + Operating costs (778.2)
#   EBITDA -> EBIT (1,308.8) + D&A (48.6)
#   EBIT (1,308.8) -> Profit before tax (full EBIT flows through)
#   Net finance income (+61.1 = 120.9 income - 59.8 expense) -> PBT (tributary)
#   Profit before tax (1,369.9) -> Net profit (1,127.7) + Tax (242.2)
#   Net profit -> Dividend (1,091.3) + Retained (36.4)
#
# Palette (v28, warm-neutral minimalist, copper the only colored accent,
# NO heritage red):
#   - source   -> dark_quartz `#ACA39A` (warm taupe, recedes)
#   - profit   -> copper       `#896C4C` (warm bronze, the story accent)
#   - cost     -> dark_stone   `#7E8182` (warm gray, neutral mass)
#   - retained -> medium_quartz `#BAB3AB` (muted taupe; v35, was a near-
#                 invisible light_quartz cream in v34)
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
net_finance       <- finance_inc - finance_exp             # ~ +61.1 m (120.9 income - 59.8 expense)
pretax_profit     <- ebit + net_finance                    # ~ 1,369.9 m (EBIT + net finance result)

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
  # Column 1 — operating-revenue sources.
  "Private equity",       rev_pe,             "source",
  "Infrastructure",       rev_infra,          "source",
  "Private credit",       rev_pc,             "source",
  "Real estate",          rev_re,             "source",
  "Other op income",      other_op_inc,       "source",
  "Net finance income",   net_finance,        "source",
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
  # Column 5 — Profit before tax (full EBIT flows through; net finance joins).
  "Profit before tax",    pretax_profit,      "profit",
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
  # Net finance income is a SEPARATE source feeding Profit before tax.
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
  # Full EBIT flows into PBT; the net financial result joins as a tributary.
  "EBIT",                "Profit before tax",   ebit,
  "Net finance income",  "Profit before tax",   net_finance,
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
  pg_palette$medium_quartz   # retained — muted taupe (#BAB3AB); v35, was
                             #            light_quartz #ECEAE4 (near-invisible)
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
#      Revenue -> EBITDA -> EBIT -> PBT -> Net profit visibly arcs up
#   5. TRIBUTARY (v34): the single Net finance income node moved to just left
#      of PBT and clearly below the copper band, its link painted taupe, so it
#      rises into PBT as a short distinct inflow — no spike, and the mid-chart
#      region is uncluttered now that the finance-expense peel is gone.
sn <- htmlwidgets::onRender(sn, "
  function(el, x) {
    document.body.style.margin  = '0';
    document.body.style.padding = '0';
    document.documentElement.style.margin  = '0';
    document.documentElement.style.padding = '0';

    // Distinct column x positions (ascending). Column indices:
    //   0 = sources, 1 = Revenue, 2 = EBITDA/Op costs, 3 = EBIT/D&A/...,
    //   4 = PBT/Finance exp, 5 = Net profit/Tax, 6 = Dividend/Retained.
    var xsSet = [];
    d3.select(el).selectAll('.node').each(function(d) {
      if (typeof d.x !== 'undefined' && xsSet.indexOf(d.x) === -1) xsSet.push(d.x);
    });
    xsSet.sort(function(a, b) { return a - b; });
    var minX     = xsSet[0];
    var ebitColX = xsSet[3];  // EBIT column — one left of PBT's column

    // --- Cascade subtotals — labelled OUTSIDE the bar, multi-line stacked.
    var aboveBar = ['Revenue', 'EBITDA', 'EBIT', 'Profit before tax',
                    'Net profit'];
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
      } else if (d.x === minX && name !== 'Net finance income') {
        // Source-column labels outside-LEFT (Net finance income handled below,
        // because the tributary fix relocates it out of the source column).
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

    // --- TRIBUTARY — relocate Net finance income to just left of, and
    // just below, the (already-shifted) Profit before tax node. ---
    // First capture PBT's final geometry (after its upward shift).
    var pbt = null;
    d3.select(el).selectAll('.node').each(function(d) {
      if ((d.name || '').split('  ')[0] === 'Profit before tax') pbt = d;
    });

    // Where does the Net finance income -> PBT link enter PBT vertically?
    // d.ty is the target-side stacked offset of that link within PBT;
    // aligning the tributary to that point makes the merge read cleanly.
    var finToPbtTy = null;
    d3.select(el).selectAll('.link').each(function(d) {
      if ((d.source.name || '').split('  ')[0] === 'Net finance income' &&
          (d.target.name || '').split('  ')[0] === 'Profit before tax') {
        finToPbtTy = d.ty + d.dy / 2;   // centre of the link's PBT entry band
      }
    });

    if (pbt) {
      d3.select(el).selectAll('.node').each(function(d) {
        if ((d.name || '').split('  ')[0] === 'Net finance income') {
          // Sit just LEFT of PBT and clearly BELOW the copper EBIT->PBT band,
          // so the inflow reads as a short distinct tributary rising into
          // PBT's bottom — not a taupe spike embedded in the copper. (The
          // mid-chart region is now uncluttered: with the finance-expense
          // peel gone, this is the only inflow here.)
          d.x = pbt.x - 37;
          var entryCentreY = (finToPbtTy !== null)
            ? pbt.y + finToPbtTy
            : pbt.y + d.dy / 2;
          d.y = entryCentreY + 14;        // node drops below the PBT entry; band rises gently in
        }
      });
    }

    // Apply the moved coordinates to every node group.
    d3.select(el).selectAll('.node').attr('transform', function(d) {
      return 'translate(' + d.x + ',' + d.y + ')';
    });

    // --- LABEL — Net finance income label as TWO compact lines sitting just
    // below the tributary, in the open pocket left of the PBT->Tax band.
    // The net node is small (~9 px), so the label drops below the rising
    // tributary band and is nudged a little left of PBT to clear the Tax band.
    d3.select(el).selectAll('.node text').each(function(d) {
      if ((d.name || '').split('  ')[0] === 'Net finance income') {
        var parts  = (d.name || '').split('  ').filter(function(s){ return s.length; });
        var fiName = parts[0] || 'Net finance income';
        var fiVal  = parts[1] || '';
        var cx = -7;              // node-local; label centre lands ~pbt.x - 44, clear of Tax band
        var firstY = 23;          // node-local; first line drops below the rising tributary band
        var t = d3.select(this);
        t.text('')
          .attr('x', cx)
          .attr('y', firstY)
          .attr('dy', '0')
          .attr('text-anchor', 'middle')
          .style('fill', '#5C5B59');
        t.append('tspan').attr('x', cx).attr('dy', '0').text(fiName);
        t.append('tspan').attr('x', cx).attr('dy', '1.1em').text(fiVal);
      }
    });

    // --- COLOUR — paint the Net finance income -> PBT link taupe to match the
    // other income-source links (PE / Infra / ... -> Revenue are taupe too).
    // Net finance income is an income source joining the cascade, not part of
    // the copper profit chain, so taupe reads as a distinct tributary.
    d3.select(el).selectAll('.link').each(function(d) {
      if ((d.source.name || '').split('  ')[0] === 'Net finance income' &&
          (d.target.name || '').split('  ')[0] === 'Profit before tax') {
        d3.select(this).style('stroke', '#ACA39A');
      }
    });

    // d3-sankey v3 smooth-Bezier link path. Reads d.source.x / d.source.y
    // and d.target.x / d.target.y dynamically, so the relocated Finance
    // income node (and all profit-chain + Finance-expense shifts) flow
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

html_out <- "iterations/task_08/v35/pg_income_sankey_v35.html"
pdf_out  <- "iterations/task_08/v35/pg_income_sankey_v35.pdf"

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
