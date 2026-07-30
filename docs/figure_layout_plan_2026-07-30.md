# Figure 统一排版规划 — Paper 1（2026-07-30）

**说明**：本文件规划 Paper 1 所有主图和补充图的内容、数据来源、尺寸和格式要求，供后续统一绘制时参考。规划原则：主图 ≤ 5 张，Supplementary ≤ 5 张；颜色方案统一；字体统一使用 Arial 10–12pt；所有图输出为 TIFF/PDF 双格式（TIFF 600 dpi 用于投稿，PDF 用于版面调整）。

---

## 主图（Main Figures）

### Figure 1：研究设计与队列流程图

| 项目 | 内容 |
|---|---|
| **类型** | CONSORT-style 流程图 |
| **内容** | 六个队列各自的纳入/排除流程；Aim 1/2/3 的训练/验证分配关系；三个 Aim 的逻辑结构（CHARLS 开发→CLHLS 验证→LOCO→全球验证）|
| **数据来源** | decision_log D-010/D-013/D-019/D-024 + 各队列分析文件 N 数 |
| **关键数字** | CHARLS: 17,705→7,551 (60+)→771 events；CLHLS: 9,765→7,095 (完整案例)→3,282 events；含 ELSA 排除说明（D-013）|
| **推荐尺寸** | 宽 180mm × 高 220mm（双栏全高）|
| **软件** | draw.io 或 BioRender；导出SVG后矢量化 |
| **注意** | Aim 3 三个目标队列（HRS/SHARE/MHAS）用单独分支；标注 Aim 1/2/3 颜色区块 |

---

### Figure 2：六队列 FI 分布与基线特征

| 项目 | 内容 |
|---|---|
| **类型** | 分组小提琴图（violin plot）+ 箱线叠加；右侧配套关键特征表 |
| **内容** | 六队列 60+ FI 分布（按队列着色）；各队列中位数标注；事件率在标题行标注 |
| **数据来源** | 六个 FI parquet 文件（D-027）；各队列 60+ 子集 |
| **分面顺序** | CHARLS / CLHLS / KLoSA（亚洲开发）// HRS / SHARE / MHAS（外部验证）|
| **颜色方案** | 开发组：蓝色系（CHARLS深蓝、CLHLS中蓝、KLoSA浅蓝）；验证组：橙色系（HRS橙、SHARE橙黄、MHAS浅橙）|
| **推荐尺寸** | 宽 180mm × 高 100mm（双栏）|
| **软件** | ggplot2（R）；`geom_violin + geom_boxplot` |
| **注意** | X轴统一 [0, 1]；KLoSA中位0.095单独标注说明（见Discussion §4.5）|

---

### Figure 3：Aim 1 模型开发与 CLHLS 外部验证

| 项目 | 内容 |
|---|---|
| **类型** | 双面板：左=CHARLS 内部 ROC（Model A vs B）；右=CLHLS 校准十分位点图 |
| **内容** | 左面板：ROC 曲线 Model A (C=0.736) vs Model B (C=0.771)，阴影区 95% CI；右面板：CLHLS 预测（x轴）vs 观测（y轴）十分位点校准图，O:E=1.25 注记 |
| **数据来源** | `results/aim1/aim1_performance_table_2026-07-29.csv`；`results/aim1/aim1_report_2026-07-29.md`（十分位校准数据）|
| **推荐尺寸** | 宽 180mm × 高 90mm（双栏双面板，各90mm宽）|
| **软件** | ggplot2；左面板 `geom_path`；右面板 `geom_point + geom_errorbar + geom_abline` |
| **注意** | 右面板对角线（理想校准）用虚线；十分位点误差棒为95%CI；图注需说明CLHLS内IC代理已排除（主模型为FI）|

---

### Figure 4：Aim 2 LOCO 多队列迁移分析

| 项目 | 内容 |
|---|---|
| **类型** | 三行 × 两列面板：左列 Raw（L0），右列 L1 重校准后；各行为 Round A/B/C |
| **内容** | 每个面板为校准曲线（光滑曲线 + 十分位点）；右列标注 O:E=1.000；左下方 C-index 注记 |
| **数据来源** | `results/aim2/aim2_loco_performance_2026-07-29.csv`；`results/aim2/figures/` 现有4张校准图 |
| **推荐尺寸** | 宽 180mm × 高 180mm（3×2，每格60mm×90mm）|
| **软件** | ggplot2；用 `facet_grid` 实现三轮×raw/L1 |
| **注意** | 统一 y 轴 [0,1]；Round 行标签在左侧；Raw/L1 列标签在顶部；H3 阴性结果在图注中说明 ΔC<0.002 |

---

### Figure 5：Aim 3 L0–L3 重校准阶梯（HRS / SHARE / MHAS）

| 项目 | 内容 |
|---|---|
| **类型** | 三队列 × 四指标（C-index、O:E、Cal slope、IPA）分面折线图，x轴为重校准层次 L0/L1/L2/L3 |
| **内容** | 每个队列用不同颜色线段；IPA 子面板包含 L0 负值（MHAS IPA=-0.002）；O:E 加水平参考线 y=1.0 |
| **数据来源** | `results/aim3/aim3_performance_table_2026-07-29.csv` |
| **推荐尺寸** | 宽 180mm × 高 120mm（1×4 面板，各约 45mm 宽）|
| **软件** | ggplot2；`facet_wrap(~metric)` |
| **注意** | IPA 面板 y 轴需包含负值（MHAS L0=-0.002）；O:E 面板标注 L1 后三队列均=1.000；颜色沿用橙色系 |

---

## 补充图（Supplementary Figures）

### Figure S1：H6 特征重要性热力图

| 项目 | 内容 |
|---|---|
| **内容** | FI_core 19条目 + age × 6队列的 |β_standardised| 热力图；右侧聚类树（队列间相似度）|
| **数据来源** | `results/h6_shap/h6_importance_matrix_2026-07-29.csv` |
| **推荐尺寸** | 宽 160mm × 高 120mm |
| **注意** | KLoSA 与其他队列的低相关（Spearman~0.10）在热力图颜色分布中应清晰可见 |

### Figure S2：SHARE 19 国 C-index 分布

| 项目 | 内容 |
|---|---|
| **内容** | 欧洲地图着色（C-index 深浅）+ 右侧排序点图；中位数水平参考线（C=0.768）|
| **数据来源** | `results/aim3/aim3_share_country_cindex_2026-07-29.csv` |
| **推荐尺寸** | 宽 160mm × 高 90mm（地图+点图拼合）|
| **注意** | 地图使用 `rnaturalearth`；点图按 C-index 降序排列；最低（荷兰）和最高（法国Cf）标注 |

### Figure S3：IPCW 敏感性分析（CLHLS）

| 项目 | 内容 |
|---|---|
| **内容** | 完整案例 vs IPCW 加权校准曲线叠加；右侧指标比较表（ΔC=+0.0008 等）|
| **数据来源** | `results/ipcw/ipcw_clhls_metrics_2026-07-29.csv`；`results/ipcw/ipcw_clhls_report_2026-07-29.md` |
| **推荐尺寸** | 宽 120mm × 高 90mm |

### Figure S4：H5 补充分析 — FI vs IC 跨队列比较

| 项目 | 内容 |
|---|---|
| **内容** | 哑铃图：CHARLS 内部 C（空心点）→ CLHLS 外部 C（实心点），Model B/C/D 各一行；|ΔC| 在右侧标注 |
| **数据来源** | `results/h5_ic/h5_model_comparison_2026-07-29.csv` |
| **推荐尺寸** | 宽 120mm × 高 70mm |
| **注意** | 图注需说明CLHLS IC为二元代理的局限；H5判定"SUPPORTED（补充分析）"标注 |

---

## 主表（Main Tables）

| 编号 | 标题 | 内容 | 数据来源 |
|---|---|---|---|
| Table 1 | 六队列基线特征 | N（60+）、年龄均值（SD）、女性%、FI中位数（IQR）、4年事件数/率 | FI parquet + outcome files |
| Table 2 | CHARLS 开发集模型系数 | Model A/B的 β（SE）、OR（95%CI）、p值 | `model_b_charls_coefficients_2026-07-29.csv` |
| Table 3 | 全队列性能汇总（L0–L3） | 六队列 C-index、O:E、Cal slope、Brier、IPA，按层次分列 | aim1/aim2/aim3 CSV |

## 补充表（Supplementary Tables）

| 编号 | 标题 | 内容 |
|---|---|---|
| Table S1 | FI 41项最终清单 | 条目名、域、定义来源（Gateway do行号）、各队列可得性 |
| Table S2 | FI_core 覆盖矩阵 | 19项×6队列；含全NA标注（joga/dimea） |
| Table S3 | H6 Spearman 相关矩阵 | 6×6矩阵全值 |
| Table S4 | SHARE 19国C-index | 国家、N、事件数、C-index（95%CI）|

---

## 统一格式要求

| 要素 | 规范 |
|---|---|
| **字体** | Arial，正文 10pt，轴标签 10pt，图注 9pt |
| **颜色** | 开发队列：蓝色系 (#2166AC系列)；验证队列：橙色系 (#D94801系列)；中性：灰色 (#636363) |
| **分辨率** | 主图 TIFF 600 dpi；矢量图另存 PDF |
| **面板标签** | 大写粗体 **A**, **B**, **C**…，左上角，Arial 12pt bold |
| **参考线** | 对角线（理想校准）：黑色虚线；水平参考线（O:E=1）：红色点线 |
| **误差线** | 95% CI，线宽1pt；若CI很窄可改为帽形误差棒 |
| **图注** | 每图正文下方；含关键统计量（C-index/O:E/N）；缩写在第一次出现处展开 |
| **统一说明文字** | 所有图注最后一行：*Abbreviations: FI, Frailty Index; CI, confidence interval; O:E, observed-to-expected ratio; IPA, Index of Prediction Accuracy.* |

---

## 制图优先级与时间规划

| 优先级 | 图号 | 所需新工作 | 预估工时 |
|---|---|---|---|
| 1 | Figure 1（流程图） | 需从头绘制 | 2h |
| 1 | Figure 5（L0–L3阶梯） | 需新建ggplot脚本 | 2h |
| 2 | Figure 3（Aim1 ROC+校准） | 部分数据已有，需整合 | 1.5h |
| 2 | Figure 4（LOCO校准） | 现有4图需格式统一 | 1.5h |
| 3 | Figure 2（FI分布） | 需合并6个parquet绘制 | 1.5h |
| 4 | Figures S1–S4 | 现有数据基本就绪 | 各0.5–1h |

---

*规划日期：2026-07-30*
*下一步：依优先级制图；Abstract定稿后同步翻译；TRIPOD+AI Checklist在Methods最终稿完成后逐条核验*
