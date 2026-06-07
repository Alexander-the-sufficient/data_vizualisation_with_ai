# Task 11 v2 — Median age by country, 2023 (UN WPP 2024 / OWID).
#
# v2 vs v1:
#   * Legend rebuilt. v1 placed the colorbar inside the plot at
#     c(0.02, 0.18) with `barwidth = 70mm`, which overflowed the panel
#     and collapsed the tick labels into a stack. v2 moves the legend
#     to the bottom of the plot, gives it `legend.direction = "horizontal"`
#     and the ticks render cleanly across a 90 mm bar.
#   * Niger callout repositioned. v1's segment crossed through Algeria
#     and Mali (visually misleading — looked like the label was pointing
#     at Algeria, not Niger). v2 routes the segment south-east into the
#     Gulf of Guinea so the label sits over open water.
#   * Subtle border tightening. v1 used 0.15pt white country borders
#     against the alloy fill; v2 keeps them but bumps to 0.2pt for
#     better separation on small European states (which are key to the
#     old-end-of-the-spectrum story).
#   * Antarctica filtering already in place in v1; kept.
#
# Story: Africa under 20, North America and Europe over 38, Japan and
# Italy over 45. The world's median age splits along the demographic
# transition.
#
# Data: OWID grapher "median-age" CSV — variant: estimates 1950-2023.
# Underlying source = UN World Population Prospects 2024.
# Median age is a per-person statistic — choropleth-normalisation rule
# (no raw counts) is satisfied by construction.
#
# Projection: Eckert IV (equal-area pseudo-cylindrical). CLAUDE.md
# requires equal-area for any choropleth where the visual "amount of
# country" is the encoding channel. Mercator inflates Russia / Canada /
# Greenland and would distort the older-skewing northern hemisphere.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(sf)
  library(rnaturalearth)
  library(rnaturalearthdata)
})

source("design_system.R")
chart_family <- ""

# ---- Load median age (OWID -> WPP 2024) -------------------------------
raw <- read_csv("data/task_11/median_age_full.csv", show_col_types = FALSE)

year_pick <- 2023
ma <- raw %>%
  filter(year == year_pick, !is.na(code), nchar(code) == 3) %>%
  transmute(iso_a3 = code,
            entity,
            median_age = median_age__sex_all__age_all__variant_estimates) %>%
  filter(!is.na(median_age))

# ---- Country shapes ---------------------------------------------------
world <- ne_countries(scale = "medium", returnclass = "sf") %>%
  filter(name != "Antarctica")

# ne_countries assigns iso_a3 = "-99" to a handful of sovereigns; patch
# from adm0_a3 fallback.
world <- world %>%
  mutate(iso3 = case_when(
    iso_a3 != "-99"  ~ iso_a3,
    adm0_a3 == "FRA" ~ "FRA",
    adm0_a3 == "NOR" ~ "NOR",
    adm0_a3 == "KOS" ~ "XKX",
    adm0_a3 == "SOL" ~ "SOM",
    TRUE             ~ adm0_a3
  ))

map_data <- world %>%
  left_join(ma, by = c("iso3" = "iso_a3"))

# ---- Project to Eckert IV (equal-area) --------------------------------
eck4 <- "+proj=eck4 +lon_0=0 +datum=WGS84 +units=m +no_defs"
map_proj <- st_transform(map_data, crs = eck4)

# ---- Annotation anchors: extremes -------------------------------------
ann_iso <- c("NER", "JPN")
anchors <- ma %>%
  filter(iso_a3 %in% ann_iso) %>%
  mutate(label = sprintf("%s\n%.1f yrs", entity, median_age))

ann_geom <- world %>%
  filter(iso3 %in% ann_iso) %>%
  st_transform(eck4) %>%
  mutate(centroid = st_centroid(geometry)) %>%
  st_drop_geometry() %>%
  select(iso3, centroid) %>%
  mutate(x = sapply(centroid, function(g) g[1]),
         y = sapply(centroid, function(g) g[2])) %>%
  select(-centroid)

# Hand-tuned offsets (in projected metres).
nudges <- tibble(
  iso3    = c("NER",   "JPN"),
  nudge_x = c(-0.5e6,  3.0e6),
  nudge_y = c(-3.4e6,  1.6e6),
  hjust   = c(1,        0)
)

ann <- anchors %>%
  inner_join(ann_geom, by = c("iso_a3" = "iso3")) %>%
  inner_join(nudges,   by = c("iso_a3" = "iso3"))

# ---- Plot -------------------------------------------------------------
pal_seq <- pg_seq_palette  # 6 stops: light_quartz cream → alloy charcoal

p <- ggplot(map_proj) +
  geom_sf(aes(fill = median_age),
          color = "white", linewidth = 0.20) +
  scale_fill_gradientn(
    colours  = pal_seq,
    breaks   = c(20, 25, 30, 35, 40, 45),
    limits   = c(15, 50),
    na.value = pg_palette$grey,
    name     = "Median age (years)",
    guide    = guide_colorbar(
      title.position = "top", title.hjust = 0,
      barwidth  = unit(90, "mm"),
      barheight = unit(2.6, "mm"),
      ticks.colour = pg_palette$alloy,
      frame.colour = NA
    )
  ) +
  geom_segment(data = ann,
               aes(x = x, y = y,
                   xend = x + nudge_x, yend = y + nudge_y),
               color = pg_palette$dark_stone, linewidth = 0.25) +
  geom_text(data = ann,
            aes(x = x + nudge_x, y = y + nudge_y, label = label,
                hjust = hjust),
            family = chart_family, size = 3.0,
            color = pg_palette$alloy,
            lineheight = 0.95,
            vjust = 0.5) +
  coord_sf(crs = eck4,
           xlim = c(-1.55e7, 1.65e7),
           ylim = c(-6.5e6,  9.0e6),
           expand = FALSE) +
  labs(x = NULL, y = NULL) +
  theme_pg(base_size = 11, base_family = chart_family) +
  theme(
    panel.grid.major     = element_blank(),
    panel.grid.minor     = element_blank(),
    axis.text            = element_blank(),
    axis.line.x          = element_blank(),
    axis.title           = element_blank(),
    legend.position      = "bottom",
    legend.direction     = "horizontal",
    legend.title         = element_text(size = 10, color = pg_palette$alloy,
                                        margin = margin(b = 4)),
    legend.text          = element_text(size = 9,  color = pg_palette$alloy),
    legend.background    = element_rect(fill = "white", color = NA),
    legend.box.margin    = margin(t = -2, b = 2),
    plot.margin          = margin(t = 4, r = 6, b = 4, l = 6)
  )

out_pdf <- "iterations/task_11/v2/median_age_v2.pdf"
ggsave(out_pdf, p, width = 28, height = 15.5, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
