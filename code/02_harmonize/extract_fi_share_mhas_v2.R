#!/usr/bin/env Rscript
# extract_fi_share_mhas_v2.R — FIXED: multi-category vars mapped to 0-1 before FI

suppressPackageStartupMessages({library(haven); library(arrow); library(dplyr)})

PROJ   <- "D:/AI_project/project3"
OUTDIR <- file.path(PROJ, "data/analysis")
RESDIR <- file.path(PROJ, "results/fi_validation_cohorts")
dir.create(RESDIR, showWarnings=FALSE, recursive=TRUE)

FI_STEMS <- c(
  "hibpe","diabe","cancre","lunge","hearte","stroke","psyche","arthre",
  "dyslipe","livere","kidneye","digeste","asthmae",
  "dressa","batha","eata","beda","toilta","urina",
  "housewka","mealsa","shopa","moneya","medsa",
  "walk100a","walk1kma","joga","climsa","chaira","stoopa","armsa","lifta","dimea",
  "dsight","nsight","hearing","shlt","painfr","fall","slfmem","mbmi"
)

# Stems that need (val-1)/(max-1) mapping instead of raw values
LIKERT5_STEMS <- c("dsight","nsight","hearing","shlt","slfmem")
# dsight/nsight/hearing/shlt: 1=excellent/good … 5=poor  →  (val-1)/4
# Also: 6=legally blind in some cohorts → 1.0

recode_likert5 <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(x == 6, 1.0,                           # legally blind / worst
         ifelse(x >= 1 & x <= 5, (x-1)/4, NA_real_))
}

# BMI: apply after extracting from height/weight or directly if available
# For SHARE/MHAS the mbmi variable may already exist as computed BMI
recode_bmi <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  ifelse(!is.na(x) & (x < 18.5 | x >= 30), 1L,
         ifelse(!is.na(x) & x >= 18.5 & x < 30, 0L, NA_integer_))
}

compute_fi_v2 <- function(df, stems, wave, id_col, age_col) {
  vars    <- paste0("r", wave, stems)
  found   <- vars[vars %in% names(df)]
  missing <- stems[!vars %in% names(df)]
  threshold <- ceiling(0.8 * length(found))
  if (length(missing)) message("  NOT FOUND (", length(missing), "): ",
                                paste(head(missing,8), collapse=", "))
  message("  threshold: >=", threshold, " of ", length(found), " found")

  # Extract found columns, convert to numeric
  m <- df %>% select(all_of(unique(c(id_col, age_col, found)))) %>%
    mutate(across(all_of(found[found %in% names(.)]),
                  ~suppressWarnings(as.numeric(.))))

  # Apply special recoding BEFORE computing FI
  for (s in stems) {
    v <- paste0("r", wave, s)
    if (!v %in% names(m)) next
    if (s %in% LIKERT5_STEMS) {
      m[[v]] <- recode_likert5(m[[v]])
    } else if (s == "mbmi") {
      m[[v]] <- recode_bmi(m[[v]])
    }
    # All others stay as-is (should already be 0/1 from Gateway)
  }

  mat      <- m %>% select(all_of(found[found %in% names(m)]))
  n_valid  <- rowSums(!is.na(mat))
  fi       <- ifelse(n_valid >= threshold,
                     rowSums(mat, na.rm=TRUE) / n_valid, NA_real_)
  m$fi_full      <- fi
  m$fi_n_valid   <- n_valid
  m$fi_n_found   <- length(found)
  m$fi_threshold <- threshold
  m$fi_excluded  <- n_valid < threshold
  m$age          <- suppressWarnings(as.numeric(m[[age_col]]))
  m$age_60_plus  <- !is.na(m$age) & m$age >= 60
  list(data=m, found_n=length(found), missing=missing, threshold=threshold)
}

# ── SHARE wave 4, r4iwy==2011 ─────────────────────────────────────────────────
cat("\n=== SHARE wave 4 (r4iwy==2011) ===\n")
nm_sh   <- names(read_dta("D:/AI_project/sql/share harmonised/GH_SHARE_g.dta", n_max=0))
need_sh <- c("mergeid","r4iwy","r4agey", paste0("r4", FI_STEMS))
avail_sh <- need_sh[need_sh %in% nm_sh]
d_sh <- read_dta("D:/AI_project/sql/share harmonised/GH_SHARE_g.dta",
                 col_select=all_of(avail_sh)) %>%
        filter(suppressWarnings(as.integer(r4iwy)) == 2011)
cat("  rows after 2011 filter:", nrow(d_sh), "\n")
res_sh <- compute_fi_v2(d_sh, FI_STEMS, 4, "mergeid", "r4agey")
fi_sh  <- res_sh$data
cat("  stems:", res_sh$found_n, "/ 41   threshold:", res_sh$threshold, "\n")
cat("  FI-eligible 60+ N:", sum(fi_sh$age_60_plus & !fi_sh$fi_excluded, na.rm=TRUE), "\n")
cat("  FI median (60+)  :", round(median(fi_sh$fi_full[fi_sh$age_60_plus], na.rm=TRUE), 3), "\n")
cat("  FI max           :", round(max(fi_sh$fi_full, na.rm=TRUE), 3), "  [should be <=1]\n")
write_parquet(fi_sh, file.path(OUTDIR, "share_fi_2011_2026-07-28.parquet"))

# ── MHAS wave 3, D-022 age ────────────────────────────────────────────────────
cat("\n=== MHAS wave 3 (D-022 age derivation) ===\n")
nm_mh   <- names(read_dta("D:/AI_project/sql/MHAS/H_MHAS_c2.dta", n_max=0))
need_mh <- c("rahhidnp","r3agey","rabyear","r3iwy", paste0("r3", FI_STEMS))
avail_mh <- need_mh[need_mh %in% nm_mh]
d_mh <- read_dta("D:/AI_project/sql/MHAS/H_MHAS_c2.dta", col_select=all_of(avail_mh)) %>%
  mutate(
    r3agey_raw = suppressWarnings(as.numeric(r3agey)),
    rabyear    = suppressWarnings(as.numeric(rabyear)),
    r3iwy      = suppressWarnings(as.numeric(r3iwy)),
    age_mhas   = case_when(
      !is.na(r3agey_raw) & r3agey_raw >= 20 & r3agey_raw <= 110 ~ r3agey_raw,
      !is.na(rabyear) & !is.na(r3iwy) ~ as.numeric(r3iwy - rabyear),
      TRUE ~ NA_real_)
  )
res_mh <- compute_fi_v2(d_mh, FI_STEMS, 3, "rahhidnp", "age_mhas")
fi_mh  <- res_mh$data
cat("  stems:", res_mh$found_n, "/ 41   threshold:", res_mh$threshold, "\n")
cat("  FI-eligible 60+ N:", sum(fi_mh$age_60_plus & !fi_mh$fi_excluded, na.rm=TRUE), "\n")
cat("  FI median (60+)  :", round(median(fi_mh$fi_full[fi_mh$age_60_plus], na.rm=TRUE), 3), "\n")
cat("  FI max           :", round(max(fi_mh$fi_full, na.rm=TRUE), 3), "  [should be <=1]\n")
write_parquet(fi_mh, file.path(OUTDIR, "mhas_fi_2012_2026-07-28.parquet"))

cat("\nDone.\n")
