# Task 12 v1 — USGS earthquake catalog data prep.
#
# Downloads the USGS ANSS ComCat catalog for 1980-01-01 to 2025-12-31
# at M≥5.0 in 5-year batches (each comfortably under the 20,000-event
# response cap of the FDSN web service). Concatenates batches, dedupes
# by event id, writes:
#
#   data/task_12/usgs_quakes_1980_2025_m5.csv         (raw concatenated)
#   interactive/task_12/data/quakes.csv.gz            (tidy, gzipped, 8 cols)
#
# Kept columns (per PLAN.md cell 2): id, time, latitude, longitude,
# depth, mag, magType, place. magType is heterogeneous across the
# catalog (Mw, mb, ML, Ms) and is surfaced alongside the value in the
# notebook detail panel.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(lubridate)
})

raw_dir   <- "data/task_12"
batch_dir <- file.path(raw_dir, "batches")
out_dir   <- "interactive/task_12/src/data"  # Framework expects FileAttachment paths inside src/
dir.create(raw_dir,   showWarnings = FALSE, recursive = TRUE)
dir.create(batch_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(out_dir,   showWarnings = FALSE, recursive = TRUE)

# Five-year batches; the global rate at M≥5.0 is ~1,500-1,700 events/yr,
# so each 5-year batch yields ~7,500-8,500 events — well under the
# 20,000-event FDSN response cap.
batches <- list(
  c("1980-01-01", "1984-12-31"),
  c("1985-01-01", "1989-12-31"),
  c("1990-01-01", "1994-12-31"),
  c("1995-01-01", "1999-12-31"),
  c("2000-01-01", "2004-12-31"),
  c("2005-01-01", "2009-12-31"),
  c("2010-01-01", "2014-12-31"),
  c("2015-01-01", "2019-12-31"),
  c("2020-01-01", "2024-12-31"),
  c("2025-01-01", "2025-12-31")
)

api_url <- function(start, end) {
  sprintf(paste0("https://earthquake.usgs.gov/fdsnws/event/1/query",
                 "?format=csv&starttime=%s&endtime=%s",
                 "&minmagnitude=5.0&orderby=time-asc"),
          start, end)
}

# ---- Download batches -------------------------------------------------
batch_files <- character(length(batches))
for (i in seq_along(batches)) {
  s <- batches[[i]][1]; e <- batches[[i]][2]
  out_file <- file.path(batch_dir, sprintf("batch_%s_%s.csv", s, e))
  batch_files[i] <- out_file

  if (file.exists(out_file) && file.info(out_file)$size > 1000) {
    cat(sprintf("[%2d/%d] %s -> %s  (cached, %s rows)\n",
                i, length(batches), s, e,
                format(nrow(read_csv(out_file, show_col_types = FALSE)),
                       big.mark = ",")))
    next
  }

  url <- api_url(s, e)
  cat(sprintf("[%2d/%d] %s -> %s  ... ", i, length(batches), s, e))
  download.file(url, destfile = out_file, quiet = TRUE, mode = "wb")
  n <- nrow(read_csv(out_file, show_col_types = FALSE))
  cat(sprintf("done (%s rows)\n", format(n, big.mark = ",")))
  Sys.sleep(0.6)
}

# ---- Concatenate, dedupe, sort ----------------------------------------
cat("\nConcatenating ", length(batch_files), " batches...\n", sep = "")
all <- bind_rows(lapply(batch_files, read_csv, show_col_types = FALSE))

# Dedupe across batch boundaries (USGS endpoints are inclusive on
# both sides — adjacent batches can share the boundary millisecond).
n_pre  <- nrow(all)
all    <- all %>% arrange(time) %>% distinct(id, .keep_all = TRUE)
n_dups <- n_pre - nrow(all)
if (n_dups > 0) cat("  removed ", n_dups, " duplicate event ids\n", sep = "")

raw_file <- file.path(raw_dir, "usgs_quakes_1980_2025_m5.csv")
write_csv(all, raw_file)
cat("\nRaw concatenated saved: ", raw_file,
    "  (", format(nrow(all), big.mark = ","), " rows, ",
    format(file.info(raw_file)$size / 1e6, digits = 3), " MB)\n", sep = "")

# ---- Tidy + gzip ------------------------------------------------------
tidy <- all %>%
  filter(!is.na(latitude), !is.na(longitude), !is.na(mag)) %>%
  select(id, time, latitude, longitude, depth, mag, magType, place) %>%
  arrange(time)

tidy_file <- file.path(out_dir, "quakes.csv")
# Uncompressed CSV. Earlier versions wrote .csv.gz, but Observable Framework's
# dev server and GitHub Pages neither set Content-Encoding: gzip on .gz
# files — the browser would receive raw gzipped bytes and d3.csv() would
# fail to parse. Uncompressed at ~7 MB is well within any sensible budget,
# loads once, and gets cached by the browser.
write_csv(tidy, tidy_file)
cat("Tidy CSV saved: ", tidy_file,
    "  (", format(nrow(tidy), big.mark = ","), " rows, ",
    format(file.info(tidy_file)$size / 1e6, digits = 3), " MB)\n", sep = "")

# ---- Verification stats (PLAN.md verification step 1) -----------------
cat("\n========== Verification ==========\n")
cat("Row count            : ", format(nrow(tidy), big.mark = ","), "\n", sep = "")
yr_min <- min(year(ymd_hms(tidy$time)))
yr_max <- max(year(ymd_hms(tidy$time)))
cat("Year range           : ", yr_min, " – ", yr_max, "\n", sep = "")
cat("Magnitude min        : ", round(min(tidy$mag, na.rm = TRUE), 2), "\n", sep = "")
cat("Magnitude max        : ", round(max(tidy$mag, na.rm = TRUE), 2), "\n", sep = "")
cat("Magnitude median     : ", round(median(tidy$mag, na.rm = TRUE), 2), "\n", sep = "")
cat("\nmagType counts (top 10):\n")
print(sort(table(tidy$magType), decreasing = TRUE)[1:10])
