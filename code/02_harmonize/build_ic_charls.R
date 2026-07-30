# build_ic_charls.R — CHARLS 2011 Intrinsic Capacity (5 domains)
# Spec: docs/ic_specification_2026-07-27.md | D-014: min-max, fixed CHARLS params
# Output: data/analysis/charls_ic_2011_2026-07-29.parquet

suppressPackageStartupMessages({
  library(haven); library(arrow)
})
OUT_PARQUET <- "D:/AI_project/project3/data/analysis/charls_ic_2011_2026-07-29.parquet"
OUT_PARAMS  <- "D:/AI_project/project3/results/ic/ic_minmax_params_2026-07-29.csv"
dir.create("D:/AI_project/project3/results/ic", showWarnings=FALSE)
cat("=== CHARLS IC Construction ===\n")

# ── 1. Load raw DTA (READ ONLY) ───────────────────────────────────────────────
bio <- as.data.frame(read_dta("D:/AI_project/sql/CHARLS/2011/biomarkers.dta"))
hsf <- as.data.frame(read_dta("D:/AI_project/sql/CHARLS/2011/health_status_and_functioning.dta"))
bio$id <- trimws(as.character(bio$ID))
hsf$id <- trimws(as.character(hsf$ID))
cat(sprintf("bio: %d rows | hsf: %d rows\n", nrow(bio), nrow(hsf)))

# Helper: clean numeric, replace sentinel codes with NA
clean_num <- function(x, max_valid=990) {
  x <- suppressWarnings(as.numeric(x))
  x[x > max_valid] <- NA_real_; x
}

# ── 2. LOCOMOTION ─────────────────────────────────────────────────────────────
# Grip strength
lgrip <- rowMeans(cbind(clean_num(bio$qc003), clean_num(bio$qc005)), na.rm=TRUE)
rgrip <- rowMeans(cbind(clean_num(bio$qc004), clean_num(bio$qc006)), na.rm=TRUE)
lgrip[is.nan(lgrip)] <- NA_real_; rgrip[is.nan(rgrip)] <- NA_real_
dh <- suppressWarnings(as.integer(bio$qc002))  # 1=right, 2=left, 3+/NA=max
grip <- ifelse(!is.na(dh) & dh==1, rgrip,
         ifelse(!is.na(dh) & dh==2, lgrip, pmax(lgrip, rgrip, na.rm=FALSE)))
cat(sprintf("  Grip valid: %d (median %.1f kg)\n", sum(!is.na(grip)), median(grip, na.rm=TRUE)))

# Gait speed (2.5m walk, CHARLS protocol)
WALK_DIST <- 2.5
t1 <- clean_num(bio$qg002, 100); t2 <- clean_num(bio$qg003, 100)
t1[t1 <= 0] <- NA_real_; t2[t2 <= 0] <- NA_real_
gait_time  <- rowMeans(cbind(t1, t2), na.rm=TRUE); gait_time[is.nan(gait_time)] <- NA_real_
walk_aid   <- suppressWarnings(as.integer(bio$qg005))
gait_time[!is.na(walk_aid) & walk_aid >= 2] <- NA_real_  # exclude walking aid users
gait_speed <- ifelse(!is.na(gait_time) & gait_time > 0, WALK_DIST/gait_time, NA_real_)
cat(sprintf("  Gait valid: %d (median %.2f m/s)\n", sum(!is.na(gait_speed)), median(gait_speed, na.rm=TRUE)))

# Balance (0=failed semi-tandem, 1=passed semi, 2=passed full-tandem)
qd <- suppressWarnings(as.integer(bio$qd002)); qd[qd > 5] <- NA_integer_
qe <- suppressWarnings(as.integer(bio$qe002)); qe[qe > 5] <- NA_integer_
balance <- ifelse(is.na(qd), NA_real_,
            ifelse(qd == 5, 0,           # failed semi
             ifelse(is.na(qe) | qe==5, 1, 2)))  # passed semi only vs both
cat(sprintf("  Balance valid: %d\n", sum(!is.na(balance))))

# ── 3. VITALITY ───────────────────────────────────────────────────────────────
# Peak flow: best of 3 trials
pf_vals <- cbind(clean_num(bio$qb002), clean_num(bio$qb003), clean_num(bio$qb004))
pf <- apply(pf_vals, 1, max, na.rm=TRUE); pf[is.infinite(pf)] <- NA_real_
cat(sprintf("  Peak flow valid: %d (median %.0f L/min)\n", sum(!is.na(pf)), median(pf, na.rm=TRUE)))

# BMI vitality: triangular function centred at 22 kg/m²
ht <- clean_num(bio$qi002, 300); wt <- clean_num(bio$ql002, 300)
ht[ht < 100 | ht > 220] <- NA_real_; wt[wt < 20 | wt > 200] <- NA_real_
bmi <- wt / (ht/100)^2
ic_bmi_raw <- pmax(0, 100 - 5 * abs(bmi - 22))  # peak=100 at BMI=22, 0 at BMI=2/42
cat(sprintf("  BMI valid: %d (median %.1f kg/m²)\n", sum(!is.na(bmi)), median(bmi, na.rm=TRUE)))

# ── 4. COGNITION ──────────────────────────────────────────────────────────────
# Immediate recall: dc006sX = 1 when word recalled, NA when not → count non-NAs
dc6_cols <- grep("^dc006s[0-9]", names(hsf), value=TRUE)
imrc <- rowSums(!is.na(data.frame(lapply(dc6_cols, function(v)
  ifelse(as.numeric(zap_labels(hsf[[v]])) == 1, 1L, NA_integer_)))))
cat(sprintf("  Immediate recall: %d items, N_valid=%d, median=%.0f\n",
            length(dc6_cols), sum(imrc>0 | TRUE), median(imrc, na.rm=TRUE)))

# Delayed recall: same with dc027sX
dc27_cols <- grep("^dc027s[0-9]", names(hsf), value=TRUE)
dlrc <- rowSums(!is.na(data.frame(lapply(dc27_cols, function(v)
  ifelse(as.numeric(zap_labels(hsf[[v]])) == 1, 1L, NA_integer_)))))

# Serial 7: exact-match scoring (expected: 93, 86, 79, 72, 65)
ser7_expected <- c(dc019=93, dc020=86, dc021=79, dc022=72, dc023=65)
ser7 <- rowSums(data.frame(mapply(function(v, e) {
  x <- suppressWarnings(as.numeric(zap_labels(hsf[[v]])))
  as.integer(!is.na(x) & x == e)
}, names(ser7_expected), ser7_expected)), na.rm=TRUE)

# Drawing (dc025): 1=incorrect, 2=correct
draw <- as.integer(suppressWarnings(as.numeric(zap_labels(hsf$dc025))) == 2)
draw[is.na(hsf$dc025)] <- NA_integer_

# Total cognition (max = dc6_items + dc27_items + 5 + 1)
COG_MAX <- length(dc6_cols) + length(dc27_cols) + 5 + 1
cog_total <- imrc + dlrc + ser7 + draw
cog_total[is.na(imrc) & is.na(dlrc)] <- NA_real_
cat(sprintf("  Cognition total: max=%d  N_valid=%d  median=%.0f\n",
            COG_MAX, sum(!is.na(cog_total)), median(cog_total, na.rm=TRUE)))

# ── 5. PSYCHOLOGY (CES-D-10) ──────────────────────────────────────────────────
cesd_cols <- c("dc009","dc010","dc011","dc012","dc013","dc014","dc015","dc016","dc017","dc018")
cesd_vals <- data.frame(lapply(cesd_cols, function(v)
  suppressWarnings(as.numeric(zap_labels(hsf[[v]])))))
cesd_sum  <- rowSums(cesd_vals, na.rm=FALSE)
cesd_sum[rowSums(!is.na(cesd_vals)) < 8] <- NA_real_
ic_psych_raw <- (40 - cesd_sum) / 30 * 100  # reverse: higher = better
cat(sprintf("  CES-D valid: %d  IC_psych median=%.0f\n",
            sum(!is.na(ic_psych_raw)), median(ic_psych_raw, na.rm=TRUE)))

# ── 6. SENSORY ────────────────────────────────────────────────────────────────
ic_sens_item <- function(v) {
  x <- suppressWarnings(as.numeric(zap_labels(hsf[[v]])))
  ifelse(x == 6, 0, ifelse(x >= 1 & x <= 5, (5-x)/4*100, NA_real_))
}
ic_near    <- ic_sens_item("da032")
ic_far     <- ic_sens_item("da034")
ic_hear    <- ic_sens_item("da039")
ic_sensory_raw <- rowMeans(cbind(ic_near, ic_far, ic_hear), na.rm=TRUE)
ic_sensory_raw[is.nan(ic_sensory_raw)] <- NA_real_
cat(sprintf("  Sensory valid: %d  median=%.0f\n",
            sum(!is.na(ic_sensory_raw)), median(ic_sensory_raw, na.rm=TRUE)))

# ── 7. Min-max normalize each component (fixed parameters from CHARLS 60+) ────
# Load FI parquet to get 60+ FI-eligible subset
fi <- as.data.frame(read_parquet("D:/AI_project/project3/data/analysis/charls_fi_2011_2026-07-27.parquet"))
elig_ids <- fi$id[fi$age >= 60 & !fi$fi_excluded]

# Assemble per-person dataframe from bio (ID-indexed)
df_bio <- data.frame(
  id     = bio$id,
  grip   = grip,
  gait   = gait_speed,
  balance= balance,
  pf     = pf,
  ic_bmi = ic_bmi_raw,
  row.names = NULL
)

# Assemble per-person from hsf
df_hsf <- data.frame(
  id        = hsf$id,
  cog_total = cog_total,
  ic_psych  = ic_psych_raw,
  ic_near   = ic_near,
  ic_far    = ic_far,
  ic_hear   = ic_hear,
  ic_sensory= ic_sensory_raw,
  row.names = NULL
)

# Join bio + hsf on id, then filter to 60+ eligible
df <- merge(df_bio, df_hsf, by="id", all=TRUE)
df_60 <- df[df$id %in% elig_ids, ]
cat(sprintf("\n60+ eligible in IC dataset: %d\n", nrow(df_60)))

# ── Fixed min/max for cross-cohort normalisation (D-014) ──────────────────────
# Use CHARLS 60+ distribution: fix min at 1st pct, max at 99th pct
pct <- function(x, p) quantile(x, p/100, na.rm=TRUE)

# Grip: min=5 kg, max=60 kg (clinically fixed, not sample-based)
GRIP_MIN <- 5;  GRIP_MAX <- 60
ic_grip_n  <- pmin(100, pmax(0, (df_60$grip  - GRIP_MIN) / (GRIP_MAX - GRIP_MIN)*100))

# Gait speed: min=0.1 m/s, max=2.0 m/s
GAIT_MIN <- 0.1; GAIT_MAX <- 2.0
ic_gait_n  <- pmin(100, pmax(0, (df_60$gait  - GAIT_MIN) / (GAIT_MAX - GAIT_MIN)*100))

# Balance: 0/1/2 → 0/50/100
ic_bal_n   <- df_60$balance / 2 * 100

# Peak flow: min=50 L/min, max=500 L/min
PF_MIN <- 50; PF_MAX <- 500
ic_pf_n    <- pmin(100, pmax(0, (df_60$pf    - PF_MIN) / (PF_MAX - PF_MIN)*100))

# BMI IC: already 0-100 (triangular centred at 22 kg/m²)
ic_bmi_n   <- df_60$ic_bmi

# Cognition: sum/33 * 100
ic_cog_n   <- pmin(100, df_60$cog_total / COG_MAX * 100)

# Psychology, Sensory: already 0-100
ic_psych_n <- df_60$ic_psych
ic_sens_n  <- df_60$ic_sensory

# ── 8. Aggregate domains ──────────────────────────────────────────────────────
loco  <- rowMeans(cbind(ic_grip_n, ic_gait_n, ic_bal_n), na.rm=TRUE)
vital <- rowMeans(cbind(ic_pf_n,   ic_bmi_n),            na.rm=TRUE)
cog   <- ic_cog_n
psych <- ic_psych_n
sens  <- ic_sens_n
loco[is.nan(loco)]  <- NA_real_; vital[is.nan(vital)] <- NA_real_

ic_total <- rowMeans(cbind(loco, vital, cog, psych, sens), na.rm=FALSE)
ic_total_partial <- rowMeans(cbind(loco, vital, cog, psych, sens), na.rm=TRUE)
ic_total_partial[rowSums(!is.na(cbind(loco,vital,cog,psych,sens))) < 3] <- NA_real_

cat(sprintf("  IC_total (complete 5-domain): N=%d  median=%.1f\n",
            sum(!is.na(ic_total)), median(ic_total, na.rm=TRUE)))
cat(sprintf("  IC_total (>=3 domains): N=%d  median=%.1f\n",
            sum(!is.na(ic_total_partial)), median(ic_total_partial, na.rm=TRUE)))

# Domain breakdown
cat("  Domain availability (60+ eligible):\n")
dom_df <- data.frame(Locomotion=loco, Vitality=vital, Cognition=cog, Psychology=psych, Sensory=sens)
for (nm in names(dom_df)) {
  v <- dom_df[[nm]]
  cat(sprintf("    %s: valid=%d (%.0f%%)  median=%.1f
",
              nm, sum(!is.na(v)), mean(!is.na(v))*100, median(v, na.rm=TRUE)))
}

# ── 9. Save min-max params CSV (for CLHLS normalisation) ─────────────────────
params <- data.frame(
  component=c("grip","gait","balance","pf","bmi","cognition","cesd","sensory"),
  min=c(GRIP_MIN,GAIT_MIN,0,PF_MIN,NA,0,10,NA),
  max=c(GRIP_MAX,GAIT_MAX,2,PF_MAX,NA,COG_MAX,40,NA),
  notes=c("kg fixed","m/s fixed","0-2 ordinal","L/min fixed",
          "triangular BMI=22 centre","sum/33","10-40 reversed","(5-x)/4 Likert"),
  stringsAsFactors=FALSE
)
write.csv(params, OUT_PARAMS, row.names=FALSE)
cat(sprintf("  Params saved: %s\n", OUT_PARAMS))

# ── 10. Save parquet ──────────────────────────────────────────────────────────
out <- data.frame(
  id=df_60$id, age=fi$age[match(df_60$id, fi$id)],
  ic_locomotion=loco, ic_vitality=vital, ic_cognition=cog,
  ic_psychology=psych, ic_sensory=sens,
  ic_total=ic_total, ic_total_partial=ic_total_partial,
  grip=df_60$grip, gait_speed=df_60$gait, balance=df_60$balance,
  peak_flow=df_60$pf, bmi=bmi[match(df_60$id, bio$id)],
  cog_total=df_60$cog_total, cesd_sum=cesd_sum[match(df_60$id, hsf$id)]
)
write_parquet(out, OUT_PARQUET)
cat(sprintf("\nSaved: %s  (%d rows × %d cols)\n", OUT_PARQUET, nrow(out), ncol(out)))
