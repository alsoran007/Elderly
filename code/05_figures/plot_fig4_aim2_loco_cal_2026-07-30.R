#!/usr/bin/env Rscript
# =============================================================================
# Figure 4: Aim 2 LOCO — calibration panels (3 rounds × raw / L1)
# Paper 1 · 2026-07-30
#
# Layout: 3 rows (Rounds A / B / C) × 2 columns (Raw L0 / L1 recalibrated)
# For each panel: calibration decile points + loess smoother + diagonal
#
# Requires: the three LOCO model objects are NOT saved on disk, so this script
# re-derives predicted probabilities from the frozen Round-specific models
# using the same parquet inputs used in run_aim2_loco_2026-07-29.R.
#
# Run from project root:
#   Rscript --vanilla code/05_figures/plot_fig4_aim2_loco_cal_2026-07-30.R
# =============================================================================

suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(ggplot2); library(patchwork)
})

args <- commandArgs(FALSE); farg <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(farg)) dirname(normalizePath(sub("^--file=", "", farg[1]))) else getwd()
root   <- normalizePath(file.path(script_dir, "..", ".."), mustWork = TRUE)
d_dir  <- file.path(root, "data", "analysis")
a2_dir <- file.path(root, "results", "aim2")
OUTDIR <- file.path(a2_dir, "figures")
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)
stamp  <- "2026-07-30"

# ── 1. Helpers ─────────────────────────────────────────────────────────────────
read_a <- function(fn) as.data.frame(read_parquet(file.path(d_dir, fn)))
clean_id <- function(x) {
  # Handle haven_labelled (from .sav/.dta via haven) before coercing to character
  if (inherits(x, "haven_labelled") || inherits(x, "labelled")) {
    x <- unclass(x)
  }
  y <- trimws(as.character(x))
  y[is.na(x)] <- NA_character_
  y
}

auc_safe <- function(y, p) {
  k <- !is.na(y) & is.finite(p)
  if (length(unique(y[k])) < 2) return(NA_real_)
  as.numeric(pROC::auc(pROC::roc(y[k], p[k], quiet=TRUE, direction="auto")))
}

wilson_ci <- function(x, n, z=1.96) {
  p_hat <- x/n; denom <- 1 + z^2/n
  centre <- (p_hat + z^2/(2*n))/denom
  half   <- z * sqrt(p_hat*(1-p_hat)/n + z^2/(4*n^2)) / denom
  data.frame(lo = pmax(0,centre-half), hi = pmin(1,centre+half))
}

# Calibration deciles from vector of y and p
cal_deciles <- function(y, p, n_dec=10) {
  dec <- dplyr::ntile(p, n_dec)
  do.call(rbind, lapply(seq_len(n_dec), function(d) {
    idx <- dec == d
    obs <- mean(y[idx]); pre <- mean(p[idx]); n <- sum(idx)
    ci  <- wilson_ci(round(obs*n), n)
    data.frame(decile=d, predicted=pre, observed=obs, n=n, lo=ci$lo, hi=ci$hi)
  }))
}

# L1 intercept recalibration
l1_recal <- function(y, p_frozen) {
  lp <- qlogis(p_frozen)
  alpha <- coef(glm(y ~ offset(lp), family=binomial()))[1]
  plogis(lp + alpha)
}

# ── 2. Load parquets ───────────────────────────────────────────────────────────
# CHARLS person-period
pp    <- read_a("charls_person_period_2026-07-27.parquet")
fi_ch <- read_a("charls_fi_2011_2026-07-27.parquet")
pp$pid_key   <- clean_id(pp$pid)
fi_ch$id_key <- clean_id(fi_ch$id)
fi_ch$id_key <- ifelse(nchar(fi_ch$id_key)==11L,
                       paste0(substr(fi_ch$id_key,1,9),"0",substr(fi_ch$id_key,10,11)),
                       fi_ch$id_key)
fi_ok_ch <- fi_ch |> filter(!is.na(age), age>=60, !is.na(fi_excluded), !fi_excluded) |>
            transmute(pid_key=id_key, fi_full)
ch <- pp |> filter(!is.na(age_60_plus), age_60_plus, period %in% c(1L,2L)) |>
     inner_join(fi_ok_ch, by="pid_key") |>
     filter(if_all(c("event","fi_full","age","female","period"), ~!is.na(.x))) |>
     mutate(female=as.numeric(female))

# CHARLS binary outcome (one row per person: died in period 1 or 2)
ch_person <- ch |> group_by(pid_key) |>
  summarise(event_4y = as.integer(any(event==1)),
            age = first(age), fi_full = first(fi_full), .groups="drop")

# CLHLS
fi_cl  <- read_a("clhls_fi_2011_2026-07-29.parquet")
out_cl <- read_a("clhls_outcome_2026-07-28.parquet")
fi_cl$id_key  <- clean_id(fi_cl$id)
out_cl$id_key <- clean_id(out_cl$id)
cl <- fi_cl |> filter(!is.na(age), age>=60, !is.na(fi_excluded), !fi_excluded) |>
     transmute(id_key, age, fi_full) |>
     inner_join(out_cl |> filter(!is.na(event_4y), prebaseline_death==0) |>
                  transmute(id_key, event_4y=as.numeric(event_4y)),
                by="id_key") |>
     filter(if_all(c("age","fi_full","event_4y"), ~!is.na(.x)))

# KLoSA — replicate the exact loading logic of run_aim2_loco_2026-07-29.R
# (outcome comes from the audit CSV, not a parquet; event_exact_4y is the
#  strict <=1461-day definition used in the Aim 2 analysis)
fi_kl  <- read_a("klosa_fi_2012_2026-07-29.parquet")
kl_aud <- read.csv(file.path(root, "results", "current_four_year_event_audit",
                             "klosa_four_year_event_audit_2026-07-28.csv"),
                   stringsAsFactors = FALSE)
kl_aud$event <- kl_aud$event_exact_4y == "True"
kl_aud$pre   <- kl_aud$death_before_baseline == "True"
kl_aud$pid_n <- as.numeric(kl_aud$person_id)

zap <- function(x) if (inherits(x, "haven_labelled") || inherits(x, "labelled")) unclass(x) else x
fi_kl$pid_n <- as.numeric(zap(fi_kl$pid))

kl <- merge(
  fi_kl[fi_kl$age_60_plus == TRUE & !fi_kl$fi_excluded, c("pid_n", "fi_full", "age")],
  kl_aud[!kl_aud$pre, c("pid_n", "event")],
  by = "pid_n"
)
kl <- kl[!is.na(kl$event) & !is.na(kl$fi_full) & !is.na(kl$age), ]
kl$event_4y <- as.numeric(kl$event)
kl$age      <- as.numeric(zap(kl$age))
kl$fi_full  <- as.numeric(zap(kl$fi_full))
cat(sprintf("Data loaded: CHARLS persons=%d(%d events), CLHLS=%d(%d), KLoSA=%d(%d)\n",
    nrow(ch_person), sum(ch_person$event_4y),
    nrow(cl), sum(cl$event_4y), nrow(kl), sum(kl$event_4y)))

# ── 3. Fit three LOCO models (event_4y ~ fi_full + age, person-level) ──────────
# Round A: train CLHLS+KLoSA  → test CHARLS
trA <- bind_rows(cl |> transmute(fi_full, age, event=event_4y),
                 kl |> transmute(fi_full, age, event=event_4y))
fitA <- glm(event ~ fi_full + age, data=trA, family=binomial())
predA_raw <- predict(fitA, newdata=ch_person |> transmute(fi_full, age), type="response")
predA_l1  <- l1_recal(ch_person$event_4y, predA_raw)
cat(sprintf("Round A: train n=%d, test CHARLS n=%d, C_raw=%.4f\n",
    nrow(trA), nrow(ch_person), auc_safe(ch_person$event_4y, predA_raw)))

# Round B: train CHARLS+KLoSA → test CLHLS
trB <- bind_rows(ch_person |> transmute(fi_full, age, event=event_4y),
                 kl |> transmute(fi_full, age, event=event_4y))
fitB <- glm(event ~ fi_full + age, data=trB, family=binomial())
predB_raw <- predict(fitB, newdata=cl |> transmute(fi_full, age), type="response")
predB_l1  <- l1_recal(cl$event_4y, predB_raw)
cat(sprintf("Round B: train n=%d, test CLHLS n=%d, C_raw=%.4f\n",
    nrow(trB), nrow(cl), auc_safe(cl$event_4y, predB_raw)))

# Round C: train CHARLS+CLHLS → test KLoSA
trC <- bind_rows(ch_person |> transmute(fi_full, age, event=event_4y),
                 cl |> transmute(fi_full, age, event=event_4y))
fitC <- glm(event ~ fi_full + age, data=trC, family=binomial())
predC_raw <- predict(fitC, newdata=kl |> transmute(fi_full, age), type="response")
predC_l1  <- l1_recal(kl$event_4y, predC_raw)
cat(sprintf("Round C: train n=%d, test KLoSA n=%d, C_raw=%.4f\n",
    nrow(trC), nrow(kl), auc_safe(kl$event_4y, predC_raw)))

# ── 4. Build calibration data ──────────────────────────────────────────────────
make_panel_df <- function(y, p_raw, p_l1, round_lbl, test_lbl) {
  bind_rows(
    cal_deciles(y, p_raw) |> mutate(version="Raw (L0)", round=round_lbl, test=test_lbl),
    cal_deciles(y, p_l1)  |> mutate(version="L1 recalibrated", round=round_lbl, test=test_lbl)
  )
}

cal_all <- bind_rows(
  make_panel_df(ch_person$event_4y, predA_raw, predA_l1, "Round A", "Test: CHARLS\n(Train: CLHLS+KLoSA)"),
  make_panel_df(cl$event_4y,        predB_raw, predB_l1, "Round B", "Test: CLHLS\n(Train: CHARLS+KLoSA)"),
  make_panel_df(kl$event_4y,        predC_raw, predC_l1, "Round C", "Test: KLoSA\n(Train: CHARLS+CLHLS)")
) |>
  mutate(
    round   = factor(round,   levels=c("Round A","Round B","Round C")),
    version = factor(version, levels=c("Raw (L0)","L1 recalibrated"))
  )

# ── 5. Plot ────────────────────────────────────────────────────────────────────
# Annotate OE per panel
oe_tbl <- cal_all |>
  group_by(round, test, version) |>
  summarise(oe = sum(observed*n)/sum(predicted*n), .groups="drop") |>
  mutate(label = sprintf("O:E = %.3f", oe))

p4 <- ggplot(cal_all, aes(predicted, observed)) +
  geom_abline(slope=1, intercept=0, linetype="dashed", colour="grey70", linewidth=0.35) +
  geom_errorbar(aes(ymin=lo, ymax=hi), width=0.015, linewidth=0.35,
                colour="#2166AC", alpha=0.75) +
  geom_point(colour="#2166AC", size=1.8) +
  geom_smooth(method="loess", span=1.0, se=FALSE, colour="#D94801",
              linewidth=0.55, linetype="solid") +
  geom_text(data=oe_tbl,
            aes(x=0.78, y=0.04, label=label),
            inherit.aes=FALSE, size=2.5, colour="grey20", hjust=0) +
  facet_grid(round ~ version, labeller = labeller(
    round   = setNames(levels(cal_all$round), levels(cal_all$round)),
    version = setNames(levels(cal_all$version), levels(cal_all$version))
  )) +
  scale_x_continuous(limits=c(0,1), breaks=seq(0,1,.25),
                     labels=scales::label_percent(accuracy=1),
                     expand=expansion(mult=.01)) +
  scale_y_continuous(limits=c(0,1), breaks=seq(0,1,.25),
                     labels=scales::label_percent(accuracy=1),
                     expand=expansion(mult=.01)) +
  labs(x="Predicted 4-year mortality",
       y="Observed 4-year mortality",
       caption=paste0(
         "Points: observed vs. predicted mortality by decile of predicted risk. Error bars: 95% Wilson CI.\n",
         "Orange: loess smoother. Dashed: perfect calibration (O:E = 1).\n",
         "Left column: frozen LOCO model (L0). Right column: intercept-updated (L1). C-index unchanged by L1 recalibration."
       )) +
  theme_bw(base_size=9.5, base_family="sans") +
  theme(
    strip.background  = element_rect(fill="grey93", colour="grey70"),
    strip.text        = element_text(face="bold", size=8.5),
    panel.grid.minor  = element_blank(),
    panel.grid.major  = element_line(colour="grey93", linewidth=0.3),
    panel.spacing     = unit(4, "mm"),
    axis.text         = element_text(size=7.5),
    axis.title        = element_text(size=9),
    plot.caption      = element_text(size=7, hjust=0, colour="grey45", margin=margin(t=5))
  )

# ── 6. Save ────────────────────────────────────────────────────────────────────
tiff_path <- file.path(OUTDIR, paste0("fig4_aim2_loco_calibration_", stamp, ".tiff"))
pdf_path  <- file.path(OUTDIR, paste0("fig4_aim2_loco_calibration_", stamp, ".pdf"))
ggsave(tiff_path, p4, width=180, height=185, units="mm", dpi=600, compression="lzw")
ggsave(pdf_path,  p4, width=180, height=185, units="mm")
cat("✔  Figure 4 saved:\n   ", tiff_path, "\n   ", pdf_path, "\n")
