# Task 2 v1 — honest remake of the White House steel chart.
# Fixes applied vs the original:
#   1. Zero baseline (the core manipulation in the original)
#   2. Single neutral color — drops the misleading red/green double-encoding
#   3. Five-year context (2021–2025) instead of a cherry-picked 2-year comparison
#   4. Direct labels on bars (data-ink discipline, no legend needed)
#   5. Visible data source

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

source("design_system.R")

# Font: cairo + Google Fonts aren't installed on this machine, so fall back to
# the PDF-native sans (Helvetica). Design_system.md's Inter preference still stands
# for any machine that has showtext + cairo available.
chart_family <- ""

raw <- read_excel("data/task_02/steel_data_us_21-25.xlsx", sheet = 1, skip = 1)

us <- raw %>%
  filter(Country == "United States") %>%
  mutate(across(-Country, as.numeric)) %>%
  pivot_longer(-Country, names_to = "year", values_to = "kt") %>%
  mutate(
    year = as.integer(year),
    mt   = kt / 1000
  )

p <- ggplot(us, aes(x = factor(year), y = mt)) +
  geom_col(fill = pg_palette$alloy, width = 0.62) +
  geom_text(
    aes(label = sprintf("%.1f", mt)),
    vjust = -0.6, size = 3.4, family = chart_family, color = pg_palette$onyx
  ) +
  scale_y_continuous(
    limits = c(0, 100),
    breaks = seq(0, 100, 20),
    expand = expansion(mult = c(0, 0.08))
  ) +
  labs(
    x = NULL,
    y = "Million metric tons (Mt)"
  ) +
  theme_pg(base_family = chart_family)

out_pdf <- "iterations/task_02/v1/steel_production_v1.pdf"
ggsave(out_pdf, p, width = 24, height = 14, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
