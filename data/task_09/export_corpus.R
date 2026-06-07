# Task 9 — export the inaugural-address corpus to a flat CSV.
#
# Source: quanteda's `data_corpus_inaugural` (CC0). The package's
# documentation traces the texts to:
#   * Bartleby.com, "Inaugural Addresses of the Presidents of the
#     United States" (https://www.bartleby.com/124/)
#   * Plus updates from C-SPAN / Miller Center / White House for
#     post-2009 inaugurals.
#
# We export to data/task_09/inaugural_addresses.csv so the chart
# script reads the raw text from disk (per the project guardrail —
# no in-script literals for measured values). Run this once to
# refresh the CSV; the chart script does not depend on quanteda.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(quanteda)
  library(dplyr)
  library(readr)
})

corpus <- data_corpus_inaugural

df <- tibble(
  year       = docvars(corpus, "Year"),
  president  = docvars(corpus, "President"),
  first_name = docvars(corpus, "FirstName"),
  party      = docvars(corpus, "Party"),
  text       = as.character(corpus)
)

cat("Exporting", nrow(df), "inaugural addresses (", min(df$year), "-",
    max(df$year), ")\n")

write_csv(df, "data/task_09/inaugural_addresses.csv")
cat("Wrote: data/task_09/inaugural_addresses.csv\n")
