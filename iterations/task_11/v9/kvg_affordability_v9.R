# Task 11 v9 — Cantonal KVG affordability with quintile binning, 2026.
#
# v9 vs v8:
#   * Continuous fill → discrete 5-bin quintile classification. v8's
#     continuous lightness ramp washed out the story because most cantons
#     cluster in the 7–11% band; visually 23 of 26 cantons looked similar.
#     v9 puts each canton in one of five quantile bins (~5 cantons per
#     bin) and assigns each bin a distinct PG palette stop. The
#     geographic pattern (light cluster around Zug/Basel, dark belt in
#     alpine and rural west) becomes immediately readable.
#   * Legend redrawn as a discrete swatch with bin breaks in the
#     0.0–0.5–1.0 percentile direction so the reader sees both the
#     ranges and the rank order.
#
# Story unchanged from v8: same federal mandate, ~4× spread in premium
# burden once normalised by income. Story now reads geographically: a
# light "Zug + Basel-Stadt" pocket, a darkening ring, an alpine and
# rural-west belt of heaviest burden.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(readxl)
  library(ggplot2)
  library(sf)
})

source("design_system.R")
chart_family <- ""

# ---- 1. Premiums (same filter as v7/v8) --------------------------------
prem_raw <- read_csv("data/task_11/Praemien_CH.csv",
                     locale = locale(encoding = "UTF-8"),
                     show_col_types = FALSE)

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

prem_per_canton <- ref |>
  group_by(Kanton) |>
  summarise(mean_premium = mean(Prämie), .groups = "drop")

# ---- 2. GDP per capita (BFS, 2022) -------------------------------------
gdp_xlsx <- "data/task_11/je-d-04.02.06.03_bip_kantone.xlsx"
gdp_raw <- read_excel(gdp_xlsx, sheet = 1, col_names = FALSE, skip = 4)

schweiz_row <- which(gdp_raw[[1]] == "Schweiz")[1]
gdp_block <- gdp_raw[seq_len(schweiz_row), ]

gdp <- gdp_block |>
  select(canton_de = `...1`, gdp_per_capita = `...16`) |>
  filter(!is.na(gdp_per_capita), canton_de != "Schweiz") |>
  mutate(gdp_per_capita = as.numeric(gdp_per_capita))

gdp_lookup <- tribble(
  ~canton_de,            ~Kanton,
  "Zürich",               "ZH",
  "Bern",                 "BE",
  "Luzern",               "LU",
  "Uri",                  "UR",
  "Schwyz",               "SZ",
  "Obwalden",             "OW",
  "Nidwalden",            "NW",
  "Glarus",               "GL",
  "Zug",                  "ZG",
  "Freiburg",             "FR",
  "Solothurn",            "SO",
  "Basel-Stadt",          "BS",
  "Basel-Landschaft",     "BL",
  "Schaffhausen",         "SH",
  "Appenzell A. Rh.",     "AR",
  "Appenzell I. Rh.",     "AI",
  "St. Gallen",           "SG",
  "Graubünden",           "GR",
  "Aargau",               "AG",
  "Thurgau",              "TG",
  "Tessin",               "TI",
  "Waadt",                "VD",
  "Wallis",               "VS",
  "Neuenburg",            "NE",
  "Genf",                 "GE",
  "Jura",                 "JU"
)

gdp <- gdp |> inner_join(gdp_lookup, by = "canton_de")
stopifnot(nrow(gdp) == 26)

# ---- 3. Affordability ratio + quintile bins ----------------------------
afford <- prem_per_canton |>
  inner_join(gdp |> select(Kanton, gdp_per_capita), by = "Kanton") |>
  mutate(annual_premium = mean_premium * 12,
         burden_pct     = 100 * annual_premium / gdp_per_capita)

# 5 quantile bins. cut() with quantile breaks; include lowest.
bin_breaks <- quantile(afford$burden_pct,
                       probs = seq(0, 1, length.out = 6),
                       na.rm = TRUE)
# Round labels for the legend.
bin_labels <- sprintf("%.1f – %.1f%%",
                      head(bin_breaks, -1), tail(bin_breaks, -1))

afford <- afford |>
  mutate(bin = cut(burden_pct, breaks = bin_breaks,
                   labels = bin_labels, include.lowest = TRUE,
                   ordered_result = TRUE))

cat("Quintile bins (boundary values):\n")
print(round(bin_breaks, 2))
cat("\nCanton assignments:\n")
print(afford |> select(Kanton, burden_pct, bin) |>
        arrange(burden_pct), n = 26)

ratio <- max(afford$burden_pct) / min(afford$burden_pct)

# ---- 4. Geometry -------------------------------------------------------
canton_lookup <- tribble(
  ~NAME,                       ~Kanton, ~label,
  "Zürich", "ZH", "Zürich",        "Bern", "BE", "Bern",
  "Luzern", "LU", "Luzern",        "Uri", "UR", "Uri",
  "Schwyz", "SZ", "Schwyz",        "Obwalden", "OW", "Obwalden",
  "Nidwalden", "NW", "Nidwalden",  "Glarus", "GL", "Glarus",
  "Zug", "ZG", "Zug",              "Fribourg", "FR", "Fribourg",
  "Solothurn", "SO", "Solothurn",  "Basel-Stadt", "BS", "Basel-Stadt",
  "Basel-Landschaft", "BL", "Basel-Land",
  "Schaffhausen", "SH", "Schaffhausen",
  "Appenzell Ausserrhoden", "AR", "Appenzell A.",
  "Appenzell Innerrhoden", "AI", "Appenzell I.",
  "St. Gallen", "SG", "St. Gallen",
  "Graubünden", "GR", "Graubünden",
  "Aargau", "AG", "Aargau",        "Thurgau", "TG", "Thurgau",
  "Ticino", "TI", "Ticino",        "Vaud", "VD", "Vaud",
  "Valais", "VS", "Valais",        "Neuchâtel", "NE", "Neuchâtel",
  "Genève", "GE", "Genève",        "Jura", "JU", "Jura"
)

ch_raw <- read_sf("data/task_11/ch-cantons.geojson")

ch <- ch_raw |>
  group_by(NAME) |>
  summarise(.groups = "drop") |>
  st_transform(2056) |>
  left_join(canton_lookup, by = "NAME") |>
  left_join(afford,        by = "Kanton")

stopifnot(nrow(ch) == 26, !any(is.na(ch$bin)))

# ---- 5. Annotation anchors --------------------------------------------
ann_iso <- c("ZG", "VS")

ann_centroids <- ch |>
  filter(Kanton %in% ann_iso) |>
  mutate(centroid = st_centroid(geometry))

cc <- st_coordinates(ann_centroids$centroid)
ann <- ann_centroids |>
  st_drop_geometry() |>
  mutate(x = cc[, 1], y = cc[, 2]) |>
  select(Kanton, label, burden_pct, x, y)

nudges <- tribble(
  ~Kanton, ~nudge_x, ~nudge_y,
  "VS",    0,        -85e3,
  "ZG",    90e3,      50e3
)

ann <- ann |>
  inner_join(nudges, by = "Kanton") |>
  mutate(text = sprintf("%s · %.1f%%", label, burden_pct))

# ---- 6. Plot ----------------------------------------------------------
# Discrete 5-bin palette. Drop light_quartz (too close to white) and
# medium_stone (too close to dark_stone) — keep 5 distinct stops.
bin_pal <- c(
  pg_palette$quartz,        # bin 1 (lowest burden)
  pg_palette$medium_quartz, # bin 2
  pg_palette$dark_quartz,   # bin 3
  pg_palette$dark_stone,    # bin 4
  pg_palette$alloy          # bin 5 (highest burden)
)

ch_bbox <- st_bbox(ch)
xlim <- c(ch_bbox$xmin - 90e3, ch_bbox$xmax + 90e3)
ylim <- c(ch_bbox$ymin - 100e3, ch_bbox$ymax + 75e3)

p <- ggplot(ch) +
  geom_sf(aes(fill = bin),
          color = "white", linewidth = 0.30) +
  scale_fill_manual(
    values = bin_pal,
    name   = "Annual adult premium as % of cantonal GDP per capita (quintile bins)",
    drop   = FALSE,
    guide  = guide_legend(
      title.position = "top", title.hjust = 0,
      keyheight = unit(2.6, "mm"),
      keywidth  = unit(20, "mm"),
      nrow = 1,
      label.position = "bottom",
      override.aes = list(color = NA)
    )
  ) +
  geom_segment(data = ann,
               aes(x = x, y = y,
                   xend = x + nudge_x, yend = y + nudge_y),
               color = pg_palette$dark_stone, linewidth = 0.30,
               inherit.aes = FALSE) +
  geom_label(data = ann,
             aes(x = x + nudge_x, y = y + nudge_y, label = text),
             family = chart_family, size = 3.0,
             color = pg_palette$alloy,
             fill = "white", label.size = 0,
             label.padding = unit(c(1, 2.5, 1, 2.5), "pt"),
             inherit.aes = FALSE) +
  annotate("text",
           x = xlim[1] + 5e3, y = ylim[2] - 8e3,
           label = sprintf("%.1fx burden", ratio),
           hjust = 0, vjust = 1,
           family = chart_family, size = 7.5,
           color = pg_palette$heritage_red,
           fontface = "bold") +
  annotate("text",
           x = xlim[1] + 5e3, y = ylim[2] - 30e3,
           label = "Valais vs. Zug, premium as share of cantonal GDP per capita.",
           hjust = 0, vjust = 1,
           family = chart_family, size = 3.2,
           color = pg_palette$alloy) +
  coord_sf(crs = 2056, datum = NA, expand = FALSE,
           xlim = xlim, ylim = ylim, clip = "off") +
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

out_pdf <- "iterations/task_11/v9/kvg_affordability_v9.pdf"
ggsave(out_pdf, p, width = 28, height = 15.5, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
