# Task: Project3 数据资产整理 + 缺口盘点

## 角色与目标

你负责 HOW（工程实现）。本任务**只做数据资产的清点、归位、体检和缺口报告**，不做任何统计建模，不做变量 harmonization 的实质构建（那是下一个任务）。

目标产物是让我（Claude，负责 WHY/WHAT）能够回答三个问题：

1. 每个队列到底有哪些可用文件，在哪里，多大，什么格式，哪一波。
2. 每个队列的**死亡结局和随访时间**能不能构建，事件数大概多少。
3. 还缺什么，缺的东西是「必须补」还是「可以绕过」。

---

## 铁律（违反即任务失败）

1. **绝对不修改、不移动、不删除、不重命名 `D:\AI_project\sql\` 下的任何文件。** 该目录视为只读原始档。所有操作只能是「读」和「在别处创建」。
2. 新建的整理目录是 `D:\AI_project\project3\data_organized\`。不要动 `D:\AI_project\project3\` 下已有的 `literature\` 和 `results\`。
3. **不要解压任何还未解压的压缩包到原目录。** 如需解压，解压到 `data_organized\_extracted\` 下。已经解压过的（例如 `KLoSA 1-9th wave (STATA)\` 旁边有同名 .zip）不要重复解压。
4. **磁盘空间**：`D:\AI_project\sql\` 约 19 GB。**默认使用硬链接（hardlink）而不是复制**，因为都在 D: 盘同一卷上，硬链接不额外占空间。Python 用 `os.link(src, dst)`。如果 `os.link` 抛异常（跨卷、权限、文件系统不支持），再退回 `shutil.copy2`，并在日志里记录哪些文件是真复制的。
5. 读取大文件时**只读元数据，不要把整个表载入内存**。`H_HRS_d.dta` 是 855 MB，`GH_SHARE_g.dta` 也很大。用 `pyreadstat.read_file_metadata()`（只读 header，秒级返回），需要看数据时用 `row_limit=200` 抽样。
6. 环境：**本机没有 Stata，没有 R，只有 Python 3.10 + pandas 2.0.3 + pyreadstat**。不要产出任何需要 Stata/R 才能跑的方案。如果你认为某步必须 Stata，明确写进缺口报告让我决策，不要自行假设可用。
7. 所有脚本和产物带日期戳，脚本可重复运行（幂等），不要一次性手工操作。

---

## 已知的两个硬阻塞（这是本任务要重点核实和量化的）

我已初步核查，请你验证并补全细节：

### 阻塞 1：CHARLS 和 KLoSA 没有 Gateway 成品 harmonized 数据

Gateway (g2aging.org) 对这两个队列**不发布成品 .dta，只发布 harmonization 程序**：

- `D:\AI_project\sql\Charls\bbxleyec.do` — 实为 `GH_CHARLS_long`，Version D.2，2025 年 9 月，2.9 MB
- `D:\AI_project\sql\KLOSA\bukpmcwp.do` — 实为 `H_KLoSA_long`，Version F，2025 年 6 月，4.5 MB

而 HRS / ELSA / MHAS / SHARE 的成品文件是有的：
`H_HRS_d.dta`、`h_elsa_g3.dta` + `h_elsa_eol_a2.dta`、`H_MHAS_c2.dta` + `H_MHAS_EOL_b.dta`、`GH_SHARE_g.dta` + `GH_SHARE_EOL_g.dta`。

**因为没有 Stata，这两个 .do 无法执行。** 请在缺口报告中确认这一点，并完成下面的「.do 文件挖掘」任务（这是本任务价值最高的部分）。

### 阻塞 2：.do 所需的输入文件有缺失

我初步查到：

- **KLoSA**：`w01_e` 到 `w09_e` 主文件齐全，`w05_new_e` 有，exit 文件 `w02_exit_e`/`w03`/`w04`/`w05`/`w06_Exit_e`/`w07`/`w08`/`Exit09_e` 看起来齐全。但 **`e_imp_w01` 到 `e_imp_w07` 七个 imputation 文件全部缺失**。请核实。
- **CHARLS**：2011/2013/2015/2018 四波齐全（对应 do 里的 w1/w2/w3/w4），2020 波额外有。但 **Life History（2014）整个缺失**（do 里的 `inputlh`，需要 `Demographic_Backgrounds`、`Education_History`、`Family_Information`、`Health_History`、`Residence`、`Sample_Infor`、`Wealth_History`、`Work_History`），且 **lunar-to-solar 日期转换的 Mata 文件缺失**（do 里的 `lunar2solar`）。请核实。

请对每个缺失项判定：**这个缺失是否影响我们要的变量**。判据是：我们要的是 FI 缺陷项、IC 五域、基础协变量、死亡日期/随访时间。收入和财富的 imputation 文件，如果只影响 income/wealth 变量，那么对我们**不构成阻塞**，请明确这样标注。

---

## Phase A：建立整理后的目录结构

在 `D:\AI_project\project3\data_organized\` 下建立：

```
data_organized/
  _manifest/                 <- 所有清单、报告、日志
  _extracted/                <- 需要解压才能读的内容（解压到这里，不动原目录）
  _scripts/                  <- 你写的所有脚本
  CHARLS/
    raw_w1_2011/  raw_w2_2013/  raw_w3_2015/  raw_w4_2018/  raw_w5_2020/
    harmonization_program/    <- bbxleyec.do 的链接 + 你的解析产物
    docs/
  CLHLS/
    raw_longitudinal/  raw_cross_sectional/  docs/
  KLOSA/
    raw_waves/  raw_exit/  harmonization_program/  docs/
  HRS/
    harmonized/  raw_rand/  exit/  docs/
  ELSA/
    harmonized/  raw_waves/  docs/
  SHARE/
    harmonized_gateway/  easyshare/  raw_waves/  docs/
  MHAS/
    harmonized/  docs/
  CHNS/
    cleaned/  raw/  docs/
```

规则：

- **每个队列的目录里，harmonized/成品文件优先级最高**，放在最显眼的一层。
- `docs/` 放所有 PDF 说明书、codebook、问卷。
- 原始波次文件按波次分目录，文件名保持原样（不要改名，改名会破坏与 .do 和文献的对应关系）。
- CHNS 单独说明：它是营养与健康调查，不是 HRS 家族的老龄化队列，**默认不进入主分析**。只需清点归位，不必深挖。在报告里标注「暂不使用，待 Claude 决策」。

---

## Phase B：全量文件清单

产出 `_manifest/file_inventory_2026-07-27.csv`，一行一个文件，覆盖 `D:\AI_project\sql\` 下**所有** .dta/.sav/.sas7bdat/.csv/.do/.pdf/.zip/.rar 文件。列：

| 列名 | 含义 |
|---|---|
| cohort | CHARLS/CLHLS/KLOSA/HRS/ELSA/SHARE/MHAS/CHNS/UNKNOWN |
| wave | 波次或年份，无法判定填 NA |
| role | harmonized / raw_main / raw_exit / raw_module / imputation / program / doc / archive |
| source_path | 原始绝对路径 |
| organized_path | 整理后路径，未纳入则填 NOT_LINKED |
| link_mode | hardlink / copy / not_linked |
| format | dta/sav/sas7bdat/csv/do/pdf/zip/rar |
| size_mb | 大小 |
| n_rows | 仅 .dta/.sav，从元数据读；读不到填 NA |
| n_cols | 同上 |
| encoding_ok | 能否正常读取元数据 true/false |
| read_error | 读取失败时的错误摘要 |
| note | 备注，例如「与同名 zip 重复」「__MACOSX 垃圾文件」 |

注意事项：

- `__MACOSX/` 下的 `._*` 文件是 macOS 元数据垃圾，标注 `note=macos_junk`，`organized_path=NOT_LINKED`。
- 同一份数据存在「已解压目录 + 同名 zip」时，链接已解压的那份，zip 标注 `note=archive_of_extracted`。
- ELSA 存在 `ELSA/stata/stata13_se/` 和 `ELSA/UKDA-5050-stata/stata/stata13_se/` 两处内容高度重复。请比对文件名与大小，判定哪一处是完整版，只链接完整的那一份，另一份标注 `note=duplicate_tree`。
- CLHLS 是 .sav（SPSS），`pyreadstat.read_file_metadata` 对 .sav 同样可用。CLHLS 常见编码问题，读失败时尝试 `encoding='gb18030'` 和 `encoding='latin1'`，把成功的编码记进 note。

---

## Phase C：死亡结局与随访可行性体检（本任务的核心）

这一步决定整个项目能不能做。产出 `_manifest/mortality_feasibility_2026-07-27.md` + 对应的机读 JSON。

对**每个队列**，回答以下问题，每个回答必须附上**文件路径 + 变量名 + 你实际跑出来的数字**。禁止凭经验或凭文档猜测，没跑出来就写 UNVERIFIED。

### C.1 死亡标识与死亡日期

- 哪个文件、哪个变量标识「该受访者已死亡」？
- 哪个文件、哪些变量给出死亡的年 / 月（甚至日）？
- 死亡年月的缺失率是多少（在已知死亡者中）？
- 死亡日期是精确日期，还是只能定位到「两次访问之间」（区间删失）？

各队列的已知线索（请验证，不要照抄）：

- **HRS**：`H_HRS_d.dta` 里找 `radyear`、`radmonth`、`radage_y`、以及 `rNiwstat` 系列（访问状态）。
- **ELSA**：`h_elsa_g3.dta` + `h_elsa_eol_a2.dta`。
- **MHAS**：`H_MHAS_c2.dta` + `H_MHAS_EOL_b.dta`。
- **SHARE**：`GH_SHARE_g.dta` + `GH_SHARE_EOL_g.dta`；另外 `easySHARE_rel9-0-0.dta` 里有 `deceased` 之类的字段，请一并核查并说明两者差异。
- **CHARLS**：`2013/Exit_Interview.dta`、`2013/Verbal_Autopsy.dta`、`2020/Exit_Module.dta`，以及每一波的 `Sample_Infor.dta`（2015/2018/2020 有）里的随访状态字段。**2015 和 2018 没有独立的 Exit 文件，这是重点核查对象**：请找出 2015/2018 期间的死亡是怎么记录的。
- **CLHLS**：`clhls_2008_2018_longitudinal_dataset_released_version1.sav` 等纵向文件里通常有 `dth**` 系列（死亡年月）和存活状态变量。请把变量名和取值分布列出来。
- **KLoSA**：exit 文件 `w02_exit_e` … `Exit09_e` 各自的行数就是各波新增死亡数的上界。请给出每个 exit 文件的行数，以及里面的死亡日期变量。

### C.2 基线波次与事件数估算

对每个队列，按我计划书里的设定（**基线 60 岁及以上，主结局 5 年全因死亡**），估算：

- 候选基线波次是哪一年，该波 60+ 的人数是多少。
- 从该基线起 5 年内的死亡事件数大概是多少（能精确算就精确算，只能粗估就说明是粗估）。
- 该队列的随访是否足够覆盖 5 年（最后一波距基线多少年）。

这一步只要量级正确即可，目的是判断「事件数够不够支撑外部验证」。我的门槛是**外部验证队列至少 100 个死亡事件**，请对每个队列给出「达标 / 不达标 / 无法判定」的结论。

### C.3 关键变量可得性抽查

不要做完整的 harmonization，只抽查以下 12 个「代表性变量」在每个队列是否存在、变量名叫什么、缺失率多少。这 12 个是我用来判断 FI 和 IC 能不能构建的探针：

年龄、性别、教育、自评健康、ADL 穿衣、ADL 洗澡、IADL 做饭、行走困难、认知词语回忆、抑郁量表（CESD 或等价）、握力、身高体重（BMI）。

产出一个 12 × 8（变量 × 队列）的可得性矩阵，值域为：`有(变量名)` / `无` / `疑似有待确认`。

---

## Phase D：.do 文件挖掘（高价值任务）

两个 Gateway .do 文件虽然没法执行，但它们是**官方权威的变量映射规范**，价值极高。请把它们当作文档来解析，产出：

1. `_manifest/gateway_charls_varmap_2026-07-27.csv`
2. `_manifest/gateway_klosa_varmap_2026-07-27.csv`

对我们关心的变量（上面 C.3 那 12 个探针，加上 ADL/IADL 全套、五域 IC 相关项、死亡日期），从 .do 里抽出：

| 列名 | 含义 |
|---|---|
| harmonized_var | Gateway 的标准变量名，例如 `r1adla`、`radyear`、`r1shlt` |
| wave | 适用波次 |
| raw_vars | 该变量由哪些原始变量构造（例如 CHARLS 的 `db001`、`da002` 等） |
| recode_logic | 从 .do 里摘出的关键 recode / replace / gen 语句原文 |
| missing_codes | 该变量用到的缺失码（例如 .m、.d、.r、-8、999 等） |
| source_line | 在 .do 文件里的行号，方便我回查 |

方法建议：用 Python 正则扫 `gen `、`replace `、`recode `、`label var ` 等语句，按目标变量名聚类。不要试图完整翻译整个 .do（它有几万行），**只做我们关心的那部分变量**，覆盖不全没关系，但抽出来的必须准确并带行号。

**这个产物的意义**：它让我们后续可以用 Python 复刻 Gateway 的官方定义，而不是自己拍脑袋定义 FI 缺陷项。这是绕过「没有 Stata」的正解。

---

## Phase E：缺口报告（给我看的最终结论）

产出 `_manifest/GAP_REPORT_2026-07-27.md`。这是我最关心的文件。结构：

### 1. 一句话结论

项目当前能不能按「CHARLS 开发 → CLHLS/KLoSA/SHARE/HRS/ELSA/MHAS 外部验证」的设计推进：能 / 有条件能 / 不能。

### 2. 缺口清单表

| 缺什么 | 属于哪个队列 | 阻塞级别 | 影响什么 | 建议处置 |
|---|---|---|---|---|

阻塞级别定义：

- **P0 致命**：不解决则项目无法推进。
- **P1 重要**：不解决则某个 Aim 或某个队列要放弃。
- **P2 可绕过**：有替代方案，或只影响非核心变量。

### 3. 对两个硬阻塞的明确建议

- 没有 Stata 这件事：是建议装 Stata、还是建议用 Python 复刻、还是建议只用 4 个成品 harmonized 队列？给出你的推荐和理由。
- CHARLS Life History 和 KLoSA imputation 文件缺失：是必须去补下载，还是对我们的变量无影响？

### 4. 你在整理过程中发现但我没问到的问题

任何数据质量异常都写进来：文件损坏、行数异常、编码乱码、波次缺失、ID 无法跨波连接、疑似重复下载、版本不一致（例如 SHARE rel9 与 Gateway G 版对不上）等。**这一节请写得具体，不要客套。**

---

## 交付清单

放在 `D:\AI_project\project3\data_organized\_manifest\`：

1. `file_inventory_2026-07-27.csv`
2. `mortality_feasibility_2026-07-27.md` + `.json`
3. `variable_availability_matrix_2026-07-27.csv`（Phase C.3 的 12×8 矩阵）
4. `gateway_charls_varmap_2026-07-27.csv`
5. `gateway_klosa_varmap_2026-07-27.csv`
6. `GAP_REPORT_2026-07-27.md`
7. `organize_log_2026-07-27.txt`（所有链接/复制操作的日志，含失败项）

脚本放 `_scripts/`，命名清晰，可重复运行。

---

## 回复给我的格式

任务完成后，**不要把整个报告贴给我**。只回复：

1. 一句话结论（Phase E.1）。
2. P0 和 P1 缺口的清单（只要表格，不要展开论述）。
3. 每个队列的「基线 60+ 人数 / 5 年死亡事件数 / 是否达到 100 事件门槛」三列小表。
4. 你认为我必须马上决策的问题，最多 3 条。
5. 产物文件的绝对路径列表。

控制在 60 行以内。详细内容我自己去读文件。

---

## 时间与顺序建议

Phase B（清单）最快，先做完让我有个全局视图。然后 Phase C（死亡体检）最关键。Phase D（.do 挖掘）最耗时但价值最高，可以放最后。如果 Phase D 时间不够，先交 B/C/E，Phase D 单独再来一轮，但要在回复里说明。
