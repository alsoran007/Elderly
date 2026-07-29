# CHARLS 2011 Gateway-aligned 43-item frailty index.
options(stringsAsFactors = FALSE, warn = 1)
suppressPackageStartupMessages({ library(haven); library(arrow) })
args <- commandArgs(FALSE); f <- grep('^--file=', args, value = TRUE)
script_path <- if (length(f)) sub('^--file=', '', f[1]) else 'code/02_harmonize/build_fi_charls.R'
root <- normalizePath(file.path(dirname(script_path), '../..'), mustWork = TRUE)
raw <- normalizePath(file.path(root, '..', 'sql', 'Charls', '2011'), mustWork = TRUE)
out_dir <- file.path(root, 'data', 'analysis'); res_dir <- file.path(root, 'results', 'fi_charls'); log_dir <- file.path(root, 'logs')
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE); dir.create(file.path(res_dir, 'tables'), recursive = TRUE, showWarnings = FALSE); dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
logc <- file(file.path(log_dir, 'build_fi_charls_2026-07-28.log'), 'wt', encoding = 'UTF-8')
sink(logc, type = 'output'); sink(logc, type = 'message')
finish <- function() { sink(type='message'); sink(type='output'); close(logc) }; on.exit(finish(), add=TRUE)
say <- function(...) cat(format(Sys.time(), '[%Y-%m-%d %H:%M:%S]'), ..., '\n')
ok <- function(x, msg) { if (!isTRUE(x)) stop('ASSERTION FAILED: ', msg); say('PASS:', msg) }
paths <- file.path(raw, c('demographic_background.dta','health_status_and_functioning.dta','biomarkers.dta','work_retirement_and_pension.dta'))
ok(all(file.exists(paths)), 'all four input modules exist')
demo <- read_dta(paths[1], .name_repair='minimal'); health <- read_dta(paths[2], .name_repair='minimal'); bio <- read_dta(paths[3], .name_repair='minimal'); work <- read_dta(paths[4], .name_repair='minimal')
ok(nrow(demo)==17705, 'demographic rows = 17705'); ok(nrow(health)==17596, 'health rows = 17596'); ok(nrow(bio)==13974, 'biomarker rows = 13974'); ok(nrow(work)==17524, 'work rows = 17524')
for (nm in c('demo','health','bio','work')) { z <- get(nm); z$id <- trimws(as.character(z$ID)); z$ID <- NULL; assign(nm,z); ok(!anyDuplicated(z$id), paste(nm,'IDs unique')) }
ok(sum(bio$id %in% demo$id)==13974, 'biomarker-demographic overlap = 13974')
dat <- merge(demo[,c('id','ba002_1','rgender')], health, by='id', all.x=TRUE, sort=FALSE)
dat <- merge(dat, bio[,c('id','qi002','ql002')], by='id', all.x=TRUE, sort=FALSE)
dat <- merge(dat, work[,c('id','fa001','fa002','fa003','fa005','fc013','fd030','fh004')], by='id', all.x=TRUE, sort=FALSE)
ok(nrow(dat)==17705, 'left merge preserves demographic rows')
rawv <- function(n) suppressWarnings(as.numeric(dat[[n]]))
bin <- function(x) { y<-rep(NA_real_,length(x)); y[x==1]<-1; y[x==2]<-0; y }
ord5 <- function(x) { y<-rep(NA_real_,length(x)); q<-x%in%1:5; y[q]<-(x[q]-1)/4; y }
diff_a <- function(x) { y<-rep(NA_real_,length(x)); y[x==1]<-0; y[x%in%2:4]<-1; y }
names43 <- c('hibpe','diabe','cancre','lunge','hearte','stroke','psyche','arthre','dyslipe','livere','kidneye','digeste','asthmae','dressa','batha','eata','beda','toilta','urina','moneya','medsa','shopa','mealsa','housewka','walk100a','walk1kma','joga','climsa','chaira','stoopa','armsa','lifta','dimea','dsight','nsight','hearing','shlt','painfr','fall','hlthlm_c','slfmem','mbmi','hearaid')
ok(length(names43)==43, '43 deficit names defined')
age <- 2011 - rawv('ba002_1'); age[!(rawv('ba002_1')>=1890 & rawv('ba002_1')<=2000)] <- NA; ok(sum(age>=60,na.rm=TRUE)==7669, 'age 60+ = 7669 using 2011 - birth year')
def <- data.frame(id=dat$id, age=age, sex=rawv('rgender'))
comorb <- c(hibpe='da007_1_',diabe='da007_3_',cancre='da007_4_',lunge='da007_5_',heart='da007_7_',stroke='da007_8_',psyche='da007_11_',arthre='da007_13_',dyslipe='da007_2_',livere='da007_6_',kidneye='da007_9_',digeste='da007_10_',asthmae='da007_14_')
for (nm in names(comorb)) def[[ifelse(nm=='heart','hearte',nm)]] <- bin(rawv(comorb[[nm]]))
front <- c('db001',paste0('db00',4:9)); all_clear <- Reduce('&',lapply(front,function(n)rawv(n)==1)); all_clear[is.na(all_clear)] <- FALSE
rescue <- data.frame(item=character(), rescued_n=integer()); adl <- c(dressa='db010',batha='db011',eata='db012',beda='db013',toilta='db014',urina='db015')
for (nm in names(adl)) { y<-diff_a(rawv(adl[[nm]])); take<-is.na(y)&all_clear; y[take]<-0; rescue<-rbind(rescue,data.frame(item=nm,rescued_n=sum(take))); def[[nm]]<-y }
iadl <- c(moneya='db019',medsa='db020',shopa='db018',mealsa='db017',housewka='db016'); for (nm in names(iadl)) def[[nm]] <- diff_a(rawv(iadl[[nm]]))
mob <- c(climsa='db005',chaira='db004',joga='db001',stoopa='db006',armsa='db007',lifta='db008',dimea='db009'); for (nm in names(mob)) def[[nm]] <- diff_a(rawv(mob[[nm]]))
w100 <- diff_a(rawv('db003')); r100 <- is.na(w100) & ((rawv('db001')==1)|(rawv('db002')==1)); r100[is.na(r100)]<-FALSE; w100[r100]<-0; def$walk100a<-w100
w1k <- diff_a(rawv('db002')); r1k <- is.na(w1k) & rawv('db001')==1; r1k[is.na(r1k)]<-FALSE; w1k[r1k]<-0; def$walk1kma<-w1k
vision <- function(n) { lens<-rawv('da032'); x<-rawv(n); y<-rep(NA_real_,length(x)); q<-lens%in%c(1,3)&x%in%1:5; y[q]<-(x[q]-1)/4; y[lens==2]<-1; y }
def$dsight<-vision('da033'); def$nsight<-vision('da034'); def$hearing<-ord5(rawv('da039'))
sh1<-rawv('da001'); sh2<-rawv('da080'); sh<-rep(NA_real_,length(sh1)); for(k in 1:5) sh[sh1==k|sh2==k]<-k; def$shlt<-ord5(sh)
def$painfr<-bin(rawv('da041')); def$fall<-bin(rawv('da023')); def$hearaid<-bin(rawv('da038'))
fc<-rawv('fc013'); fd<-rawv('fd030'); fh<-rawv('fh004'); def$hlthlm_c<-NA_real_; def$hlthlm_c[(fc==0)|(fd==0)|(fh==0)]<-0; def$hlthlm_c[(fc%in%1:365)|(fd%in%1:365)|(fh%in%1:365)]<-1
def$slfmem<-ord5(rawv('dc004'))
h<-rawv('qi002'); w<-rawv('ql002'); h[!(h>=130&h<=200)]<-NA; w[!(w>=25&w<=150)]<-NA; bmi<-w/(h/100)^2; bmi[!(bmi>=12&bmi<=60)]<-NA; def$mbmi<-NA_real_; def$mbmi[bmi<18.5|bmi>=30]<-1; def$mbmi[bmi>=18.5&bmi<30]<-0
ok(sum(!is.na(bmi))==13572,'BMI computable = 13572'); ok(abs(median(bmi,na.rm=TRUE)-23.1)<.2,'BMI median approximately 23.1')
def<-def[,c('id','age','sex',names43)]; m<-as.matrix(def[,names43]); def$fi_n_valid<-rowSums(!is.na(m)); def$fi_n_deficit<-rowSums(m,na.rm=TRUE); def$fi_excluded<-def$fi_n_valid<35; def$fi_full<-rowSums(m,na.rm=TRUE)/def$fi_n_valid; def$fi_full[def$fi_excluded]<-NA_real_
write_parquet(def,file.path(out_dir,'charls_fi_2011_2026-07-27.parquet')); write.csv(rescue,file.path(res_dir,'tables','adl_jump_rescue_counts.csv'),row.names=FALSE); ok(file.exists(file.path(out_dir,'charls_fi_2011_2026-07-27.parquet')),'FI parquet written'); say('Rows:',nrow(def),'included:',sum(!is.na(def$fi_full)),'excluded:',sum(def$fi_excluded)); say('Build complete')
