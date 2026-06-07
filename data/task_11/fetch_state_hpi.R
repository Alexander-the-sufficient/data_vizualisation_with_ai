# Task 11 — fetch FHFA All-Transactions House Price Index (state-level)
# from FRED for all 50 states + DC, 2019-10-01 to today.
#
# Output: `data/task_11/us_state_hpi.csv` — long-format CSV with one
# row per (state, quarter), plus a wide computed summary CSV at
# `data/task_11/us_state_hpi_pct_change.csv` (start_value, end_value,
# pct_change) ready for the chart script.
#
# FRED series naming: `<STATE_CODE>STHPI` (e.g. CASTHPI = California HPI).
# Quarterly data, index value (2005Q1 = 100 for most series).

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
  library(dplyr)
  library(readr)
})

readRenviron(".env")
api_key <- Sys.getenv("FRED_API_KEY")
if (!nzchar(api_key)) stop("FRED_API_KEY missing in .env")

state_codes <- c(
  "AL","AK","AZ","AR","CA","CO","CT","DE","FL","GA",
  "HI","ID","IL","IN","IA","KS","KY","LA","ME","MD",
  "MA","MI","MN","MS","MO","MT","NE","NV","NH","NJ",
  "NM","NY","NC","ND","OH","OK","OR","PA","RI","SC",
  "SD","TN","TX","UT","VT","VA","WA","WV","WI","WY",
  "DC"
)

fetch_one <- function(state) {
  series_id <- paste0(state, "STHPI")
  resp <- GET(
    "https://api.stlouisfed.org/fred/series/observations",
    query = list(
      series_id         = series_id,
      api_key           = api_key,
      file_type         = "json",
      observation_start = "2019-10-01",
      observation_end   = format(Sys.Date(), "%Y-%m-%d")
    )
  )
  if (status_code(resp) != 200) {
    cat(sprintf("  [%s] HTTP %d -- skipping\n", state, status_code(resp)))
    return(NULL)
  }
  obs <- fromJSON(content(resp, "text", encoding = "UTF-8"),
                  simplifyDataFrame = TRUE)$observations
  if (is.null(obs) || nrow(obs) == 0) {
    cat(sprintf("  [%s] empty -- skipping\n", state))
    return(NULL)
  }
  data.frame(
    state = state,
    date  = as.Date(obs$date),
    value = suppressWarnings(as.numeric(obs$value))
  ) |> dplyr::filter(!is.na(value))
}

cat("Fetching", length(state_codes), "state HPI series...\n")
all_data <- bind_rows(lapply(state_codes, function(s) {
  cat(sprintf("  %s ", s))
  d <- fetch_one(s)
  if (!is.null(d)) cat(nrow(d), "rows\n")
  d
}))

out_long <- "data/task_11/us_state_hpi.csv"
write_csv(all_data, out_long)
cat("\nSaved long CSV:", out_long,
    " (rows:", nrow(all_data), ")\n")

# Compute % change from 2020-01-01 to latest available per state.
# (FHFA HPI is quarterly; 2020-01-01 = 2020 Q1.)
baseline_date <- as.Date("2020-01-01")
pct_change <- all_data |>
  group_by(state) |>
  summarise(
    start_date  = baseline_date,
    end_date    = max(date),
    start_value = value[date == baseline_date][1],
    end_value   = value[date == max(date)][1],
    .groups     = "drop"
  ) |>
  mutate(pct_change = (end_value / start_value - 1) * 100)

out_summary <- "data/task_11/us_state_hpi_pct_change.csv"
write_csv(pct_change, out_summary)
cat("Saved summary CSV:", out_summary,
    " (rows:", nrow(pct_change), ")\n\n")

cat("Top 5 by % change:\n")
print(pct_change |> arrange(desc(pct_change)) |> head(5))
cat("\nBottom 5 by % change:\n")
print(pct_change |> arrange(pct_change) |> head(5))
cat("\nMedian state % change:", round(median(pct_change$pct_change, na.rm = TRUE), 1), "%\n")
