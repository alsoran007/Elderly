#!/usr/bin/env Rscript
# =============================================================================
# Figure S1: H6 — cross-cohort feature importance heatmap + Spearman concordance
# Paper 1 · 2026-07-30
#
# Panel A: |beta_standardised| heatmap, FI_core 19 items + age x 6 cohorts
# Panel B: 6x6 Spearman rank-correlation matrix (lower triangle annotated)
#
# Run from project root:
#   Rscript --vanilla code/05_figures/plot_figS1_h6_importance_2026-07-30.R
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(ggplot2); library(patchwork)
})

args <- commandArgs(FALSE); farg <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(farg)) dirname(normalizePath(sub("^--file=", "", farg[1]))) else getwd()
root   <- normalizePath(file.path(script_dir, "..", ".."), mustWork = TRUE)
h6_dir <- file.path(root, "results", "h6_shap")
OUTDIR <- file.path(h6_dir, "figures")
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)
stamp  <- "2026-07-30"

cohort_order <- c("CHARLS", "CLHLS", "KLoSA", "HRS", "SHARE", "MHAS")

# ── 1. Panel A: importance heatmap ────────────────────────────────────────────
imp <- read.csv(file.path(h6_dir, "h6_importance_matrix_2026-07-29.csv"),
                row.names = 1, check.names = FALSE)
rnk <- read.csv(file.path(h6_dir, "h6_rank_matrix_2026-07-29.csv"),
                row.names = 1, check.names = FALSE)

imp_long <- imp |>
  tibble::rownames_to_column("feature") |>
  pivot_longer(-feature, names_to = "cohort", values_to = "importance")

rnk_long <- rnk |>
  tibble::rownames_to_column("feature") |>
  pivot_longer(-feature, names_to = "cohort", values_to = "rank")

dat <- left_join(imp_long, rnk_long, by = c("feature", "cohort"))

# Order features by mean importance across cohorts (descending, age on top)
feat_order <- dat |>
  group_by(feature) |>
  summarise(m = mean(importance, na.rm = TRUE), .groups = "drop") |>
  arrange(desc(m)) |>
  pull(feature)

dat$feature <- factor(dat$feature, levels = rev(feat_order))
dat$cohort  <- factor(dat$cohort,  levels = cohort_order)

pA <- ggplot(dat, aes(cohort, feature, fill = importance)) +
  geom_tile(colour = "white", linewidth = 0.4) +
  geom_text(aes(label = rank,
                colour = importance > max(dat$importance, na.rm = TRUE) * 0.55),
            size = 2.1, fontface = "bold", show.legend = FALSE) +
  scale_fill_gradientn(
    colours = c("#F7FBFF", "#C6DBEF", "#6BAED6", "#2171B5", "#08306B"),
    name = expression("|" * beta[std] * "|"),
    guide = guide_colourbar(barheight = unit(28, "mm"), barwidth = unit(3, "mm"))
  ) +
  scale_colour_manual(values = c("FALSE" = "grey35", "TRUE" = "white")) +
  scale_x_discrete(position = "top") +
  labs(x = NULL, y = NULL, subtitle = "A  Standardised feature importance (cell label = within-cohort rank)") +
  theme_minimal(base_size = 9, base_family = "sans") +
  theme(
    axis.text.x       = element_text(size = 7.5, face = "bold"),
    axis.text.y       = element_text(size = 6.8),
    panel.grid        = element_blank(),
    legend.title      = element_text(size = 8),
    legend.text       = element_text(size = 7),
    plot.subtitle     = element_text(face = "bold", size = 8.5)
  )

# ── 2. Panel B: Spearman concordance matrix ──────────────────────────────────
sp <- read.csv(file.path(h6_dir, "h6_spearman_matrix_2026-07-29.csv"),
               row.names = 1, check.names = FALSE)

sp_long <- sp |>
  tibble::rownames_to_column("c1") |>
  pivot_longer(-c1, names_to = "c2", values_to = "rho") |>
  mutate(
    c1 = factor(c1, levels = cohort_order),
    c2 = factor(c2, levels = cohort_order),
    i1 = as.integer(c1), i2 = as.integer(c2)
  ) |>
  # keep lower triangle + diagonal for a clean display
  filter(i1 >= i2)

med_rho <- median(sp_long$rho[sp_long$i1 > sp_long$i2])

pB <- ggplot(sp_long, aes(c2, c1, fill = rho)) +
  geom_tile(colour = "white", linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.2f", rho),
                colour = rho > 0.55), size = 2.5, show.legend = FALSE) +
  scale_fill_gradientn(
    colours = c("#FFF5EB", "#FDD0A2", "#FD8D3C", "#D94801", "#7F2704"),
    limits = c(0, 1), name = expression(rho),
    guide = guide_colourbar(barheight = unit(28, "mm"), barwidth = unit(3, "mm"))
  ) +
  scale_colour_manual(values = c("FALSE" = "grey25", "TRUE" = "white")) +
  scale_y_discrete(limits = rev(cohort_order)) +
  labs(x = NULL, y = NULL,
       subtitle = sprintf("B  Spearman rank concordance (median off-diagonal = %.2f)", med_rho)) +
  coord_fixed() +
  theme_minimal(base_size = 9, base_family = "sans") +
  theme(
    axis.text     = element_text(size = 7.5, face = "bold"),
    panel.grid    = element_blank(),
    legend.title  = element_text(size = 9),
    legend.text   = element_text(size = 7),
    plot.subtitle = element_text(face = "bold", size = 8.5)
  )

# ── 3. Combine & save ─────────────────────────────────────────────────────────
figS1 <- pA + pB +
  plot_layout(widths = c(1.35, 1)) +
  plot_annotation(caption = paste0(
    "A: Absolute standardised logistic-regression coefficients for FI_core (19 items) plus age, fitted separately within each cohort. ",
    "Cell labels give the within-cohort importance rank (1 = most important). Age ranked first in all six cohorts.\n",
    "B: Pairwise Spearman rank correlation of the importance orderings in panel A. Pre-registered H6 threshold was median rho >= 0.70; ",
    "the observed median of 0.41 did not meet it, so H6 is partially supported.\n",
    "Lowest concordance: KLoSA-HRS (0.10) and KLoSA-CHARLS (0.10). Highest: CHARLS-SHARE (0.67)."
  )) &
  theme(plot.caption = element_text(size = 6.8, hjust = 0, colour = "grey45",
                                    margin = margin(t = 5)))

tiff_path <- file.path(OUTDIR, paste0("figS1_h6_importance_concordance_", stamp, ".tiff"))
pdf_path  <- file.path(OUTDIR, paste0("figS1_h6_importance_concordance_", stamp, ".pdf"))
ggsave(tiff_path, figS1, width = 180, height = 130, units = "mm", dpi = 600, compression = "lzw")
ggsave(pdf_path,  figS1, width = 180, height = 130, units = "mm")
cat("OK  Figure S1 saved:\n   ", tiff_path, "\n   ", pdf_path, "\n")
