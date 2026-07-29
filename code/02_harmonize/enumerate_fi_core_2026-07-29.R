#!/usr/bin/env Rscript
# Enumerate the fixed-41 FI coverage matrix using only the six task-specified
# analysis parquet files. Raw source data are not accessed or modified.

suppressPackageStartupMessages(library(arrow))

files <- c(
  CHARLS = "D:/AI_project/project3/data/analysis/charls_fi_2011_2026-07-27.parquet",
  CLHLS  = "D:/AI_project/project3/data/analysis/clhls_fi_2011_2026-07-29.parquet",
  KLoSA  = "D:/AI_project/project3/data/analysis/klosa_fi_2012_2026-07-29.parquet",
  HRS    = "D:/AI_project/project3/data/analysis/hrs_fi_2012_2026-07-29.parquet",
  SHARE  = "D:/AI_project/project3/data/analysis/share_fi_2011_2026-07-29.parquet",
  MHAS   = "D:/AI_project/project3/data/analysis/mhas_fi_2012_2026-07-28.parquet"
)
cohorts <- names(files)

# Final 41-item specification: 13 comorbidity, 6 ADL, 5 IADL,
# 9 mobility, 3 sensory, 4 general-health, and BMI.
stems <- c(
  "hibpe","dyslipe","diabe","cancre","lunge","livere","hearte",
  "stroke","kidneye","digeste","psyche","arthre","asthmae",
  "dressa","batha","eata","beda","toilta","urina",
  "housewka","mealsa","shopa","moneya","medsa",
  "walk100a","walk1kma","joga","climsa","chaira","stoopa",
  "armsa","lifta","dimea","dsight","nsight","hearing",
  "shlt","painfr","fall","slfmem","mbmi"
)
domains <- c(
  rep("comorbidity", 13), rep("adl", 6), rep("iadl", 5),
  rep("mobility", 9), rep("sensory", 3), rep("general_health", 4),
  "anthropometry"
)
stopifnot(length(stems) == 41L, length(domains) == 41L)

# HRS and KLoSA have non-equivalent substitute slots in their builders.
# They remain visible in mapping notes but are not counted as the canonical
# stem unless the canonical item column itself is present.
read_one <- function(path) as.data.frame(read_parquet(path))

data <- lapply(files, read_one)
age60 <- lapply(data, function(d) {
  if ("age_60_plus" %in% names(d)) {
    z <- d[["age_60_plus"]]
    if (is.logical(z)) return(!is.na(z) & z)
    return(!is.na(z) & as.numeric(z) == 1)
  }
  if ("age" %in% names(d)) return(!is.na(d[["age"]]) & as.numeric(d[["age"]]) >= 60)
  rep(TRUE, nrow(d))
})
names(age60) <- cohorts

map_one <- function(cohort, cols) {
  m <- setNames(rep(NA_character_, length(stems)), stems)
  if (cohort %in% c("CHARLS", "CLHLS", "SHARE", "HRS", "KLoSA")) {
    hit <- stems[stems %in% cols]
    m[hit] <- hit
  } else if (cohort == "MHAS") {
    prefixed <- paste0("r3", stems)
    hit <- stems[prefixed %in% cols]
    m[hit] <- prefixed[match(hit, stems)]
  }
  m
}
maps <- Map(map_one, cohorts, lapply(data, names))

rate_one <- function(d, keep, col) {
  if (is.na(col) || !nzchar(col)) {
    return(c(present = FALSE, nonmissing_rate = NA_real_, positive_rate = NA_real_))
  }
  x <- suppressWarnings(as.numeric(d[[col]][keep]))
  n_valid <- sum(!is.na(x))
  if (!n_valid) return(c(present = TRUE, nonmissing_rate = 0, positive_rate = NA_real_))
  c(present = TRUE, nonmissing_rate = n_valid / length(x), positive_rate = mean(x == 1, na.rm = TRUE))
}

rows <- vector("list", length(stems))
for (i in seq_along(stems)) {
  out <- data.frame(stem = stems[i], domain = domains[i], stringsAsFactors = FALSE)
  available <- logical(length(cohorts))
  rates <- numeric(length(cohorts))
  rates[] <- NA_real_
  missing_rate <- numeric(length(cohorts))
  missing_rate[] <- NA_real_
  for (j in seq_along(cohorts)) {
    col <- maps[[j]][[stems[i]]]
    z <- rate_one(data[[j]], age60[[j]], col)
    has_column <- !is.na(col) && nzchar(col)
    available[j] <- has_column && !is.na(z[["nonmissing_rate"]]) && z[["nonmissing_rate"]] > 0
    rates[j] <- z[["positive_rate"]]
    missing_rate[j] <- z[["nonmissing_rate"]]
    out[[paste0(cohorts[j], "_column")]] <- ifelse(is.na(col), NA_character_, col)
    out[[paste0(cohorts[j], "_present")]] <- isTRUE(z[["present"]])
    out[[paste0(cohorts[j], "_nonmissing_rate")]] <- unname(z[["nonmissing_rate"]])
    out[[paste0(cohorts[j], "_rate")]] <- unname(z[["positive_rate"]])
  }
  out$n_cohorts <- sum(available)
  out$in_FI_core <- out$n_cohorts == 6
  out$in_FI_core_5of6 <- out$n_cohorts >= 5
  out$missing_cohorts <- if (out$n_cohorts == 6) "" else paste(cohorts[!available], collapse = ",")
  low <- any(rates[available] < 0.01, na.rm = TRUE)
  high <- any(rates[available] > 0.60, na.rm = TRUE) && any(rates[available] < 0.30, na.rm = TRUE)
  warnings <- c(if (low) "very_low_positive_rate" else NULL,
                if (high) "cross_cohort_high_low_rate" else NULL)
  out$quality_warning <- if (length(warnings)) paste(warnings, collapse = ";") else ""
  rows[[i]] <- out
}
matrix <- do.call(rbind, rows)

out_dir <- "D:/AI_project/project3/results/fi_core"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
csv_path <- file.path(out_dir, "fi_core_coverage_matrix_2026-07-29.csv")
write.csv(matrix, csv_path, row.names = FALSE, na = "")

fmt <- function(x) ifelse(is.na(x), "NA", sprintf("%.3f", x))
rate_text <- function(row, cohort) {
  v <- row[[paste0(cohort, "_rate")]]
  paste0(cohort, "=", fmt(v))
}
md <- c(
  "# FI_core Enumeration Report",
  "",
  paste0("Execution date: 2026-07-29"),
  "Source scope: exactly the six task-specified analysis parquet files.",
  "Positive rate is the proportion with deficit value exactly equal to 1 among age 60+ rows; ordinal items are therefore reported using the task-specified exact-1 rule.",
  "",
  "## Executive Summary",
  "",
  paste0("- Total canonical stems: ", nrow(matrix)),
  paste0("- FI_core (all 6 cohorts): ", sum(matrix$in_FI_core), " stems"),
  paste0("- FI_core_5of6: ", sum(matrix$in_FI_core_5of6), " stems"),
  paste0("- Age 60+ rows: ", paste(paste0(cohorts, "=", vapply(age60, sum, integer(1))), collapse = "; ")),
  paste0("- Coverage matrix: ", csv_path),
  "",
  "The MHAS file is the required 2026-07-28 version. HRS and KLoSA substitute columns are not silently relabeled as canonical concepts; only exact canonical columns count toward FI_core.",
  "",
  "## Full Coverage Matrix",
  "",
  paste0("| stem | domain | ", paste(paste0(cohorts, "_rate"), collapse = " | "), " | n_cohorts | in_FI_core | in_FI_core_5of6 | missing_cohorts | warning |"),
  paste0("|", paste(rep("---", 13), collapse = "|"), "|"),
  vapply(seq_len(nrow(matrix)), function(i) {
    r <- matrix[i,]
    paste(c(r$stem, r$domain, vapply(cohorts, function(cc) fmt(r[[paste0(cc, "_rate")]]), character(1)),
            r$n_cohorts, r$in_FI_core, r$in_FI_core_5of6, r$missing_cohorts, r$quality_warning), collapse = " | ")
  }, character(1)),
  "",
  "## FI_core Stems by Domain",
  ""
)
for (dom in unique(domains)) {
  core <- matrix$stem[matrix$domain == dom & matrix$in_FI_core]
  md <- c(md, paste0("### ", dom, " (", length(core), "/", sum(matrix$domain == dom), ")"))
  if (length(core)) {
    for (s in core) {
      r <- matrix[matrix$stem == s,]
      md <- c(md, paste0("- ", s, ": ", paste(vapply(cohorts, function(cc) rate_text(r, cc), character(1)), collapse = ", ")))
    }
  } else md <- c(md, "- None")
  md <- c(md, "")
}

md <- c(md,
  "## Stems Excluded from FI_core",
  "",
  "The following stems have at least one missing cohort. The missing_cohorts field identifies the limiting cohort(s); column fields in the CSV preserve the exact source column mapping.",
  "",
  vapply(which(!matrix$in_FI_core), function(i) {
    r <- matrix[i,]
    paste0("- ", r$stem, " (", r$domain, "): missing ", r$missing_cohorts,
           "; FI_core_5of6=", r$in_FI_core_5of6)
  }, character(1)),
  "",
  "## Quality Warnings",
  ""
)
warn <- matrix$stem[nzchar(matrix$quality_warning)]
if (length(warn)) {
  for (s in warn) {
    r <- matrix[matrix$stem == s,]
    md <- c(md, paste0("- ", s, ": ", r$quality_warning))
  }
} else md <- c(md, "- None")
md <- c(md,
  "",
  "## SAP Impact",
  "",
  paste0("FI_core (", sum(matrix$in_FI_core), " items) will be used as the sensitivity analysis against FI_full (41 items, cohort-specific threshold). The unified sensitivity threshold is ceiling(0.8 x ", sum(matrix$in_FI_core), ") = ", ceiling(0.8 * sum(matrix$in_FI_core)), ". FI_core_5of6 (", sum(matrix$in_FI_core_5of6), " items) is an expanded coverage diagnostic and is not the primary sensitivity set unless explicitly approved."),
  "",
  "## Mapping Notes",
  "",
  "- CHARLS, CLHLS, and SHARE use the canonical column names directly in the analysis parquet.",
  "- MHAS uses r3-prefixed canonical columns and contains 27 of the 41 canonical stems.",
  "- HRS and KLoSA contain additional cohort-specific substitute columns. Those columns are retained in the source FI files but are not counted as canonical FI_core coverage without an explicit equivalence decision.",
  ""
)
report_path <- "D:/AI_project/project3/docs/fi_core_enumeration_2026-07-29.md"
writeLines(md, report_path, useBytes = TRUE)
cat("FI_CORE_ENUMERATION_PASS\n")
cat("FI_core:", sum(matrix$in_FI_core), "\n")
cat("FI_core_5of6:", sum(matrix$in_FI_core_5of6), "\n")
cat("CSV:", csv_path, "\n")
cat("REPORT:", report_path, "\n")