# Task: HRS / SHARE / MHAS FI 提取（使用现成 harmonized 文件）

## 背景与优先级

CHARLS FI（41 项，Gateway 标准命名）已完成：`data/analysis/charls_fi_2011_2026-07-27.parquet`

HRS / SHARE / MHAS 的成品 harmonized 文件使用**完全相同的 Gateway 变量命名规则**（`r{wave}hibpe`、`r{wave}dressa` 等），因此这三个队列的 FI 提取远比 CHARLS 简单——直接从对应变量列读出来就好，不需要重新写 harmonization 逻辑。

本任务同时处理三个队列，产出三份 FI parquet，格式与 CHARLS FI 保持一致。

---

## 铁律

1. **`D:/AI_project/sql/` 全程只读**
2. R 路径：`D:/LeStoreDownload/R/R-4.4.1/bin/x64/Rscript.exe`，装包加 `type="binary"`
3. 脚本幂等，遇矛盾停下报告
4. **不做 FI 与死亡的关联分析**，不碰结局变量

---

## 输入文件（harmonized，全部已就绪）

```
HRS  : D:/AI_project/sql/HRS Products/harmonised HRS/H_HRS_d.dta    (855MB, 16349 vars)
SHARE: D:/AI_project/sql/share harmonised/GH_SHARE_g.dta             (1.8GB, 8096 vars)
MHAS : D:/AI_project/sql/MHAS/H_MHAS_c2.dta                         (172MB, 5241 vars)
```

**注意大文件**：读取时必须用 `col_select=` 只选需要的列，不要全量读入内存。先用 `read_dta(f, n_max=0)` 获取变量名列表，再选取 FI 所需列。

---

## FI 的 41 项变量（以 CHARLS wave 1 为参照）

以下是目标变量 stem 列表，需要在各队列找对应的波次变量。各队列的波次编号不同：

| Stem | 域 | CHARLS (wave 1) | HRS 对应波次 | SHARE 对应波次 | MHAS 对应波次 |
|---|---|---|---|---|---|
| hibpe | 共病 | r1hibpe | **r11hibpe** (2012) | **r4hibpe** (2011 w4) | **r3hibpe** (2012) |

其余 40 个 stem：diabe cancre lunge hearte stroke psyche arthre dyslipe livere kidneye digeste asthmae dressa batha eata beda toilta urina housewka mealsa shopa moneya medsa walk100a walk1kma joga climsa chaira stoopa armsa lifta dimea dsight nsight hearing shlt painfr fall slfmem mbmi

**规则**：

- **HRS**：基线 wave 11（2012 年），变量名前缀 `r11`。例：`r11hibpe`、`r11dressa`、`r11mbmi`
- **SHARE**：基线 wave 4（2011 年），变量名前缀 `r4`。例：`r4hibpe`、`r4dressa`
- **MHAS**：基线 wave 3（2012 年），变量名前缀 `r3`。例：`r3hibpe`、`r3dressa`

**波次编号由我预先指定，不要自行查找**。若某变量在指定波次不存在，报告该变量名并标记 `NOT_FOUND`。

---

## 每个队列需要做的事

### Step 1：变量可得性检查

对 41 个 stem，逐一确认 `r{wave}{stem}` 是否存在于该文件。输出可得性矩阵（41 行 × 3 队列）。

### Step 2：FI 构建

与 CHARLS FI 完全相同的规则（`docs/fi_specification_2026-07-27.md`）：

```r
# 每个 deficit 列已经是 0/1/连续 0-1
# FI = sum(deficit) / count(non-missing deficit)
# 纳入门槛：非缺失项 >= 80%（41 项中至少 33 项有值）
fi_full = rowSums(deficit_cols, na.rm=TRUE) / rowSums(!is.na(deficit_cols))
fi_n_valid = rowSums(!is.na(deficit_cols))
fi_excluded = (fi_n_valid < 33)
fi_full = ifelse(fi_excluded, NA, fi_full)
```

**不需要重新做 recode**——Gateway harmonized 文件里的 `r{wave}dressa` 等已经是 0/1 编码，与 CHARLS 的 Gateway 对齐完全一致。直接读出来就是可用的 deficit 值。

### Step 3：60+ 子样本

- HRS：年龄变量 `r11agey_e`（若不存在试 `r11agey`）
- SHARE：`r4agey`
- MHAS：`r3agey`（主）+ `rabyear` + `r3iwy` 派生（备用，见 D-022）

MHAS age 规则：
```r
age_mhas = case_when(
  !is.na(r3agey) & r3agey>=20 & r3agey<=110 ~ r3agey,
  !is.na(rabyear) & !is.na(r3iwy) ~ as.numeric(r3iwy - rabyear),
  TRUE ~ NA_real_
)
age60plus = (!is.na(age_mhas) & age_mhas >= 60)
```

### Step 4：基本诊断

每个队列输出：
- FI 中位数 / 均值 / 60+ 组的中位数（期望在 0.10–0.30 范围）
- FI 分布偏度
- 60+ 中 FI 可计算人数
- 不可计算（NA）的原因（哪些 stem NOT_FOUND 或缺失率过高）

---

## 交付清单

1. `code/02_harmonize/extract_fi_hrs_share_mhas.R`
2. `data/analysis/hrs_fi_2012_2026-07-28.parquet`
3. `data/analysis/share_fi_2011_2026-07-28.parquet`
4. `data/analysis/mhas_fi_2012_2026-07-28.parquet`
5. `results/fi_validation_cohorts/fi_availability_matrix_2026-07-28.csv`（41 stem × 3 队列）
6. `results/fi_validation_cohorts/fi_summary_2026-07-28.md`（三队列诊断报告）
7. `logs/extract_fi_hrs_share_mhas_2026-07-28.log`

---

## 回复格式（30 行以内）

1. 三队列各自的可得 stem 数 / 41（NOT_FOUND 列表）
2. 三队列各自的 FI 中位数和 60+ 可计算 N
3. 你发现的意外问题（最多 3 条）
4. 产物路径列表
