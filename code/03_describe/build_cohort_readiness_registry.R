# Build an auditable six-cohort readiness registry from validated project outputs.
# This registry does not recompute mortality outcomes or modify raw data.

options(stringsAsFactors = FALSE, warn = 1)
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
out_dir <- file.path(root, "results", "cohort_readiness")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
csv_path <- file.path(out_dir, "six_cohort_readiness_registry_2026-07-28.csv")
report_path <- file.path(out_dir, "six_cohort_readiness_registry_2026-07-28.md")

registry <- data.frame(
  cohort = c("CHARLS", "CLHLS", "KLoSA", "SHARE", "MHAS", "HRS"),
  role = c("development", "external_validation", "Asian_validation",
           "European_validation", "American_validation", "American_validation"),
  baseline = c("2011", "2011/2012", "2012", "2011", "2012", "2012"),
  denominator_rule = c(
    "2011 - ba002_1 >= 60",
    "trueage >= 60",
    "w04A002_age >= 60",
    "wave-4 r4iwy == 2011 and age >= 60",
    "r3agey or rabyear/r3iwy derived age >= 60",
    "2012 na019 >= 60"
  ),
  raw_baseline_n = c(17705L, 9765L, 7486L, 54550L, 15716L, 20554L),
  age60_n = c(7669L, 9749L, 5289L, 36604L, 10174L, 13867L),
  four_year_window = c("2011-2015", "baseline to <=1461 days", "2012-2016",
                       "2011-2015", "2012-2016", "2012-2016"),
  verified_current_event_n = c(785L, 3502L, 585L, 3689L, 1404L, 2352L),
  prior_reported_event_n = c(785L, 3502L, 918L, 6287L, 1735L, 2352L),
  event_status = c(
    "VERIFIED_CURRENT",
    "VERIFIED_CURRENT",
    "VERIFIED_CURRENT",
    "VERIFIED_CURRENT",
    "VERIFIED_CURRENT",
    "VERIFIED_CURRENT"
  ),
  source = c(
    "person_period_report periods 1+2",
    "clhls_outcome_v2_report and raw SAV audit",
    "current_four_year_event_audit/klosa_four_year_event_audit_2026-07-28.csv; historical D-013 value retained",
    "current_four_year_event_audit/share_four_year_event_audit_2026-07-28.csv; D-021 applied",
    "current_four_year_event_audit/mhas_four_year_event_audit_2026-07-28.csv; D-022 applied",
    "hrs_event_count_report"
  ),
  stringsAsFactors = FALSE
)

stopifnot(nrow(registry) == 6L)
stopifnot(all(registry$age60_n > 0L))
stopifnot(registry$age60_n[registry$cohort == "SHARE"] == 36604L)
stopifnot(registry$age60_n[registry$cohort == "MHAS"] == 10174L)
stopifnot(registry$verified_current_event_n[registry$cohort == "CHARLS"] == 785L)
stopifnot(registry$verified_current_event_n[registry$cohort == "CLHLS"] == 3502L)
stopifnot(registry$verified_current_event_n[registry$cohort == "KLoSA"] == 585L)
stopifnot(registry$verified_current_event_n[registry$cohort == "SHARE"] == 3689L)
stopifnot(registry$verified_current_event_n[registry$cohort == "MHAS"] == 1404L)
stopifnot(registry$verified_current_event_n[registry$cohort == "HRS"] == 2352L)
write.csv(registry, csv_path, row.names = FALSE, na = "")

report <- c(
  "# Six-Cohort Readiness Registry",
  "",
  "## Material Passport",
  "- Type: cross-cohort denominator and four-year event-readiness registry",
  "- Status: VERIFIED_CURRENT for all six cohorts; three current event counts were recomputed from raw mortality sources",
  paste0("- Script: ", normalizePath("code/03_describe/build_cohort_readiness_registry.R", winslash = "/")),
  paste0("- Output: ", normalizePath(csv_path, winslash = "/")),
  "- Raw data modified: no.",
  "",
  "## Current Denominators",
  "The registry applies D-021 to SHARE (wave-4 visits in 2011 only) and D-022 to MHAS (direct or derived age). These supersede the earlier denominator-audit values for those cohorts.",
  "",
  "| Cohort | Baseline | Raw N | Current age 60+ N | Four-year window | Verified current events | Prior reported events | Status |",
  "|---|---:|---:|---:|---|---:|---:|---|",
  "| CHARLS | 2011 | 17,705 | 7,669 | 2011-2015 | 785 | 785 | VERIFIED |",
  "| CLHLS | 2011/12 | 9,765 | 9,749 | <=1461 days | 3,502 | 3,502 | VERIFIED |",
  "| KLoSA | 2012 | 7,486 | 5,289 | 2012-2016 | 585 | 918 | VERIFIED |",
  "| SHARE | 2011 only | 54,550 | 36,604 | 2011-2015 | 3,689 | 6,287 | VERIFIED |",
  "| MHAS | 2012 | 15,716 age-valid | 10,174 | 2012-2016 | 1,404 | 1,735 | VERIFIED |",
  "| HRS | 2012 | 20,554 | 13,867 | 2012-2016 | 2,352 | 2,352 | VERIFIED |",
  "",
  "## Interpretation",
  "All six cohorts now have current verified event counts. The KLoSA historical 918 was not a valid current denominator-restricted count: it summed EXIT records without restricting to wave-4 baseline IDs and age 60+.",
  "SHARE and MHAS use D-021 and D-022 respectively. Valid death year is sufficient for the frozen primary event count when month is missing; exact-date counts are reported separately in the audit artifact.",
  "The CLHLS D-019 correction is now recorded separately: 45 pre-baseline deaths are marked `prebaseline_death=TRUE` and excluded from the time axis; no outcome definition was changed by this registry.",
  "",
  "## Remaining Gate",
  "The event-count gate is complete. Preserve the exact-date sensitivity columns and the 44 KLoSA year-only records as documented when selecting the final modeling time scale."
)
writeLines(report, report_path, useBytes = TRUE)
message("Wrote ", csv_path)
message("Wrote ", report_path)
