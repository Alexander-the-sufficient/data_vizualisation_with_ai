# Task 11 v6 — Mean adult standard health-insurance premium by canton, 2026.
#
# v6 vs v5:
#   * "76% gap" headline moved from bottom-left to top-left. v5 stacked the
#     red headline, the legend, and the Genève callout in the same lower-
#     left quadrant — three competing emphases in one corner. v6 puts the
#     headline at the top-left so the reader hits the story first on the
#     natural left-to-right top-down scan; the bottom row is left for the
#     Genève callout and the legend.
#   * Em-dash → hyphen-space-hyphen. v5's "—" character did not survive
#     the default PDF Helvetica encoding (mbcsToSbcs warning, replaced
#     with a hyphen-minus). v6 uses a plain " · " mid-dot instead, which
#     is in the Latin-1 supplement and renders correctly.
#   * Genève callout repositioned a hair to the south-east so it doesn't
#     crowd the legend's left edge.
#
# Story unchanged: Genève adults pay 76% more than Zug adults for the same
# federally-mandated standard reference policy. 2026 BAG tariffs.

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

range_min <- min(per_canton$mean_premium)
range_max <- max(per_canton$mean_premium)
gap_pct   <- 100 * (range_max / range_min - 1)
cat(sprintf("Range: CHF %.0f to %.0f, gap = %.0f%%\n",
            range_min, range_max, gap_pct))

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

# ---- 3. Annotation anchors --------------------------------------------
ann_iso <- c("GE", "ZG", "BS", "AI")

ann_centroids <- ch |>
  filter(Kanton %in% ann_iso) |>
  mutate(centroid = st_centroid(geometry))

cc <- st_coordinates(ann_centroids$centroid)
ann <- ann_centroids |>
  st_drop_geometry() |>
  mutate(x = cc[, 1], y = cc[, 2]) |>
  select(Kanton, label, mean_premium, x, y)

nudges <- tribble(
  ~Kanton, ~nudge_x, ~nudge_y,
  "GE",    -35e3,    -65e3,    # SSW into French border whitespace
  "ZG",     90e3,     50e3,    # NE through Schaffhausen direction
  "BS",      0,        65e3,   # due N into German border whitespace
  "AI",     85e3,      0       # due E into Bodensee whitespace
)

ann <- ann |>
  inner_join(nudges, by = "Kanton") |>
  mutate(text = sprintf("%s · CHF %.0f", label, mean_premium))  # · mid-dot

# ---- 4. Plot ----------------------------------------------------------
seq_pal <- pg_seq_palette[-1]   # drop light_quartz (too close to white)

ch_bbox <- st_bbox(ch)
xlim <- c(ch_bbox$xmin - 90e3, ch_bbox$xmax + 90e3)
ylim <- c(ch_bbox$ymin - 80e3, ch_bbox$ymax + 75e3)

p <- ggplot(ch) +
  geom_sf(aes(fill = mean_premium),
          color = "white", linewidth = 0.30) +
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
  geom_label(data = ann,
             aes(x = x + nudge_x, y = y + nudge_y, label = text),
             family = chart_family, size = 3.0,
             color = pg_palette$alloy,
             fill = "white", label.size = 0,
             label.padding = unit(c(1, 2.5, 1, 2.5), "pt")) +
  # Headline gap callout — top-left whitespace.
  annotate("text",
           x = xlim[1] + 5e3, y = ylim[2] - 8e3,
           label = "76% gap",
           hjust = 0, vjust = 1,
           family = chart_family, size = 7.5,
           color = pg_palette$heritage_red,
           fontface = "bold") +
  annotate("text",
           x = xlim[1] + 5e3, y = ylim[2] - 30e3,
           label = "Genève vs. Zug, same federal mandate.",
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

out_pdf <- "iterations/task_11/v6/kvg_premium_v6.pdf"
ggsave(out_pdf, p, width = 28, height = 15.5, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
