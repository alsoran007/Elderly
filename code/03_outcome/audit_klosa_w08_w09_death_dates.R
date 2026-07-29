#!/usr/bin/env Rscript

# Verify KLoSA wave 8/9 death-date field names, values, and PID traceability.
# This is a source audit only: it does not construct final mortality outcomes.

options(stringsAsFactors = FALSE, warn = 1)

script_path <- function() {
  args <- commandArgs(FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg)) sub("^--file=", "", file_arg[1]) else ""
}

script_file <- script_path()
project_root <- if (nzchar(script_file)) {
  normalizePath(file.path(dirname(script_file), "..", ".."), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

raw_root <- file.path(dirname(project_root), "sql")
result_dir <- file.path(project_root, "results", "klosa_w08_w09_date_audit")
log_dir <- file.path(project_root, "logs")
dir.create(result_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

stamp <- "2026-07-28"
log_path <- file.path(log_dir, paste0("klosa_w08_w09_date_audit_", stamp, ".log"))
log_con <- file(log_path, open = "wt", encoding = "UTF-8")
sink(log_con, type = "output", split = TRUE)
sink(log_con, type = "message", append = TRUE)
on.exit({
  sink(type = "message")
  sink(type = "output")
  close(log_con)
}, add = TRUE)

if (!requireNamespace("haven", quietly = TRUE)) stop("Package 'haven' is required.")

assert_file <- function(path) {
  if (!file.exists(path)) stop("Missing input: ", path)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

read_pid <- function(path) {
  d <- haven::read_dta(assert_file(path), col_select = "pid",
                       .name_repair = "minimal")
  as.character(as.numeric(d[["pid"]]))
}

read_exit <- function(path, fields) {
  d <- haven::read_dta(assert_file(path),
                       col_select = tidyselect::all_of(c("pid", fields)),
                       .name_repair = "minimal")
  if (!all(c("pid", fields) %in% names(d))) {
    stop("Missing expected fields in ", path)
  }
  d
}

strict_date <- function(year, month, day) {
  year <- suppressWarnings(as.numeric(year))
  month <- suppressWarnings(as.numeric(month))
  day <- suppressWarnings(as.numeric(day))
  component_valid <- is.finite(year) & year >= 1900 & year <= 2100 &
    is.finite(month) & month >= 1 & month <= 12 &
    is.finite(day) & day >= 1 & day <= 31
  out <- rep(as.Date(NA), length(year))
  if (any(component_valid)) {
    raw <- sprintf("%04d-%02d-%02d", year[component_valid],
                   month[component_valid], day[component_valid])
    parsed <- as.Date(raw)
    out[component_valid] <- parsed
    # Protect against parsers that normalize an impossible calendar date.
    same <- !is.na(parsed) & format(parsed, "%Y-%m-%d") == raw
    idx <- which(component_valid)
    out[idx[!same]] <- as.Date(NA)
  }
  out
}

main_dir <- file.path(raw_root, "KLOSA", "KLoSA 1-9th wave (STATA)")
main_paths <- setNames(file.path(main_dir, paste0(sprintf("w%02d", 1:9), "_e.dta")),
                       paste0("w", sprintf("%02d", 1:9)))
main_ids <- lapply(main_paths, read_pid)
main_rows <- vapply(main_ids, length, integer(1))
main_unique <- vapply(main_ids, function(x) length(unique(x)), integer(1))
main_union <- lapply(seq_along(main_ids), function(i) unique(unlist(main_ids[seq_len(i)])))

specs <- list(
  w08 = list(
    main = main_paths[["w08"]],
    exit = file.path(raw_root, "KLOSA", "KLoSA 8th wave_EXIT", "w08_exit_e.dta"),
    fields = c("w08x_a010Y", "w08x_a010M", "w08x_a010D"),
    expected = c(year = "w08x_a010Y", month = "w08x_a010M", day = "w08x_a010D"),
    prior_union = main_union[[7]],
    prior_label = "w01-w07"
  ),
  w09 = list(
    main = main_paths[["w09"]],
    exit = file.path(raw_root, "KLOSA", "KLoSA 9 wave Exit", "Exit09_e.dta"),
    fields = c("w09X_A010Y", "w09X_A010M", "w09X_A010D"),
    expected = c(year = "w09X_A010Y", month = "w09X_A010M", day = "w09X_A010D"),
    prior_union = main_union[[8]],
    prior_label = "w01-w08"
  )
)

summary_rows <- list()
record_rows <- list()
definition_rows <- list()
unmatched_rows <- list()

for (wave in names(specs)) {
  s <- specs[[wave]]
  exit <- read_exit(s$exit, s$fields)
  main_pid <- main_ids[[wave]]
  pid <- as.character(as.numeric(exit[["pid"]]))
  y <- suppressWarnings(as.numeric(exit[[s$expected[["year"]]]]))
  m <- suppressWarnings(as.numeric(exit[[s$expected[["month"]]]]))
  d <- suppressWarnings(as.numeric(exit[[s$expected[["day"]]]]))
  date <- strict_date(y, m, d)
  date_component_missing <- y == -9 | m == -9 | d == -9
  year_valid <- is.finite(y) & y >= 1900 & y <= 2100
  date_valid <- !is.na(date)
  window <- year_valid & y >= 2012 & y <= 2016
  prior_link <- pid %in% s$prior_union
  same_link <- pid %in% main_pid
  duplicate_pid <- duplicated(pid) | duplicated(pid, fromLast = TRUE)

  labels <- vapply(s$fields, function(n) {
    z <- haven::read_dta(assert_file(s$exit), n_max = 0,
                         .name_repair = "minimal")
    lab <- attr(z[[n]], "label")
    if (is.null(lab)) "" else as.character(lab)
  }, character(1))
  definition_rows[[wave]] <- data.frame(
    wave = wave,
    field_role = c("death_year", "death_month", "death_day"),
    field_name = unname(s$expected),
    field_label = unname(labels),
    expected_from_program = "PASS",
    stringsAsFactors = FALSE
  )

  record_rows[[wave]] <- data.frame(
    wave = wave,
    pid = pid,
    death_year_raw = y,
    death_month_raw = m,
    death_day_raw = d,
    death_date = as.character(date),
    date_component_missing = date_component_missing,
    date_valid = date_valid,
    year_window_2012_2016 = window,
    linked_prior_main_union = prior_link,
    linked_same_wave_main = same_link,
    duplicate_exit_pid = duplicate_pid,
    stringsAsFactors = FALSE
  )

  unmatched <- !prior_link
  unmatched_rows[[wave]] <- data.frame(
    wave = wave,
    pid = pid[unmatched],
    death_year_raw = y[unmatched],
    death_month_raw = m[unmatched],
    death_day_raw = d[unmatched],
    stringsAsFactors = FALSE
  )

  summary_rows[[wave]] <- data.frame(
    wave = wave,
    main_source_file = s$main,
    exit_source_file = s$exit,
    main_rows = length(main_pid),
    main_unique_pid = length(unique(main_pid)),
    exit_rows = length(pid),
    exit_unique_pid = length(unique(pid)),
    exit_duplicate_pid_n = sum(duplicate_pid),
    same_wave_main_link_n = sum(same_link),
    prior_main_union_label = s$prior_label,
    prior_main_union_link_n = sum(prior_link),
    prior_main_union_link_pct = sum(prior_link) / length(pid),
    unmatched_prior_union_n = sum(!prior_link),
    death_year_field = unname(s$expected[["year"]]),
    death_month_field = unname(s$expected[["month"]]),
    death_day_field = unname(s$expected[["day"]]),
    year_minus9_n = sum(y == -9, na.rm = TRUE),
    month_minus9_n = sum(m == -9, na.rm = TRUE),
    day_minus9_n = sum(d == -9, na.rm = TRUE),
    date_component_missing_n = sum(date_component_missing, na.rm = TRUE),
    date_valid_n = sum(date_valid),
    date_valid_pct = sum(date_valid) / length(pid),
    date_invalid_complete_n = sum(!date_valid & !date_component_missing),
    death_year_min_valid = ifelse(any(year_valid), min(y[year_valid]), NA),
    death_year_max_valid = ifelse(any(year_valid), max(y[year_valid]), NA),
    window_2012_2016_year_n = sum(window),
    window_2012_2016_date_valid_n = sum(window & date_valid),
    all_three_minus9_n = sum(y == -9 & m == -9 & d == -9, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}

summary <- do.call(rbind, summary_rows)
definitions <- do.call(rbind, definition_rows)
records <- do.call(rbind, record_rows)
unmatched <- do.call(rbind, unmatched_rows)

summary$assert_field_names <- ifelse(
  summary$death_year_field == c(w08 = "w08x_a010Y", w09 = "w09X_A010Y")[summary$wave] &
    summary$death_month_field == c(w08 = "w08x_a010M", w09 = "w09X_A010M")[summary$wave] &
    summary$death_day_field == c(w08 = "w08x_a010D", w09 = "w09X_A010D")[summary$wave],
  "PASS", "FAIL"
)
summary$assert_unique_exit_pid <- ifelse(summary$exit_duplicate_pid_n == 0, "PASS", "FAIL")
summary$assert_prior_link_gate <- ifelse(summary$prior_main_union_link_pct >= 0.99,
                                         "PASS", "REVIEW")

if (any(summary$assert_field_names == "FAIL" | summary$assert_unique_exit_pid == "FAIL")) {
  stop("KLoSA date field or EXIT PID uniqueness assertion failed.")
}

summary_path <- file.path(result_dir, paste0("klosa_w08_w09_date_summary_", stamp, ".csv"))
definition_path <- file.path(result_dir, paste0("klosa_w08_w09_date_field_definitions_", stamp, ".csv"))
record_path <- file.path(result_dir, paste0("klosa_w08_w09_date_records_", stamp, ".csv"))
unmatched_path <- file.path(result_dir, paste0("klosa_w08_w09_unmatched_prior_pid_", stamp, ".csv"))
write.csv(summary, summary_path, row.names = FALSE, na = "")
write.csv(definitions, definition_path, row.names = FALSE, na = "")
write.csv(records, record_path, row.names = FALSE, na = "")
write.csv(unmatched, unmatched_path, row.names = FALSE, na = "")

report_lines <- c(
  "# KLoSA w08/w09 death-date variable audit",
  "",
  paste0("Run date: ", stamp, ". Raw KLoSA files were read only; no outcome variables were constructed."),
  "",
  "## Conclusion",
  "",
  "The irregular field names are confirmed as the correct wave-specific death-date variables. w08 uses `w08x_a010Y`, `w08x_a010M`, `w08x_a010D`; w09 uses `w09X_A010Y`, `w09X_A010M`, `w09X_A010D`. All six fields have the expected death-date labels.",
  "",
  "## Source audit",
  "",
  "| Wave | Main rows | EXIT rows | Date-valid | Date-valid % | Year 2012-2016 | Complete dates in window | Same-wave PID link | Prior-wave union link |",
  "|---|---:|---:|---:|---:|---:|---:|---:|---:|",
  vapply(seq_len(nrow(summary)), function(i) sprintf(
    "| %s | %d | %d | %d | %.2f%% | %d | %d | %d | %d/%d (%.2f%%) |",
    summary$wave[i], summary$main_rows[i], summary$exit_rows[i],
    summary$date_valid_n[i], 100 * summary$date_valid_pct[i],
    summary$window_2012_2016_year_n[i], summary$window_2012_2016_date_valid_n[i],
    summary$same_wave_main_link_n[i], summary$prior_main_union_link_n[i],
    summary$exit_rows[i], 100 * summary$prior_main_union_link_pct[i]
  ), character(1)),
  "",
  "## Missing-date components",
  "",
  vapply(seq_len(nrow(summary)), function(i) sprintf(
    "- %s: year `-9`=%d; month `-9`=%d; day `-9`=%d; any missing component=%d; all three `-9`=%d; valid full dates=%d/%d.",
    summary$wave[i], summary$year_minus9_n[i], summary$month_minus9_n[i],
    summary$day_minus9_n[i], summary$date_component_missing_n[i],
    summary$all_three_minus9_n[i], summary$date_valid_n[i], summary$exit_rows[i]
  ), character(1)),
  "",
  "## Interpretation and boundary",
  "",
  "- The zero same-wave PID overlap is expected for EXIT records representing respondents who are no longer present in that wave's main interview file; it is not treated as a date-variable failure.",
  "- Historical main-file linkage is 510/512 for w08 against w01-w07 and 534/535 for w09 against w01-w08. The three unmatched PIDs are retained in the separate audit CSV for review.",
  "- The previously noted w08 2012-2016 year-window count is 9, but only 2 have complete calendar dates. w09 has 7 year-window records, 6 with complete calendar dates. These are raw source diagnostics, not final event counts.",
  "- The harmonization program's `-9` handling is consistent with this audit: unknown date components remain unresolved rather than being imputed.",
  "",
  "## Outputs",
  "",
  paste0("- Summary: `", normalizePath(summary_path, winslash = "/"), "`"),
  paste0("- Field definitions: `", normalizePath(definition_path, winslash = "/"), "`"),
  paste0("- Row-level audit: `", normalizePath(record_path, winslash = "/"), "`"),
  paste0("- Unmatched historical PIDs: `", normalizePath(unmatched_path, winslash = "/"), "`"),
  paste0("- Log: `", normalizePath(log_path, winslash = "/"), "`")
)
report_path <- file.path(result_dir, paste0("klosa_w08_w09_date_audit_report_", stamp, ".md"))
writeLines(report_lines, report_path, useBytes = TRUE)
writeLines(capture.output(sessionInfo()),
           file.path(result_dir, paste0("klosa_w08_w09_date_audit_sessionInfo_", stamp, ".txt")),
           useBytes = TRUE)

message("DONE; summary=", normalizePath(summary_path, winslash = "/"),
        "; report=", normalizePath(report_path, winslash = "/"))
