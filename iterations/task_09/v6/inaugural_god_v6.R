# Task 9 v6 — focused lexical dispersion of the word "God" across all 60
# US inaugural addresses, 1789–2025.
#
# v6 vs v5: dropped the 6-panel small-multiples format. v5 had 1 panel
# (GOD) that read preattentively and 5 that didn't, which makes 5/6 of
# the chart's ink decorative — a nothingburger risk per lecture 06's
# mistake #8. v6 commits to the one panel that already worked, with two
# stories layered on top of one another:
#
#   (1) HISTORICAL: 20 of the first 30 inaugurals (Washington 1789 →
#       Hayes 1877, with the exception of Lincoln 1861) never mention
#       God at all. "God" emerges in inaugural rhetoric in the late
#       19th century and becomes a fixture from FDR onward.
#   (2) POSITIONAL: in the speeches where God appears, the occurrences
#       cluster heavily in the final 20% of the speech — the canonical
#       closing benediction ("God bless America"). v6 marks this zone
#       with a light copper background fill.
#
# Annotation anchors: Reagan 1985 = modern peak (8 mentions); Lincoln
# 1865 = first president to invoke God repeatedly (5 mentions).
#
# Data: US presidential inaugural addresses, 1789–2025 (60 speeches),
# from the `quanteda` R corpus `data_corpus_inaugural`. Local CSV
# `data/task_09/inaugural_addresses.csv`.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(quanteda)
})

source("design_system.R")
chart_family <- ""

raw <- read_csv("data/task_09/inaugural_addresses.csv", show_col_types = FALSE)
corp <- corpus(raw, text_field = "text", docid_field = "year")
toks <- tokens(corp, remove_punct = TRUE, remove_symbols = TRUE) %>%
  tokens_tolower()

# For each speech, find positions of "god" and the speech length.
disp <- bind_rows(lapply(seq_along(toks), function(i) {
  positions <- which(as.character(toks[[i]]) == "god")
  if (length(positions) == 0) return(NULL)
  n <- length(toks[[i]])
  data.frame(year = as.integer(docnames(toks)[i]),
             pos = positions, n = n, norm = positions / n)
}))

# Counts per speech (including zeros).
counts <- raw %>%
  mutate(
    row_id = row_number(),
    n_god  = sapply(seq_along(toks),
                    function(i) sum(as.character(toks[[i]]) == "god")),
    label  = paste0(year, "  ", president)
  ) %>%
  arrange(year)

# Attach row_id to disp so y-axis stays chronological.
disp <- disp %>%
  left_join(counts %>% select(year, row_id), by = "year")

# Annotation anchors.
ann <- tibble::tribble(
  ~row_id, ~text, ~xlab,
  counts$row_id[counts$year == 1865 & counts$president == "Lincoln"],
    "Lincoln 1865 — 5 mentions, the first dense invocation", 1.05,
  counts$row_id[counts$year == 1985],
    "Reagan 1985 — 8 mentions, the modern peak",            1.05
)

# Benediction zone (closing 20%) — light copper background fill.
benediction <- data.frame(xmin = 0.80, xmax = 1.00,
                          ymin = -Inf, ymax = Inf)

# Pick which y-axis labels to show — all 60 at small font.
y_breaks <- counts$row_id
y_labels <- counts$label

p <- ggplot() +
  geom_rect(data = benediction,
            aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
            fill = pg_palette$copper, alpha = 0.10) +
  annotate("text", x = 0.98, y = -1.6,
           label = "closing benediction zone",
           family = chart_family, size = 2.8,
           color = pg_palette$copper, hjust = 1, vjust = 0,
           fontface = "italic") +
  geom_segment(data = counts,
               aes(x = 0, xend = 1, y = row_id, yend = row_id),
               color = pg_palette$light_quartz, linewidth = 0.25) +
  geom_point(data = disp,
             aes(x = norm, y = row_id),
             color = pg_palette$alloy, shape = 124, size = 2.6) +
  # Count of mentions at the far right of each row (only > 0).
  geom_text(data = counts %>% filter(n_god > 0),
            aes(x = 1.03, y = row_id, label = n_god),
            family = chart_family, size = 2.5,
            color = pg_palette$dark_stone, hjust = 0, vjust = 0.5) +
  scale_x_continuous(breaks = c(0, 0.5, 1),
                     labels = c("Start", "Middle", "End"),
                     limits = c(0, 1.10),
                     expand = expansion(mult = c(0.005, 0))) +
  scale_y_reverse(breaks = y_breaks, labels = y_labels,
                  expand = expansion(mult = c(0.005, 0.02))) +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = NULL) +
  theme_pg(base_family = chart_family) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.minor   = element_blank(),
    axis.ticks.x       = element_line(color = pg_palette$dark_stone,
                                      linewidth = 0.3),
    axis.ticks.length.x = unit(2, "pt"),
    axis.ticks.y       = element_blank(),
    axis.text.x        = element_text(size = 9, color = pg_palette$dark_stone),
    axis.text.y        = element_text(size = 6.5, color = pg_palette$alloy,
                                      hjust = 1, margin = margin(r = 4)),
    plot.margin        = margin(t = 6, r = 18, b = 6, l = 6)
  )

out_pdf <- "iterations/task_09/v6/inaugural_god_v6.pdf"
ggsave(out_pdf, p, width = 22, height = 17, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
cat("Speeches with God mentions:", sum(counts$n_god > 0), "/", nrow(counts), "\n")
cat("Total occurrences:", sum(counts$n_god), "\n")
cat("Top 5 speeches by God count:\n")
counts %>% arrange(desc(n_god)) %>% select(year, president, n_god) %>% head(5) %>% print()
