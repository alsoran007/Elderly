# Task: HRS 2012 FI 构建（RAND Fat File 变量映射）

## 背景

HRS 的成品 harmonized 文件（`H_HRS_d.dta`）只含汇总分，没有个体 deficit 项。
FI 必须从 RAND 2012 Fat File 构建：`D:/AI_project/sql/HRS Products/RAND HRS Products(原始)/2012 RAND HRS Fat File/h12f3a.dta`（8,902 变量，RAND 私有命名规则）。

## 铁律

1. `D:/AI_project/sql/` 只读
2. R 路径：`D:/LeStoreDownload/R/R-4.4.1/bin/x64/Rscript.exe`，装包加 `type="binary"`
3. 脚本幂等；遇到与本文档已知数字矛盾停下报告
4. **不做 FI 与死亡的关联分析**

## 已知的 RAND 2012 变量（我已核实标签和取值）

| FI stem | RAND 变量 | 标签 | 编码 |
|---|---|---|---|
| hibpe | nc005 | high blood pressure | 1=yes,4/5=no |
| cancre | nc018 | cancer of any kind excl skin | 1=yes,4/5=no |
| lunge | nc030 | lung disease | 1=yes,4/5=no |
| stroke | nc053 | stroke | 1=yes,4/5=no |
| dressa | ng014 | difficulty- dressing | 1=yes,5=no |
| batha | ng021 | difficulty bathing | 1=yes,5=no |
| beda | ng025 | difficulty get in/out bed | 1=yes,5=no |
| toilta | ng031 | adl toilet help (→ difficulty) | 1=yes,5=no |
| mealsa | ng041 | iadl meal preparation difficulty | 1=yes,5/6/7=no |
| shopa | ng044 | iadl groc shop difficulty | 1=yes,5/7=no |
| medsa | 待查 | taking medication difficulty | — |
| moneya | 待查 | managing money difficulty | — |
| housewka | 待查 | housework difficulty | — |
| walk100a | ng003 | difficulty- walking 1 block | 1=yes,5/6=no |
| walk1kma | ng001 | difficulty- walking several blocks | 1=yes,5/6/7=no |
| climsa | ng007 | difficulty- climbing 1 flight stairs | 1=yes,5/6/7=no |
| chaira | ng005 | difficulty- getting up from chair | 1=yes,5=no |
| stoopa | 待查 | difficulty- stooping/kneeling | — |
| armsa | 待查 | difficulty- reaching arms above shoulder | — |
| lifta | ng010 | difficulty- pull/push large objects (≈lift) | 1=yes,5/6/7=no |
| dimea | ng012 | difficulty- picking up dime | 1=yes,5=no |
| age | na019 | r current age calculation | 连续 |

**「待查」变量（约13 个），请按以下方法找：**

```r
# 用标签关键词搜索
lb <- sapply(d1, function(x){a<-attr(x,"label"); if(is.null(a)) "" else a})
hits <- function(kw) grep(kw, lb, value=FALSE, ignore.case=TRUE)
# 用变量名前缀 + 取值范围判断
```

需要找的概念：糖尿病(diabetes)、心脏病(heart disease/attack)、精神/心理(psychiatric/mental)、关节炎(arthritis)、血脂异常(cholesterol/lipid)、肝病(liver)、肾病(kidney)、消化系统(digestive/stomach)、哮喘(asthma)、大小便控制(continence/bladder/bowel)、做家务、服药、管钱、蹲下(stoop/kneel)、举手过肩(arm above shoulder)、自评健康(self-rated health)、疼痛(chronic pain)、跌倒(fall)、记忆自评(self-rated memory)、BMI(体重/身高)、视力(eyesight/vision)、听力(hearing)、抑郁(CES-D/depressive)。

## FI 编码规则（RAND 特有，与 CHARLS 不同）

RAND HRS 的编码通常为：`1=yes（有问题）`，`5=no（没问题）`，`6/7=could not do`（视为 deficit=1），`8/9/NA=缺失`。

**通用规则**：
- 共病：1→1，其他有效值→0，缺失→NA
- ADL/IADL/活动：1→1（有困难），5→0，6/7→1（不能做），8/9→NA
- 连续型（BMI、抑郁总分等）：按各自规则映射到 0-1

## 60+ 子样本

用 `na019 >= 60`。

已知 HRS 2012 基线 N=20,554，60+ N=13,867，4 年事件 2,352（D-018）。

## 输出规格

```
data/analysis/hrs_fi_2012_2026-07-28.parquet
results/fi_hrs/fi_hrs_diagnostic_report_2026-07-28.md
results/fi_hrs/tables/hrs_fi_stem_mapping_2026-07-28.csv   ← 最重要：RAND变量→FI stem 对照表
```

`hrs_fi_stem_mapping_2026-07-28.csv` 格式：`fi_stem, rand_var, rand_label, recode_rule, missing_codes`

## 回复格式（25行以内）

1. 找到的 stems 数 / 41（列出 NOT_FOUND）
2. FI 中位数（全样本 + 60+ 各一个）
3. FI-eligible 60+ N
4. RAND 变量对照表路径
5. 你发现的意外问题（最多3条）
