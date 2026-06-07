# Task 9 v1 — Average sentence length in US inaugural addresses, 1789-2025.
#
# Story: American presidential rhetoric has structurally simplified.
# Washington's 1789 inaugural averaged 51 words per sentence (Latinate,
# clause-stacked Federalist prose). Modern inaugurals run 13-19 wpsentence,
# below modern newspaper writing. The decline is not about "shorter
# speeches" (some recent inaugurals are long) — it's about sentence
# structure. Long, periodic sentences disappeared.
#
# Data source: Quanteda built-in `data_corpus_inaugural`, exported once
# via data/task_09/export_corpus.R to data/task_09/inaugural_addresses.csv.
# Quanteda traces the texts to Bartleby.com / Miller Center / C-SPAN.
#
# Method: tokenize each address into sentences (quanteda nsentence /
# ntoken on a sentence-tokenized corpus). Average sentence length =
# total tokens (words) / total sentences for that address.
#
# Chart: scatter (year, avg sentence length) + LOESS smoother. Five
# inaugurals annotated as story anchors: Washington 1789 (high),
# W.H.Harrison 1841 (long-but-grand), Lincoln 1865 (short, plain),
# JFK 1961 (famously punchy), Trump 2017 (modern low).

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
# Sentence count uses quanteda's tokenizer (handles "Mr.", "U.S.", etc.
# better than naive period splitting). Word count strips punctuation.
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
  year = c(1789, 1841, 1865, 1961, 2017),
  label = c("Washington 1789",
            "W. H. Harrison 1841",
            "Lincoln 1865",
            "Kennedy 1961",
            "Trump 2017")
)

ann <- stats %>% inner_join(anchors, by = "year")
cat("\nAnnotation anchor values:\n"); print(ann)

# ---- Plot -------------------------------------------------------------
x_breaks <- seq(1800, 2020, by = 40)
y_breaks <- seq(10, 70, by = 10)

p <- ggplot(stats, aes(x = year, y = avg_wps)) +
  geom_smooth(method = "loess", span = 0.55, se = FALSE,
              color = pg_palette$dark_stone, linewidth = 0.6,
              linetype = "dashed") +
  geom_point(color = pg_palette$alloy, size = 2.4, alpha = 0.85) +
  geom_point(data = ann, color = pg_palette$copper, size = 2.8) +
  geom_text_repel(data = ann, aes(label = label),
                  family = chart_family, size = 3.1,
                  color = pg_palette$alloy,
                  segment.color = pg_palette$dark_stone,
                  segment.size = 0.25,
                  box.padding = 0.45, point.padding = 0.35,
                  min.segment.length = 0,
                  nudge_y = c(8, 6, -7, 5, -7),
                  nudge_x = c(8, 6, -10, -8, -8),
                  seed = 17) +
  scale_x_continuous(breaks = x_breaks,
                     limits = c(1785, 2030),
                     expand = expansion(mult = c(0.01, 0.01))) +
  scale_y_continuous(breaks = y_breaks,
                     limits = c(8, 75),
                     expand = expansion(mult = c(0.02, 0.05))) +
  labs(x = NULL, y = "Average words per sentence") +
  theme_pg(base_size = 11, base_family = chart_family) +
  theme(
    panel.grid.major.y = element_line(color = pg_palette$light_quartz,
                                      linewidth = 0.3),
    panel.grid.major.x = element_blank(),
    plot.margin = margin(t = 8, r = 12, b = 6, l = 8)
  )

out_pdf <- "iterations/task_09/v1/inaugural_sentence_length_v1.pdf"
ggsave(out_pdf, p, width = 26, height = 14, units = "cm", device = "pdf")
cat("\nSaved:", out_pdf, "\n")

# ---- Sanity-check exports ---------------------------------------------
write_csv(stats,
          "iterations/task_09/v1/inaugural_sentence_length_stats.csv")
