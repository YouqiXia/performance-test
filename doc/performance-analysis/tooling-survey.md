# 工具调研：从动态 trace 中提取「相连 BB 片段集合」

## Q1：候选清单

下表覆盖 Task A 六个分支以及邻接借鉴池（生物信息 / 时序）。每行的"工具状态"列已尽可能查证；引用未亲见原文的标 `[需核实]`。

| # | 算法 / 工具名 | 一手出处 | 开源实现 + URL | 维护状态 | Task A 分支 |
|---|---|---|---|---|---|
| 1 | **SimPoint 3.2**（k-means + BBV，固定区间） | Sherwood et al., *Automatically Characterizing Large Scale Program Behavior*, ASPLOS 2002；Hamerly et al., *SimPoint 3.0*, JILP 2005 | UCSD 原版 https://cseweb.ucsd.edu/~calder/simpoint/ ；GCC 9 修复版 https://github.com/s117/SimPoint | UCSD 原档静态（2008），s117 fork 仍接受 issue（最近改动 2022 左右） | 1 |
| 2 | **SimPoint VLI**（Variable Length Intervals，区间边界沿过程/循环边界对齐） | Lau, Schoenmackers, Calder, *Motivation for Variable Length Intervals and Hierarchical Phase Behavior*, ISPASS 2005 | 集成在 SimPoint 3.0+ 的 `-coveragePct` / VLI option 内；BBV 由 PinPlay/Valgrind 侧产生 | 同 SimPoint 3.x | 1 |
| 3 | **Valgrind exp-bbv**（BBV 生成器，可配置 interval=10K~1M） | Weaver, Sherwood, *Multiplatform SimPoint Generation via DBI*, HiPEAC LNCS 4917 (2008) | https://valgrind.org/docs/manual/bbv-manual.html | 跟随 Valgrind 主线维护 | 1 |
| 4 | **PinPoints (Intel pinplay-tools)** | Patil et al., *Pinpointing Representative Portions of Large Intel Itanium Programs with Dynamic Instrumentation*, MICRO 2004；扩展见 Sasanka et al. PinPlay PLDI 2010 | https://github.com/intel/pinplay-tools ；包含 SDE 9 中 | 活跃（最近一年内有 commit） | 1 |
| 5 | **qpoints (QEMU SimPoint plugin)** | 工程实现，无独立论文 | https://github.com/Project-Slicer/qpoints （RISC-V Spike machine 友好）；衍生 https://github.com/pranith/qpoints | Project-Slicer 仓库 2023-2024 间有更新 | 1（与目标 ISA 直接对齐） |
| 6 | **Ball-Larus 路径编号 + LLVM PathProfiling** | Ball, Larus, *Efficient Path Profiling*, MICRO 1996 | LLVM 历史路径：`llvm/lib/Transforms/Instrumentation/PathProfiling.cpp`（已从主线移除，可在旧版找到）；Cornell CS6120 课程实现；https://github.com/lac-dcc/Nisse （Ball-Larus 改进） | LLVM 主线已 deprecate；Nisse 有近期更新；多份课程实现 | 3 |
| 7 | **WPP (Whole Program Paths) — Larus 1999 流水** | Larus, *Whole Program Paths*, PLDI 1999 | **无原始 WPP 工具公开**；SEQUITUR 后端有多份开源实现：https://github.com/jsdw/cpp-sequitur ；https://github.com/hammacher/sequitur （Java）；https://github.com/elarielcl/ArielsSequitur | SEQUITUR 实现稳定；前端（acyclic-path-trace 编号→SEQUITUR 输入）需自接 | 3 |
| 8 | **NLR (Nested Loop Recognition) — Ketterlin 0.7** | Ketterlin, Clauss, *Prediction and Trace Compression of Data Access Addresses through Nested Loop Recognition*, CGO 2008 | https://icps.u-strasbg.fr/nlr/ （nlr-0.7.tar.gz） | 单作者维护，最新 0.7 估计 2010 前后 [需核实精确日期]；C99 单文件构建 | 4 |
| 9 | **PLR (Polynomial Loop Recognition)** | Ketterlin, *Polynomial Loop Recognition in Traces*, IMPACT 2025 (workshop, Jan 2025, Barcelona) | 论文中的工具：HAL https://inria.hal.science/hal-04922050 ；PDF https://www.impact-workshop.org/impact2025/papers/plr.pdf ；分发 URL 需向作者询问 [需核实是否已公开] | 2025 年发布，新近 | 4 |
| 10 | **Exana**（LCCT，loop-call context tree；on-the-fly 循环嵌套识别） | Sato, Inoguchi, Nakamura, *Identifying Program Loop Nesting Structures during Execution of Machine Code*, IEICE Trans. Information and Systems E97-D(9):2371-2385, 2014；工具论文：Sato et al., *Exana: an execution-driven application analysis tool*, SEPS 2015 (workshop) | https://github.com/YukinoriSato/Exana （基于 Intel Pin 3.7） | 19 commits，2014-2018 间活跃，之后停滞 | 4 |
| 11 | **DynamoRIO 自定义 trace API**（NET 算法的可改写实现） | Bala, Duesterwald, Banerjia, *Dynamo: A Transparent Dynamic Optimization System*, PLDI 2000；DynamoRIO 论文：Bruening, MIT 2004 thesis | https://github.com/DynamoRIO/dynamorio ；trace creation 通过 `dr_register_trace_event` / `dr_mark_trace_head` API | 高度活跃 | 2 |
| 12 | **DCFG (Intel Dynamically Discovered Control-Flow Graph)** | Intel SDE 文档；passlab 集成版 | https://github.com/passlab/DCFG ；Intel SDE 内置 | passlab 仓库较旧；SDE 内 DCFG 跟随 SDE 维护 | 2/3 边界 |
| 13 | **CLIPPER (iterative pattern mining)** | Lo, Khoo, Liu, *Efficient Mining of Iterative Patterns for Software Specification Discovery*, KDD 2007；扩展 TKDE 2011 | **无作者维护开源工具**；近邻替代：SPMF https://www.philippe-fournier-viger.com/spmf/ （周期/序列模式实现合集，Java） | SPMF 持续维护（年级别更新） | 6 |
| 14 | **DiffTrace**（NLR + concept lattice + 层次聚类，HPC trace 比对） | Taheri, Briggs, Burtscher, Gopalakrishnan, *DiffTrace: Efficient Whole-Program Trace Analysis and Diffing for Debugging*, IEEE Cluster 2019 | 论文 https://userweb.cs.txstate.edu/~mb92/papers/cluster19.pdf ；公开仓库 [需核实] | 学术原型 | 4+6 组合 |
| 15 | **变长时序 motif（grammar-induction 路线）** | Li, Lin, Oates, *Visualizing Variable-Length Time Series Motifs*, SDM 2012；底层是 SEQUITUR | 多份 SEQUITUR 实现见 #7；motif 可视化原型见作者主页 | 邻接领域；通用工具，非程序专用 | 邻接（生物信息/时序） |
| 16 | **Interprocedural Path Profiling** | Melski, Reps, *Interprocedural Path Profiling*, CC 1999 | 无现成实现 | 无公开可查的现成开源实现 | 3（跨过程路径扩展） |
| 17 | **PELT / ruptures 时序断点检测** | Killick, Fearnhead, Eckley, *Optimal Detection of Changepoints with a Linear Computational Cost*, JASA 2012 | [deepcharles/ruptures](https://github.com/deepcharles/ruptures) | v1.1.10 (2025-09-10)，仓库活跃，维护状态在所有候选里最佳 | 邻接（changepoint detection；用作边界辅助） |

> 说明：原本的 `Loop-Call Context Graph` (Moseley/Sato 系列) 在 Task A 标 [需核实首作者]；本次确认首作者为 **Yukinori Sato**，论文 IEICE Trans. E97-D 2014。Tipp Moseley 的 LoopProf（PACT 2006/2007 工作坊报告）是另一条相关线，但不是同一篇。

---

## Q2：每个候选的端到端处理流程

### 1. SimPoint 3.2

```
PC 流（spike --log-commits）
  → BBV 生成器（exp-bbv / qpoints / 自写脚本）：以固定 interval 输出 sparse BBV
  → simpoint 二进制（k-means + BIC 选 k）
  → simpts/weights 文件：(interval_id → cluster_id, cluster_weight)
```

- **「相连」定义**：**不显式建模相连**。每个片段是 *固定窗口* 的连续指令，BB 之间天然 fall-through。但跨 cluster 之间无相连关系，cluster 内含哪些 BB 需要回查 BBV。
- **片段数量**：由 BIC 在 `MaxK`（默认 10~30）内自动选；可强制 `--maxK 30`。
- **占比权重**：simpoint 输出每 cluster 的 weight（覆盖率 = 该 cluster interval 数 / 总 interval 数）。
- **下游契合度**：每个 representative interval 是一段连续 PC 流，可直接做 dependence DAG 分析。**问题**：默认 interval 100M 太粗；需要自定义到 10K~1M（exp-bbv 支持 `--bb-out-file --interval-size=N`）。
- **判断**：方向最对路。但用户需要的"相连 BB 子图"在 SimPoint 模型里隐式的——cluster 内 BB 集合可以通过 BBV 的非零项重建，不过 BB 间转移频率需要额外记录。

### 2. SimPoint VLI

```
PC 流 + 静态二进制（识别 procedure call/loop boundary）
  → 沿过程/循环边界切 variable-length interval
  → BBV（带 weight = interval 长度）
  → SimPoint k-means（带 weight）
  → 代表 interval 集
```

- **「相连」**：interval 边界对齐到 procedure call/return/loop entry-exit，因此每个 interval 内 BB 控制流封闭性更强。
- **片段数量**：BIC 自动；用户可设 cluster 上限。
- **占比**：weight 反映指令数占比（不再是等长 interval 数）。
- **下游契合度**：比固定 interval 高一档——interval 边界即"循环单元"边界，自然对应工程目标的"循环单元尺度"。
- **判断**：在 SimPoint 系里**最匹配工程目标**的变体。但 VLI 的边界标注需要静态分析配合，spike --log-commits 直出还需补一步（识别 backward branch 作为 loop edge 即可，工作量小）。

### 3. Valgrind exp-bbv

仅 BBV 生成器，作为 SimPoint/SimPoint VLI 的前端使用；输出 `bb.out`（per-interval BBV）+ `pc.out`（每个 BB 的代表 PC）。

- 支持 interval 任意配置（默认 100M，可调到 10K）。
- 不做聚类、不输出片段。
- **判断**：组件级工具，不独立解题。x86/ARM 平台为主，对 RISC-V 用 qpoints 替代。

### 4. PinPoints (Intel pinplay-tools)

```
ELF + Pin → pinplay 录制 → BBV（per-interval）→ simpoint → pinball checkpoint（含 warmup region）
```

- **「相连」**：interval 内连续；cluster 之间不相连。
- **片段数量**：SimPoint 决定。
- **占比**：cluster weight。
- **下游契合度**：pinball 是确定性 replay 文件，可重放进任意 simulator；适合 x86，对 RISC-V 不直接适用。
- **判断**：x86 项目首选，**不适合本工程**（spike + RISC-V）。

### 5. qpoints (QEMU SimPoint plugin)

```
QEMU TCG plugin → BBV（QEMU 看得到 BB 边界）→ SimPoint
```

- 支持 `qemu-system-riscv64 -machine spike`，与本工程 ISA 完全对齐。
- 其余流程同 SimPoint。
- **判断**：本工程**最直接可用的 BBV 前端**。spike 自身没有 BBV plugin（有 issue #16 但未实现），改用 qpoints 是最短路径；或在 spike `--log-commits` 输出上写一个 BBV 后处理脚本（后者更轻）。

### 6. Ball-Larus + LLVM PathProfiling

```
LLVM IR → BL pass 编号 acyclic path → 运行时计数器记每条 path 的 frequency → top-K 最热 path
```

- **「相连」**：每条 BL path 是从函数 entry 到 exit / 从 backedge target 到 backedge source 的*单一无环路径*，BB 全部相连且 fall-through。
- **片段数量**：用户阈值（频率 top-K，或累计覆盖率）。
- **占比**：每条 path 的执行次数 / 总 path 次数。
- **下游契合度**：path 是 BB 序列；天然适合 dependence DAG 分析。**限制**：跨 backedge 的 inter-iteration 数据流被切断（每条 path 内不含循环），所以"循环作为整体片段"需要把多条 path 按 loop header 聚合。
- **判断**：用户工程目标的**最干净对接**。如果接受"片段 = 循环体的一条 acyclic path"颗粒度，且不要求严格"跨 backedge 仍相连"，BL 路径直接出片段集。需要外部循环包封不复杂。

### 7. Larus WPP (PLDI 1999)

```
Ball-Larus path 流（每次跨 backedge / function call 输出一个 path id）
  → 转成 path-id 字符串
  → SEQUITUR 压缩成层级文法（CFG）
  → 在文法树中找出现频率高的子串（hot subpath）
  → hot subpath 反向解码回 BB 序列
```

- **「相连」**：subpath 由连续 path-id 组成，每个 path 内 BB 相连；path 间通过 backedge/call 相连，因此 subpath 是*跨循环迭代和跨函数*的**真正的"相连 BB 序列"**。
- **片段数量**：按文法规则的 utility = `(rule_length × usage_count)` 排序 top-K，或卡覆盖率阈值。
- **占比**：每条规则的 `usage_count × rule_length` / 总 path 长度。
- **下游契合度**：**与工程目标几乎完全对齐**——hot subpath 就是"循环单元 + 控制流 + 占比"三件套。
- **判断**：算法层面**最匹配**的候选。但**没有现成开箱工具**：要自接 BL path 编号 → SEQUITUR；前端 100~300 行、SEQUITUR 后端用现成库（jsdw/cpp-sequitur 推荐）。

### 8. NLR (Ketterlin 0.7)

```
数值序列（每行一个数；可以是 PC、地址、或任意标号）
  → NLR 算法（自底向上匹配 affine recurrence）
  → 输出嵌套 for 伪代码 + 仿射映射
```

- **「相连」**：NLR 的输出是**显式循环嵌套**——每个循环范围内的元素天然相连。
- **片段数量**：由识别成功的最外层循环个数决定（跑出来才知道）。
- **占比**：每个 for 循环的 `iteration_count × body_size`。
- **下游契合度**：非常高——直接给出"这一段 trace 是循环 X 的迭代 0..N"的解释。**前提是 trace 有 affine 结构**；非 affine 的不规则控制流会被当成 noise。
- **判断**：当 benchmark 是规则数值核（matmul、stencil、polybench 类）时**接近完美匹配**；不规则负载（解释器、字符串处理、SAT solver）失效。配合 PLR（候选 #9）可扩到 polynomial 归纳。
- **注意**：NLR 默认处理*数值序列*（如内存地址）；要喂 PC 流需要把每个 BB 映射到一个数（如 BB 起始 PC）；这一步是 < 50 行 Python 胶水。

### 9. PLR (Ketterlin IMPACT 2025)

NLR 的扩展，识别 polynomial（≥2 次）归纳。流程同 NLR。新出工具，**未确认是否已公开发布二进制/源码**——发布在 IMPACT workshop 论文的 PDF 内，需向作者邮件询问。如可获得，对带数据依赖型循环索引（A[i*j]、A[i*i+j]）类负载提升明显。

### 10. Exana

```
ELF (x86_64) + Pin 3.7 → 运行时识别 LCCT
  → 输出 Loop-Call Context Tree（含每个 loop 的 entry/exit PC、嵌套关系、迭代次数）
  + 内存访问模式 + cache 模拟（可选）
```

- **「相连」**：loop body 内部 BB 通过 loop-edge 相连，外加 call context 路径。
- **片段数量**：等于动态识别出的 loop 数（含嵌套）。
- **占比**：每个 loop node 的 `self_instr_count + nested_instr_count`。
- **下游契合度**：高——LCCT 是"循环单元"概念的工程实现，可逐 loop 抽出 PC 段做 DAG 分析。
- **判断**：x86_64 only，**不能直接用于 RISC-V**。但其算法（IEICE 2014 论文里详述的 loop entry/exit marker + on-the-fly 嵌套追踪）可以移植——Sato 把"如何在动态 trace 里抓 loop 边界"讲得很透，移植到 spike trace 上估计 200~500 行。

### 11. DynamoRIO 自定义 trace API + NET

```
DynamoRIO client → 注册 dr_register_trace_event → NET-style 计数器
  → 当某 trace head 计数过阈值，DR 内部已 form 一个 trace（按 BB 顺序拼接）
  → 在 client 里 dump 该 trace 的 PC 序列 + 频次
```

- **「相连」**：trace = 一串 fall-through / branch-taken 的 BB 顺序拼接，全部相连；DR 自动做 tail duplication。
- **片段数量**：由 NET 阈值（默认~50）决定，自动；可调。
- **占比**：每 trace 的执行次数 × 长度。
- **下游契合度**：trace 即"线性 BB 序列"，最适合 DAG 分析；trace 之间通过 trace exit 链接（DR 暴露这些 link）。
- **判断**：工程上**最 robust** 的现成路径，前提是能在目标 ISA 上跑 DR。**RISC-V 支持仍在 bring-up 阶段（DynamoRIO RISC-V port 进展见仓库 issues），生产可用度需先验证**；x86/ARM 完美。

### 12. DCFG

```
Intel SDE → record program execution → DCFG 文件（XML）
  含: BB 集 + 每条 dynamic edge + 每条 edge 的执行计数
```

- **「相连」**：DCFG 即整个动态可达控制流图；"相连"=有 dynamic edge 连接。
- **片段数量**：DCFG 是单图，要"切片段"需要在图上跑 SCC / community detection（自写）。
- **占比**：edge / node 的 count 直接给。
- **下游契合度**：图给得很完整，但**不直接给"片段"**——需要后处理（SCC 找循环 + 频次门限砍掉冷边）。
- **判断**：作为"中间表示"非常好，但要靠下游算法切片段。Intel SDE 平台限制（x86 only）。

### 13. CLIPPER (iterative pattern mining) / SPMF 替代

```
事件序列（每个 event 是一个符号，如 BB id）
  → 频繁子序列挖掘（CloSpan / PrefixSpan / CLIPPER）
  → 输出 (pattern, support, occurrence_list)
```

- **「相连」**：迭代模式*不要求*邻接（默认 gap-allowed），所以"相连"由用户额外加约束（如 max_gap=0）。
- **片段数量**：由 min_support 阈值控制。
- **占比**：每 pattern 的 support × length。
- **下游契合度**：低——挖出的是抽象模式，反向定位回 trace 还要再 scan；且默认带 gap，与"BB 相连"默认违背。
- **判断**：作为**算法借鉴池**有用（SPMF 的 PrefixSpan / SPADE 实现成熟），但直接当"片段提取器"用费力不讨好，除非你愿意配置 max_gap=0 + min_length 限制。

### 14. DiffTrace

```
ParLoT 压缩 trace → NLR（候选 #8）摘要循环 → concept lattice → 层次聚类 → 标 outlier
```

DiffTrace 内部组合了 NLR 来做 loop summarization。**它的副产品**——摘要后的 loop list + 频次——其实正是工程目标想要的输出。但 DiffTrace 公开源码状态 [需核实]，且面向 HPC MPI 应用，单线程负载是否退化也不清楚。

- **判断**：**可作为"组合方案"的现成参考**——它的算法栈（NLR + 层次聚类）正是 Q3 推荐组合的现成实现。如能拿到源码，是 Q3 组合的近似一站式解。

### 15. 变长时序 motif (grammar-induction)

时序数据挖掘领域常用 SEQUITUR / Sequitur 衍生算法做变长 motif 发现，与候选 #7 同源算法栈；区别是面向数值 / 离散符号时序，已积累不少 Python 库。**对程序 trace 的应用基本就是 #7 WPP**，没有独立增益。

### 16. Interprocedural Path Profiling

```
动态 trace + 调用上下文
  → 跨过程 CFG（含 call/return edge）
  → 路径编号扩展自 Ball-Larus，但允许跨函数边
  → top-K 跨过程路径
```

- **「相连」**：跨过程 CFG 上的连续路径，允许跨函数边。
- **片段数量**：由上下文深度、路径长度上限或观测到的路径集合决定。
- **占比**：路径计数 / 硬件事件计数。
- **下游契合度**：可直接给路径级分析。**问题**：公开工具链不现成，要按 Melski-Reps CC 1999 的算法重写。
- **判断**：作为 BL 的"跨函数版"概念上重要，但工程上没有现成实现。主要价值是当 CRC32 那种"主体跨多个函数"的 case 出现时，提示在路径编号阶段要保留 call/ret 信息。

### 17. PELT / ruptures（changepoint detection）

```
trace 上的窗口级特征序列（BBV、分支密度、IPC proxy）
  → ruptures.PELT（带 BIC 风格惩罚项）
  → 输出 changepoint 位置列表 + 段间分组
```

- **「相连」**：相邻窗口的统计相似性，**不是 BB 图结构连通**。
- **片段数量**：由 `pen` 自动选，或显式 `n_bkps`。
- **占比**：窗口长度 / 指令占比。
- **下游契合度**：**不能单独满足"BB 子图片段"要求**——只能做时序边界的辅助，与 NLR / WPP 联合用。
- **判断**：维护状态在所有候选中最好（v1.1.10, 2025-09），适合做"边界对齐"层；和 SimPoint 形成对照——SimPoint 是"先聚类、再代表点"，PELT 是"先找断点、再分段"，两者的输出可以互验。

---

## Q3：现成组合最接近方案与工程量评估

**没有完全现成的一体化工具**——最接近的有 4 条路径，按工程量排序：

### 路径 A：SimPoint VLI（小 interval 版） + 后处理

```
spike --log-commits
  → [脚本 1，~150 行] 切 backward-branch 边界，生成 VLI 列表 + per-VLI BBV
  → simpoint 二进制（现成）
  → [脚本 2，~80 行] 把 cluster 反向映射到 BB 集合 + 转移频率（从原 trace 二次扫描）
  → 片段集 = {代表 VLI 的 BB 集合 + 内部 edge 频率}
```

- 胶水量：**100-500 行**
- 自研瓶颈：脚本 1（VLI 切分）和脚本 2（BB 邻接重建）；都是直接编程，无算法风险
- 整体难度：**小改**
- 优势：完全离线、确定性、SimPoint 算法本身已被 ASPLOS 引用千次以上；
- 劣势：cluster 内部 BB 转移关系是后验重建的，"相连"是事后保证，不是模型自带

### 路径 B：BL 路径编号 + LLVM 编译时插桩

```
源码 / IR → LLVM 加 BL PathProfiling pass → 运行时统计每 path frequency
  → [脚本 1，~50 行] top-K path 提取 + 累计覆盖率
  → [脚本 2，~100 行] 把每 path 反查回 BB 序列（PathNumbering 是确定性可逆）
  → 片段集 = {top-K path 的 BB 序列 + path frequency}
```

- 胶水量：**< 100 行**
- 自研瓶颈：LLVM PathProfiling pass 已从主线移除，需要从历史版本恢复或用 lac-dcc/Nisse fork；这一步 0~100 行重建
- 整体难度：**小改**
- 优势：每个片段就是"一条 acyclic 控制流"，BB 严格相连，DAG 分析直入；
- 劣势：要求源码可用（不能纯 binary）；对跨 backedge 的循环单元需要把多条 path 按 loop header 聚合（再加 50 行）；与工程"不跑程序就预估全程 IPC"的"不跑"冲突——BL profiling 仍要跑

### 路径 C：WPP 复刻（BL path → SEQUITUR）

```
spike trace
  → [脚本 1，~150 行] 静态构建 CFG，对每条动态 acyclic path 做 BL 编号
  → [脚本 2，~50 行] 把 path-id 流喂给 SEQUITUR（用 jsdw/cpp-sequitur）
  → [脚本 3，~150 行] 在文法树上找 hot rule（按 length × usage）
  → [脚本 4，~80 行] 文法规则反向解码成 BB 序列
  → 片段集 = {hot subpath + 占比}
```

- 胶水量：**100-500 行**（接近上限）
- 自研瓶颈：脚本 1 的静态 CFG 构建（RISC-V 反汇编 → 基本块），其他都是粘合
- 整体难度：**中改**
- 优势：算法上**最贴**用户工程目标——"相连 BB 序列 + 占比 + 数量少"是 WPP 的天然输出
- 劣势：没有现成 WPP 一站式工具，需要自己接管道；SEQUITUR 在长 path-id 流上的 grammar 大小可能爆炸（10M 指令的 trace 估计产 1M~5M 个 path-id），需要内存 / 流式 SEQUITUR

### 路径 D：NLR/PLR + spike trace adapter

```
spike trace
  → [脚本 1，~50 行] 抽 backward-branch 序列 / BB 起始 PC 序列
  → nlr 二进制（现成 C 程序）/ plr （新工具）
  → [脚本 2，~100 行] 把 NLR 输出的 for-nest 反向映射到 BB 范围 + 迭代数
  → 片段集 = {每个 loop nest 的 PC range + iteration count}
```

- 胶水量：**< 100 行**
- 自研瓶颈：无算法瓶颈；如果 trace 不是 affine 的，NLR 失败比例高，需要 fallback 到 SEQUITUR（变成路径 C 的 hybrid）
- 整体难度：**小改**
- 优势：当 benchmark 是规则计算核（embench 中的 matmul / NN / fft 类）时一击即中
- 劣势：embench 全集中相当一部分（解释器型、字符串型）NLR 失败，需要 fallback

---

### 推荐 Top-3

按"工程目标契合 × 工程量"综合：

**Top 1：路径 A（SimPoint VLI 小 interval + 后处理）**——最快出结果。SimPoint 工具链已在 RISC-V/spike 圈用 qpoints 跑通；把 default 100M interval 改成 10K~100K 即解决"颗粒度太粗"的 SimPoint 老问题；后处理脚本短。**风险点是 SimPoint 在 100K 级 interval 上 BIC 是否还能稳健选 k**——按 SimPoint 3.0 论文里的实验，10K~1M 区间是 well-studied 的，应可行。

**Top 2：路径 D（NLR + adapter）**——如果你的目标 workload 主要是 embench / SPEC 里规则数值核，NLR 几乎免费给出最干净的"循环单元"结果。算法成熟（CGO 2008），工具单文件 C99，调通 < 1 天。**风险点是 affine 假设**，对不规则负载会"无话可说"。

**Top 3：路径 C（WPP 复刻：BL + SEQUITUR）**——算法层面最对路（hot subpath ≡ 工程目标），但工程量大 1 档，且 SEQUITUR grammar 爆炸风险需要测试。**只有当路径 A 的颗粒度精度不够 + 路径 D 在你 workload 上失效时才上**。

> 路径 B（LLVM BL）虽然漂亮，但和"基于 spike trace、不依赖 LLVM 重编译"的工程上下文冲突，所以不进 top-3。如果未来有意把 RISC-V 工具链统一到 LLVM，再回来考虑。

### 路径 E：NLR + PP/WPP + SEQUITUR + PELT 多算法组合

把多种算法做成分层 pipeline，而不是"四选一"，每层负责不同子问题：

| 步骤 | 现成工具 | 脚本量 | 自研瓶颈 |
| --- | --- | --- | --- |
| BB 序列标准化 | spike log + 解析 | < 100 行 | PC / BB ID 归一化 |
| 循环单元恢复 | NLR | < 100 行 | 解析 NLR 输出、映射回 BB 区间 |
| 热路径抽取 | PP / WPP 或 Ball-Larus | 100-300 行 | 热路径阈值、路径去重、路径计数汇总 |
| 残余边界清理 | ruptures.PELT | < 100 行 | 何时切、切完如何并回片段集 |
| 重复结构压缩 | SEQUITUR | < 100 行 | 规则展开、覆盖率统计 |
| 覆盖/冲突合并 | 自写 glue | 100-500 行 | 片段互斥、90% 覆盖、最少片段数 |

**判断**：路径 E 思想上漂亮——NLR 抓规则循环、WPP 抓不规则热路径、SEQUITUR 抓重复结构、PELT 校准边界。但**整体工程量等于路径 A + C + D 之和**，做不到"快速上手"。**适合的场景**是 workload 谱很广（既有规则数值核又有不规则控制流）且初期不知道哪条路径占主导时，先 pipeline 跑一遍看每层的产出占比，再做剪枝。**不适合**初次原型——首选还是路径 A 或 D。

---

## 关键判断

- **「相连」**最严格的定义来自 BL/WPP（每条 path 内 BB 是 fall-through + branch-taken 拓扑相连）；NLR 给出的是"同一循环 body 内的 BB 集合"——也算相连但更松；PELT 的"相连"完全不是图意义上的，只是时序意义上的相邻段，因此它只能做边界辅助。SimPoint 不显式建相连，需后处理重建。
- **片段数量自动**这一项，BL/WPP 用"top-K 覆盖率"控制，NLR 由数据本身决定，SimPoint 用 BIC，PELT 用 `pen` 自动选——后三者更"自动"。
- **工程量分布**：从全自研（< 100 行）到中等（500 行）都有现成路径覆盖，**没必要自研片段抽取算法**；自研投入应集中在"trace 格式适配 + 反向映射回 PC 范围"这两步胶水。
- **核心结论**：NLR 是规则数值核场景的最佳选择；SimPoint 系颗粒度需调小；WPP 算法层最贴目标但无现成工具；CLIPPER/SPMF 是算法借鉴池而非主选。
