# =============================================================================
# Shared figure theme — Paper 1
# 2026-08-01
#
# Single source of truth for typography and colour across all figures, so that
# consistency is structural rather than something I have to re-type per script.
#
# Design decisions:
#   Font        Times New Roman throughout (registered via showtext so it embeds
#               correctly in raster devices; sysfonts alias "TNR").
#   Type scale  Exactly four sizes, no exceptions:
#                 11 pt  panel tags (A, B) and axis titles
#                 10 pt  axis tick labels, legend text, in-panel value labels
#                  9 pt  strip (facet) labels
#                  8 pt  footnote / caption
#               Previously these ranged over 6.8-10 pt across seven scripts.
#   Colour      Development/Asian cohorts blue, external validation orange,
#               matching the manuscript's framing. Colour-blind safe pairing
#               (Okabe-Ito derived).
#   Overlap     No value label is drawn on top of geometry; labels sit outside
#               points, and long axis labels are wrapped rather than rotated
#               into each other.
#
# Usage:
#   source("code/05_figures/_fig_theme.R")
#   ... + theme_paper()
#   ggsave_paper("out", plot, width_mm = 180, height_mm = 110)
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2); library(ragg); library(systemfonts)
})

# ── Font ──────────────────────────────────────────────────────────────────────
# ragg resolves system font families directly, which avoids the showtext dpi
# scaling trap entirely: a size given in pt renders as that physical size
# regardless of device resolution. Verify the family is visible to systemfonts.
FONT <- "Times New Roman"
.m <- systemfonts::match_font(FONT)
if (is.null(.m$path) || !grepl("times", basename(.m$path), ignore.case = TRUE)) {
  systemfonts::register_font(
    name    = FONT,
    plain   = "C:/Windows/Fonts/times.ttf",
    bold    = "C:/Windows/Fonts/timesbd.ttf",
    italic  = "C:/Windows/Fonts/timesi.ttf",
    bolditalic = "C:/Windows/Fonts/timesbi.ttf"
  )
}

FONT <- "TNR"

# ── Type scale (four sizes only) ──────────────────────────────────────────────
SZ_TITLE  <- 11   # axis titles, panel tags
SZ_TEXT   <- 10   # tick labels, legend, in-panel values
SZ_STRIP  <-  9   # facet strip labels
SZ_NOTE   <-  8   # captions / footnotes

# ── Palette ───────────────────────────────────────────────────────────────────
COL_DEV   <- "#2C6FAF"   # development / Asian pool
COL_EXT   <- "#D95F0E"   # external validation
COL_ACC   <- "#3B8A5A"   # third series where needed
COL_GREY  <- "#59636E"
COL_REF   <- "#9AA4AE"   # reference lines
COL_IDEAL <- "#B02418"   # ideal-value reference (O:E = 1, slope = 1)

PAL_COHORT <- c(
  "CHARLS" = "#1F4E79", "CLHLS" = "#2C6FAF", "KLoSA" = "#6BAED6",
  "HRS"    = "#A63603", "SHARE" = "#D95F0E", "MHAS"  = "#FD9E4F"
)
PAL_ROLE <- c("Development / Asian pool" = COL_DEV, "External validation" = COL_EXT)

# ── Base theme ────────────────────────────────────────────────────────────────
theme_paper <- function(base_size = SZ_TEXT, grid = c("both", "x", "y", "none"),
                        legend = "top") {
  grid <- match.arg(grid)
  gx <- if (grid %in% c("both", "x")) element_line(colour = "grey90", linewidth = 0.25) else element_blank()
  gy <- if (grid %in% c("both", "y")) element_line(colour = "grey90", linewidth = 0.25) else element_blank()

  theme_bw(base_size = base_size, base_family = FONT) +
    theme(
      text              = element_text(family = FONT, colour = "black"),
      plot.title        = element_text(size = SZ_TITLE, face = "bold", hjust = 0,
                                       margin = margin(b = 4)),
      plot.subtitle     = element_text(size = SZ_TEXT, colour = COL_GREY,
                                       margin = margin(b = 6)),
      plot.caption      = element_text(size = SZ_NOTE, colour = COL_GREY,
                                       hjust = 0, lineheight = 1.25,
                                       margin = margin(t = 8)),
      plot.caption.position = "plot",
      axis.title        = element_text(size = SZ_TITLE),
      axis.title.x      = element_text(margin = margin(t = 6)),
      axis.title.y      = element_text(margin = margin(r = 6)),
      axis.text         = element_text(size = SZ_TEXT, colour = "black"),
      axis.ticks        = element_line(colour = "grey45", linewidth = 0.3),
      panel.border      = element_rect(colour = "grey35", linewidth = 0.45),
      panel.grid.major.x = gx,
      panel.grid.major.y = gy,
      panel.grid.minor  = element_blank(),
      strip.background  = element_rect(fill = "grey94", colour = "grey35",
                                       linewidth = 0.45),
      strip.text        = element_text(size = SZ_STRIP, face = "bold",
                                       margin = margin(3, 3, 3, 3)),
      legend.position   = legend,
      legend.title      = element_text(size = SZ_TEXT),
      legend.text       = element_text(size = SZ_TEXT),
      legend.key.size   = unit(4.5, "mm"),
      legend.margin     = margin(0, 0, 2, 0),
      legend.box.spacing = unit(2, "mm"),
      plot.margin       = margin(6, 8, 6, 6)
    )
}

# Panel tag (A, B, ...) styled consistently for multi-panel figures
tag_theme <- function() {
  theme(plot.tag = element_text(family = FONT, size = SZ_TITLE, face = "bold"),
        plot.tag.position = c(0, 1))
}

# ── Output helper: TIFF (journal) + PDF (vector) at identical geometry ─────────
ggsave_paper <- function(stem, plot, width_mm, height_mm, dpi = 600) {
  dir.create(dirname(stem), recursive = TRUE, showWarnings = FALSE)
  ggsave(paste0(stem, ".tiff"), plot, device = ragg::agg_tiff,
         width = width_mm, height = height_mm, units = "mm",
         res = dpi, compression = "lzw", background = "white")
  ggsave(paste0(stem, ".pdf"), plot, device = cairo_pdf,
         width = width_mm, height = height_mm, units = "mm")
  cat(sprintf("  saved %s.{tiff,pdf}  %.0fx%.0f mm @ %d dpi\n",
              basename(stem), width_mm, height_mm, dpi))
}
