# Project3 多队列老龄化预测研究

## 1. 本轮文献证据范围

本轮仅依据 `D:\AI_project\project3\literature\pdf\` 中的本地 PDF 进行提取，不把无法下载或无法在本地全文中准确匹配的 DOI 当作已核实证据。

- 本地 PDF 总数：82 份。
- 进入核心证据矩阵：26 篇。
- 其中包括 CHARLS/CLHLS 外部验证、多队列死亡预测、FI/IC 纵向研究、跨文化测量和 ML 方法学参考。
- 用户提供但本地尚未获得全文的 12 个 DOI/来源已单独列入“待补齐 DOI”工作表。
- `core_paper_pages_2026-07-26.json` 是 PDF 页面级提取原始证据；Excel 是面向研究决策的结构化矩阵。

因此，本报告中的数字和方法描述分为两类：一是来自本地全文或摘要中明确报告的结果；二是根据全文方法和图表识别出的可借鉴做法。未能从 PDF 稳定核实的内容已标注为需要回看原文。

## 2. 核心文献逐篇摘要

### C01 Yao et al.：CHARLS 开发、CLHLS 外部验证的 MCI 模型

**背景、目的和意义。** 抑郁患者的轻度认知障碍风险较高，但现有模型通常缺乏跨中国队列验证。该研究直接对应“CHARLS 开发、CLHLS 外部验证”的中国内部稳定性问题，目标是识别 MCI 风险并解释关键变量。

**方法。** 研究在 CHARLS 2018 中按 7:3 划分训练集和内部测试集，比较 8 种机器学习算法，并使用 5 折交叉验证和 LASSO 进行变量筛选。最优模型使用 RF；评价包括 ROC/AUC、平衡准确率、召回率和特异度，使用 DeLong 比较 AUC，并用 DCA 评价净获益。SHAP 被用于全局重要性、依赖关系和个体解释。CLHLS 作为独立外部验证集，而不是重新选择变量的训练集。

**结果和图表。** RF 内部训练 AUC 约 0.826，内部验证 AUC 约 0.801，5 折平均 AUC 约 0.791；外部区分度为中等。教育、孤独、户籍、IADL 障碍和血脂异常较重要。图表包括研究流程、LASSO 路径、各模型 ROC/AUC、DeLong 比较、DCA、RF 重要性和 SHAP summary/dependence/个体图。

**对 Project3 的启示。** 可借鉴开发集冻结、外部队列独立验证和解释链；必须补充时间窗、校准曲线、校准截距/斜率和外部 DCA。该研究是横断面 MCI 判别，不能直接作为全人群死亡模型。

### C02 He et al.：CHARLS 到 CLHLS-HF 的衰弱外部验证

**背景、目的和意义。** 衰弱预测研究常缺乏可解释性和真正的独立队列验证。该研究以 CHARLS 开发、CLHLS-HF 外部验证为主要设计，是 Aim 1 最直接的蓝本，并进一步检验预测衰弱与跌倒、住院和失能的关系。

**方法。** 研究纳入年龄不低于 60 岁者，在 CHARLS 中开发，以 4 年后的 Fried Frailty Phenotype 为结局，在 CLHLS-HF 中独立外部验证。比较 6 个机器学习算法，以 ROC/AUC 和 F1 为主要评价，并用 SHAP 展示全局重要性、非线性依赖和个体瀑布图。之后将模型预测的衰弱状态与后续跌倒、住院和失能进行比较。

**结果和图表。** XGBoost 最优，内部 AUC 0.934，外部 AUC 0.792；F1 分别约为 0.712 和 0.702。预测为衰弱者后续跌倒 OR 约 2.11、住院 OR 约 1.75、失能 OR 约 1.42。图表包括样本流程、特征重要性、双队列 ROC、SHAP summary、dependence 和个体瀑布图。

**对 Project3 的启示。** 冻结 CHARLS 的特征、预处理和算法后再进入 CLHLS；外部性能下降本身是重要结果，必须同时分析校准和协变量漂移。

### C03 Yang & Zhang：多队列心脏病死亡 ML

**背景、目的和意义。** 既有死亡工具跨文化验证和解释不足。该研究采用 SHARE 开发、HRS 与 CHARLS 外部验证，研究结构与 Aim 3 相近。

**方法。** 先从三个队列提取共同变量，用 Boruta 在开发数据中筛选 27 个特征；SHARE 按 70:30 划分训练和内部测试，比较 11 个机器学习模型，再对 HRS 和 CHARLS 做外部验证。报告 AUC、敏感度、特异度和校准，并用 SHAP 排名、依赖图解释非线性和跨队列差异。

**结果和图表。** XGBoost 平均 AUC 约 0.798，SHARE 内部约 0.799，HRS 外部约 0.821，CHARLS 外部约 0.770。年龄、性别、体力活动和自评健康在多个队列较稳定，但排序存在差异。图表包括三队列流程、Boruta 分布、ROC/AUC 热图、SHAP top-10、dependence 和校准图。

**对 Project3 的启示。** 共同变量应在建模前锁定；特征选择只在训练集完成；使用 source-target 性能热图和跨队列 SHAP 排名比较。该研究仅限心脏病患者，不能直接证明全人群全球可推广。

### C04 Yang et al.：SHARE/CHARLS 老年哮喘死亡生存模型

**背景、目的和意义。** 老年哮喘患者死亡风险因素和跨队列生存预测证据不足。研究提供了较完整的生存 ML 评价框架。

**方法。** 按队列比较 5 种生存 ML，利用 permutation importance 和 C-index 变化筛选风险因子；分别报告训练、测试和外部验证 C-index。进一步报告 integrated Brier score、time-dependent AUC、校准曲线、DCA 和 SHAP，并将最优模型制成列线图/在线工具。

**结果和图表。** 关键因子包括年龄、FI、男性、PEF%pred、BMI 和 CVD；SHARE 有 311 个死亡，CHARLS 有 183 个死亡。图表包括样本选择、模型性能比较、外部 SHAP、10 年列线图和在线工具。

**对 Project3 的启示。** 5 年死亡主分析应同时报告 C-index、time-dependent AUC、Brier、校准和 DCA，而不能仅报告 AUC。专病样本和两队列设计不能支撑全球推广结论。

### C05 Tang et al.：四队列 IC 与 incident CVD

研究在 CHARLS、HRS、MHAS 和 SHARE 中构建 locomotion、cognition、vitality、sensory、psychology 五域 IC，并将 IC 变化分为 robust、decline、improve 和 stable impaired，随后各队列使用统一 Cox 框架分析 incident CVD。结果提示多域受损和持续受损均增加 CVD 风险，稳定受损 HR 约为 1.53-1.65。该研究是跨队列关联证据，不是 ML 外部验证；适合支持 IC 作为并行模块，并为动态 IC 分析提供分组方法。

### C06 Zhang et al.：五队列 IC 与髋部骨折

研究使用 CHARLS、HRS、MHAS、SHARE 和 ELSA，按 ICOPE 五域构建 IC，排除基线髋部骨折、关键缺失和失访者，各队列先独立 Cox，再使用 common-effects meta-analysis 合并。较高 IC 与较低髋部骨折风险相关，合并 HR 约 0.76，I2 约 10.7%。可借鉴“队列内模型 + 效应合并”的可解释关联分析，但髋部骨折测量的跨队列可比性需要核查。

### C07 Suemoto et al.：五队列十年死亡传统预测模型

研究合并 ELSA、HRS、MHAS、SABE-Sao Paulo 和 SHARE，共约 35,367 人、16 国，使用个体数据 meta-analysis，纳入年龄、性别、共病、功能和认知等基线变量，按性别分层 Cox，并用 C-statistic 和观测-预测回归评估判别和校准。该研究不是 ML，但为 Project3 提供 Cox 传统基线和跨队列校准报告模板。随机混合队列切分不能替代按队列留出的外部验证。

### C08 Stolz et al.：四个纵向研究的 FI 变化与死亡

研究协调 HRS、SHARE、ELSA 和 LASA 的 FI，约 24,961 人、95,897 次观测，最多 9 次 FI 测量；在生存模型中同时比较当前 FI 水平和 time-varying FI。结果支持 FI 当前水平预测死亡，重复测量和变化可改善长期风险刻画。Project3 主模型宜使用基线 FI，time-varying FI 作为动态扩展，不能把预测时点之后的信息带回基线模型。

### C09 Bai et al.：三项纵向研究的 FI 轨迹

研究对重复测量 Rockwood FI 按死亡年龄分层，在广义生存模型中同时纳入当前 FI 和个体变化率，并将效应缩放为 FI 增加 0.1。当前 FI 的死亡 HR 约 1.68；调整当前 FI 后，变化率不再显著。由此支持把当前基线 FI 作为主要可迁移预测模块，轨迹分析作为机制或敏感性分析。

### C10 Li et al.：重复 FI 与德国队列死亡

ESTHER 队列纳入约 9,912 名 50-75 岁人群，构建 30 缺陷 FI，在基线、2、5、8、11 年重复测量，并把 FI 作为 time-varying covariate 放入 Cox 模型，与只使用基线 FI 的模型比较。14 年全因死亡、癌症死亡和 CVD 死亡均被分析；time-varying FI 与全因死亡的关联明显。可作为动态 FI 次级分析的依据，但必须严格保证时间顺序。

### C11 Sanchez-Sanchez et al.：IC 系统综述与 meta-analysis

研究检索 MEDLINE、Scopus 和 Web of Science 至 2024-02-14，双人提取，使用 Newcastle-Ottawa 评价质量，并进行三层 meta-analysis；将 beta/OR 转换为 Pearson r，死亡结局提取 HR，使用 I2 区分异质性。37 个纵向研究、约 206,693 人的证据显示 IC 与 BADL、IADL 和死亡相关，死亡 HR 约 0.57。PRISMA 和 BADL/IADL/死亡森林图可借鉴，但综合效应不是任何一个原始队列的模型性能。

### C12 Gonzalez-Bautista et al.：10/66 队列 IC 潜在状态

研究使用 10/66 多国队列约 14,923 人、两波数据，以五域 IC 损伤指标进行 latent transition analysis，识别潜在状态和状态转移，再评价其与衰弱、失能、痴呆和死亡的并发及预测效度。得到 4 种 IC 状态，约 61% 发生恶化，高损伤状态死亡 HR 约 4.60，Harrell C 约 0.73。它直接提示在跨国 pooled ML 前进行 CFA、IRT-DIF 或潜在类别敏感性分析。

### C13 Lee et al.：IC 与功能能力的十年死亡预测

研究在 I-Lan Longitudinal Aging Study 中，将五个 IC 域重标化到 0-100 后取均值，用 29 项 SMAF 衡量功能能力，并使用 Cox、Kaplan-Meier、重复 IC、logistic 和 inverse probability weighting 分析。每提高 1 分 IC，死亡 HR 约 0.95；低 IC HR 约 1.94；完全调整后功能能力的独立效应减弱。该研究支持优先使用 IC，而不是包含环境依赖性的 FA，作为跨文化表型候选。

### C14 Campbell et al.：ELSA 中 IC 的操作化

研究在 ELSA 中构建 IC，分别分析基线 IC 与后续失能、住院和死亡的关系，并按五域展开回归/生存模型。其价值主要在于提供“IC 总分 + 五域分别报告”的变量映射和森林图模板；单一英国队列尚未解决跨文化量表等价性。

### C15 Stolz et al.：动态 IC 与负面健康结局

该研究在单一长期老年队列中使用约 754 人、4,751 次重复观测，将 IC 标准化到 0-100，进行 21 年随访和 time-varying IC 分析，并给出个体 ADL-free survival 概率。动态 IC 可预测 ADL、住院和死亡。个体轨迹图适合放入补充材料，不宜作为跨国主性能证据。

### C16 Olender et al.：老年 ML 预测的系统综述与 meta-analysis

研究按 PRISMA 汇总老年临床 ML 预测研究，死亡研究按短期和较长期窗口分层，对 AUC 进行随机效应 meta-analysis，并使用森林图和漏斗图。死亡预测合并 AUC 约 0.80-0.81。该研究的核心启示是：Project3 的创新应体现在严格外部验证、校准、DCA、测量可比性和跨文化迁移，而不是单纯比较算法 AUC。

### C17 Lai et al.：多来源 FI 简化工具

研究使用 NHANES、CHARLS、CHNS 和 SYSU3 CKD 等数据，先用 5 种特征选择方法取交集，把 75 个变量缩减到 8 个临床可获得变量，再比较 12 个 ML，并在多队列、多结局中报告 ROC、DCA、SHAP 和网页工具。可借鉴“稳定核心变量模型 vs 全变量模型”的对照，但要区分 FI 诊断/评估和未来结局预测。

### C18 Wang et al.：CHARLS 到 ELSA/HRS 的 CKD 外部验证

研究采用 CHARLS 开发、ELSA 和 HRS 外部验证，构建工程化 FI、TyG、AISI 等特征，比较多算法，使用 XGBoost、SHAP 和 DCA。训练 AUC 约 0.892，ELSA 约 0.867，HRS 约 0.871。该研究提供了中国到两个西方队列的工作流，但专病和复合指标可能降低跨队列定义稳定性。

### C19 Zhu et al.：CHARLS 到 ELSA 的慢性肺病 CVD 外部验证

研究在 CHARLS 纳入 2,639 名慢性肺病患者，以单变量和多变量 logistic 筛选核心变量，比较 7 种 ML，使用 ELSA 1,303 人进行外部验证，并报告 ROC、PR、校准、DCA、分层 AUC、SHAP 和网页工具。XGBoost AUC 为训练 0.838、测试 0.797、外部 0.695。外部性能下降说明必须将漂移分解为事件率、变量分布和测量差异，而不能只报告一个 AUC。

### C20 Susnjak & Griffin：可解释生存 ML

研究在 40 家养老机构、约 11,944 人中比较 Cox、ridge、lasso、gradient boosting 和 random survival forest，纳入 18 个特征，报告动态 AUROC、C-index、ROC 和校准，并用 SHAP、交互 dependence、个案生存曲线和瀑布图解释。该研究适合借鉴生存版患者级解释，但机构样本与全人群老龄队列不同。

### C21 Klopack & Crimmins：HRS 系统特异衰老与死亡

研究将 HRS 生物标志物按 12 个生物系统分组，用 XGBoost 建立系统特异和多系统死亡风险分数，比较变量重要性，并分析社会人口学关联。其主要方法学启示是按域组织特征和 SHAP，报告“域别重要性热图”而不是只给一个混合排名；但生物标志物模块可能降低多队列覆盖率。

### C22 Delpino et al.：ELSI-Brazil 单国死亡 ML

研究在 ELSI-Brazil 纳入约 9,412 人和 59 个基线预测因子，比较 9 个算法，评价 AUC、准确率、精确率、F1 和 SHAP。RF AUC 约 0.92，年龄、性别、BMI、用药和体力活动重要。该研究可作为单国基线和变量域参考，但未提供充分外部验证和完整校准，不能替代跨文化证据。

### C23 Zhang et al.：SHARE、ELSA、KLoSA 功能失能研究

研究纳入约 33,766 名功能独立者，构建疼痛、睡眠和抑郁症状簇，在三个队列分别使用 Cox、Kaplan-Meier、meta-analysis、中介分析和 Sankey 图。三症状组失能 HR 约 2.36，并展示持续、进展和部分逆转轨迹。Project3 可把“队列内估计 + 合并/异质性展示”作为失能次要结局的可解释对照，但该研究不是 ML。

### C24 Yuan et al.：17 国认知衰弱与死亡

研究在 6 个老龄队列、17 国中按认知损伤和衰弱组合成四组，每队列使用 competing-risks regression，再用 meta-analysis 合并 subhazard ratio，并进行亚组和交互边际效应分析。认知衰弱 pooled SHR 约 2.34。该方法支持对认知和衰弱模块做队列内关联与敏感性分析，而不是把不同量表直接拼接后解释为同一构念。

### C25 Lee et al.：Gateway to Global Aging Data

研究使用 Gateway harmonized files 比较 20 国失能和共病，强调统一测量、年龄标准化和跨国描述。没有预测模型，但直接支持 Project3 在所有 Aim 前建立逐变量 Harmonization Table，包括原始题目、编码、波次、允许值、缺失码、FI deficit/IC 域和队列可得性。

### C26 Wang et al.：23 国中年失能比较

研究使用 Gateway harmonized data 比较 23 国 55-65 岁 ADL/IADL 失能比例、性别差异和时间趋势。它适合用于确认年龄层、功能结局和国家差异的描述框架，但属于横断面比较，不是预测研究，也不能替代随访时间和删失核验。

## 3. 暴露因子和结局的推荐

### 推荐主问题

建议把论文主问题定为：

> 基于多国纵向老龄化队列的基线衰弱累积指数和共同协变量，能否预测 5 年全因死亡，并在中国内部、亚洲队列以及欧洲/美国队列中保持判别、校准和临床效用？

这里的“暴露因子”更准确地称为预测因子模块；如果写成病因学暴露，容易把预测关联误写成因果效应。

### 主预测模块：FI 40+ deficits

建议优先使用 40 项以上的 deficit accumulation FI，原因是：

1. FI 在多篇纵向研究中与死亡风险保持稳定关联，并可在不同队列中按缺陷比例构建。
2. FI 是连续分数，保留信息多于简单 frail/non-frail 二分类。
3. FI 可作为传统 Cox、固定时间 pooled logistic、RF、XGBoost 和 LightGBM 的共同输入。
4. FI 可在跨文化研究中拆成域别分数，用于解释漂移和 SHAP 稳定性。

需要预先冻结：缺陷清单、分母规则、缺失处理、允许缺陷数量、截断规则、年龄限制和基线波次。不同队列不能仅因变量名相似就直接合并。

### 并行模块：IC 五域

建议把 locomotion、cognition、vitality、sensory、psychology 五域 IC 作为并行模块，而不是一开始与 FI 合成一个总暴露。原因是 IC 的跨文化测量等价性和域定义差异更明显。

建议至少比较四个预先定义的模型：

- Model A：共同人口学、生活方式和共病变量。
- Model B：Model A + FI。
- Model C：Model A + IC 五域/IC 总分。
- Model D：Model A + FI + IC。

只有在 Harmonization Table 和 CFA/IRT-DIF 或域别可比性审查通过后，才将 IC 总分作为主模型变量；否则将 IC 限定为增量预测、敏感性或解释模块。

### 主结局：5 年全因死亡

推荐 5 年全因死亡作为主结局，8 年死亡作为预先规定的敏感性分析。理由是：死亡定义相对客观，多数老龄队列存在死亡随访，且可以同时使用 Cox 生存模型和固定时间窗分类模型。固定 5 年窗口还便于在同一时间点比较不同算法和不同目标队列的校准。

建议的次要结局是：

- incident ADL/IADL disability：用于临床功能意义和跨文化功能迁移。
- 4 年或相近窗口的 frailty：用于与 C02 研究对照，不建议替代死亡主结局。
- 8 年全因死亡：用于检验时间窗变化后的稳定性。

不建议把 CVD、髋部骨折、MCI 或专病结局作为第一篇主结局，因为它们的跨队列定义、事件核实和可得性更不稳定；可以在后续文章或敏感性分析中使用。

## 4. 三阶段设计的可执行修订

### Aim 1：中国内部稳定性

- 开发：CHARLS。
- 外部验证：CLHLS。
- 主问题：中国不同调查框架、年龄结构和变量测量下，冻结模型是否保持性能。
- 必须冻结：变量字典、FI/IC 构建、插补流程、标准化、特征选择、模型超参数和风险阈值。
- CLHLS 只做外部评估；若校准不佳，二次分析才进行 intercept-only 或 logistic recalibration。

### Aim 2：亚洲多样性是否提高迁移

不能把 KLoSA 和 JSTAR 同时用于模型更新和最终测试。建议预先规定双向 leave-one-cohort-out：

- CHARLS + CLHLS + KLoSA 开发/更新，JSTAR 测试。
- CHARLS + CLHLS + JSTAR 开发/更新，KLoSA 测试。

同时比较“仅中国模型”和“加入一个亚洲队列后的更新模型”，报告加入亚洲数据前后的性能变化。这样才能回答“亚洲多样性是否提高迁移”，而不是只回答“亚洲合并模型在亚洲内部表现如何”。

### Aim 3：亚洲到欧洲/美国

- 亚洲开发集：CHARLS + CLHLS + KLoSA + JSTAR。
- 独立目标队列：SHARE 和 HRS 分别验证。
- 主结论只能表述为“对欧洲和美国队列的外部验证”。单凭 SHARE 和 HRS 不足以宣称全球可推广；如需全球主张，应增加 MHAS、ELSA 或其他低中收入国家队列。

## 5. 每个 source-target 对的评价指标

### 判别

- 生存模型：Harrell C-index、time-dependent AUC。
- 5 年固定时间模型：AUC，并报告 bootstrap 95% CI。
- 不把 AUC 单独作为迁移成功标准。

### 校准

- calibration-in-the-large。
- calibration slope。
- 校准曲线及按风险分组的观察/预测风险。
- Brier score 或 integrated Brier score。

### 临床效用和迁移原因

- DCA，在预先规定阈值范围内报告净获益。
- 开发队列与目标队列的事件率、均值/分位数、缺失率、SMD 或 PSI。
- SHAP 特征排名的 Spearman 一致性和方向稳定性。
- 必要时报告目标队列的截距重校准与 logistic recalibration，但与原始冻结模型并列。

## 6. 建议的图表包

### 主文图

1. **Figure 1：研究设计和队列时间线。** 展示 CHARLS、CLHLS、KLoSA、JSTAR、SHARE、HRS 的波次、基线、随访和 source-target 关系。
2. **Figure 2：样本流程和变量可得性。** 各队列排除、事件数、失访和 FI/IC 可得性。
3. **Figure 3：开发与外部验证性能。** source-target 性能热图，配合 time-dependent AUC、C-index、Brier 和校准分面。
4. **Figure 4：校准与临床效用。** 校准曲线、校准斜率/截距和 DCA。
5. **Figure 5：解释稳定性。** FI、IC 五域和共同协变量的 SHAP summary、域别热图和跨队列排名一致性。

### 补充图

- 变量 Harmonization Table 的分域可得性图。
- 缺失机制和缺失率热图。
- 开发集与目标集的 SMD/PSI 漂移热图。
- FI 分布、IC 五域分布及队列间重叠。
- 8 年死亡和 incident disability 敏感性分析。
- 按年龄、性别、教育和国家/地区的亚组校准。

## 7. 主要风险和必须避免的问题

1. **把关联研究写成预测研究。** C05、C06、C08、C09、C10、C11、C12、C13、C14、C15、C23、C24 主要是关联、测量或轨迹证据，不能作为外部验证性能证据。
2. **把随机混合切分写成外部验证。** 跨队列迁移必须按完整队列留出。
3. **外部测试后重新筛选变量。** 这会破坏外部验证；所有插补、标准化、特征选择和阈值选择必须在开发集完成。
4. **只报告最优 AUC。** 需要同时报告校准、Brier、DCA、事件率和协变量漂移。
5. **把 SHAP 当作因果效应。** SHAP 仅解释模型输出，不证明 FI/IC 对死亡的因果作用。
6. **直接合并不同量表。** IC 总分和域别变量需经过逐变量映射和测量等价性审查。
7. **过度解释“全球推广”。** SHARE/HRS 只能代表目标外部队列，不能覆盖所有文化和医疗制度。

## 8. 下一步执行顺序

1. 对 CHARLS、CLHLS、KLoSA、JSTAR、SHARE、HRS 逐队列盘点基线波次、死亡日期、删失日期、死亡事件和随访长度。
2. 建立逐变量 Harmonization Table，并先验证 FI 40+ deficits 的可构建性。
3. 对 IC 五域做可得性、分布和测量等价性检查；未通过时保留为并行/敏感性模块。
4. 冻结 5 年全因死亡主结局和 8 年敏感性结局的时间定义。
5. 先完成 Cox/pooled logistic 基线，再比较 RF、XGBoost、LightGBM 和生存 ML。
6. 按 Aim 1、Aim 2、Aim 3 顺序做严格外部验证，最后才做目标队列重校准。
7. 按 TRIPOD、PROBAST-AI 和模型卡要求保存变量字典、随机种子、预处理、模型参数和验证结果。

## 9. 输出文件

- `project3_literature_evidence_matrix.xlsx`：包含“研究设计”“核心证据矩阵”“全部 PDF 筛选台账”“待补齐 DOI”四个工作表。
- `project3_literature_review_and_design_report.md`：本综合报告。
- `core_paper_pages_2026-07-26.json`：本轮 PDF 页面级提取原始证据。

