# Task 11 v4 — Mean adult standard health-insurance premium by canton, 2026.
#
# v4 vs v3:
#   * Annotation nudges. v3 used 1.0–1.6 × 10^5 m (100–160 km) which is huge
#     against Switzerland's ~350 km × 220 km bounding box — both callouts
#     ended up off-page. v4 uses 25–60 km and routes them to clean white
#     space. Coordinates extracted via st_coordinates() (no sapply guessing).
#   * Palette. v3 started the sequential ramp at light_quartz (#ECEAE4), so
#     Zug and Appenzell I. were almost invisible against the white canvas.
#     v4 drops that stop and starts at quartz (#D6D0C2) — the lightest fill
#     is now distinguishable from page background but still clearly the
#     "low" end.
#   * Callouts. v3 annotated only the two extremes. v4 adds the three highest
#     (Genève, Ticino, Basel-Stadt) and the three lowest (Zug, Appenzell I.,
#     Nidwalden) — six callouts that bracket the spread.
#   * Country outline. v4 strokes the dissolved national border in alloy at
#     0.4pt for crispness; canton-internal borders stay white at 0.30pt.
#
# Story unchanged: 76% gap between Zug (cheapest) and Genève (most expensive)
# for the same federally-mandated standard reference policy. 2026 tariffs.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(sf)
})

source("design_system.R")
chart_family <- ""

# ---- 1. Premium data ---------------------------------------------------
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

per_canton <- ref |>
  group_by(Kanton) |>
  summarise(mean_premium = mean(Prämie), .groups = "drop")

# ---- 2. Canton geometry -----------------------------------------------
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
  left_join(per_canton,    by = "Kanton")

stopifnot(nrow(ch) == 26, !any(is.na(ch$mean_premium)))

# National outline = union of cantons
national <- st_union(ch)

# ---- 3. Annotation anchors --------------------------------------------
# Six callouts: top three and bottom three. Nudges in LV95 metres
# (Switzerland is ~350 km × 220 km — keep nudges 25–60 km).
ann_iso <- c("GE","TI","BS","ZG","AI","NW")

ann_centroids <- ch |>
  filter(Kanton %in% ann_iso) |>
  mutate(centroid = st_centroid(geometry))

cc <- st_coordinates(ann_centroids$centroid)
ann <- ann_centroids |>
  st_drop_geometry() |>
  mutate(x = cc[, 1], y = cc[, 2]) |>
  select(Kanton, label, mean_premium, x, y)

nudges <- tribble(
  ~Kanton, ~nudge_x, ~nudge_y, ~hjust,
  # top 3
  "GE",    -55e3,    -25e3,    1,     # SW into French border whitespace
  "TI",     50e3,    -45e3,    0,     # SE off the southern tip
  "BS",     20e3,     45e3,    0,     # NE into German border whitespace
  # bottom 3
  "ZG",     35e3,     38e3,    0,     # NE into the upper Zürich whitespace
  "AI",     50e3,     20e3,    0,     # E off the German border
  "NW",    -55e3,    -28e3,    1      # SW into Bernese / Bernese-Oberland whitespace
)

ann <- ann |>
  inner_join(nudges, by = "Kanton") |>
  mutate(text = sprintf("%s\nCHF %.0f", label, mean_premium))

# ---- 4. Plot ----------------------------------------------------------
seq_pal <- pg_seq_palette[-1]   # drop #ECEAE4 light_quartz — too close to page

p <- ggplot(ch) +
  geom_sf(aes(fill = mean_premium),
          color = "white", linewidth = 0.30) +
  geom_sf(data = national, fill = NA,
          color = pg_palette$alloy, linewidth = 0.40) +
  scale_fill_gradientn(
    colours = seq_pal,
    breaks  = c(450, 525, 600, 675, 750),
    limits  = c(425, 775),
    labels  = function(x) sprintf("CHF %d", x),
    name    = "Mean adult standard premium per month (CHF, 2026)",
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

out_pdf <- "iterations/task_11/v4/kvg_premium_v4.pdf"
ggsave(out_pdf, p, width = 28, height = 15.5, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
