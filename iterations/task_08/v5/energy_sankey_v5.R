# Task 8 v5 — US Primary Energy Flow, 2023 (LLNL Sankey, 3-stage).
#
# Changes from v4:
#   * Three stages instead of two: Source → Sector → Useful/Rejected.
#     This is the FULL LLNL Sankey structure and shows the canonical
#     insight that only a Sankey can show: roughly two-thirds of US
#     primary energy never reaches a useful end — it's lost as waste
#     heat in transportation engines and electricity-generation plants.
#   * Color bands by DISPOSITION (sage = useful, terracotta = rejected
#     as heat). The colors carry semantic meaning: sage = productive /
#     calm, terracotta = burned / lost. Replaces v4's single-flow
#     highlight which the user found unclear.
#   * Strata coloured neutral (charcoal) so the band colour carries the
#     entire story.
#   * Electricity routing handled explicitly: each fuel that feeds the
#     grid is split between (a) generation loss and (b) sector-delivered
#     electricity, with the sectoral split using LLNL's Electricity →
#     Sector flows.
#
# Source: LLNL "Estimated U.S. Energy Consumption in 2023: 93.6 Quads",
# Oct 2024. Local files:
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

chart_family <- ""  # PDF-native fallback; see task_07 notes.

# ---- Read parsed LLNL flows -------------------------------------------
flows_raw <- read_csv("data/task_08_energy/llnl_us_energy_2023_flows.csv",
                      show_col_types = FALSE)

# Split into primary-energy → target rows and electricity → sector rows.
primary_flows  <- flows_raw %>% filter(source != "Electricity")
elec_to_sector <- flows_raw %>% filter(source == "Electricity")

# Sanity: published totals
cat(sprintf("Primary energy total: %.2f quads\n", sum(primary_flows$quads)))
cat(sprintf("Electricity delivered: %.2f quads\n", sum(elec_to_sector$quads)))

# ---- Sector efficiencies (LLNL footnote) -------------------------------
sector_eta <- c(
  Residential    = 0.65,
  Commercial     = 0.65,
  Industrial     = 0.49,
  Transportation = 0.21
)

# ---- Electricity generation efficiency --------------------------------
elec_input <- sum(primary_flows$quads[primary_flows$target == "Electricity"])
elec_delivered <- sum(elec_to_sector$quads)
eta_gen <- elec_delivered / elec_input
cat(sprintf("Electricity gen efficiency: %.1f%% (%.2f delivered / %.2f input)\n",
            100 * eta_gen, elec_delivered, elec_input))

# Sector shares of delivered electricity (e.g. Residential 4.64/13.3)
elec_sector_share <- elec_to_sector$quads
names(elec_sector_share) <- elec_to_sector$target
elec_sector_share <- elec_sector_share / sum(elec_sector_share)

# ---- Aggregate small renewable sources for legibility -----------------
small_sources <- c("Solar", "Hydro", "Wind", "Geothermal",
                   "Net Electricity Imports")
primary_flows <- primary_flows %>%
  mutate(source = if_else(source %in% small_sources,
                          "Renewables & imports", source)) %>%
  group_by(source, target) %>%
  summarise(quads = sum(quads), .groups = "drop")

# ---- Expand each primary flow into 3-stage paths -----------------------
# For direct source→sector flows: split by sector_eta.
# For source→Electricity flows: route to (a) Generation Loss → Rejected
# and (b) sectors → Useful/Rejected with sector_eta.
expand_direct <- function(src, tgt, q) {
  eta <- sector_eta[[tgt]]
  tibble(
    stage1 = c(src, src),
    stage2 = c(tgt, tgt),
    stage3 = c("Useful Energy", "Rejected Energy"),
    quads  = c(q * eta, q * (1 - eta))
  )
}

expand_via_electricity <- function(src, q) {
  # Generation loss
  gen_loss <- tibble(
    stage1 = src,
    stage2 = "Generation loss",
    stage3 = "Rejected Energy",
    quads  = q * (1 - eta_gen)
  )
  # Delivered electricity → sectors
  delivered <- q * eta_gen
  sector_paths <- map_dfr(names(sector_eta), function(s) {
    flow_s <- delivered * elec_sector_share[[s]]
    eta_s  <- sector_eta[[s]]
    tibble(
      stage1 = c(src, src),
      stage2 = c(s, s),
      stage3 = c("Useful Energy", "Rejected Energy"),
      quads  = c(flow_s * eta_s, flow_s * (1 - eta_s))
    )
  })
  bind_rows(gen_loss, sector_paths)
}

paths <- primary_flows %>%
  pmap_dfr(function(source, target, quads) {
    if (target == "Electricity") {
      expand_via_electricity(source, quads)
    } else {
      expand_direct(source, target, quads)
    }
  }) %>%
  group_by(stage1, stage2, stage3) %>%
  summarise(quads = sum(quads), .groups = "drop")

cat("\n--- Path rows (Source × Sector × Disposition) ---\n")
cat("Total paths:", nrow(paths), "\n")
cat(sprintf("Total useful: %.2f quads (LLNL published: 32.1)\n",
            sum(paths$quads[paths$stage3 == "Useful Energy"])))
cat(sprintf("Total rejected: %.2f quads (LLNL published: 61.5)\n",
            sum(paths$quads[paths$stage3 == "Rejected Energy"])))
cat(sprintf("Total: %.2f quads (LLNL published: 93.6)\n",
            sum(paths$quads)))

# ---- Order strata: largest at top --------------------------------------
src_order <- paths %>% group_by(stage1) %>%
  summarise(s = sum(quads), .groups = "drop") %>%
  arrange(desc(s)) %>% pull(stage1)

sector_order <- c("Generation loss", "Industrial", "Transportation",
                  "Residential", "Commercial")
disp_order   <- c("Rejected Energy", "Useful Energy")

paths <- paths %>%
  mutate(
    stage1 = factor(stage1, levels = src_order),
    stage2 = factor(stage2, levels = sector_order),
    stage3 = factor(stage3, levels = disp_order)
  )

# ---- Color scheme (semantic) -------------------------------------------
# Useful = sage (calm, productive), Rejected = terracotta (burned heat).
disp_colors <- c(
  "Useful Energy"  = pg_palette$heritage_red,   # sage
  "Rejected Energy" = pg_palette$copper          # terracotta
)

# Strata: neutral charcoal so band colour carries the entire story.
stratum_fill <- setNames(
  rep(pg_palette$onyx,
      length(src_order) + length(sector_order) + length(disp_order)),
  c(src_order, sector_order, disp_order)
)
stratum_fill["Useful Energy"]    <- pg_palette$heritage_red
stratum_fill["Rejected Energy"]  <- pg_palette$copper
stratum_fill["Generation loss"]  <- pg_palette$copper

# ---- Helpers -----------------------------------------------------------
fmt_q <- function(x) {
  ifelse(x < 1,
         sprintf("%.2f q", x),
         sprintf("%.1f q", x))
}

# ---- Base plot ---------------------------------------------------------
stratum_w <- 0.22

# Sort so the rejected (terracotta) bands draw first and useful (sage)
# bands draw on top — both are storied; the order keeps the chart reads
# consistent (sage = where attention naturally falls).
paths <- paths %>% arrange(stage3)

p_base <- ggplot(paths,
                 aes(axis1 = stage1, axis2 = stage2, axis3 = stage3,
                     y = quads)) +
  geom_alluvium(aes(fill = stage3),
                width = stratum_w, alpha = 0.75,
                knot.pos = 0.4, curve_type = "sigmoid") +
  geom_stratum(width = stratum_w,
               aes(fill = after_stat(stratum)),
               color = NA) +
  scale_fill_manual(values = c(disp_colors, stratum_fill),
                    guide = "none") +
  scale_x_continuous(limits = c(-0.5, 4.7), expand = c(0, 0)) +
  scale_y_continuous(expand = expansion(mult = c(0.02, 0.07))) +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = NULL) +
  theme_void(base_family = chart_family) +
  theme(plot.margin = margin(t = 14, r = 14, b = 8, l = 14))

# Pull stratum positions for label placement
gb <- ggplot_build(p_base)
strat_layer_idx <- which(sapply(gb$plot$layers,
                                function(l) inherits(l$stat, "StatStratum")))[1]
strat_data <- gb$data[[strat_layer_idx]] %>%
  mutate(y_mid = (ymin + ymax) / 2)

src_pos    <- strat_data %>% filter(x == 1)
sector_pos <- strat_data %>% filter(x == 2)
disp_pos   <- strat_data %>% filter(x == 3)

src_labels <- src_pos %>%
  transmute(
    x = 1 - stratum_w / 2 - 0.02,
    y = y_mid,
    label = paste0(stratum, "   ", fmt_q(count))
  )
sector_labels <- sector_pos %>%
  transmute(
    x = 2,
    y = y_mid,
    label = paste0(stratum, "\n", fmt_q(count))
  )
disp_labels <- disp_pos %>%
  transmute(
    x = 3 + stratum_w / 2 + 0.02,
    y = y_mid,
    label = paste0(fmt_q(count), "   ", stratum),
    color = if_else(stratum == "Useful Energy",
                    pg_palette$heritage_red, pg_palette$copper)
  )

total_q <- sum(paths$quads)

# ---- Final plot --------------------------------------------------------
p <- p_base +
  geom_text(data = src_labels, aes(x = x, y = y, label = label),
            family = chart_family, size = 3.0, color = pg_palette$alloy,
            hjust = 1, vjust = 0.5, inherit.aes = FALSE) +
  geom_text(data = sector_labels, aes(x = x, y = y, label = label),
            family = chart_family, size = 2.8, color = "white",
            fontface = "bold",
            hjust = 0.5, vjust = 0.5, inherit.aes = FALSE,
            lineheight = 0.9) +
  geom_text(data = disp_labels,
            aes(x = x, y = y, label = label, color = color),
            family = chart_family, size = 3.4, fontface = "bold",
            hjust = 0, vjust = 0.5, inherit.aes = FALSE) +
  scale_color_identity() +
  # Column headers
  annotate("text", x = 1, y = total_q + 4,
           label = "PRIMARY ENERGY SOURCE",
           family = chart_family, size = 3.0, fontface = "bold",
           color = pg_palette$onyx, hjust = 0.5) +
  annotate("text", x = 2, y = total_q + 4,
           label = "WHERE IT GOES",
           family = chart_family, size = 3.0, fontface = "bold",
           color = pg_palette$onyx, hjust = 0.5) +
  annotate("text", x = 3, y = total_q + 4,
           label = "WHAT HAPPENS",
           family = chart_family, size = 3.0, fontface = "bold",
           color = pg_palette$onyx, hjust = 0.5)

out_pdf <- "iterations/task_08/v5/energy_sankey_v5.pdf"
ggsave(out_pdf, p, width = 32, height = 17, units = "cm", device = "pdf")
cat("\nSaved:", out_pdf, "\n")
