# Task 8 v7 — US Primary Energy Flow, 2023 (efficiency-coloured rebuild).
#
# Analytical departure from the canonical LLNL chart (so this is not a
# copy). LLNL's diagram colours flows by source (one hue per fuel). This
# rebuild colours flows by *disposition* (Useful vs Rejected), which makes
# a different question primary: not "where does each fuel go?" but "where
# is energy lost?". Every band keeps its useful/rejected colour from the
# left axis to the right, so the rejected-energy story reads at every
# stage of the chain — not just in the right-most column. The four
# stratum nodes are kept neutral charcoal; only the end disposition
# strata pick up the semantic colour. Source aggregation also groups
# small renewables ( <2 q each ) into "Renewables & imports" for legibility.
#
# v7 changes vs v6:
#   * Re-rendered with the analytical-departure framing made explicit in
#     this header (and matched in reference_log.md). No data changes.
#
# Changes from v5 → v6:
#   * Adds an EXPLICIT "Electricity generation" intermediate node — the
#     iconic feature of the LLNL Sankey: at the source column, fuels
#     visibly DIVERGE into "via electricity" and "direct" routes; at
#     the end-use column they re-converge from both routes.
#   * Four ggalluvial axes: Source → Conversion (Electricity gen | Direct
#     use) → End-use (sectors + Generation loss) → Disposition (Useful |
#     Rejected).
#
# Source: LLNL "Estimated U.S. Energy Consumption in 2023: 93.6 Quads",
# Oct 2024. Local files (data comes from these — no hand-typed numbers
# in this script):
#   data/task_08_energy/llnl_us_energy_2023.pdf       (canonical source)
#   data/task_08_energy/llnl_us_energy_2023_flows.csv (parsed flows)
# Sector efficiencies from the LLNL footnote: Residential 65 %,
# Commercial 65 %, Industrial 49 %, Transportation 21 %.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(purrr)
  library(ggplot2)
  library(ggalluvial)
})

source("design_system.R")

chart_family <- ""

# ---- Read LLNL flows --------------------------------------------------
flows_raw <- read_csv("data/task_08_energy/llnl_us_energy_2023_flows.csv",
                      show_col_types = FALSE)
primary_flows  <- flows_raw %>% filter(source != "Electricity")
elec_to_sector <- flows_raw %>% filter(source == "Electricity")

# Aggregate small renewable sources for legibility.
small_sources <- c("Solar", "Hydro", "Wind", "Geothermal",
                   "Net Electricity Imports")
primary_flows <- primary_flows %>%
  mutate(source = if_else(source %in% small_sources,
                          "Renewables & imports", source)) %>%
  group_by(source, target) %>%
  summarise(quads = sum(quads), .groups = "drop")

# ---- Routing parameters -----------------------------------------------
sector_eta <- c(
  Residential    = 0.65,
  Commercial     = 0.65,
  Industrial     = 0.49,
  Transportation = 0.21
)
elec_input     <- sum(primary_flows$quads[primary_flows$target == "Electricity"])
elec_delivered <- sum(elec_to_sector$quads)
eta_gen        <- elec_delivered / elec_input
elec_share     <- setNames(elec_to_sector$quads / sum(elec_to_sector$quads),
                           elec_to_sector$target)

cat(sprintf("Electricity gen efficiency: %.1f%%\n", 100 * eta_gen))

# ---- Build path table (4 stages) --------------------------------------
# Each row = one complete path (source, conversion, end_use, disposition,
# quads). Three path types:
#   1. Direct fuel: source→Direct→sector→{Useful,Rejected}
#   2. Via grid:    source→ElectricityGen→sector→{Useful,Rejected}
#   3. Gen loss:    source→ElectricityGen→GenerationLoss→Rejected
build_direct_paths <- function(src, sec, q) {
  eta <- sector_eta[[sec]]
  tibble(
    source = src, conversion = "Direct use", end_use = sec,
    disposition = c("Useful Energy", "Rejected Energy"),
    quads = c(q * eta, q * (1 - eta))
  )
}
build_grid_paths <- function(src, q_to_grid) {
  delivered <- q_to_grid * eta_gen
  gen_loss  <- q_to_grid * (1 - eta_gen)
  sector_paths <- map_dfr(names(sector_eta), function(s) {
    flow_s <- delivered * elec_share[[s]]
    eta_s  <- sector_eta[[s]]
    tibble(
      source = src, conversion = "Electricity gen", end_use = s,
      disposition = c("Useful Energy", "Rejected Energy"),
      quads = c(flow_s * eta_s, flow_s * (1 - eta_s))
    )
  })
  loss <- tibble(
    source = src, conversion = "Electricity gen",
    end_use = "Generation loss",
    disposition = "Rejected Energy",
    quads = gen_loss
  )
  bind_rows(sector_paths, loss)
}

paths <- primary_flows %>%
  pmap_dfr(function(source, target, quads) {
    if (target == "Electricity") {
      build_grid_paths(source, quads)
    } else {
      build_direct_paths(source, target, quads)
    }
  }) %>%
  filter(quads > 0.005)  # drop near-zero paths to declutter

cat(sprintf("Paths: %d | Useful: %.2f q | Rejected: %.2f q | Total: %.2f q\n",
            nrow(paths),
            sum(paths$quads[paths$disposition == "Useful Energy"]),
            sum(paths$quads[paths$disposition == "Rejected Energy"]),
            sum(paths$quads)))

# ---- Order strata: largest at top -------------------------------------
src_order <- paths %>% group_by(source) %>%
  summarise(s = sum(quads), .groups = "drop") %>%
  arrange(desc(s)) %>% pull(source)
conv_order   <- c("Direct use", "Electricity gen")
end_order    <- c("Industrial", "Transportation",
                  "Generation loss", "Residential", "Commercial")
disp_order   <- c("Rejected Energy", "Useful Energy")

paths <- paths %>%
  mutate(
    source      = factor(source,      levels = src_order),
    conversion  = factor(conversion,  levels = conv_order),
    end_use     = factor(end_use,     levels = end_order),
    disposition = factor(disposition, levels = disp_order)
  )

# ---- Colours (semantic) -----------------------------------------------
disp_colors <- c(
  "Useful Energy"   = pg_palette$heritage_red,  # sage = useful
  "Rejected Energy" = pg_palette$copper         # terracotta = burned heat
)
# All strata are neutral charcoal; disposition strata pick up the
# semantic colour so the right column reads as the chart's climax.
all_strata <- c(src_order, conv_order, end_order, disp_order)
stratum_fill <- setNames(rep(pg_palette$onyx, length(all_strata)),
                         all_strata)
stratum_fill["Useful Energy"]    <- pg_palette$heritage_red
stratum_fill["Rejected Energy"]  <- pg_palette$copper
stratum_fill["Generation loss"]  <- pg_palette$copper

# ---- Helpers ----------------------------------------------------------
fmt_q <- function(x) {
  ifelse(x < 1, sprintf("%.2f q", x), sprintf("%.1f q", x))
}

stratum_w <- 0.20

# Sort so the (terracotta) rejected bands draw first, sage useful on top.
paths <- paths %>% arrange(disposition)

# ---- Base plot --------------------------------------------------------
p_base <- ggplot(paths,
                 aes(axis1 = source,
                     axis2 = conversion,
                     axis3 = end_use,
                     axis4 = disposition,
                     y = quads)) +
  geom_alluvium(aes(fill = disposition),
                width = stratum_w, alpha = 0.7,
                knot.pos = 0.4, curve_type = "sigmoid") +
  geom_stratum(width = stratum_w,
               aes(fill = after_stat(stratum)),
               color = NA) +
  scale_fill_manual(values = c(disp_colors, stratum_fill),
                    guide = "none") +
  scale_x_continuous(limits = c(-0.4, 5.4), expand = c(0, 0)) +
  scale_y_continuous(expand = expansion(mult = c(0.04, 0.10))) +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = NULL) +
  theme_void(base_family = chart_family) +
  theme(plot.margin = margin(t = 16, r = 14, b = 14, l = 14))

# Pull rendered stratum positions
gb <- ggplot_build(p_base)
strat_layer_idx <- which(sapply(gb$plot$layers,
                                function(l) inherits(l$stat, "StatStratum")))[1]
strat_data <- gb$data[[strat_layer_idx]] %>%
  mutate(y_mid = (ymin + ymax) / 2)

src_pos    <- strat_data %>% filter(x == 1)
conv_pos   <- strat_data %>% filter(x == 2)
end_pos    <- strat_data %>% filter(x == 3)
disp_pos   <- strat_data %>% filter(x == 4)

src_labels <- src_pos %>%
  transmute(x = 1 - stratum_w / 2 - 0.02, y = y_mid,
            label = paste0(stratum, "   ", fmt_q(count)))
conv_labels <- conv_pos %>%
  transmute(x = 2, y = y_mid,
            label = paste0(stratum, "\n", fmt_q(count)))
end_labels <- end_pos %>%
  transmute(x = 3, y = y_mid,
            label = paste0(stratum, "\n", fmt_q(count)))
disp_labels <- disp_pos %>%
  transmute(x = 4 + stratum_w / 2 + 0.04, y = y_mid,
            label = paste0(fmt_q(count), "   ", stratum),
            color = if_else(stratum == "Useful Energy",
                            pg_palette$heritage_red, pg_palette$copper))

total_q <- sum(paths$quads)

# ---- Final plot -------------------------------------------------------
p <- p_base +
  geom_text(data = src_labels, aes(x = x, y = y, label = label),
            family = chart_family, size = 2.9, color = pg_palette$alloy,
            hjust = 1, vjust = 0.5, inherit.aes = FALSE) +
  geom_text(data = conv_labels, aes(x = x, y = y, label = label),
            family = chart_family, size = 2.6, color = "white",
            fontface = "bold", hjust = 0.5, vjust = 0.5,
            inherit.aes = FALSE, lineheight = 0.9) +
  geom_text(data = end_labels, aes(x = x, y = y, label = label),
            family = chart_family, size = 2.6, color = "white",
            fontface = "bold", hjust = 0.5, vjust = 0.5,
            inherit.aes = FALSE, lineheight = 0.9) +
  geom_text(data = disp_labels,
            aes(x = x, y = y, label = label, color = color),
            family = chart_family, size = 3.6, fontface = "bold",
            hjust = 0, vjust = 0.5, inherit.aes = FALSE) +
  scale_color_identity() +
  # Column headers
  annotate("text", x = 1, y = total_q + 5,
           label = "PRIMARY ENERGY SOURCE",
           family = chart_family, size = 2.9, fontface = "bold",
           color = pg_palette$onyx, hjust = 0.5) +
  annotate("text", x = 2, y = total_q + 5,
           label = "CONVERSION",
           family = chart_family, size = 2.9, fontface = "bold",
           color = pg_palette$onyx, hjust = 0.5) +
  annotate("text", x = 3, y = total_q + 5,
           label = "END USE",
           family = chart_family, size = 2.9, fontface = "bold",
           color = pg_palette$onyx, hjust = 0.5) +
  annotate("text", x = 4, y = total_q + 5,
           label = "WHAT HAPPENS",
           family = chart_family, size = 2.9, fontface = "bold",
           color = pg_palette$onyx, hjust = 0.5)

out_pdf <- "iterations/task_08/v7/energy_sankey_v7.pdf"
ggsave(out_pdf, p, width = 34, height = 18, units = "cm", device = "pdf")
cat("\nSaved:", out_pdf, "\n")
