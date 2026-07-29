# CLHLS 2011-2018 longitudinal extraction: Step 1 only.
# The source SAV file is read-only. This script selects only the fields
# required by the Step 1-4 outcome probe and writes a local parquet cache.

options(stringsAsFactors = FALSE, warn = 1)

project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
raw_path <- file.path(
  dirname(project_root), "sql", "CLHLS", "CLHLS_dataset_2008-2018_SPSS",
  "clhls_2011_2018_longitudinal_dataset_released_version1.sav"
)
interim_dir <- file.path(project_root, "data", "interim")
log_dir <- file.path(project_root, "logs")
log_path <- file.path(log_dir, "clhls_step1_4_2026-07-27.log")
raw_cache_path <- file.path(interim_dir, "clhls_2011_selected_raw_2026-07-27.parquet")

dir.create(interim_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

log_lines <- character()
log_msg <- function(level, message) {
  line <- sprintf("[%s] %s %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), level, message)
  log_lines <<- c(log_lines, line)
  message(line)
}
flush_log <- function() writeLines(log_lines, log_path, useBytes = TRUE)
fail <- function(message) {
  log_msg("FAIL", message)
  flush_log()
  stop(message, call. = FALSE)
}
assert_equal <- function(actual, expected, label) {
  ok <- isTRUE(all.equal(actual, expected, check.attributes = FALSE))
  if (ok) log_msg("PASS", label)
  else fail(sprintf("%s | expected=%s | actual=%s", label,
                    paste(expected, collapse = ","), paste(actual, collapse = ",")))
}

if (!file.exists(raw_path)) fail(paste("Missing input:", raw_path))
if (!requireNamespace("haven", quietly = TRUE)) fail("Package haven is required")
if (!requireNamespace("arrow", quietly = TRUE)) fail("Package arrow is required")

selected_names <- c(
  "id", "a1", "yearin", "monthin", "dayin", "trueage", "dth11_14",
  "yearin_14", "monthin_14", "dayin_14", "dth14_18",
  "yearin_18", "monthin_18", "dayin_18"
)

log_msg("INFO", paste("Reading read-only SAV:", raw_path))
dat <- tryCatch(
  haven::read_sav(
    raw_path,
    col_select = tidyselect::all_of(selected_names),
    .name_repair = "minimal"
  ),
  error = function(e) fail(paste("haven::read_sav failed:", conditionMessage(e)))
)

assert_equal(nrow(dat), 9765L, "Step 1 N == 9765")
assert_equal(sort(names(dat)), sort(selected_names), "Selected field set matches contract")
dat <- dat[, selected_names]

count_code <- function(x, code) sum(!is.na(x) & as.numeric(x) == code)
assert_equal(
  c(`-9` = count_code(dat$dth11_14, -9), `0` = count_code(dat$dth11_14, 0),
    `1` = count_code(dat$dth11_14, 1), missing = sum(is.na(dat$dth11_14))),
  c(`-9` = 820L, `0` = 6066L, `1` = 2879L, missing = 0L),
  "dth11_14 code counts"
)
assert_equal(
  c(`-9` = count_code(dat$dth14_18, -9), `0` = count_code(dat$dth14_18, 0),
    `1` = count_code(dat$dth14_18, 1), missing = sum(is.na(dat$dth14_18))),
  c(`-9` = 1345L, `0` = 2884L, `1` = 1837L, missing = 3699L),
  "dth14_18 code counts"
)
assert_equal(
  c(`2011` = sum(!is.na(dat$yearin) & dat$yearin == 2011),
    `2012` = sum(!is.na(dat$yearin) & dat$yearin == 2012)),
  c(`2011` = 7328L, `2012` = 2437L),
  "Baseline yearin counts"
)
assert_equal(
  count_code(dat$dth14_18, 0) + count_code(dat$dth14_18, 1) + count_code(dat$dth14_18, -9),
  6066L,
  "Non-missing dth14_18 counts sum to dth11_14 survivors"
)

raw_numeric <- as.data.frame(lapply(dat, function(x) as.numeric(x)), check.names = FALSE)
arrow::write_parquet(raw_numeric, raw_cache_path, compression = "snappy")
log_msg("PASS", paste("Wrote selected raw parquet:", normalizePath(raw_cache_path, winslash = "/")))
log_msg("INFO", "Step 1 extraction complete; Step 2-4 will be run by clhls_interval_probe.R")
flush_log()
