# SAP 修订日志（SAP Amendments Log）

**用途**：记录 SAP v1.0 冻结后的所有修订，构成 TRIPOD+AI 要求的审计链。

**规则**：
- 每次修订追加一条记录（不删除历史记录）
- 必须在修订后**立即**记录，不可回溯补写
- 修订原因限于：数据质量新发现、审稿人要求、技术错误纠正
- H1–H6 假设方向冻结后不可修改

---

## 修订记录

---

### A-001 · 新增敏感性分析 SA-3（教育调整）

**修订日期**：2026-07-30
**修订类型**：技术错误纠正 → 新增敏感性分析
**⚠️ 结局盲状态**：**否** —— 本修订发生在结局揭盲之后（主分析自 2026-07-29 起完成，见 D-029 至 D-034）。**SA-3 在论文中必须标注为事后（post hoc）敏感性分析，不得表述为预先注册分析。**

#### 修订内容

新增 **SA-3：教育调整模型**。

| 项目 | 内容 |
|---|---|
| 分析范围 | 仅 Aim 1（CHARLS 开发 → CLHLS 外部验证） |
| 主模型（**不变**） | `event ~ fi_full + age + female + factor(period)` |
| SA-3 模型 | `event ~ fi_full + age + female + factor(period) + edu_isced` |
| 比较指标 | C-index 及 ΔC、O:E、校准截距、校准斜率、Brier、IPA |
| 判读标准 | 若 SA-3 与主模型 ΔC < 0.02 且校准指标变化可忽略，判定主模型结论对教育未调整具稳健性 |

**Aim 2 / Aim 3 不纳入 SA-3**：其规格为 `event ~ fi_full + age`（KLoSA FI parquet 缺已协调的性别变量，见 Methods §6）。在该规格上追加教育会引入与主分析不同的协变量结构，削弱可比性。

#### 修订原因

D-029 记录教育变量「无法可靠关联」，主分析据此未作教育调整。2026-07-30 的只读可得性排查（`results/education_availability_audit.md`）证明该结论不成立：六队列教育变量全部可得，与 FI-eligible 60+ 分析样本 ID join 率均为 **100.0%**，缺失率 **0.00%–0.53%**。

D-029 误判的技术原因：HRS 教育变量不在 FI 构建所用的 RAND Fat File（`h12f3a.dta`）中，而在 Gateway harmonized 文件（`H_HRS_d.dta`）；MHAS 的 ID 字段为 `rahhidnp` 而非 `unhhid`。

#### 教育编码规则（本条目冻结，SA-3 执行中不得调整）

统一尺度为 **ISCED 三分类**：1 = 低于高中；2 = 高中及职业教育；3 = 高等教育。

| 队列 | 源文件 | 字段 | 映射 |
|---|---|---|---|
| HRS | `H_HRS_d.dta` | `raeducl` | 原生 ISCED，直接使用 |
| SHARE | `GH_SHARE_g.dta` | `raeducl` | 原生 ISCED，直接使用 |
| MHAS | `H_MHAS_c2.dta` | `raeducl` | 原生 ISCED，直接使用 |
| CHARLS | `demographic_background.dta` | `bd001`（11 级） | 1–5 → 1；6–7 → 2；8–11 → 3 |
| CLHLS | `clhls_2011_2018_longitudinal...sav` | `f1`（受教育年数） | 0–9 → 1；10–12 → 2；≥13 → 3；88/99 = 缺失 |
| KLoSA | `w04_e.dta` | `w04edu`（4 级） | 1–2 → 1；3 → 2；4 → 3；−9/−8 = 缺失 |

**映射中的判断性决定（须在 Limitations 披露）**：
1. CHARLS「私塾」（`bd001` = 3）为中国传统教育形式，无直接 ISCED 对应，归入类别 1
2. CHARLS「文盲」（= 1）与「未完成小学但能读写」（= 2）在三分类下合并，损失识字能力区分
3. CLHLS 年数分段依赖学制假设；1949 年前受教育的高龄成员学制与后期不同
4. KLoSA「小学及以下」合并未受教育与小学毕业，粒度低于 CHARLS

#### 本修订不变更的内容

主模型规格、H1–H6 假设及方向、已报告的主分析结果、FI 构建规范（41 项，D-020）、结局定义（4 年全因死亡，D-010）。SA-3 为补充证据，不替代任何主分析结论。

#### 关联文档

- 可得性排查报告：`results/education_availability_audit.md`
- 机读汇总：`results/education_availability_audit_2026-07-30.csv`
- 排查脚本：`code/06_audit/audit_education_availability_2026-07-30.R`
- 决策日志：D-036
- 实施脚本：`code/04_model/run_sa3_education_2026-07-30.R`（**待实现**）

---
