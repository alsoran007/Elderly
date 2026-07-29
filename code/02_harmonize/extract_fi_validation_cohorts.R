#!/usr/bin/env Rscript
# extract_fi_share_mhas.R — FI for SHARE (w4/2011) and MHAS (w3/2012)
# Uses cohort-specific 80% threshold (not fixed 33) for missing stems

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
  "dsight","nsight","hearing",
  "shlt","painfr","fall","slfmem","mbmi"
)

compute_fi <- function(df, stems, wave, id_col, age_col) {
  vars      <- paste0("r", wave, stems)
  found     <- vars[vars %in% names(df)]
  missing   <- stems[!vars %in% names(df)]
  threshold <- ceiling(0.8 * length(found))   # 80% of AVAILABLE stems
  if (length(missing)) message("  NOT FOUND (", length(missing), "): ",
                                paste(head(missing,8), collapse=", "))
  message("  threshold: >=", threshold, " of ", length(found), " found stems")

  cols_to_select <- unique(c(id_col, age_col, found))
  cols_to_select <- cols_to_select[cols_to_select %in% names(df)]
  m <- df %>% select(all_of(cols_to_select)) %>%
    mutate(across(all_of(found[found %in% names(.)]),
                  ~suppressWarnings(as.numeric(.))))
  mat     <- m %>% select(all_of(found[found %in% names(m)]))
  n_valid <- rowSums(!is.na(mat))
  fi      <- ifelse(n_valid >= threshold,
                    rowSums(mat, na.rm=TRUE) / n_valid, NA_real_)
  m$fi_full      <- fi
  m$fi_n_valid   <- n_valid
  m$fi_n_found   <- length(found)
  m$fi_threshold <- threshold
  m$fi_excluded  <- n_valid < threshold
  m$age          <- if (age_col %in% names(m)) suppressWarnings(as.numeric(m[[age_col]])) else NA_real_
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
cat("  r4agey present:", "r4agey" %in% names(d_sh),
    "  non-missing:", sum(!is.na(suppressWarnings(as.numeric(d_sh$r4agey)))), "\n")
res_sh <- compute_fi(d_sh, FI_STEMS, 4, "mergeid", "r4agey")
fi_sh  <- res_sh$data
cat("  stems:", res_sh$found_n, "/", length(FI_STEMS),
    "  threshold:", res_sh$threshold, "\n")
cat("  FI-eligible 60+ N:", sum(fi_sh$age_60_plus & !fi_sh$fi_excluded, na.rm=TRUE), "\n")
cat("  FI median (60+)  :", round(median(fi_sh$fi_full[fi_sh$age_60_plus], na.rm=TRUE), 3), "\n")
write_parquet(fi_sh, file.path(OUTDIR, "share_fi_2011_2026-07-28.parquet"))

# ── MHAS wave 3, D-022 age ────────────────────────────────────────────────────
cat("\n=== MHAS wave 3 (D-022 age derivation) ===\n")
nm_mh   <- names(read_dta("D:/AI_project/sql/MHAS/H_MHAS_c2.dta", n_max=0))
need_mh <- c("rahhidnp","r3agey","rabyear","r3iwy", paste0("r3", FI_STEMS))
avail_mh <- need_mh[need_mh %in% nm_mh]
d_mh <- read_dta("D:/AI_project/sql/MHAS/H_MHAS_c2.dta",
                 col_select=all_of(avail_mh)) %>%
  mutate(
    r3agey_raw = suppressWarnings(as.numeric(r3agey)),
    rabyear    = suppressWarnings(as.numeric(rabyear)),
    r3iwy      = suppressWarnings(as.numeric(r3iwy)),
    age_mhas   = case_when(
      !is.na(r3agey_raw) & r3agey_raw >= 20 & r3agey_raw <= 110 ~ r3agey_raw,
      !is.na(rabyear) & !is.na(r3iwy) ~ as.numeric(r3iwy - rabyear),
      TRUE ~ NA_real_)
  )
cat("  age_mhas non-missing:", sum(!is.na(d_mh$age_mhas)), "\n")
cat("  age_mhas 60+:", sum(d_mh$age_mhas >= 60, na.rm=TRUE), "\n")
res_mh <- compute_fi(d_mh, FI_STEMS, 3, "rahhidnp", "age_mhas")
fi_mh  <- res_mh$data
cat("  stems:", res_mh$found_n, "/", length(FI_STEMS),
    "  threshold:", res_mh$threshold, "\n")
cat("  FI-eligible 60+ N:", sum(fi_mh$age_60_plus & !fi_mh$fi_excluded, na.rm=TRUE), "\n")
cat("  FI median (60+)  :", round(median(fi_mh$fi_full[fi_mh$age_60_plus], na.rm=TRUE), 3), "\n")
write_parquet(fi_mh, file.path(OUTDIR, "mhas_fi_2012_2026-07-28.parquet"))

cat("\nDone.\n")
