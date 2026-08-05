# Performance Analysis 文档目录

> 一套用于"不跑程序就预估 IPC"的方法学：从动态 trace 中提取相连 BB 片段集合，每片段独立做 dependence DAG 分析，按权重加权得到全程 IPC 预估。

---

## 4 份文档及其角色

| 文档 | 角色 | 何时读 |
|------|------|-------|
| `methodology.md` | **总览**：4 步主干流程定义 | 第一次接触这套工作的人，先读它 |
| `tooling-survey.md` | **工具调研**：路径 A/B/C/D/E 的候选工具与对比 | 决定 trace profiler 用什么算法时 |
| `execution-plan.md` | **执行计划**：M1-M7 渐进 milestone | 落地阶段，按它走 |
| `history.md` | **历史综述**：性能分析子领域 6 分支演化 | 跑工具时的伴读材料，不是离线读 |

---

## 文档间关系

```
        ┌────────────────────┐
        │   methodology.md   │  ← 4 步主干，定义 IO 接口
        │    (总览，3 KB)    │
        └─────────┬──────────┘
                  │ Step 1 trace profiler 用什么工具？
                  ▼
        ┌────────────────────┐
        │  tooling-survey.md │  ← 调研 15+ 候选，给出路径 A/B/C/D/E
        │   (28 KB)          │
        └─────────┬──────────┘
                  │ 选了路径 D 起步，怎么落地？
                  ▼
        ┌────────────────────┐
        │  execution-plan.md │  ← M1-M7 + 3 个决策点
        │   (8 KB)           │
        └─────────┬──────────┘
                  │ 跑工具时翻哪段历史？
                  ▼
        ┌────────────────────┐
        │   history.md       │  ← 6 分支历史脉络，伴读用
        │   (94 KB)          │
        └────────────────────┘
```

---

## 当前选择（一句话）

**路径 D（NLR 单层）起步 → 按失败模式渐进加层 → 视需要长成路径 E（多算法 pipeline）**

- 验证基准：cycle-accurate model 跑出的 IPC 作为 ground truth
- 第一阶段：embench（4 个代表性 benchmark）
- 第二阶段：SPEC2017（3 个代表性 benchmark）

详见 `execution-plan.md`。

---

## 与 doc/ 主目录其他文档的关系

| 文档 | 关系 |
|------|------|
| `../embench-analysis-methodology.md` | 早期源码 + 热点 + SimPoint 综合分析方法，本目录 execution-plan M2/M3 与之并行 |
| `../embench/<bench>.md` | 具体 benchmark 的应用结果（CRC32 等） |

---

## 当前状态

- ✓ 历史综述完成（`history.md`）
- ✓ 工具调研完成（`tooling-survey.md`）
- ✓ 执行计划落地（`execution-plan.md`）
- → 进行中：M1（NLR 0.7 环境 + spike trace adapter）

---

## 索引：怎么快速找到答案

| 你在想什么 | 看哪份文档的哪一节 |
|-----------|-----------------|
| "DAG 提取的 4 步是什么" | `methodology.md` § 4 步主干流程 |
| "什么叫 hazard 三类边" | `methodology.md` § 三类 hazard 与 DAG 边的对应 |
| "为什么不用 SimPoint 默认 100M" | `tooling-survey.md` Q2 § 1 + § 2 |
| "NLR 是谁提出的，解决什么问题" | `history.md` Part 2 § 4 |
| "现在做到哪一步了" | `execution-plan.md` § 当前状态 |
| "下一步具体跑什么" | `execution-plan.md` § M1 / M2 |
| "路径 D 失败了该怎么办" | `execution-plan.md` § Decision Point 1 + § M4 |
| "为什么倾向 NLR 而不是 SimPoint" | `tooling-survey.md` § 推荐 Top-3 |
