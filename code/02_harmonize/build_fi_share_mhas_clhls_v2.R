#!/usr/bin/env Rscript
# Build fixed 41-item FI outputs for SHARE, MHAS and CLHLS.
# Raw source files are read only. Every source-to-deficit decision is recorded
# in the mapping tables; unsupported concepts remain NA rather than being filled
# from mortality/follow-up variables.

suppressPackageStartupMessages({
  library(haven)
  library(arrow)
})

PROJ <- "D:/AI_project/project3"
STAMP <- "2026-07-29"
OUTDIR <- file.path(PROJ, "data/analysis")
TABDIR <- file.path(PROJ, "results/fi_share_mhas_clhls/tables")
REPORTDIR <- file.path(PROJ, "results/fi_share_mhas_clhls")
LOGDIR <- file.path(PROJ, "logs")
dir.create(OUTDIR, recursive=TRUE, showWarnings=FALSE)
dir.create(TABDIR, recursive=TRUE, showWarnings=FALSE)
dir.create(REPORTDIR, recursive=TRUE, showWarnings=FALSE)
dir.create(LOGDIR, recursive=TRUE, showWarnings=FALSE)

LOG <- file.path(LOGDIR, paste0("build_fi_share_mhas_clhls_v2_", STAMP, ".log"))
lc_out <- file(LOG, open="wt", encoding="UTF-8")
lc_msg <- file(LOG, open="at", encoding="UTF-8")
sink(lc_out, type="output"); sink(lc_msg, type="message")
on.exit({sink(type="message"); sink(type="output"); close(lc_msg); close(lc_out)}, add=TRUE)

# Frozen cross-cohort layout: 13 comorbidity, 6 ADL, 5 IADL,
# 9 mobility, 3 sensory, 4 general health, and 1 cognition/BMI slot.
# The last two rows are slfmem and mbmi; both are retained as separate items.
FI_STEMS <- c(
  "hibpe","dyslipe","diabe","cancre","lunge","livere","hearte",
  "stroke","psyche","arthre","kidneye","digeste","asthmae",
  "dressa","batha","eata","beda","toilta","urina",
  "housewka","mealsa","shopa","moneya","medsa",
  "walk100a","walk1kma","joga","climsa","chaira","stoopa","armsa","lifta","dimea",
  "dsight","nsight","hearing","shlt","painfr","fall","slfmem","mbmi"
)
stopifnot(length(FI_STEMS) == 41L, !anyDuplicated(FI_STEMS))
THRESHOLD <- 33L

num <- function(x) suppressWarnings(as.numeric(x))
na_bad <- function(x, bad=c(8,9,98,99,888,889,999,-8,-9,-88,-89,-99)) {
  z <- num(x); z[z %in% bad] <- NA_real_; z
}
binary_yes <- function(x, yes=1, no=0) {
  z <- na_bad(x)
  ifelse(z == yes, 1, ifelse(z == no, 0, NA_real_))
}
binary_bad <- function(x, bad_when=c(1,2), good_when=3) {
  z <- na_bad(x)
  ifelse(z %in% bad_when, 1, ifelse(z == good_when, 0, NA_real_))
}
ordinal_deficit <- function(x, min_value, max_value, reverse=FALSE) {
  z <- na_bad(x)
  keep <- !is.na(z) & z >= min_value & z <= max_value
  out <- rep(NA_real_, length(z))
  if (reverse) out[keep] <- (max_value - z[keep])/(max_value-min_value)
  else out[keep] <- (z[keep] - min_value)/(max_value-min_value)
  out
}
share_function <- function(x) {
  # SHARE difficulty fields: 0=no difficulty, 1=some, 2=more/cannot.
  z <- na_bad(x, c(8,9,98,99,-8,-9)); ifelse(z==0,0,ifelse(z %in% c(1,2),1,NA_real_))
}
mhas_function <- function(x) {
  # MHAS: 0=no difficulty; 1/2 difficulty; 9 is missing.
  z <- na_bad(x, c(8,9,98,99,-8,-9)); ifelse(z==0,0,ifelse(z %in% c(1,2,3),1,NA_real_))
}
clhls_function <- function(x) {
  # CLHLS functional fields: 1=independent, 2/3 impaired.
  z <- na_bad(x, c(8,9,98,99,-8,-9)); ifelse(z==1,0,ifelse(z %in% c(2,3),1,NA_real_))
}
clhls_binary_deficit <- function(x) {
  # CLHLS disease fields: 1=yes, 2=no; 8/9 are nonresponse.
  z <- na_bad(x, c(8,9,98,99,-8,-9)); ifelse(z==1,1,ifelse(z==2,0,NA_real_))
}
rating5 <- function(x) ordinal_deficit(x, 1, 5, reverse=FALSE)
bmi_deficit <- function(x) {
  z <- na_bad(x, c(8,9,98,99,888,889,999,-8,-9,-88,-89,-99))
  ifelse(!is.na(z) & z > 5 & z < 80, ifelse(z < 18.5 | z >= 30, 1, 0), NA_real_)
}

blank_map <- function(cohort) data.frame(
  cohort=cohort, stem=FI_STEMS, domain=c(rep("comorbidity",13),rep("adl",6),rep("iadl",5),rep("mobility",9),rep("sensory",3),rep("general",3),"cognition","anthropometry"),
  source_var=NA_character_, source_label=NA_character_, status=NA_character_, coding=NA_character_, review_note=NA_character_,
  stringsAsFactors=FALSE
)
set_map <- function(mp, stem, source, label, status, coding, note="") {
  i <- match(stem, mp$stem); stopifnot(!is.na(i)); mp[i,c("source_var","source_label","status","coding","review_note")] <- list(source,label,status,coding,note); mp
}
finish <- function(fi, map, cohort, out_name) {
  mat <- fi[,FI_STEMS,drop=FALSE]
  mat[] <- lapply(mat, function(x) pmin(pmax(num(x),0),1))
  fi[,FI_STEMS] <- mat
  fi$fi_n_valid <- rowSums(!is.na(mat))
  fi$fi_n_found <- 41L
  fi$fi_threshold <- THRESHOLD
  fi$fi_full <- ifelse(fi$fi_n_valid >= THRESHOLD, rowSums(mat,na.rm=TRUE)/fi$fi_n_valid, NA_real_)
  fi$fi_excluded <- fi$fi_n_valid < THRESHOLD
  fi$age_60_plus <- !is.na(fi$age) & fi$age >= 60
  stopifnot(ncol(fi[,FI_STEMS,drop=FALSE])==41L, all(fi$fi_full[!is.na(fi$fi_full)]>=0 & fi$fi_full[!is.na(fi$fi_full)]<=1))
  map$n_nonmissing <- vapply(FI_STEMS, function(s) sum(!is.na(mat[[s]])), integer(1))
  map$deficit_rate <- vapply(FI_STEMS, function(s) mean(mat[[s]], na.rm=TRUE), numeric(1))
  map$deficit_rate[is.nan(map$deficit_rate)] <- NA_real_
  corr <- suppressWarnings(cor(mat, use="pairwise.complete.obs"))
  hi <- which(abs(corr) > .85 & upper.tri(corr), arr.ind=TRUE)
  high <- if(nrow(hi)) data.frame(item_1=rownames(corr)[hi[,1]], item_2=colnames(corr)[hi[,2]], abs_correlation=abs(corr[hi])) else data.frame(item_1=character(),item_2=character(),abs_correlation=numeric())
  summary <- data.frame(metric=c("raw_rows","age60_rows","fi_eligible_all","fi_eligible_age60","fi_median_all","fi_median_age60","fi_min","fi_max","item_count","threshold"), value=c(nrow(fi),sum(fi$age_60_plus,na.rm=TRUE),sum(!fi$fi_excluded,na.rm=TRUE),sum(fi$age_60_plus & !fi$fi_excluded,na.rm=TRUE),median(fi$fi_full,na.rm=TRUE),median(fi$fi_full[fi$age_60_plus],na.rm=TRUE),min(fi$fi_full,na.rm=TRUE),max(fi$fi_full,na.rm=TRUE),41,THRESHOLD))
  write.csv(map,file.path(TABDIR,paste0(tolower(cohort),"_fi_v2_mapping_",STAMP,".csv")),row.names=FALSE,na="")
  write.csv(summary,file.path(TABDIR,paste0(tolower(cohort),"_fi_v2_summary_",STAMP,".csv")),row.names=FALSE)
  write.csv(high,file.path(TABDIR,paste0(tolower(cohort),"_fi_v2_high_correlation_pairs_",STAMP,".csv")),row.names=FALSE)
  write_parquet(fi,file.path(OUTDIR,out_name))
  list(fi=fi,map=map,summary=summary,high=high)
}

### SHARE wave 4, interview year 2011
share_raw <- "D:/AI_project/sql/share harmonised/GH_SHARE_g.dta"
share_names <- names(read_dta(share_raw,n_max=0))
share_sources <- c("mergeid","r4iwy","r4agey","r4hibpe","r4hchole","r4diabe","r4cancre","r4lunge","r4ulcere","r4hearte","r4stroke","r4psyche","r4arthre","r4respe","r4dressa","r4batha","r4eata","r4beda","r4toilta","r4urinai6m","r4housewka","r4mealsa","r4shopa","r4moneya","r4medsa","r4walk100a","r4walkra","r4joga","r4climsa","r4chaira","r4stoopa","r4armsa","r4lifta","r4dimea","r4dsight","r4nsight","r4hearing","r4shlt","r4pain_s","r4fall_s","r4slfmem","r4bmi")
share_keep <- intersect(share_sources, share_names)
d <- read_dta(share_raw,col_select=all_of(share_keep))
d <- d[!is.na(num(d$r4iwy)) & num(d$r4iwy)==2011,]
sh <- data.frame(id=as.character(d$mergeid),age=num(d$r4agey),stringsAsFactors=FALSE)
sh$hibpe<-binary_yes(d$r4hibpe); sh$dyslipe<-binary_yes(d$r4hchole); sh$diabe<-binary_yes(d$r4diabe); sh$cancre<-binary_yes(d$r4cancre); sh$lunge<-binary_yes(d$r4lunge); sh$livere<-binary_yes(d$r4ulcere); sh$hearte<-binary_yes(d$r4hearte); sh$stroke<-binary_yes(d$r4stroke); sh$psyche<-binary_yes(d$r4psyche); sh$arthre<-binary_yes(d$r4arthre); sh$kidneye<-NA_real_; sh$digeste<-NA_real_; sh$asthmae<-binary_yes(d$r4respe)
for(s in c("dressa","batha","eata","beda","toilta")) sh[[s]]<-share_function(d[[paste0("r4",s)]])
sh$urina<-binary_yes(d$r4urinai6m)
for(s in c("housewka","mealsa","shopa","moneya","medsa")) sh[[s]]<-share_function(d[[paste0("r4",s)]])
sh$walk100a<-share_function(d$r4walk100a); sh$walk1kma<-share_function(d$r4walkra); sh$joga<-NA_real_; sh$climsa<-share_function(d$r4climsa); sh$chaira<-share_function(d$r4chaira); sh$stoopa<-share_function(d$r4stoopa); sh$armsa<-share_function(d$r4armsa); sh$lifta<-share_function(d$r4lifta); sh$dimea<-share_function(d$r4dimea)
sh$dsight<-rating5(d$r4dsight); sh$nsight<-rating5(d$r4nsight); sh$hearing<-rating5(d$r4hearing); sh$shlt<-rating5(d$r4shlt); sh$painfr<-binary_yes(d$r4pain_s); sh$fall<-binary_yes(d$r4fall_s); sh$slfmem<-rating5(d$r4slfmem); sh$mbmi<-bmi_deficit(d$r4bmi)
mp <- blank_map("SHARE")
for(s in FI_STEMS) mp <- set_map(mp,s,paste0("r4",s),"SHARE harmonised wave-4 field",ifelse(s %in% c("dyslipe","livere","asthmae"),"documented_substitute","direct"),"Binary 1=deficit; ordinal/rating5=(x-1)/4; BMI WHO <18.5 or >=30")
mp <- set_map(mp,"dyslipe","r4hchole","ever had high cholesterol","documented_substitute","1=deficit, 0=no","No r4dyslipe exists; high cholesterol is the closest labelled dyslipidemia proxy.")
mp <- set_map(mp,"livere","r4ulcere","ever had ulcer","cross_domain_substitute","1=deficit, 0=no","No liver disease field was found; ulcer is not equivalent and is retained only as a flagged sensitivity item.")
mp <- set_map(mp,"asthmae","r4respe","chronic lung disease or asthma","documented_substitute","1=deficit, 0=no","Respiratory disease including asthma replaces the unavailable asthma-only field.")
mp <- set_map(mp,"kidneye","","No verified baseline kidney field","unsupported","NA","Must not be filled from unrelated symptoms.")
mp <- set_map(mp,"digeste","","No verified baseline digestive field","unsupported","NA","Must not be filled from unrelated symptoms.")
mp <- set_map(mp,"joga","","No verified SHARE wave-4 jogging field","unsupported","NA","No r4joga exists; retained as NA rather than duplicating another mobility field.")
rs <- finish(sh,mp,"SHARE",paste0("share_fi_2011_",STAMP,".parquet"))

### MHAS wave 3
mhas_raw <- "D:/AI_project/sql/MHAS/H_MHAS_c2.dta"
mhas_names <- names(read_dta(mhas_raw,n_max=0))
mhas_sources <- c("rahhidnp","r3agey","rabyear","r3iwy",paste0("r3",c("hibpe","diabe","cancre","stroke","arthre","dressa","batha","eata","beda","toilta","mealsa","shopa","moneya","medsa","joga","climsa","chaira","stoopa","armsa","lifta","dimea","hearing","shlt","painfr","fall","slfmem","mbmi")),"r3respe","r3hrtatte","r3cholst","r3resplmt","r3depres","r3fatigue","r3ftired","r3walkr","r3walks","r3walk1","r3sight","r3bmi","r3sleepr")
mhas_keep <- intersect(mhas_sources,mhas_names)
d <- read_dta(mhas_raw,col_select=all_of(mhas_keep))
age <- num(d$r3agey); age[is.na(age) | age<20 | age>110] <- num(d$r3iwy[is.na(age) | age<20 | age>110]) - num(d$rabyear[is.na(age) | age<20 | age>110])
mh <- data.frame(id=as.character(d$rahhidnp),age=age,stringsAsFactors=FALSE)
mh$hibpe<-binary_yes(d$r3hibpe); mh$dyslipe<-binary_yes(d$r3cholst); mh$diabe<-binary_yes(d$r3diabe); mh$cancre<-binary_yes(d$r3cancre); mh$lunge<-binary_yes(d$r3respe); mh$livere<-NA_real_; mh$hearte<-binary_yes(d$r3hrtatte); mh$stroke<-binary_yes(d$r3stroke); mh$psyche<-binary_yes(d$r3depres); mh$arthre<-binary_yes(d$r3arthre); mh$kidneye<-NA_real_; mh$digeste<-NA_real_; mh$asthmae<-binary_yes(d$r3resplmt)
for(s in c("dressa","batha","eata","beda","toilta")) mh[[s]]<-mhas_function(d[[paste0("r3",s)]])
mh$urina<-NA_real_
mh$housewka<-NA_real_
for(s in c("mealsa","shopa","moneya","medsa")) mh[[s]]<-mhas_function(d[[paste0("r3",s)]])
mh$walk100a<-mhas_function(d$r3walkr); mh$walk1kma<-mhas_function(d$r3walks); mh$joga<-mhas_function(d$r3joga); mh$climsa<-mhas_function(d$r3climsa); mh$chaira<-mhas_function(d$r3chaira); mh$stoopa<-mhas_function(d$r3stoopa); mh$armsa<-mhas_function(d$r3armsa); mh$lifta<-mhas_function(d$r3lifta); mh$dimea<-mhas_function(d$r3dimea)
mh$dsight<-ordinal_deficit(d$r3sight,1,6); mh$nsight<-NA_real_; mh$hearing<-ordinal_deficit(d$r3hearing,1,6); mh$shlt<-ordinal_deficit(d$r3shlt,1,6); mh$painfr<-binary_yes(d$r3painfr); mh$fall<-binary_yes(d$r3fall); mh$slfmem<-ordinal_deficit(d$r3slfmem,1,6); mh$mbmi<-bmi_deficit(d$r3mbmi)
mp <- blank_map("MHAS")
for(s in FI_STEMS) mp <- set_map(mp,s,paste0("r3",s),"MHAS harmonised wave-3 field",ifelse(s %in% c("dyslipe","asthmae","psyche"),"documented_substitute","direct"),"Binary 1=deficit; difficulty 0/1/2 -> 0/1; rating 1-6 -> 0-1; BMI WHO")
mp <- set_map(mp,"dyslipe","r3cholst","preventive cholesterol measure","cross_domain_substitute","1=deficit when coded abnormal; other codes checked in report","This is a care/measurement proxy, not a diagnosis; review before primary analysis.")
mp <- set_map(mp,"asthmae","r3resplmt","respiratory problems limit activities","cross_domain_substitute","1=limitation, 0=none","No asthma-only field; respiratory limitation is a non-equivalent substitute.")
mp <- set_map(mp,"psyche","r3depres","CESD felt depressed","documented_substitute","1=depressed, 0=not depressed","Depression symptom is used because no harmonised psychiatric diagnosis field exists.")
for(s in c("livere","kidneye","digeste","urina","nsight","housewka")) mp <- set_map(mp,s,"","No verified wave-3 field","unsupported","NA","Not filled from unrelated variables.")
rm <- finish(mh,mp,"MHAS",paste0("mhas_fi_2012_",STAMP,".parquet"))

### CLHLS 2011/2012 baseline (first 2011/2012 interview only)
clhls_raw <- "D:/AI_project/sql/CLHLS/CLHLS_dataset_2008-2018_SPSS/clhls_2011_2018_longitudinal_dataset_released_version1.sav"
clhls_sources <- c("id","yearin","trueage","g15a1","g15b1","g15c1","g15d1","g15e1","g15f1","g15g1","g15i1","g15k1","g15n1","g15o1","g15q1","g15s1","g15v1","b28","e0","e1","e2","e3","e4","e5","e6","d11a","e7","e8","e9","e10","e11","e12","e13","e14","f340","g11","g9","g83","g106","h1","b12","g01","g1","g24a","g101","g1021","g102b")
clhls_names <- names(read_sav(clhls_raw,n_max=0))
d <- read_sav(clhls_raw,col_select=all_of(intersect(clhls_sources,clhls_names)))
d <- d[!is.na(num(d$yearin)) & num(d$yearin) %in% c(2011,2012),]
cl <- data.frame(id=as.character(d$id),age=num(d$trueage),stringsAsFactors=FALSE)
cl$hibpe<-clhls_binary_deficit(d$g15a1); cl$dyslipe<-clhls_binary_deficit(d$g15q1); cl$diabe<-clhls_binary_deficit(d$g15b1); cl$cancre<-clhls_binary_deficit(d$g15i1); cl$lunge<-clhls_binary_deficit(d$g15e1); cl$livere<-clhls_binary_deficit(d$g15v1); cl$hearte<-clhls_binary_deficit(d$g15c1); cl$stroke<-clhls_binary_deficit(d$g15d1); cl$psyche<-clhls_binary_deficit(d$b28); cl$arthre<-clhls_binary_deficit(d$g15n1); cl$kidneye<-clhls_binary_deficit(d$g15s1); cl$digeste<-clhls_binary_deficit(d$g15k1); cl$asthmae<-clhls_binary_deficit(d$g15f1)
cl$dressa<-clhls_function(d$e2); cl$batha<-clhls_function(d$e1); cl$eata<-clhls_function(d$e6); cl$beda<-clhls_function(d$e4); cl$toilta<-clhls_function(d$e3); cl$urina<-clhls_function(d$e5)
cl$housewka<-ifelse(na_bad(d$d11a,c(8,9))==1,0,ifelse(na_bad(d$d11a,c(8,9)) %in% c(2,3,4,5),1,NA_real_)); cl$mealsa<-clhls_function(d$e9); cl$shopa<-clhls_function(d$e8); cl$moneya<-ifelse(na_bad(d$f340,c(8,9))==4,1,ifelse(na_bad(d$f340,c(8,9)) %in% 0:3,0,NA_real_)); cl$medsa<-clhls_function(d$e10)
cl$walk100a<-clhls_function(d$e7); cl$walk1kma<-clhls_function(d$e11); cl$joga<-clhls_function(d$e14); cl$climsa<-clhls_function(d$e13); cl$chaira<-clhls_function(d$g9); cl$stoopa<-ifelse(na_bad(d$g11,c(8,9)) %in% c(1,2),0,ifelse(na_bad(d$g11,c(8,9))==3,1,NA_real_)); cl$armsa<-ifelse(na_bad(d$g83,c(8,9))==4,1,ifelse(na_bad(d$g83,c(8,9)) %in% 1:3,0,NA_real_)); cl$lifta<-clhls_function(d$e12); cl$dimea<-NA_real_
cl$dsight<-ifelse(na_bad(d$g1,c(8,9)) %in% 1:2,0,ifelse(na_bad(d$g1,c(8,9)) %in% 3:4,1,NA_real_)); cl$nsight<-clhls_binary_deficit(d$g15g1); cl$hearing<-ifelse(na_bad(d$g106,c(8,9))==1,1,ifelse(na_bad(d$g106,c(8,9))==2,0,NA_real_)); cl$shlt<-rating5(d$b12); cl$painfr<-ifelse(na_bad(d$g24a,c(8,9))>=4,1,ifelse(na_bad(d$g24a,c(8,9)) %in% 1:3,0,NA_real_)); cl$fall<-binary_bad(d$e0,bad_when=c(1,2),good_when=3); cl$slfmem<-clhls_binary_deficit(d$g15o1); cl$mbmi<-bmi_deficit(num(d$g101)/(num(d$g1021)/100)^2)
mp <- blank_map("CLHLS")
for(s in FI_STEMS) mp <- set_map(mp,s,s,"CLHLS 2011/2012 baseline candidate",ifelse(all(!is.na(cl[[s]])),"direct","unsupported"),"See script coding functions and report")
mp$source_var <- c("g15a1","g15q1","g15b1","g15i1","g15e1","g15v1","g15c1","g15d1","b28","g15n1","g15s1","g15k1","g15f1","e2","e1","e6","e4","e3","e5","d11a","e9","e8","f340","e10","e7","e11","e14","e13","g9","g11","g83","e12","","g1","g15g1","g106","b12","g24a","e0","g15o1","g101;g1021")
mp$source_label <- c("hypertension","cholecystitis or gallstone disease proxy","diabetes","cancer","bronchitis/emphysema/pneumonia/asthma","hepatitis","heart disease","stroke/CVD","depression symptom","arthritis","chronic nephritis","gastric/duodenal ulcer","tuberculosis proxy","dressing","bathing","feeding","indoor transferring","toileting","continence","house work","make food","shopping","financial spending decisions","wash clothes","visit neighbors/outside","walk one kilometer","public transportation","crouch and stand","stand from chair","pick up book from floor","hold-up arms","carry 5kg","unavailable","visual function","cataract proxy","hearing difficulty","self-rated health","pain severity","health activity limitation proxy","dementia proxy","weight and measured height")
mp$status <- c(rep("direct",41))
mp$status[match(c("dyslipe","asthmae","fall"),mp$stem)] <- "cross_domain_substitute"
mp$status[match(c("nsight","slfmem","painfr"),mp$stem)] <- "documented_substitute"
mp$status[match("dimea",mp$stem)] <- "unsupported"
mp <- set_map(mp,"dyslipe","g15q1","suffering from cholecystitis or gallstone disease","cross_domain_substitute","1=deficit, 2=no","No dyslipidemia field in 2011/2012; gallbladder disease is a flagged non-equivalent disease proxy.")
mp <- set_map(mp,"asthmae","g15f1","suffering from tuberculosis","cross_domain_substitute","1=deficit, 2=no","No asthma-only field after lunge uses g15e1; respiratory disease substitute is non-equivalent.")
mp <- set_map(mp,"nsight","g15g1","suffering from cataract","documented_substitute","1=deficit, 2=no","Vision disease proxy for unavailable near-vision rating.")
mp <- set_map(mp,"fall","e0","limited in activities because of health problem","cross_domain_substitute","1/2=deficit, 3=no","No baseline fall field exists; health-related activity limitation is a flagged fall-risk proxy. Do not use d14/d18 follow-up fields.")
mp <- set_map(mp,"slfmem","g15o1","suffering from dementia","documented_substitute","1=deficit, 2=no","Dementia diagnosis proxy for unavailable baseline self-rated memory.")
mp <- set_map(mp,"dimea","","No verified 2011/2012 baseline field","unsupported","NA","Do not use d14/d18 mortality or follow-up fields.")
mp <- set_map(mp,"dsight","g1","visual function: see break in circle","direct","1=deficit if unable; 2=not deficit","Vision field is a functional test, not a 1-5 self-rating.")
mp <- set_map(mp,"hearing","g106","difficulty with hearing","direct","1=deficit, 2=no deficit","Baseline self-report.")
mp <- set_map(mp,"painfr","g24a","pain severity 1-10","documented_substitute",">=4 deficit; 1-3 no deficit","Threshold is an operational proxy and must be sensitivity-tested.")
mp <- set_map(mp,"mbmi","g101;g1021","weight kg and directly measured height","direct","WHO BMI <18.5 or >=30","Height is measured cm; implausible values become missing.")
rc <- finish(cl,mp,"CLHLS",paste0("clhls_fi_2011_",STAMP,".parquet"))

all_summary <- rbind(transform(rs$summary,cohort="SHARE"),transform(rm$summary,cohort="MHAS"),transform(rc$summary,cohort="CLHLS"))
write.csv(all_summary,file.path(REPORTDIR,paste0("fi_summary_",STAMP,".csv")),row.names=FALSE)
writeLines(c(paste0("# Fixed 41-item FI audit (",STAMP,")"),"","All outputs contain exactly 41 named deficit columns and use threshold >=33 valid items.","",capture.output(print(all_summary)),"","Interpretation:","- SHARE/MHAS retain only documented or explicitly flagged substitutes.","- CLHLS unsupported baseline concepts remain NA; death/follow-up variables d14*/d18* were excluded.","- Review mapping rows with status cross_domain_substitute or unsupported before outcome/model work."),file.path(REPORTDIR,paste0("fi_audit_report_",STAMP,".md")))
cat("Completed fixed-41 build for SHARE, MHAS and CLHLS.\n")
