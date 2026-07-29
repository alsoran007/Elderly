# Project3 Phase 1: link follow-up coverage and mortality-source evidence.
# Raw data are read only. This script does not create the final 5-year outcome.

options(stringsAsFactors = FALSE, warn = 1)

project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
raw_root <- normalizePath(file.path(project_root, "..", "sql"), winslash = "/", mustWork = TRUE)
out_root <- file.path(project_root, "results", "data_audit")
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

if (!requireNamespace("haven", quietly = TRUE)) stop("Package 'haven' is required.")
if (!requireNamespace("tidyselect", quietly = TRUE)) stop("Package 'tidyselect' is required.")

log_path <- file.path(out_root, "06_link_followup_sources.log")
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

as_id <- function(x) {
  if (is.character(x)) return(trimws(x))
  y <- suppressWarnings(as.numeric(x))
  out <- format(y, scientific = FALSE, trim = TRUE, nsmall = 0)
  out[is.na(y)] <- NA_character_
  out
}

as_year <- function(x) {
  y <- suppressWarnings(as.numeric(x))
  y[!is.na(y) & (y < 1900 | y > 2100)] <- NA_real_
  as.integer(y)
}

as_month <- function(x) {
  y <- suppressWarnings(as.numeric(x))
  y[!is.na(y) & (y < 1 | y > 12)] <- NA_real_
  as.integer(y)
}

as_day <- function(x) {
  y <- suppressWarnings(as.numeric(x))
  y[!is.na(y) & (y < 1 | y > 31)] <- NA_real_
  as.integer(y)
}

safe_col <- function(dat, name, fun = as.character) {
  if (!name %in% names(dat)) return(rep(NA, nrow(dat)))
  fun(dat[[name]])
}

assert_unique <- function(x, label) {
  valid <- !is.na(x) & nzchar(x)
  if (anyDuplicated(x[valid])) stop("Duplicate IDs in ", label)
}

write_csv <- function(x, name) {
  utils::write.csv(x, file.path(out_root, name), row.names = FALSE, na = "")
}

# CHARLS: 2011 IDs are 11 characters; later files use the 12-character
# form created by inserting zero before the final two ID characters.
base_raw <- read_dta("Charls/2011/demographic_background.dta", c("ID"))
charls_base <- data.frame(
  person_id = as_id(base_raw$ID),
  stringsAsFactors = FALSE
)
charls_base$person_id_12 <- ifelse(
  nchar(charls_base$person_id) == 11,
  paste0(substr(charls_base$person_id, 1, 9), "0", substr(charls_base$person_id, 10, 11)),
  charls_base$person_id
)
assert_unique(charls_base$person_id, "CHARLS 2011 raw IDs")
assert_unique(charls_base$person_id_12, "CHARLS 2011 normalized IDs")

charls_specs <- data.frame(
  wave = c(2015L, 2018L, 2020L),
  rel_path = c("Charls/2015/Sample_Infor.dta", "Charls/2018/Sample_Infor.dta", "Charls/2020/Sample_Infor.dta"),
  stringsAsFactors = FALSE
)

read_charls_sample <- function(wave, rel_path) {
  d <- read_dta(rel_path, c("ID", "crosssection", "died", "iyear", "imonth"))
  out <- data.frame(
    person_id_12 = as_id(d$ID),
    present_in_sample_info = 1L,
    crosssection = as.integer(d$crosssection),
    died = as.integer(d$died),
    interview_year = as_year(d$iyear),
    interview_month = as_month(d$imonth),
    stringsAsFactors = FALSE
  )
  assert_unique(out$person_id_12, paste0("CHARLS ", wave, " Sample_Infor"))
  out$wave <- as.integer(wave)
  out
}

charls_samples <- lapply(seq_len(nrow(charls_specs)), function(i) {
  read_charls_sample(charls_specs$wave[i], charls_specs$rel_path[i])
})
names(charls_samples) <- as.character(charls_specs$wave)

charls_link <- charls_base[, c("person_id", "person_id_12")]
for (wave in charls_specs$wave) {
  x <- charls_samples[[as.character(wave)]]
  old <- c("present_in_sample_info", "crosssection", "died", "interview_year", "interview_month")
  names(x)[match(old, names(x))] <- paste0(old, "_", wave)
  charls_link <- merge(charls_link, x, by = "person_id_12", all.x = TRUE, sort = FALSE)
  charls_link[[paste0("sample_status_", wave)]] <- ifelse(
    is.na(charls_link[[paste0("present_in_sample_info_", wave)]]),
    "not_observed_in_sample_info",
    ifelse(charls_link[[paste0("died_", wave)]] == 1, "death_recorded",
           ifelse(charls_link[[paste0("died_", wave)]] == 0,
                  "alive_at_sample_info_interview", "status_unresolved"))
  )
}

# These are candidates for noncoverage or loss to follow-up only. They are
# not death events and are not final censoring dates.
charls_link$noncoverage_candidate_after_2015 <- as.integer(
  !is.na(charls_link$present_in_sample_info_2015) & is.na(charls_link$present_in_sample_info_2018)
)
charls_link$noncoverage_candidate_after_2018 <- as.integer(
  !is.na(charls_link$present_in_sample_info_2018) & is.na(charls_link$present_in_sample_info_2020)
)

exit2020 <- read_dta("Charls/2020/Exit_Module.dta", c("ID", "exb001_1", "exb001_2", "exb001_3"))
exit2020 <- data.frame(
  person_id_12 = as_id(exit2020$ID),
  exit_2020_record = 1L,
  exit_2020_death_year = as_year(exit2020$exb001_1),
  exit_2020_death_month = as_month(exit2020$exb001_2),
  exit_2020_death_day = as_day(exit2020$exb001_3),
  stringsAsFactors = FALSE
)
assert_unique(exit2020$person_id_12, "CHARLS 2020 Exit_Module")
charls_link <- merge(charls_link, exit2020, by = "person_id_12", all.x = TRUE, sort = FALSE)
charls_link$exit_2020_date_precision <- ifelse(
  !is.na(charls_link$exit_2020_death_day), "day",
  ifelse(!is.na(charls_link$exit_2020_death_month), "month",
         ifelse(!is.na(charls_link$exit_2020_death_year), "year", "missing"))
)
charls_link$death_status_without_exit_date <- as.integer(
  (charls_link$died_2015 == 1 | charls_link$died_2018 == 1 | charls_link$died_2020 == 1) &
    is.na(charls_link$exit_2020_record)
)

charls_wave_summary <- do.call(rbind, lapply(seq_len(nrow(charls_specs)), function(i) {
  wave <- charls_specs$wave[i]
  x <- charls_samples[[as.character(wave)]]
  data.frame(
    cohort = "CHARLS", wave = wave, source_file = charls_specs$rel_path[i],
    source_rows = nrow(x), source_unique_ids = length(unique(x$person_id_12)),
    baseline_2011_overlap = sum(charls_base$person_id_12 %in% x$person_id_12),
    died_1_n = sum(x$died == 1, na.rm = TRUE),
    died_0_n = sum(x$died == 0, na.rm = TRUE),
    interview_date_complete_n = sum(!is.na(x$interview_year) & !is.na(x$interview_month)),
    crosssection_1_n = sum(x$crosssection == 1, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))

charls_transition <- data.frame(
  transition = c("2011_to_2015", "2015_to_2018", "2018_to_2020"),
  denominator_n = c(
    nrow(charls_link),
    sum(charls_link$present_in_sample_info_2015 == 1, na.rm = TRUE),
    sum(charls_link$present_in_sample_info_2018 == 1, na.rm = TRUE)
  ),
  next_wave_observed_n = c(
    sum(!is.na(charls_link$present_in_sample_info_2015)),
    sum(!is.na(charls_link$present_in_sample_info_2018[charls_link$present_in_sample_info_2015 == 1])),
    sum(!is.na(charls_link$present_in_sample_info_2020[charls_link$present_in_sample_info_2018 == 1]))
  ),
  death_recorded_in_next_wave_n = c(
    sum(charls_link$died_2015 == 1, na.rm = TRUE),
    sum(charls_link$died_2018 == 1 & charls_link$present_in_sample_info_2015 == 1, na.rm = TRUE),
    sum(charls_link$died_2020 == 1 & charls_link$present_in_sample_info_2018 == 1, na.rm = TRUE)
  ),
  noncoverage_candidate_n = c(
    sum(is.na(charls_link$present_in_sample_info_2015)),
    sum(charls_link$noncoverage_candidate_after_2015 == 1, na.rm = TRUE),
    sum(charls_link$noncoverage_candidate_after_2018 == 1, na.rm = TRUE)
  ),
  stringsAsFactors = FALSE
)

write_csv(charls_link, "charls_sample_info_linkage.csv")
write_csv(charls_wave_summary, "charls_sample_info_wave_summary.csv")
write_csv(charls_transition, "charls_sample_info_transition_summary.csv")

# KLoSA: w01/w02 coverage and w02/w03 EXIT linkage. The newly downloaded
# w02_exit_e.dta is linked separately from the w02 main-file coverage.
klosa_specs <- data.frame(
  wave = 1:9,
  rel_path = c(
    "KLOSA/KLoSA 1-9th wave (STATA)/w01_e.dta",
    "KLOSA/KLoSA 1-9th wave (STATA)/w02_e.dta",
    "KLOSA/KLoSA 1-9th wave (STATA)/w03_e.dta",
    "KLOSA/KLoSA 1-9th wave (STATA)/w04_e.dta",
    "KLOSA/KLoSA 1-9th wave (STATA)/w05_e.dta",
    "KLOSA/KLoSA 1-9th wave (STATA)/w06_e.dta",
    "KLOSA/KLoSA 1-9th wave (STATA)/w07_e.dta",
    "KLOSA/KLoSA 1-9th wave (STATA)/w08_e.dta",
    "KLOSA/KLoSA 1-9th wave (STATA)/w09_e.dta"
  ),
  stringsAsFactors = FALSE
)

read_klosa_main <- function(wave, rel_path) {
  prefix <- sprintf("w%02d", wave)
  wanted <- c("pid", "hhid", paste0(prefix, "mniw_y"), paste0(prefix, "mniw_m"), paste0(prefix, "mniw_d"))
  d <- read_dta(rel_path, wanted)
  out <- data.frame(
    pid = as_id(d$pid),
    hhid = as_id(safe_col(d, "hhid")),
    interview_year = as_year(safe_col(d, paste0(prefix, "mniw_y"))),
    interview_month = as_month(safe_col(d, paste0(prefix, "mniw_m"))),
    interview_day = as_day(safe_col(d, paste0(prefix, "mniw_d"))),
    observed_in_main_wave = 1L, wave = wave, source_file = rel_path,
    stringsAsFactors = FALSE
  )
  out <- out[!is.na(out$pid) & nzchar(out$pid), , drop = FALSE]
  assert_unique(out$pid, paste0("KLoSA w", sprintf("%02d", wave), " main file"))
  out
}

klosa_main <- lapply(seq_len(nrow(klosa_specs)), function(i) {
  read_klosa_main(klosa_specs$wave[i], klosa_specs$rel_path[i])
})

make_klosa_wide <- function(x, wave) {
  prefix <- paste0("w", sprintf("%02d", wave))
  y <- x[, c("pid", "observed_in_main_wave", "interview_year", "interview_month", "interview_day")]
  names(y)[-1] <- paste0(prefix, c("_observed", "_interview_year", "_interview_month", "_interview_day"))
  y
}

klosa_w01w02 <- merge(make_klosa_wide(klosa_main[[1]], 1), make_klosa_wide(klosa_main[[2]], 2),
                      by = "pid", all = TRUE, sort = FALSE)
klosa_w01w02$w01_w02_status <- ifelse(
  !is.na(klosa_w01w02$w02_observed),
  "observed_in_w02_main_file",
  "not_observed_in_w02_main_file_pending_exit_link"
)
klosa_w01w02$w02_nonresponse_candidate <- as.integer(
  !is.na(klosa_w01w02$w01_observed) & is.na(klosa_w01w02$w02_observed)
)

exit_specs <- data.frame(
  wave = c(2L, 3L, 4L, 5L, 6L, 7L, 8L, 9L),
  rel_path = c(
    "KLOSA/w02_exit_e.dta", "KLOSA/w03_exit_e.dta", "KLOSA/w04_exit_e.dta", "KLOSA/w05_exit_e.dta",
    "KLOSA/w06_Exit_e.dta", "KLOSA/2018 KLoSA 7 wave EXIT/w07_exit_e.dta",
    "KLOSA/KLoSA 8th wave_EXIT/w08_exit_e.dta", "KLOSA/KLoSA 9 wave Exit/Exit09_e.dta"
  ),
  year_var = c("w02Xa010y", "w03Xa010y", "w04Xa010y", "w05xA010Y", "w06x_A010Y", "w07x_a010y", "w08x_a010Y", "w09X_A010Y"),
  month_var = c("w02Xa010m", "w03Xa010m", "w04Xa010m", "w05xA010M", "w06x_A010M", "w07x_a010m", "w08x_A010M", "w09X_A010M"),
  day_var = c("w02Xa010d", "w03Xa010d", "w04Xa010d", "w05xA010D", "w06x_A010D", "w07x_a010d", "w08x_A010D", "w09X_A010D"),
  stringsAsFactors = FALSE
)

read_klosa_exit <- function(i) {
  d <- read_dta(exit_specs$rel_path[i], c("pid", "hhid", exit_specs$year_var[i],
                                           exit_specs$month_var[i], exit_specs$day_var[i]))
  out <- data.frame(
    pid = as_id(d$pid), exit_record = 1L,
    death_year = as_year(safe_col(d, exit_specs$year_var[i])),
    death_month = as_month(safe_col(d, exit_specs$month_var[i])),
    death_day = as_day(safe_col(d, exit_specs$day_var[i])),
    exit_wave = exit_specs$wave[i], exit_source_file = exit_specs$rel_path[i],
    stringsAsFactors = FALSE
  )
  out <- out[!is.na(out$pid) & nzchar(out$pid), , drop = FALSE]
  assert_unique(out$pid, paste0("KLoSA w", exit_specs$wave[i], " EXIT"))
  out
}

klosa_w02_exit <- read_klosa_exit(1)
names(klosa_w02_exit)[match(c("exit_record", "death_year", "death_month", "death_day", "exit_wave", "exit_source_file"), names(klosa_w02_exit))] <-
  c("w02_exit_record", "w02_death_year", "w02_death_month", "w02_death_day", "w02_exit_wave", "w02_exit_source_file")
klosa_w01w02 <- merge(klosa_w01w02, klosa_w02_exit, by = "pid", all.x = TRUE, sort = FALSE)
klosa_w01w02$w02_exit_date_precision <- ifelse(
  !is.na(klosa_w01w02$w02_death_day), "day",
  ifelse(!is.na(klosa_w01w02$w02_death_month), "month",
         ifelse(!is.na(klosa_w01w02$w02_death_year), "year", "missing"))
)
klosa_w01w02$w02_exit_death_candidate <- as.integer(!is.na(klosa_w01w02$w02_exit_record))
klosa_w01w02$w01_w02_status <- ifelse(
  !is.na(klosa_w01w02$w02_observed),
  "observed_in_w02_main_file",
  ifelse(klosa_w01w02$w02_exit_death_candidate == 1L,
         "w02_exit_death_record",
         "not_observed_in_w02_main_file_no_w02_exit_record")
)

klosa_w03_exit <- read_klosa_exit(2)
klosa_w01w02 <- merge(klosa_w01w02, klosa_w03_exit, by = "pid", all.x = TRUE, sort = FALSE)
klosa_w01w02$w03_exit_date_precision <- ifelse(
  !is.na(klosa_w01w02$death_day), "day",
  ifelse(!is.na(klosa_w01w02$death_month), "month",
         ifelse(!is.na(klosa_w01w02$death_year), "year", "missing"))
)

klosa_wave_summary <- do.call(rbind, lapply(seq_len(nrow(klosa_specs)), function(i) {
  x <- klosa_main[[i]]
  data.frame(
    cohort = "KLoSA", wave = klosa_specs$wave[i], source_file = klosa_specs$rel_path[i],
    source_rows = nrow(x), source_unique_pids = length(unique(x$pid)),
    interview_date_complete_n = sum(!is.na(x$interview_year) & !is.na(x$interview_month)),
    stringsAsFactors = FALSE
  )
}))

klosa_source_audit <- data.frame(
  cohort = "KLoSA",
  source_role = c("w01_main", "w02_main", "w02_exit", "w03_exit", "harmonization_script"),
  rel_path = c(
    klosa_specs$rel_path[1], klosa_specs$rel_path[2], exit_specs$rel_path[1],
    exit_specs$rel_path[2], "KLOSA/bukpmcwp.do"
  ),
  exists = file.exists(file.path(raw_root, c(
    klosa_specs$rel_path[1], klosa_specs$rel_path[2], exit_specs$rel_path[1],
    exit_specs$rel_path[2], "KLOSA/bukpmcwp.do"
  ))),
  read_status = c("ok", "ok", "ok", "ok", "text_inspected"),
  rows = c(nrow(klosa_main[[1]]), nrow(klosa_main[[2]]), nrow(klosa_w02_exit), nrow(klosa_w03_exit), NA_integer_),
  unique_pid = c(length(unique(klosa_main[[1]]$pid)), length(unique(klosa_main[[2]]$pid)),
                 length(unique(klosa_w02_exit$pid)), length(unique(klosa_w03_exit$pid)), NA_integer_),
  notes = c(
    "w01 main file establishes respondent coverage and interview date.",
    "w02 main file establishes respondent coverage and interview date only.",
    "w02 EXIT file supplies death date fields and is linked by pid; this is a mortality-source candidate, not a final event.",
    "Available mortality-date source; linkable by pid.",
    "wstat: 1 alive, 4 nonresponse alive, 5 died this wave, 6 died previous wave, 7 dropped, 9 unknown."
  ),
  stringsAsFactors = FALSE
)

klosa_wstat <- data.frame(
  code = c(0L, 1L, 4L, 5L, 6L, 7L, 9L),
  label = c("inapplicable", "respondent alive", "nonresponse alive", "nonresponse died this wave",
            "nonresponse died previous wave", "dropped from sample", "unknown alive/dead"),
  interpretation = c("not in wave", "observed respondent", "not interviewed but alive",
                     "mortality event", "mortality event assigned to prior wave",
                     "not a mortality event", "not a mortality event until resolved"),
  stringsAsFactors = FALSE
)

write_csv(klosa_wave_summary, "klosa_main_wave_coverage_summary.csv")
write_csv(klosa_w01w02, "klosa_w01_w02_followup_linkage.csv")
write_csv(klosa_source_audit, "klosa_followup_source_audit.csv")
write_csv(klosa_wstat, "klosa_wstat_codebook.csv")

# HRS: probe expected mortality/status fields. The documentation page 4
# lists a separate Cross-Wave 2020 Tracker product; it is absent locally.
hrs_pattern <- "iwstat|iwindy|radyear|radmonth|raddate|death.*date|date.*death|mortality|vital.*status|died|exit"

inspect_hrs <- function(rel_path, role) {
  path <- file.path(raw_root, rel_path)
  if (!file.exists(path)) {
    return(data.frame(cohort = "HRS", source_role = role, rel_path = rel_path, exists = FALSE,
                      read_status = "missing", rows = NA_integer_, columns = NA_integer_,
                      candidate_field_n = NA_integer_, candidate_fields = "",
                      notes = "File not available locally.", stringsAsFactors = FALSE))
  }
  d <- tryCatch(haven::read_dta(path, col_select = tidyselect::matches(paste0("hhidpn|", hrs_pattern), ignore.case = TRUE),
                                .name_repair = "minimal"), error = function(e) e)
  if (inherits(d, "error")) {
    return(data.frame(cohort = "HRS", source_role = role, rel_path = rel_path, exists = TRUE,
                      read_status = "error", rows = NA_integer_, columns = NA_integer_,
                      candidate_field_n = NA_integer_, candidate_fields = "",
                      notes = conditionMessage(d), stringsAsFactors = FALSE))
  }
  candidates <- names(d)[grepl(hrs_pattern, names(d), ignore.case = TRUE)]
  data.frame(cohort = "HRS", source_role = role, rel_path = rel_path, exists = TRUE,
             read_status = "ok", rows = nrow(d), columns = ncol(d),
             candidate_field_n = length(candidates), candidate_fields = paste(candidates, collapse = ";"),
             notes = ifelse(length(candidates) == 0, "No expected mortality/status field matched.",
                            "Candidates require codebook confirmation."),
             stringsAsFactors = FALSE)
}

hrs_audit <- rbind(
  inspect_hrs("HRS Products/harmonised HRS/H_HRS_d.dta", "harmonized_HRS_D"),
  inspect_hrs("HRS Products/RAND HRS Products(原始)/2012 RAND HRS Fat File/h12f3a.dta", "RAND_2012_fat_file"),
  inspect_hrs("HRS Products/RAND HRS Products(原始)/2020 RAND HRS Fat File/h20f1a.dta", "RAND_2020_fat_file"),
  data.frame(cohort = "HRS", source_role = "tracker_or_mortality_product",
             rel_path = "HRS Products/**/Tracker or mortality product", exists = FALSE,
             read_status = "not_found_in_local_inventory", rows = NA_integer_, columns = NA_integer_,
             candidate_field_n = NA_integer_, candidate_fields = "",
             notes = "Harmonized HRS D PDF page 4 lists Cross-Wave 2020 Tracker File v.e.3.0; no local Tracker/mortality file found.",
             stringsAsFactors = FALSE)
)
hrs_summary <- data.frame(
  item = c("local_harmonized_death_status", "local_tracker_or_mortality_source", "primary_analysis_readiness"),
  status = c("not_confirmed", "not_found", "blocked_pending_approved_source"),
  evidence = c(
    "Targeted probe did not identify iwstat, iwindy, radyear, radmonth, raddate, or explicit death-date/status fields.",
    "Local inventory contains Harmonized HRS D and RAND 2012/2020 fat files but no Tracker or mortality product.",
    "Do not construct HRS 5-year mortality outcome or use HRS external validation until an approved source is supplied."
  ),
  stringsAsFactors = FALSE
)
write_csv(hrs_audit, "hrs_mortality_source_audit.csv")
write_csv(hrs_summary, "hrs_mortality_source_summary.csv")

# Refresh the Phase 1 registry/crosswalk status without touching raw data.
registry_path <- file.path(out_root, "cohort_registry.csv")
if (file.exists(registry_path)) {
  registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE, check.names = FALSE)
  registry$mortality_source_status[registry$cohort == "CHARLS"] <-
    "2015/2018/2020 Sample_Infor linked by normalized ID; died status retained; 2020 Exit_Module dates linked; noncoverage candidates flagged"
  registry$current_gate[registry$cohort == "CHARLS"] <- "Date and censoring rule"
  registry$mortality_source_status[registry$cohort == "KLoSA"] <-
    "w01-w09 main coverage linked; w02/w03 EXIT sources linked by pid; date and wstat interpretation remain gated"
  registry$current_gate[registry$cohort == "KLoSA"] <- "Death-date and wstat rule"
  registry$mortality_source_status[registry$cohort == "HRS"] <-
    "Targeted H_HRS_d/RAND probes found no expected mortality fields; Tracker/mortality source not found locally"
  registry$current_gate[registry$cohort == "HRS"] <- "Mortality source confirmation"
  write_csv(registry, "cohort_registry.csv")
}

crosswalk_path <- file.path(out_root, "outcome_crosswalk.csv")
if (file.exists(crosswalk_path)) {
  crosswalk <- utils::read.csv(crosswalk_path, stringsAsFactors = FALSE, check.names = FALSE)
  crosswalk$notes[crosswalk$cohort == "CHARLS"] <-
    "Sample_Infor ID linkage completed; died is a status observation; 2020 Exit_Module supplies dates where linked; noncoverage is not death"
  crosswalk$notes[crosswalk$cohort == "KLoSA"] <-
    "w01/w02 main coverage and w02_exit_e.dta linked by pid; w03 EXIT linked as later mortality-date source; no final event/censoring rule applied"
  crosswalk$notes[crosswalk$cohort == "HRS"] <-
    "Local H_HRS_d/RAND probes found no expected mortality fields; approved Tracker or mortality source still required"
  write_csv(crosswalk, "outcome_crosswalk.csv")
}

charls_overlap <- charls_wave_summary$baseline_2011_overlap
klosa_overlap <- sum(!is.na(klosa_w01w02$w01_observed) & !is.na(klosa_w01w02$w02_observed))
notes <- c(
  "# Follow-up linkage and mortality-source gate",
  "",
  "This Phase 1 artifact links source fields and coverage only. It is not the final analysis-ready 5-year outcome.",
  "Raw data under D:/AI_project/sql were read only and were not modified.",
  "",
  "## CHARLS",
  paste0("- Baseline 2011 persons: ", nrow(charls_base), ". Normalized 2011 IDs are unique; the 11-character form is mapped to 12 characters by inserting zero before the final two characters."),
  paste0("- Baseline overlap in 2015/2018/2020 Sample_Infor: ", paste(charls_overlap, collapse = "/"), "."),
  "- Sample_Infor died=1 is retained as death status; Sample_Infor interview year/month is not treated as the death date.",
  "- Later-wave absence is exported as a noncoverage/loss-to-follow-up candidate only, not as death or final censoring.",
  "- Available 2020 Exit_Module date fields are linked separately; a death status without that exit date remains unresolved.",
  "",
  "## KLoSA",
  paste0("- Main-file coverage: w01 n=", nrow(klosa_main[[1]]), ", w02 n=", nrow(klosa_main[[2]]), ", w01-w02 overlap=", klosa_overlap, "."),
  paste0("- w02 EXIT records: ", nrow(klosa_w02_exit), "; linked w02 EXIT IDs among the w01/w02 linkage frame: ", sum(klosa_w01w02$w02_exit_death_candidate == 1L, na.rm = TRUE), "."),
  "- w01/w02 interview dates establish coverage; w02 EXIT supplies a separate death-date source and is not treated as a final event without the approved rule.",
  "- w03 EXIT is available and linked by pid as a later mortality-date source.",
  "- wstat codes 5 and 6 are death states; 4 is nonresponse alive; 7 is dropped; 9 is unknown.",
  "",
  "## HRS",
  "- Local Harmonized HRS D, RAND 2012 fat, and RAND 2020 fat files did not yield the expected death/status fields in the targeted probe.",
  "- Harmonized HRS D PDF page 4 lists Cross-Wave 2020 Tracker File v.e.3.0, but no Tracker or mortality product was found locally.",
  "- HRS is blocked for mortality outcome construction and external validation pending an approved Tracker/RAND longitudinal/mortality source.",
  "",
  "## Required next gate",
  "- Confirm CHARLS death-date and administrative censoring rules.",
  "- Confirm KLoSA death-date precedence, wstat interpretation, and administrative censoring rules.",
  "- Supply the HRS Tracker/RAND longitudinal or approved mortality product and codebook.",
  "- Only then create final 5-year event and censoring variables."
)
writeLines(notes, file.path(out_root, "followup_linkage_gate_report.md"), useBytes = TRUE)
writeLines(capture.output(sessionInfo()), file.path(out_root, "06_link_followup_sources_sessionInfo.txt"), useBytes = TRUE)
message("Follow-up linkage completed. Outputs written to: ", normalizePath(out_root, winslash = "/"))
