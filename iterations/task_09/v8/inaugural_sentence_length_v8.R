# Task 9 v8 — Average sentence length in US inaugural addresses, 1789-2025.
#
# v8 vs v4 (the shipped scatter; v5/v6/v7 were rejected chart-type
# alternates — lexical dispersion / God dispersion / scatter-with-quotes):
#   * Only change: the "2025" endpoint label is shifted further to the
#     right (nudge_x = 3) so it sits clear of the rightmost dot instead
#     of crowding it at the plot's right edge. Everything else — anchors,
#     LOESS, palette, axes — is byte-for-byte v4.
#
# v4 vs v3:
#   * Lincoln 1865 annotation dropped. Two anchors (founding-father
#     baseline + modern minimum) carry the story; the rhetorical-pivot
#     midpoint was nice-to-have, not load-bearing, and the chart reads
#     cleaner without a third label crossing the trend.
#   * Washington 1789 label moved slightly up and left — closer to the
#     dot, sitting just above the early-1790s data points instead of
#     drifting out toward 1820.
#   * Biden 2021 label moved to the left of the dot at the same y
#     level, with a short leader segment back to the point.
#
# Data source: Quanteda built-in `data_corpus_inaugural`, exported once
# via data/task_09/export_corpus.R to data/task_09/inaugural_addresses.csv.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(quanteda)
  library(ggplot2)
  library(ggrepel)
})

source("design_system.R")
chart_family <- ""

# ---- Load -------------------------------------------------------------
raw <- read_csv("data/task_09/inaugural_addresses.csv", show_col_types = FALSE)

# ---- Per-address text statistics --------------------------------------
compute_stats <- function(txt) {
  corp_one <- corpus(txt)
  sents    <- corpus_reshape(corp_one, to = "sentences")
  toks     <- tokens(sents, remove_punct = TRUE, remove_symbols = TRUE,
                     remove_numbers = FALSE)
  n_sent   <- ndoc(sents)
  n_word   <- sum(ntoken(toks))
  tibble(n_sent = n_sent, n_word = n_word,
         avg_wps = n_word / n_sent)
}

stats <- raw %>%
  rowwise() %>%
  mutate(s = list(compute_stats(text))) %>%
  ungroup() %>%
  tidyr::unnest_wider(s) %>%
  select(year, president, first_name, party, n_word, n_sent, avg_wps)

cat("Stats summary:\n")
print(stats %>% summarise(min = min(avg_wps), median = median(avg_wps),
                          max = max(avg_wps)))

# ---- Annotation anchors -----------------------------------------------
# Two anchors only: founding-father baseline and modern minimum.
anchors <- tibble(
  year    = c(1789, 2021),
  label   = c("Washington 1789", "Biden 2021"),
  hjust   = c(0,    1),
  vjust   = c(0.5,  0.5),
  nudge_x = c(12,  -8),
  nudge_y = c( 6,   0)
)

ann <- stats %>% inner_join(anchors, by = "year")
cat("\nAnnotation anchor values:\n"); print(ann)

# Endpoint marker for 2025 (most recent observation).
endpoint <- stats %>% filter(year == max(year))

# ---- Plot -------------------------------------------------------------
x_breaks <- c(1800, 1840, 1880, 1920, 1960, 2000)
y_breaks <- seq(10, 70, by = 10)

p <- ggplot(stats, aes(x = year, y = avg_wps)) +
  geom_smooth(method = "loess", span = 0.55, se = FALSE,
              color = pg_palette$alloy, linewidth = 0.7,
              linetype = "dashed") +
  geom_point(color = pg_palette$alloy, size = 2.4, alpha = 0.85) +
  geom_text_repel(data = ann, aes(label = label,
                                  hjust = hjust, vjust = vjust),
                  family = chart_family, size = 3.2,
                  color = pg_palette$alloy,
                  segment.color = pg_palette$dark_stone,
                  segment.size = 0.3,
                  box.padding = 0.4, point.padding = 0.5,
                  min.segment.length = 0,
                  nudge_x = ann$nudge_x,
                  nudge_y = ann$nudge_y,
                  force = 0.1, force_pull = 1,
                  seed = 17) +
  geom_text(data = endpoint, aes(label = "2025"),
            family = chart_family, size = 3.0,
            color = pg_palette$dark_stone,
            hjust = -0.25, vjust = 0.5, nudge_x = 3) +
  scale_x_continuous(breaks = x_breaks,
                     limits = c(1785, 2035),
                     expand = expansion(mult = c(0.01, 0.01))) +
  scale_y_continuous(breaks = y_breaks,
                     limits = c(7, 75),
                     expand = expansion(mult = c(0.02, 0.05))) +
  labs(x = NULL, y = "Average words per sentence") +
  theme_pg(base_size = 11, base_family = chart_family) +
  theme(
    panel.grid.major.y = element_line(color = pg_palette$light_quartz,
                                      linewidth = 0.3),
    panel.grid.major.x = element_blank(),
    plot.margin = margin(t = 8, r = 14, b = 8, l = 8)
  )

out_pdf <- "iterations/task_09/v8/inaugural_sentence_length_v8.pdf"
ggsave(out_pdf, p, width = 26, height = 14, units = "cm", device = "pdf")
cat("\nSaved:", out_pdf, "\n")

write_csv(stats,
          "iterations/task_09/v8/inaugural_sentence_length_stats.csv")
