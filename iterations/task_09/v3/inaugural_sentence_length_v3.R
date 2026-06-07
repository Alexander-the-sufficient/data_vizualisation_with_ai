# Task 9 v3 — Average sentence length in US inaugural addresses, 1789-2025.
#
# v3 vs v2:
#   * All dots are one color (alloy). v2 highlighted Washington / Lincoln
#     / Biden in copper; that was a double encoding (color + label saying
#     "look here"). User requested uniform dot color so the leader lines
#     do the pointing on their own.
#   * Labels are pushed clear of the data path with longer leader lines,
#     placed in empty regions above the trend so they no longer sit on
#     or near the line:
#       - Washington 1789: label far to the right of the point, in the
#         upper-right empty zone where the trend has dropped away.
#       - Lincoln 1865: label well above the point, in the upper-mid
#         empty band above the trend.
#       - Biden 2021: label well above the point, in the upper-right
#         empty band above the recent flat run.
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
# Three rhetorical anchors: founding-father baseline, plain-English pivot,
# modern minimum. Labels sit in empty whitespace above the trend curve,
# connected to their points via short leader segments.
anchors <- tibble(
  year   = c(1789, 1865, 2021),
  label  = c("Washington 1789",
             "Lincoln 1865",
             "Biden 2021"),
  nudge_x = c(28,    0,    0),
  nudge_y = c( 2,   24,   17)
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
  geom_text_repel(data = ann, aes(label = label),
                  family = chart_family, size = 3.2,
                  color = pg_palette$alloy,
                  segment.color = pg_palette$dark_stone,
                  segment.size = 0.3,
                  box.padding = 0.5, point.padding = 0.5,
                  min.segment.length = 0,
                  nudge_x = ann$nudge_x,
                  nudge_y = ann$nudge_y,
                  force = 0.2, force_pull = 0.5,
                  seed = 17) +
  geom_text(data = endpoint, aes(label = "2025"),
            family = chart_family, size = 3.0,
            color = pg_palette$dark_stone,
            hjust = -0.25, vjust = 0.5) +
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

out_pdf <- "iterations/task_09/v3/inaugural_sentence_length_v3.pdf"
ggsave(out_pdf, p, width = 26, height = 14, units = "cm", device = "pdf")
cat("\nSaved:", out_pdf, "\n")

write_csv(stats,
          "iterations/task_09/v3/inaugural_sentence_length_stats.csv")
