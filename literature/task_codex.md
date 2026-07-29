# Project3 — HOW 实施任务清单(致 Codex)

## 研究定案(已由 PI 拍板,勿改设计,只负责实现)
- 主结局:**全因死亡 (all-cause mortality)**。
- 预测因子:**老龄表型作为自变量** —— Frailty Index(40+ deficits)、WHO Intrinsic Capacity 五域;协变量:年龄、性别、教育、SES。
- 表型不作结局。目的:分离"表型测量是否跨国一致"与"表型预测客观结局是否一致"。
- 队列与流程:CHARLS(开发)→ CLHLS(华人/极高龄)→ KLoSA(±JSTAR 仅敏感性分析)→ SHARE(欧)→ HRS(美)。
- 数据底座:优先 **Gateway to Global Aging Data 的 Harmonized 数据集**(CHARLS/CLHLS/KLoSA/SHARE/HRS 均有)。原始库在 D:/AI_project/sql/。

## 你的交付物(按顺序)

### 0. 数据工程与可复现管线
- 建立统一 ETL:从各 Harmonized 数据集抽取,输出统一 schema 的分析表(每队列一张 + 合并主表)。
- 定义 baseline wave(可算 FI/IC 的首个 wave)、随访终点、死亡日期/删失。
- 缺失机制描述 + 多重插补 (MICE) 方案,插补在各队列内部独立进行。
- 输出:数据字典、每队列 flowchart(纳入/排除人数)、变量可得性矩阵(哪些队列缺哪些 deficit/IC 项)。

### 模块A — 表型测量等价性(建模前地基,最高优先级)
- 构建 FI 的 40+ deficit 逐项编码表;IC 五域(运动/活力/认知/心理/感觉)指标映射表。
- 实现 **多组验证性因子分析 (multi-group CFA)**:依次检验 configural / metric / scalar 三级不变性,报 ΔCFI、ΔRMSEA。
- 实现 **IRT 差异项目功能 (DIF)** 逐项检验,标出各国不等价条目。
- 输出:"哪些老龄指标可跨国比较 / 哪些不可"的等价性地图(表 + 图)。

### 模块B — 迁移性基准(判别 + 校准)
- CHARLS 开发模型;逐级外部验证 + 全队列 **Leave-One-Cohort-Out (LOCO)**。
- 模型:先 Cox / 生存(报 C-index),再固定时间窗(如 5 或 8 年)二分类用于 ML(XGBoost/LightGBM)。
- **必须同时报判别与校准**:AUC/C-index + calibration slope & intercept + calibration plot + DCA。校准是本研究区别于现有文献的硬指标,不可省。

### 模块C — 掉点来源分解(方法学核心)
- 将每次外部验证的性能下降正式拆解为:
  1) 协变量漂移 covariate shift(密度比 / importance weighting);
  2) 结局患病率漂移 outcome prevalence shift;
  3) 条件关系漂移 P(Y|X) shift;
  4) 测量漂移(接模块A结果)。
- 输出:每个 source-target 对的掉点归因分解表/图。

### 模块D — 可解释性迁移
- 各队列计算 SHAP,比较重要性**排序稳定性**(Spearman/Kendall)与方向一致性。
- 区分"全球锚点"(预期:年龄、躯体功能)与"文化易变因子"(预期:抑郁、教育、城乡)。

### 模块E(次选)— 稳定核心模型 vs 全模型
- 用"等价 + 全球稳定"因子建简约模型,对比全变量模型的迁移性。
- 修复只用**轻量重校准(截距重校准 / Platt scaling)**,不用 DANN/UDA。论证可解释、可落地。

## 约束
- 全程可复现:固定随机种子、环境锁定 (requirements/lockfile)、脚本化。
- 每模块产出中间结果供 PI 与 Claude 审阅,勿一次性跑完全部。
- 先回一条:数据可得性确认(Harmonized 各库是否在本地/可获取)+ 模块A 的落地技术方案与预计工作量。
