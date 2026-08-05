# 依赖链 DAG 提取方法学（极简总览）

> 从动态执行 trace 中提取核心循环的指令依赖链 DAG，用于 IPC 上界分析。
> 本文只覆盖 4 步主干流程；具体工具选择、执行节奏、历史脉络见同目录其他文档。

---

## 目标与边界

```
INPUT:  ELF + 动态 trace + uarch policy 配置
OUTPUT: 循环总指令数 + 候选关键环（链式格式，按政策分组）
```

不在本方法学范围内（这三步与微架构强相关，由人工完成）：
- IPC 上界数值计算
- 瓶颈归因（哪条边绑定，怎么放松）
- 与实测 IPC 的验证比对

---

## 4 步主干流程

```
┌──────────────────────────────────────────────────────────────┐
│ INPUT:  ELF + dynamic trace + uarch policy config            │
└──────────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────────────────────┐
│ [1] Trace Profiler                                           │
│      In:  trace (PC sequence)                                │
│      Op:  从 trace 提取"相连的 hot BB 片段集合"              │
│      Out: 一组片段 = {(BB 范围, 占比, 内部转移关系)}         │
│      工具选择见 → tooling-survey.md                          │
│      执行计划见 → execution-plan.md                          │
└──────────────────────────────────────────────────────────────┘
        │ (每个片段)
        ▼
┌──────────────────────────────────────────────────────────────┐
│ [2] Hot Section Extractor                                    │
│      In:  ELF + 片段 PC 范围                                 │
│      Op:  反汇编 + 抽取一个 iter 的指令序列                  │
│      Out: 指令序列 + 该 iter 的总指令数 N                    │
└──────────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────────────────────┐
│ [3] DAG Builder                                              │
│      In:  指令序列 + uarch policy 配置                       │
│      Op:  连节点 + 三类 typed edges                          │
│           ─►  data flow      (RAW / same-addr mem RAW)       │
│           ═►  ordering policy (inorder load / fence / TSO)   │
│           ↺   loop-carried   (跨迭代 reg / mem 写读)         │
│      Out: 节点列表 + typed edge 列表                         │
└──────────────────────────────────────────────────────────────┘
        │
        ▼
┌──────────────────────────────────────────────────────────────┐
│ [4] Critical Cycle Finder                                    │
│      In:  DAG                                                │
│      Op:  枚举跨迭代环 + 按政策分组                          │
│      Out: 候选关键环（链式格式）                             │
└──────────────────────────────────────────────────────────────┘
```

---

## 输出格式（链式表达）

每个片段最终输出 3 块：

```
循环总指令数: N insn/iter

候选关键环:
  环 X (base):      A →(edge_type) B → C → ... → A
  环 Y (policy=P):  A → ... → B
```

边类型符号：
- `→(reg fwd)`：寄存器转发
- `→(sfwd)`：store-forward
- `→(load_use)`：load 数据 ready
- `→(issue order)`：ordering policy 强制的边

环按政策分组：
- **base**：仅由 data flow 边构成的环
- **policy=...**：含至少一条 ordering policy 边的环（每种政策一组）

---

## 三类 hazard 与 DAG 边的对应

| 边的来源 | 边在哪两个节点之间 | 由什么决定 | 例子 |
|---------|------------------|-----------|------|
| Data flow | producer → consumer | 程序的数据语义 | reg RAW、same-addr mem RAW |
| Ordering policy | 两个本不相关的 op | ISA / uarch 政策 | inorder load issue、fence、TSO |
| Resource | 两个争资源的 op | 微架构资源限制 | 单 mul 单元、LSU port |

注：control hazard（branch mispredict）**不进 DAG**，作为 DAG 之外的"乘性 IPC tax"单独处理。

---

## 关联文档（按使用场景）

| 想做什么 | 看哪个 |
|---------|-------|
| 选 [1] Trace Profiler 用什么工具 | `tooling-survey.md` |
| 知道当前 milestone 进度 | `execution-plan.md` |
| 跑工具时翻历史脉络伴读 | `history.md` |
| embench 综合分析方法 | `../embench-analysis-methodology.md` |
| 看一个具体 benchmark 的应用结果 | `../embench/<bench>.md` |
