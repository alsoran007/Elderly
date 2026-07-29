# Project3 — PI 决策放行(致 Codex)

你的 Module A 计划已通过评审,CFA/IRT 拆解专业到位。现补齐三条决策,数据阻塞已清零,可正式开工:

## 1. 数据状态更新:硬阻塞清零
- KLoSA 已到位,CLHLS 已解压。**5 个主流程队列(CHARLS/CLHLS/KLoSA/SHARE/HRS)数据全部齐备**。
- 现有格式:CHARLS 原始 .dta + Harmonized 文档;HRS = H_HRS_d.dta(Harmonized);SHARE = Gateway Harmonized .dta;CLHLS 已解压;KLoSA 已获取。
- 请优先使用各库的 Harmonized 版本对齐建表。

## 2. 结局时间窗
- **主分析:统一 5 年全因死亡窗**(样本损失最小,各库随访均覆盖)。
- **敏感性分析:8 年窗**,仅在随访足够长的库(CHARLS/CLHLS/HRS)上做。
- 生存分析(Cox/C-index)与固定窗二分类(XGBoost/LightGBM)并行,校准(calibration slope/intercept + DCA)为硬指标不可省。

## 3. 队列边界澄清(勿因 JSTAR 停滞)
- **JSTAR 从设计之初即为敏感性分析的可选队列,不在关键路径**。JSTAR 缺失/暂缺不构成阻塞,也不算"擅自删队列"——主流程 5 库不含 JSTAR。
- KLoSA 是主流程必需队列(已到位)。

## 现在可启动
- 立即启动 Module 0(ETL/数据审计)+ Module A(字段可得性矩阵、FI 40+ deficit 编码表、WHO IC 五域映射、分队列清洗+MICE、ordinal/binary CFA 三级不变性、IRT-DIF)。
- 分队列独立插补,不跨队列。
- 按你的工期推进,每模块产出中间结果供 PI 与 Claude 审阅,勿一次性跑完。
- Module A 通过测量等价性审查后,才进入 Module B 模型开发与 LOCO。

先回:确认收到本决策,并给出 Module 0 + A 的启动确认与首个里程碑预计时间。
