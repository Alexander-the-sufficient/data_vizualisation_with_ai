# Task 8 v4 — US Primary Energy Flow, 2023 (LLNL Sankey).
#
# Topic pivot from the v1-v3 federal-budget Sankey. Reason: federal
# money is fungible; the v1-v3 chart's bands were a proportional split,
# not a true measured flow. The LLNL US Energy Flow is the *canonical*
# Sankey example used in every data-viz course because every band is a
# real measurable flow of energy in quadrillion BTU (quads). It also
# lets us show the famous "rejected energy" insight: about two-thirds
# of US primary energy is lost as waste heat before reaching a useful
# end. That insight is impossible to communicate in any forbidden chart
# type (bar / line / pie / etc.).
#
# Source: Lawrence Livermore National Laboratory (LLNL),
# "Estimated U.S. Energy Consumption in 2023: 93.6 Quads", October 2024.
# LLNL is the canonical publisher; the underlying numbers come from the
# US Department of Energy / EIA SEDS (2024).
#   PDF: https://flowcharts.llnl.gov/sites/flowcharts/files/
#        2024-10/energy-2023-united-states.pdf
#   Local files:
#     data/task_08_energy/llnl_us_energy_2023.pdf  (the canonical source)
#     data/task_08_energy/llnl_us_energy_2023_flows.csv  (parsed once)
# The CSV is a transcription of every flow value visible on the LLNL
# PDF chart. Per-source totals reconcile to the published source totals
# within LLNL's stated rounding tolerance ("Totals may not equal sum of
# components due to independent rounding"). The chart script reads from
# the CSV — no numbers are typed in this file.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tidyr)
  library(ggplot2)
  library(ggalluvial)
})

source("design_system.R")

chart_family <- ""  # PDF-native fallback; see task_07 notes.

# ---- Read the parsed LLNL flow data -----------------------------------
flows_raw <- read_csv("data/task_08_energy/llnl_us_energy_2023_flows.csv",
                      show_col_types = FALSE)

cat("Flow rows in CSV:", nrow(flows_raw), "\n")

# ---- Verify per-source totals against published values ----------------
# Published source totals from LLNL 2023 chart (in quads):
#   Solar 0.89, Nuclear 8.1, Hydro 0.82, Wind 1.5, Geothermal 0.12,
#   Natural Gas 33.4, Coal 8.17, Biomass 5, Petroleum 35.4,
#   Net Electricity Imports 0.07. Total: 93.6 quads.
src_check <- flows_raw %>%
  group_by(source) %>%
  summarise(sum_flows = sum(quads), .groups = "drop")
print(src_check)
cat(sprintf("Total primary energy in CSV: %.2f quads (LLNL published: 93.6)\n",
            sum(flows_raw$quads)))

# ---- Aggregate small sources for legibility ---------------------------
# The chart aggregates the five smallest non-fossil sources (Solar,
# Hydro, Wind, Geothermal, Net Electricity Imports) into "Renewables &
# imports" — they each sum to less than 1.5 quads individually and
# together account for <4% of primary energy, so collapsing them keeps
# the chart legible without losing the story (which is dominated by
# the big three: Petroleum, Natural Gas, Coal/Nuclear).
small_sources <- c("Solar", "Hydro", "Wind", "Geothermal",
                   "Net Electricity Imports")
flows <- flows_raw %>%
  mutate(source_grouped = if_else(source %in% small_sources,
                                  "Renewables & imports",
                                  source)) %>%
  group_by(source_grouped, target) %>%
  summarise(quads = sum(quads), .groups = "drop") %>%
  rename(source = source_grouped)

# Rename "Electricity" target to "Electricity generation" for clarity.
flows <- flows %>%
  mutate(target = if_else(target == "Electricity",
                          "Electricity generation",
                          target))

# Source totals (after aggregation)
src_totals <- flows %>%
  group_by(source) %>%
  summarise(amount = sum(quads), .groups = "drop")

# Target totals
tgt_totals <- flows %>%
  group_by(target) %>%
  summarise(amount = sum(quads), .groups = "drop")

cat("\n--- Source totals (quads) ---\n"); print(src_totals)
cat("\n--- Target totals (quads) ---\n"); print(tgt_totals)

total_primary <- sum(flows$quads)
cat(sprintf("\nTotal primary energy: %.2f quads\n", total_primary))

# ---- Order strata: largest at top --------------------------------------
src_levels_top_first <- src_totals %>% arrange(desc(amount)) %>% pull(source)
tgt_levels_top_first <- c("Electricity generation",
                          "Industrial",
                          "Transportation",
                          "Residential",
                          "Commercial")
flows <- flows %>%
  mutate(
    source = factor(source, levels = src_levels_top_first),
    target = factor(target, levels = tgt_levels_top_first)
  )

# ---- Story flows: highlight Petroleum → Transportation -----------------
# Headline story: petroleum-fueled transportation is the dominant
# primary-energy path in the US (24.8 of 93.6 quads, ~26%) — and the
# most wasteful: ~80% of it is rejected as heat in internal-combustion
# engines. Heritage Red marks ONLY this single flow + the Transportation
# stratum + the Petroleum stratum. Everything else is the neutral cream
# from the design system.
flows <- flows %>%
  mutate(storyflow = factor(case_when(
    source == "Petroleum" & target == "Transportation" ~ "Petroleum → Transportation",
    TRUE                                                ~ "Other"
  ), levels = c("Other", "Petroleum → Transportation")))

flows <- flows %>% arrange(storyflow)

flow_colors <- c(
  "Other"                       = pg_palette$dark_quartz,
  "Petroleum → Transportation"  = pg_palette$heritage_red
)

stratum_fill <- setNames(
  rep(pg_palette$onyx,
      length(src_levels_top_first) + length(tgt_levels_top_first)),
  c(src_levels_top_first, tgt_levels_top_first)
)
stratum_fill["Petroleum"]      <- pg_palette$heritage_red
stratum_fill["Transportation"] <- pg_palette$heritage_red

# ---- Helpers -----------------------------------------------------------
# Show 1 decimal place for everything >= 1 quad so big similar-magnitude
# sources (e.g. Petroleum 35.4 vs Natural Gas 35.2) stay distinguishable
# in the labels. Sub-1 quad values get 2 decimals to retain precision.
fmt_q <- function(x) {
  ifelse(x < 1,
         sprintf("%.2f quads", x),
         sprintf("%.1f quads", x))
}

# ---- Base plot ---------------------------------------------------------
stratum_w <- 1/4

p_base <- ggplot(flows,
                 aes(axis1 = source, axis2 = target, y = quads)) +
  geom_alluvium(aes(fill = storyflow),
                width = stratum_w, alpha = 0.75,
                knot.pos = 0.4, curve_type = "sigmoid") +
  geom_stratum(width = stratum_w,
               aes(fill = after_stat(stratum)),
               color = NA) +
  scale_fill_manual(values = c(flow_colors, stratum_fill),
                    guide = "none") +
  scale_x_continuous(limits = c(-1.6, 4.0), expand = c(0, 0)) +
  scale_y_continuous(expand = expansion(mult = c(0.02, 0.07))) +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = NULL) +
  theme_void(base_family = chart_family) +
  theme(plot.margin = margin(t = 14, r = 14, b = 8, l = 14))

gb <- ggplot_build(p_base)
strat_layer_idx <- which(sapply(gb$plot$layers,
                                function(l) inherits(l$stat, "StatStratum")))[1]
strat_data <- gb$data[[strat_layer_idx]] %>%
  mutate(y_mid = (ymin + ymax) / 2)

src_pos <- strat_data %>% filter(x == 1)
tgt_pos <- strat_data %>% filter(x == 2)

src_labels <- src_pos %>%
  transmute(
    x  = 1 - stratum_w / 2 - 0.02,
    y  = y_mid,
    label = paste0(stratum, "   ", fmt_q(count))
  )
tgt_labels <- tgt_pos %>%
  transmute(
    x  = 2 + stratum_w / 2 + 0.02,
    y  = y_mid,
    label = paste0(fmt_q(count), "   ", stratum)
  )

petroleum_y      <- src_pos$y_mid[src_pos$stratum == "Petroleum"]
transportation_y <- tgt_pos$y_mid[tgt_pos$stratum == "Transportation"]

# ---- Final plot --------------------------------------------------------
p <- p_base +
  geom_text(data = src_labels, aes(x = x, y = y, label = label),
            family = chart_family, size = 3.0, color = pg_palette$alloy,
            hjust = 1, vjust = 0.5, inherit.aes = FALSE) +
  geom_text(data = tgt_labels, aes(x = x, y = y, label = label),
            family = chart_family, size = 3.0, color = pg_palette$alloy,
            hjust = 0, vjust = 0.5, inherit.aes = FALSE) +
  annotate("text", x = 1, y = total_primary + 4,
           label = "PRIMARY ENERGY SOURCE",
           family = chart_family, size = 3.2, fontface = "bold",
           color = pg_palette$onyx, hjust = 0.5) +
  annotate("text", x = 2, y = total_primary + 4,
           label = "WHERE IT GOES",
           family = chart_family, size = 3.2, fontface = "bold",
           color = pg_palette$onyx, hjust = 0.5) +
  # Story callout — Petroleum side (left). Pushed past the longest
  # source label ("Renewables & imports 3.4 quads") so it doesn't
  # collide with any stratum label.
  annotate("text",
           x = 1 - stratum_w / 2 - 1.45,
           y = petroleum_y,
           label = "Petroleum supplies\n38% of US primary\nenergy.",
           family = chart_family, size = 3.1,
           color = pg_palette$heritage_red,
           fontface = "bold",
           hjust = 1, vjust = 0.5,
           lineheight = 0.95) +
  # Story callout — Transportation side (right). Pushed past the
  # "27.9 quads Transportation" label which extends far right.
  annotate("text",
           x = 2 + stratum_w / 2 + 1.05,
           y = transportation_y,
           label = "...and 89% of\ntransportation runs\non it.",
           family = chart_family, size = 3.1,
           color = pg_palette$heritage_red,
           fontface = "bold",
           hjust = 0, vjust = 0.5,
           lineheight = 0.95)

out_pdf <- "iterations/task_08/v4/energy_sankey_v4.pdf"
ggsave(out_pdf, p, width = 30, height = 17, units = "cm", device = "pdf")
cat("\nSaved:", out_pdf, "\n")
