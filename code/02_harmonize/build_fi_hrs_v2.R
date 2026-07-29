#!/usr/bin/env Rscript
# Fixed 41-item HRS FI for 2012 RAND HRS Fat File.
# Raw data are read only; five unavailable disease slots use documented HRS substitutes.

suppressPackageStartupMessages({ library(haven); library(arrow) })

PROJ <- "D:/AI_project/project3"
STAMP <- "2026-07-29"
RAW <- "D:/AI_project/sql/HRS Products/RAND HRS Products(原始)/2012 RAND HRS Fat File/h12f3a.dta"
OUT <- file.path(PROJ, "data/analysis", paste0("hrs_fi_2012_", STAMP, ".parquet"))
RES <- file.path(PROJ, "results/fi_hrs_v2")
TAB <- file.path(RES, "tables")
LOG <- file.path(PROJ, "logs", paste0("build_fi_hrs_v2_", STAMP, ".log"))
dir.create(TAB, recursive=TRUE, showWarnings=FALSE)
dir.create(dirname(LOG), recursive=TRUE, showWarnings=FALSE)
lc <- file(LOG, open="wt", encoding="UTF-8")
sink(lc, type="output"); sink(lc, type="message")
on.exit({sink(type="message"); sink(type="output"); close(lc)}, add=TRUE)

FI_STEMS <- c(
  "hibpe","diabe","cancre","lunge","hearte","stroke","psyche","arthre",
  "kidneye","dizzy","fatigue","depressed_yr","ever_depression",
  "dressa","batha","eata","beda","toilta","urina",
  "housewka","mealsa","shopa","moneya","medsa",
  "walk100a","walk1kma","joga","climsa","chaira","stoopa","armsa","lifta","dimea",
  "dsight","nsight","hearing","shlt","painfr","fall","mbmi","slfmem"
)
stopifnot(length(FI_STEMS)==41L, !anyDuplicated(FI_STEMS))

MAP <- data.frame(
  stem=FI_STEMS,
  domain=c(rep("comorbidity",13),rep("adl",6),rep("iadl",5),rep("mobility",9),rep("sensory",3),rep("general",3),"cognition"),
  source_vars=c(
    "nc005","nc010","nc018","nc030","nc036","nc053","nc065","nc070",
    "nc017","nc145","nc148","nc150","nc271",
    "ng014","ng021","ng023","ng025","ng030","nc087",
    "ng058","ng041","ng044","ng059","ng050",
    "ng003","ng001","ng002","ng007","ng005","ng008","ng009","ng011","ng012",
    "nc096","nc097","nc103","nc001","nc104","nc079","nc139;nc141;nc142","nd101"
  ),
  status=c(rep("direct",8),rep("documented_substitute",5),rep("direct",28)),
  coding_note=NA_character_, stringsAsFactors=FALSE
)
MAP$coding_note <- c(
  rep("1=yes; 5=no; other codes missing",13),
  rep("1=yes; 5=no; 6=unable deficit; 7=does not do no; other codes missing",5),
  "1=yes; 5=no; other codes missing",
  rep("1=yes; 5=no; 6=unable deficit; 7=does not do no; other codes missing",14),
  rep("1=excellent to 5=poor; (x-1)/4",3),
  "1=excellent to 5=poor; (x-1)/4",
  "1=yes; 5=no; other codes missing",
  "Weight pounds and height feet/inches; BMI deficit outside 18.5-30",
  "1=excellent to 5=poor; (x-1)/4"
)
MAP$review_note <- c(
  rep("",8),
  "Kidney trouble due to diabetes replaces unavailable general kidney disease.",
  "Ever dizzy replaces an unavailable symptom/mobility slot.",
  "Severe fatigue replaces an unavailable symptom slot.",
  "Felt depressed in past year is a documented substitute.",
  "Ever had depression is a separate lifetime depression substitute.",
  rep("",28)
)

num <- function(x) suppressWarnings(as.numeric(x))
yesno <- function(x) { z<-num(x); ifelse(z==1,1,ifelse(z==5,0,NA_real_)) }
function_deficit <- function(x, iadl=FALSE) {
  z<-num(x)
  ifelse(z==1 | z==6,1,ifelse(z==5 | (iadl & z==7),0,NA_real_))
}
rating5 <- function(x) { z<-num(x); ifelse(z>=1 & z<=5,(z-1)/4,NA_real_) }

cat("Input:",RAW,"\n")
if (!file.exists(RAW)) stop("HRS raw file not found")
d <- read_dta(RAW)
cat("Rows:",nrow(d)," variables:",ncol(d),"\n")
required <- unique(c("hhidpn","na019",unlist(strsplit(MAP$source_vars,";",fixed=TRUE))))
missing_required <- setdiff(required,names(d))
if (length(missing_required)) stop("Missing source fields: ",paste(missing_required,collapse=", "))

fi <- data.frame(hhidpn=d$hhidpn, age=num(d$na019), stringsAsFactors=FALSE)
for (i in 1:8) fi[[FI_STEMS[i]]] <- yesno(d[[MAP$source_vars[i]]])
for (i in 9:13) fi[[FI_STEMS[i]]] <- yesno(d[[MAP$source_vars[i]]])
for (i in 14:18) fi[[FI_STEMS[i]]] <- function_deficit(d[[MAP$source_vars[i]]])
fi$urina <- yesno(d$nc087)
for (i in 20:24) fi[[FI_STEMS[i]]] <- function_deficit(d[[MAP$source_vars[i]]], iadl=TRUE)
for (i in 25:33) fi[[FI_STEMS[i]]] <- function_deficit(d[[MAP$source_vars[i]]])
fi$dsight <- rating5(d$nc096); fi$nsight <- rating5(d$nc097); fi$hearing <- rating5(d$nc103)
fi$shlt <- rating5(d$nc001); fi$painfr <- yesno(d$nc104); fi$fall <- yesno(d$nc079)
wt_kg <- num(d$nc139)*0.453592
ht_ft <- num(d$nc141); ht_in <- num(d$nc142)
ht_total <- ht_ft*12+ht_in
bmi <- wt_kg/((ht_total*0.0254)^2)
bmi[!(ht_ft %in% 4:6 & ht_in %in% 0:11 & wt_kg>=27 & wt_kg<=227)] <- NA_real_
fi$mbmi <- ifelse(!is.na(bmi),ifelse(bmi<18.5 | bmi>=30,1,0),NA_real_)
fi$slfmem <- rating5(d$nd101)

mat <- fi[,FI_STEMS,drop=FALSE]
mat[] <- lapply(mat,num)
fi$fi_n_valid <- rowSums(!is.na(mat))
fi$fi_n_found <- 41L
fi$fi_threshold <- 33L
fi$fi_full <- ifelse(fi$fi_n_valid>=33,rowSums(mat,na.rm=TRUE)/fi$fi_n_valid,NA_real_)
fi$fi_excluded <- fi$fi_n_valid<33
fi$age_60_plus <- !is.na(fi$age) & fi$age>=60
stopifnot(all(fi$fi_full[!is.na(fi$fi_full)]>=0 & fi$fi_full[!is.na(fi$fi_full)]<=1))

MAP$n_nonmissing <- vapply(FI_STEMS,function(s) sum(!is.na(mat[[s]])),integer(1))
MAP$deficit_rate <- vapply(FI_STEMS,function(s) mean(mat[[s]],na.rm=TRUE),numeric(1))
MAP$deficit_rate[is.nan(MAP$deficit_rate)] <- NA_real_
summary <- data.frame(
  metric=c("raw_rows","age60_rows","fi_eligible_all","fi_eligible_age60","fi_median_all","fi_median_age60","fi_min","fi_max","item_count","threshold"),
  value=c(nrow(fi),sum(fi$age_60_plus),sum(!fi$fi_excluded),sum(fi$age_60_plus & !fi$fi_excluded),
          median(fi$fi_full,na.rm=TRUE),median(fi$fi_full[fi$age_60_plus],na.rm=TRUE),
          min(fi$fi_full,na.rm=TRUE),max(fi$fi_full,na.rm=TRUE),41,33)
)
write.csv(MAP,file.path(TAB,paste0("hrs_fi_v2_mapping_",STAMP,".csv")),row.names=FALSE,na="")
write.csv(summary,file.path(TAB,paste0("hrs_fi_v2_summary_",STAMP,".csv")),row.names=FALSE)

corr <- suppressWarnings(cor(mat,use="pairwise.complete.obs"))
high <- which(abs(corr)>.85 & upper.tri(corr),arr.ind=TRUE)
high_df <- if (nrow(high)) data.frame(item_1=rownames(corr)[high[,1]],item_2=colnames(corr)[high[,2]],abs_correlation=abs(corr[high])) else data.frame(item_1=character(),item_2=character(),abs_correlation=numeric())
write.csv(high_df,file.path(TAB,paste0("hrs_fi_v2_high_correlation_pairs_",STAMP,".csv")),row.names=FALSE)
age_group <- cut(fi$age,c(0,59,69,79,89,Inf),right=TRUE)
age_gradient <- aggregate(fi$fi_full,list(age_group=age_group),function(x) c(n=length(x),mean=mean(x),median=median(x)),na.action=na.omit)
write.csv(age_gradient,file.path(TAB,paste0("hrs_fi_v2_age_gradient_",STAMP,".csv")),row.names=FALSE)
write_parquet(fi,OUT)

report <- c(
  paste0("# HRS Fixed 41-item FI (",STAMP,")"),"",
  "The HRS FI uses exactly 41 unique deficit columns and requires at least 33 valid items for FI.",
  paste0("- Input: ",RAW),paste0("- Output: ",OUT),paste0("- Rows: ",nrow(fi)),
  paste0("- Age 60+: ",sum(fi$age_60_plus)),paste0("- FI eligible all: ",sum(!fi$fi_excluded)),
  paste0("- FI eligible age 60+: ",sum(fi$age_60_plus & !fi$fi_excluded)),
  "- Threshold: 33/41 valid items",
  paste0("- FI range: ",round(min(fi$fi_full,na.rm=TRUE),4)," to ",round(max(fi$fi_full,na.rm=TRUE),4)),"",
  "## Documented HRS substitutions","",
  "- nc017 kidney trouble due to diabetes replaces unavailable general kidney disease.",
  "- nc145, nc148, nc150, and nc271 are documented symptom/depression substitutes.",
  "- ng002 is used for jogging; ng009 for reaching arms; nc087 for incontinence.",
  "- nc096 and nc097 are distal and near vision separately; nd101 is rated memory.",
  "- BMI uses nc139 pounds and nc141 feet plus nc142 inches.","",
  "## Validation","",
  "- FI values are checked to be within [0,1].",
  "- Source-derived item columns are unique and exactly 41.",
  paste0("- High-correlation pairs (absolute r > 0.85): ",nrow(high_df)),
  paste0("- Mapping: ",file.path(TAB,paste0("hrs_fi_v2_mapping_",STAMP,".csv"))),
  paste0("- Log: ",LOG)
)
writeLines(report,file.path(RES,paste0("hrs_fi_v2_report_",STAMP,".md")),useBytes=TRUE)
cat("PASS\nOutput:",OUT,"\n")
