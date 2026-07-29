# Project3 Phase 1: process HRS Exit A_R mortality-source records.
# Raw data under D:/AI_project/sql are read only. This script does not create
# the final event, censoring date, or model-ready five-year outcome.

options(stringsAsFactors = FALSE, warn = 1)

project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
raw_root <- normalizePath(file.path(project_root, "..", "sql"), winslash = "/", mustWork = TRUE)
out_root <- file.path(project_root, "results", "data_audit")
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

if (!requireNamespace("haven", quietly = TRUE)) stop("Package 'haven' is required.")
if (!requireNamespace("tidyselect", quietly = TRUE)) stop("Package 'tidyselect' is required.")

log_path <- file.path(out_root, "07_process_hrs_exit.log")
log_con <- file(log_path, open = "wt", encoding = "UTF-8")
sink(log_con, type = "output", split = TRUE)
sink(log_con, type = "message", append = TRUE)
on.exit({
  sink(type = "message")
  sink(type = "output")
  close(log_con)
}, add = TRUE)

read_dta <- function(rel_path, columns = NULL) {
  path <- file.path(raw_root, rel_path)
  if (!file.exists(path)) stop("Missing raw file: ", path)
  if (is.null(columns)) {
    haven::read_dta(path, .name_repair = "minimal")
  } else {
    haven::read_dta(path, col_select = tidyselect::any_of(columns), .name_repair = "minimal")
  }
}

as_num <- function(x) {
  if (is.factor(x)) x <- as.character(x)
  suppressWarnings(as.numeric(trimws(as.character(x))))
}

valid_year <- function(x) {
  y <- as_num(x)
  y[!is.na(y) & (y < 1900 | y > 2100)] <- NA_real_
  as.integer(y)
}

valid_month <- function(x) {
  m <- as_num(x)
  m[!is.na(m) & (m < 1 | m > 12)] <- NA_real_
  as.integer(m)
}

raw_special_count <- function(x, value) sum(as_num(x) == value, na.rm = TRUE)

pad_id <- function(x, width) {
  y <- trimws(as.character(x))
  y[y == ""] <- NA_character_
  out <- vapply(y, function(z) {
    if (is.na(z) || nchar(z) > width) return(NA_character_)
    paste0(strrep("0", width - nchar(z)), z)
  }, character(1))
  out
}

make_hhidpn <- function(hhid, pn) {
  h <- pad_id(hhid, 6)
  p <- pad_id(pn, 3)
  out <- ifelse(is.na(h) | is.na(p), NA_character_, paste0(h, p))
  out[!is.na(out) & !grepl("^[0-9]{9}$", out)] <- NA_character_
  out
}

assert_unique <- function(x, label) {
  valid <- !is.na(x) & nzchar(x)
  if (anyDuplicated(x[valid])) stop("Duplicate IDs in ", label)
}

write_csv <- function(x, name) {
  utils::write.csv(x, file.path(out_root, name), row.names = FALSE, na = "")
}

date_status <- function(death_year_raw, death_month_raw) {
  y <- as_num(death_year_raw)
  m <- as_num(death_month_raw)
  known_y <- !is.na(y) & y >= 1900 & y <= 2100
  known_m <- !is.na(m) & m >= 1 & m <= 12
  raw_present <- !is.na(y) | !is.na(m)
  out <- rep("missing", length(y))
  out[raw_present & !known_y & !known_m] <- "unknown_special_or_invalid"
  out[raw_present & known_y & !known_m] <- "year_only"
  out[raw_present & known_y & known_m] <- "month_year"
  out[raw_present & !known_y & known_m] <- "month_only_invalid_year"
  out
}

parse_fixed_a_r <- function(rel_path, wave, prefix, interview_pos, death_pos, expected_width) {
  path <- file.path(raw_root, rel_path)
  if (!file.exists(path)) stop("Missing raw fixed-width file: ", path)
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  line_width <- nchar(lines)
  if (length(lines) == 0L || any(line_width != expected_width)) {
    stop("Unexpected fixed-width layout for ", rel_path,
         "; expected ", expected_width, " characters per row")
  }
  field <- function(start, end) trimws(substr(lines, start, end))
  hhid <- field(1, 6)
  pn <- field(7, 9)
  interview_month_raw <- field(interview_pos[1], interview_pos[2])
  interview_year_raw <- field(interview_pos[3], interview_pos[4])
  death_month_raw <- field(death_pos[1], death_pos[2])
  death_year_raw <- field(death_pos[3], death_pos[4])
  data.frame(
    cohort = "HRS", wave = as.integer(wave), source_role = "HRS Exit A_R",
    hhid = hhid, pn = pn, hhidpn = make_hhidpn(hhid, pn),
    interview_year = valid_year(interview_year_raw),
    interview_month = valid_month(interview_month_raw),
    death_year = valid_year(death_year_raw),
    death_month = valid_month(death_month_raw),
    death_year_raw = as_num(death_year_raw),
    death_month_raw = as_num(death_month_raw),
    exit_record = 1L,
    date_status = date_status(death_year_raw, death_month_raw),
    date_precision = ifelse(date_status(death_year_raw, death_month_raw) == "month_year", "month",
                            ifelse(date_status(death_year_raw, death_month_raw) == "year_only", "year", NA_character_)),
    source_file = rel_path,
    stringsAsFactors = FALSE
  )
}

parse_dta_a_r <- function(rel_path, wave, prefix) {
  cols <- c("HHID", "PN", paste0(prefix, c("500", "501", "121", "123")))
  d <- read_dta(rel_path, cols)
  required <- cols[cols %in% names(d)]
  if (!all(cols %in% names(d))) stop("Missing expected HRS fields in ", rel_path,
                                    ": ", paste(setdiff(cols, required), collapse = ", "))
  death_month_raw <- as_num(d[[paste0(prefix, "121")]])
  death_year_raw <- as_num(d[[paste0(prefix, "123")]])
  status <- date_status(death_year_raw, death_month_raw)
  data.frame(
    cohort = "HRS", wave = as.integer(wave), source_role = "HRS Exit A_R",
    hhid = trimws(as.character(d$HHID)), pn = trimws(as.character(d$PN)),
    hhidpn = make_hhidpn(d$HHID, d$PN),
    interview_year = valid_year(d[[paste0(prefix, "501")]]),
    interview_month = valid_month(d[[paste0(prefix, "500")]]),
    death_year = valid_year(death_year_raw),
    death_month = valid_month(death_month_raw),
    death_year_raw = death_year_raw, death_month_raw = death_month_raw,
    exit_record = 1L, date_status = status,
    date_precision = ifelse(status == "month_year", "month",
                            ifelse(status == "year_only", "year", NA_character_)),
    source_file = rel_path,
    stringsAsFactors = FALSE
  )
}

specs <- data.frame(
  wave = c(2012L, 2014L, 2016L, 2018L, 2020L),
  rel_path = c(
    "HRS Products/HRS Exit/2012/x12da/X12A_R.da",
    "HRS Products/HRS Exit/2014/x14da/X14A_R.da",
    "HRS Products/HRS Exit/2016/x16da/X16A_R.da",
    "HRS Products/HRS Exit/2018/x18sta/X18A_R.dta",
    "HRS Products/HRS Exit/2020/x20sta/X20A_R.dta"
  ),
  stringsAsFactors = FALSE
)

hrs_list <- list(
  parse_fixed_a_r(specs$rel_path[1], 2012L, "XA", c(15L, 16L, 17L, 20L), c(27L, 28L, 29L, 32L), 183L),
  parse_fixed_a_r(specs$rel_path[2], 2014L, "YA", c(15L, 16L, 17L, 20L), c(39L, 40L, 41L, 44L), 198L),
  parse_fixed_a_r(specs$rel_path[3], 2016L, "ZA", c(15L, 16L, 17L, 20L), c(39L, 40L, 41L, 44L), 197L),
  parse_dta_a_r(specs$rel_path[4], 2018L, "XQA"),
  parse_dta_a_r(specs$rel_path[5], 2020L, "XRA")
)
hrs_exit <- do.call(rbind, hrs_list)
assert_unique(hrs_exit$hhidpn, "HRS Exit A_R pooled records")

# The RAND fat-file ID is numeric in hhidpn but character in hhid and pn.
# Use the character components as the reference key to preserve leading zeros.
rand2012_rel <- "HRS Products/RAND HRS Products(原始)/2012 RAND HRS Fat File/h12f3a.dta"
rand2012 <- read_dta(rand2012_rel, c("hhid", "pn", "hhidpn"))
rand2012_id <- make_hhidpn(rand2012$hhid, rand2012$pn)
assert_unique(rand2012_id, "HRS 2012 RAND fat-file IDs")
hrs_exit$in_rand2012_baseline <- as.integer(hrs_exit$hhidpn %in% rand2012_id)

wave_summary <- do.call(rbind, lapply(seq_len(nrow(specs)), function(i) {
  x <- hrs_exit[hrs_exit$wave == specs$wave[i], , drop = FALSE]
  data.frame(
    cohort = "HRS", wave = specs$wave[i], source_file = specs$rel_path[i],
    source_rows = nrow(x), source_unique_ids = length(unique(x$hhidpn)),
    rand2012_baseline_overlap_n = sum(x$in_rand2012_baseline == 1L, na.rm = TRUE),
    exit_record_n = sum(x$exit_record == 1L, na.rm = TRUE),
    death_date_month_year_n = sum(x$date_status == "month_year"),
    death_date_year_only_n = sum(x$date_status == "year_only"),
    death_date_unknown_or_invalid_n = sum(x$date_status == "unknown_special_or_invalid"),
    death_date_month_only_invalid_year_n = sum(x$date_status == "month_only_invalid_year"),
    death_date_unresolved_n = sum(x$date_status %in% c("unknown_special_or_invalid", "month_only_invalid_year")),
    death_date_missing_n = sum(x$date_status == "missing"),
    interview_date_complete_n = sum(!is.na(x$interview_year) & !is.na(x$interview_month)),
    death_month_98_n = sum(x$death_month_raw == 98, na.rm = TRUE),
    death_year_9998_n = sum(x$death_year_raw == 9998, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))

audit <- data.frame(
  cohort = "HRS", source_role = "HRS Exit A_R pooled",
  rel_path = paste(specs$rel_path, collapse = " | "), exists = TRUE,
  read_status = "ok", rows = nrow(hrs_exit), columns = ncol(hrs_exit),
  candidate_field_n = 4L,
  candidate_fields = "death_month/death_year; interview_month/interview_year",
  notes = "A_R exit records parsed from fixed-width .da/.dct imports for 2012-2016 and Stata .dta for 2018/2020; month 98 and year 9998 retained as unresolved special values",
  stringsAsFactors = FALSE
)
write_csv(hrs_exit, "hrs_exit_mortality_records.csv")
write_csv(wave_summary, "hrs_mortality_source_summary.csv")
write_csv(audit, "hrs_mortality_source_audit.csv")

registry_path <- file.path(out_root, "cohort_registry.csv")
if (file.exists(registry_path)) {
  registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE, check.names = FALSE)
  registry$mortality_source_status[registry$cohort == "HRS"] <-
    "2012/2014/2016/2018/2020 HRS Exit A_R parsed; death date precision retained; unresolved special values flagged"
  registry$current_gate[registry$cohort == "HRS"] <- "Death-date and administrative censoring rule"
  write_csv(registry, "cohort_registry.csv")
}

crosswalk_path <- file.path(out_root, "outcome_crosswalk.csv")
if (file.exists(crosswalk_path)) {
  crosswalk <- utils::read.csv(crosswalk_path, stringsAsFactors = FALSE, check.names = FALSE)
  crosswalk$notes[crosswalk$cohort == "HRS"] <-
    "HRS Exit A_R 2012-2020 parsed and linked by HHID+PN; death month/year are source fields; month 98/year 9998 remain unresolved; no final event/censoring rule applied"
  write_csv(crosswalk, "outcome_crosswalk.csv")
}

notes <- c(
  "# Follow-up linkage and mortality-source gate",
  "",
  "This Phase 1 artifact links source fields and coverage only. It is not the final analysis-ready 5-year outcome.",
  "Raw data under D:/AI_project/sql were read only and were not modified.",
  "",
  "## CHARLS",
  "- CHARLS 2015/2018/2020 Sample_Infor linkage and 2020 Exit_Module date fields were processed by the preceding follow-up linkage stage.",
  "- Sample_Infor died status and later-wave absence remain distinct from a validated death date or final censoring date.",
  "",
  "## KLoSA",
  "- KLoSA w01/w02 main-file coverage was linked; the newly available w02 EXIT source contains 187 unique PID records and is linked by PID.",
  "- w02 EXIT dates are mortality-source candidates; wstat interpretation, date precedence, and administrative censoring remain to be confirmed.",
  "",
  "## HRS",
  paste0("- HRS Exit A_R source rows: ", nrow(hrs_exit), " across waves 2012/2014/2016/2018/2020."),
  paste0("- Wave-specific rows: ", paste0(wave_summary$wave, "=", wave_summary$source_rows, collapse = "; "), "."),
  paste0("- All parsed HRS Exit A_R IDs are unique; overlap with the 2012 RAND fat-file reference is ", paste0(wave_summary$rand2012_baseline_overlap_n, collapse = "/"), " by wave."),
  "- 2012/2014/2016 were parsed from the supplied fixed-width .da files using their matching .dct column positions; 2018/2020 were read from the supplied Stata A_R files.",
  "- Death year/month are retained as raw and cleaned fields. Month 98 and year 9998 are marked unresolved rather than converted to valid dates.",
  "- Exit A_R records are mortality-source candidates; a final event requires a valid death date and an approved administrative censoring rule.",
  "",
  "## Required next gate",
  "- Confirm CHARLS death-date and administrative censoring rules.",
  "- Confirm KLoSA death-date precedence, wstat interpretation, and administrative censoring rules.",
  "- Confirm HRS death-date precedence across Exit A_R waves and the approved administrative censoring date for each baseline.",
  "- Only then create final five-year event, time-at-risk, and censoring variables."
)
writeLines(notes, file.path(out_root, "followup_linkage_gate_report.md"), useBytes = TRUE)
writeLines(capture.output(sessionInfo()), file.path(out_root, "07_process_hrs_exit_sessionInfo.txt"), useBytes = TRUE)
message("HRS Exit processing completed. Outputs written to: ", normalizePath(out_root, winslash = "/"))
