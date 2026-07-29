# Project3 文献检索状态（2026-07-25）

## 检索主题

- 多队列老龄化数据中的全因死亡、失能和健康结局预测
- Frailty Index（FI）与 WHO Intrinsic Capacity（IC）
- 机器学习模型开发、跨队列外部验证和 leave-one-cohort-out（LOCO）
- 跨文化迁移、模型校准、SHAP 和 Decision Curve Analysis（DCA）

## 本轮检索边界

已尝试访问 Crossref、OpenAlex、PubMed/E-utilities、Google Scholar 和 DOI 解析页面。当前运行环境仍拒绝这些外部服务，因此本文件不宣称完成在线元数据核验，也没有下载论文全文。

现有 `literature_map.xlsx` 中的条目继续保留为待核验线索。特别是其中部分 2024--2025 年题名、DOI、样本量和 AUC/C-index 数字，在在线核验前不得用于研究报告、论文或结果解释。

## 可作为检索起点的基础文献候选

下列条目是与本项目设计直接相关的经典方法学或理论锚点，先记录 DOI 线索；在外部元数据服务恢复后，应逐条核对作者、卷期、页码和 DOI 落地页面。

| 主题 | 文献候选 | DOI | 用途 | 当前状态 |
|---|---|---|---|---|
| FI 构建 | Searle et al. (2008). A standard procedure for creating a frailty index. *BMC Geriatrics*, 8, 24. | 10.1186/1471-2318-8-24 | 40+ deficits 的构建规则 | 待在线核验 |
| FI 理论 | Rockwood & Mitnitski (2007). Frailty in relation to the accumulation of deficits. *Journal of Gerontology: Series A*, 62(7), 722–727. | 10.1093/gerona/62.7.722 | 缺陷累积模型的理论依据 | 待在线核验 |
| Frailty 综述 | Clegg et al. (2013). Frailty in elderly people. *The Lancet*, 381(9868), 752–762. | 10.1016/S0140-6736(12)62167-9 | 老年衰弱定义和临床意义 | 待在线核验 |
| Frailty 公共卫生 | Hoogendijk et al. (2019). Frailty: implications for clinical practice and public health. *The Lancet*, 394(10206), 1365–1375. | 10.1016/S0140-6736(19)31786-6 | 结局选择和公共卫生解释 | 待在线核验 |
| 健康老龄化/IC | Beard et al. (2016). The World report on ageing and health: a policy framework for healthy ageing. *The Lancet*, 387(10033), 2145–2154. | 10.1016/S0140-6736(15)00516-4 | 健康老龄化和 IC 的政策框架 | 待在线核验 |
| 预测模型报告 | Collins et al. (2015). Transparent Reporting of a multivariable prediction model for Individual Prognosis Or Diagnosis (TRIPOD). *Annals of Internal Medicine*, 162(1), 55–63. | 10.7326/M14-0697 | 预测模型报告规范 | 待在线核验 |
| 预测模型评价 | Steyerberg et al. (2010). Assessing the performance of prediction models. *Epidemiology*, 21(1), 128–138. | 10.1097/EDE.0b013e3181c30fb2 | 区分判别与校准 | 待在线核验 |
| 校准 | Van Calster et al. (2019). Calibration: the Achilles heel of predictive analytics. *BMC Medicine*, 17, 230. | 10.1186/s12916-019-1466-7 | calibration slope/intercept 与校准图 | 待在线核验 |
| 临床效用 | Vickers & Elkin (2006). Decision curve analysis. *Medical Decision Making*, 26(6), 565–574. | 10.1177/0272989X06295361 | DCA 和净获益 | 待在线核验 |

## 面向本项目的重点检索式

```text
(CHARLS OR CLHLS OR KLoSA OR SHARE OR HRS OR ELSA OR MHAS)
AND (frailty index OR intrinsic capacity OR functional ability)
AND (mortality OR disability OR cognitive decline)
AND (machine learning OR XGBoost OR LightGBM OR random forest)
AND (external validation OR transportability OR leave-one-cohort-out OR calibration)
```

## 暂定研究方向（未替代 PI 决策）

1. 主结局优先考虑 5 年全因死亡：跨队列编码相对稳定、事件定义较客观，适合 Cox/C-index 与固定时间窗 AUC、校准和 DCA 并行评价。
2. 主暴露/核心预测模块优先考虑 FI 40+ deficits；WHO IC 五域作为并行的测量等价性模块，而不是在等价性审查前强行合成一个跨国总分。
3. 主要迁移评价应采用 CHARLS 开发、逐队列外部验证和 LOCO；模型性能下降需要同时检查 covariate shift、结局发生率差异、条件关系变化和测量不等价。
4. 失能、认知衰退和 8 年死亡可作为预先规定的次要或敏感性结局，不能在主结局确认前随意替换。

## 下一步

- 恢复公开文献元数据访问后，补充至少 10 篇可核验的实证论文，重点覆盖多队列老龄化预测和跨文化外部验证。
- 逐条验证现有 `literature_map.xlsx`，将每条记录标记为 `verified`、`partially_verified` 或 `unverified`。
- 在 Module 0 的变量可得性矩阵完成后，再最终确定暴露组合和结局窗口。
