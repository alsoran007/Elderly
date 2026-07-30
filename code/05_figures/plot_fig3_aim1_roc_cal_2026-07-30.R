#!/usr/bin/env Rscript
# =============================================================================
# Figure 3: Aim 1 — Model development ROC (left) + CLHLS calibration (right)
# Paper 1 · 2026-07-30
#
# Left  : ROC curves, Model A (demographic) vs Model B (FI), CHARLS dev set
# Right : Calibration-in-the-large decile plot, CLHLS external validation
#
# Run from project root:
#   Rscript --vanilla code/05_figures/plot_fig3_aim1_roc_cal_2026-07-30.R
# =============================================================================

suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(pROC); library(ggplot2); library(patchwork)
})

args <- commandArgs(FALSE); farg <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(farg)) dirname(normalizePath(sub("^--file=", "", farg[1]))) else getwd()
root   <- normalizePath(file.path(script_dir, "..", ".."), mustWork = TRUE)
d_dir  <- file.path(root, "data", "analysis")
a1_dir <- file.path(root, "results", "aim1")
OUTDIR <- file.path(root, "results", "aim1", "figures")
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)
stamp  <- "2026-07-30"

# ── 1. Rebuild CHARLS dev set (mirrors run_aim1_charls_clhls_v2) ──────────────
read_a <- function(fn) as.data.frame(read_parquet(file.path(d_dir, fn)))
pp    <- read_a("charls_person_period_2026-07-27.parquet")
fi_ch <- read_a("charls_fi_2011_2026-07-27.parquet")

clean_id <- function(x) { y <- trimws(as.character(x)); y[is.na(x)] <- NA_character_; y }
pp$pid_key   <- clean_id(pp$pid)
fi_ch$id_key <- clean_id(fi_ch$id)
fi_ch$id_key <- ifelse(nchar(fi_ch$id_key) == 11L,
                       paste0(substr(fi_ch$id_key,1,9),"0",substr(fi_ch$id_key,10,11)),
                       fi_ch$id_key)

fi_ok <- fi_ch |> filter(!is.na(age), age >= 60, !is.na(fi_excluded), !fi_excluded) |>
         transmute(pid_key = id_key, fi_full)

ch_cc <- pp |>
  filter(!is.na(age_60_plus), age_60_plus, period %in% c(1L,2L)) |>
  inner_join(fi_ok, by = "pid_key") |>
  filter(if_all(c("event","fi_full","age","female","period"), ~ !is.na(.x))) |>
  mutate(female = as.numeric(female))

cat(sprintf("CHARLS dev set: %d persons | %d pp rows | %d events\n",
            n_distinct(ch_cc$pid_key), nrow(ch_cc), sum(ch_cc$event==1)))

# ── 2. Fit models & extract ROC coords ───────────────────────────────────────
fit_a <- glm(event ~ age + female + factor(period),             data = ch_cc, family = binomial())
fit_b <- glm(event ~ fi_full + age + female + factor(period),   data = ch_cc, family = binomial())

roc_a <- roc(ch_cc$event, predict(fit_a, type="response"), quiet=TRUE, direction="auto")
roc_b <- roc(ch_cc$event, predict(fit_b, type="response"), quiet=TRUE, direction="auto")
C_a   <- as.numeric(auc(roc_a))
C_b   <- as.numeric(auc(roc_b))

# Convert to data.frame of (1-specificity, sensitivity) = (FPR, TPR)
roc_df <- bind_rows(
  data.frame(FPR = 1 - roc_a$specificities, TPR = roc_a$sensitivities,
             model = sprintf("Model A (C=%.3f)", C_a)),
  data.frame(FPR = 1 - roc_b$specificities, TPR = roc_b$sensitivities,
             model = sprintf("Model B + FI (C=%.3f)", C_b))
) |> arrange(model, FPR)

# ── 3. Left panel: ROC ────────────────────────────────────────────────────────
col_roc <- c("#636363", "#2166AC")    # grey for A, blue for B
names(col_roc) <- c(sprintf("Model A (C=%.3f)", C_a),
                    sprintf("Model B + FI (C=%.3f)", C_b))

p_roc <- ggplot(roc_df, aes(FPR, TPR, colour = model)) +
  geom_abline(slope=1, intercept=0, linetype="dashed", colour="grey70", linewidth=0.4) +
  geom_path(linewidth = 0.75) +
  annotate("text", x=0.72, y=0.10,
           label = sprintf("Delta C = %.3f", C_b - C_a),
           colour="#2166AC", size=3.2, fontface="bold") +
  scale_colour_manual(values = col_roc, name = NULL) +
  scale_x_continuous(limits=c(0,1), breaks=seq(0,1,.2), expand=expansion(mult=.01)) +
  scale_y_continuous(limits=c(0,1), breaks=seq(0,1,.2), expand=expansion(mult=.01)) +
  labs(x="1 − Specificity", y="Sensitivity",
       subtitle="A  ROC — CHARLS development set") +
  theme_bw(base_size=10, base_family="sans") +
  theme(legend.position=c(.62,.18), legend.key.size=unit(4,"mm"),
        legend.text=element_text(size=7.5), legend.background=element_rect(fill="white",colour="grey80"),
        panel.grid.minor=element_blank(),
        panel.grid.major=element_line(colour="grey93",linewidth=0.3),
        plot.subtitle=element_text(face="bold",size=9))

# ── 4. Right panel: CLHLS calibration deciles ─────────────────────────────────
cal <- read.csv(file.path(a1_dir, "aim1_calibration_deciles_clhls_2026-07-29.csv"))

# Confidence interval for observed proportion per decile (Wilson)
wilson_ci <- function(x, n, z=1.96) {
  p_hat <- x/n
  denom <- 1 + z^2/n
  centre <- (p_hat + z^2/(2*n))/denom
  half   <- z * sqrt(p_hat*(1-p_hat)/n + z^2/(4*n^2)) / denom
  data.frame(lo = pmax(0, centre-half), hi = pmin(1, centre+half))
}
ci <- wilson_ci(round(cal$observed * cal$n), cal$n)
cal$obs_lo <- ci$lo; cal$obs_hi <- ci$hi

p_cal <- ggplot(cal, aes(predicted, observed)) +
  geom_abline(slope=1, intercept=0, linetype="dashed", colour="grey70", linewidth=0.4) +
  geom_errorbar(aes(ymin=obs_lo, ymax=obs_hi), width=0.012, linewidth=0.45,
                colour="#2166AC", alpha=0.8) +
  geom_point(colour="#2166AC", size=2.5) +
  geom_smooth(method="loess", span=1.0, se=FALSE, colour="#D94801",
              linewidth=0.6, linetype="solid") +
  annotate("text", x=0.84, y=0.06,
           label="O:E = 1.247\nC = 0.839",
           size=2.8, colour="grey20", hjust=0) +
  scale_x_continuous(limits=c(0,1), breaks=seq(0,1,.2), expand=expansion(mult=.01)) +
  scale_y_continuous(limits=c(0,1), breaks=seq(0,1,.2), expand=expansion(mult=.01)) +
  labs(x="Predicted 4-year mortality", y="Observed 4-year mortality",
       subtitle="B  Calibration — CLHLS external validation (n=7,095)") +
  theme_bw(base_size=10, base_family="sans") +
  theme(panel.grid.minor=element_blank(),
        panel.grid.major=element_line(colour="grey93",linewidth=0.3),
        plot.subtitle=element_text(face="bold",size=9))

# ── 5. Combine & save ─────────────────────────────────────────────────────────
fig3 <- p_roc + p_cal +
  plot_annotation(
    caption = paste0(
      "A: ROC curves for Model A (age + sex + period) and Model B (FI + age + sex + period), CHARLS 2011 development set. ",
      "Apparent C-indices; optimism-corrected Model B C = 0.770 (bootstrap B=200, optimism 0.0004).\n",
      "B: Calibration-in-the-large for CLHLS external validation. Points = observed vs. predicted mortality by decile of predicted risk; ",
      "error bars 95% Wilson CI. Orange curve: loess smoother. Dashed line: perfect calibration."
    )
  ) &
  theme(plot.caption = element_text(size=7, hjust=0, colour="grey45", margin=margin(t=5)))

tiff_path <- file.path(OUTDIR, paste0("fig3_aim1_roc_calibration_", stamp, ".tiff"))
pdf_path  <- file.path(OUTDIR, paste0("fig3_aim1_roc_calibration_", stamp, ".pdf"))
ggsave(tiff_path, fig3, width=180, height=90, units="mm", dpi=600, compression="lzw")
ggsave(pdf_path,  fig3, width=180, height=90, units="mm")
cat("✔  Figure 3 saved:\n   ", tiff_path, "\n   ", pdf_path, "\n")
