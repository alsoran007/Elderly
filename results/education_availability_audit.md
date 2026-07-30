# 教育变量可得性排查报告（2026-07-30）

**排查性质**：只读数据可得性排查。未修改 SAP、FI 构建、任何模型或现有 Results。
**排查脚本**：`code/06_audit/audit_education_availability_2026-07-30.R`
**机读结果**：`results/education_availability_audit_2026-07-30.csv`

---

## 摘要

**六个队列的教育变量全部可得且可可靠关联，D-029 记录的「教育变量无法可靠关联」结论不成立。** 六队列与现有 FI-eligible 60+ 分析样本的 ID join 率均为 **100.0%**，教育缺失率介于 **0.00%–0.53%**，全部远低于 10% 的直接纳入门槛。

关键限制不在可得性，而在**跨队列编码可比性**：HRS、SHARE、MHAS 三队列具备 Gateway 统一的 `raeducl`（ISCED 三分类），可直接跨队列比较；CHARLS（11 级原始学历）、CLHLS（受教育年数）、KLoSA（4 级韩国学制）三队列需要人工映射到 ISCED 三分类才能与前者对齐。

**建议**：教育可以纳入，但须以 ISCED 三分类为共同尺度重新编码。鉴于 SAP 已冻结且主分析已完成，建议将教育调整作为**预先声明的敏感性分析**加入，而非替换主模型（详见「对 Paper 1 的建议」）。

---

## 逐队列结果

### CHARLS（开发队列）

| 项目 | 内容 |
|---|---|
| 源文件 | `sql/CHARLS/2011/demographic_background.dta` |
| 字段名（原始） | `bd001` |
| 字段名（Gateway harmonized） | 本地无 harmonized CHARLS 文件；仅有原始调查项 |
| 60+ FI-eligible 分母 | 7,551 |
| 非缺失 | 7,539 |
| **缺失率** | **0.16%** |
| **join 率** | **100.0%** |
| 编码 | 11 级序数：1=未受正式教育（文盲）、2=未完成小学但能读写、3=私塾、4=小学、5=初中、6=高中、7=中专、8=大专、9=本科、10=硕士、11=博士（实测最高值 10） |
| **结论** | **推荐** |

备注：ID join 使用 `ID` 字段直接匹配，未涉及 D-009 的跨波桥接规则（教育取自 2011 基线波，与 FI 同波，无需跨波匹配）。这是 join 率达 100% 的原因。

### CLHLS

| 项目 | 内容 |
|---|---|
| 源文件 | `sql/CLHLS/CLHLS_dataset_2008-2018_SPSS/clhls_2011_2018_longitudinal_dataset_released_version1.sav` |
| 字段名 | `f1`（"years of schooling"） |
| 60+ FI-eligible 分母 | 9,207 |
| 非缺失 | 9,170 |
| **缺失率** | **0.40%** |
| **join 率** | **100.0%** |
| 编码 | 连续型受教育年数，有效范围 0–25；**88 与 99 为缺失码**（已在排查中剔除） |
| **结论** | **推荐** |

备注：受教育年数与其余队列的分类变量不同尺度，需转换。建议映射：0 年 → ISCED 1；1–9 年 → ISCED 1；10–12 年 → ISCED 2；≥13 年 → ISCED 3。

### KLoSA

| 项目 | 内容 |
|---|---|
| 源文件 | `sql/KLOSA/KLoSA 1-9th wave (STATA)/w04_e.dta` |
| 字段名 | `w04edu`（"In the 4th interview, the highest level of education"） |
| 60+ FI-eligible 分母 | 5,289 |
| 非缺失 | 5,289 |
| **缺失率** | **0.00%** |
| **join 率** | **100.0%** |
| 编码 | 4 级：1=小学及以下、2=初中、3=高中、4=大学及以上；−9=不知道、−8=拒答（实测无此类值） |
| **结论** | **推荐** |

备注：排查过程中曾误命中 `w04Ba001`（子女数）——原因是初版字段搜索模式 `ba00` 过宽。已收紧模式并改用 `w04edu`。此教训记录在脚本注释中。

### HRS

| 项目 | 内容 |
|---|---|
| 源文件 | `sql/HRS Products/harmonised HRS/H_HRS_d.dta` |
| 字段名（Gateway harmonized） | `raeducl` |
| 60+ FI-eligible 分母 | 10,707 |
| 非缺失 | 10,704 |
| **缺失率** | **0.03%** |
| **join 率** | **100.0%**（`hhidpn`） |
| 编码 | Gateway ISCED 三分类：1=less than upper secondary、2=upper secondary and vocational training、3=tertiary |
| **结论** | **推荐** |

**重要实施注意**：FI 构建使用的是 RAND Fat File（`h12f3a.dta`），该文件**不含**教育变量。教育须从 harmonized 文件 `H_HRS_d.dta` 二次 join 获得。这很可能是 D-029 得出「无法可靠关联」结论的原因——当时只在 Fat File 中查找。

### SHARE

| 项目 | 内容 |
|---|---|
| 源文件 | `sql/share harmonised/GH_SHARE_g.dta` |
| 字段名（Gateway harmonized） | `raeducl`（另有 `raedyrs` 年数版本） |
| 60+ FI-eligible 分母 | 36,361 |
| 非缺失 | 36,361 |
| **缺失率** | **0.00%** |
| **join 率** | **100.0%**（`mergeid`） |
| 编码 | Gateway ISCED 三分类，同 HRS |
| **结论** | **推荐** |

### MHAS

| 项目 | 内容 |
|---|---|
| 源文件 | `sql/MHAS/H_MHAS_c2.dta` |
| 字段名（Gateway harmonized） | `raeducl`（另有 `raedyrs`、`raedisced`） |
| 60+ FI-eligible 分母 | 9,094 |
| 非缺失 | 9,046 |
| **缺失率** | **0.53%** |
| **join 率** | **100.0%**（`rahhidnp`） |
| 编码 | Gateway ISCED 三分类，同 HRS/SHARE |
| **结论** | **推荐** |

备注：ID 字段为 `rahhidnp`（非 `unhhid`）。FI parquet 中的对应列同名，直接匹配。

---

## 跨队列可比性评估

| 队列 | 变量类型 | 原生尺度 | 是否 Gateway 统一 |
|---|---|---|---|
| CHARLS | 序数 11 级 | 中国学制（含私塾） | ❌ 原始调查项 |
| CLHLS | 连续 | 受教育年数 | ❌ 原始调查项 |
| KLoSA | 序数 4 级 | 韩国学制 | ❌ 原始调查项 |
| HRS | 序数 3 级 | **ISCED** | ✅ `raeducl` |
| SHARE | 序数 3 级 | **ISCED** | ✅ `raeducl` |
| MHAS | 序数 3 级 | **ISCED** | ✅ `raeducl` |

**三队列直接可比（HRS / SHARE / MHAS）**，三队列需映射（CHARLS / CLHLS / KLoSA）。

建议的统一映射方案（映射到 ISCED 三分类）：

| ISCED 类别 | CHARLS `bd001` | CLHLS `f1`（年） | KLoSA `w04edu` |
|---|---|---|---|
| 1 = 低于高中 | 1–5（含私塾、小学、初中） | 0–9 | 1–2 |
| 2 = 高中及职业教育 | 6–7（高中、中专） | 10–12 | 3 |
| 3 = 高等教育 | 8–11（大专及以上） | ≥13 | 4 |

**映射的固有局限**（须在 Limitations 说明）：
1. CHARLS 的「私塾」（`bd001`=3）是中国传统教育形式，无直接 ISCED 对应，归入类别 1 是判断性决定
2. CHARLS 的「未完成小学但能读写」（=2）与「文盲」（=1）在 ISCED 三分类下合并，损失了识字能力这一区分
3. CLHLS 的年数→类别转换依赖各时期学制假设，1949 年前受教育的高龄队列成员学制与后期不同
4. KLoSA 的「小学及以下」合并了未受教育与小学毕业，粒度低于 CHARLS

---

## 对 Paper 1 的建议

**总体判断：教育可以纳入，但建议作为敏感性分析而非替换主模型。**

理由：

1. **可得性无障碍** — 六队列 join 率 100%，缺失率最高 0.53%，完全满足纳入条件
2. **但 SAP 已冻结** — SAP v1.0（commit 9bc7b85）冻结的主模型规格为 `event ~ fi_full + age + female`（Aim 1）与 `event ~ fi_full + age`（Aim 2/3）。分析已在结局非盲状态下完成（D-029 起）。此时更换主模型规格，会使「预先注册」的声明失去意义，且 H1–H6 的判定基础发生变动
3. **映射引入新的判断性决定** — 三队列的 ISCED 映射（尤其私塾归类、CLHLS 年数分段）是在已知结局关联的情况下做出的，属事后决定，须明确标注

**建议方案（按优先级）**：

**方案 A（推荐）**：新增预先声明的敏感性分析 SA-3「教育调整模型」，规格 `event ~ fi_full + age + female + edu_isced`，在 Aim 1（CHARLS→CLHLS）执行，报告 ΔC 与校准指标相对主模型的变化。SAP 通过 `docs/SAP_amendments.md` 追加记录修订（注明修订日期晚于结局揭盲，属事后敏感性分析）。Limitations 中「教育未调整」改为「主模型未调整教育；敏感性分析 SA-3 显示…」。

**方案 B**：仅更新 Limitations 表述。将当前「教育变量无法可靠获取」改为「教育变量可获取，但为维持预注册模型规格的完整性，未纳入主模型；ISCED 映射的可比性限制见补充材料」。工作量最小，但放弃了一个可回应审稿人的实证结果。

**方案 C（不推荐）**：重跑全部分析并将教育纳入主模型。这会推翻预注册声明，且需重做 Aim 1/2/3 全流程与全部图表。

无论选哪个方案，**D-029 的错误结论都应通过新增决策日志条目纠正**（append-only 规则下不删除原条目）。

---

## 排查脚本

```bash
cd D:/AI_project/project3
"D:/LeStoreDownload/R/R-4.4.1/bin/x64/Rscript.exe" --vanilla --no-restore --no-save \
  code/06_audit/audit_education_availability_2026-07-30.R
```

输出：
- `results/education_availability_audit_2026-07-30.csv`（机读汇总）
- 本报告

排查中修正的两处技术问题（已写入脚本注释）：
1. 字段搜索模式过宽，误命中 KLoSA `w04Ba001`（子女数）与 CHARLS `ba00*`（出生地），已收紧
2. HRS 教育不在 FI 所用的 RAND Fat File 中，须从 `H_HRS_d.dta` 二次 join；MHAS ID 列为 `rahhidnp` 而非 `unhhid`

---

*排查完成日期：2026-07-30*
*未修改：SAP、decision_log、FI 构建脚本、任何 parquet、任何现有 Results*
