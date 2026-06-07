# Task 11 v1 — Median age by country, 2023 (UN WPP 2024 / OWID).
#
# Story: the world's median age splits cleanly along the demographic
# transition — Sub-Saharan Africa under 20, North America and most of
# Europe over 38, Japan and the EU's southern tier over 45. The map
# answers "where is the world young, and where is it old?" in one frame.
#
# Data: Our World in Data, "Median age" (variant: estimates 1950-2023,
# medium projection 2024-2100). Underlying source = UN World Population
# Prospects 2024. Median age is already a per-person statistic, so the
# choropleth-normalisation rule (no raw counts) is satisfied by
# construction.
#
# Projection: Eckert IV (equal-area). CLAUDE.md requires equal-area for
# any choropleth where the visual "amount of country" is the encoding
# channel; Mercator inflates high-latitude countries (Russia, Canada,
# Greenland) and would make the older-skewing northern hemisphere look
# even older. Eckert IV pseudo-cylindrical preserves area correctly while
# keeping a familiar global outline.
#
# Palette: pg_seq_palette (light_quartz cream → alloy charcoal). Single
# magnitude variable, sequential ramp, no danger semantics. Antarctica
# excluded (no permanent population, would crowd the south).
#
# Annotation: extremes flagged at the legend, plus a lightweight callout
# on Niger (lowest, 14.9) and Japan (highest, 49.4). Labels are kept off
# the map face and tied with thin segments to avoid covering small states.

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

# Filter to country-level rows in the latest *estimate* year (not projection).
year_pick <- 2023
ma <- raw %>%
  filter(year == year_pick, !is.na(code), nchar(code) == 3) %>%
  transmute(iso_a3 = code,
            entity,
            median_age = median_age__sex_all__age_all__variant_estimates) %>%
  filter(!is.na(median_age))

# Drop OWID region/aggregate codes (anything not a real ISO3 country).
# OWID uses non-ISO codes like "OWID_WRL" for World; nchar==3 above already
# excludes those (5 chars). Sanity-check:
cat("Country rows:", nrow(ma), "\n")
cat("Min / median / max median age:\n")
print(ma %>% summarise(min = min(median_age),
                       med = median(median_age),
                       max = max(median_age)))
cat("\nLowest 5:\n"); print(ma %>% arrange(median_age) %>% head(5))
cat("\nHighest 5:\n"); print(ma %>% arrange(desc(median_age)) %>% head(5))

# ---- Country shapes ---------------------------------------------------
world <- ne_countries(scale = "medium", returnclass = "sf") %>%
  filter(name != "Antarctica")

# Many ne_countries rows have iso_a3 == "-99" (e.g. France, Norway, Kosovo).
# Patch those manually using the adm0_a3 fallback that is correct for the
# affected sovereigns. We only need the few that the OWID dataset covers.
world <- world %>%
  mutate(iso3 = case_when(
    iso_a3 != "-99"  ~ iso_a3,
    adm0_a3 == "FRA" ~ "FRA",
    adm0_a3 == "NOR" ~ "NOR",
    adm0_a3 == "KOS" ~ "XKX",   # OWID code for Kosovo
    adm0_a3 == "SOL" ~ "SOM",   # Somaliland → SOM in OWID
    TRUE             ~ adm0_a3
  ))

map_data <- world %>%
  left_join(ma, by = c("iso3" = "iso_a3"))

cat("\nCountries on map without median_age value:\n")
missing <- map_data %>% filter(is.na(median_age)) %>%
  st_drop_geometry() %>% select(name, iso3)
print(missing)

# ---- Project to Eckert IV (equal-area) --------------------------------
# Use proj string for Eckert IV. World is centred on prime meridian.
eck4 <- "+proj=eck4 +lon_0=0 +datum=WGS84 +units=m +no_defs"
map_proj <- st_transform(map_data, crs = eck4)

# ---- Annotation anchors -----------------------------------------------
anchors <- ma %>%
  filter(entity %in% c("Niger", "Japan")) %>%
  mutate(label = sprintf("%s\n%.1f yrs", entity, median_age))

# Get centroids in Eckert IV for label positions.
ann_geom <- world %>%
  filter(iso3 %in% c("NER", "JPN")) %>%
  st_transform(eck4) %>%
  mutate(centroid = st_centroid(geometry)) %>%
  st_drop_geometry() %>%
  select(iso3, centroid) %>%
  mutate(x = sapply(centroid, function(g) g[1]),
         y = sapply(centroid, function(g) g[2])) %>%
  select(-centroid)

ann <- anchors %>%
  inner_join(ann_geom, by = c("iso_a3" = "iso3")) %>%
  mutate(
    # nudge label off the country, segment line points back to centroid.
    nudge_x = c(NER = -3e6, JPN = 3e6)[iso_a3],
    nudge_y = c(NER = -2.8e6, JPN = 2.0e6)[iso_a3]
  )

# ---- Plot -------------------------------------------------------------
breaks <- c(15, 20, 25, 30, 35, 40, 45, 50)
pal_seq <- pg_seq_palette  # 6 stops: light_quartz → alloy

p <- ggplot(map_proj) +
  geom_sf(aes(fill = median_age),
          color = "white", linewidth = 0.15) +
  scale_fill_gradientn(
    colours = pal_seq,
    breaks  = c(20, 25, 30, 35, 40, 45),
    limits  = c(15, 50),
    na.value = pg_palette$grey,
    name    = "Median age (years)",
    guide   = guide_colorbar(
      title.position = "top", title.hjust = 0,
      barwidth = unit(70, "mm"), barheight = unit(2.4, "mm"),
      ticks.colour = pg_palette$alloy,
      frame.colour = NA
    )
  ) +
  # Annotation segments + labels for the two extremes.
  geom_segment(data = ann,
               aes(x = x, y = y,
                   xend = x + nudge_x, yend = y + nudge_y),
               color = pg_palette$dark_stone, linewidth = 0.25) +
  geom_text(data = ann,
            aes(x = x + nudge_x, y = y + nudge_y, label = label),
            family = chart_family, size = 3.0,
            color = pg_palette$alloy,
            lineheight = 0.95,
            hjust = c(NER = 1, JPN = 0)[ann$iso_a3],
            vjust = 0.5) +
  coord_sf(crs = eck4,
           xlim = c(-1.55e7, 1.65e7),
           ylim = c(-6.5e6,  9.0e6),
           expand = FALSE) +
  labs(x = NULL, y = NULL) +
  theme_pg(base_size = 11, base_family = chart_family) +
  theme(
    panel.grid.major   = element_blank(),
    panel.grid.minor   = element_blank(),
    axis.text          = element_blank(),
    axis.line.x        = element_blank(),
    axis.title         = element_blank(),
    legend.position    = c(0.02, 0.18),
    legend.justification = c(0, 0.5),
    legend.title       = element_text(size = 10, color = pg_palette$alloy),
    legend.text        = element_text(size = 9,  color = pg_palette$alloy),
    legend.background  = element_rect(fill = "white", color = NA),
    plot.margin        = margin(t = 4, r = 6, b = 4, l = 6)
  )

out_pdf <- "iterations/task_11/v1/median_age_v1.pdf"
ggsave(out_pdf, p, width = 28, height = 14.5, units = "cm", device = "pdf")
cat("\nSaved:", out_pdf, "\n")

# Sanity export of the joined country-level data.
write_csv(ma, "iterations/task_11/v1/median_age_2023.csv")
