# Task 9 v7 — sentence length over 235 years of US inaugural addresses,
# with the extreme sentences quoted on the chart.
#
# v7 vs v6: chart-type pivot back to the v4 sentence-length scatter, with
# the v5/v6 lesson applied (a chart for the "visualisation of textual
# data" task should put text on the chart). Two real sentences from the
# corpus are quoted inline:
#   * Washington 1789's longest sentence (140 words) — the Latinate
#     periodic-prose extreme.
#   * Biden 2021 ("There is truth and there are lies.", 7 words) — the
#     declarative-aphoristic modern extreme.
# The visible *length* of each quoted block on the chart is itself a
# secondary encoding: the Washington quote takes many lines, Biden's
# takes one, mirroring the y-axis values their dots sit on.
#
# Why a third chart-type pivot is defensible:
#   - v1-v4 (sentence-length scatter): the chart told a strong story but
#     visually didn't read as "text data."
#   - v5 (6-panel lexical dispersion): five of six panels failed
#     preattentive reading (lecture 06 mistake #8, nothingburger risk).
#   - v6 (focused God dispersion): single-finding story, narrower than
#     "the evolution of presidential English."
#   - v7 returns to v4's broader story (language as such) and ADDS the
#     text-on-the-chart lesson from v5/v6: real sentences from the corpus
#     are quoted at the chart's two extreme data points. The iteration
#     arc reads: tried this → tried that → learned from both → settled.
#
# Data: same as v1-v6 — `data/task_09/inaugural_addresses.csv`,
# built from the `quanteda` corpus `data_corpus_inaugural`.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(quanteda)
})

source("design_system.R")
chart_family <- ""

raw  <- read_csv("data/task_09/inaugural_addresses.csv",
                 show_col_types = FALSE)
corp <- corpus(raw, text_field = "text", docid_field = "year")
sents <- corpus_reshape(corp, to = "sentences")
sent_toks <- tokens(sents, remove_punct = TRUE, remove_symbols = TRUE)
sent_lens <- ntoken(sent_toks)

# Average words per sentence per inaugural. `corpus_reshape` strips the
# docid (year) from the docvars, so recover it from the docname prefix
# ("1789.1", "1789.2", ...).
sent_year <- as.integer(sub("\\..*$", "", docnames(sents)))

wps <- tibble(year = sent_year,
              len  = as.integer(sent_lens)) %>%
  group_by(year) %>%
  summarise(wps = mean(len), .groups = "drop") %>%
  arrange(year)

# Two highlighted dots: Washington 1789 (62.2 wps) and Biden 2021 (11.0).
anchors <- wps %>% filter(year %in% c(1789, 2021))

# Endpoint label for 2025 (no quote, just a low-emphasis marker so the
# series visibly ends today).
endpoint_2025 <- wps %>% filter(year == 2025)

# Quoted-sentence text blocks. Each block is one annotate("text") call;
# multi-line text is wrapped manually with \n at sensible breakpoints.
wash_block <- paste(
  "Washington 1789 — one sentence (140 words):",
  "“I dwell on this prospect with every satisfaction which an",
  "ardent love for my country can inspire, since there is no truth",
  "more thoroughly established than that there exists in the economy",
  "and course of nature an indissoluble union between virtue and",
  "happiness; between duty and advantage; between the genuine maxims",
  "of an honest and magnanimous policy and the solid rewards of public",
  "prosperity and felicity …”",
  sep = "\n"
)

biden_block <- paste(
  "Biden 2021 — one sentence (7 words):",
  "“There is truth and there are lies.”",
  sep = "\n"
)

# Anchor positions for the text blocks + leader lines to the dots.
# Washington quote sits in the upper-right empty quadrant; Biden quote
# sits in the middle-right empty quadrant.
text_anchors <- tibble::tribble(
  ~role,        ~x_text,             ~y_text, ~x_pt,                ~y_pt,
  "washington", as.Date("1820-01-01"),  53,    as.Date("1789-01-01"), 62.2,
  "biden",      as.Date("1955-01-01"),  35,    as.Date("2021-01-01"), 11.0
) %>%
  mutate(year_text = as.integer(format(x_text, "%Y")),
         year_pt   = as.integer(format(x_pt,   "%Y")))

# Build the plot.
p <- ggplot(wps, aes(x = year, y = wps)) +
  geom_smooth(method = "loess", span = 0.55, se = FALSE,
              color = pg_palette$dark_quartz,
              linewidth = 0.5, linetype = "dashed") +
  geom_point(color = pg_palette$alloy, size = 1.6) +
  # Highlighted extreme dots get a slightly bolder treatment.
  geom_point(data = anchors, aes(x = year, y = wps),
             color = pg_palette$heritage_red, size = 2.2) +
  # 2025 endpoint label.
  geom_text(data = endpoint_2025, aes(x = year, y = wps, label = "2025"),
            family = chart_family, size = 2.8,
            color = pg_palette$dark_stone,
            hjust = -0.2, vjust = 0.5) +
  # Leader segments from each text block to its anchor dot.
  geom_segment(data = text_anchors,
               aes(x = year_text, y = y_text, xend = year_pt, yend = y_pt),
               color = pg_palette$dark_quartz, linewidth = 0.25,
               linetype = "dotted",
               inherit.aes = FALSE) +
  # Washington quote block.
  annotate("text",
           x = 1820, y = 67,
           label = wash_block,
           family = chart_family, size = 2.8,
           color = pg_palette$alloy,
           hjust = 0, vjust = 1, lineheight = 1.15) +
  # Biden quote block.
  annotate("text",
           x = 1955, y = 40,
           label = biden_block,
           family = chart_family, size = 2.8,
           color = pg_palette$alloy,
           hjust = 0, vjust = 1, lineheight = 1.15) +
  scale_x_continuous(breaks = seq(1800, 2020, 40),
                     limits = c(1785, 2032),
                     expand = expansion(mult = c(0.01, 0.02))) +
  scale_y_continuous(breaks = seq(10, 70, 10),
                     limits = c(8, 70),
                     expand = expansion(mult = c(0.02, 0.02))) +
  labs(x = NULL, y = "Average words per sentence") +
  theme_pg(base_family = chart_family) +
  theme(
    panel.grid.major.y = element_line(color = pg_palette$light_quartz,
                                      linewidth = 0.3),
    panel.grid.minor   = element_blank(),
    axis.title.y       = element_text(size = 10, color = pg_palette$alloy,
                                      margin = margin(r = 8))
  )

out_pdf <- "iterations/task_09/v7/inaugural_sentence_length_v7.pdf"
ggsave(out_pdf, p, width = 26, height = 14, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
cat("Washington 1789 avg wps:", round(wps$wps[wps$year == 1789], 1), "\n")
cat("Biden 2021 avg wps:    ", round(wps$wps[wps$year == 2021], 1), "\n")
cat("Trump 2025 avg wps:    ", round(wps$wps[wps$year == 2025], 1), "\n")
