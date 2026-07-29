# Task: CHARLS 5 年全因死亡结局构建（Phase 2 第一个可执行任务）

## 前置结论（我已亲自核实，不要重新怀疑，但要在代码里复现验证）

本任务的所有前提我已经跑过一遍，以下数字是实测结果，你的脚本必须复现出同样的数字，作为自检：

### 1. 技术路线已定：不用 Stata，用 Python

本机无 Stata，且不再申请。`bbxleyec.do`（67,559 行）**只作为权威规范文档来读**，不执行。已装好的工具链：

- Python 3.10 + pandas 2.0.3 + pyreadstat
- **lunardate 0.3.0 + sxtwl 2.0.7**（农历转换，已装并测试通过）
- R 4.4.1 + riskRegression / pec / timeROC / dcurves / ranger / xgboost（已全部装好，本任务暂不用）

硬件：i7-13700H（14C/20T），16 GB RAM，D 盘余 298 GB。

**内存铁律**：`H_HRS_d.dta` 有 16,349 个变量、`GH_SHARE_g.dta` 有 8,096 个变量，全量读入会爆内存。凡读大文件必须带 `usecols=`。本任务只读 CHARLS 的小文件，压力不大，但请养成习惯。

### 2. `died` 变量是增量语义（已验证）

`Sample_Infor.dta` 里的 `died` 标记，跨波 ID **零重叠**：

| 波次 | died=1 人数 |
|---|---|
| 2015 | 689 |
| 2018 | 997 |
| 2020 | 785 |

两两交集：15&18 = 0，15&20 = 0，18&20 = 0。

**结论：`died` 表示「自上一波以来新发生的死亡」，可以跨波累加，不会重复计数。** 这一点请在脚本里重新验证并断言（assert），因为它是整个结局构建的基础。

### 3. 跨波 ID 必须重建（这是最大的坑，已解决）

CHARLS 2011 的 ID 是 **11 位**，2013 及以后是 **12 位**，直接 merge 得到 **0% 重叠**。

官方 do 文件第 1919–1920 行给出了转换规则：

```stata
gen householdID = householdID_w1 + "0"
gen ID = householdID + substr(ID_w1,-2,2)
```

即：**新 12 位 ID = 9 位 householdID + "0" + 原 11 位 ID 的末 2 位**

我已用 Python 复现验证：

```python
hh    = df["householdID"].astype(str).str.strip()   # 9 位
id11  = df["ID"].astype(str).str.strip()            # 11 位
id_new = hh + "0" + id11.str[-2:]                   # 12 位
```

实测连通率：

| 目标文件 | 该文件 ID 数 | 与重建 ID 的交集 |
|---|---|---|
| 2015 Sample_Infor | 21,789 | **15,139（占 2011 基线 85.5%）** |
| 2013 Exit_Interview | 431 | **408** |
| 2018 Sample_Infor | 20,813 | 14,395 |
| 2020 Sample_Infor | 20,180 | 13,734 |

2011 基线 N = 17,705。

**注意 2013 Exit 有 431 条但只匹配 408 条，差 23 条。** 请查清这 23 条是什么（可能是 2013 新入样的家属、或 ID 异常），并在报告里说明。不要静默丢弃。

### 4. 农历死亡日期占比很高（已量化）

死亡日期的日历标记变量是 `exb002`（1 = 公历，2 = 农历）：

| 文件 | 公历 | 农历 | 农历占比 |
|---|---|---|---|
| 2013 Exit_Interview | 185 | 241 | **56.6%** |
| 2020 Exit_Module | 588 | 181 | 23.5% |

**超过一半的 2013 死亡日期是农历，必须转换，不能当公历用。**

官方 do 文件第 3298–3310 行的处理逻辑：

```stata
gen dyear_l  = exb001_1 if inrange(exb001_1,2011,2014) & exb002 == 2
gen dmonth_l = exb001_2 if inrange(exb001_2,1,12) & exb002 == 2
gen dday_l   = 15 if ... & exb002 == 2          // 日缺失时固定填 15
gen ddate_l  = mdy(dmonth_l, dday_l, dyear_l)
lunar2solar ddate_l2, matfile($lunar2solar) gen(ddate_s)
gen dyear_s  = year(ddate_s2)
gen dmonth_s = month(ddate_s2)
```

**请用 `lunardate` 严格复刻这个逻辑**，包括「日缺失时填 15」这一条。`lunar2solar.mmat` 是 Stata Mata 二进制文件，我们不需要也读不了。

API 注意：`lunardate` 新版方法名是 `to_solar_date()`，`toSolarDate()` 已废弃会告警。已测通的例子：

```python
from lunardate import LunarDate
LunarDate(2013, 2, 15).to_solar_date()   # -> 2013-03-26
```

闰月：`LunarDate` 的构造签名不接受 `isleap` 关键字。CHARLS 问卷未采集闰月信息，所以**统一按非闰月处理**，并在报告中记录这一处近似及其影响（受影响者仅限死亡月恰为闰月者，量级应很小，请估算出来）。

### 5. 两波 Exit 文件的日期精度不一致（已核实）

| 文件 | 死亡年 | 死亡月 | 死亡日 |
|---|---|---|---|
| 2013 Exit_Interview | `exb001_1` ✅ | `exb001_2` ✅ | ❌ 无 |
| 2020 Exit_Module | `exb001_1` ✅ | `exb001_2` ✅ | `exb001_3` ✅ |

2020 有「日」，2013 没有。**统一到月精度**处理，日一律取 15，不要因为 2020 有日就混用两种精度——那会让随访时间的测量误差在波次间不一致。

另外 2020 Exit_Module 共 770 行，但 `exb001_1` 有 **663 个缺失**，只有约 107 条有死亡年份。请查清这 663 条是什么（可能是非死亡类退出、或死亡日期确实未采集到），并在报告中分类说明。

### 6. Gateway CHARLS D.2 只覆盖到 2018（已核实）

do 文件里 wave 5（2020）的整段代码被 `/* */` 注释掉了（第 1993–2009 行），`local wv=` 的循环只有 1、2、lh、3、4。

**含义**：官方 harmonization 只到 2018，2011 基线 + 2018 = 7 年随访。5 年主结局完全够；**8 年敏感性分析需要我们自己把 2020 波接上**。本任务要把 2020 也纳入，为 8 年分析留出可能，但要把 2020 的数据来源单独标记，因为它不在官方 harmonization 覆盖范围内。

### 7. 2011 基线没有个人访问日期字段（已核实）

`2011/demographic_background.dta` 和 `health_status_and_functioning.dta` 里**都没有** `iyear`/`imonth` 之类的访问日期变量（我搜过，返回空）。而 2015/2018/2020 的 `Sample_Infor.dta` 里**有** `iyear`、`imonth`。

这是个真问题：**没有基线日期，就无法计算随访时间**。请你去找：

- 2011 其他模块文件里是否有访问日期（逐个 `.dta` 扫变量名，找 `iyear`/`imonth`/`interview`/`date` 等）
- `weight.dta`、`psu.dta`、`biomarkers.dta`、`Blood_20140429.dta` 都要查
- 如果确实找不到，回退方案是**统一假定 2011 基线日期为 2011-07-01**（CHARLS 2011 主访问期在 2011 年 6–9 月），并把这个假设作为一条显式限制记录下来，同时做一个「基线日期 ±3 个月」的敏感性检查，看对 5 年事件判定的影响有多大

这一条请**优先解决**，它比其他任何事都更卡关键路径。

---

## 铁律

1. **`D:\AI_project\sql\` 全程只读。** 不修改、不移动、不删除、不重命名任何原始文件。
2. 所有产物写到 `D:\AI_project\project3\`，不要动已有的 `literature\`、`results\literature_extract\`、`results\data_audit\`。
3. 脚本要**幂等**，可重复运行，不依赖手工中间步骤。
4. 随机种子固定 `SEED = 20260726`（本任务大概用不上，但写进配置）。
5. 遇到任何与上述「前置结论」矛盾的实测结果，**停下来报告，不要自行调整方案绕过**。我给的数字是实测的，如果你跑出不同的数，说明有一方理解错了，必须先对齐。

---

## 任务：构建 CHARLS 分析级死亡结局

### 输入文件

| 用途 | 路径 |
|---|---|
| 基线人群 | `Charls/2011/demographic_background.dta` |
| 基线年龄/出生 | 同上（`ba002_1/2/3` 出生年月日、`ba003` 历法、`ba004` 自报年龄） |
| 2013 死亡 | `Charls/2013/Exit_Interview.dta`（`exb001_1`、`exb001_2`、`exb002`） |
| 2013 死因 | `Charls/2013/Verbal_Autopsy.dta`（本任务不用，仅登记存在） |
| 2015 随访状态 | `Charls/2015/Sample_Infor.dta`（`died`、`iyear`、`imonth`） |
| 2018 随访状态 | `Charls/2018/Sample_Infor.dta`（同上） |
| 2020 随访状态 | `Charls/2020/Sample_Infor.dta`（同上） |
| 2020 死亡日期 | `Charls/2020/Exit_Module.dta`（`exb001_1/2/3`、`exb002`） |
| 权威规范（只读不跑） | `Charls/bbxleyec.do` |

### Step 1：ID 桥接与基线定义

1. 读 2011 基线，按官方规则重建 12 位 ID，**同时保留原 11 位 ID** 两列并存（后续回溯要用）。
2. 断言重建后与 2015 的交集 = 15,139、与 2013 Exit 的交集 = 408。数字不符就停下报告。
3. 定义基线人群：2011 全部 17,705 人，先不做年龄筛选（年龄筛选留到建模阶段，这里保留全量以便后续灵活调整）。
4. 计算基线年龄：用 `ba002_*` 出生信息 + 基线日期。注意 `ba003` 标记出生日期是公历还是农历，**农历出生日期也要转换**（这会影响年龄计算）。请报告农历出生的比例。

### Step 2：解决基线日期（关键路径）

按前置结论第 7 条执行。产出一份短报告说明：
- 2011 各模块中是否存在访问日期字段，扫描结果如何
- 最终采用的基线日期方案（实测字段 or 2011-07-01 假定）
- 若用假定值，±3 个月敏感性检查的结果

### Step 3：死亡日期构建（含农历转换）

1. 从 2013 Exit_Interview 和 2020 Exit_Module 提取死亡年月（日统一取 15）。
2. `exb002 == 2` 的记录走 `lunardate` 转公历；`exb002 == 1` 或缺失的按公历直接用。
3. 严格复刻 do 文件第 3298–3310 行的取值范围限制（如 2013 文件限 `inrange(exb001_1, 2011, 2014)`），**并说明 2020 文件应该用什么范围**（我倾向 2011–2020，请你判断并给理由）。
4. 转换前后各输出一份分布对照（年 × 月交叉表），让我能肉眼检查转换有没有把日期推到不合理的区间。
5. 报告农历转换实际影响了多少条记录、其中有多少条因转换而**跨年**或**跨月**。

### Step 4：随访状态整合

对 2011 基线的每个人，判定为以下之一：

| 状态 | 判定依据 |
|---|---|
| `dead` | 任一波 `died==1`，或在 Exit 文件中有死亡记录 |
| `alive_censored` | 有后续波访问记录且从未标记死亡，删失于最后一次已知存活日期 |
| `lost_to_followup` | 既无死亡记录、也无任何后续波访问记录 |

要求：

- 三类必须互斥且穷尽，加断言检查三类人数之和 == 17,705。
- 死亡者优先采用 Exit 文件的具体日期；仅有 `died==1` 而无日期者，用**该波访问期中点**作为死亡日期近似，并单独标记 `death_date_source`（取值如 `exit_file` / `wave_midpoint` / `unknown`）。
- 输出 `death_date_source` 的分布。这个字段后面写论文和做敏感性分析都要用。

### Step 5：随访时间与 5 年事件

1. `time_to_event`（天）= 死亡日期或删失日期 − 基线日期。
2. `event_5y`：基线后 1,826 天内死亡 = 1，否则 0。
3. `time_5y`：min(time_to_event, 1826)，用于生存分析。
4. 同时构建 `event_8y` / `time_8y`（2,922 天），标注其依赖 2020 波、超出官方 harmonization 范围。
5. 断言：无负值随访时间、无 0 天随访（若有，单独列出并说明原因）。

### Step 6：诊断报告

产出 `results/outcome_charls/charls_outcome_report_2026-07-27.md`，必须包含：

1. **样本流程**：17,705 → 各步排除 → 最终分析样本，每步给出人数。
2. **事件数表**：5 年死亡数、8 年死亡数、删失数、失访数，并按性别和年龄段（60-69/70-79/80+）分层。
3. **死亡日期来源分布**：`exit_file` / `wave_midpoint` / `unknown` 各多少。
4. **农历转换影响**：转换记录数、跨年数、跨月数、闰月近似的估计影响。
5. **随访时间分布**：直方图 + 中位数/四分位数 + Kaplan-Meier 曲线（可用 R 或 `lifelines`）。
6. **与文献对标**：CHARLS 5 年粗死亡率与已发表文献比较。这是最重要的质检——若差异超过 2 个百分点，说明结局构建有系统性错误，必须停下来查。请自己检索 CHARLS 死亡率的已发表数值作为对标基准，并注明来源。
7. **所有不确定性与近似的清单**：每一条写明「做了什么近似、影响多少人、对 5 年事件判定的可能影响」。

### Step 7：输出分析级数据集

`data/analysis/charls_outcome_2026-07-27.parquet`，一行一人，列至少包括：

```
id_12          重建的 12 位 ID
id_w1_11       原始 11 位 ID
household_id
baseline_date
baseline_age
female
death_date
death_date_source
death_date_calendar     原始历法标记（1公历/2农历/缺失）
last_known_alive_date
followup_status         dead / alive_censored / lost_to_followup
time_to_event
event_5y   time_5y
event_8y   time_8y
```

用 Parquet 不用 CSV（保留类型、体积小）。

---

## 交付清单

1. `code/03_outcome/charls_outcome.py` — 主脚本，幂等可重跑
2. `code/03_outcome/lunar_convert.py` — 农历转换工具函数（独立成模块，KLoSA/CLHLS 后面会复用）
3. `data/analysis/charls_outcome_2026-07-27.parquet`
4. `results/outcome_charls/charls_outcome_report_2026-07-27.md`
5. `results/outcome_charls/` 下的图表（随访时间分布、KM 曲线、农历转换前后对照）
6. `logs/charls_outcome_2026-07-27.log` — 完整运行日志，含所有断言结果

---

## 回复格式

**不要贴整个报告。** 只回复：

1. 基线日期问题怎么解决的（实测字段 or 假定值），一句话。
2. 一张小表：5 年死亡数 / 8 年死亡数 / 删失数 / 失访数 / 合计（应等于 17,705）。
3. 死亡日期来源分布（三类各多少）。
4. 与文献对标的结果：我们算出的 5 年粗死亡率 vs 文献值，差多少。
5. 前置结论里 7 条断言的验证结果：逐条 PASS / FAIL。
6. 你发现的、我没预料到的问题（最多 3 条，具体写，不要客套）。
7. 产物文件的绝对路径。

控制在 50 行以内。

---

## 优先级

Step 2（基线日期）是关键路径，先解决它。如果基线日期完全无法确定，立刻停下来告诉我，不要用假定值硬推到 Step 7——那样后面全部要重做。

Step 6 的第 6 项（与文献对标）是**质量闸门**。对标不通过，就不要交 Step 7 的数据集，先报告差异原因。
