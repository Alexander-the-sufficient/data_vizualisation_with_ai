# Task 4 v4 — Swiss glacier annual mass balance, 1956-2025.
# v4 changes vs v3: dropped the red highlight on 2022-2025 entirely.
#   The v3 framing ("In four years, glaciers lost more ice than in the
#   previous thirty-four") was true but selectively framed — it compared
#   the four worst recent years against an arbitrary 34-year slice,
#   ignoring 1990-2021 which was also a long period of loss. Years 2024
#   (-1.10) and 2025 (-1.55) aren't even individually in the five most
#   negative years on record — 2003 (-1.90), 2017 (-1.76), 2011 (-1.59)
#   are comparable. Painting 2022-2025 in red implied they were uniquely
#   catastrophic when they are really the latest in a long acceleration
#   that began in the 1990s.
#   v4 strategy: single-colour bars (alloy), let the data shape carry the
#   story. The new title leads on the unbroken streak (every year since
#   1993 has had negative balance) rather than the cherry-picked aggregate.
# v3 vs v2: palette migration only.
# v2 vs v1: highlight switched from then-sage heritage_red to copper for
#   visibility. v4 removes the highlight entirely.
# Story: every year since 1993 has had a negative mass balance — 32
#   straight years of loss — and the annual loss rate has roughly
#   tenfold-ed compared to the 1956-1989 average.
#
# Aggregation: area-weighted mean of glacier-wide annual mass balance across all
# monitored glaciers each hydrological year. Restricted to 1956+ where >= 10
# glaciers are continuously observed.
#
# Source: GLAMOS (2025). Swiss Glacier Mass Balance, release 2025,
#   Glacier Monitoring Switzerland, doi:10.18750/massbalance.2025.r2025.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(ggplot2)
})

source("design_system.R")

# Same fallback as task_02: cairo + Google Fonts unavailable on this machine,
# fall back to PDF-native sans (Helvetica).
chart_family <- ""

# Header at line 7, units rows at 8-9, data starts at line 10. Skip all header
# rows and assign column names manually.
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

mb <- raw %>%
  mutate(
    hydro_year = as.integer(format(as.Date(date_end), "%Y")),
    Ba_m_we    = as.numeric(Ba_mm_we) / 1000,
    area_km2   = as.numeric(area_km2)
  ) %>%
  filter(!is.na(Ba_m_we), !is.na(area_km2), area_km2 > 0)

# Area-weighted Swiss reference-glacier mean per year
swiss <- mb %>%
  group_by(hydro_year) %>%
  summarise(
    n_glaciers = n(),
    Ba_m_we    = sum(Ba_m_we * area_km2) / sum(area_km2),
    .groups    = "drop"
  ) %>%
  filter(n_glaciers >= 10, hydro_year >= 1956, hydro_year <= 2025) %>%
  arrange(hydro_year)

cat("Swiss-wide aggregate, recent years (sanity check vs GLAMOS published):\n")
swiss %>% filter(hydro_year >= 2020) %>% print()
cat("\n5 most-negative years across the series:\n")
swiss %>% arrange(Ba_m_we) %>% head(5) %>% print()

# v4: single-colour bars. The `highlight` column is retained as a no-op
# so the rest of the script's structure is unchanged, but the fill scale
# below maps both levels to alloy.
swiss <- swiss %>%
  mutate(highlight = hydro_year >= 2022)

# Minimum visible bar height — three years had near-zero mass balance
# (1956: +0.004, 1967: -0.0001, 1993: +0.007 m w.e.) that would render as
# invisible gaps. We render them at the minimum visible height (preserving
# the sign of the original measurement) to guarantee every year produces a
# visible bar. Disclosed in the Quarto caption. This affects 3 of 70 bars.
min_visible <- 0.05
swiss <- swiss %>%
  mutate(
    Ba_plot = case_when(
      abs(Ba_m_we) >= min_visible ~ Ba_m_we,
      Ba_m_we >= 0                ~  min_visible,
      TRUE                        ~ -min_visible
    )
  )

# Bracket the recent vs historical period for a comparison annotation
recent_sum <- sum(swiss %>% filter(hydro_year >= 2022) %>% pull(Ba_m_we))
hist_sum   <- sum(swiss %>% filter(hydro_year <= 1989) %>% pull(Ba_m_we))
cat(sprintf("\nSum 2022-2025 (4 yrs):   %.2f m w.e.\n", recent_sum))
cat(sprintf("Sum 1956-1989 (34 yrs): %.2f m w.e.\n", hist_sum))

# Plot. A thickened zero baseline ensures the three near-zero years
# (1956: +0.004, 1967: -0.0001, 1993: +0.007 m w.e.) visibly sit on a
# continuous line rather than reading as gaps between neighbouring bars.
p <- ggplot(swiss, aes(x = hydro_year, y = Ba_plot, fill = highlight)) +
  geom_col(width = 0.78) +
  geom_hline(yintercept = 0, color = pg_palette$onyx, linewidth = 0.9) +
  scale_fill_manual(
    values = c(`FALSE` = pg_palette$alloy, `TRUE` = pg_palette$alloy),
    guide  = "none"
  ) +
  scale_x_continuous(
    breaks = seq(1960, 2025, 10),
    expand = expansion(mult = c(0.01, 0.02))
  ) +
  scale_y_continuous(
    breaks = seq(-3, 1, 1),
    limits = c(-3.2, 1.2),
    expand = expansion(mult = c(0.02, 0.02))
  ) +
  labs(
    x = NULL,
    y = "Annual mass balance (m water equivalent)"
  ) +
  theme_pg(base_family = chart_family)

out_pdf <- "iterations/task_04/v4/glacier_mass_balance_v4.pdf"
ggsave(out_pdf, p, width = 26, height = 13, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
