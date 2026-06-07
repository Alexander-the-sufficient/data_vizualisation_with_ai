# Task 11 v3 — Mean adult standard health-insurance premium by canton, 2026.
#
# Pivot from the v1/v2 world median-age choropleth: the portfolio's economic
# story leans Swiss, so a Swiss-only data map fits better. The 2026 KVG
# premium tariffs were published 26 Sep 2025 (BAG); the spread between the
# cheapest canton (Zug) and the most expensive (Geneva) is roughly 1.76× for
# the same federally-mandated standard reference policy — a textbook
# choropleth story.
#
# Data: BAG / opendata.swiss `health-insurance-premiums` dataset, file
# `Praemien_CH.csv` (downloaded into data/task_11/). Filtered to the
# *standard reference policy*: adults (AKL-ERW), with-accident coverage
# (MIT-UNF), ordinary tariff (TAR-BASE, no HMO / family-doctor model),
# 300 CHF deductible (FRA-300, the default). Per-canton mean across all
# insurer offerings — *unweighted* by enrollment, since the BAG file does
# not expose per-insurer enrollment counts. Disclosed in the chart caption.
#
# Geometry: severinlandolt/map-switzerland CH_Kantonsgrenzen_050 (50%
# generalised swisstopo cantons, WGS84 lon/lat). 51 features dissolved to
# the 26 cantons via NAME. Reprojected to CH1903+ / LV95 (EPSG:2056) — the
# Swiss equal-area national grid; correct projection for area-faithful
# choropleth on Swiss territory.
#
# Palette: pg_seq_palette (cream → warm charcoal). Single magnitude
# variable, no danger semantics, grayscale-safe by construction.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(sf)
  library(scales)
  library(stringr)
})

source("design_system.R")
chart_family <- ""

# ---- 1. Premium data ---------------------------------------------------
prem_raw <- read_csv("data/task_11/Praemien_CH.csv",
                     locale = locale(encoding = "UTF-8"),
                     show_col_types = FALSE)

# Real cantons only — exclude ZE (residents in EU/EFTA) and ZR (rest of world).
real_cantons <- c("AG","AI","AR","BE","BL","BS","FR","GE","GL","GR","JU",
                  "LU","NE","NW","OW","SG","SH","SO","SZ","TG","TI",
                  "UR","VD","VS","ZG","ZH")

ref <- prem_raw |>
  filter(
    Geschäftsjahr     == 2026,
    Altersklasse      == "AKL-ERW",
    Unfalleinschluss  == "MIT-UNF",
    Tariftyp          == "TAR-BASE",
    Franchise         == "FRA-300",
    Kanton %in% real_cantons
  )

per_canton <- ref |>
  group_by(Kanton) |>
  summarise(mean_premium = mean(Prämie),
            n_offerings  = n(),
            .groups      = "drop")

cat("Per-canton mean adult standard premium 2026 (CHF/month):\n")
print(per_canton |> arrange(mean_premium))

# ---- 2. Canton geometry -----------------------------------------------
# 50% generalised swisstopo cantons. 51 polygon features split by KT_TEIL
# (lake-bisected pieces, Konstanz Bodensee chunks, etc.) — dissolve to 26.
ch_raw <- read_sf("data/task_11/ch-cantons.geojson")

ch_dissolved <- ch_raw |>
  group_by(NAME) |>
  summarise(.groups = "drop") |>
  st_transform(2056)  # CH1903+ / LV95 — Swiss equal-area national grid.

canton_lookup <- tribble(
  ~NAME,                       ~Kanton, ~label,
  "Zürich",                    "ZH",    "Zürich",
  "Bern",                      "BE",    "Bern",
  "Luzern",                    "LU",    "Luzern",
  "Uri",                       "UR",    "Uri",
  "Schwyz",                    "SZ",    "Schwyz",
  "Obwalden",                  "OW",    "Obwalden",
  "Nidwalden",                 "NW",    "Nidwalden",
  "Glarus",                    "GL",    "Glarus",
  "Zug",                       "ZG",    "Zug",
  "Fribourg",                  "FR",    "Fribourg",
  "Solothurn",                 "SO",    "Solothurn",
  "Basel-Stadt",               "BS",    "Basel-Stadt",
  "Basel-Landschaft",          "BL",    "Basel-Land",
  "Schaffhausen",              "SH",    "Schaffhausen",
  "Appenzell Ausserrhoden",    "AR",    "Appenzell A.",
  "Appenzell Innerrhoden",     "AI",    "Appenzell I.",
  "St. Gallen",                "SG",    "St. Gallen",
  "Graubünden",                "GR",    "Graubünden",
  "Aargau",                    "AG",    "Aargau",
  "Thurgau",                   "TG",    "Thurgau",
  "Ticino",                    "TI",    "Ticino",
  "Vaud",                      "VD",    "Vaud",
  "Valais",                    "VS",    "Valais",
  "Neuchâtel",                 "NE",    "Neuchâtel",
  "Genève",                    "GE",    "Genève",
  "Jura",                      "JU",    "Jura"
)

ch <- ch_dissolved |>
  left_join(canton_lookup, by = "NAME") |>
  left_join(per_canton,    by = "Kanton")

stopifnot(nrow(ch) == 26, !any(is.na(ch$mean_premium)))

# ---- 3. Annotation anchors --------------------------------------------
# Two extreme anchors — Zug (lowest) and Genève (highest). Centroids in
# LV95 metres, with hand-tuned offsets (in metres) to route segments away
# from neighbouring cantons.
anchors_iso <- c("ZG", "GE")

ann <- ch |>
  filter(Kanton %in% anchors_iso) |>
  mutate(centroid = st_centroid(geometry)) |>
  st_drop_geometry() |>
  select(Kanton, label, mean_premium, centroid) |>
  mutate(x = sapply(centroid, function(g) g[1]),
         y = sapply(centroid, function(g) g[2])) |>
  select(-centroid)

nudges <- tibble(
  Kanton  = c("ZG",     "GE"),
  nudge_x = c( 1.6e5,  -1.4e5),
  nudge_y = c( 1.2e5,  -1.0e5),
  hjust   = c( 0,        1)
)

ann <- ann |>
  left_join(nudges, by = "Kanton") |>
  mutate(text = sprintf("%s\nCHF %.0f / month", label, mean_premium))

# ---- 4. Plot ----------------------------------------------------------
p <- ggplot(ch) +
  geom_sf(aes(fill = mean_premium),
          color = "white", linewidth = 0.30) +
  scale_fill_gradientn(
    colours = pg_seq_palette,
    breaks  = c(450, 525, 600, 675, 750),
    limits  = c(425, 775),
    labels  = function(x) sprintf("CHF %d", x),
    name    = "Mean adult standard premium per month (2026, CHF)",
    guide   = guide_colorbar(
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
               color = pg_palette$dark_stone, linewidth = 0.30) +
  geom_text(data = ann,
            aes(x = x + nudge_x, y = y + nudge_y,
                label = text, hjust = hjust),
            family = chart_family, size = 3.0,
            color = pg_palette$alloy,
            lineheight = 0.95, vjust = 0.5) +
  coord_sf(crs = 2056, datum = NA, expand = FALSE) +
  labs(x = NULL, y = NULL) +
  theme_pg(base_size = 11, base_family = chart_family) +
  theme(
    panel.grid       = element_blank(),
    axis.text        = element_blank(),
    axis.line.x      = element_blank(),
    axis.title       = element_blank(),
    legend.position  = "bottom",
    legend.direction = "horizontal",
    legend.title     = element_text(size = 10, color = pg_palette$alloy,
                                    margin = margin(b = 4)),
    legend.text      = element_text(size = 9,  color = pg_palette$alloy),
    legend.background = element_rect(fill = "white", color = NA),
    legend.box.margin = margin(t = -2, b = 2),
    plot.margin       = margin(t = 4, r = 6, b = 4, l = 6)
  )

out_pdf <- "iterations/task_11/v3/kvg_premium_v3.pdf"
ggsave(out_pdf, p, width = 28, height = 15.5, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
