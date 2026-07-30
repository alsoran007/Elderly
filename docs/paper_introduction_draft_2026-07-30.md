# 1. 引言（Introduction）— 论文草稿

**文件说明**：本文件为 Introduction 节初稿，约 900–1000 字中文，与 Methods / Results / Discussion 风格一致。后续翻译为英文投稿版本。

---

## 1. 引言

全球人口老龄化已成为 21 世纪最重要的公共卫生挑战之一。据联合国估计，全球 60 岁及以上人口将从 2020 年的约 10 亿增加至 2030 年的近 14 亿，增幅逾 40%，且其中绝大多数增长将发生在中低收入国家 [CITATION: UN World Population Ageing 2019]。老年人群的健康状态存在极大个体间异质性：在同一日历年龄层内，部分人群几乎未受任何功能限制，另一部分则承受多系统疾病负担，死亡风险差异可达数倍乃至数十倍。准确识别高风险老年人，是指导临床决策、优化医疗资源分配和设计精准预防干预的前提。

衰弱（frailty）是刻画老年人健康异质性的核心概念。在众多衰弱评估工具中，衰弱指数（Frailty Index，FI）——由 Rockwood 和 Mitnitski 提出的缺陷累积模型 [CITATION: Mitnitski 2001, Rockwood 2005]——因其客观量化、项目灵活且不依赖单一物理测量的特性而在纵向老龄化研究中得到广泛应用。FI 通过将 40 项以上涵盖共病、功能、感官和认知等多个系统的健康缺陷加和除以总项目数，生成 0 至 1 之间的连续衰弱指标。Searle 等（2008）制定了构建标准化 FI 的程序规范 [CITATION]，此后多项单队列研究在欧洲、北美和亚洲人群中证实，FI 是四年至八年全因死亡率的强独立预测因子，且增量预测价值超越传统人口学协变量 [CITATION]。

然而，现有 FI 死亡预测模型的开发和验证大多局限于单一高收入国家队列，跨文化可迁移性缺乏系统评估。这一研究缺口的科学和实践意义不容忽视。一方面，中国、墨西哥等中低收入国家正经历最快速的人口老龄化，若 FI 模型无法从英美高收入队列中可靠迁移，则需要重复耗费资源独立开发本地模型。另一方面，跨文化迁移面临三类结构性障碍：（1）**测量不等价**——不同队列以不同量表、截点和语言情境操作化同一 FI 缺陷定义；（2）**事件率差异**——CHARLS（中国农村，四年死亡率 10.2%）、CLHLS（中国高龄，46.3%）和 SHARE（欧洲，8.7%）之间存在数倍乃至数十倍的基准死亡率差距；（3）**人群构成漂移**——不同文化情境下年龄分布、共病模式和功能缺陷分布均存在差异。既往多队列老龄化研究通常仅报告单一 C-index，未系统区分判别力损失与校准失败的相对贡献，也未建立可操作的重校准策略框架，难以指导实践应用。

本研究旨在填补上述缺口。我们以中国纵向健康与养老追踪调查（CHARLS）2011 年基线队列（n = 7,551，60 岁及以上）为开发集，构建 41 项 FI 四年全因死亡预测模型，并在五个外部队列（CLHLS、KLoSA、HRS、SHARE 和 MHAS）中系统开展外部验证。研究采用分层重校准阶梯（L0–L3）框架，将性能损失分解为可归因成分——事件率漂移（L1）、斜率漂移（L2）和完全重校准（L3）——以量化不同干预层次的收益。六项假设（H1–H6）在任何结局-预测因子分析前均预先注册于统计分析计划（SAP），研究全程遵循预测模型报告规范 TRIPOD+AI [CITATION] 和 PROBAST-AI 偏倚风险评估框架 [CITATION]。本研究的主要目的是：评估 FI 判别力和校准性能的跨文化可迁移性，量化性能损失的可归因来源，并确定最低程度的重校准干预是否足以在新人群中恢复模型实用价值。

---

## 1. Introduction (English)

Population ageing is among the defining public health challenges of the twenty-first century. The global population aged 60 years and older is projected to rise from approximately 1.0 billion in 2020 to nearly 1.4 billion by 2030, an increase of more than 40%, with the large majority of this growth occurring in low- and middle-income countries.[REF-1] Health status within older populations is markedly heterogeneous: within a single chronological age stratum, some individuals remain essentially free of functional limitation while others carry substantial multisystem disease burden, with mortality risks differing several-fold or more. Identifying older adults at elevated risk is therefore a prerequisite for informing clinical decisions, allocating health care resources, and designing targeted preventive interventions.

Frailty is the central construct used to characterise this heterogeneity. Among available frailty instruments, the Frailty Index (FI) — the deficit-accumulation model introduced by Mitnitski and Rockwood[REF-2,REF-3] — has been widely adopted in longitudinal ageing research because it is objectively quantified, flexible in item composition, and does not depend on any single physical performance measurement. The FI is computed as the sum of health deficits spanning comorbidity, function, sensory capacity and cognition, divided by the number of non-missing items, yielding a continuous index bounded between 0 and 1. Searle and colleagues established a standard procedure for constructing an FI,[REF-4] and subsequent single-cohort studies in European, North American and Asian populations have shown the FI to be a strong independent predictor of four- to eight-year all-cause mortality, with incremental predictive value beyond conventional demographic covariates.[REF-5,REF-6,REF-7]

Existing FI mortality models have, however, been developed and validated predominantly within single high-income cohorts, and their cross-cultural transferability has not been systematically evaluated. This gap carries both scientific and practical weight. Countries such as China and Mexico are experiencing the most rapid population ageing, and if FI models cannot be reliably transported from high-income cohorts, locally developed models must be built at duplicated cost. At the same time, cross-cultural transfer faces three structural obstacles: (i) **measurement non-equivalence**, whereby the same nominal FI deficit is operationalised through different instruments, cut-points and linguistic contexts across cohorts; (ii) **event-rate divergence**, with four-year mortality ranging from 8.7% in SHARE (Europe) and 10.2% in CHARLS (rural China) to 46.3% in CLHLS (Chinese oldest-old); and (iii) **case-mix drift** in age distribution, comorbidity patterns and functional deficit prevalence across cultural settings. Prior multi-cohort ageing studies have typically reported a single C-index without separating the relative contributions of discrimination loss and calibration failure, and without establishing an actionable recalibration framework to guide deployment.

We addressed this gap by developing a 41-item FI model for four-year all-cause mortality in the China Health and Retirement Longitudinal Study (CHARLS) 2011 baseline cohort (n = 7,551 aged ≥60 years) and externally validating it in five cohorts: CLHLS, KLoSA, HRS, SHARE and MHAS. We applied a hierarchical recalibration ladder (L0–L3) to decompose performance loss into attributable components — event-rate drift (L1), slope drift (L2) and full refitting (L3) — thereby quantifying the yield of each level of intervention. Six hypotheses (H1–H6) were pre-registered in a statistical analysis plan before any outcome–predictor analyses were undertaken, and the study was conducted in accordance with the TRIPOD+AI reporting guideline[REF-8] and the PROBAST-AI risk-of-bias framework.[REF-9] Our objectives were to evaluate the cross-cultural transferability of FI discrimination and calibration, to quantify the attributable sources of performance loss, and to determine whether a minimal recalibration intervention is sufficient to restore practical model utility in new populations.

---

*中文初稿日期：2026-07-30 | 英文版日期：2026-07-30*
*字数：中文 ~950 字；英文 ~570 words*
*引用编号对照见 `docs/references_placeholder_2026-07-30.md`*
