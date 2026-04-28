# Task 9 v2 — Average sentence length in US inaugural addresses, 1789-2025.
#
# Story: American presidential rhetoric has structurally simplified.
# Washington's 1789 inaugural averaged 62 words per sentence (Latinate,
# clause-stacked Federalist prose). Modern inaugurals run 11-19 wps,
# below modern newspaper writing. The decline is not about "shorter
# speeches" (some recent inaugurals are long) — it's about sentence
# structure. Long, periodic sentences disappeared.
#
# Data source: Quanteda built-in `data_corpus_inaugural`, exported once
# via data/task_09/export_corpus.R to data/task_09/inaugural_addresses.csv.
# Quanteda traces the texts to Bartleby.com / Miller Center / C-SPAN.
#
# Method: tokenize each address into sentences (quanteda corpus_reshape
# to sentences). Average sentence length = total word tokens / total
# sentences for that address.
#
# v2 vs v1:
#   * Annotation set rewritten. v1 anchored Kennedy 1961 (26.3 wps) and
#     Harrison 1841 (40.2 wps); neither is extreme on this metric — they
#     sat near the trendline so annotating them was off-message. Story
#     anchors are now the *extremes plus the rhetorical pivot*: Washington
#     1789 (62.2 — founding-father baseline), Lincoln 1865 (26.9 — the
#     pivot to plain English), Biden 2021 (11.0 — historical minimum).
#     Three is enough; four was crowded.
#   * Trump 2017 label was clipped at the lower margin in v1. v2 raises
#     the lower y-limit and drops Trump-2017 in favour of Biden-2021
#     (Biden 2021 is the actual record low — Trump 2017 was 16.4 wps,
#     which several other modern inaugurals match).
#   * 2025 (Trump 2nd inaugural, the dataset's rightmost point) was
#     unlabelled and easy to miss. Added a small "2025" tick at that
#     point so the reader sees the series ends today.
#   * LOESS line bumped from dark_stone 0.6pt to alloy 0.7pt — too faint
#     in v1; the trend is the chart's structural element.

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
cat("\nTop 5 longest sentences (avg):\n")
print(stats %>% arrange(desc(avg_wps)) %>% head(5))
cat("\nTop 5 shortest sentences (avg):\n")
print(stats %>% arrange(avg_wps) %>% head(5))

# ---- Annotation anchors -----------------------------------------------
anchors <- tibble(
  year = c(1789, 1865, 2021),
  label = c("Washington 1789",
            "Lincoln 1865",
            "Biden 2021"),
  hjust = c(0,    0,    1),
  vjust = c(0.5,  0,    0.5),
  nudge_x = c(6,  4,   -4),
  nudge_y = c(0,  6,    0)
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
  geom_point(data = ann, color = pg_palette$copper, size = 2.9) +
  geom_text_repel(data = ann, aes(label = label,
                                  hjust = hjust, vjust = vjust),
                  family = chart_family, size = 3.2,
                  color = pg_palette$alloy,
                  segment.color = pg_palette$dark_stone,
                  segment.size = 0.25,
                  box.padding = 0.4, point.padding = 0.35,
                  min.segment.length = 0,
                  nudge_x = ann$nudge_x,
                  nudge_y = ann$nudge_y,
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

out_pdf <- "iterations/task_09/v2/inaugural_sentence_length_v2.pdf"
ggsave(out_pdf, p, width = 26, height = 14, units = "cm", device = "pdf")
cat("\nSaved:", out_pdf, "\n")

# ---- Sanity-check exports ---------------------------------------------
write_csv(stats,
          "iterations/task_09/v2/inaugural_sentence_length_stats.csv")
