# Project3 Phase 1: build a cohort registry and mortality-field crosswalk.
# The candidate record table contains exit/EOL cases only; it is not the final
# analysis cohort and must still be linked to baseline and censoring data.

options(stringsAsFactors = FALSE, warn = 1)

project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
raw_root <- normalizePath(file.path(project_root, "..", "sql"), winslash = "/", mustWork = TRUE)
out_root <- file.path(project_root, "results", "data_audit")
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

if (!requireNamespace("haven", quietly = TRUE)) stop("Package 'haven' is required.")

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || is.na(x[1]) || !nzchar(as.character(x[1]))) y else as.character(x[1])
}

read_data <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (ext == "dta") return(haven::read_dta(path, .name_repair = "minimal"))
  if (ext == "sav") return(haven::read_sav(path, .name_repair = "minimal"))
  stop("Unsupported file type: ", ext)
}

as_id <- function(x) {
  if (is.character(x)) return(trimws(x))
  y <- suppressWarnings(as.numeric(x))
  out <- format(y, scientific = FALSE, trim = TRUE)
  out[is.na(y)] <- NA_character_
  out
}

as_valid_year <- function(x) {
  y <- suppressWarnings(as.numeric(x))
  y[!is.na(y) & (y < 1900 | y > 2100)] <- NA_real_
  y
}

as_valid_month <- function(x) {
  y <- suppressWarnings(as.numeric(x))
  y[!is.na(y) & (y < 1 | y > 12)] <- NA_real_
  y
}

as_valid_day <- function(x) {
  y <- suppressWarnings(as.numeric(x))
  y[!is.na(y) & (y < 1 | y > 31)] <- NA_real_
  y
}

get_var <- function(dat, var, fun) {
  if (is.null(var) || is.na(var) || !nzchar(var)) return(rep(NA_real_, nrow(dat)))
  if (!var %in% names(dat)) return(rep(NA_real_, nrow(dat)))
  fun(dat[[var]])
}

target <- function(cohort, source_file, id_var, year_var, month_var = NA_character_,
                   day_var = NA_character_, source_role = "exit_or_eol") {
  data.frame(
    cohort = cohort,
    source_file = source_file,
    id_var = id_var,
    year_var = year_var,
    month_var = month_var,
    day_var = day_var,
    source_role = source_role,
    stringsAsFactors = FALSE
  )
}

targets <- rbind(
  target("CHARLS", "Charls/2013/Exit_Interview.dta", "ID", "exb001_1", "exb001_2", NA_character_),
  target("CHARLS", "Charls/2020/Exit_Module.dta", "ID", "exb001_1", "exb001_2", "exb001_3"),
  target("KLoSA", "KLOSA/w03_exit_e.dta", "pid", "w03Xa010y", "w03Xa010m", "w03Xa010d"),
  target("KLoSA", "KLOSA/w04_exit_e.dta", "pid", "w04Xa010y", "w04Xa010m", "w04Xa010d"),
  target("KLoSA", "KLOSA/w05_exit_e.dta", "pid", "w05xA010Y", "w05xA010M", "w05xA010D"),
  target("KLoSA", "KLOSA/w06_Exit_e.dta", "pid", "w06x_A010Y", "w06x_A010M", "w06x_A010D"),
  target("KLoSA", "KLOSA/2018 KLoSA 7 wave EXIT/w07_exit_e.dta", "pid", "w07x_a010y", "w07x_a010m", "w07x_a010d"),
  target("KLoSA", "KLOSA/KLoSA 8th wave_EXIT/w08_exit_e.dta", "pid", "w08x_a010Y", "w08x_a010M", "w08x_a010D"),
  target("KLoSA", "KLOSA/KLoSA 9 wave Exit/Exit09_e.dta", "pid", "w09X_A010Y", "w09X_A010M", "w09X_A010D"),
  target("SHARE", "share harmonised/GH_SHARE_EOL_g.dta", "mergeid", "raxyear", "raxmonth", NA_character_, "end_of_life"),
  target("ELSA", "ELSA/stata/stata13_se/h_elsa_eol_a2.dta", "idauniq", "raxyear", NA_character_, NA_character_, "end_of_life"),
  target("MHAS", "MHAS/H_MHAS_EOL_b.dta", "rahhidnp", "raxyear", "raxmonth", NA_character_, "end_of_life")
)

make_records <- function(spec) {
  path <- file.path(raw_root, spec$source_file)
  if (!file.exists(path)) stop("Missing outcome source: ", path)
  dat <- read_data(path)
  n <- nrow(dat)
  year <- get_var(dat, spec$year_var, as_valid_year)
  month <- get_var(dat, spec$month_var, as_valid_month)
  day <- get_var(dat, spec$day_var, as_valid_day)
  id <- as_id(dat[[spec$id_var]])
  precision <- ifelse(!is.na(day) & !is.na(month) & !is.na(year), "day",
                      ifelse(!is.na(month) & !is.na(year), "month",
                             ifelse(!is.na(year), "year", "missing")))
  data.frame(
    cohort = spec$cohort,
    source_file = spec$source_file,
    source_role = spec$source_role,
    source_id_var = spec$id_var,
    person_id = id,
    death_year = as.integer(year),
    death_month = as.integer(month),
    death_day = as.integer(day),
    date_precision = precision,
    source_wave = NA_character_,
    event_candidate = 1L,
    stringsAsFactors = FALSE
  )
}

records <- do.call(rbind, lapply(seq_len(nrow(targets)), function(i) make_records(targets[i, , drop = FALSE])))
records <- records[!is.na(records$person_id) & nzchar(records$person_id), , drop = FALSE]

# CLHLS stores mortality status and validated death dates in the longitudinal
# file rather than in a separate EOL file. Keep one candidate row per death
# interval and preserve the interval/wave source for later linkage.
make_clhls_records <- function() {
  rel <- "CLHLS/CLHLS_dataset_2008-2018_SPSS/clhls_2011_2018_longitudinal_dataset_released_version1.sav"
  path <- file.path(raw_root, rel)
  if (!file.exists(path)) stop("Missing CLHLS longitudinal source: ", path)
  dat <- read_data(path)
  id <- as_id(dat$id)
  build_interval <- function(wave, year_var, month_var, day_var, status_var) {
    year <- get_var(dat, year_var, as_valid_year)
    month <- get_var(dat, month_var, as_valid_month)
    day <- get_var(dat, day_var, as_valid_day)
    status <- suppressWarnings(as.numeric(dat[[status_var]]))
    is_event <- status == 1 & !is.na(year)
    precision <- ifelse(!is.na(day) & !is.na(month) & !is.na(year), "day",
                        ifelse(!is.na(month) & !is.na(year), "month",
                               ifelse(!is.na(year), "year", "missing")))
    data.frame(
      cohort = "CLHLS",
      source_file = rel,
      source_role = "longitudinal_wave_status",
      source_id_var = "id",
      person_id = id,
      death_year = as.integer(ifelse(is_event, year, NA_real_)),
      death_month = as.integer(ifelse(is_event, month, NA_real_)),
      death_day = as.integer(ifelse(is_event, day, NA_real_)),
      date_precision = ifelse(is_event, precision, "not_death"),
      source_wave = wave,
      event_candidate = as.integer(is_event),
      stringsAsFactors = FALSE
    )
  }
  out <- rbind(
    build_interval("2011/2012_to_2014", "d14vyear", "d14vmonth", "d14vday", "dth11_14"),
    build_interval("2014_to_2018", "d18vyear", "d18vmonth", "d18vday", "dth14_18")
  )
  out[out$event_candidate == 1L & !is.na(out$person_id) & nzchar(out$person_id), , drop = FALSE]
}

clhls_records <- make_clhls_records()
records <- rbind(records, clhls_records)

summary <- do.call(rbind, lapply(split(records, records$cohort), function(d) {
  data.frame(
    cohort = d$cohort[1],
    source_files = length(unique(d$source_file)),
    candidate_rows = nrow(d),
    unique_person_ids = length(unique(d$person_id)),
    duplicate_person_id_rows = sum(duplicated(d$person_id)),
    year_present_n = sum(!is.na(d$death_year)),
    month_present_n = sum(!is.na(d$death_month)),
    day_present_n = sum(!is.na(d$death_day)),
    day_precision_n = sum(d$date_precision == "day"),
    month_precision_n = sum(d$date_precision == "month"),
    year_precision_n = sum(d$date_precision == "year"),
    missing_date_n = sum(d$date_precision == "missing"),
    min_year = ifelse(any(!is.na(d$death_year)), min(d$death_year, na.rm = TRUE), NA),
    max_year = ifelse(any(!is.na(d$death_year)), max(d$death_year, na.rm = TRUE), NA),
    stringsAsFactors = FALSE
  )
}))
rownames(summary) <- NULL

registry <- data.frame(
  cohort = c("CHARLS", "CLHLS", "KLoSA", "SHARE", "HRS", "ELSA", "MHAS"),
  country = c("China", "China", "South Korea", "SHARE countries", "United States", "United Kingdom", "Mexico"),
  analysis_role = c("Aim 1 development; Aim 2 source", "Aim 1 validation; Aim 2 source", "Aim 2 LOCO target/source", "Aim 3 external validation", "Aim 3 external validation", "Aim 3 external validation", "Aim 3 external validation"),
  planned_baseline = c("2011 wave 1", "2011 recommended", "2012 wave 4 recommended", "2011 wave 4 recommended", "2012 recommended", "2012 wave 6 recommended", "2012 recommended"),
  planned_outcome_window = c("5 years; 8-year sensitivity", "5 years; 8-year sensitivity", "5 years", "5 years", "5 years; 8-year sensitivity", "5 years", "5 years"),
  person_id_status = c("ID confirmed in exit files", "id confirmed in 2011-2018 longitudinal file", "pid confirmed", "mergeid confirmed", "hhidpn confirmed in H_HRS_d", "idauniq confirmed", "rahhidnp confirmed"),
  mortality_source_status = c("Exit files found; 2015/2018 Sample_Infor linkage pending", "dth11_14/dth14_18 and validated death dates confirmed in 2011-2018 longitudinal file", "w03-w09 exit files found; w01-w02 mortality linkage pending", "EOL file found", "H_HRS_d has no radyear/radmonth in metadata probe; tracker/RAND mortality source unresolved", "h_elsa_eol_a2 is Version A.2 (2004-2013); use h_elsa_g3 iwstat/interview dates for post-2012 follow-up", "EOL file found"),
  current_gate = c("Outcome linkage", "Outcome linkage", "Outcome linkage", "Baseline linkage", "Mortality source confirmation", "Wave-status outcome linkage", "Baseline linkage"),
  stringsAsFactors = FALSE
)

crosswalk <- rbind(
  data.frame(cohort = "CHARLS", source_file = "Charls/2013/Exit_Interview.dta", person_id = "ID", death_year = "exb001_1", death_month = "exb001_2", death_day = NA, date_precision = "month", event_rule = "Rows are exit interview cases; confirm against Sample_Infor and wave linkage", notes = "2013 exit has year/month only", stringsAsFactors = FALSE),
  data.frame(cohort = "CHARLS", source_file = "Charls/2020/Exit_Module.dta", person_id = "ID", death_year = "exb001_1", death_month = "exb001_2", death_day = "exb001_3", date_precision = "day", event_rule = "Rows are exit module cases; confirm against Sample_Infor and wave linkage", notes = "2020 exit has year/month/day", stringsAsFactors = FALSE),
  data.frame(cohort = rep("KLoSA", 7), source_file = c("w03_exit_e.dta", "w04_exit_e.dta", "w05_exit_e.dta", "w06_Exit_e.dta", "w07_exit_e.dta", "w08_exit_e.dta", "Exit09_e.dta"), person_id = rep("pid", 7), death_year = c("w03Xa010y", "w04Xa010y", "w05xA010Y", "w06x_A010Y", "w07x_a010y", "w08x_a010Y", "w09X_A010Y"), death_month = c("w03Xa010m", "w04Xa010m", "w05xA010M", "w06x_A010M", "w07x_a010m", "w08x_a010M", "w09X_A010M"), death_day = c("w03Xa010d", "w04Xa010d", "w05xA010D", "w06x_A010D", "w07x_a010d", "w08x_a010D", "w09X_A010D"), date_precision = rep("day", 7), event_rule = "Rows are wave-specific exit cases; deduplicate by pid after wave linkage", notes = "w09 is available; w01/w02 exit files not identified", stringsAsFactors = FALSE),
  data.frame(cohort = c("SHARE", "CLHLS", "ELSA", "ELSA", "HRS", "MHAS"), source_file = c("GH_SHARE_EOL_g.dta", "clhls_2011_2018_longitudinal_dataset_released_version1.sav", "h_elsa_eol_a2.dta", "h_elsa_g3.dta", "H_HRS_d.dta", "H_MHAS_EOL_b.dta"), person_id = c("mergeid", "id", "idauniq", "idauniq", "hhidpn", "rahhidnp"), death_year = c("raxyear", "d14vyear/d18vyear", "raxyear", "r6-r9iwindy", NA, "raxyear"), death_month = c("raxmonth", "d14vmonth/d18vmonth", NA, "r6-r9iwindm", NA, "raxmonth"), death_day = rep(NA, 6), date_precision = c("month", "wave-status/date", "year", "wave-status/year-month", "unresolved", "month"), event_rule = c("EOL record is a mortality candidate; confirm linkage to baseline person-level file", "Use dth11_14/dth14_18 == 1; retain -9 as lost to follow-up and use validated date fields when present", "Historical EOL record; not sufficient alone for 2012 baseline 5-year follow-up", "For baseline wave 6, evaluate r7-r9 iwstat; codes 5/6 indicate death in/current or previous wave; confirm codebook and dates", "H_HRS_d metadata probe did not identify a death date/status field; do not construct outcome yet", "EOL record is a mortality candidate; confirm linkage to baseline person-level file"), notes = c("Year/month precision; no day field in probed EOL file", "Baseline 2011/2012; d14/d18 validated death dates available", "Version A.2 covers 2004-2013", "Wave status fields are available; exact death date still requires source-specific documentation", "Need HRS tracker or approved mortality product", "Year/month precision; no day field in probed EOL file"), stringsAsFactors = FALSE)
)

write.csv(registry, file.path(out_root, "cohort_registry.csv"), row.names = FALSE, na = "")
write.csv(crosswalk, file.path(out_root, "outcome_crosswalk.csv"), row.names = FALSE, na = "")
write.csv(records, file.path(out_root, "outcome_candidate_records.csv"), row.names = FALSE, na = "")
write.csv(summary, file.path(out_root, "outcome_candidate_summary.csv"), row.names = FALSE, na = "")

summary_lines <- c(
  "# Project3 Outcome Registry",
  "",
  "This registry is a Phase 1 data-layer artifact. The candidate records are exit/EOL/longitudinal mortality candidates only and are not the final analysis cohort or final 5-year outcome.",
  "",
  paste0("- Candidate records exported: ", nrow(records)),
  paste0("- Cohorts represented in candidate records: ", paste(sort(unique(records$cohort)), collapse = ", ")),
  paste0("- Candidate records with day-level dates: ", sum(records$date_precision == "day")),
  paste0("- Candidate records with month-level dates: ", sum(records$date_precision == "month")),
  paste0("- Candidate records with year-level dates: ", sum(records$date_precision == "year")),
  paste0("- Candidate records with missing/invalid dates: ", sum(records$date_precision == "missing")),
  "",
  "## Required next linkage gate",
  "",
  "1. Link each candidate record to the appropriate baseline person-level file using the confirmed person ID.",
  "2. Obtain last-known-alive/interview dates and administrative censoring dates for non-events.",
  "3. Resolve CHARLS 2015/2018 mortality status, confirm CLHLS interval/status coding against the codebook, resolve KLoSA w01/w02 mortality coverage, and confirm HRS mortality fields.",
  "4. Pre-specify handling of month/year-only death dates; do not silently impute a day in the primary outcome.",
  "5. Only after this gate construct the analysis-ready 5-year outcome and calculate event counts.",
  "",
  "## Output files",
  "",
  "- `cohort_registry.csv`: planned role, baseline, identifier status, and current data gate.",
  "- `outcome_crosswalk.csv`: source-specific ID and death-date fields.",
  "- `outcome_candidate_records.csv`: derived exit/EOL mortality candidates with date precision.",
  "- `outcome_candidate_summary.csv`: source-level counts and date completeness."
)
writeLines(summary_lines, file.path(out_root, "outcome_registry_summary.md"), useBytes = TRUE)
writeLines(capture.output(sessionInfo()), file.path(out_root, "03_build_outcome_registry_sessionInfo.txt"), useBytes = TRUE)

message("Outcome registry completed. Outputs: ", normalizePath(out_root, winslash = "/"))
