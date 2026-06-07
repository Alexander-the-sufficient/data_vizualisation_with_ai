# Task 9 v5 — lexical dispersion of six focal words across all 60 US
# inaugural addresses, 1789–2025.
#
# v5 vs v4: chart-type pivot. v1–v4 plotted one stylometric number per
# speech (average sentence length) — that was defensible as text analysis
# but visually indistinguishable from any quantitative time series. v5 is
# a lexical dispersion plot in the canonical sense: each speech is a
# horizontal row, each tick mark is one occurrence of the focal word at
# its normalised position within the speech. Six focal words rendered as
# small multiples in a 2×3 grid.
#
# Story: which presidents leaned on which words, and *where* in the speech
# they put them. "God" clusters at openings and closings (invocation +
# benediction); "war" peaks in the Civil-War, WWI, WWII, and post-9/11
# inaugurals; "freedom" lights up the Cold War and Reagan/Bush era;
# "peace" peaks after major wars; "America" and "people" are baseline-
# steady but trend denser in the modern era.
#
# Data: US presidential inaugural addresses, 1789–2025 (60 speeches), via
# the `quanteda` corpus `data_corpus_inaugural`. Local CSV
# `data/task_09/inaugural_addresses.csv` — already used by v1–v4.

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

# Six focal words. Order chosen for story flow: identity → ideology →
# religion → conflict → resolution → polity.
focal_words <- c("america", "freedom", "god", "war", "peace", "people")

# For each (word, speech), find the positions of the word in the
# tokenised text and normalise to 0–1.
disp <- bind_rows(lapply(focal_words, function(w) {
  bind_rows(lapply(seq_along(toks), function(i) {
    positions <- which(as.character(toks[[i]]) == w)
    if (length(positions) == 0) return(NULL)
    n_toks <- length(toks[[i]])
    year   <- as.integer(docnames(toks)[i])
    data.frame(word = w, year = year, pos = positions,
               n_toks = n_toks, norm = positions / n_toks)
  }))
}))

# Speech-length scaffold: one horizontal line per (word, year) so the
# reader sees that 60 speeches are present even when a word never appears.
speech_rows <- expand.grid(
  word = focal_words,
  year = as.integer(docnames(toks)),
  stringsAsFactors = FALSE
)

# Panel-level counts to put in a small annotation per facet
panel_counts <- disp %>%
  count(word, name = "occurrences") %>%
  mutate(label = paste0(occurrences, " occurrences"))

# Lock factor order so facets follow the story sequence above.
disp$word         <- factor(disp$word,         levels = focal_words)
speech_rows$word  <- factor(speech_rows$word,  levels = focal_words)
panel_counts$word <- factor(panel_counts$word, levels = focal_words)

# Title-case facet labels.
facet_labels <- setNames(toupper(focal_words), focal_words)

p <- ggplot() +
  geom_segment(data = speech_rows,
               aes(x = 0, xend = 1, y = year, yend = year),
               color = pg_palette$light_quartz, linewidth = 0.25) +
  geom_point(data = disp,
             aes(x = norm, y = year),
             color = pg_palette$alloy,
             shape = 124, size = 1.6) +  # shape 124 = vertical tick
  geom_text(data = panel_counts,
            aes(x = 0.98, y = 2030, label = label),
            family = chart_family, size = 2.6,
            color = pg_palette$dark_stone,
            hjust = 1, vjust = 1) +
  facet_wrap(~ word, ncol = 3,
             labeller = labeller(word = facet_labels)) +
  scale_x_continuous(breaks = c(0, 0.5, 1),
                     labels = c("Start", "Middle", "End"),
                     expand = expansion(mult = c(0.01, 0.01))) +
  scale_y_reverse(breaks = seq(1800, 2000, 50),
                  expand = expansion(mult = c(0.04, 0.06))) +
  labs(x = NULL, y = NULL) +
  theme_pg(base_family = chart_family) +
  theme(
    strip.text          = element_text(size = 10, face = "bold",
                                       color = pg_palette$onyx, hjust = 0),
    strip.background    = element_blank(),
    panel.spacing.x     = unit(0.8, "cm"),
    panel.spacing.y     = unit(0.6, "cm"),
    panel.grid.major.x  = element_blank(),
    panel.grid.major.y  = element_line(color = pg_palette$light_quartz,
                                       linewidth = 0.2),
    panel.grid.minor    = element_blank(),
    axis.ticks.x        = element_line(color = pg_palette$dark_stone,
                                       linewidth = 0.3),
    axis.ticks.length.x = unit(2, "pt"),
    axis.text.x         = element_text(size = 8, color = pg_palette$dark_stone),
    axis.text.y         = element_text(size = 8, color = pg_palette$alloy)
  )

out_pdf <- "iterations/task_09/v5/inaugural_dispersion_v5.pdf"
ggsave(out_pdf, p, width = 26, height = 14, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
cat("Total ticks rendered:", nrow(disp), "\n")
print(panel_counts)
