# Embench 性能分析方法学

本文档定义了对 embench-iot 基准测试进行性能分析的标准方法，以 `matmult-int` 为示例贯穿全文。方法学分为三个层次：**源码分析**、**汇编热点分析**、**SimPoint 权重分析**。

---

## 1. 源码分析方法学

### 1.1 目标

从 C 源码层面理解：
- 算法复杂度与循环结构
- 数据访存模式（stride / random / streaming）
- 计算密集度（compute-bound vs memory-bound）
- 数据类型与运算类型（int mul / fp add / bitwise / branch-heavy）

### 1.2 分析步骤

#### Step 1: 识别 benchmark 入口与执行框架

Embench 的统一入口是 `bd/support/main.c`：

```
initialise_board()        ← 初始化 perf counter
initialise_benchmark()    ← 一次性数据初始化
warm_caches(WARMUP_HEAT)  ← cache 预热（默认 WARMUP_HEAT=1）
start_trigger()           ← 开始计数
result = benchmark()      ← 被测代码
stop_trigger()            ← 停止计数，输出 cycles/instret/IPC
verify_benchmark(result)  ← 验证正确性
```

关键参数：
- `LOCAL_SCALE_FACTOR`：benchmark 内部定义，控制重复次数
- `GLOBAL_SCALE_FACTOR`：构建时通过 `gsf` 参数传入（默认 1）
- 总迭代 = `lsf × gsf`

#### Step 2: 定位核心计算函数

在 benchmark 源码中找到被 `benchmark()` 调用的核心函数。通常遵循：

```
benchmark() → benchmark_body(lsf, gsf)
    └→ 外层 lsf × gsf 循环
        └→ 核心计算函数（如 Multiply, crc32, md5_process 等）
```

#### Step 3: 分析循环嵌套与复杂度

以 matmult-int 为例：

```c
// matmult-int.c — 核心函数 Multiply()
void Multiply(matrix A, matrix B, matrix Res) {
    for (Outer = 0; Outer < 20; Outer++)       // L1: 行遍历
        for (Inner = 0; Inner < 20; Inner++) {  // L2: 列遍历
            Res[Outer][Inner] = 0;
            for (Index = 0; Index < 20; Index++)// L3: 点积累加
                Res[Outer][Inner] += A[Outer][Index] * B[Index][Inner];
        }
}
```

| 属性 | 值 |
|------|------|
| 循环深度 | 3 层 |
| 总迭代（L3） | 20 × 20 × 20 = 8,000 |
| 每次 Multiply 调用总乘法数 | 8,000 |
| lsf=39, gsf=1 时总 Multiply 调用 | 39（测量区间内） |
| warmup 额外调用 | 1（lsf=1, gsf=1） |
| 算法复杂度 | O(N³), N=20 |

#### Step 4: 分析访存模式

```
A[Outer][Index]  — Outer 在 L1 不变，Index 在 L3 连续 → row-major 顺序访问，stride=8B
B[Index][Inner]  — Inner 在 L2 不变，Index 在 L3 连续 → column-major 访问，stride=160B (20×8B)
Res[Outer][Inner] — L3 内不变，反复读写同一地址 → 单地址热点
```

**访存特征总结**：
- A 矩阵：**顺序访问**（cache 友好）
- B 矩阵：**列访问 stride=160B**（cache line 跨越，但 20×20×8B=3.2KB 整个矩阵可驻 L1）
- 数据总量：3 个 20×20 long 矩阵 = 3 × 3200B = 9.6KB → **完全驻 L1D**（典型 32-64KB）
- 分类：**compute-bound**（数据全在 L1，瓶颈在 ALU/MUL 吞吐）

#### Step 5: 分析计算特征

| 指令类型 | 每次 L3 迭代 | 比例 |
|----------|-------------|------|
| ld（load） | 2 | 25% |
| mul（整数乘法） | 1 | 12.5% |
| add（累加） | 1 | 12.5% |
| sd（store） | 1 | 12.5% |
| addi（地址递增） | 2 | 25% |
| bne（循环控制） | 1 | 12.5% |

**关键依赖链**：`ld A → ld B → mul → add → sd`，其中 mul 依赖两个 ld 的结果，add 依赖 mul 和上一次的累加值。

#### Step 6: 输出源码分析摘要

```
Benchmark:      matmult-int
算法:           20×20 矩阵乘法 (long)
复杂度:         O(N³), N=20
数据量:         9.6KB (全驻 L1D)
计算类型:       int ld/mul/add 密集
访存模式:       A 顺序, B stride-160B, Res 单点
瓶颈预测:       compute-bound (MUL throughput + ld→mul forwarding)
分支:           3 层循环控制，内层 L3 高度可预测 (trip count=20)
```

---

## 2. 汇编热点分析方法学

### 2.1 目标

从编译产物和动态执行 trace 层面理解：
- 编译器优化效果（循环展开、寄存器分配、指令选择）
- 实际执行的指令混合比
- 热点代码段占总执行的比例
- 微架构瓶颈点（依赖链长度、功能单元压力）

### 2.2 分析步骤

#### Step 1: 反汇编核心函数

```bash
riscv64-unknown-elf-objdump -d bin_spike/embench/<bench> | grep -A 100 '<核心函数>:'
```

matmult-int 的 `Multiply` 函数反汇编（-O2 编译）：

```asm
# === Multiply 函数 (0x1042a - 0x1047a) ===
# 编译器将 3 层循环优化为紧凑的寄存器分配方案

# --- 内层循环 L3 (Index loop, 0x1044e - 0x10462) --- 热点 ★★★
1044e:  ld    a4, 0(a5)           # a4 = A[Outer][Index]     ← A 元素加载
10450:  ld    a0, 0(a2)           # a0 = B[Index][Inner]     ← B 元素加载
10452:  addi  a5, a5, 8           # a5 += 8                  ← A 指针前进 (stride=8)
10454:  addi  a2, a2, 160         # a2 += 160                ← B 指针前进 (stride=160)
10458:  mul   a4, a4, a0          # a4 = A[i][k] * B[k][j]  ← 核心乘法
1045c:  add   a3, a3, a4          # a3 += a4                 ← 累加到 Res
1045e:  sd    a3, 0(a6)           # Res[i][j] = a3           ← 写回结果
10462:  bne   a5, a7, 0x1044e     # if (a5 != end) goto loop ← 循环控制

# --- 中间循环 L2 (Inner loop, 0x10444 - 0x1046a) ---
10444:  sd    zero, 0(a6)         # Res[i][j] = 0            ← 清零
10448:  mv    a5, t3              # a5 = &A[Outer][0]        ← 重置 A 指针
1044a:  mv    a2, t1              # a2 = &B[0][Inner]        ← 重置 B 指针
1044c:  li    a3, 0               # a3 = 0                   ← 累加器清零
# ... L3 body ...
10466:  addi  t1, t1, 8           # Inner++  (B 列指针 +8)
10468:  addi  a6, a6, 8           # Res 列指针 +8
1046a:  bne   t1, t4, 0x10444     # if (Inner != 20) continue

# --- 外层循环 L1 (Outer loop, 0x1043c - 0x10476) ---
1043c:  mv    t1, a1              # 重置 B 基地址
1043e:  mv    a6, t5              # 重置 Res 行基地址
# ... L2 body ...
1046e:  addi  a7, a5, 160         # 更新 A 行结束地址
10472:  addi  t5, t5, 160         # Res 行基地址 +160
10476:  bne   a7, t6, 0x1043c     # if (Outer != 20) continue
```

**编译器优化观察**：
- 使用指针递增代替数组索引计算（避免了 `slli` + `add` 的地址计算）
- B 矩阵 stride=160B 直接编码为 `addi a2, a2, 160`
- 累加器 `a3` 全程在寄存器中，每次 L3 迭代都 `sd` 写回（非最优，但保证了 memory consistency）
- 无循环展开（-O2 对 trip count=20 的小循环未展开）

#### Step 2: 通过 spike 获取动态执行 profile

```bash
SPIKE_BIN=$HOME/workspace/riscv-spike/bin/spike
SPIKE_PK=$HOME/workspace/riscv-pk/build/pk
ISA=rv64gcv_zba_zbb_zbs_zfh_zfhmin_zfa_zicond_zcb_zicboz_zicbom_zicbop_zicntr_zicsr_zifencei_zimop_zkt_zvbb_zvfhmin_zvkt_zihintpause_zihintntl

# 1. 运行并获取 perf 数据
$SPIKE_BIN --isa=$ISA $SPIKE_PK bin_spike/embench/<bench>

# 2. 获取完整指令 trace（大 benchmark 慎用，会很大）
$SPIKE_BIN --log-commits --isa=$ISA $SPIKE_PK bin_spike/embench/<bench> 2>/tmp/trace.log

# 3. 生成 PC 热度直方图
grep '0x000000000001' /tmp/trace.log | awk '{print $4}' | sort | uniq -c | sort -rn > /tmp/pc_hist.txt
```

#### Step 3: 分析执行热度分布

matmult-int 动态执行 profile：

| 区域 | PC 范围 | 每个 PC 执行次数 | 指令数 | 总执行次数 | 占比 |
|------|---------|-----------------|--------|-----------|------|
| **L3 内层循环** | 0x1044e - 0x10462 | 320,000 | 8 | **2,560,000** | **71.7%** |
| L2 中间循环 overhead | 0x10444 - 0x1046a | 16,000 | 7 | 112,000 | 3.1% |
| memcpy(ArrayA) | 0x104d6 - 0x104f6 | 4,000 | 12 | 48,000 | 1.3% |
| memcpy(ArrayB) | 0x10500 - 0x1051c | 4,000 | 12 | 48,000 | 1.3% |
| L1 外层循环 overhead | 0x1043c - 0x10476 | 800 | 6 | 4,800 | 0.1% |
| benchmark_body 循环 | 0x104ce - 0x10532 | 40 | ~30 | ~1,200 | 0.03% |
| **User-space 总计** | — | — | — | **2,796,811** | **78.4%** |
| pk/bbl 开销 | — | — | — | 772,701 | 21.6% |
| **总计** | — | — | — | **3,569,512** | 100% |

**关键发现**：
- 内层循环 8 条指令占全部执行的 **71.7%** → 这是唯一值得优化的热点
- pk/bbl 系统开销占 21.6%（Linux 实机上 perf_event_open 开销更低）
- 320,000 = 8,000 (20³) × 40 (lsf=39 + warmup=1) → 执行次数与源码分析完全吻合

#### Step 4: 分析内层循环微架构特征

```
Cycle  Insn
  0    ld    a4, 0(a5)       # L1 hit, 假设 2-cycle latency
  0    ld    a0, 0(a2)       # 与上条独立，可并行发射
  1    addi  a5, a5, 8       # 与 ld a4 独立
  1    addi  a2, a2, 160     # 与 ld a0 独立
  2    mul   a4, a4, a0      # 依赖 ld a4 + ld a0，必须等 load 完成
  ?    add   a3, a3, a4      # 依赖 mul（mul latency 通常 3-4 cycle）
  ?    sd    a3, 0(a6)       # 依赖 add
  ?    bne   a5, a7, loop    # 依赖 addi a5（早已 ready）
```

**依赖链分析**：
- **关键路径**: `ld → mul → add → (sd)` ≈ 2 + 3~4 + 1 = 6~7 cycles（假设 L1 hit）
- **次关键路径**: `add(iter N) → add(iter N+1)` 通过 a3 累加器形成跨迭代 RAW 依赖
- **循环携带依赖**: `a3`（累加器）、`a5`/`a2`（地址指针，但 addi 1-cycle 不是瓶颈）
- **ILP**: 两个 ld 可并行，两个 addi 可并行，但 mul/add/sd 是串行链
- **预计 IPC**: 8 insn / 6~7 cycles ≈ 1.14~1.33（理论上限）

#### Step 5: 对比 spike 基准数据

```
Spike 结果: cycles=2,696,483  instret=2,696,486  IPC=1.0000
```

Spike 是顺序执行（IPC≡1.0），因此 spike 数据作为**功能验证基准**而非性能参考。真实 OoO 核上预期 IPC > 1.0（内层循环 ld/addi 可并行）。

#### Step 6: 输出汇编分析摘要

```
Benchmark:          matmult-int
编译优化:           -O2, 指针递增, 无循环展开
内层循环指令数:     8 条
内层循环执行占比:   71.7%
内层循环指令混合:   2×ld, 1×mul, 1×add, 1×sd, 2×addi, 1×bne
关键依赖链:         ld→mul→add (6-7 cycles)
循环携带依赖:       a3 累加器 (add→add cross-iteration)
预计 IPC 上界:      ~1.3 (OoO core, L1 hit)
```

---

## 3. SimPoint 权重分析方法学

### 3.1 概念

SimPoint 通过 **Basic Block Vector (BBV)** 将程序执行划分为若干 **phase**（时间片），每个 phase 内的执行行为相似。通过聚类找到**代表性 interval**，只模拟这些 interval 即可估算全程性能，大幅缩减仿真时间。

### 3.2 为什么 Embench 需要 SimPoint

| 场景 | 说明 |
|------|------|
| RTL 仿真 | 仿真全程 ~3M 指令耗时大，SimPoint 可只仿真代表性片段 |
| 多 benchmark 比较 | 不同 benchmark 的 phase 结构不同，SimPoint 给出可比较的权重 |
| 微架构设计探索 | 快速评估设计变更对不同 phase 的影响 |

### 3.3 分析步骤

#### Step 1: 生成 BBV (Basic Block Vector)

BBV 记录每个 interval（通常 1M 或 100K 指令）内各 basic block 的执行频率。

**方法 A：通过 spike log-commits 离线生成**

```bash
# 1. 获取完整 PC trace
$SPIKE_BIN --log-commits --isa=$ISA $SPIKE_PK bin_spike/embench/<bench> 2>/tmp/trace.log

# 2. 用脚本将 PC trace 转为 BBV 格式
python3 scripts/trace_to_bbv.py /tmp/trace.log \
    --interval 100000 \
    --output /tmp/<bench>.bbv
```

**方法 B：通过 spike checkpoint + 自定义插桩**

对于大型 benchmark，可在 spike 中添加 BBV 收集插桩（修改 `riscv-isa-sim` 的 `execute.cc`），在每个 interval 边界输出 BBV。

#### Step 2: 运行 SimPoint 聚类

```bash
# SimPoint 工具（需要安装 SimPoint 3.2）
simpoint -loadFVFile /tmp/<bench>.bbv \
         -maxK 10 \
         -saveSimpoints /tmp/<bench>.simpoints \
         -saveSimpointWeights /tmp/<bench>.weights
```

输出：
- `<bench>.simpoints`：每行一个代表性 interval 编号
- `<bench>.weights`：每行一个权重（占总执行的比例）

#### Step 3: 解读 SimPoint 结果

以 matmult-int 为例（预期结果）：

matmult-int 总指令约 3.5M，若 interval=100K，则约 35 个 interval。由于 matmult-int 的行为非常规律（反复执行相同的矩阵乘法），预期：

```
SimPoint 预期:
- 1-2 个 cluster 即可覆盖 >95% 的执行
- 主 cluster: 纯 Multiply 内层循环（权重 ~90%）
- 次 cluster: benchmark_body 的 memcpy + 循环控制（权重 ~8%）
- 初始化 cluster: initialise_benchmark + pk startup（权重 ~2%）
```

**解读维度**：
- **cluster 数量**: 反映程序行为的多样性（matmult 很少，picojpeg 会很多）
- **主 cluster 权重**: 反映核心计算的集中度
- **phase 切换频率**: 反映程序的时间局部性

#### Step 4: 基于 SimPoint 的快速仿真

```bash
# 只仿真代表性 interval
for interval in $(cat /tmp/<bench>.simpoints | awk '{print $1}'); do
    # 从对应的 checkpoint 恢复，仿真 100K 指令
    spike --restore-checkpoint checkpoints/<bench>_${interval}.zstd \
          --max-instructions 100000 ...
done
```

#### Step 5: 加权汇总性能数据

```python
# weighted_ipc = sum(ipc_i * weight_i) for each simpoint interval
total_cycles = sum(cycles[i] * weight[i] for i in simpoints)
total_instret = sum(instret[i] * weight[i] for i in simpoints)
estimated_ipc = total_instret / total_cycles
```

---

## 4. 综合分析模板

对每个 embench benchmark，按以下模板输出分析结果：

```markdown
## <benchmark-name>

### 源码分析
- **算法**: <一句话描述>
- **复杂度**: <O(?)>
- **数据量**: <总 working set>
- **计算类型**: <int/fp, 运算种类>
- **访存模式**: <sequential/stride/random/mixed>
- **瓶颈预测**: <compute-bound / memory-bound / branch-bound>

### 汇编热点
- **内层循环指令数**: <N 条>
- **内层循环占比**: <X%>
- **指令混合**: <ld:N, mul:N, add:N, ...>
- **关键依赖链**: <insn1 → insn2 → insn3, N cycles>
- **循环携带依赖**: <描述>
- **预计 IPC**: <range>

### SimPoint 权重
- **Cluster 数**: <N>
- **主 cluster 权重**: <X%>
- **主 cluster 特征**: <描述>
- **Phase 多样性**: <low/medium/high>

### 微架构关注点
- <对 OoO 调度的具体影响>
- <对 cache 的具体影响>
- <对分支预测的具体影响>
```

---

## 5. Embench 基准测试列表

| Benchmark | 类型 | 预期瓶颈 |
|-----------|------|----------|
| aha-mont64 | Montgomery 乘法 | compute (int mul/div) |
| crc32 | CRC 校验 | compute (shift/xor, table lookup) |
| depthconv | 深度卷积 | compute (int mac) + memory |
| edn | 信号处理滤波 | compute (int mul/add) |
| huffbench | Huffman 编解码 | branch-heavy |
| **matmult-int** | **矩阵乘法** | **compute (int mul)** |
| md5sum | MD5 哈希 | compute (shift/rotate/xor) |
| nettle-aes | AES 加密 | compute (table lookup) |
| nettle-sha256 | SHA256 哈希 | compute (shift/rotate) |
| nsichneu | 状态机模拟 | branch-heavy |
| picojpeg | JPEG 解码 | mixed (compute + memory) |
| qrduino | QR 码生成 | mixed |
| sglib-combined | 数据结构操作 | memory (pointer chase) |
| slre | 正则匹配 | branch-heavy |
| statemate | 状态机 | branch-heavy |
| tarfind | 归档搜索 | memory + branch |
| ud | 表查找运算 | memory (table lookup) |
| wikisort | 排序算法 | memory (random access) + branch |
| xgboost | 决策树推理 | branch + memory |

---

## 6. 工具链参考

```bash
# 编译 embench (spike 版本)
./uarch build embench spike

# 编译 embench (linux 交叉编译)
./uarch build embench linux

# 反汇编
riscv64-unknown-elf-objdump -d bin_spike/embench/<bench>

# Spike 运行
SPIKE_BIN=$HOME/workspace/riscv-spike/bin/spike
SPIKE_PK=$HOME/workspace/riscv-pk/build/pk
ISA=rv64gcv_zba_zbb_zbs_zfh_zfhmin_zfa_zicond_zcb_zicboz_zicbom_zicbop_zicntr_zicsr_zifencei_zimop_zkt_zvbb_zvfhmin_zvkt_zihintpause_zihintntl

# 功能运行 + perf 输出
$SPIKE_BIN --isa=$ISA $SPIKE_PK bin_spike/embench/<bench>

# 完整指令 trace
$SPIKE_BIN --log-commits --isa=$ISA $SPIKE_PK bin_spike/embench/<bench> 2>/tmp/trace.log

# PC 热度直方图
grep '0x000000000001' /tmp/trace.log | awk '{print $4}' | sort | uniq -c | sort -rn

# 反汇编 + trace 交叉对照
riscv64-unknown-elf-objdump -d bin_spike/embench/<bench> | grep '<hot_addr>:'
```
