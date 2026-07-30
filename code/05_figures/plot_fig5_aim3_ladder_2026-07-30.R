# ============================================================
# Figure 5: L0–L3 Recalibration Ladder (HRS / SHARE / MHAS)
# Aim 3 — Asian pool → Western/Latin American external validation
# Paper 1 · 2026-07-30
#
# Run from project root:
#   Rscript --vanilla code/05_figures/plot_fig5_aim3_ladder_2026-07-30.R
# ============================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(ggplot2)
})

# ── 0. Paths ─────────────────────────────────────────────────────────────────
INPUT  <- "results/aim3/aim3_performance_table_2026-07-29.csv"
OUTDIR <- "results/aim3/figures"
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)

# ── 1. Read & reshape ─────────────────────────────────────────────────────────
raw <- read_csv(INPUT, show_col_types = FALSE) |>
  separate(label, into = c("cohort", "level"), sep = "_") |>
  mutate(
    cohort = factor(cohort,
                    levels = c("HRS",   "SHARE",          "MHAS"),
                    labels = c("HRS (USA)", "SHARE (Europe, 27 countries)", "MHAS (Mexico)")),
    level  = factor(level, levels = c("L0", "L1", "L2", "L3"))
  )

# Long format for faceting (exclude brier, cal_intercept — not plotted in main fig)
long_df <- raw |>
  select(cohort, level, c_index, c_lo, c_hi, oe, cal_slope, ipa) |>
  pivot_longer(
    cols      = c(c_index, oe, cal_slope, ipa),
    names_to  = "metric",
    values_to = "value"
  ) |>
  mutate(
    metric = factor(metric,
                    levels = c("c_index", "oe", "cal_slope", "ipa"),
                    labels = c("C-index", "O:E ratio",
                               "Calibration slope", "IPA"))
  )
# Note: c_lo / c_hi survive pivot_longer unchanged (not pivoted),
# so they are already available in long_df for error-bar use in ci_df.

# C-index subset (for error bars)
ci_df <- long_df |>
  filter(metric == "C-index")

# Non-C-index subset (no error bars)
other_df <- long_df |>
  filter(metric != "C-index")

# ── 2. Reference lines (per panel) ───────────────────────────────────────────
ref_df <- tibble(
  metric    = factor(c("O:E ratio", "Calibration slope", "IPA"),
                     levels = levels(long_df$metric)),
  yref      = c(1.0, 1.0, 0.0),
  line_col  = c("firebrick3", "firebrick3", "grey50"),
  line_type = c("dashed", "dashed", "dotted")
)

# ── 3. Colour / shape palette ─────────────────────────────────────────────────
cohort_pal <- c(
  "HRS (USA)"                        = "#C45000",   # deep orange
  "SHARE (Europe, 27 countries)"     = "#F4A010",   # amber
  "MHAS (Mexico)"                    = "#6BAF44"    # green — distinguishable from orange pair
)
cohort_shapes <- c(
  "HRS (USA)"                        = 16,   # circle
  "SHARE (Europe, 27 countries)"     = 17,   # triangle-up
  "MHAS (Mexico)"                    = 15    # square
)

# ── 4. Panel-level y-axis label helper ───────────────────────────────────────
# Each facet needs its own y-axis meaning; we use strip labels + axis label = NULL

# ── 5. Build plot ─────────────────────────────────────────────────────────────
p <- ggplot(mapping = aes(x = level, colour = cohort,
                          shape = cohort, group = cohort)) +

  # Reference lines (appear behind data)
  geom_hline(
    data        = ref_df,
    aes(yintercept = yref),
    colour      = ref_df$line_col,
    linetype    = ref_df$line_type,
    linewidth   = 0.45,
    inherit.aes = FALSE
  ) +

  # Lines for non-C-index metrics
  geom_line(
    data      = other_df,
    aes(y = value),
    linewidth = 0.75, alpha = 0.9
  ) +
  geom_point(
    data = other_df,
    aes(y = value),
    size = 2.4
  ) +

  # Lines + error bars for C-index
  geom_line(
    data      = ci_df,
    aes(y = value),
    linewidth = 0.75, alpha = 0.9
  ) +
  geom_point(
    data = ci_df,
    aes(y = value),
    size = 2.4
  ) +
  geom_errorbar(
    data  = ci_df,
    aes(y = value, ymin = c_lo, ymax = c_hi),
    width = 0.10, linewidth = 0.45
  ) +

  # Facets: 4 panels in a row, free y-axis scale
  facet_wrap(~ metric, nrow = 1, scales = "free_y") +

  # Scales
  scale_colour_manual(values = cohort_pal,    name = NULL) +
  scale_shape_manual(values  = cohort_shapes, name = NULL) +
  scale_x_discrete(
    name   = "Recalibration level",
    labels = c(
      "L0" = "L0\n(frozen)",
      "L1" = "L1\n(intercept)",
      "L2" = "L2\n(slope)",
      "L3" = "L3\n(full)"
    )
  ) +
  labs(
    y       = NULL,
    caption = paste0(
      "L0 = frozen Asian-pool model; L1 = intercept update (event-rate calibration); ",
      "L2 = slope recalibration; L3 = full logistic recalibration in target cohort.\n",
      "Dashed red line: O:E = 1.0 (ideal calibration) and slope = 1.0. ",
      "Dotted grey line: IPA = 0 (null-model baseline). ",
      "Error bars: 95% bootstrap CI for C-index.\n",
      "IPA = Index of Prediction Accuracy (Nagelkerke-scaled Brier improvement over null model). ",
      "N: HRS = 10,707; SHARE = 36,352; MHAS = 9,081."
    )
  ) +

  theme_bw(base_size = 10, base_family = "sans") +
  theme(
    strip.background  = element_rect(fill = "grey93", colour = "grey70"),
    strip.text        = element_text(face = "bold", size = 10),
    panel.grid.minor  = element_blank(),
    panel.grid.major  = element_line(colour = "grey92", linewidth = 0.3),
    legend.position   = "bottom",
    legend.box        = "horizontal",
    legend.key.size   = unit(4, "mm"),
    legend.text       = element_text(size = 8.5),
    legend.spacing.x  = unit(3, "mm"),
    plot.caption      = element_text(size = 7, hjust = 0, colour = "grey45",
                                     margin = margin(t = 6)),
    axis.title.x      = element_text(size = 9, margin = margin(t = 4)),
    axis.text.x       = element_text(size = 8),
    axis.text.y       = element_text(size = 8),
    panel.spacing.x   = unit(5, "mm")
  )

# ── 6. Save ───────────────────────────────────────────────────────────────────
tiff_path <- file.path(OUTDIR, "fig5_aim3_recalibration_ladder_2026-07-30.tiff")
pdf_path  <- file.path(OUTDIR, "fig5_aim3_recalibration_ladder_2026-07-30.pdf")

ggsave(tiff_path, plot = p,
       width = 180, height = 100, units = "mm",
       dpi = 600, compression = "lzw")

ggsave(pdf_path, plot = p,
       width = 180, height = 100, units = "mm")

message("✔  Figure 5 saved:")
message("   TIFF: ", tiff_path)
message("   PDF : ", pdf_path)
