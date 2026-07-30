#!/usr/bin/env Rscript
# =============================================================================
# Figure S2: SHARE country-level C-index (19 countries/regions)
# Paper 1 · 2026-07-30
#
# Sorted dot plot with 95% CI-free point estimates, n and event counts,
# median reference line. Map deliberately avoided (rnaturalearth dependency
# and SHARE's non-ISO region codes make a dot plot both safer and more precise).
#
# Run from project root:
#   Rscript --vanilla code/05_figures/plot_figS2_share_country_2026-07-30.R
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr); library(ggplot2)
})

args <- commandArgs(FALSE); farg <- grep("^--file=", args, value = TRUE)
script_dir <- if (length(farg)) dirname(normalizePath(sub("^--file=", "", farg[1]))) else getwd()
root   <- normalizePath(file.path(script_dir, "..", ".."), mustWork = TRUE)
a3_dir <- file.path(root, "results", "aim3")
OUTDIR <- file.path(a3_dir, "figures")
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)
stamp  <- "2026-07-30"

# ── 1. Read + map SHARE country codes to names ────────────────────────────────
d <- read.csv(file.path(a3_dir, "aim3_share_country_cindex_2026-07-29.csv"),
              stringsAsFactors = FALSE)

# SHARE wave-4 country codes (incl. language-split regions: Bf/Bn Belgium,
# Cf/Cg Switzerland). Unmapped codes fall through to the raw code.
code_map <- c(
  AT = "Austria",        DE = "Germany",      SE = "Sweden",
  NL = "Netherlands",    ES = "Spain",        IT = "Italy",
  FR = "France",         DK = "Denmark",      GR = "Greece",
  CH = "Switzerland",    Cf = "Switzerland (Fr)", Cg = "Switzerland (Ge)",
  BE = "Belgium",        Bf = "Belgium (Fr)", Bn = "Belgium (Nl)",
  CZ = "Czechia",        PL = "Poland",       IE = "Ireland",
  LU = "Luxembourg",     HU = "Hungary",      PT = "Portugal",
  SI = "Slovenia",       EE = "Estonia",      HR = "Croatia",
  LT = "Lithuania",      BG = "Bulgaria",     CY = "Cyprus",
  FI = "Finland",        LV = "Latvia",       MT = "Malta",
  RO = "Romania",        SK = "Slovakia",     IL = "Israel"
)

d$country_name <- ifelse(d$country %in% names(code_map),
                         code_map[d$country], d$country)
d$label <- sprintf("%s (%s)", d$country_name, d$country)

med_c <- median(d$c_index)

cat(sprintf("SHARE countries: %d | C-index range %.4f-%.4f | median %.4f\n",
            nrow(d), min(d$c_index), max(d$c_index), med_c))

# ── 2. Order by C-index; flag extremes ────────────────────────────────────────
d <- d |>
  arrange(c_index) |>
  mutate(
    label   = factor(label, levels = label),
    extreme = case_when(
      c_index == max(c_index) ~ "highest",
      c_index == min(c_index) ~ "lowest",
      TRUE                    ~ "mid"
    )
  )

pal <- c(lowest = "#B2182B", mid = "#D94801", highest = "#08519C")

# ── 3. Plot ───────────────────────────────────────────────────────────────────
p <- ggplot(d, aes(c_index, label)) +
  geom_vline(xintercept = med_c, linetype = "dashed",
             colour = "grey45", linewidth = 0.45) +
  geom_vline(xintercept = 0.70, linetype = "dotted",
             colour = "grey65", linewidth = 0.4) +
  geom_segment(aes(x = min(d$c_index) - 0.015, xend = c_index,
                   y = label, yend = label),
               colour = "grey85", linewidth = 0.35) +
  geom_point(aes(colour = extreme, size = events)) +
  geom_text(aes(label = sprintf("%.3f", c_index)),
            hjust = -0.42, size = 2.3, colour = "grey20") +
  annotate("text", x = med_c, y = 0.6,
           label = sprintf("median %.3f", med_c),
           size = 2.4, colour = "grey35", hjust = -0.06, vjust = 0.4) +
  scale_colour_manual(values = pal, guide = "none") +
  scale_size_continuous(range = c(1.3, 3.6), name = "Deaths",
                        breaks = c(50, 200, 500)) +
  scale_x_continuous(limits = c(min(d$c_index) - 0.02, max(d$c_index) + 0.045),
                     breaks = seq(0.65, 0.90, 0.05)) +
  labs(
    x = "C-index (Asian-pool model, L0 frozen)",
    y = NULL,
    caption = paste0(
      "Country-level discrimination of the frozen Asian-pool model within SHARE wave-4 (2011 interviews, age >= 60). ",
      "Point size proportional to the number of deaths.\n",
      "Dashed line: across-country median C-index. Dotted line: C = 0.70 conventional usefulness threshold. ",
      "All 19 countries/regions exceeded 0.69.\n",
      "Bf/Bn = Belgium French/Dutch-speaking; Cf/Cg = Switzerland French/German-speaking. ",
      "Country-level event rates and case-mix differ, which is reflected in the spread."
    )
  ) +
  theme_bw(base_size = 9, base_family = "sans") +
  theme(
    panel.grid.minor   = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.major.x = element_line(colour = "grey93", linewidth = 0.3),
    axis.text.y        = element_text(size = 7.5),
    axis.text.x        = element_text(size = 8),
    axis.title.x       = element_text(size = 9),
    legend.position    = c(0.88, 0.22),
    legend.background  = element_rect(fill = "white", colour = "grey80"),
    legend.key.size    = unit(3.5, "mm"),
    legend.title       = element_text(size = 7.5),
    legend.text        = element_text(size = 7),
    plot.caption       = element_text(size = 6.8, hjust = 0, colour = "grey45",
                                      margin = margin(t = 6))
  )

# ── 4. Save ───────────────────────────────────────────────────────────────────
tiff_path <- file.path(OUTDIR, paste0("figS2_share_country_cindex_", stamp, ".tiff"))
pdf_path  <- file.path(OUTDIR, paste0("figS2_share_country_cindex_", stamp, ".pdf"))
ggsave(tiff_path, p, width = 160, height = 125, units = "mm", dpi = 600, compression = "lzw")
ggsave(pdf_path,  p, width = 160, height = 125, units = "mm")

# Export the labelled table for Supplementary Table S4
write.csv(d |> arrange(desc(c_index)) |>
            select(code = country, country = country_name, n, events, event_rate, c_index),
          file.path(a3_dir, paste0("tableS4_share_country_cindex_", stamp, ".csv")),
          row.names = FALSE)

cat("OK  Figure S2 saved:\n   ", tiff_path, "\n   ", pdf_path, "\n")
