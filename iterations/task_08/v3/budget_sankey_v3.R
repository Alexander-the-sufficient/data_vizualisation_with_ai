# Task 8 v3 — US Federal Budget Sankey, FY2025.
#
# Changes from v2:
#   * EVERY data value now read from the downloaded Treasury MTS Table 9
#     JSON. v2 hand-typed the source/use amounts into a tribble, which
#     violated the portfolio's "data comes from a downloaded file" rule.
#     v3 reads `data/task_08/mts_table_9_fy2025.json`, filters to the
#     correct rows by `sequence_number_cd`, aggregates the small
#     functions into "Other functions", and computes Borrowing as
#     (total outlays − total receipts). No numbers are typed by hand.
#   * Annotation text (callouts, column headers) remains in code — that
#     is editorial overlay, not data.
#
# Source: U.S. Department of the Treasury, Bureau of the Fiscal Service,
# Monthly Treasury Statement, FY2025 final (record date 2025-09-30),
# MTS Table 9, retrieved via the Fiscal Data API:
#   https://api.fiscaldata.treasury.gov/services/api/fiscal_service/
#     v1/accounting/mts/mts_table_9
# Local file: data/task_08/mts_table_9_fy2025.json.

setwd("/Users/alexanderweber/Documents/hsg/6_semester/data_visualization_with_ai")

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(ggalluvial)
  library(jsonlite)
})

source("design_system.R")

chart_family <- ""  # PDF-native fallback; see task_07 notes.

# ---- Read & parse the MTS Table 9 JSON --------------------------------
raw <- fromJSON("data/task_08/mts_table_9_fy2025.json")$data %>%
  as_tibble() %>%
  mutate(amount = suppressWarnings(as.numeric(current_fytd_rcpt_outly_amt)) / 1e9)

cat("Rows in MTS Table 9 JSON:", nrow(raw), "\n")

# Helper: pull the FYTD amount (in $B) for a given sequence_number_cd.
amt_at <- function(seq) {
  v <- raw$amount[raw$sequence_number_cd == seq]
  stopifnot(length(v) == 1)
  v
}

# ---- Aggregate receipts into six source buckets ------------------------
# Sequence numbers from MTS Table 9 metadata:
#   1.1 = Individual Income Taxes
#   1.2 = Corporation Income Taxes
#   1.3 = Social Insurance / Retirement (header; sum 1.3.1 + 1.3.2 + 1.3.3)
#   1.4 = Excise Taxes
#   1.5 = Estate and Gift Taxes
#   1.6 = Customs Duties
#   1.7 = Miscellaneous Receipts
#   1.8 = Total Receipts
#   2.20 = Total Outlays
total_receipts <- amt_at("1.8")
total_outlays  <- amt_at("2.20")
borrowing      <- total_outlays - total_receipts

sources <- tibble::tibble(
  source = c(
    "Individual income tax",
    "Payroll tax",
    "Corporate income tax",
    "Customs duties",
    "Other receipts",
    "Borrowing"
  ),
  amount = c(
    amt_at("1.1"),
    amt_at("1.3.1") + amt_at("1.3.2") + amt_at("1.3.3"),
    amt_at("1.2"),
    amt_at("1.6"),
    amt_at("1.4") + amt_at("1.5") + amt_at("1.7"),
    borrowing
  )
)

# ---- Aggregate outlays into nine spending functions --------------------
# Big eight named explicitly; the remaining eleven small functions
# (2.2-2.10, 2.16, 2.17, 2.19) collapse into "Other functions" so the
# Sankey stays legible.
named_uses <- c(
  "Social Security"          = "2.14",
  "Medicare"                 = "2.12",
  "Health (incl. Medicaid)"  = "2.11",
  "Net Interest"             = "2.18",
  "National Defense"         = "2.1",
  "Income Security"          = "2.13",
  "Veterans benefits"        = "2.15",
  "Transportation"           = "2.8"
)
named_amounts <- vapply(named_uses, amt_at, numeric(1))

other_functions <- total_outlays - sum(named_amounts)

uses <- tibble::tibble(
  use    = c(names(named_uses), "Other functions"),
  amount = c(named_amounts,     other_functions)
)

# ---- Sanity checks (all derived from the file, not hand-typed) ---------
cat(sprintf("Total receipts: $%.2f B\n", total_receipts))
cat(sprintf("Total outlays:  $%.2f B\n", total_outlays))
cat(sprintf("Implied borrowing: $%.2f B\n", borrowing))
stopifnot(abs(sum(sources$amount) - total_outlays) < 0.01)
stopifnot(abs(sum(uses$amount)    - total_outlays) < 0.01)

# ---- Build flow table (proportional split, money is fungible) ---------
flows <- tidyr::expand_grid(
    source = sources$source,
    use    = uses$use
  ) %>%
  left_join(sources, by = "source") %>%
  rename(src_amt = amount) %>%
  left_join(uses, by = "use") %>%
  rename(use_amt = amount) %>%
  mutate(flow = src_amt * use_amt / total_outlays)

src_check <- flows %>% group_by(source) %>% summarise(s = sum(flow), .groups = "drop") %>%
  left_join(sources, by = "source") %>% mutate(diff = s - amount)
use_check <- flows %>% group_by(use) %>% summarise(s = sum(flow), .groups = "drop") %>%
  left_join(uses, by = "use") %>% mutate(diff = s - amount)
stopifnot(all(abs(src_check$diff) < 0.01))
stopifnot(all(abs(use_check$diff) < 0.01))

# ---- Order strata so the largest sits at the TOP -----------------------
src_levels_top_first <- c(
  "Individual income tax", "Payroll tax", "Corporate income tax",
  "Customs duties", "Other receipts", "Borrowing"
)
use_levels_top_first <- c(
  "Social Security", "Medicare", "Health (incl. Medicaid)",
  "Net Interest", "National Defense", "Income Security",
  "Veterans benefits", "Transportation", "Other functions"
)
flows <- flows %>%
  mutate(
    source = factor(source, levels = src_levels_top_first),
    use    = factor(use,    levels = use_levels_top_first)
  )

# ---- Color scheme (story-driven) ---------------------------------------
flows <- flows %>%
  mutate(storyflow = factor(case_when(
    source == "Borrowing"     ~ "Borrowing",
    use    == "Net Interest"  ~ "Net Interest",
    TRUE                      ~ "Other"
  ), levels = c("Other", "Net Interest", "Borrowing")))

flows <- flows %>% arrange(storyflow)

flow_colors <- c(
  "Other"        = pg_palette$dark_quartz,
  "Net Interest" = pg_palette$heritage_red,
  "Borrowing"    = pg_palette$heritage_red
)

stratum_fill <- setNames(
  rep(pg_palette$onyx,
      length(src_levels_top_first) + length(use_levels_top_first)),
  c(src_levels_top_first, use_levels_top_first)
)
stratum_fill["Borrowing"]    <- pg_palette$heritage_red
stratum_fill["Net Interest"] <- pg_palette$heritage_red

# ---- Helpers -----------------------------------------------------------
fmt_b <- function(x) {
  ifelse(x >= 1000,
         sprintf("$%.2f T", x / 1000),
         sprintf("$%d B", round(x)))
}

# ---- Base plot ---------------------------------------------------------
stratum_w <- 1/4

p_base <- ggplot(flows,
                 aes(axis1 = source, axis2 = use, y = flow)) +
  geom_alluvium(aes(fill = storyflow),
                width = stratum_w, alpha = 0.75,
                knot.pos = 0.4, curve_type = "sigmoid") +
  geom_stratum(width = stratum_w,
               aes(fill = after_stat(stratum)),
               color = NA) +
  scale_fill_manual(values = c(flow_colors, stratum_fill),
                    guide = "none") +
  scale_x_continuous(limits = c(-0.6, 3.6), expand = c(0, 0)) +
  scale_y_continuous(expand = expansion(mult = c(0.02, 0.07))) +
  coord_cartesian(clip = "off") +
  labs(x = NULL, y = NULL) +
  theme_void(base_family = chart_family) +
  theme(plot.margin = margin(t = 14, r = 14, b = 8, l = 14))

gb <- ggplot_build(p_base)
strat_layer_idx <- which(sapply(gb$plot$layers,
                                function(l) inherits(l$stat, "StatStratum")))[1]
strat_data <- gb$data[[strat_layer_idx]] %>%
  mutate(y_mid = (ymin + ymax) / 2)

src_pos <- strat_data %>% filter(x == 1)
use_pos <- strat_data %>% filter(x == 2)

src_labels <- src_pos %>%
  transmute(
    x  = 1 - stratum_w / 2 - 0.02,
    y  = y_mid,
    label = paste0(stratum, "   ", fmt_b(count))
  )
use_labels <- use_pos %>%
  transmute(
    x  = 2 + stratum_w / 2 + 0.02,
    y  = y_mid,
    label = paste0(fmt_b(count), "   ", stratum)
  )

borrowing_y    <- src_pos$y_mid[src_pos$stratum == "Borrowing"]
net_interest_y <- use_pos$y_mid[use_pos$stratum == "Net Interest"]

# ---- Final plot --------------------------------------------------------
p <- p_base +
  geom_text(data = src_labels, aes(x = x, y = y, label = label),
            family = chart_family, size = 3.0, color = pg_palette$alloy,
            hjust = 1, vjust = 0.5, inherit.aes = FALSE) +
  geom_text(data = use_labels, aes(x = x, y = y, label = label),
            family = chart_family, size = 3.0, color = pg_palette$alloy,
            hjust = 0, vjust = 0.5, inherit.aes = FALSE) +
  annotate("text", x = 1, y = total_outlays + 250,
           label = "WHERE IT CAME FROM",
           family = chart_family, size = 3.2, fontface = "bold",
           color = pg_palette$onyx, hjust = 0.5) +
  annotate("text", x = 2, y = total_outlays + 250,
           label = "WHERE IT WENT",
           family = chart_family, size = 3.2, fontface = "bold",
           color = pg_palette$onyx, hjust = 0.5) +
  annotate("text",
           x = 1 - stratum_w / 2 - 0.55,
           y = borrowing_y,
           label = "$1 of every $4 spent\nwas borrowed.",
           family = chart_family, size = 3.1,
           color = pg_palette$heritage_red,
           fontface = "bold",
           hjust = 1, vjust = 0.5,
           lineheight = 0.95) +
  annotate("text",
           x = 2 + stratum_w / 2 + 0.55,
           y = net_interest_y,
           label = "Net interest now exceeds\nthe defense budget.",
           family = chart_family, size = 3.1,
           color = pg_palette$heritage_red,
           fontface = "bold",
           hjust = 0, vjust = 0.5,
           lineheight = 0.95)

out_pdf <- "iterations/task_08/v3/budget_sankey_v3.pdf"
ggsave(out_pdf, p, width = 30, height = 17, units = "cm", device = "pdf")
cat("Saved:", out_pdf, "\n")
