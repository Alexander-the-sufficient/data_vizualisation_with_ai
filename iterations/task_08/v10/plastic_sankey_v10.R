# Task 8 v10 — Global plastic waste by sector and fate, 2019.
#
# Topic pivot from US energy (LLNL Sankey, v4-v9) to global plastic waste.
# Reasons documented in v9 reference_log.md notes:
#   * The LLNL chart, even after extensive cleanup, was a complex 4-stage
#     flow that read as busy at A4-landscape size. Visual fixes (stratum
#     outlines, copper Generation loss) helped but the chart still felt
#     "engineering" rather than "editorial."
#   * The user explicitly invited a topic + dataset switch: "consider to
#     take an entirely different data set ... we are free with the data
#     we choose. At the end, the chart has to look good."
#   * Plastic waste data has a far stronger story-imbalance than energy:
#     of ~460 Mt of plastic waste generated globally in 2019, less than
#     10% is recycled. The visual contrast between the tiny "recycled"
#     ribbon and the massive "landfilled + mismanaged" slabs is the
#     entire chart.
#
# Story: of the world's 460 Mt of plastic waste in 2019, just 9% was
# recycled. Half went to landfill; almost a quarter leaked into the
# environment as mismanaged waste.
#
# Chart structure: 2-stage Sankey.
#   Stage 1: use sector that produced the waste (7 buckets, four small
#     industrial sectors collapsed into "Other" for legibility).
#   Stage 2: end-of-life fate (4 buckets: recycled / incinerated /
#     landfilled / mismanaged).
# Total flow tonnage on each side reconciles: each sector splits into
# the four fates in the proportions of the 2019 global fate breakdown,
# applied uniformly. Geyer / Jambeck / Law (2017) note that fate splits
# do vary modestly by sector but the global proportions are the right
# first-order approximation when sector-specific fate is not separately
# published.
#
# Sources:
#   * Plastic-waste-by-sector (1990-2019). OWID extension of Geyer,
#     Jambeck & Law (2017), Science Advances 3(7).
#     URL: https://ourworldindata.org/grapher/plastic-waste-by-sector
#     Local: data/task_08_plastic/plastic_waste_by_sector.csv
#   * Global plastic fate (2000-2019). Same provenance, regional + World
#     totals by fate.
#     URL: https://ourworldindata.org/grapher/global-plastic-fate
#     Local: data/task_08_plastic/global_plastic_fate.csv

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(purrr)
  library(ggplot2)
  library(ggalluvial)
})

source("design_system.R")
chart_family <- ""

# ---- Load data --------------------------------------------------------
target_year <- 2019  # latest year in both datasets

sector_raw <- read_csv("data/task_08_plastic/plastic_waste_by_sector.csv",
                       show_col_types = FALSE) %>%
  filter(Entity == "World", Year == target_year) %>%
  select(-Entity, -Code, -Year)

fate_raw   <- read_csv("data/task_08_plastic/global_plastic_fate.csv",
                       show_col_types = FALSE) %>%
  filter(Entity == "World", Year == target_year) %>%
  select(Recycled, Incinerated, Landfilled, Mismanaged)

# ---- Sector aggregation ----------------------------------------------
# Collapse the four very small industrial / niche sectors into the
# existing "Other" bucket so the Sankey has 7 readable rows instead of
# 11 with tiny dribbles.
small_sectors <- c("Industrial machinery", "Road marking",
                   "Marine coatings", "Personal care products")

sector <- sector_raw %>%
  pivot_longer(everything(), names_to = "sector", values_to = "tonnes") %>%
  mutate(sector = if_else(sector %in% small_sectors, "Other", sector)) %>%
  group_by(sector) %>%
  summarise(tonnes = sum(tonnes), .groups = "drop") %>%
  arrange(desc(tonnes))

# Rename for nicer display
sector <- sector %>%
  mutate(sector = recode(sector,
    "Building and construction"            = "Building & construction",
    "Consumer and institutional products"  = "Consumer products",
    "Textile sector"                       = "Textiles"
  ))

cat("Sector totals (Mt):\n")
sector %>% mutate(Mt = tonnes / 1e6) %>% print()

# ---- Fate proportions ------------------------------------------------
fate <- fate_raw %>%
  pivot_longer(everything(), names_to = "fate", values_to = "tonnes") %>%
  mutate(share = tonnes / sum(tonnes))

cat("\nFate breakdown (% of total fate tonnage):\n")
fate %>% mutate(pct = round(100 * share, 1)) %>% print()

# ---- Build path table ------------------------------------------------
# OWID's two datasets have slightly different total tonnages: the
# sector dataset reports 460 Mt of plastic waste generated in 2019, the
# fate dataset reports 353 Mt of plastic waste reaching end-of-life
# (the gap is plastic still in use or in stockpile). For an internally
# consistent Sankey we use the **fate dataset's absolute tonnages** as
# the total flow and the **sector dataset's proportions** to break
# them down by origin. That way the rightmost column matches the
# Geyer-Jambeck-Law fate measurements exactly, and the leftmost column
# shows the proportional contribution of each sector.
sector <- sector %>% mutate(share = tonnes / sum(tonnes))
sector_share_lookup <- setNames(sector$share, sector$sector)
fate_tonnes_lookup  <- setNames(fate$tonnes,  fate$fate)

paths <- crossing(sec_name = sector$sector, ft_name = fate$fate) %>%
  mutate(tonnes = sector_share_lookup[sec_name] *
                  fate_tonnes_lookup[ft_name]) %>%
  rename(sector = sec_name, fate = ft_name)

cat(sprintf("\nFlows: %d  | Total: %.0f Mt\n",
            nrow(paths), sum(paths$tonnes) / 1e6))

# ---- Order strata ----------------------------------------------------
sector_order <- sector$sector  # already desc by tonnes
fate_order   <- c("Mismanaged", "Landfilled", "Incinerated", "Recycled")

paths <- paths %>%
  mutate(sector = factor(sector, levels = sector_order),
         fate   = factor(fate,   levels = fate_order))

# ---- Colours ---------------------------------------------------------
# Severity-graded fate palette: copper for the alarming "mismanaged
# / leaked into environment" outcome (the only true accent in the
# chart), then a warm-neutral ramp from dark to light for the rest.
fate_colors <- c(
  "Mismanaged"  = pg_palette$copper,        # warm bronze, the accent
  "Landfilled"  = pg_palette$alloy,         # warm charcoal — dominant fate
  "Incinerated" = pg_palette$dark_stone,    # warm gray — energy-recovery loss
  "Recycled"    = pg_palette$dark_quartz    # taupe — the small good outcome
)

# Sector strata: all alloy (neutral). Fate strata pick up their fate
# colour. ggalluvial uses one fill scale across alluvium + stratum, so
# we combine the sector + fate colour vectors into a single named map.
sector_fill <- setNames(rep(pg_palette$alloy, length(sector_order)),
                        sector_order)
all_fills <- c(sector_fill, fate_colors)

# ---- Helpers ---------------------------------------------------------
fmt_t <- function(x) {
  ifelse(x >= 1e7, sprintf("%.0f Mt", x / 1e6),
         sprintf("%.1f Mt", x / 1e6))
}

stratum_w <- 0.18

# ---- Base plot -------------------------------------------------------
# alpha 0.75: flows visibly translucent so over-flow blending reads
# clearly, but strata still pop against them without needing thick
# white outlines (which read goofy at this size — see v9 lessons).
p_base <- ggplot(paths,
                 aes(axis1 = sector, axis2 = fate, y = tonnes)) +
  geom_alluvium(aes(fill = fate),
                width = stratum_w, alpha = 0.75,
                knot.pos = 0.4, curve_type = "sigmoid") +
  geom_stratum(width = stratum_w,
               aes(fill = after_stat(stratum)),
               color = "white", linewidth = 0.25) +
  scale_fill_manual(values = all_fills, guide = "none") +
  scale_x_continuous(limits = c(0.4, 2.6), expand = c(0, 0)) +
  scale_y_continuous(expand = expansion(mult = c(0.02, 0.10))) +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = NULL) +
  theme_void(base_family = chart_family) +
  theme(plot.margin = margin(t = 16, r = 18, b = 14, l = 18))

# Pull rendered stratum positions for label placement.
gb <- ggplot_build(p_base)
strat_layer_idx <- which(sapply(gb$plot$layers,
                                function(l) inherits(l$stat, "StatStratum")))[1]
strat_data <- gb$data[[strat_layer_idx]] %>%
  mutate(y_mid = (ymin + ymax) / 2)

sec_pos  <- strat_data %>% filter(x == 1)
fate_pos <- strat_data %>% filter(x == 2)

sec_labels <- sec_pos %>%
  transmute(x = 1 - stratum_w / 2 - 0.04, y = y_mid,
            label = paste0(stratum, "   ", fmt_t(count)))
fate_labels <- fate_pos %>%
  transmute(x = 2 + stratum_w / 2 + 0.04, y = y_mid,
            label = paste0(fmt_t(count), "  ", stratum,
                           "  (", round(100 * count / sum(count)), "%)"),
            color = fate_colors[as.character(stratum)])

total_t <- sum(paths$tonnes)

# ---- Final plot ------------------------------------------------------
p <- p_base +
  geom_text(data = sec_labels, aes(x = x, y = y, label = label),
            family = chart_family, size = 3.0, color = pg_palette$alloy,
            hjust = 1, vjust = 0.5, inherit.aes = FALSE) +
  geom_text(data = fate_labels,
            aes(x = x, y = y, label = label, color = color),
            family = chart_family, size = 3.4, fontface = "bold",
            hjust = 0, vjust = 0.5, inherit.aes = FALSE) +
  scale_color_identity() +
  # Column headers
  annotate("text", x = 1, y = total_t * 1.06,
           label = "USE SECTOR",
           family = chart_family, size = 2.9, fontface = "bold",
           color = pg_palette$onyx, hjust = 0.5) +
  annotate("text", x = 2, y = total_t * 1.06,
           label = "FATE",
           family = chart_family, size = 2.9, fontface = "bold",
           color = pg_palette$onyx, hjust = 0.5)

out_pdf <- "iterations/task_08/v10/plastic_sankey_v10.pdf"
ggsave(out_pdf, p, width = 30, height = 16, units = "cm", device = "pdf")
cat("\nSaved:", out_pdf, "\n")
