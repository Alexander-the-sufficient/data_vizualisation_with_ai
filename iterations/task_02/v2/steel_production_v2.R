# Task 2 v2 — honest remake of the White House steel chart, long context.
# v2 changes vs v1: extended window from 5 yrs (2021-2025) to 56 yrs
#   (1970-2025) by splicing USGS DS140 historical raw-steel-production data
#   onto the existing worldsteel 2021-2025 series. The 5-year window made
#   the same cherry-pick mistake we critiqued in task 1; the long view
#   shows the 1973 peak, the post-1970s structural decline, the GFC
#   trough, and that the 2024 -> 2025 increase is well within ambient noise.
# Chart-type choice: line chart (per CLAUDE.md "line for time series").
#   Zero baseline is kept (not required for line, but more honest about scale
#   and matches the bar-chart convention of the original).
#
# Sources spliced:
#   * USGS DS140 (Iron and Steel Statistics, 1900-2021), Steel sheet,
#     "Raw steel production" column. Used 1900-2020 portion.
#   * World Steel Association, P1 crude steel total, USA, 2021-2025.
#     Used 2021-2025 portion.
# Both report 2021 = 85.8 Mt (sanity check passes).

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

source("design_system.R")

chart_family <- ""

# --- 1. Historical: USGS DS140, 1900-2021 ----------------------------------
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
cat("Peak:  "); us %>% slice_max(mt, n = 1) %>% print()
cat("Trough (post-1970): "); us %>% slice_min(mt, n = 1) %>% print()
cat("Recent (2021-2025):\n"); us %>% filter(year >= 2021) %>% print()

# Highlight: the two years the original White House chart used (2024, 2025).
us <- us %>% mutate(highlight = year %in% c(2024, 2025))

# Anchor labels for the four points the reader should see.
ann <- us %>%
  filter(year %in% c(1973, 2009, 2021, 2025)) %>%
  mutate(
    label = sprintf("%.0f Mt\n%d", mt, year),
    vjust = case_when(year == 1973 ~ -0.7,
                       year == 2009 ~  1.6,
                       year == 2021 ~ -0.7,
                       year == 2025 ~ -0.7),
    hjust = case_when(year == 1973 ~ 0.2,
                       year == 2009 ~ 0.5,
                       year == 2021 ~ 0.5,
                       year == 2025 ~ 1.0)
  )

p <- ggplot(us, aes(x = year, y = mt)) +
  geom_line(color = pg_palette$alloy, linewidth = 0.55) +
  geom_point(data = us %>% filter(!highlight),
             color = pg_palette$alloy, size = 0.9) +
  geom_point(data = us %>% filter(highlight),
             color = pg_palette$copper, size = 2.2) +
  geom_text(data = ann, aes(label = label, vjust = vjust, hjust = hjust),
            family = chart_family, size = 3.0, color = pg_palette$onyx,
            lineheight = 0.9) +
  scale_x_continuous(breaks = seq(1970, 2025, 10),
                     expand = expansion(mult = c(0.02, 0.04))) +
  scale_y_continuous(limits = c(0, 150),
                     breaks = seq(0, 150, 25),
                     expand = expansion(mult = c(0, 0.04))) +
  labs(x = NULL, y = "Million metric tons (Mt)") +
  theme_pg(base_family = chart_family)

out_pdf <- "iterations/task_02/v2/steel_production_v2.pdf"
ggsave(out_pdf, p, width = 26, height = 12, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
