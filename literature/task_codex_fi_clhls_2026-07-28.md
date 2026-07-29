# Task: CLHLS 2011 FI 构建（codebook 自建）

## 背景

CLHLS 无官方 Gateway harmonized 文件，需从原始 SPSS 自建41项 FI。

## 铁律

1. `D:/AI_project/sql/` 只读
2. **必须用 R `haven::read_sav()`**（pyreadstat 对这个文件完全失败）
3. R 路径：`D:/LeStoreDownload/R/R-4.4.1/bin/x64/Rscript.exe`，装包加 `type="binary"`
4. 读取时只选需要的列（`col_select=`），3046 个变量全读没必要
5. 不做 FI 与死亡的关联分析

## 输入

```
主文件：D:/AI_project/sql/CLHLS/CLHLS_dataset_2008-2018_SPSS/clhls_2011_2018_longitudinal_dataset_released_version1.sav
codebook：D:/AI_project/sql/CLHLS/CLHLS_codebook 1998-2018/codebook_for_2011_2018_longitudinal_dataset.docx
```

已知：N=9,765，`trueage` 为核验年龄，60+ N=9,749（几乎全样本）。

## 核心任务

### Step 1：从 codebook 找 FI 相关变量

用 `officer::read_docx()` 读取 docx codebook，搜索以下概念的变量名：

共病（13）：高血压、糖尿病、癌症/肿瘤、肺病/支气管炎/肺气肿、心脏病/冠心病/心肌梗死、脑卒中/偏瘫、精神/情绪问题、关节炎/风湿、血脂异常/高胆固醇、肝病、肾病、消化系统疾病、哮喘

ADL（6）：穿衣、洗澡/淋浴、进食/吃饭、起立/坐下/起床、如厕/使用马桶、大小便控制/失禁

IADL（5）：做家务、做饭/烹饪、购物、管理钱财/财务、服药/用药

活动能力（9）：走路（100米/100步）、爬楼梯、蹲下/弯腰/跪下、举手过肩、提重物（5公斤）、拿起硬币、上下椅子、平衡、户外行走

感觉（3）：视力、听力、口腔/牙齿/咀嚼

一般健康（4+）：自评健康、疼痛、跌倒、体重/BMI

认知（1）：记忆自评

### Step 2：对每个找到的变量输出频数表，确定编码规则

CLHLS 的常见缺失码是 88（不知道）、99（不回答）、8、9。

### Step 3：按 FI 规格构建41 项 deficit（每项 0/1 或 0-1 连续）

FI 计算规则（与 CHARLS 相同）：

```r
fi_full = rowSums(deficit_cols, na.rm=TRUE) / rowSums(!is.na(deficit_cols))
threshold = ceiling(0.8 * n_found)    # 80% of AVAILABLE items
fi_full[fi_n_valid < threshold] <- NA
```

**多分类量表（视力、听力、自评健康等）必须先映射到 0-1 再进入FI，不能用原始值！**（0=最好，1=最差）

### Step 4：基本诊断

- FI 中位数（全样本 + 60+）
- FI max（必须 ≤1，若 >1 说明有量纲错误）
- stems 找到数 / 41
- 找不到的 stem 列表

## 输出

```
data/analysis/clhls_fi_2011_2026-07-28.parquet
results/fi_clhls/fi_clhls_diagnostic_report_2026-07-28.md
results/fi_clhls/tables/clhls_fi_varmap_2026-07-28.csv   ← 变量对照表：fi_stem, clhls_var, recode_rule
```

## 回复格式（20行以内）

1. stems 找到数 / 41（NOT_FOUND 列表）
2. FI 中位数（全样本 + 60+）及 FI max（必须 ≤1）
3. FI-eligible 60+ N
4. 变量对照表路径
5. 意外问题（最多2条）
