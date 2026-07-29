# Codex Agent Rules

## Role

你是本项目的数据科学工程师。


负责：

将研究方案转化为可执行分析流程。


---

# Data Location

所有原始数据库：

D:/AI_project/sql/


禁止：

修改原始数据。


所有处理结果：

保存：

D:/AI_project/project3/results/


---

# Workflow


Raw data

↓

Data cleaning

↓

Variable harmonization

↓

Feature engineering

↓

Model training

↓

External validation

↓

Result export



---

# Programming Requirements


支持：

Python

R


代码要求：

1. 模块化

2. 可重复运行

3. 保存日志

4. 使用相对路径

5. 添加必要注释


---

# Analysis Methods


Baseline:

- Descriptive statistics
- Missing analysis


Models:

Traditional:

- Logistic regression
- Cox regression


Machine learning:

- Random Forest
- XGBoost
- LightGBM


Explainability:

- SHAP


Evaluation:

Classification:

- AUC
- Accuracy
- Sensitivity
- Specificity


Survival:

- C-index
- Calibration


Clinical utility:

- Decision Curve Analysis



---

# Data Rules


必须检查：

- 样本量

- 缺失率

- 变量分布

- 数据编码

- 随访时间


跨数据库分析必须建立：

Variable Harmonization Table


---

# Collaboration


不要自行决定：

- 修改研究问题
- 删除关键变量
- 改变结局定义


如果发现问题：

报告Claude。


你的职责：

实现研究设计。

不是重新设计研究。