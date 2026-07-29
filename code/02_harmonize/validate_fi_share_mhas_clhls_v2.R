suppressPackageStartupMessages(library(arrow))
stems <- c("hibpe","dyslipe","diabe","cancre","lunge","livere","hearte","stroke","psyche","arthre","kidneye","digeste","asthmae","dressa","batha","eata","beda","toilta","urina","housewka","mealsa","shopa","moneya","medsa","walk100a","walk1kma","joga","climsa","chaira","stoopa","armsa","lifta","dimea","dsight","nsight","hearing","shlt","painfr","fall","slfmem","mbmi")
files <- c("share_fi_2011_2026-07-29.parquet","mhas_fi_2012_2026-07-29.parquet","clhls_fi_2011_2026-07-29.parquet")
for (f in files) {
  d <- read_parquet(file.path("data/analysis", f))
  mat <- as.data.frame(d[, stems])
  fi <- d[["fi_full"]]; age <- d[["age"]]
  cat(f, " rows=", nrow(d), " stem_n=", ncol(mat),
      " id_unique=", length(unique(d[["id"]])) == nrow(d),
      " threshold=", paste(unique(d[["fi_threshold"]]), collapse="/"),
      " found=", paste(unique(d[["fi_n_found"]]), collapse="/"),
      " eligible=", sum(!is.na(fi)), " age60=", sum(!is.na(age) & age >= 60),
      " age60_eligible=", sum(!is.na(fi) & !is.na(age) & age >= 60),
      " range=", paste(range(fi, na.rm=TRUE), collapse=":"),
      " bad_range=", any(fi < 0 | fi > 1, na.rm=TRUE), "\n", sep="")
  stopifnot(ncol(mat) == 41L, all(d[["fi_n_found"]] == 41L), all(d[["fi_threshold"]] == 33L), all(fi >= 0 | is.na(fi)), all(fi <= 1 | is.na(fi)))
}
cat("VALIDATION_PASS\n")
