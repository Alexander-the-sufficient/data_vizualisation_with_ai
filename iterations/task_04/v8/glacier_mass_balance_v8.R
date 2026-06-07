# Task 4 v8 — Silvrettagletscher annual mass balance, 1915-2025.
# v8 changes vs v7:
#   - REMOVED the geom_point layer entirely. The user disliked the
#     little point markers sitting at the end of every bar.
#   - Bars still plot the TRUE Ba_m_we values at exact magnitude (no
#     flooring, no minimum-bar hack). Lie factor stays ~1: every bar
#     height equals its data value.
#   - Data completeness (no perceived gaps) is now carried entirely by
#     the thick onyx zero baseline (linewidth 0.9). The eight near-zero
#     years (1917, 1930, 1939, 1951, 1962, 1995, 1996, 2000) appear as
#     tiny bars attached to the continuous heavy zero line, so they read
#     as present observations resting on the baseline rather than as
#     gaps in the record. Thick baseline replaces the dots as the
#     completeness device.
#
# Story for Silvretta alone (unchanged from v6/v7):
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

# No flooring, no point markers. Bars carry the exact data value
# (Ba_m_we). The thick onyx zero baseline is the data-completeness
# device: near-zero years render as tiny bars attached to the heavy
# continuous zero line, so the 111-year record reads as complete with
# no perceived gaps and no magnitude distortion.
p <- ggplot(silvretta, aes(x = hydro_year, y = Ba_m_we)) +
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

out_pdf <- "iterations/task_04/v8/glacier_mass_balance_v8.pdf"
ggsave(out_pdf, p, width = 26, height = 13, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
