#!/usr/bin/env Rscript
# =============================================================================
# Figure S3: IPCW sensitivity analysis (CLHLS missing outcomes)
# Paper 1 · 2026-07-30
#
# Panel A: censoring predictors (coefficient forest from the censoring model)
# Panel B: unweighted vs IPCW-weighted performance metrics (paired dots)
#
# Run from project root:
#   Rscript --vanilla code/05_figures/plot_figS3_ipcw_2026-07-30.R
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(ggplot2); library(patchwork)
})

args <- commandArgs(FALSE); farg <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(farg)) dirname(normalizePath(sub("^--file=", "", farg[1]))) else getwd()
root    <- normalizePath(file.path(script_dir, "..", ".."), mustWork = TRUE)
ipcw_dir<- file.path(root, "results", "ipcw")
OUTDIR  <- file.path(ipcw_dir, "figures")
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)
stamp   <- "2026-07-30"

# ── 1. Panel A: censoring-model coefficients (from D-032) ─────────────────────
# Coefficient values from results/ipcw/ipcw_clhls_report_2026-07-29.md.
# Standard errors not archived; forest plot replaced by a lollipop chart
# annotated with coefficient magnitude and significance.
cens <- data.frame(
  term  = c("FI (per unit)", "Age (per year)", "Female"),
  beta  = c( 0.652,  0.0115, -0.078),
  p     = c( 0.0004,  0.0001,  0.130),
  stringsAsFactors = FALSE
) |>
  mutate(
    sig  = p < 0.05,
    term = factor(term, levels = rev(term)),
    plab = ifelse(p < 0.001, "p<0.001",
                 ifelse(p < 0.01, sprintf("p=%.3f", p), sprintf("p=%.2f", p))),
    blab = sprintf("beta=%.3f", beta)
  )

pA <- ggplot(cens, aes(beta, term, colour = sig)) +
  geom_vline(xintercept = 0, linetype = "dashed",
             colour = "grey55", linewidth = 0.45) +
  geom_segment(aes(x = 0, xend = beta, y = term, yend = term),
               linewidth = 0.5, colour = "grey75") +
  geom_point(size = 3.0) +
  geom_text(aes(label = paste0(blab, "\n", plab)),
            hjust = ifelse(cens$beta >= 0, -0.15, 1.15),
            size = 2.4, colour = "grey25", lineheight = 0.85) +
  scale_colour_manual(values = c("TRUE" = "#B2182B", "FALSE" = "grey55"),
                      guide = "none") +
  scale_x_continuous(limits = c(-0.32, 1.05),
                     breaks = c(-0.2, 0, 0.2, 0.4, 0.6, 0.8)) +
  labs(x = "Log-odds of having an observed outcome", y = NULL,
       subtitle = "A  Censoring model: predictors of complete follow-up",
       caption = "Note: SE not archived; error bars omitted. Positive beta = predictor associated with higher probability of observed outcome.") +
  theme_bw(base_size = 9, base_family = "sans") +
  theme(panel.grid.minor  = element_blank(),
        panel.grid.major.y = element_blank(),
        panel.grid.major.x = element_line(colour = "grey93", linewidth = 0.3),
        axis.text = element_text(size = 8),
        axis.title.x = element_text(size = 8.5),
        plot.subtitle = element_text(face = "bold", size = 8.5),
        plot.caption  = element_text(size = 6.5, colour = "grey50", hjust = 0))

# ── 2. Panel B: metric comparison (unweighted vs IPCW) ────────────────────────
m <- read.csv(file.path(ipcw_dir, "ipcw_clhls_metrics_2026-07-29.csv"),
              stringsAsFactors = FALSE)

met <- m |>
  select(analysis, c_index, oe_ratio, cal_slope, brier, ipa) |>
  pivot_longer(-analysis, names_to = "metric", values_to = "value") |>
  mutate(
    analysis = factor(ifelse(analysis == "unweighted_aim1",
                             "Complete case", "IPCW weighted"),
                      levels = c("Complete case", "IPCW weighted")),
    metric = factor(metric,
      levels = c("c_index", "oe_ratio", "cal_slope", "brier", "ipa"),
      labels = c("C-index", "O:E ratio", "Cal. slope", "Brier", "IPA"))
  )

# Delta annotations per metric
delta <- met |>
  group_by(metric) |>
  summarise(d = value[analysis == "IPCW weighted"] - value[analysis == "Complete case"],
            ymax = max(value), .groups = "drop") |>
  mutate(lab = sprintf("%+.4f", d))

pB <- ggplot(met, aes(analysis, value, group = metric)) +
  geom_line(colour = "grey70", linewidth = 0.5) +
  geom_point(aes(colour = analysis), size = 2.6) +
  geom_text(data = delta, aes(x = 1.5, y = ymax, label = lab),
            inherit.aes = FALSE, size = 2.3, colour = "grey25",
            vjust = -0.8) +
  facet_wrap(~ metric, nrow = 1, scales = "free_y") +
  scale_colour_manual(values = c("Complete case" = "#2166AC",
                                 "IPCW weighted" = "#D94801"),
                      guide = "none") +
  scale_y_continuous(expand = expansion(mult = c(0.10, 0.20))) +
  scale_x_discrete(labels = c("Complete\ncase", "IPCW\nweighted")) +
  labs(x = NULL, y = NULL,
       subtitle = "B  Performance: complete-case vs IPCW-weighted (labels = difference)") +
  theme_bw(base_size = 9, base_family = "sans") +
  theme(strip.background = element_rect(fill = "grey93", colour = "grey70"),
        strip.text = element_text(face = "bold", size = 8),
        panel.grid.minor = element_blank(),
        panel.grid.major.x = element_blank(),
        panel.grid.major.y = element_line(colour = "grey93", linewidth = 0.3),
        axis.text.x = element_text(size = 7),
        axis.text.y = element_text(size = 7),
        panel.spacing.x = unit(3, "mm"),
        plot.subtitle = element_text(face = "bold", size = 8.5))

# ── 3. Combine & save ─────────────────────────────────────────────────────────
figS3 <- pA / pB +
  plot_layout(heights = c(1, 1.15)) +
  plot_annotation(caption = paste0(
    "Among 9,207 FI-eligible CLHLS participants aged >= 60, 2,112 (22.9%) had a missing four-year outcome. ",
    "Panel A: logistic model for the probability of having an observed outcome; higher FI and older age predicted\n",
    "complete follow-up (censoring is mildly informative, so MCAR does not hold). Censoring by FI tertile: 25.2% (low), 24.1% (middle), 19.6% (high).\n",
    "Panel B: inverse-probability-of-censoring weights (mean 1.29, max 1.45 after 99th-percentile truncation) changed every metric negligibly ",
    "(C-index +0.0008), indicating the complete-case Aim 1 results are robust to informative censoring."
  )) &
  theme(plot.caption = element_text(size = 6.8, hjust = 0, colour = "grey45",
                                    margin = margin(t = 5)))

tiff_path <- file.path(OUTDIR, paste0("figS3_ipcw_sensitivity_", stamp, ".tiff"))
pdf_path  <- file.path(OUTDIR, paste0("figS3_ipcw_sensitivity_", stamp, ".pdf"))
ggsave(tiff_path, figS3, width = 170, height = 130, units = "mm", dpi = 600, compression = "lzw")
ggsave(pdf_path,  figS3, width = 170, height = 130, units = "mm")
cat("OK  Figure S3 saved:\n   ", tiff_path, "\n   ", pdf_path, "\n")
