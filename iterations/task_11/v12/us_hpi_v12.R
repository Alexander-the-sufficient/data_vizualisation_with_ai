# Task 11 v12 — US House Price Index growth by state, 2020 Q1 → 2025 Q3.
#
# Topic pivot from the Swiss KVG choropleth (v3-v11). The Swiss-canton
# variation story was real but niche; this version shows the post-
# pandemic US housing boom geography, which has clear winners and
# losers and matches the portfolio's macroeconomic theme.
#
# Data: FHFA All-Transactions House Price Index, state level
# (FRED `<STATE_CODE>STHPI` series). Downloaded via the project's FRED
# API helper at `data/task_11/fetch_state_hpi.R`. Long-format CSV at
# `data/task_11/us_state_hpi.csv`; the per-state % change ready for
# mapping at `data/task_11/us_state_hpi_pct_change.csv`.
#
# Story: the Sunbelt narrative is incomplete. Maine (+82%), New Hampshire
# (+76%), Vermont (+76%), Rhode Island (+75%), and New Jersey (+73%) lead
# the country. Washington DC trails everyone at +18%. The Sunbelt states
# come in second-tier (FL +69%, TN/NC/SC ~72%); California only +45%.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(sf)
  library(usmap)
})

source("design_system.R")
chart_family <- ""

hpi <- read_csv("data/task_11/us_state_hpi_pct_change.csv",
                show_col_types = FALSE)

# usmap::us_map() returns an sf object with Alaska + Hawaii pre-shifted
# into the lower-left inset (the standard "Albers USA" composite).
us_sf <- usmap::us_map(regions = "states")

us_data <- us_sf %>%
  left_join(hpi, by = c("abbr" = "state"))

# Sequential palette: light quartz (lowest growth) → alloy (highest).
# Range in the data: 17.7% (DC) to 81.9% (ME). 5 stops for legend bins.
seq_ramp <- c(pg_palette$light_quartz,
              pg_palette$quartz,
              pg_palette$medium_quartz,
              pg_palette$dark_quartz,
              pg_palette$dark_stone,
              pg_palette$alloy)

# Annotation anchors. usmap pre-projected coordinates; centroids are
# what we leader-line to.
centroids <- us_data %>%
  mutate(centroid = st_centroid(geom)) %>%
  st_set_geometry("centroid") %>%
  st_coordinates() %>%
  as.data.frame() %>%
  setNames(c("cx", "cy"))
us_data$cx <- centroids$cx
us_data$cy <- centroids$cy

ann <- us_data %>%
  st_drop_geometry() %>%
  filter(abbr %in% c("ME", "DC")) %>%
  mutate(
    text = case_when(
      abbr == "ME" ~ paste0("Maine +", round(pct_change), "%\nhighest in the country"),
      abbr == "DC" ~ paste0("DC +", round(pct_change), "%\nlowest in the country")
    ),
    nudge_x = case_when(
      abbr == "ME" ~  900000,
      abbr == "DC" ~  1500000
    ),
    nudge_y = case_when(
      abbr == "ME" ~  300000,
      abbr == "DC" ~ -600000
    ),
    role = ifelse(abbr == "ME", "high", "low")
  )

p <- ggplot(us_data) +
  geom_sf(aes(fill = pct_change),
          color = "white", linewidth = 0.25) +
  geom_segment(data = ann,
               aes(x = cx + nudge_x, y = cy + nudge_y,
                   xend = cx, yend = cy),
               color = pg_palette$alloy, linewidth = 0.3,
               inherit.aes = FALSE) +
  geom_label(data = ann,
             aes(x = cx + nudge_x, y = cy + nudge_y, label = text),
             family = chart_family, size = 3.0,
             color = pg_palette$alloy,
             fill = "white", linewidth = 0,
             label.r = unit(0, "pt"),
             label.padding = unit(c(2, 3, 2, 3), "pt"),
             lineheight = 0.95,
             hjust = 0.5, vjust = 0.5,
             inherit.aes = FALSE) +
  scale_fill_gradientn(
    colours = seq_ramp,
    name    = "Change in House Price Index, 2020 Q1 to 2025 Q3",
    labels  = function(x) paste0("+", x, "%"),
    breaks  = c(20, 35, 50, 65, 80),
    guide   = guide_colorbar(
      barwidth = unit(7, "cm"), barheight = unit(0.3, "cm"),
      title.position = "top", title.hjust = 0,
      ticks.colour = pg_palette$alloy,
      frame.colour = NA
    )
  ) +
  coord_sf(crs = st_crs(us_sf), datum = NA, clip = "off") +
  labs(x = NULL, y = NULL) +
  theme_pg(base_size = 11, base_family = chart_family) +
  theme(
    panel.grid       = element_blank(),
    axis.text        = element_blank(),
    axis.line.x      = element_blank(),
    axis.line.y      = element_blank(),
    axis.ticks       = element_blank(),
    legend.position  = "bottom",
    legend.title     = element_text(size = 10, color = pg_palette$alloy,
                                    margin = margin(b = 4)),
    legend.text      = element_text(size = 9, color = pg_palette$alloy),
    legend.box.spacing = unit(0.3, "cm"),
    plot.margin      = margin(t = 6, r = 6, b = 6, l = 6)
  )

out_pdf <- "iterations/task_11/v12/us_hpi_v12.pdf"
ggsave(out_pdf, p, width = 26, height = 14, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
