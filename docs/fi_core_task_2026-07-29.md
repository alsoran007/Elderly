# FI_core 枚举任务（2026-07-29）

## 背景

六个队列的 FI 文件已全部完成（D-027）。现在需要枚举跨队列的公共 stems 子集（FI_core），供 SAP 预注册时的 Sensitivity Analysis 使用。

MHAS 仅有 27/41 stems，是最严格的下界约束。

## 任务目标

构建一张 **"41 stems × 6 队列"** 的覆盖矩阵，输出：
1. 每个 stem 在每个队列中的正率（positive rate, 60+ 子样本）
2. FI_core：**全部6个队列都有数据**的 stems 列表
3. FI_core_5of6：至少5/6队列有数据的扩展列表

## 正式文件列表（只读这些，不读其他）

```
D:/AI_project/project3/data/analysis/charls_fi_2011_2026-07-27.parquet   # CHARLS 41/41
D:/AI_project/project3/data/analysis/clhls_fi_2011_2026-07-29.parquet    # CLHLS 41/41
D:/AI_project/project3/data/analysis/klosa_fi_2012_2026-07-29.parquet    # KLoSA 41/41 w/subs
D:/AI_project/project3/data/analysis/hrs_fi_2012_2026-07-29.parquet      # HRS 41/41 w/subs
D:/AI_project/project3/data/analysis/share_fi_2011_2026-07-29.parquet    # SHARE 41/41 w/subs
D:/AI_project/project3/data/analysis/mhas_fi_2012_2026-07-28.parquet     # MHAS 27/41（用2026-07-28版）
```

## 执行步骤

### Step 1：读取并打印列名（发现结构）

```python
import pandas as pd

files = {
    "CHARLS": "D:/AI_project/project3/data/analysis/charls_fi_2011_2026-07-27.parquet",
    "CLHLS":  "D:/AI_project/project3/data/analysis/clhls_fi_2011_2026-07-29.parquet",
    "KLoSA":  "D:/AI_project/project3/data/analysis/klosa_fi_2012_2026-07-29.parquet",
    "HRS":    "D:/AI_project/project3/data/analysis/hrs_fi_2012_2026-07-29.parquet",
    "SHARE":  "D:/AI_project/project3/data/analysis/share_fi_2011_2026-07-29.parquet",
    "MHAS":   "D:/AI_project/project3/data/analysis/mhas_fi_2012_2026-07-28.parquet",
}

dfs = {}
for cohort, path in files.items():
    df = pd.read_parquet(path)
    dfs[cohort] = df
    print(f"\n=== {cohort} ===")
    print("Shape:", df.shape)
    print("Columns:", df.columns.tolist())
    if "age" in df.columns or any(c.startswith("r") and "agey" in c for c in df.columns):
        print("Age column found")
    print("FI-related cols:", [c for c in df.columns if "fi" in c.lower()])
```

打印结果后，判断：
- 列名是 `deficit_diab`、`d_diab`、`fi_diab`，还是直接用 stem 名如 `diab`？
- 是否有 `age60plus` 或类似的60+ 子集标记？

### Step 2：识别 deficit 列

根据 Step 1 发现的列命名模式，筛选出"个体 deficit 列"（区别于聚合 fi 分数列）。

已知的 41 个 stem 名称（来自 `docs/fi_specification_2026-07-27.md`，匹配时做模糊匹配）：

```
comorbidity (13): diab, heart, stroke, lung, cancer, arth, bp, fall, psy, livere, kidneye, digeste, asthmae
ADL (6): adlba, adldr, adlea, adlto, adlwk, adlbd
IADL (5): iadlmo, iadlmd, iadlfi, iadlph, iadlsh
mobility (9): mobwa, mobmo, mobcl, mobco, mobli, mobpu, joga, armsa, mobex
sensory (3): dsight, nsight, hearing
general health (4): shlt, mbmi, urina, slfmem
cognition (1): cogtot
```

### Step 3：构建覆盖矩阵

对每个 stem、每个队列，计算：
- 列是否存在（True/False）
- 若存在：60+ 子样本中（按年龄列筛选，或直接用全样本若无年龄列）的非缺失率、正率（mean）

输出格式（示例）：

| stem | domain | CHARLS_rate | CLHLS_rate | KLoSA_rate | HRS_rate | SHARE_rate | MHAS_rate | n_cohorts | in_FI_core |
|---|---|---|---|---|---|---|---|---|---|
| diab | comorbidity | 0.312 | 0.278 | 0.253 | 0.389 | 0.214 | 0.298 | 6 | True |
| urina | general | 0.214 | 0.287 | NA | 0.231 | NA | NA | 3 | False |

其中：
- `_rate` = 60+ 子样本中该 deficit==1 的比例（若整列为 NA，则输出 NA）
- `n_cohorts` = 有数据的队列数
- `in_FI_core` = n_cohorts == 6

### Step 4：生成汇总报告

**FI_core（全6队列）的 stems 列表，按 domain 分组列出：**

```
Domain: comorbidity (n_core / 13)
  - diab: CHARLS=0.31, CLHLS=0.28, KLoSA=0.25, HRS=0.39, SHARE=0.21, MHAS=0.30
  - ...
...
FI_core 总计：X / 41 stems
FI_core_5of6：Y / 41 stems（其中哪个队列缺失）
```

**质量警告标准**：
- 任意队列正率 < 0.01（< 1%）：标记 `⚠️ 极低正率`
- 任意队列正率 > 0.60 且该 stem 在其他队列正率 < 0.30：标记 `⚠️ 队列异常高`

## 输出文件

### 文件 1：`results/fi_core/fi_core_coverage_matrix_2026-07-29.csv`
所有41行，每行一个 stem，含全部上述字段。

### 文件 2：`docs/fi_core_enumeration_2026-07-29.md`
人类可读报告，包含：
- 执行摘要（FI_core N，FI_core_5of6 N）
- 完整覆盖矩阵表格
- FI_core stems 按域分组列表
- 缺失 stems（未进入 FI_core）的原因（哪个队列缺）
- 质量警告（若有）
- 对 SAP 的影响说明：`FI_core（X项）将作为主分析中 FI_full（41项，cohort-specific阈值）的敏感性对照，使用统一阈值 ceiling(0.8 × X)`

## 注意事项

- `D:/AI_project/sql/` 只读，不要访问
- MHAS 只读 `2026-07-28` 版本（`2026-07-29` 版已作废）
- 如果 parquet 列名与预期 stem 名不完全匹配，优先做正则/部分匹配，并在报告中注明实际列名→stem 名的映射
- 若某个 parquet 文件中没有个体 deficit 列（只有聚合 fi 分数），则改为读对应的 R 构建脚本，找出哪些 stem 有数据，并标记该信息来源为"脚本推断"而非"列实测"
- `results/fi_core/` 目录若不存在，请创建
