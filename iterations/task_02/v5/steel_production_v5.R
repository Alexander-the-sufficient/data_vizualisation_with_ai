# Task 2 v5 — bare line, no in-chart annotations.
# v5 change vs v4:
#   * Removed the three text anchors ("1973 peak", "GFC trough", "2025")
#     and the `ann` data frame that placed them. The line alone now carries
#     the story; the title/subtitle (in Quarto) name the peak, the trough,
#     and the recent flat stretch. Stripping the in-chart labels pushes the
#     data-ink ratio up and keeps the chart reusable if the headline copy
#     changes.
#
# v4 had removed point markers and the per-anchor value labels; see v4 header
#   for the full lineage (point markers, colour highlight, value labels).
# v3: design-system palette migration. v2: extended 5yr -> 56yr window.
#
# Chart-type choice: line chart (per CLAUDE.md "line for time series").
#   Zero baseline kept (not required for a line, but honest about scale and
#   matches the bar-chart convention of the original task-1 example).
#
# Sources spliced:
#   * USGS DS140 (Iron and Steel Statistics, 1900-2021), Steel sheet,
#     "Raw steel production" column. Used 1970-2020 portion.
#   * World Steel Association, P1 crude steel total, USA, 2021-2025.
#   Both report 2021 = 85.8 Mt (sanity check passes).

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

source("design_system.R")

chart_family <- ""

# --- 1. Historical: USGS DS140, 1970-2020 ----------------------------------
ds140 <- read_excel(
  "data/task_02/usgs_ds140_iron_steel_2021.xlsx",
  sheet = "Steel",
  skip  = 5
) %>%
  select(year_chr = Year, raw_steel_t = `Raw steel production`) %>%
  mutate(year = suppressWarnings(as.integer(year_chr)),
         raw_steel_mt = as.numeric(raw_steel_t) / 1e6) %>%
  filter(!is.na(year), !is.na(raw_steel_mt), year >= 1970, year <= 2020) %>%
  select(year, mt = raw_steel_mt)

# --- 2. Recent: worldsteel, 2021-2025 --------------------------------------
ws <- read_excel(
  "data/task_02/steel_data_us_21-25.xlsx",
  sheet = 1,
  skip = 1
) %>%
  filter(Country == "United States") %>%
  mutate(across(-Country, as.numeric)) %>%
  pivot_longer(-Country, names_to = "year", values_to = "kt") %>%
  mutate(year = as.integer(year), mt = kt / 1000) %>%
  select(year, mt)

us <- bind_rows(ds140, ws) %>% arrange(year)

cat("Series: ", min(us$year), "-", max(us$year),
    " (n =", nrow(us), ")\n")

p <- ggplot(us, aes(x = year, y = mt)) +
  geom_line(color = pg_palette$alloy, linewidth = 0.7) +
  scale_x_continuous(breaks = seq(1970, 2025, 10),
                     expand = expansion(mult = c(0.02, 0.04))) +
  scale_y_continuous(limits = c(0, 150),
                     breaks = seq(0, 150, 25),
                     expand = expansion(mult = c(0, 0.04))) +
  labs(x = NULL, y = "Million metric tons (Mt)") +
  theme_pg(base_family = chart_family)

out_pdf <- "iterations/task_02/v5/steel_production_v5.pdf"
ggsave(out_pdf, p, width = 26, height = 12, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
