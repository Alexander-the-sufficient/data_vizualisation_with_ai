# Task 13 — FRED data fetch helper.
#
# Reads the FRED API key from the project-root .env file (already gitignored)
# and downloads a FRED series as a tidy CSV into data/task_13/.
#
# Usage (from project root):
#   Rscript data/task_13/fetch_fred.R <SERIES_ID> [start_date] [end_date]
# Examples:
#   Rscript data/task_13/fetch_fred.R UNRATE
#   Rscript data/task_13/fetch_fred.R DGS10 1990-01-01 2026-05-01
#
# Series IDs are looked up at https://fred.stlouisfed.org — every dataset
# page shows its ID in the URL.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
  library(readr)
})

readRenviron(".env")
api_key <- Sys.getenv("FRED_API_KEY")
if (!nzchar(api_key)) {
  stop("FRED_API_KEY is empty. Paste your key into the project-root .env file.")
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Usage: Rscript data/task_13/fetch_fred.R <SERIES_ID> [start_date] [end_date]")
}
series_id  <- args[1]
start_date <- if (length(args) >= 2) args[2] else "1900-01-01"
end_date   <- if (length(args) >= 3) args[3] else format(Sys.Date(), "%Y-%m-%d")

url <- "https://api.stlouisfed.org/fred/series/observations"
resp <- GET(url, query = list(
  series_id              = series_id,
  api_key                = api_key,
  file_type              = "json",
  observation_start      = start_date,
  observation_end        = end_date
))
stop_for_status(resp)

payload <- fromJSON(content(resp, "text", encoding = "UTF-8"),
                    simplifyDataFrame = TRUE)
obs <- payload$observations

if (is.null(obs) || nrow(obs) == 0) {
  stop("FRED returned no observations for series '", series_id, "'.")
}

tidy <- data.frame(
  date  = as.Date(obs$date),
  value = suppressWarnings(as.numeric(obs$value))
)
tidy <- tidy[!is.na(tidy$value), ]

out_csv <- sprintf("data/task_13/%s.csv", series_id)
write_csv(tidy, out_csv)

cat("Saved:", out_csv, "\n")
cat("Rows: ",  nrow(tidy), "\n")
cat("Range:",  as.character(min(tidy$date)), "to", as.character(max(tidy$date)), "\n")
