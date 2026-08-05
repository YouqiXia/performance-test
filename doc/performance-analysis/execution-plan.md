# 执行计划

> **当前路径选择：D（NLR 单层起步） → 按失败模式渐进加层 → 视需要长成 E（多算法 pipeline）**
> 路径 A / B / C / D / E 的定义与对比见同目录 `tooling-survey.md` Q3。
>
> 工程目标：不跑程序就预估全程 IPC。做法是把 trace 拆成"相连 BB 片段集合"，每片段独立做 dependence DAG 分析得 IPC，再按权重加权。
> 验证基准：cycle-accurate model 跑出的 IPC 作为 ground truth。
> 学习节奏：跑工具时配合同目录 `history.md` 对应章节伴读。

---

## 流程总图

```
M1 ─── M2 ─── M3 ─── [Decision 1] ─── M4 ─── M5 ─── [Decision 2] ─── M6 ─── [Decision 3] ─── M7
NLR    embench  精度    层补全？           失败    精度补                SPEC？           SPEC    路径 E
环境   首跑    验证                       case   验证                                  试水   完整化
                                          补层
```

**乐观路径**（NLR 一击即中）：M1 → M2 → M3 → M6 ≈ 12 天
**典型路径**（embench 需要补一层）：+ M4 + M5 ≈ 22 天
**悲观路径**（SPEC 仍需路径 E 完整化）：+ M7 ≈ 32 天

---

## M1：NLR 环境 + spike trace adapter（~2 天）

### 产出

- NLR 0.7 编译跑通（C99 单文件）
- `spike-trace-to-nlr.py`：将 `spike --log-commits` 输出转成 NLR 输入（BB 起始 PC 序列或地址序列）
- 反向映射脚本：NLR 输出的 for-nest → BB 范围 + 迭代数 → PC 区间

### Exit criteria

- 输入一个 hand-written affine 循环，NLR 能正确识别 + 反向映射到 PC

### 历史阅读绑定（路径 D = 6 分支中的分支 4）

- `history.md` Part 2 § 4 起源段：理解 NLR 的"逆问题"动机
- Ketterlin & Clauss CGO 2008 原文：算法步骤（一阶差分、自底向上匹配、affine recurrence 识别）

### 已知风险

- NLR 0.7 是单作者 2010 前后的代码，可能依赖老 toolchain → 提前 docker / nix shell 隔离环境

---

## M2：embench 首跑（~3 天）

### 产出

对 4 个代表性 embench 走完整链路：

| Benchmark | 形态 | 验证什么 |
|-----------|------|---------|
| matmult-int | 3 层嵌套 affine | NLR 应一击即中 |
| crc32 | 表查找 + LCG，跨函数（rand_beebs） | NLR 能否跨 jal 识别循环 |
| md5sum | 64 轮 + 4 状态变量轮转 | NLR 对"轮转模式"的识别力 |
| nettle-aes | 表查找密集 | NLR 在不规则地址上的反应 |

每个 benchmark 输出片段集：`{(BB 范围, 占比, 迭代数)}`

### Exit criteria

- 4 个 benchmark 中至少 2 个 NLR 覆盖率 ≥ 80%
- 至少 1 个 benchmark 揭露 NLR 失败模式（这是好事，给 M4 提供 case）

### 历史阅读绑定

- 跑 matmult-int 时回看 Part 1 § 三（Larus SEQUITUR 跨域跳跃）：对照 NLR 的 affine vs grammar 两种压缩思路差异
- 跑 crc32 时回看 Part 2 § 1（phase 与 path 的颗粒度对比）：crc32 实测的 175,104 iter 就是 NLR 该识别出来的对象

---

## M3：cycle-accurate model 精度验证（~2 天）

### 产出

- 每个片段独立做 dependence DAG（沿用 `doc/dep-chain-methodology.md`）
- DAG 给出 IPC_i 预估
- 加权求和：`IPC_predicted = Σ (weight_i × IPC_i)`
- 与 cycle-accurate model 跑出的 IPC_truth 对比
- 误差表：`{benchmark: IPC_predicted, IPC_truth, error%}`

### Exit criteria（决策点 1）

| 状态 | 平均误差 | 后续动作 |
|------|---------|---------|
| 绿灯 | < 10% | embench 阶段路径 D 验证成功，跳过 M4，直接进 M6 |
| 黄灯 | 10-25% | 进 M4，看哪个分量错得大 |
| 红灯 | > 25% | 进 M4 + 反思 DAG 方法学本身 |

### 历史阅读绑定

- 对照 Part 2 § 5（关键路径 / interval analysis）：Karkhanis-Smith mechanistic model 误差也是 ~5%，你的方法学是它的近亲，精度参照系大致相同

---

## Decision Point 1 — 仅黄/红灯时进 M4

```
失败模式 = ?
├─ NLR 漏掉的部分是不规则控制流 → 进 M4a（路径 C：WPP 复刻）
├─ 漏掉的部分是大段无明显循环   → 进 M4b（路径 A：SimPoint VLI 小 interval）
├─ 漏掉的是时序边界模糊         → 进 M4c（PELT 校准）
└─ DAG 方法学本身有问题         → 退一步检查 dep-chain-methodology
```

---

## M4：层补全（仅当 M3 黄/红灯，~5-10 天，按需）

### M4a 路径 C：WPP 复刻

- 工具：BL path 编号 + jsdw/cpp-sequitur
- 在 M2 失败的 benchmark 上单独验证
- 历史阅读：Part 2 § 3（WPP / SEQUITUR）、Larus PLDI 1999

### M4b 路径 A：SimPoint VLI

- 工具：qpoints 跑 BBV（RISC-V 友好）+ SimPoint VLI
- 调小 interval 到 100K~1M
- 历史阅读：Part 2 § 1（SimPoint 系）、Hamerly JILP 2005

### M4c PELT 校准

- 工具：deepcharles/ruptures 跑窗口特征
- 校 NLR / WPP 给出的边界
- 历史阅读：Part 1 § 七 + Codex 视角的"残余边界清理"

---

## M5：补层后再次精度验证（~2 天）

### 产出

- 与 M3 同样的误差表，但带上 M4 加的层
- 衡量"加一层带来多大精度提升"

### Exit criteria（决策点 2）

- 误差 < 10% → embench 阶段完成，进 M6
- 误差仍 > 10% → 回 M4 补另一层，或退到方法学层面找原因

---

## M6：SPEC2017 试水（~5-7 天）

### 产出

选 3 个 SPEC2017 benchmark：

| Benchmark | 形态 | 想看到什么 |
|-----------|------|----------|
| leela | 规则计算多 | NLR 是否仍占主导 |
| xz | 压缩，混合 | NLR + WPP 联合是否够 |
| gcc | 解释器型，路径多 | 故意挑难的，验证 SPEC 极端场景 |

走完整链路：trace → NLR (+M4 层) → 片段集 → DAG → 加权 IPC → 与 cycle-accurate model 对比

### Exit criteria（决策点 3）

- gcc 上 NLR + 已有层覆盖率 ≥ 80% → 路径 E 不用，方法学定型
- gcc 覆盖率不足 → 把 E 的剩余层（PELT + SEQUITUR）叠上，进 M7

### 历史阅读绑定

- Part 1 § 七（外部因素重塑）：SPEC 规模膨胀如何牵动 phase analysis 演化
- Part 2 § 1 当前状态：SimPoint 在 SPEC 圈仍是事实标准

---

## M7：路径 E 完整化（仅当 M6 决策点拒绝时，~7-10 天）

### 产出

完整路径 E pipeline：

```
spike trace
  → NLR     (规则循环)
  → WPP     (不规则热路径)
  → SEQUITUR(重复结构压缩)
  → PELT    (时序边界校准)
  → 覆盖率合并层 (片段互斥 + 90% 覆盖 + 最少片段数)
```

这是 Task B 调研里 Codex 推荐的最终形态。

### 历史阅读绑定

- Part 1 § 八（当下工业态势）：六分支合流的 datacenter 案例（AutoFDO + BOLT）
- 你做的事在小尺度上重演这种合流

---

## Milestone 总览表

| MS | 时间 | 关键产出 | 决策意义 |
|----|------|---------|--------|
| M1 | 2d | NLR 环境 + adapter | 工具链通了没 |
| M2 | 3d | 4 个 embench 片段集 | NLR 在 workload 上行不行 |
| M3 | 2d | 精度对比表 | 决策点 1：是否需要补层 |
| M4 | 5-10d | 补的那一层（C / A / PELT） | 仅黄/红灯触发 |
| M5 | 2d | 补层后精度对比 | 决策点 2：层够不够 |
| M6 | 5-7d | SPEC 3 benchmark 验证 | 决策点 3：路径 E 是否需要 |
| M7 | 7-10d | 完整路径 E | 仅 SPEC 触发 |

---

## 红线（绕开"硬撑"陷阱）

- 任何一个 milestone 超时 50% → 停一下回看是否走错方向，不要硬撑
- M3 / M5 / M6 的精度对比表是核心交付物，不是"跑过就行"
- 历史阅读不是 milestone 内的 task，是 milestone 期间的伴读 —— 跑工具时翻综述对应章节，不要切换上下文专门读

---

## 与本目录其他文档的关系

- `methodology.md`：定义"DAG 提取"4 步流程，本计划的 M3 / M5 在每个片段上调用它
- `history.md`：综述与历史脉络，作为伴读材料（M1-M7 各对应一个章节）
- `tooling-survey.md`：路径 A / B / C / D / E 的工具调研与选择依据
- `../embench-analysis-methodology.md`（在 doc/ 主目录）：早期源码 + 热点 + SimPoint 综合分析方法，本计划的 M2 / M3 与之并行

---

## 当前状态

- 已完成：历史综述、工具调研整合
- 正在：M1 准备工作（NLR 0.7 环境 + spike trace adapter）
- 已知阻塞：无

## Loose Ends（不堵主流程，方便后续清理）

- `methodology.md` 旧版有 6 个 TODO（D1-D4 阈值校准、多 phase iter 边界识别、ordering edge 映射等），已随精简版剥离；按 worked example 跑出来后视情况回填
- `history.md` 中 3 篇标 [需核实] 引用：Akram-Sawalha 综述出版去向、Eyerman ISCA 2010 完整标题、Gabel-Su 首发会议
- `history.md` 中 LCCT 首作者已在 `tooling-survey.md` 确认是 Yukinori Sato，文中标记可顺手清理

记录每个 milestone 的实际开始日期与产出位置，便于后续 retrospective。
