# Abstract（摘要）— 论文草稿

**文件说明**：结构化摘要，英文版（投稿用）+ 中文对应版本。基于 SAP v1.0 冻结结果，H1–H6 判定与 decision_log 一致。目标字数：英文 ≤350 words，中文 ≤500 字。

---

## 英文版（English）

**Title（暂定）**
Cross-cultural transferability of a frailty index for four-year mortality prediction: development and external validation in six longitudinal ageing cohorts

---

**Background**

The Frailty Index (FI) reliably predicts mortality within single cohorts, but whether its discrimination and calibration transfer across diverse cultural and health-system contexts—and which aspects of performance are recoverable through recalibration—remain poorly characterised.

**Methods**

We developed a pooled logistic regression model predicting four-year all-cause mortality (predictors: FI, age, sex) in CHARLS 2011 (China; n = 7,551 aged ≥60; 771 events) and validated it externally in five cohorts: CLHLS (China), KLoSA (South Korea), HRS (United States), SHARE (27 European countries), and MHAS (Mexico). The FI comprised 41 harmonised deficits across seven domains, derived from Gateway-harmonised data. A hierarchical recalibration ladder (L0–L3) decomposed performance loss into event-rate drift (L1), slope drift (L2), and full recalibration (L3). Six hypotheses were pre-registered in a statistical analysis plan before any outcome-predictor analyses were conducted.

**Results**

Adding FI to demographic predictors increased C-index by 0.035 (from 0.736 to 0.771; H1 supported). Across all external cohorts, C-indices ranged from 0.72 to 0.84 and changed by ≤0.003 after full recalibration, while L0 O:E ratios ranged from 0.60 to 1.25, indicating systematic calibration drift (H2 supported). Level-1 intercept recalibration (event-rate adjustment only) explained 95% (SHARE) and 89% (HRS) of the recoverable improvement in the Integrated Prediction Accuracy (IPA) index (H4 supported). Expanding the training set from one to two Asian cohorts produced no meaningful increase in C-index (|ΔC| ≤ 0.001; H3 not supported). In a supplementary analysis, FI showed smaller cross-cohort |ΔC| than the WHO intrinsic capacity five-domain framework (0.052 vs. 0.095; H5 supported, with caveats). Age ranked first in feature importance in all six cohorts; however, deficit-level importance concordance was moderate (median Spearman ρ = 0.41; H6 partially supported).

**Conclusions**

FI discrimination transfers across diverse cultural contexts without retraining. Calibration requires local adjustment, achievable through a simple intercept update using the target-population event rate. Training-set diversity does not improve cross-cohort transferability; local recalibration is the more efficient optimisation strategy for deploying FI mortality models in new populations.

**Keywords**: frailty index; mortality prediction; external validation; cross-cultural transferability; recalibration; ageing cohorts

---

## 中文版

**标题（暂定）**
衰弱指数四年死亡预测的跨文化可迁移性：六个纵向老龄化队列的模型开发与外部验证

---

**背景**

衰弱指数（Frailty Index，FI）能可靠预测单一队列内的死亡风险，但其判别力和校准性能能否跨文化和医疗体系迁移、以及哪些性能损失可通过重校准恢复，目前尚缺乏系统评估。

**方法**

在中国 CHARLS 2011 年基线队列（60 岁及以上，n = 7,551；771 例死亡事件）中，以混合逻辑回归（预测因子：FI、年龄、性别）开发四年全因死亡预测模型，并在五个外部队列中进行外部验证：CLHLS（中国）、KLoSA（韩国）、HRS（美国）、SHARE（欧洲 27 国）和 MHAS（墨西哥）。FI 涵盖跨 7 个域的 41 个协调化缺陷项目，来源于 Gateway 协调化数据。采用 L0–L3 分层重校准阶梯将性能损失分解为事件率漂移（L1）、斜率漂移（L2）和完全重校准（L3）三个层次。六项假设均在任何结局-预测因子分析之前预先注册于统计分析计划（SAP）。

**结果**

在人口学协变量基础上加入 FI 使 C-index 提升 0.035（0.736→0.771；H1 成立）。各外部队列 C-index 范围为 0.72–0.84，完全重校准后变化 ≤ 0.003，而 L0 时 O:E 比值范围为 0.60–1.25，提示系统性校准漂移（H2 成立）。仅 L1 截距更新（事件率调整）即解释了 SHARE 和 HRS 可改善预测准确性（IPA 指数）空间的 95% 和 89%（H4 成立）。将训练集从单一亚洲队列扩展至两个队列未带来有意义的 C-index 提升（|ΔC| ≤ 0.001；H3 不成立）。补充分析显示 FI 的跨队列 |ΔC| 小于 WHO 内在能力（IC）五域框架（0.052 vs. 0.095；H5 成立，附注意事项）。年龄在全部 6 个队列中均位居特征重要性第一，但缺陷条目重要性排序一致性中等（中位 Spearman ρ = 0.41；H6 部分成立）。

**结论**

FI 判别力无需重新训练即可跨文化迁移。校准需要局部调整，仅通过基于目标人群事件率的截距更新即可实现。训练集多样性不能改善跨队列迁移性，局部重校准是向新人群部署 FI 死亡预测模型更高效的优化策略。

**关键词**：衰弱指数；死亡率预测；外部验证；跨文化可迁移性；重校准；老龄化队列

---

*草稿日期：2026-07-30 | 英文版字数：~310 words | 中文版字数：~430 字*
