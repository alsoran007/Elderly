#!/usr/bin/env Rscript
# =============================================================================
# Education variable availability audit — six ageing cohorts
# Paper 1 · 2026-07-30
#
# READ-ONLY AUDIT. Does not modify SAP, FI parquets, models, or Results.
# Writes: results/education_availability_audit.md (+ a machine-readable CSV)
#
# For each cohort:
#   1. locate the source file holding education
#   2. identify field name(s) — harmonized and/or raw survey item
#   3. missingness among the 60+ FI-eligible analytic denominator
#   4. coding scheme (categories / years)
#   5. cross-cohort comparability
#   6. join rate against the existing FI parquet (the reliability test from D-029)
#
# Run from project root:
#   Rscript --vanilla code/06_audit/audit_education_availability_2026-07-30.R
# =============================================================================

suppressPackageStartupMessages({
  library(arrow); library(haven); library(dplyr)
})

args <- commandArgs(FALSE); farg <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(farg)) dirname(normalizePath(sub("^--file=", "", farg[1]))) else getwd()
root   <- normalizePath(file.path(script_dir, "..", ".."), mustWork = TRUE)
d_dir  <- file.path(root, "data", "analysis")
sql    <- "D:/AI_project/sql"          # read-only source tree
org    <- file.path(root, "data_organized")
OUTDIR <- file.path(root, "results")
stamp  <- "2026-07-30"

zap <- function(x) if (inherits(x, c("haven_labelled", "labelled"))) unclass(x) else x
clean_id <- function(x) { x <- zap(x); y <- trimws(as.character(x)); y[is.na(x)] <- NA_character_; y }

# Accumulator
rows <- list()
log  <- function(...) cat(sprintf(...), "\n")

add_row <- function(cohort, file, field_h, field_raw, denom, n_nonmiss,
                    coding, join_rate, verdict, note) {
  rows[[length(rows) + 1]] <<- data.frame(
    cohort = cohort, source_file = file,
    field_harmonized = field_h, field_raw = field_raw,
    denominator_60plus = denom, n_nonmissing = n_nonmiss,
    missing_pct = round(100 * (denom - n_nonmiss) / denom, 2),
    coding = coding, join_rate_pct = join_rate,
    verdict = verdict, note = note,
    stringsAsFactors = FALSE
  )
}

# Helper: scan a data.frame for plausible education field names
# NB: keep the pattern tight. A loose pattern such as "ba00" matches KLoSA's
# w04Ba001 (number of children) and CHARLS ba00* (birthplace) items.
find_edu <- function(df) {
  pat <- "raeducl|raedyrs|raedisced|^w0[0-9]edu|edyrs|edisced|^educ|schlyrs|degree|isced|^bd001$|^f1$"
  grep(pat, names(df), ignore.case = TRUE, value = TRUE)
}

# =============================================================================
log("=== CHARLS ===")
# -----------------------------------------------------------------------------
fi_ch <- as.data.frame(read_parquet(file.path(d_dir, "charls_fi_2011_2026-07-27.parquet")))
ch_elig <- fi_ch |> filter(!is.na(age), age >= 60, !is.na(fi_excluded), !fi_excluded)
denom_ch <- nrow(ch_elig)
log("  FI-eligible 60+: %d", denom_ch)

demo <- read_dta(file.path(sql, "CHARLS/2011/demographic_background.dta"))
cands <- find_edu(demo)
log("  candidate fields in demographic_background.dta: %s", paste(cands, collapse = ", "))

# bd001 = highest level of education attained (CHARLS 2011 questionnaire)
edu_field <- if ("bd001" %in% names(demo)) "bd001" else cands[1]
demo$id_key <- clean_id(demo$ID)
ch_elig$id_key <- clean_id(ch_elig$id)

j <- ch_elig |> left_join(demo |> select(id_key, edu_raw = all_of(edu_field)) |> distinct(id_key, .keep_all = TRUE),
                          by = "id_key")
n_join_ch  <- sum(!is.na(j$edu_raw) | j$id_key %in% demo$id_key)
n_valid_ch <- sum(!is.na(zap(j$edu_raw)))
jr_ch <- round(100 * sum(ch_elig$id_key %in% demo$id_key) / denom_ch, 1)
log("  field=%s | joined=%.1f%% | non-missing edu=%d (%.1f%%)",
    edu_field, jr_ch, n_valid_ch, 100 * n_valid_ch / denom_ch)
lv <- attr(demo[[edu_field]], "labels")
log("  coding: %d levels", length(lv))

add_row("CHARLS", "sql/CHARLS/2011/demographic_background.dta",
        "— (raw survey item; Gateway raeducl not in local files)", edu_field,
        denom_ch, n_valid_ch,
        sprintf("%d-level ordinal (1=no formal … highest)", length(lv)),
        jr_ch,
        ifelse(jr_ch >= 90 & 100 * n_valid_ch / denom_ch >= 90, "RECOMMENDED",
        ifelse(jr_ch >= 90, "CONDITIONAL", "NOT RECOMMENDED")),
        "Raw CHARLS item; requires manual mapping to ISCED for cross-cohort use")

# =============================================================================
log("=== CLHLS ===")
# -----------------------------------------------------------------------------
fi_cl <- as.data.frame(read_parquet(file.path(d_dir, "clhls_fi_2011_2026-07-29.parquet")))
cl_elig <- fi_cl |> filter(!is.na(age), age >= 60, !is.na(fi_excluded), !fi_excluded)
denom_cl <- nrow(cl_elig)
log("  FI-eligible 60+: %d", denom_cl)

cl_sav <- file.path(sql, "CLHLS/CLHLS_dataset_2008-2018_SPSS",
                    "clhls_2011_2018_longitudinal_dataset_released_version1.sav")
# Read header only (n_max) to list fields, then pull just the needed columns
cl_head <- read_sav(cl_sav, n_max = 5)
cands_cl <- find_edu(cl_head)
log("  candidate fields: %s", paste(head(cands_cl, 10), collapse = ", "))

# CLHLS: f1 = years of schooling (baseline wave prefix varies)
edu_cl <- intersect(c("f1", "f11", "f1_11", "edyrs"), names(cl_head))
edu_cl <- if (length(edu_cl)) edu_cl[1] else cands_cl[1]

if (!is.na(edu_cl) && length(edu_cl)) {
  cl_edu <- read_sav(cl_sav, col_select = all_of(c("id", edu_cl)))
  cl_edu$id_key <- clean_id(cl_edu$id)
  cl_elig$id_key <- clean_id(cl_elig$id)
  jr_cl <- round(100 * sum(cl_elig$id_key %in% cl_edu$id_key) / denom_cl, 1)
  m <- cl_elig |> left_join(cl_edu |> select(id_key, e = all_of(edu_cl)) |>
                              distinct(id_key, .keep_all = TRUE), by = "id_key")
  ev <- zap(m$e); ev[ev %in% c(88, 99, 888, 999)] <- NA   # CLHLS missing codes
  n_valid_cl <- sum(!is.na(ev))
  log("  field=%s | joined=%.1f%% | non-missing=%d (%.1f%%)",
      edu_cl, jr_cl, n_valid_cl, 100 * n_valid_cl / denom_cl)
  add_row("CLHLS", "sql/CLHLS/.../clhls_2011_2018_longitudinal...sav",
          "—", edu_cl, denom_cl, n_valid_cl,
          "Years of schooling (continuous; 88/99 = missing codes)", jr_cl,
          ifelse(jr_cl >= 90 & 100 * n_valid_cl / denom_cl >= 90, "RECOMMENDED",
          ifelse(jr_cl >= 90 & 100 * n_valid_cl / denom_cl >= 70, "CONDITIONAL", "NOT RECOMMENDED")),
          "Years-of-schooling metric; not directly comparable to ISCED categories")
} else {
  log("  NO education field located")
  add_row("CLHLS", "sql/CLHLS/...sav", "—", "NOT FOUND", denom_cl, 0,
          "—", NA, "NOT RECOMMENDED", "No education field located in baseline file")
}

# =============================================================================
log("=== KLoSA ===")
# -----------------------------------------------------------------------------
fi_kl <- as.data.frame(read_parquet(file.path(d_dir, "klosa_fi_2012_2026-07-29.parquet")))
kl_elig <- fi_kl |> filter(age_60_plus == TRUE, !fi_excluded)
denom_kl <- nrow(kl_elig)
log("  FI-eligible 60+: %d", denom_kl)

kl_w4 <- read_dta(file.path(sql, "KLOSA/KLoSA 1-9th wave (STATA)/w04_e.dta"), n_max = 5)
cands_kl <- find_edu(kl_w4)
log("  candidate fields: %s", paste(head(cands_kl, 12), collapse = ", "))

edu_kl <- intersect(c("w04edu", "w04edua"), names(kl_w4))
edu_kl <- if (length(edu_kl)) edu_kl[1] else cands_kl[1]
if (!is.na(edu_kl)) {
  kl_full <- read_dta(file.path(sql, "KLOSA/KLoSA 1-9th wave (STATA)/w04_e.dta"))
  idc <- intersect(c("pid", "hhid", "id"), names(kl_full))[1]
  kl_full$pid_n <- as.numeric(zap(kl_full[[idc]]))
  kl_elig$pid_n <- as.numeric(zap(kl_elig$pid))
  jr_kl <- round(100 * sum(kl_elig$pid_n %in% kl_full$pid_n) / denom_kl, 1)
  m <- kl_elig |> left_join(kl_full |> select(pid_n, e = all_of(edu_kl)) |>
                              distinct(pid_n, .keep_all = TRUE), by = "pid_n")
  n_valid_kl <- sum(!is.na(zap(m$e)))
  log("  field=%s | joined=%.1f%% | non-missing=%d (%.1f%%)",
      edu_kl, jr_kl, n_valid_kl, 100 * n_valid_kl / denom_kl)
  add_row("KLoSA", "sql/KLOSA/KLoSA 1-9th wave (STATA)/w04_e.dta",
          "—", edu_kl, denom_kl, n_valid_kl,
          "Korean education categories (survey-specific)", jr_kl,
          ifelse(jr_kl >= 90 & 100 * n_valid_kl / denom_kl >= 90, "RECOMMENDED",
          ifelse(jr_kl >= 90 & 100 * n_valid_kl / denom_kl >= 70, "CONDITIONAL", "NOT RECOMMENDED")),
          "FI parquet lacks sex; education would need the same re-linkage step")
} else {
  add_row("KLoSA", "w04_e.dta", "—", "NOT FOUND", denom_kl, 0, "—", NA,
          "NOT RECOMMENDED", "No education field matched the search pattern")
}

# =============================================================================
log("=== HRS ===")
# -----------------------------------------------------------------------------
fi_hrs <- as.data.frame(read_parquet(file.path(d_dir, "hrs_fi_2012_2026-07-29.parquet")))
hrs_elig <- fi_hrs |> filter(age_60_plus == TRUE, !fi_excluded)
denom_hrs <- nrow(hrs_elig)
log("  FI-eligible 60+: %d", denom_hrs)


# NOTE: the RAND Fat File (h12f3a.dta) used for FI construction does NOT carry
# education. Gateway's harmonized HRS file does (raeducl). Audit that instead.
hrs_f <- file.path(sql, "HRS Products/harmonised HRS/H_HRS_d.dta")
hrs_head <- read_dta(hrs_f, n_max = 5)
cands_hrs <- find_edu(hrs_head)
log("  candidate fields in H_HRS_d.dta: %s", paste(head(cands_hrs, 12), collapse = ", "))

edu_hrs <- intersect(c("raeducl", "raedyrs", "raedisced", "raedegrm"), cands_hrs)
edu_hrs <- if (length(edu_hrs)) edu_hrs[1] else cands_hrs[1]

if (!is.na(edu_hrs) && length(edu_hrs)) {
  hrs_full <- read_dta(hrs_f, col_select = all_of(c("hhidpn", edu_hrs)))
  hrs_full$pid_n <- as.numeric(zap(hrs_full$hhidpn))
  idc <- intersect(c("hhidpn", "pid", "id"), names(hrs_elig))[1]
  hrs_elig$pid_n <- as.numeric(zap(hrs_elig[[idc]]))
  jr_hrs <- round(100 * sum(hrs_elig$pid_n %in% hrs_full$pid_n) / denom_hrs, 1)
  m <- hrs_elig |> left_join(hrs_full |> select(pid_n, e = all_of(edu_hrs)) |>
                               distinct(pid_n, .keep_all = TRUE), by = "pid_n")
  n_valid_hrs <- sum(!is.na(zap(m$e)))
  log("  field=%s | joined=%.1f%% | non-missing=%d (%.1f%%)",
      edu_hrs, jr_hrs, n_valid_hrs, 100 * n_valid_hrs / denom_hrs)
  add_row("HRS", "sql/HRS Products/harmonised HRS/H_HRS_d.dta", edu_hrs, edu_hrs,
          denom_hrs, n_valid_hrs,
          "Gateway harmonized raeducl (1=<upper sec, 2=upper sec, 3=tertiary)", jr_hrs,
          ifelse(jr_hrs >= 90 & 100 * n_valid_hrs / denom_hrs >= 90, "RECOMMENDED",
          ifelse(jr_hrs >= 90 & 100 * n_valid_hrs / denom_hrs >= 70, "CONDITIONAL", "NOT RECOMMENDED")),
          "Education is in the harmonized file, NOT the RAND Fat File used for FI; needs a second join")
} else {
  add_row("HRS", "H_HRS_d.dta", "NOT FOUND", "NOT FOUND", denom_hrs, 0, "—", NA,
          "NOT RECOMMENDED", "No education field located")
}

# =============================================================================
log("=== SHARE ===")
# -----------------------------------------------------------------------------
fi_sh <- as.data.frame(read_parquet(file.path(d_dir, "share_fi_2011_2026-07-29.parquet")))
sh_elig <- fi_sh |> filter(age_60_plus == TRUE, !fi_excluded)
denom_sh <- nrow(sh_elig)
log("  FI-eligible 60+: %d", denom_sh)

sh_f <- file.path(sql, "share harmonised/GH_SHARE_g.dta")
sh_head <- read_dta(sh_f, n_max = 5)
cands_sh <- find_edu(sh_head)
log("  candidate fields (first 12): %s", paste(head(cands_sh, 12), collapse = ", "))

edu_sh <- intersect(c("raeducl", "raedyrs", "raeduc_gateway", "isced"), cands_sh)
edu_sh <- if (length(edu_sh)) edu_sh[1] else cands_sh[1]

if (!is.na(edu_sh) && length(edu_sh)) {
  idc_sh <- intersect(c("mergeid", "pid", "id"), names(sh_head))[1]
  sh_full <- read_dta(sh_f, col_select = all_of(c(idc_sh, edu_sh)))
  sh_full$id_key <- clean_id(sh_full[[idc_sh]])
  idc2 <- intersect(c("mergeid", "id", "pid"), names(sh_elig))[1]
  sh_elig$id_key <- clean_id(sh_elig[[idc2]])
  jr_sh <- round(100 * sum(sh_elig$id_key %in% sh_full$id_key) / denom_sh, 1)
  m <- sh_elig |> left_join(sh_full |> select(id_key, e = all_of(edu_sh)) |>
                              distinct(id_key, .keep_all = TRUE), by = "id_key")
  n_valid_sh <- sum(!is.na(zap(m$e)))
  log("  field=%s | joined=%.1f%% | non-missing=%d (%.1f%%)",
      edu_sh, jr_sh, n_valid_sh, 100 * n_valid_sh / denom_sh)
  add_row("SHARE", "sql/share harmonised/GH_SHARE_g.dta", edu_sh, edu_sh,
          denom_sh, n_valid_sh,
          "Gateway harmonized ISCED-based (raeducl: 1=<upper sec, 2=upper sec, 3=tertiary)",
          jr_sh,
          ifelse(jr_sh >= 90 & 100 * n_valid_sh / denom_sh >= 90, "RECOMMENDED",
          ifelse(jr_sh >= 90 & 100 * n_valid_sh / denom_sh >= 70, "CONDITIONAL", "NOT RECOMMENDED")),
          "Gateway harmonized — the cross-cohort comparability reference standard")
} else {
  add_row("SHARE", "GH_SHARE_g.dta", "NOT FOUND", "NOT FOUND", denom_sh, 0, "—", NA,
          "NOT RECOMMENDED", "No education field matched")
}

# =============================================================================
log("=== MHAS ===")
# -----------------------------------------------------------------------------
fi_mh <- as.data.frame(read_parquet(file.path(d_dir, "mhas_fi_2012_2026-07-28.parquet")))
mh_elig <- fi_mh |> filter(age_60_plus == TRUE, !fi_excluded)
denom_mh <- nrow(mh_elig)
log("  FI-eligible 60+: %d", denom_mh)

mh_f <- file.path(sql, "MHAS/H_MHAS_c2.dta")
mh_head <- read_dta(mh_f, n_max = 5)
cands_mh <- find_edu(mh_head)
log("  candidate fields (first 12): %s", paste(head(cands_mh, 12), collapse = ", "))

edu_mh <- intersect(c("raeducl", "raedyrs", "raeduc"), cands_mh)
edu_mh <- if (length(edu_mh)) edu_mh[1] else cands_mh[1]

if (!is.na(edu_mh) && length(edu_mh)) {
  idc_mh <- intersect(c("rahhidnp", "unhhidnp", "unhhid", "cunicah"), names(mh_head))[1]
  mh_full <- read_dta(mh_f, col_select = all_of(c(idc_mh, edu_mh)))
  mh_full$id_key <- clean_id(mh_full[[idc_mh]])
  idc3 <- intersect(c("rahhidnp", "unhhidnp", "unhhid", "cunicah"), names(mh_elig))[1]
  mh_elig$id_key <- clean_id(mh_elig[[idc3]])
  jr_mh <- round(100 * sum(mh_elig$id_key %in% mh_full$id_key) / denom_mh, 1)
  m <- mh_elig |> left_join(mh_full |> select(id_key, e = all_of(edu_mh)) |>
                              distinct(id_key, .keep_all = TRUE), by = "id_key")
  n_valid_mh <- sum(!is.na(zap(m$e)))
  log("  field=%s | joined=%.1f%% | non-missing=%d (%.1f%%)",
      edu_mh, jr_mh, n_valid_mh, 100 * n_valid_mh / denom_mh)
  add_row("MHAS", "sql/MHAS/H_MHAS_c2.dta", edu_mh, edu_mh,
          denom_mh, n_valid_mh,
          "Gateway harmonized (raeducl ISCED-based / raedyrs years)", jr_mh,
          ifelse(jr_mh >= 90 & 100 * n_valid_mh / denom_mh >= 90, "RECOMMENDED",
          ifelse(jr_mh >= 90 & 100 * n_valid_mh / denom_mh >= 70, "CONDITIONAL", "NOT RECOMMENDED")),
          "Gateway harmonized; same standard as SHARE")
} else {
  add_row("MHAS", "H_MHAS_c2.dta", "NOT FOUND", "NOT FOUND", denom_mh, 0, "—", NA,
          "NOT RECOMMENDED", "No education field matched")
}

# =============================================================================
# Save machine-readable results
# =============================================================================
res <- bind_rows(rows)
csv_path <- file.path(OUTDIR, paste0("education_availability_audit_", stamp, ".csv"))
write.csv(res, csv_path, row.names = FALSE, na = "")

cat("\n===== SUMMARY =====\n")
print(res[, c("cohort", "field_raw", "denominator_60plus", "n_nonmissing",
              "missing_pct", "join_rate_pct", "verdict")], row.names = FALSE)
cat("\nCSV written:", csv_path, "\n")
cat("Now generating the Markdown report...\n")
saveRDS(res, file.path(OUTDIR, ".edu_audit_tmp.rds"))
