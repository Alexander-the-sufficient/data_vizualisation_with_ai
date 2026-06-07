# Task 11 v8 — Cantonal KVG affordability: annual adult standard premium
# as a % of cantonal GDP per capita, 2026 premium / 2022 GDP.
#
# v8 vs v7:
#   * Metric pivot. v7 mapped raw premium level (CHF 436–764 spread). v8
#     normalises by ability to pay: annual premium ÷ cantonal GDP per
#     capita. The headline shifts. Geneva (highest premium) drops to
#     mid-pack because its GDP per capita is also high; the heaviest
#     affordability burden lands on Wallis, Jura, Freiburg, Aargau, Uri
#     — premium isn't extreme but income is. The lightest burden is
#     still Zug, and the gap widens from 1.76× (premium) to ≈4× (share
#     of GDP per capita).
#   * Honest caveat. GDP per capita is not disposable household income.
#     In Zug and Basel-Stadt it is materially inflated by booked
#     corporate profits (Zug = CHF 193k, Basel-Stadt = CHF 210k), which
#     means actual residents in those cantons feel a heavier squeeze
#     than this ratio implies. A purer measure would be cantonal mean
#     taxable income per natural person from the ESTV statistics, but
#     that is not openly published per canton in CSV. GDP per capita is
#     the standard cantonal income proxy in Swiss regional analysis and
#     is acknowledged in the caption.
#   * Sequential ramp now starts from a slightly darker quartz so the
#     low end (Zug at ~2.7%) is clearly distinguishable on the page.
#
# Story: same federal mandate, ~4× spread in premium burden once you
# normalise by income. "Premium expensiveness" doesn't tell you who is
# squeezed — affordability does.
#
# Data:
#   * Premiums: BAG opendata.swiss `Praemien_CH.csv`, 2026 tariff year,
#     standard reference policy (adult, with-accident, ordinary tariff,
#     300 CHF deductible). Same filter as v7. Annualised (× 12).
#   * GDP per capita: BFS `je-d-04.02.06.03_bip_kantone.xlsx`, 2022
#     (latest column in the published series). Source: BFS asset 32627389.
#
# Geometry: same as v7 (severinlandolt/map-switzerland 50% generalised
# swisstopo cantons, dissolved to 26 features, projected to LV95).

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

# ---- 1. Premiums (same filter as v7) -----------------------------------
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

# The first block (rows 1..26 here) is CHF amounts per canton + Schweiz.
# Subsequent blocks are growth rates and shares — drop them by taking
# only rows up to and including "Schweiz".
schweiz_row <- which(gdp_raw[[1]] == "Schweiz")[1]
gdp_block <- gdp_raw[seq_len(schweiz_row), ]

# Year columns: ...2 = 2008 ... ...16 = 2022.
gdp <- gdp_block |>
  select(canton_de = `...1`, gdp_per_capita = `...16`) |>
  filter(!is.na(gdp_per_capita), canton_de != "Schweiz") |>
  mutate(gdp_per_capita = as.numeric(gdp_per_capita))

# Map BFS German canton names → 2-letter codes used in the BAG file.
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

# ---- 3. Affordability ratio --------------------------------------------
afford <- prem_per_canton |>
  inner_join(gdp |> select(Kanton, gdp_per_capita), by = "Kanton") |>
  mutate(annual_premium = mean_premium * 12,
         burden_pct     = 100 * annual_premium / gdp_per_capita) |>
  arrange(burden_pct)

cat("Affordability burden (annual premium / GDP per capita, %):\n")
print(afford |> select(Kanton, mean_premium, gdp_per_capita, burden_pct), n = 26)

burden_min <- min(afford$burden_pct)
burden_max <- max(afford$burden_pct)
ratio      <- burden_max / burden_min
cat(sprintf("\nRange: %.1f%% to %.1f%%, ratio = %.1fx\n",
            burden_min, burden_max, ratio))

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

stopifnot(nrow(ch) == 26, !any(is.na(ch$burden_pct)))

# ---- 5. Annotation anchors --------------------------------------------
# Zug is the clear outlier at the bottom (2.7%, the next-cheapest is
# Basel-Stadt at 4.1% — a 1.4 pp gap). At the top, seven cantons cluster
# between 10.16% (Aargau) and 10.91% (Fribourg) — the absolute max moves
# from year to year as GDP and premiums shift, so picking it as a single
# anchor is fragile. Wallis (10.85%, essentially tied with Fribourg) is
# the largest, most visually distinctive canton in that cluster — it
# anchors the alpine / rural-west story the dark fill is making.
ann_iso <- c("ZG", "VS")

ann_centroids <- ch |>
  filter(Kanton %in% ann_iso) |>
  mutate(centroid = st_centroid(geometry))

cc <- st_coordinates(ann_centroids$centroid)
ann <- ann_centroids |>
  st_drop_geometry() |>
  mutate(x = cc[, 1], y = cc[, 2]) |>
  select(Kanton, label, burden_pct, x, y)

# Wallis is in the SW alpine ridge, Zug is central-N.
nudges <- tribble(
  ~Kanton, ~nudge_x, ~nudge_y,
  "VS",    0,        -85e3,    # S into Italian border whitespace
  "ZG",    90e3,      50e3     # NE through Schaffhausen direction
)

ann <- ann |>
  inner_join(nudges, by = "Kanton") |>
  mutate(text = sprintf("%s · %.1f%%", label, burden_pct))

# ---- 6. Plot ----------------------------------------------------------
seq_pal <- pg_seq_palette[-1]   # drop light_quartz

ch_bbox <- st_bbox(ch)
xlim <- c(ch_bbox$xmin - 90e3, ch_bbox$xmax + 90e3)
ylim <- c(ch_bbox$ymin - 100e3, ch_bbox$ymax + 75e3)

p <- ggplot(ch) +
  geom_sf(aes(fill = burden_pct),
          color = "white", linewidth = 0.30) +
  scale_fill_gradientn(
    colours = seq_pal,
    breaks  = c(3, 5, 7, 9, 11),
    limits  = c(2.5, 11.5),
    labels  = function(x) sprintf("%.0f%%", x),
    name    = "Annual adult standard premium as % of cantonal GDP per capita",
    guide   = guide_colorbar(
      title.position = "top", title.hjust = 0,
      barwidth  = unit(95, "mm"),
      barheight = unit(2.6, "mm"),
      ticks.colour = pg_palette$alloy,
      frame.colour = NA
    )
  ) +
  geom_segment(data = ann,
               aes(x = x, y = y,
                   xend = x + nudge_x, yend = y + nudge_y),
               color = pg_palette$dark_stone, linewidth = 0.30) +
  geom_label(data = ann,
             aes(x = x + nudge_x, y = y + nudge_y, label = text),
             family = chart_family, size = 3.0,
             color = pg_palette$alloy,
             fill = "white", label.size = 0,
             label.padding = unit(c(1, 2.5, 1, 2.5), "pt")) +
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

out_pdf <- "iterations/task_11/v8/kvg_affordability_v8.pdf"
ggsave(out_pdf, p, width = 28, height = 15.5, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
