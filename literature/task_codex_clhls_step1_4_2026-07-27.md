# Task: CLHLS 死亡结局构建 —— Step 1-4（实测阶段）

完整方案见 `D:/AI_project/project3/docs/clhls_outcome_plan_2026-07-27.md`，请先读那份文档的第 1、2、3、5 节再动手。

本次**只做 Step 1-4**。Step 5-7（最终结局构建与输出）待三个待定决策确认后再派，不要提前做。

---

## 为什么只做前四步

Step 5 及之后依赖三个尚未确定的���计决策（敏感性分析时间窗改 7 年还是仅 CHARLS 做 8 年、Aim 1 是否加方法敏感性分析层、失访率 22.2% 如何处理）。而 Step 1-4 全是实测，结论不受那些决策影响，先跑出来正好为决策提供依据。

**Step 4 的产出（区间跨越 1826 天的人数）是决定主分析方法的关键数字，这是本次任务的核心目标。**

---

## 铁律

1. **`D:/AI_project/sql/` 全程只读。** 不修改、不移动、不重命名任何原始文件。
2. **必须用 R `haven::read_sav()` 读取。** pyreadstat 已实测失败：四种编码（gb18030 / gbk / latin1 / utf-8）全部报 `<method 'get' of 'dict' objects> returned a result with an exception set`，`metadataonly=True` 和 `row_limit=5` 两种绕法都不行。R 读取正常返回 9765 × 3046。不要再试 Python 读 `.sav`。
3. R 路径：`D:/LeStoreDownload/R/R-4.4.1/bin/x64/Rscript.exe`（注意在 x64 子目录下，直接用 `bin/Rscript.exe` 会报路径错）。
4. 只读需要的列，用 `col_select=`。3,046 个变量全读没必要。
5. 脚本幂等，可重复运行。
6. **遇到与下面实测数字矛盾的结果，立刻停下报告，不要自行调整方案绕过。** 我给的数字是亲自跑出来的，不一致说明有一方理解错了，必须先对齐。

---

## 输入文件

```
主数据：D:/AI_project/sql/CLHLS/CLHLS_dataset_2008-2018_SPSS/clhls_2011_2018_longitudinal_dataset_released_version1.sav
codebook：D:/AI_project/sql/CLHLS/CLHLS_codebook 1998-2018/codebook_for_2011_2018_longitudinal_dataset.docx
```

选 2011–2018 文件的理由：与 CHARLS 2011 基线年份对齐，消除时期效应（医疗水平、死亡率长期下降趋势）这一混杂。不要改用其他起始年的文件。

---

## Step 1：读取与断言

读取后逐条断言，任一不符即停止并报告。

**总量**
```
N = 9765
变量数 = 3046
```

**`dth11_14`**（label: *status of survival, death, or lost to follow-up from 2011/2012 to 2014 waves*）

| 类别 | 人数 |
|---|---|
| surviving at the 2014 survey | 6066 |
| died before the 2014 survey | 2879 |
| lost to follow-up in the 2014 survey | 820 |
| died or lost to follow-up in previous waves | 0 |
| 合计 | 9765 |

**`dth14_18`**（label: *status of survival, death, or lost to follow-up from 2014 to 2018 waves*）

| 类别 | 人数 |
|---|---|
| surviving at the 2018 survey | 2884 |
| died before the 2018 survey | 1837 |
| lost to follow-up in the 2018 survey | 1345 |
| NA | 3699 |
| 合计 | 9765 |

**基线访问年 `yearin`**
```
2011 = 7328
2012 = 2437
```

注意基线跨两年，后续不能统一假定单一基线日期。

**额外要做的一致性检查（我没跑过，你来做）**

`dth11_14` 与 `dth14_18` 的交叉表。预期逻辑：
- `dth11_14 = died` 或 `lost` 的人，在 `dth14_18` 应为 NA
- `dth11_14 = surviving` 的 6066 人，应完整分布在 `dth14_18` 的三个非 NA 类别中（2884 + 1837 + 1345 = 6066）

**请验证 2884 + 1837 + 1345 是否恰好等于 6066。** 若不等，说明状态变量的逻辑与我的理解不同，立刻停下报告——这会直接改变随访状态的三分类规则。

---

## Step 2：访问期实测

`R`（区间右端点）的取值依赖各波访问期范围，必须实测而非查文献。

```r
# 从实际访问日期推断访问期
d14 <- as.Date(sprintf("%04d-%02d-%02d", yearin_14, monthin_14, dayin_14))
d18 <- as.Date(sprintf("%04d-%02d-%02d", yearin_18, monthin_18, dayin_18))
range(d14, na.rm=TRUE); range(d18, na.rm=TRUE)
```

产出：

1. 2014 波访问日期的 min / max / 中位数
2. 2018 波访问日期的 min / max / 中位数
3. **两波各自的月度直方图**（横轴年-月，纵轴人数）
4. 基线（`yearin`/`monthin`/`dayin`）的月度直方图

关键判断：若某波访问期跨度很长（例如超过 6 个月），区间中点的不确定性会显著增大。请明确报告每波访问期的跨度天数，并说明这对 Step 4 的影响。

日期构造注意：`monthin` / `dayin` 可能有缺失或异常值（如 0、99、98）。请先输出这些变量的取值分布，识别缺失码，再构造日期。不要静默产生 NA。

---

## Step 3：基线构建

**基线日期**
```
baseline_date = make_date(yearin, monthin, dayin)
```
报告缺失情况：有多少人无法构造完整基线日期，缺的是年/月/日哪一部分。

**基线年龄**

用 `trueage`（CLHLS 已核验年龄，高龄人群质量较好）。产出：

1. 年龄分布描述统计（min / P25 / 中位 / P75 / max / 均值 / SD）
2. **分段人数与占比：60-69 / 70-79 / 80-89 / 90-99 / 100+**
3. 年龄直方图
4. 与 CHARLS 60+ 年龄分布的**并列对比图**（CHARLS 数据取自前一个任务的产物 `data/analysis/charls_outcome_2026-07-27.parquet`；若该文件尚不存在，先只出 CLHLS 的图，并在报告中注明待补）

**这一步的意义**：CLHLS 刻意超额抽样 80+ 与百岁老人，年龄结构与 CHARLS 差异极大。这不是数据缺陷，而是 Aim 1 的核心科学看点——一次天然的年龄结构压力测试。量化这个差异是后续「限制到 65-85 岁共同重叠区间」敏感性分析的前提。

**性别变量**：请从 codebook 确认性别变量名（可能是 `a1`），并报告分布。CLHLS 高龄段女性占比通常显著高于男性，请一并报告分性别的年龄分布。

---

## Step 4：区间构造（本次任务的核心）

对每个死亡者构造死亡时间区间 `[L, R]`。

**第一区间死亡**（`dth11_14 == "died before the 2014 survey"`，2879 人）
```
L = baseline_date
R = 2014 波访问期结束日期（用 Step 2 实测的 max）
```

**第二区间死亡**（`dth14_18 == "died before the 2018 survey"`，1837 人）
```
L = 该人 2014 年的实际访问日期
    若缺失 → 用 2014 波访问期开始日期（Step 2 实测的 min）
R = 2018 波访问期结束日期（Step 2 实测的 max）
```

保留为两列 `interval_L`、`interval_R`（日期型），不要在这一步做任何插补。

### 核心产出：区间跨越 1826 天的人数

```
interval_L_days = interval_L - baseline_date   （天）
interval_R_days = interval_R - baseline_date   （天）

interval_crosses_1826 = (interval_L_days < 1826) & (interval_R_days > 1826)
```

**必须报告：**

1. `interval_crosses_1826 == TRUE` 的**人数与占全部死亡者（4716）的百分比**
2. 按第一区间 / 第二区间分别报告（预期第一区间几乎为 0，第二区间为主）
3. 跨越者的区间宽度分布（`interval_R_days - interval_L_days` 的 min/中位/max）
4. 跨越者中，`interval_L_days` 到 1826 的距离分布 —— 这反映"若假设死在区间早期，有多少会被判为 5 年内事件"
5. **敏感性区间**：分别用三种假设计算 5 年死亡数
   - 全部跨越者假设死在区间**左端**（最早）→ 5 年死亡数上界
   - 全部跨越者假设死在区间**中点** → 主分析值
   - 全部跨越者假设死在区间**右端**（最晚）→ 5 年死亡数下界

第 5 项给出的三个数字，就是区间删失带来的不确定性范围。这是本次任务最有价值的输出。

### 判定标准（写进报告的结论）

| 跨越人数 | 结论 |
|---|---|
| < 200 | 区间中点插补的偏倚可忽略，方案 A 可作主分析 |
| 200-800 | 方案 A 可用但必须并列报告方案 B（icenReg），两者结论需一致 |
| > 800 | 方案 A 偏倚过大，需重新考虑 Aim 1 的方法一致性策略，报告后等我决策 |

请明确给出落在哪一档，以及你的判断理由。**不要因为想让方案 A 成立而弱化这个数字。**

---

## 不要做的事

- 不做 Step 5（最终 event_5y / time_5y 构建）
- 不做 Step 6 的完整诊断报告（本次只出 Step 1-4 相关部分）
- 不做 Step 7（parquet 输出）—— 但可以输出一个**中间文件**供后续复用，见下
- 不做 FI / IC 变量构建
- 不做与文献的死亡率对标（那属于 Step 6）

---

## 交付清单

1. `code/01_extract/clhls_extract.R` —— 读取 + 列筛选 + 断言，导出中间 parquet
2. `code/03_outcome/clhls_interval_probe.R` —— Step 2-4 的实测与区间构造
3. `data/interim/clhls_2011_baseline_interim_2026-07-27.parquet` —— 中间文件，含：
   ```
   id, yearin, monthin, dayin, baseline_date,
   trueage, sex（确认变量名后填）,
   dth11_14, dth14_18,
   yearin_14, monthin_14, dayin_14, date_14,
   yearin_18, monthin_18, dayin_18, date_18,
   interval_L, interval_R, interval_L_days, interval_R_days,
   interval_crosses_1826
   ```
4. `results/outcome_clhls/clhls_step1_4_report_2026-07-27.md` —— 本次实测报告
5. `results/outcome_clhls/` 下图表：
   - 三波访问日期月度直方图
   - 基线年龄直方图（分性别）
   - CLHLS vs CHARLS 年龄分布对比图（CHARLS 数据可得时）
   - 区间宽度分布图
6. `logs/clhls_step1_4_2026-07-27.log` —— 完整日志，含所有断言的 PASS/FAIL

---

## 回复格式（40 行以内）

1. Step 1 全部断言逐条 PASS / FAIL（含新增的 2884+1837+1345 == 6066 检查）
2. 2014 / 2018 / 基线三个访问期的实测范围与跨度天数
3. **区间跨越 1826 天：人数、占比、落在哪一档**
4. 三种假设下的 5 年死亡数（左端 / 中点 / 右端）
5. 基线年龄：中位数 + 80+/90+/100+ 占比
6. 性别变量名及分布
7. 无法构造基线日期的人数及原因
8. 你发现的意外问题（最多 3 条，具体写，不要客套）
9. 产物文件绝对路径

**不要贴完整报告正文，详细内容我自己读文件。**

---

## 优先级

Step 4 的"区间跨越 1826 天人数"是最高优先级。如果时间紧张，Step 3 的 CHARLS 对比图可以省略（标注待补），但 Step 4 的五项产出必须齐全。
