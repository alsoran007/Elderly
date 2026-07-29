# Project3 — EVIDENCE 证据任务清单(致 Gemini)

## 背景(已定案)
多国老龄队列 + 机器学习的迁移性研究。主结局=全因死亡;老龄表型(Frailty Index / WHO Intrinsic Capacity)作预测因子。队列:CHARLS/CLHLS/KLoSA(±JSTAR)/SHARE/HRS。目标期刊:Lancet Healthy Longevity、Nature Aging、J Gerontology。

## 你的角色:提供已有研究与证据,论证本设计的新颖性与空白
我们的卖点建立在四个"文献里反复被点名却没人真正解决"的 gap 上。请为每一条**证实或证伪**,并附高质量文献(题目/期刊/年/DOI/关键结论一句话)。

### 需要你系统检索并给出证据的问题

1. **测量等价性空白**:老龄队列研究中,是否已有人在建预测模型**之前**,用 multi-group CFA / IRT-DIF 正式检验 Frailty Index 或 Intrinsic Capacity 的跨国测量不变性?找出最接近的先例,说明它们做到哪一步、缺什么。

2. **可解释性漂移空白**:是否有人量化过 ML 模型的**特征重要性(SHAP等)在不同国家/队列间的稳定性**?几乎为空白请明确说明,有先例请列出。

3. **掉点来源分解空白**:跨队列迁移的性能下降,是否有人把它正式**拆解为 covariate shift / prevalence shift / P(Y|X) shift / 测量漂移**?现有文献(如 Nature Aging 2024、eClinicalMedicine 2024)停在哪一步?

4. **校准缺失**:多队列老龄预测文献里,报告**跨队列校准(calibration slope/intercept、DCA)**的比例如何?是否普遍只报 AUC/C-index?给出证据支持"校准是集体缺失点"这一论断。

### 方法学证据(供 Codex 参考)
5. FI 标准构建(Searle/Rockwood 40+ deficit)与 WHO Intrinsic Capacity 五域操作化的**权威方法学文献**。
6. Gateway to Global Aging Data 的 **Harmonized 数据集**在 CHARLS/CLHLS/KLoSA/SHARE/HRS 的覆盖情况与变量对齐文档;**JSTAR 是否被纳入标准 harmonized 集**(我们初判未纳入,需你核实)。
7. 跨队列迁移性方法(LOCO、importance weighting/密度比、Platt/截距重校准)在流行病学预测研究中的应用先例。

## 交付格式
- 每个问题:结论(空白/部分做过/已做透)+ 3–5 篇支撑文献 + 一句话 gap 判断。
- 汇总一句话:本设计相对现有文献的净新颖性在哪。
- 先回一条确认你能开始,以及预计给出证据的时间。
