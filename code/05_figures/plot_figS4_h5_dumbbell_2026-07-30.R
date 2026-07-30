#!/usr/bin/env Rscript
# =============================================================================
# Figure S4: H5 supplementary — FI vs IC cross-cohort stability (dumbbell plot)
# Paper 1 · 2026-07-30
#
# Dumbbell: CHARLS internal C (hollow) -> CLHLS external C (solid)
# Models: B (FI), C (IC), D (FI+IC)
# Annotates |Delta C| and marks the CLHLS IC-proxy caveat
#
# Run from project root:
#   Rscript --vanilla code/05_figures/plot_figS4_h5_dumbbell_2026-07-30.R
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(ggplot2)
})

args <- commandArgs(FALSE); farg <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(farg)) dirname(normalizePath(sub("^--file=", "", farg[1]))) else getwd()
root   <- normalizePath(file.path(script_dir, "..", ".."), mustWork = TRUE)
h5_dir <- file.path(root, "results", "h5_ic")
OUTDIR <- h5_dir
stamp  <- "2026-07-30"

# ── 1. Load data ──────────────────────────────────────────────────────────────
d <- read.csv(file.path(h5_dir, "h5_model_comparison_2026-07-29.csv"),
              stringsAsFactors = FALSE)

# Clean model labels
d$model_label <- c(
  B_FI    = "Model B\n(FI only)",
  `C_IC`  = "Model C\n(IC only)",
  `D_FI+IC` = "Model D\n(FI + IC)"
)[d$model]

d$model_label <- factor(d$model_label,
  levels = c("Model B\n(FI only)", "Model C\n(IC only)", "Model D\n(FI + IC)"))

# |Delta C| label
d$dc_label <- sprintf("|Delta C| = %.3f", abs(d$drop_apparent_to_external))

# ── 2. Plot ───────────────────────────────────────────────────────────────────
# Colours: CHARLS internal = hollow blue; CLHLS external = solid orange
pal <- c("CHARLS (internal)" = "#2166AC", "CLHLS (external)" = "#D94801")

# Long format for points
pts <- bind_rows(
  d |> transmute(model_label, C = charls_apparent_C,
                 set = "CHARLS (internal)", arrow_x = charls_apparent_C),
  d |> transmute(model_label, C = clhls_external_C,
                 set = "CLHLS (external)", arrow_x = charls_apparent_C)
)

p <- ggplot() +
  # Connecting segment (the "bell" part)
  geom_segment(
    data = d,
    aes(x = charls_apparent_C, xend = clhls_external_C,
        y = model_label, yend = model_label),
    colour = "grey70", linewidth = 1.2, lineend = "round"
  ) +
  # Arrow to show direction of change
  geom_segment(
    data = d,
    aes(x = charls_apparent_C + sign(clhls_external_C - charls_apparent_C) * 0.004,
        xend = clhls_external_C - sign(clhls_external_C - charls_apparent_C) * 0.008,
        y = model_label, yend = model_label),
    colour = "grey50", linewidth = 0.4,
    arrow = arrow(length = unit(2.5, "mm"), type = "closed")
  ) +
  # CHARLS internal (hollow)
  geom_point(
    data = d,
    aes(x = charls_apparent_C, y = model_label, colour = "CHARLS (internal)"),
    size = 4, shape = 21, fill = "white", stroke = 1.5
  ) +
  # CLHLS external (solid)
  geom_point(
    data = d,
    aes(x = clhls_external_C, y = model_label, colour = "CLHLS (external)"),
    size = 4, shape = 16
  ) +
  # |Delta C| labels (right of the external C point)
  geom_text(
    data = d,
    aes(x = pmax(charls_apparent_C, clhls_external_C) + 0.007,
        y = model_label, label = dc_label),
    hjust = 0, size = 2.6, colour = "grey20"
  ) +
  # C-value labels
  geom_text(
    data = d,
    aes(x = charls_apparent_C, y = model_label,
        label = sprintf("%.3f", charls_apparent_C)),
    vjust = -1.2, size = 2.2, colour = "#2166AC"
  ) +
  geom_text(
    data = d,
    aes(x = clhls_external_C, y = model_label,
        label = sprintf("%.3f", clhls_external_C)),
    vjust = -1.2, size = 2.2, colour = "#D94801"
  ) +
  scale_colour_manual(values = pal, name = NULL) +
  scale_x_continuous(
    limits = c(0.680, 0.855),
    breaks = seq(0.70, 0.85, 0.05)
  ) +
  labs(
    x = "C-index",
    y = NULL,
    subtitle = "H5: cross-cohort C-index stability — FI vs Intrinsic Capacity (supplementary analysis)",
    caption = paste0(
      "Hollow circle = CHARLS apparent C-index (development set). ",
      "Solid circle = CLHLS external C-index (validation set). ",
      "Arrow direction shows CHARLS -> CLHLS change.\n",
      "|Delta C| = absolute cross-cohort change in C-index. ",
      "Model B (FI): |Delta C| = 0.052 vs Model C (IC): |Delta C| = 0.095 -> H5 supported (FI more stable).\n",
      "IMPORTANT CAVEAT: CLHLS IC (Model C/D) used binary FI items as proxies for continuous measurements ",
      "(grip strength, gait speed, peak flow, cognitive scores). This likely overstates IC instability.\n",
      "Full H5 test with continuous IC measurements is deferred to Paper 2 (D-012). ",
      "Bootstrap 95% CI for CLHLS C-indices did not converge; only point estimates are reported."
    )
  ) +
  theme_bw(base_size = 10, base_family = "sans") +
  theme(
    panel.grid.minor   = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(colour = "grey93", linewidth = 0.35),
    axis.text.y        = element_text(size = 9, lineheight = 0.9),
    axis.text.x        = element_text(size = 8),
    axis.title.x       = element_text(size = 9),
    legend.position    = c(0.17, 0.12),
    legend.background  = element_rect(fill = "white", colour = "grey80"),
    legend.key.size    = unit(4, "mm"),
    legend.text        = element_text(size = 8),
    plot.subtitle      = element_text(face = "bold", size = 9),
    plot.caption       = element_text(size = 6.8, hjust = 0, colour = "grey45",
                                      margin = margin(t = 6))
  )

# ── 3. Save ───────────────────────────────────────────────────────────────────
tiff_path <- file.path(OUTDIR, paste0("figS4_h5_dumbbell_", stamp, ".tiff"))
pdf_path  <- file.path(OUTDIR, paste0("figS4_h5_dumbbell_", stamp, ".pdf"))
ggsave(tiff_path, p, width = 155, height = 110, units = "mm", dpi = 600, compression = "lzw")
ggsave(pdf_path,  p, width = 155, height = 110, units = "mm")
cat("OK  Figure S4 saved:\n   ", tiff_path, "\n   ", pdf_path, "\n")
