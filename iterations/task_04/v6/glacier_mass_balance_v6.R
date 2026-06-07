# Task 4 v6 — Silvrettagletscher annual mass balance, 1915-2025.
# v6 changes vs v5:
#   - Scope narrowed from "all monitored Swiss glaciers, area-weighted"
#     to a single glacier: Silvrettagletscher (A10g-05). The aggregated
#     series mixed glaciers with very different baselines, observer
#     histories, and areas; a single-glacier record removes that noise
#     and shows one continuous, comparable measurement.
#   - Silvretta has an unbroken record 1915-2025 (111 years, no gaps),
#     so the chart now spans the full series instead of starting at 1956.
#   - In-panel annotations removed: the two label blocks and their
#     leader segments are gone. The chart now carries only bars, the
#     zero baseline, and the y-axis. Title and source live in Quarto.
#
# Story for Silvretta alone:
#   - 21 straight negative years, 2005-2025. 2004 (+0.225 m w.e.) was
#     the last positive year on record.
#   - Era means: 1915-1989 -0.13 m/yr; 1990-2021 -0.76 m/yr; 2022-2025
#     -2.39 m/yr. The recent four-year average is ~19x the pre-1990
#     baseline.
#   - Worst year: 2022 at -3.34 m w.e.
#
# Source: GLAMOS (2025). Swiss Glacier Mass Balance, release 2025,
#   Glacier Monitoring Switzerland, doi:10.18750/massbalance.2025.r2025.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
})

source("design_system.R")

chart_family <- ""

mb_cols <- c(
  "glacier", "glacier_id",
  "date_start", "date_end_winter", "date_end",
  "Bw_mm_we", "Bs_mm_we", "Ba_mm_we",
  "ELA", "AAR", "area_km2", "h_min", "h_max", "observer"
)

raw <- read_csv(
  "data/task_04/massbalance_fixdate.csv",
  skip = 9,
  col_names = mb_cols,
  show_col_types = FALSE,
  na = c("", "NA")
)

silvretta <- raw %>%
  filter(glacier == "Silvrettagletscher") %>%
  mutate(
    hydro_year = as.integer(format(as.Date(date_end), "%Y")),
    Ba_m_we    = as.numeric(Ba_mm_we) / 1000
  ) %>%
  filter(!is.na(Ba_m_we)) %>%
  arrange(hydro_year)

# Minimum visible bar height — five years have near-zero mass balance
# (1917, 1939, 1951, 1962, 2000; |Ba| < 0.05 m w.e.) that would render
# as invisible gaps. Render at minimum visible height (preserving sign)
# so every year produces a visible bar. Disclosed in the Quarto caption.
min_visible <- 0.05
silvretta <- silvretta %>%
  mutate(
    Ba_plot = case_when(
      abs(Ba_m_we) >= min_visible ~ Ba_m_we,
      Ba_m_we >= 0                ~  min_visible,
      TRUE                        ~ -min_visible
    )
  )

p <- ggplot(silvretta, aes(x = hydro_year, y = Ba_plot)) +
  geom_col(width = 0.78, fill = pg_palette$alloy) +
  geom_hline(yintercept = 0, color = pg_palette$onyx, linewidth = 0.9) +
  scale_x_continuous(
    breaks = seq(1920, 2020, 10),
    expand = expansion(mult = c(0.01, 0.02))
  ) +
  scale_y_continuous(
    breaks = seq(-3, 1, 1),
    limits = c(-3.5, 1.4),
    expand = expansion(mult = c(0.02, 0.02))
  ) +
  labs(
    x = NULL,
    y = "Annual mass balance (m water equivalent)"
  ) +
  theme_pg(base_family = chart_family)

out_pdf <- "iterations/task_04/v6/glacier_mass_balance_v6.pdf"
ggsave(out_pdf, p, width = 26, height = 13, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
