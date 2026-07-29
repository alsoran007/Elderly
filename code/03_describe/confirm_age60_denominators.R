#!/usr/bin/env Rscript

# Confirm baseline age-60+ denominators for the six retained cohorts.
# This is a read-only audit: no mortality, FI, model, or outcome variables are built.

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

result_dir <- file.path(project_root, "results", "age60_denominators")
log_dir <- file.path(project_root, "logs")
dir.create(result_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

stamp <- "2026-07-28"
log_path <- file.path(log_dir, paste0("confirm_age60_denominators_", stamp, ".log"))
log_con <- file(log_path, open = "wt", encoding = "UTF-8")
sink(log_con, type = "output", split = TRUE)
sink(log_con, type = "message", append = TRUE)
on.exit({
  sink(type = "message")
  sink(type = "output")
  close(log_con)
}, add = TRUE)

if (!requireNamespace("haven", quietly = TRUE)) stop("Package 'haven' is required.")
if (!requireNamespace("arrow", quietly = TRUE)) {
  message("Package 'arrow' not found; CSV output remains available.")
}

raw_root <- file.path(dirname(project_root), "sql")
assert_file <- function(path) {
  if (!file.exists(path)) stop("Missing input: ", path)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

read_dta_cols <- function(path, cols) {
  haven::read_dta(assert_file(path), col_select = tidyselect::any_of(cols),
                  .name_repair = "minimal")
}

read_sav_cols <- function(path, cols) {
  haven::read_sav(assert_file(path), col_select = tidyselect::any_of(cols),
                  .name_repair = "minimal")
}

as_numeric <- function(x) suppressWarnings(as.numeric(x))

make_summary <- function(cohort, baseline, age, age_field, source_file,
                         baseline_rule, sensitivity_n = NA_integer_,
                         sensitivity_label = NA_character_) {
  age <- as_numeric(age)
  age[!is.finite(age) | age < 0 | age > 120] <- NA_real_
  data.frame(
    cohort = cohort,
    source_file = source_file,
    baseline_rule = baseline_rule,
    age_field = age_field,
    raw_rows = nrow(baseline),
    unique_id_n = length(unique(as.character(baseline[[1]]))),
    age_valid_n = sum(!is.na(age)),
    age_missing_n = sum(is.na(age)),
    age_missing_pct = sum(is.na(age)) / nrow(baseline),
    age60_n = sum(age >= 60, na.rm = TRUE),
    age60_pct_of_age_valid = sum(age >= 60, na.rm = TRUE) / sum(!is.na(age)),
    sensitivity_label = sensitivity_label,
    sensitivity_age60_n = sensitivity_n,
    stringsAsFactors = FALSE
  )
}

message("START age-60+ denominator audit; project_root=", project_root)

# CHARLS: approved project convention is age = 2011 - ba002_1.
charls_path <- file.path(raw_root, "Charls", "2011", "demographic_background.dta")
charls <- read_dta_cols(charls_path, c("ID", "ba002_1"))
charls_age <- 2011 - as_numeric(charls[["ba002_1"]])
charls_age[as_numeric(charls[["ba002_1"]]) < 1890 |
             as_numeric(charls[["ba002_1"]]) > 2000] <- NA_real_
charls_summary <- make_summary(
  "CHARLS", charls, charls_age, "2011 - ba002_1", charls_path,
  "2011 demographic_background rows; valid birth year 1890-2000"
)

# CLHLS: trueage is the baseline age in the 2011-2018 longitudinal file.
clhls_path <- file.path(raw_root, "CLHLS", "CLHLS_dataset_2008-2018_SPSS",
                        "clhls_2011_2018_longitudinal_dataset_released_version1.sav")
clhls <- read_sav_cols(clhls_path, c("id", "trueage"))
clhls_summary <- make_summary(
  "CLHLS", clhls, clhls[["trueage"]], "trueage", clhls_path,
  "2011-2018 longitudinal file; all rows with valid trueage"
)

# KLoSA: w04 is the 2012 baseline wave; age is a direct wave-specific field.
klosa_path <- file.path(raw_root, "KLOSA", "KLoSA 1-9th wave (STATA)", "w04_e.dta")
klosa <- read_dta_cols(klosa_path, c("pid", "w04A002_age"))
klosa_summary <- make_summary(
  "KLoSA", klosa, klosa[["w04A002_age"]], "w04A002_age", klosa_path,
  "2012 wave w04 rows; valid direct age"
)

# HRS: RAND 2012 Fat File; na019 is the documented 2012 age field.
hrs_path <- file.path(raw_root, "HRS Products", "RAND HRS Products(原始)",
                      "2012 RAND HRS Fat File", "h12f3a.dta")
hrs <- read_dta_cols(hrs_path, c("hhidpn", "na019"))
hrs_summary <- make_summary(
  "HRS", hrs, hrs[["na019"]], "na019", hrs_path,
  "2012 RAND Fat File rows; valid na019"
)

# SHARE: cv_r is pooled in this release; waveid==42 identifies SHARE wave 4 (2011).
# The primary count retains all wave-4 rows with valid age. Complete-interview 60+
# is reported as a sensitivity because the task is denominator confirmation only.
share_path <- file.path(raw_root, "SHARE", "sharew4_rel9-0-0_ALL_datasets_stata",
                        "sharew4_rel9-0-0_cv_r.dta")
share_all <- read_dta_cols(share_path,
                           c("mergeid", "waveid", "interview", "age2011"))
share <- share_all[as_numeric(share_all[["waveid"]]) == 42, , drop = FALSE]
share_age <- as_numeric(share[["age2011"]])
share_age[!is.finite(share_age) | share_age < 0 | share_age > 120] <- NA_real_
share_summary <- make_summary(
  "SHARE", share, share_age, "age2011", share_path,
  "waveid==42 (2011 wave 4); valid age2011",
  sensitivity_n = sum(share_age >= 60 & as_numeric(share[["interview"]]) == 1,
                      na.rm = TRUE),
  sensitivity_label = "interview==1 among waveid==42"
)

# MHAS: r3 is the 2012 wave in the harmonized longitudinal file.
mhas_path <- file.path(raw_root, "MHAS", "H_MHAS_c2.dta")
mhas <- read_dta_cols(mhas_path, c("rahhidnp", "r3agey", "r3iwstat"))
mhas_summary <- make_summary(
  "MHAS", mhas, mhas[["r3agey"]], "r3agey", mhas_path,
  "2012 wave r3; all rows with valid r3agey"
)

summary <- rbind(charls_summary, clhls_summary, klosa_summary,
                 hrs_summary, share_summary, mhas_summary)

expected <- c(CHARLS = 7669L, CLHLS = 9749L, KLoSA = 5289L,
              HRS = 13867L, SHARE = 12722L, MHAS = 10176L)
summary$expected_age60_n <- unname(expected[summary$cohort])
summary$assert_age60 <- ifelse(summary$age60_n == summary$expected_age60_n,
                               "PASS", "FAIL")
summary$source_file <- normalizePath(summary$source_file, winslash = "/")

if (any(summary$assert_age60 == "FAIL")) {
  print(summary)
  stop("Age-60+ denominator assertion failed.")
}

csv_path <- file.path(result_dir, paste0("age60_denominators_", stamp, ".csv"))
write.csv(summary, csv_path, row.names = FALSE, na = "")

report_lines <- c(
  "# Baseline age-60+ denominator audit",
  "",
  paste0("Run date: ", stamp, ". Raw source files were read only; no raw file was modified."),
  "",
  "## Primary counts",
  "",
  "The primary denominator is the number of records in the frozen baseline source with a valid age field and age >=60. No mortality, FI, model, or outcome construction was performed.",
  "",
  "| Cohort | Baseline age field | Raw rows | Age-valid rows | Age missing | Age 60+ | 60+ / age-valid | Check |",
  "|---|---:|---:|---:|---:|---:|---:|---|",
  vapply(seq_len(nrow(summary)), function(i) {
    sprintf("| %s | `%s` | %d | %d | %d (%.2f%%) | **%d** | %.2f%% | %s |",
            summary$cohort[i], summary$age_field[i], summary$raw_rows[i],
            summary$age_valid_n[i], summary$age_missing_n[i],
            100 * summary$age_missing_pct[i], summary$age60_n[i],
            100 * summary$age60_pct_of_age_valid[i], summary$assert_age60[i])
  }, character(1)),
  "",
  "## SHARE response sensitivity",
  "",
  paste0("SHARE `cv_r` contains pooled release rows; wave 4 is selected with `waveid==42`. The primary count is all wave-4 rows with valid `age2011` (",
         share_summary$age60_n, "). Among completed interviews (`interview==1`), the corresponding 60+ count is ",
         share_summary$sensitivity_age60_n, ". This sensitivity is reported without changing the primary denominator."),
  "",
  "## Source and scope notes",
  "",
  "- CHARLS age follows the project-approved convention `2011 - ba002_1`.",
  "- CLHLS uses `trueage` from the 2011-2018 longitudinal baseline file.",
  "- KLoSA uses direct `w04A002_age` from 2012 wave w04.",
  "- HRS uses `na019` from the 2012 RAND Fat File; the previously validated 60+ count is 13,867.",
  "- MHAS uses `r3agey`, where r3 is the 2012 wave in H_MHAS_c2.",
  "- These are denominator checks only. Existing mortality event counts were not recomputed."
)
report_path <- file.path(result_dir, paste0("age60_denominators_report_", stamp, ".md"))
writeLines(report_lines, report_path, useBytes = TRUE)

if (requireNamespace("arrow", quietly = TRUE)) {
  arrow::write_parquet(summary, file.path(result_dir,
                                           paste0("age60_denominators_", stamp, ".parquet")))
}

writeLines(capture.output(sessionInfo()),
           file.path(result_dir, paste0("age60_denominators_sessionInfo_", stamp, ".txt")),
           useBytes = TRUE)
message("DONE; csv=", normalizePath(csv_path, winslash = "/"),
        "; report=", normalizePath(report_path, winslash = "/"))
