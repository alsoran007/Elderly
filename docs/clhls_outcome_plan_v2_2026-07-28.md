# CLHLS 死亡结局构建方案 v2.0

| 项目 | 内容 |
|---|---|
| 版本 | **v2.0 — 完全取代 v1.0** |
| 日期 | 2026-07-28 |
| 主要变更 | v1 的核心前提「CLHLS 无死亡日期」已被推翻；改用精确日期 + 离散时间对齐 |
| 关联文档 | `docs/charls_outcome_plan_v2_2026-07-27.md`、`docs/seven_cohort_timeframe_2026-07-27.md` |

---

## 为什么 v1 完全失效

v1 的核心前提是：

> *CLHLS 没有死亡日期变量，只有区间存活状态，属于区间删失数据，需要 `icenReg`。*

这个前提是错的。

我之后搜索了 CLHLS 全部变量名，发现：

```
d14vyear  validated year of death of the sampled person
d14vmonth validated month of death of the sampled person
d14vday   validated year of death of the sampled person   ← label 写错，实为日
d18vyear  validated year of death (2018 波)
d18vmonth validated month of death (2018 波)
d18vday   validated day of death (2018 波)
```

实测覆盖率：

| 来源 | 死亡者 | 年份有效 | 月份有效 | 年月均有效 |
|---|---|---|---|---|
| `d14vyear/month` | 2,879 | 97.7% | 100.0% | **97.7%** |
| `d18vyear/month` | 1,837 | 100.0% | 100.0% | **100.0%** |
| **合计** | **4,716** | **98.6%** | — | — |

变量标签里的 "validated" 说明 CLHLS 官方做过死亡日期核验。

**因此**：

- 区间删失问题不存在
- `icenReg` 不需要
- 原 v1 的 Step 4（区间构造）、Step 5（双方案）、第 7.2 节（方法敏感性）全部作废
- 结合 D-010 决策（主结局改 4 年），CLHLS 的构建反而比 CHARLS 更简单

---

## CLHLS 与 CHARLS 的对比（更新后）

| 维度 | CHARLS | CLHLS |
|---|---|---|
| 死亡日期 | 2015+ 无精确日期（波次级） | **validated 年月日，98.6%** |
| 时间精度 | 波次近似（离散时间）→ 必选 | **可用精确日期** |
| 4 年结局实现 | 期 1+2 波次近似 | **直接用日期切 ≤1461 天** |
| 基线日期 | 缺月份，假定 07-01 | **精确到日** |
| ID 跨波 | 需重建（11→12 位） | 单文件内 id 一致 ✅ |
| 读取工具 | Python pyreadstat ✅ | 仅 R haven（pyreadstat 失败） |
| 年龄结构 | 45+，60+ 中位约 67 | 65+，中位 86，80+ 占 66.9% |
| 失访率 | 9.0%（60+） | 22.2% |
| 官方 harmonization | 有 `.do` 可参照 | **完全无** |
| 最大随访 | 约 9 年（→2020） | 约 7 年（→2018） |

**这个不对称值得在论文中说明**：验证队列（CLHLS）的死亡日期质量反而优于开发队列（CHARLS）。对外部验证而言，这是好事——意味着 CLHLS 上的性能评估比 CHARLS 内部评估更精确。

---

## 4 年主结局的实现

### 精确日期方案（CLHLS 独有优势）

```r
# 死亡日期
d <- d %>% mutate(
  dy = coalesce(valid(d14vyear,2011,2015), valid(d18vyear,2014,2019)),
  dm = coalesce(valid(d14vmonth,1,12),    valid(d18vmonth,1,12)),
  dd = coalesce(valid(d14vday,1,31),      valid(d18vday,1,31)),
  death_date = as.Date(sprintf("%04d-%02d-%02d",
                 dy, dm, ifelse(is.na(dd),15,pmin(dd,28)))),
  days = as.numeric(death_date - baseline_date)
)

# 4 年事件（≤1461 天，比 1826 天更精确对应 CHARLS 期1+2 的实际跨度）
event_4y = as.integer(died==1 & days <= 1461 & days >= 0)
```

**为什么用 1461 天而非 1826 天**：

CHARLS 的"4 年"是期 1+2（2011→2015），实际跨度约 1,461 天（4 年 = 365×4 + 1 闰日）。CLHLS 有精确日期，可以直接切 1461 天，与 CHARLS 精确对齐，而不用像 CHARLS 那样用波次近似。

对应的主结局表述：

> *The primary outcome was all-cause mortality within 1,461 days (approximately 4 years) of the baseline interview.*

对 CHARLS 的补充说明：

> *For CHARLS, this window was approximated by two discrete follow-up intervals (baseline to wave 2, wave 2 to wave 3); for CLHLS, exact death dates allowed a precise calendar cut-off.*

### 实测事件数（已由我先跑确认）

```
总死亡数（有效日期）：4,605 / 4,716（98.1%）
4 年内死亡（≤1461 天）：3,502
全样本 60+ 均为 CLHLS（仅 16 人 <60，占 0.2%）
```

**45 例负随访天数**（死亡日期早于基线）已发现，分布如下：

```
min=-306 天；这些记录的 followup_status 保留 dead，
但 event_4y / time_4y 设为 NA，不进入时间分析，
在样本流程图中单独报告。
```

---

## 人群与基线定义

### 基线

```
文件：clhls_2011_2018_longitudinal_dataset_released_version1.sav
N = 9,765（跨 2011=7,328 和 2012=2,437 两年）
读取：R haven::read_sav()  ← 仅此工具，pyreadstat 完全失败
```

### 基线日期

```r
baseline_date = make_date(yearin, monthin, pmin(pmax(dayin,1),28))
```

CLHLS 精确到日，这是相对 CHARLS（只有年月，用 07-01 近似）的优势。

### 年龄与 60+ 筛选

`trueage`（CLHLS 经核验年龄）：

```
中位数：86    P25：76    P75：94    max：114
80+：66.9%    90+：39.8%    100+：14.9%
60+ 以下：仅 16 人（0.2%）
```

主分析限 `trueage >= 60`，实际与"全样本"几乎等同。CLHLS 的年龄结构远高于 CHARLS，这是 Aim 1 的核心科学看点——年龄结构差异本身是「迁移距离」的一个维度。

### 随访状态

| 状态 | 判定 | 人数 |
|---|---|---|
| `dead` | `dth11_14==1` 或 `dth14_18==1` | 4,716 |
| `alive_censored` | `dth14_18==0`（2018 仍存活） | 2,884 |
| `lost` | `dth11_14==-9` 或 `dth14_18==-9` | 2,165 |
| 合计 | | **9,765** ✅ |

失访率 22.2% > 计划书设的 20% 理想值。**需在 Limitations 讨论，并做失访敏感性分析**（假设失访者全部在失访时点死亡，看 4 年事件数变化多少）。

---

## 待 Codex 完成的任务

v1 的 Step 4（区间构造）和 Step 5（双方案结局）已完全替换为精确日期方案。

**Step 1：读取与断言**（全部继承自 CLHLS Step 1-4 的已完成结果）

已由先前任务（request_id=5bd8d266）完成：
- N=9765 ✅、dth11_14/dth14_18 分布 ✅、yearin 分布 ✅、交叉核验 2884+1837+1345=6066 ✅

中间产物：`data/interim/clhls_2011_baseline_interim_2026-07-27.parquet` 已存在，包含：
`id, yearin, monthin, dayin, baseline_date, trueage, a1, dth11_14, dth14_18, d14vyear, d14vmonth, d14vday, d18vyear, d18vmonth, d18vday, interval_L, interval_R, interval_L_days, interval_R_days, interval_crosses_1826`

**Step 2：构建 4 年精确日期结局**

基于中间产物，构建：

```
event_4y  = 1 if died=1 & days∈[0,1461]；else 0
time_4y   = min(days, 1461) if days≥0；else NA
followup_status = dead / alive_censored / lost
prebaseline_death = (days < 0)   # 45 例，设 event_4y=NA
```

断言：
- `event_4y == 1` 的人数 = **3,502**（已由我实测确认）
- `event_4y == 1` 在 60+ 子样本中的人数 = 3,502（CLHLS 60+ 几乎等于全样本）
- `prebaseline_death` = **45**

**Step 3：诊断报告**

`results/outcome_clhls/clhls_outcome_v2_report_2026-07-28.md`，必须含：

1. 与 v1 的差异说明（三句话：发现 validated 日期、区间删失作废、改精确日期）
2. 样本流程：9,765 → 排除 prebaseline 45 例 → 最终分析 N
3. 4 年事件数按年龄段（60-79 / 80-89 / 90-99 / 100+）和性别分层
4. 死亡日期来源分布（d14/d18 各多少、missing 多少）
5. 失访率与失访者基线特征（用于判断失访是否随机）
6. CLHLS vs CHARLS 年龄分布对比图（已有 `baseline_age_by_sex.png`，复用）
7. **与文献对标**：CLHLS 60+ 的 4 年粗死亡率（3502/9749≈35.9%）与已发表 CLHLS 死亡率比较
8. 45 例负随访天数明细（pid、baseline_date、death_date、delta_days）

**Step 4：输出**

```
data/analysis/clhls_outcome_2026-07-28.parquet
```

列：`id, baseline_date, baseline_age, female, dth11_14, dth14_18, death_year, death_month, death_day, death_date, days, followup_status, prebaseline_death, event_4y, time_4y`

---

## 对整体设计的影响

| 原 v1 的担忧 | v2 的解答 |
|---|---|
| 区间删失 → 需 icenReg | ✅ **不需要**，有精确日期 |
| 8 年分析不可行 | 仍然：约 7 年（→2018），与 D-010 一致 |
| 失访率 22.2% | 仍然需要失访敏感性分析，但精确日期减少了不确定性 |
| 方法不一致（CHARLS Cox vs CLHLS icenReg） | ✅ **已解决**，两队列用同一离散时间框架 |
| CLHLS 精度低于 CHARLS | ✅ **颠倒**：CLHLS 精度反而更高 |

---

*v2.0 基于 2026-07-27/28 实测（d14vyear/d18vyear 覆盖率 97.7%/100%）撰写。*
*v1.0 的全部内容已作废，保留原文件仅供审计参考。*
