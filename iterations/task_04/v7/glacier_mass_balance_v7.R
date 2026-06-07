# Task 4 v7 — Silvrettagletscher annual mass balance, 1915-2025.
# v7 changes vs v6:
#   - REMOVED the minimum-visible-bar hack. v6 used a case_when that
#     floored every year with |Ba| < 0.05 m w.e. to +/-0.05, which
#     distorted magnitude (a lie-factor violation): 1951 (+0.025)
#     rendered at ~2x its true height, and the disclosure only named
#     five years while 1930 (-0.078), 1995 (+0.059) and 1996 (+0.079)
#     sat just above the threshold as near-invisible slivers anyway.
#   - The bars now plot the TRUE Ba values at exact magnitude. Lie
#     factor is back to ~1: every bar height equals its data value.
#   - To honour the data-completeness rule (no perceived gaps) without
#     distorting any magnitude, a thin alloy geom_point marker sits at
#     every year's exact value. Near-zero years (1917, 1930, 1939,
#     1951, 1962, 1995, 1996, 2000) whose bars are too short to read
#     still produce a visible dot exactly on the zero line, so the
#     series reads as 111 continuous observations, not a record with
#     missing years. The zero baseline is also kept heavy (onyx,
#     linewidth 0.9) so near-zero values visually rest on a continuous
#     line rather than appearing as gaps.
#
# Story for Silvretta alone (unchanged from v6):
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

# No flooring. Bars carry the exact data value (Ba_m_we). A thin alloy
# point marker at every year's value guarantees that even years whose
# bar is sub-pixel produce a visible mark — preserving magnitudes while
# eliminating any perceived gap in the 111-year record.
p <- ggplot(silvretta, aes(x = hydro_year, y = Ba_m_we)) +
  geom_col(width = 0.78, fill = pg_palette$alloy) +
  geom_point(color = pg_palette$alloy, size = 0.55) +
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

out_pdf <- "iterations/task_04/v7/glacier_mass_balance_v7.pdf"
ggsave(out_pdf, p, width = 26, height = 13, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
