# Task 11 v10 — Mean adult standard health-insurance premium by canton, 2026.
#
# v10 vs v7:
#   * Zug callout pushed further NE. v7's nudge (+90 km E, +50 km N)
#     placed the label so close to Switzerland's NE edge that it read
#     as crowding the map. v10 stretches the nudge to ~140 km E / 90 km
#     N — clear breathing room above the country; the line is a touch
#     longer but still points unambiguously at Zug. Plot xlim / ylim
#     widened to match so the label has room to land.
#
# (v7 vs v6 history retained below.)
#
# v7 vs v6:
#   * Callouts trimmed from 4 (GE / ZG / BS / AI) to 2 (GE, ZG). The
#     two extremes are the whole story; BS and AI were "pattern evidence"
#     that the colour ramp already conveys without needing labels. Less
#     ink on the page, headline reads faster.
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
ann_iso <- c("GE", "ZG")

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
  "ZG",    140e3,     90e3     # NE — pushed further out so the label
                                #     is no longer crowding the map
)

ann <- ann |>
  inner_join(nudges, by = "Kanton") |>
  mutate(text = sprintf("%s · CHF %.0f", label, mean_premium))

# ---- 4. Plot ----------------------------------------------------------
seq_pal <- pg_seq_palette[-1]

ch_bbox <- st_bbox(ch)
xlim <- c(ch_bbox$xmin - 90e3, ch_bbox$xmax + 140e3)   # extra E room
ylim <- c(ch_bbox$ymin - 80e3, ch_bbox$ymax + 110e3)   # extra N room

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

out_pdf <- "iterations/task_11/v10/kvg_premium_v10.pdf"
ggsave(out_pdf, p, width = 28, height = 15.5, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
