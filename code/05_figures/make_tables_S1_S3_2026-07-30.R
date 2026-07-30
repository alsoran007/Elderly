#!/usr/bin/env Rscript
# =============================================================================
# Supplementary Tables S1-S3 generation
# Paper 1 · 2026-07-30
#
# S1: Final 41-item FI specification (domain, Gateway source line, raw variables)
# S2: FI_core coverage matrix (positive rates x 6 cohorts, core membership flags)
# S3: H6 Spearman rank-concordance matrix (full 6x6 with summary statistics)
#
# Outputs both CSV (for submission) and Markdown (for review) per table.
#
# Run from project root:
#   Rscript --vanilla code/05_figures/make_tables_S1_S3_2026-07-30.R
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(tidyr)
})

args <- commandArgs(FALSE); farg <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(farg)) dirname(normalizePath(sub("^--file=", "", farg[1]))) else getwd()
root   <- normalizePath(file.path(script_dir, "..", ".."), mustWork = TRUE)
OUTDIR <- file.path(root, "results", "tables")
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)
stamp  <- "2026-07-30"

md_lines <- character(0)
add <- function(...) md_lines <<- c(md_lines, ...)

# Minimal markdown table writer
md_table <- function(df, align = NULL) {
  hdr <- paste0("| ", paste(names(df), collapse = " | "), " |")
  if (is.null(align)) align <- rep("---", ncol(df))
  sep <- paste0("| ", paste(align, collapse = " | "), " |")
  rows <- apply(df, 1, function(r) {
    r[is.na(r)] <- "—"
    paste0("| ", paste(trimws(as.character(r)), collapse = " | "), " |")
  })
  c(hdr, sep, rows)
}

# =============================================================================
# TABLE S1 — Final 41-item FI specification
# =============================================================================
cat("Building Table S1 (FI 41-item specification)...\n")

defs <- read.csv(file.path(root, "docs", "gateway_charls_fi_defs_2026-07-27.csv"),
                 stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM")
names(defs)[1] <- "harmonized_var"

# Three items excluded from the 44-candidate list at D-020
excluded <- c("hearaid", "hlthlm_c", "mbmicata")
excl_reason <- c(
  hearaid   = "Excluded: positive rate 0.56% (< 1% Searle criterion); cross-cohort non-comparability",
  hlthlm_c  = "Excluded: missing rate 35.1% (> 30% threshold)",
  mbmicata  = "Excluded: construct redundant with continuous mbmi"
)

defs <- defs |>
  mutate(
    stem = gsub("^r\\{wave\\}", "", harmonized_var),
    in_final_41 = !(stem %in% excluded),
    note = ifelse(stem %in% excluded, excl_reason[stem], "")
  )

domain_label <- c(
  comorbidity = "Chronic conditions",
  adl         = "ADL",
  iadl        = "IADL",
  mobility    = "Mobility",
  sensory     = "Sensory",
  general     = "General health",
  cognition   = "Cognitive proxy"
)

s1 <- defs |>
  mutate(Domain = ifelse(domain %in% names(domain_label),
                         domain_label[domain], domain)) |>
  arrange(match(domain, names(domain_label)), stem) |>
  transmute(
    Stem            = stem,
    Domain,
    Concept         = concept,
    `Gateway .do line` = source_line,
    `Raw variable(s)`  = raw_vars,
    `In final 41-item FI` = ifelse(in_final_41, "Yes", "No"),
    Note            = note
  )

write.csv(s1, file.path(OUTDIR, paste0("tableS1_fi_specification_", stamp, ".csv")),
          row.names = FALSE, na = "")

n_final <- sum(s1$`In final 41-item FI` == "Yes")
cat(sprintf("  S1: %d candidate items -> %d in final FI (%d excluded)\n",
            nrow(s1), n_final, nrow(s1) - n_final))

dom_counts <- s1 |> filter(`In final 41-item FI` == "Yes") |> count(Domain, name = "Items")

add("# Supplementary Table S1. Final 41-item frailty index specification",
    "",
    paste0("All deficit definitions were extracted programmatically from the Gateway to Global Aging ",
           "harmonised CHARLS Version D.2 Stata script (`bbxleyec.do`, 2025-09 release) using ",
           "`code/02_harmonize/extract_gateway_fi_defs.py`. The `Gateway .do line` column gives the ",
           "line number of the defining statement, enabling item-by-item audit."),
    "",
    paste0("**Item count**: ", nrow(s1), " candidates screened; **", n_final,
           "** retained in the final locked specification (decision D-020, 2026-07-28); ",
           nrow(s1) - n_final, " excluded (see Note column)."),
    "",
    "**Domain distribution of the final 41 items**",
    "",
    md_table(dom_counts, c("---", "---:")),
    "",
    "**Full item specification**",
    "",
    md_table(s1),
    "",
    paste0("Abbreviations: ADL, activities of daily living; IADL, instrumental activities of daily living; ",
           "FI, frailty index; BMI, body mass index."),
    "",
    "---",
    "")

# =============================================================================
# TABLE S2 — FI_core coverage matrix
# =============================================================================
cat("Building Table S2 (FI_core coverage matrix)...\n")

cov <- read.csv(file.path(root, "results", "fi_core",
                          "fi_core_coverage_matrix_2026-07-29.csv"),
                stringsAsFactors = FALSE, check.names = FALSE)

cohorts <- c("CHARLS", "CLHLS", "KLoSA", "HRS", "SHARE", "MHAS")

fmt_rate <- function(x) ifelse(is.na(x), NA_character_, sprintf("%.3f", x))

s2 <- cov |>
  arrange(desc(n_cohorts), stem) |>
  mutate(across(all_of(cohorts), fmt_rate)) |>
  transmute(
    Stem = stem,
    CHARLS, CLHLS, KLoSA, HRS, SHARE, MHAS,
    `Cohorts with data` = n_cohorts,
    `FI_core (6/6)`     = ifelse(in_FI_core  == TRUE | in_FI_core  == "TRUE", "Yes", ""),
    `FI_core_5of6`      = ifelse(in_FI_core5 == TRUE | in_FI_core5 == "TRUE", "Yes", "")
  )

write.csv(s2, file.path(OUTDIR, paste0("tableS2_fi_core_coverage_", stamp, ".csv")),
          row.names = FALSE, na = "")

n_core  <- sum(s2$`FI_core (6/6)` == "Yes")
n_core5 <- sum(s2$`FI_core_5of6`  == "Yes")
cat(sprintf("  S2: %d stems | FI_core=%d | FI_core_5of6=%d\n",
            nrow(s2), n_core, n_core5))

add("# Supplementary Table S2. Cross-cohort FI item coverage and positive rates",
    "",
    paste0("Cell values give the **positive rate** (proportion coded as a deficit) among ",
           "participants aged >= 60 years in each cohort. Blank cells indicate the item was ",
           "unavailable, or present as an all-missing column, in that cohort's harmonised file."),
    "",
    paste0("**FI_core** (", n_core, " items) = stems available with a valid positive rate in all ",
           "six cohorts under strict column-name matching; used in sensitivity analysis SA-1 and ",
           "in the H6 feature-importance analysis. **FI_core_5of6** (", n_core5,
           " items) = stems available in at least five cohorts."),
    "",
    paste0("Coverage is constrained mainly by MHAS (27 of 41 canonical stems) and by KLoSA, whose ",
           "mobility items use non-canonical column names. Two items are present but all-missing ",
           "by design and were verified as intentional (decision D-028 addendum): `joga` in SHARE ",
           "(no `r4joga` field in the Gateway wave-4 file) and `dimea` in CLHLS (no coin-pickup ",
           "measurement at the 2011/12 baseline)."),
    "",
    md_table(s2),
    "",
    paste0("**Measurement-equivalence caution.** Two chronic-condition items show outlying ",
           "cross-cohort rates that likely reflect differential diagnosis or ascertainment rather ",
           "than true prevalence: `hibpe` (KLoSA 0.067 vs HRS 0.682) and `arthre` (KLoSA 0.025 vs ",
           "HRS 0.672). Both are retained in FI_full but interpreted with caution; this ",
           "heterogeneity is one mechanism underlying the H3 null result."),
    "",
    "---",
    "")

# =============================================================================
# TABLE S3 — H6 Spearman concordance matrix
# =============================================================================
cat("Building Table S3 (H6 Spearman matrix)...\n")

sp <- read.csv(file.path(root, "results", "h6_shap",
                          "h6_spearman_matrix_2026-07-29.csv"),
               row.names = 1, check.names = FALSE)

sp_m <- as.matrix(sp)
off  <- sp_m[upper.tri(sp_m)]

s3 <- data.frame(Cohort = rownames(sp_m), stringsAsFactors = FALSE)
for (cc in cohorts) s3[[cc]] <- sprintf("%.4f", sp_m[, cc])
# Blank out the redundant upper triangle for readability
for (i in seq_len(nrow(s3))) {
  for (j in seq_along(cohorts)) {
    if (j > i) s3[i, cohorts[j]] <- ""
  }
}

write.csv(
  data.frame(Cohort = rownames(sp_m), sp_m, check.names = FALSE),
  file.path(OUTDIR, paste0("tableS3_h6_spearman_", stamp, ".csv")),
  row.names = FALSE
)

med_off <- median(off); min_off <- min(off); max_off <- max(off)
which_min <- which(sp_m == min_off & upper.tri(sp_m), arr.ind = TRUE)[1, ]
which_max <- which(sp_m == max_off & upper.tri(sp_m), arr.ind = TRUE)[1, ]

cat(sprintf("  S3: median rho=%.4f | range %.4f-%.4f\n", med_off, min_off, max_off))

summ <- data.frame(
  Statistic = c("Number of cohort pairs", "Median rho", "Minimum rho",
                "Maximum rho", "Interquartile range",
                "Pre-registered H6 threshold", "H6 concordance criterion"),
  Value = c(
    length(off),
    sprintf("%.4f", med_off),
    sprintf("%.4f (%s-%s)", min_off, rownames(sp_m)[which_min[1]], colnames(sp_m)[which_min[2]]),
    sprintf("%.4f (%s-%s)", max_off, rownames(sp_m)[which_max[1]], colnames(sp_m)[which_max[2]]),
    sprintf("%.4f-%.4f", quantile(off, .25), quantile(off, .75)),
    "median rho >= 0.70",
    "Not met"
  ),
  stringsAsFactors = FALSE
)

add("# Supplementary Table S3. Cross-cohort concordance of FI item importance (H6)",
    "",
    paste0("Pairwise Spearman rank correlations between cohort-specific orderings of feature ",
           "importance. Importance was quantified as |beta_standardised| from a logistic model ",
           "fitted separately in each cohort on FI_core (", n_core, " items) plus age; for a ",
           "main-effects generalised linear model this is the exact linear-SHAP importance."),
    "",
    "**Summary statistics**",
    "",
    md_table(summ, c("---", "---")),
    "",
    "**Full 6 x 6 matrix** (lower triangle; diagonal = 1 by construction)",
    "",
    md_table(s3),
    "",
    paste0("H6 specified two criteria: (i) age ranks in the top three in every cohort, and ",
           "(ii) median pairwise Spearman rho >= 0.70. Criterion (i) was met — age ranked **first** ",
           "in all six cohorts. Criterion (ii) was not met (observed median ",
           sprintf("%.2f", med_off), "), so **H6 is partially supported**."),
    "",
    paste0("KLoSA showed the weakest concordance with other cohorts (rho = ",
           sprintf("%.2f", sp_m["KLoSA", "HRS"]), " with HRS; ",
           sprintf("%.2f", sp_m["KLoSA", "CHARLS"]), " with CHARLS), attributable to floor effects ",
           "in its ADL items (positive rates 2-7%) among a relatively young, community-dwelling ",
           "sample (median age ~71 years). The Western and Latin American cohorts were mutually ",
           "more concordant (SHARE-HRS ", sprintf("%.2f", sp_m["SHARE", "HRS"]),
           "; SHARE-MHAS ", sprintf("%.2f", sp_m["SHARE", "MHAS"]), ")."),
    "",
    paste0("*Scope caveat*: |beta_standardised| captures main-effect contributions only and is ",
           "insensitive to non-linearity and interactions. These results are exploratory; SHAP ",
           "values from non-linear learners may reveal additional structure."),
    "")

# =============================================================================
# Write combined Markdown
# =============================================================================
md_path <- file.path(OUTDIR, paste0("supplementary_tables_S1_S3_", stamp, ".md"))
writeLines(md_lines, md_path, useBytes = TRUE)

cat("\nOK  Supplementary tables written to", OUTDIR, "\n")
cat("  tableS1_fi_specification_",  stamp, ".csv\n", sep = "")
cat("  tableS2_fi_core_coverage_",  stamp, ".csv\n", sep = "")
cat("  tableS3_h6_spearman_",       stamp, ".csv\n", sep = "")
cat("  supplementary_tables_S1_S3_", stamp, ".md  (combined, review copy)\n", sep = "")
