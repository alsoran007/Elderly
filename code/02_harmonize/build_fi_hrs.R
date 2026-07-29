#!/usr/bin/env Rscript
# build_fi_hrs.R — HRS 2012 FI from RAND Fat File h12f3a.dta

suppressPackageStartupMessages({library(haven); library(arrow); library(dplyr)})

PROJ   <- "D:/AI_project/project3"
OUTDIR <- file.path(PROJ, "data/analysis")
RESDIR <- file.path(PROJ, "results/fi_hrs")
dir.create(RESDIR, showWarnings=FALSE, recursive=TRUE)
dir.create(file.path(RESDIR,"tables"), showWarnings=FALSE)

f <- "D:/AI_project/sql/HRS Products/RAND HRS Products(原始)/2012 RAND HRS Fat File/h12f3a.dta"
cat("Reading RAND HRS 2012 fat file (this may take 30-60s)...\n")
d <- read_dta(f)
nm <- names(d)
lb <- sapply(d, function(x){a<-attr(x,"label"); if(is.null(a)) "" else a})
cat("Loaded:", nrow(d), "rows,", length(nm), "vars\n\n")

# Helper: find RAND variable by label keyword
find_var <- function(kw, prefix=NULL) {
  h <- grep(kw, lb, ignore.case=TRUE, value=FALSE)
  if (!is.null(prefix)) h <- h[startsWith(nm[h], prefix)]
  nm[h]
}

# Helper: binary comorbidity (1=yes, any other valid = no)
recode_comorb <- function(x) {
  x <- suppressWarnings(as.integer(x))
  ifelse(x == 1, 1, ifelse(x %in% c(4,5), 0, NA_integer_))
}

# Helper: ADL difficulty (1=yes, 5=no, 6/7=can't/don't do → deficit=1)
recode_adl <- function(x) {
  x <- suppressWarnings(as.integer(x))
  ifelse(x == 1 | x == 6, 1, ifelse(x == 5, 0, ifelse(x == 7, 0, NA_integer_)))
}

# Helper: IADL (same as ADL but 7=don't do → 0 for IADL)
recode_iadl <- function(x) {
  x <- suppressWarnings(as.integer(x))
  ifelse(x == 1 | x == 6, 1, ifelse(x %in% c(5,7), 0, NA_integer_))
}

cat("=== Building FI deficits ===\n")
fi <- d %>% select(hhidpn, na019) %>%
  mutate(age = suppressWarnings(as.numeric(na019)))

# --- Comorbidity (13 items) ---
# hibpe: nc005 high blood pressure
fi$hibpe   <- recode_comorb(d$nc005)
# diabe: nc010 diabetes
nc_diab <- find_var("diabetes", "nc"); nc_diab <- nc_diab[!grepl("age|before|medic|insulin", lb[match(nc_diab,nm)], ignore.case=TRUE)][1]
cat("diabe ->", nc_diab, "|", lb[match(nc_diab,nm)], "\n")
fi$diabe   <- if (!is.na(nc_diab)) recode_comorb(d[[nc_diab]]) else NA_integer_
# cancre: nc018 cancer
fi$cancre  <- recode_comorb(d$nc018)
# lunge: nc030 lung disease
fi$lunge   <- recode_comorb(d$nc030)
# hearte: nc036 heart condition (most current)
fi$hearte  <- recode_comorb(d$nc036)
# stroke: nc053
fi$stroke  <- recode_comorb(d$nc053)
# psyche: nc065 emotional/psychiatric
fi$psyche  <- recode_comorb(d$nc065)
# arthre: nc070 arthritis
fi$arthre  <- recode_comorb(d$nc070)
# dyslipe: search cholesterol diagnosis
nc_chol <- find_var("cholesterol|high.*fat|lipid|dyslip", "nc"); nc_chol <- nc_chol[1]
cat("dyslipe ->", nc_chol, "|", if(!is.na(nc_chol)) lb[match(nc_chol,nm)] else "NOT FOUND", "\n")
fi$dyslipe <- if (!is.na(nc_chol)) recode_comorb(d[[nc_chol]]) else NA_integer_
# livere, kidneye, digeste, asthmae — search
for (stem in c("livere","kidneye","digeste","asthmae")) {
  kw <- switch(stem, livere="liver", kidneye="kidney", digeste="digest|stomach ulcer", asthmae="asthma")
  v  <- find_var(kw, "nc")[1]
  cat(stem, "->", v, "|", if(!is.na(v)) substr(lb[match(v,nm)],1,40) else "NOT FOUND", "\n")
  fi[[stem]] <- if (!is.na(v)) recode_comorb(d[[v]]) else NA_integer_
}

# --- ADL (6 items) ---
fi$dressa <- recode_adl(d$ng014)   # dressing
fi$batha  <- recode_adl(d$ng021)   # bathing
# eata: search
ng_eat <- find_var("eating|difficulty.*eat", "ng")[1]
cat("eata ->", ng_eat, "|", if(!is.na(ng_eat)) lb[match(ng_eat,nm)] else "NOT FOUND", "\n")
fi$eata   <- if (!is.na(ng_eat)) recode_adl(d[[ng_eat]]) else NA_integer_
fi$beda   <- recode_adl(d$ng025)   # getting in/out bed
# toilta
ng_toil <- find_var("toilet|using toilet|lavatory", "ng")[1]
cat("toilta ->", ng_toil, "|", if(!is.na(ng_toil)) lb[match(ng_toil,nm)] else "NOT FOUND", "\n")
fi$toilta <- if (!is.na(ng_toil)) recode_adl(d[[ng_toil]]) else NA_integer_
# urina: incontinence — nc087 (1=yes, 5=no); NOT ng search which found nothing
fi$urina  <- recode_comorb(d$nc087)

# --- IADL (5 items) ---
fi$housewka <- NA_integer_           # no separate housework item in RAND HRS 2012 IADL battery
fi$mealsa   <- recode_iadl(d$ng041) # meal preparation difficulty
fi$shopa    <- recode_iadl(d$ng044) # grocery shopping
# moneya: managing money
ng_money <- find_var("money|financ|pay bill|manage finance", "ng")[1]
cat("moneya ->", ng_money, "|", if(!is.na(ng_money)) lb[match(ng_money,nm)] else "NOT FOUND", "\n")
fi$moneya   <- if (!is.na(ng_money)) recode_iadl(d[[ng_money]]) else NA_integer_
# medsa: taking medication
ng_med <- find_var("medication|taking.*med|managing.*med", "ng")[1]
cat("medsa ->", ng_med, "|", if(!is.na(ng_med)) lb[match(ng_med,nm)] else "NOT FOUND", "\n")
fi$medsa    <- if (!is.na(ng_med)) recode_iadl(d[[ng_med]]) else NA_integer_

# --- Mobility (9 items) ---
fi$walk100a <- recode_adl(d$ng003)   # walk 1 block
fi$walk1kma <- recode_adl(d$ng001)   # walk several blocks
fi$joga     <- NA_integer_           # jogging — not in HRS
fi$climsa   <- recode_adl(d$ng007)   # climb 1 flight
fi$chaira   <- recode_adl(d$ng005)   # rise from chair
fi$stoopa   <- recode_adl(d$ng008)   # stooping/kneeling
fi$armsa    <- { v <- find_var("arm above|overhead|reach.*should", "ng")[1]
                 cat("armsa ->", v, "|", if(!is.na(v)) lb[match(v,nm)] else "NOT FOUND", "\n")
                 if (!is.na(v)) recode_adl(d[[v]]) else NA_integer_ }
fi$lifta    <- recode_adl(d$ng010)   # push/pull (≈ lift heavy)
fi$dimea    <- recode_adl(d$ng012)   # pick up dime

# --- Sensory (3 items) ---
# dsight/nsight: eyesight rating (1=excellent…5=poor, 6=blind)
ng_sight <- find_var("eyesight|vision", "nc")[1]
cat("dsight/nsight ->", ng_sight, "|", if(!is.na(ng_sight)) lb[match(ng_sight,nm)] else "NOT FOUND", "\n")
recode_sight <- function(x) {
  x <- suppressWarnings(as.integer(x)); ifelse(x>=4, 1, ifelse(x<=3, 0, NA_integer_))
}
fi$dsight <- if (!is.na(ng_sight)) recode_sight(d[[ng_sight]]) else NA_integer_
fi$nsight <- fi$dsight  # HRS has one combined eyesight rating
# hearing
nc_hear <- find_var("hearing.*fair|rate.*hearing|hearing.*problem", "nc")[1]
cat("hearing ->", nc_hear, "|", if(!is.na(nc_hear)) lb[match(nc_hear,nm)] else "NOT FOUND", "\n")
fi$hearing <- if (!is.na(nc_hear)) recode_sight(d[[nc_hear]]) else NA_integer_

# --- General health (4 items) ---
# shlt: self-rated health (1=excellent…5=poor)
nc_shlt <- find_var("rate.*health|health.*excel|self.*health", "nc")[1]
cat("shlt ->", nc_shlt, "|", if(!is.na(nc_shlt)) lb[match(nc_shlt,nm)] else "NOT FOUND", "\n")
fi$shlt <- if (!is.na(nc_shlt)) {
  x <- suppressWarnings(as.integer(d[[nc_shlt]]))
  ifelse(x>=1 & x<=5, (x-1)/4, NA_real_)
} else NA_real_
# painfr: chronic pain
nc_pain <- find_var("pain.*most|troubled.*pain|chronic pain", "nc")[1]
cat("painfr ->", nc_pain, "|", if(!is.na(nc_pain)) lb[match(nc_pain,nm)] else "NOT FOUND", "\n")
fi$painfr <- if (!is.na(nc_pain)) recode_comorb(d[[nc_pain]]) else NA_integer_
# fall: falling
nc_fall <- find_var("fall|fell down", "nc")[1]
cat("fall ->", nc_fall, "|", if(!is.na(nc_fall)) lb[match(nc_fall,nm)] else "NOT FOUND", "\n")
fi$fall <- if (!is.na(nc_fall)) recode_comorb(d[[nc_fall]]) else NA_integer_
# mbmi: use nc141(height ft) + nc142(height in) + nc139(weight lbs)
{
  ht_ft  <- suppressWarnings(as.numeric(d$nc141))
  ht_in  <- suppressWarnings(as.numeric(d$nc142))
  wt_lb  <- suppressWarnings(as.numeric(d$nc139))
  ht_tot <- ifelse(!is.na(ht_ft) & ht_ft %in% 4:6 & !is.na(ht_in) & ht_in %in% 0:11,
                   ht_ft*12 + ht_in, NA_real_)
  wt_kg  <- ifelse(!is.na(wt_lb) & wt_lb >= 60 & wt_lb <= 500, wt_lb*0.453592, NA_real_)
  bmi_v  <- wt_kg / ((ht_tot * 0.0254)^2)
  fi$mbmi <- ifelse(!is.na(bmi_v), ifelse(bmi_v < 18.5 | bmi_v >= 30, 1L, 0L), NA_integer_)
  cat("mbmi non-NA:", sum(!is.na(fi$mbmi)),
      "  deficit rate:", round(mean(fi$mbmi, na.rm=TRUE), 3), "\n")
}

# --- Cognition (1 item) ---
# slfmem: self-rated memory (1=excellent…5=poor)
nc_mem <- find_var("rate.*memory|memory.*excel|self.*memory", "nc")[1]
cat("slfmem ->", nc_mem, "|", if(!is.na(nc_mem)) lb[match(nc_mem,nm)] else "NOT FOUND", "\n")
fi$slfmem <- if (!is.na(nc_mem)) {
  x <- suppressWarnings(as.integer(d[[nc_mem]]))
  ifelse(x>=1 & x<=5, (x-1)/4, NA_real_)
} else NA_real_

# ── Compute FI ──────────────────────────────────────────────────────────────
fi_stems <- c("hibpe","diabe","cancre","lunge","hearte","stroke","psyche","arthre",
              "dyslipe","livere","kidneye","digeste","asthmae",
              "dressa","batha","eata","beda","toilta","urina",
              "housewka","mealsa","shopa","moneya","medsa",
              "walk100a","walk1kma","joga","climsa","chaira","stoopa","armsa","lifta","dimea",
              "dsight","nsight","hearing","shlt","painfr","fall","slfmem","mbmi")

fi_mat <- fi %>% select(all_of(fi_stems)) %>%
  mutate(across(everything(), ~suppressWarnings(as.numeric(.))))
fi$fi_n_valid  <- rowSums(!is.na(fi_mat))
fi$fi_n_found  <- sum(sapply(fi_stems, function(s) !all(is.na(fi[[s]]))))
threshold      <- ceiling(0.8 * fi$fi_n_found[1])
fi$fi_threshold<- threshold
fi$fi_full     <- ifelse(fi$fi_n_valid >= threshold,
                         rowSums(fi_mat, na.rm=TRUE) / fi$fi_n_valid, NA_real_)
fi$fi_excluded <- fi$fi_n_valid < threshold
fi$age_60_plus <- !is.na(fi$age) & fi$age >= 60

cat("\n=== FI Summary ===\n")
cat("stems with any data:", fi$fi_n_found[1], "/ 41\n")
cat("threshold:", threshold, "\n")
cat("FI-eligible (all):", sum(!fi$fi_excluded, na.rm=TRUE), "\n")
cat("FI-eligible 60+ :", sum(fi$age_60_plus & !fi$fi_excluded, na.rm=TRUE), "\n")
cat("FI median (all) :", round(median(fi$fi_full, na.rm=TRUE), 3), "\n")
cat("FI median (60+) :", round(median(fi$fi_full[fi$age_60_plus], na.rm=TRUE), 3), "\n")

# ── Stem mapping table ───────────────────────────────────────────────────────
map <- data.frame(fi_stem=fi_stems, stringsAsFactors=FALSE)
map$has_data <- sapply(fi_stems, function(s) !all(is.na(fi[[s]])))
write.csv(map, file.path(RESDIR,"tables","hrs_fi_stem_availability_2026-07-28.csv"), row.names=FALSE)

# ── Save parquet ─────────────────────────────────────────────────────────────
write_parquet(fi, file.path(OUTDIR, "hrs_fi_2012_2026-07-28.parquet"))
cat("\nSaved: hrs_fi_2012_2026-07-28.parquet\n")
