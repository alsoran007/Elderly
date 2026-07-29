#!/usr/bin/env Rscript
# Fixed 41-item KLoSA wave-4 FI. Raw data are read only.
# Substitute variables and directional recoding are documented below and in the report.

suppressPackageStartupMessages({ library(haven); library(arrow) })
PROJ <- "D:/AI_project/project3"
STAMP <- "2026-07-29"
RAW <- "D:/AI_project/sql/KLOSA/KLoSA 1-9th wave (STATA)/w04_e.dta"
OUT <- file.path(PROJ,"data/analysis",paste0("klosa_fi_2012_",STAMP,".parquet"))
RES <- file.path(PROJ,"results/fi_klosa_v2")
TAB <- file.path(RES,"tables")
LOG <- file.path(PROJ,"logs",paste0("build_fi_klosa_v2_",STAMP,".log"))
dir.create(TAB,recursive=TRUE,showWarnings=FALSE); dir.create(dirname(LOG),recursive=TRUE,showWarnings=FALSE)
lc <- file(LOG,open="wt",encoding="UTF-8"); sink(lc,type="output"); sink(lc,type="message")
on.exit({sink(type="message"); sink(type="output"); close(lc)},add=TRUE)

FI_STEMS <- c(
  "hibpe","diabe","cancre","lunge","livere","hearte","stroke","psyche","arthre",
  "other_disease","weight_change","gloom_2wk","restless_sleep",
  "dressa","batha","eata","beda","toilta","urina",
  "housewka","mealsa","shopa","moneya","medsa",
  "wash_groom","laundry","near_out","transport_out","phone","activity_health","vision_activity","hearing_activity","grooming",
  "dsight","nsight","hearing","shlt","painfr","fall","mbmi","concentration"
)
stopifnot(length(FI_STEMS)==41L,!anyDuplicated(FI_STEMS))
MAP <- data.frame(
  stem=FI_STEMS,
  domain=c(rep("comorbidity",13),rep("adl",6),rep("iadl",5),rep("mobility",9),rep("sensory",3),rep("general",4),"cognition"),
  source_vars=c(
    "w04C006","w04C011","w04C016","w04C023","w04C028","w04C033","w04C038","w04C043","w04C048",
    "w04C103","w04C106","w04C141","w04C148",
    "w04C201","w04C203","w04C204","w04C205","w04C206","w04C068",
    "w04C209","w04C210","w04C214","w04C215","w04C217",
    "w04C202","w04C211","w04C212","w04C213","w04C216","w04C005","w04C081","w04C084","w04C208",
    "w04C075","w04C076","w04C083","w04C001","w04C102","w04C056","w04C105;w04C107","w04C143"
  ),
  status=c(rep("direct",9),rep("documented_substitute",4),rep("direct",11),rep("documented_substitute",9),rep("direct",7),"documented_substitute"),
  coding_note=NA_character_, stringsAsFactors=FALSE
)
MAP$coding_note <- c(
  rep("1=yes; 5=no; -8/-9 missing",9),
  "1=yes; 5=no; -8/-9 missing","1:4=weight change deficit; 5=no change","1/3=yes; 5=no; -8/-9 missing","1=rarely to 4=most/all; (x-1)/3",
  rep("1=no help; 3=some help; 5=full help; -8/-9 missing",5),"1=yes; 5=no; -8/-9 missing",
  rep("1=no help; 3=some help; 5=full help; -8/-9 missing",5),
  rep("1=no help; 3=some help; 5=full help; -8/-9 missing",5),
  "1=very much limited to 4=not at all; (4-x)/3","1=yes; 5=no; -8/-9 missing","1=yes; 5=no; -8/-9 missing","1=no help; 3=some help; 5=full help; -8/-9 missing",
  rep("1=very good to 5=very bad; (x-1)/4",3),"1=excellent to 5=poor; (x-1)/4","1=yes; 5=no; -8/-9 missing","1=yes; 5=no; -8/-9 missing","Weight kg and height cm; BMI deficit outside 18.5-30","1=rarely to 4=most/all; (x-1)/3"
)
MAP$review_note <- c(
  rep("",9),"Other disease substitutes an unavailable disease slot.","Recent >5 kg weight change substitutes a metabolic symptom slot.","Two-week gloom substitutes a depressive-symptom slot.","Restless sleep substitutes a symptom slot.",
  rep("",28)
)

num <- function(x) { z<-suppressWarnings(as.numeric(x)); z[z %in% c(-8,-9)]<-NA_real_; z }
yesno <- function(x) { z<-num(x); ifelse(z==1,1,ifelse(z==5,0,NA_real_)) }
help <- function(x) { z<-num(x); ifelse(z==1,0,ifelse(z==3,.5,ifelse(z==5,1,NA_real_))) }
rating5 <- function(x) { z<-num(x); ifelse(z>=1 & z<=5,(z-1)/4,NA_real_) }
freq4 <- function(x) { z<-num(x); ifelse(z>=1 & z<=4,(z-1)/3,NA_real_) }

if (!file.exists(RAW)) stop("KLoSA raw file not found")
all_names <- names(read_dta(RAW,n_max=0))
id_name <- intersect(c("pid","PID","w04PID","w04pid"),all_names)[1]
if (is.na(id_name)) stop("No KLoSA PID field found")
vars <- unique(c(id_name,"w04A002_age",unlist(strsplit(MAP$source_vars,";",fixed=TRUE))))
missing_vars <- setdiff(vars,all_names)
if (length(missing_vars)) stop("Missing source fields: ",paste(missing_vars,collapse=", "))
d <- read_dta(RAW,col_select=all_of(vars))
fi <- data.frame(pid=d[[id_name]],age=num(d$w04A002_age),stringsAsFactors=FALSE)
for (i in 1:9) fi[[FI_STEMS[i]]] <- yesno(d[[MAP$source_vars[i]]])
fi$other_disease <- yesno(d$w04C103)
fi$weight_change <- ifelse(num(d$w04C106)>=1 & num(d$w04C106)<=4,1,ifelse(num(d$w04C106)==5,0,NA_real_))
fi$gloom_2wk <- ifelse(num(d$w04C141)%in%c(1,3),1,ifelse(num(d$w04C141)==5,0,NA_real_))
fi$restless_sleep <- freq4(d$w04C148)
for (i in 14:18) fi[[FI_STEMS[i]]] <- help(d[[MAP$source_vars[i]]])
fi$urina <- yesno(d$w04C068)
for (i in 20:24) fi[[FI_STEMS[i]]] <- help(d[[MAP$source_vars[i]]])
for (i in 25:29) fi[[FI_STEMS[i]]] <- help(d[[MAP$source_vars[i]]])
fi$activity_health <- ifelse(num(d$w04C005)>=1 & num(d$w04C005)<=4,(4-num(d$w04C005))/3,NA_real_)
fi$vision_activity <- yesno(d$w04C081); fi$hearing_activity <- yesno(d$w04C084); fi$grooming <- help(d$w04C208)
fi$dsight <- rating5(d$w04C075); fi$nsight <- rating5(d$w04C076); fi$hearing <- rating5(d$w04C083)
fi$shlt <- rating5(d$w04C001); fi$painfr <- yesno(d$w04C102); fi$fall <- yesno(d$w04C056)
bmi <- num(d$w04C105)/(num(d$w04C107)/100)^2
bmi[!(num(d$w04C105)>=25 & num(d$w04C105)<=250 & num(d$w04C107)>=120 & num(d$w04C107)<=220)] <- NA_real_
fi$mbmi <- ifelse(!is.na(bmi),ifelse(bmi<18.5 | bmi>=30,1,0),NA_real_)
fi$concentration <- freq4(d$w04C143)

mat <- fi[,FI_STEMS,drop=FALSE]; mat[] <- lapply(mat,num)
fi$fi_n_valid <- rowSums(!is.na(mat);)
fi$fi_n_found <- 41L; fi$fi_threshold <- 33L
fi$fi_full <- ifelse(fi$fi_n_valid>=33,rowSums(mat,na.rm=TRUE)/fi$fi_n_valid,NA_real_)
fi$fi_excluded <- fi$fi_n_valid<33; fi$age_60_plus <- !is.na(fi$age) & fi$age>=60
stopifnot(all(fi$fi_full[!is.na(fi$fi_full)]>=0 & fi$fi_full[!is.na(fi$fi_full)]<=1))
MAP$n_nonmissing <- vapply(FI_STEMS,function(s) sum(!is.na(mat[[s]])),integer(1))
MAP$deficit_rate <- vapply(FI_STEMS,function(s) mean(mat[[s]],na.rm=TRUE),numeric(1)); MAP$deficit_rate[is.nan(MAP$deficit_rate)]<-NA_real_
summary <- data.frame(metric=c("raw_rows","age60_rows","fi_eligible_all","fi_eligible_age60","fi_median_all","fi_median_age60","fi_min","fi_max","item_count","threshold"),value=c(nrow(fi),sum(fi$age_60_plus),sum(!fi$fi_excluded),sum(fi$age_60_plus & !fi$fi_excluded),median(fi$fi_full,na.rm=TRUE),median(fi$fi_full[fi$age_60_plus],na.rm=TRUE),min(fi$fi_full,na.rm=TRUE),max(fi$fi_full,na.rm=TRUE),41,33))
write.csv(MAP,file.path(TAB,paste0("klosa_fi_v2_mapping_",STAMP,".csv")),row.names=FALSE,na="")
write.csv(summary,file.path(TAB,paste0("klosa_fi_v2_summary_",STAMP,".csv")),row.names=FALSE)
corr <- suppressWarnings(cor(mat,use="pairwise.complete.obs")); high <- which(abs(corr)>.85 & upper.tri(corr),arr.ind=TRUE)
high_df <- if (nrow(high)) data.frame(item_1=rownames(corr)[high[,1]],item_2=colnames(corr)[high[,2]],abs_correlation=abs(corr[high])) else data.frame(item_1=character(),item_2=character(),abs_correlation=numeric())
write.csv(high_df,file.path(TAB,paste0("klosa_fi_v2_high_correlation_pairs_",STAMP,".csv")),row.names=FALSE)
age_group <- cut(fi$age,c(0,59,69,79,89,Inf),right=TRUE)
age_gradient <- aggregate(fi$fi_full,list(age_group=age_group),function(x) c(n=length(x),mean=mean(x),median=median(x)),na.action=na.omit)
write.csv(age_gradient,file.path(TAB,paste0("klosa_fi_v2_age_gradient_",STAMP,".csv")),row.names=FALSE)
write_parquet(fi,OUT)
report <- c(paste0("# KLoSA Fixed 41-item FI (",STAMP,")"),"","KLoSA wave 4 uses exactly 41 unique deficit columns and requires at least 33 valid items for FI.",paste0("- Input: ",RAW),paste0("- Output: ",OUT),paste0("- Rows: ",nrow(fi)),paste0("- Age 60+: ",sum(fi$age_60_plus)),paste0("- FI eligible all: ",sum(!fi$fi_excluded)),paste0("- FI eligible age 60+: ",sum(fi$age_60_plus & !fi$fi_excluded)),"- Threshold: 33/41 valid items",paste0("- FI range: ",round(min(fi$fi_full,na.rm=TRUE),4)," to ",round(max(fi$fi_full,na.rm=TRUE),4)),"","## Substitute-variable rules","","- Four condition/general slots use w04C103, w04C106, w04C141, and w04C148.","- Nine function slots use w04C202, w04C208, w04C211, w04C212, w04C213, w04C216, w04C005, w04C081, and w04C084.","- Help-needed items map 1=no help, 3=some help, 5=full help to 0, 0.5, 1.","- Stroke code 3 (suspected stroke/TIA) is not counted in the primary FI and needs sensitivity review.","","## Validation","", "- FI values are checked to be within [0,1].","- Source-derived item columns are unique and exactly 41.",paste0("- High-correlation pairs (absolute r > 0.85): ",nrow(high_df)),paste0("- Mapping: ",file.path(TAB,paste0("klosa_fi_v2_mapping_",STAMP,".csv"))),paste0("- Log: ",LOG))
writeLines(report,file.path(RES,paste0("klosa_fi_v2_report_",STAMP,".md")),useBytes=TRUE)
cat("PASS\nOutput:",OUT,"\n")
