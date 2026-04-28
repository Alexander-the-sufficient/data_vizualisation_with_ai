# Task 6 v4 — National electricity mixes, 2000-2025 (color is the aesthetic).
# v4 changes vs v3: softened coal from Onyx (#000000 pure black) to Alloy
#   (#5C5B59 warm charcoal). With Coal = Onyx, the Poland / China / India
#   panels rendered as walls of pure black across most of their vertical
#   range — visually overwhelming and breaking the design system's
#   "black should be an accent, not a main color type" rule even though
#   "coal IS black" was semantically defensible. v4 keeps coal as the
#   darkest fill in the stack but uses a warm charcoal that sits in the
#   brand's neutral ramp rather than at its extreme. No pure black
#   appears anywhere in the chart fills.
#
#   v4 mapping — bottom of stack (dirtiest) to top (cleanest):
#     Coal           Alloy        #5C5B59  warm charcoal (was: Onyx)
#     Gas & oil      Dark Stone   #7E8182  warm gray (was: Alloy)
#     Nuclear        Dark Quartz  #ACA39A  taupe (was: Dark Stone)
#     Hydro & bio    Quartz       #D6D0C2  warm sand (was: Dark Quartz)
#     Wind & solar   Copper       #896C4C  warm bronze, the only accent
#
#   Lightness sequence (Lab L*): 38 -> 53 -> 68 -> 80 -> 47. Mostly
#   monotonic dark->light from bottom to top, with copper interrupting
#   at L=47 - the deliberate "warm hue interruption" that makes wind &
#   solar read as the chart's story signal rather than just another
#   neutral.
#
# v3 changes vs v2: complete fuel-to-color remapping under the new "red
#   and black are accents only" colour discipline. v2's "Nuclear =
#   heritage_red" was the worst offender - France's nuclear-heavy panel
#   rendered as a giant block of red, exactly the "thick red graph"
#   pattern we are now disallowing.
#
# v2 changes vs v1: y-axis title added ("Share of generation, %") so the
#   panels read independently of the subtitle.
# 100%-stacked area, small multiples: 10 countries x 5 fuel categories.
# Color does the encoding work that no other channel can: tracking each
# fuel's share through 26 years across 10 panels relies entirely on
# consistent hue mapping. Stack normalised to 100% so layer thickness is
# directly comparable across countries (no shifting baselines).
#
# Source: Ember (2025). Yearly Electricity Data.
#   https://ember-energy.org/data/yearly-electricity-data/

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
})

source("design_system.R")

# Font fallback — XQuartz / cairo not installed locally, so PDF-native
# Helvetica is used. Switch to Inter via showtext + cairo_pdf when set up.
chart_family <- ""

raw <- read_csv(
  "data/task_06/yearly_full_release_long_format.csv",
  show_col_types = FALSE,
  col_select = c("Area", "Year", "Category", "Subcategory",
                 "Variable", "Unit", "Value")
)

countries <- c("United Kingdom", "Germany", "Denmark", "France", "Sweden",
               "United States of America", "Australia", "Poland", "China", "India")

# Aggregate Ember's 9 fuels into 5 narrative categories. Five-category cap
# matches the qualitative palette contract in design_system.md.
fuel_to_cat <- c(
  "Coal"             = "Coal",
  "Gas"              = "Gas & oil",
  "Other Fossil"     = "Gas & oil",
  "Nuclear"          = "Nuclear",
  "Hydro"            = "Hydro & bio",
  "Bioenergy"        = "Hydro & bio",
  "Other Renewables" = "Hydro & bio",
  "Wind"             = "Wind & solar",
  "Solar"            = "Wind & solar"
)

mix <- raw %>%
  filter(
    Category    == "Electricity generation",
    Subcategory == "Fuel",
    Unit        == "%",
    Area        %in% countries,
    Year        >= 2000, Year <= 2025
  ) %>%
  mutate(category = fuel_to_cat[Variable]) %>%
  group_by(Area, Year, category) %>%
  summarise(share = sum(Value, na.rm = TRUE), .groups = "drop") %>%
  # Renormalise to 100% — guards against Ember's rounded percentages drifting
  # off-total (typical drift <0.1pp).
  group_by(Area, Year) %>%
  mutate(share = share / sum(share) * 100) %>%
  ungroup()

# Sanity check: every panel should sum to 100% in every year.
chk <- mix %>% group_by(Area, Year) %>% summarise(s = sum(share), .groups = "drop")
stopifnot(all(abs(chk$s - 100) < 1e-6))

# Stack order bottom -> top: dirtiest -> cleanest. Coal sits on the
# x-axis baseline (the most accurately-read position), so the shrinking-
# coal story reads at a glance.
cat_levels <- c("Coal", "Gas & oil", "Nuclear", "Hydro & bio", "Wind & solar")

cat_colors <- c(
  "Coal"         = pg_palette$alloy,       # #5C5B59 warm charcoal (darkest)
  "Gas & oil"    = pg_palette$dark_stone,  # #7E8182 warm gray
  "Nuclear"      = pg_palette$dark_quartz, # #ACA39A taupe
  "Hydro & bio"  = pg_palette$quartz,      # #D6D0C2 warm sand
  "Wind & solar" = pg_palette$copper       # #896C4C warm bronze (the accent)
)

# Country order tells the narrative left-to-right, top-to-bottom:
# Row 1 = European transitioners + already-clean baselines.
# Row 2 = slower transitions / coal-dominant systems.
country_order <- c("United Kingdom", "Germany", "Denmark", "France", "Sweden",
                   "United States of America", "Australia", "Poland", "China", "India")

country_label <- c("United Kingdom"             = "United Kingdom",
                   "Germany"                    = "Germany",
                   "Denmark"                    = "Denmark",
                   "France"                     = "France",
                   "Sweden"                     = "Sweden",
                   "United States of America"   = "United States",
                   "Australia"                  = "Australia",
                   "Poland"                     = "Poland",
                   "China"                      = "China",
                   "India"                      = "India")

mix <- mix %>%
  mutate(
    category = factor(category, levels = cat_levels),
    Area     = factor(Area, levels = country_order,
                      labels = country_label[country_order])
  )

# Quick diagnostic to make defensibility traceable in the v1 log.
diag <- mix %>%
  filter(Year %in% c(2000, 2025), category %in% c("Coal", "Wind & solar")) %>%
  arrange(Area, category, Year)
cat("Coal and Wind&solar shares, 2000 vs 2025:\n")
print(diag)

p <- ggplot(mix, aes(x = Year, y = share, fill = category)) +
  geom_area(position = "stack", color = NA) +
  facet_wrap(~ Area, ncol = 5) +
  scale_x_continuous(
    breaks = c(2000, 2010, 2020),
    expand = expansion(mult = c(0, 0))
  ) +
  scale_y_continuous(
    breaks = c(0, 50, 100),
    labels = c("0", "50", "100%"),
    expand = expansion(mult = c(0, 0))
  ) +
  scale_fill_manual(values = cat_colors, breaks = cat_levels, name = NULL) +
  labs(x = NULL, y = "Share of generation (%)") +
  theme_pg(base_family = chart_family) +
  theme(
    legend.position    = "bottom",
    legend.key.height  = grid::unit(8,  "pt"),
    legend.key.width   = grid::unit(18, "pt"),
    legend.text        = element_text(size = 10, color = pg_palette$alloy),
    legend.box.margin  = margin(t = 6, b = 0),
    legend.margin      = margin(t = 0, b = 0),
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.spacing.x    = grid::unit(10, "pt"),
    panel.spacing.y    = grid::unit(14, "pt"),
    strip.text         = element_text(size = 10, color = pg_palette$onyx,
                                      face = "bold", hjust = 0,
                                      margin = margin(b = 4)),
    axis.text.x        = element_text(size = 8),
    axis.text.y        = element_text(size = 8),
    axis.line.x        = element_line(color = pg_palette$alloy, linewidth = 0.3),
    plot.margin        = margin(t = 4, r = 6, b = 4, l = 4)
  )

out_pdf <- "iterations/task_06/v4/energy_mix_v4.pdf"
ggsave(out_pdf, p, width = 28, height = 14, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
