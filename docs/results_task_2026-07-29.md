# 论文 Results 节起草任务（2026-07-29）

## 任务目标

基于已完成的所有分析结果，起草论文的**结果（Results）**节。输出为中文学术写作风格，保留英文技术术语（如 C-index, O:E ratio, SHAP 等）。

---

## 数据来源（只读，禁止修改）

请阅读以下文件以获取结果数值：

```
D:/AI_project/project3/results/aim1/aim1_performance_table_2026-07-29.csv
D:/AI_project/project3/results/aim1/aim1_report_2026-07-29.md
D:/AI_project/project3/results/aim1/model_b_charls_coefficients_2026-07-29.csv
D:/AI_project/project3/results/aim1/model_a_charls_coefficients_2026-07-29.csv
D:/AI_project/project3/results/aim2/aim2_loco_performance_2026-07-29.csv
D:/AI_project/project3/results/aim2/aim2_loco_report_2026-07-29.md
D:/AI_project/project3/results/aim3/aim3_performance_table_2026-07-29.csv
D:/AI_project/project3/results/aim3/aim3_report_2026-07-29.md
D:/AI_project/project3/results/aim3/aim3_share_country_cindex_2026-07-29.csv
D:/AI_project/project3/results/h6_shap/h6_shap_report_2026-07-29.md
D:/AI_project/project3/results/h6_shap/h6_spearman_matrix_2026-07-29.csv
D:/AI_project/project3/results/h6_shap/h6_rank_matrix_2026-07-29.csv
D:/AI_project/project3/results/ipcw/ipcw_clhls_report_2026-07-29.md
D:/AI_project/project3/results/ipcw/ipcw_clhls_metrics_2026-07-29.csv
D:/AI_project/project3/results/cohort_readiness/six_cohort_readiness_registry_2026-07-29.csv
```

---

## Results 节结构要求

### 3.1 研究对象特征（Study Populations）

撰写一段话描述六个队列的基线特征，包含：
- 各队列FI可计算60+人数（表格形式）
- 各队列4年事件数和事件率
- FI中位数（从readiness registry获取）和四分位范围（若有）
- 一句话说明各队列主要人口学差异（年龄、事件率范围）

### 3.2 FI分布（FI Distribution）

从各队列的FI统计数据描述FI分布：
- FI中位数（CHARLS=0.200, CLHLS=0.169, KLoSA=0.095, HRS=0.287, SHARE=0.169, MHAS=0.220）
- 说明KLoSA中位数0.095的合理性（社区居住、中位年龄71岁）

### 3.3 CHARLS 开发集模型（Model Development）

从 model_a_charls_coefficients 和 model_b_charls_coefficients 报告：
- FI（Model B）的回归系数（β, OR, p值）
- 年龄系数
- ΔC（Model B - Model A）
- H1判定：ΔC = 0.035 ≥ 0.02，H1成立

### 3.4 Aim 1：CHARLS→CLHLS 外部验证

从 aim1_performance_table 报告CLHLS外部验证：
- C-index = 0.8389（95% CI: 0.8301–0.8481）
- O:E = 1.2473（模型低估CLHLS死亡率，原因：CHARLS训练事件率10% vs CLHLS目标46%）
- Calibration slope = 0.9393
- IPA = 0.2957
- 注明教育调整版本未包含，为初步结果

### 3.5 Aim 2：LOCO 分析（多队列训练可迁移性）

从 aim2_loco_performance 报告：
1. 三轮LOCO的C-index、O:E、校准斜率（原始/L1重校准）
2. **H3判定**：downsampled ΔC Round B=+0.0013, Round C=−0.0013，H3不成立
3. 说明多队列训练无法改善判别力的意义
4. L1重校准后O:E = 1.000，截距更新的有效性

### 3.6 Aim 3：亚洲池→HRS/SHARE/MHAS L0-L3 重校准阶梯

从 aim3_performance_table 报告：
1. 亚洲池规格（N=19,934, events=4,563, rate=22.9%）
2. 各验证队列L0-L3完整指标表（C-index, O:E, slope, IPA）
3. **H2判定**：判别力L0→L3变化<0.003，O:E变化>0.4 → H2成立
4. **H4判定**：L1修正解释89-95%的可改善空间 → H4成立
5. SHARE内19国C-index：中位数=0.768，范围[0.691, 0.856]
6. MHAS L0 IPA=-0.002 → 事件率漂移过大需L1+L2修正

### 3.7 IPCW 灵敏度分析

从 ipcw_clhls_metrics 报告：
- CLHLS 22.9%结局未知（2,112/9,207）
- 删失模型：高FI和高龄者更可能被观察（fi_full p=0.0004, age p<0.0001）
- IPCW加权 vs 无权重：ΔC = +0.0008，完整案例分析稳健

### 3.8 特征重要性分析（SHAP，H6）

从 h6_shap_report 和 h6_spearman_matrix 报告：
1. 年龄在所有6个队列中均排名第1
2. 第二常见特征：shlt（自评健康）出现在4/6队列前3
3. 跨队列Spearman秩相关：中位数=0.41，范围[0.10, 0.67]
4. **H6判定**：PARTIAL（年龄始终第1成立；中位Spearman=0.41<0.70未达阈值）
5. KLoSA与CHARLS相关性最低（0.099），说明人群特异性差异

---

## 输出要求

**输出文件**：`D:/AI_project/project3/docs/paper_results_draft_2026-07-29.md`

**格式要求**：
- 中文学术写作风格，保留英文技术术语
- 每个子节用 `### 3.x` 标题
- 关键数字加粗（如 **0.8389**）
- 正式报告H1-H6判定结论，使用"成立/不成立/部分成立"
- 适当引用表格（"见表X"）但不需要生成实际LaTeX表格，用Markdown即可
- 总字数约1500-2500中文字

**注意事项**：
- D:/AI_project/sql/ 只读，不访问
- 所有数字必须与分析输出文件一致，不得自行估算
- 教育调整缺失须在正文中说明
- 报告Aim1 CLHLS事件率时注意：完整案例为7,095人/3,282事件/46.3%（非原始9,207/3,502）
