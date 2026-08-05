# nsichneu 性能分析

## 1. 源码分析

### 1.1 基本信息
- **源文件**: `thirdparty/embench-iot/src/nsichneu/libnsichneu.c`
- **算法描述**: Petri 网（Place/Transition Net）模拟器，由 Sea2CHaRy 工具从 NSicherNeu.sea 自动生成
- **LOCAL_SCALE_FACTOR**: 1232
- **数据类型**: `volatile long`（64-bit signed integer）, `volatile int`

### 1.2 调用链
```
benchmark() → benchmark_body(lsf=1232, gsf=1)
  └→ 循环 1232×1 = 1232 次
      ├→ P1_is_marked = 3; P2_is_marked = 5; P3_is_marked = 0;  (重置状态)
      └→ 126 个 Transition 检查（全部展开为 if-else 链）
          ├→ T1: 6 个排列（P1 的 3 元素取 3 的排列）
          ├→ T2: 60 个排列（P2 的 5 元素取 4 的排列）
          └→ T3: 60 个排列（P2 的 5 元素取 4 的排列）
```

### 1.3 核心计算逻辑

nsichneu 没有传统的循环热点。整个 `benchmark_body` 是一个巨大的 if-else 链（~4500 行 C 代码），模拟 Petri 网中 3 个 Place（P1/P2/P3）和 3 个 Transition（T1/T2/T3）的所有可能 firing 规则。

每个 Transition 检查的模式如下：

```c
/* Transition T1, Permutation (0,1,2) */
if ((P1_is_marked >= 3) &&                       // guard 1: 足够 token
    (P3_is_marked + 3 <= 6) &&                    // guard 2: 输出不溢出
    (P1_marking_member_0[1] == P1_marking_member_0[2]))  // guard 3: 值相等
{
    x = P1_marking_member_0[0];
    y = P1_marking_member_0[1];
    if (x < y) {                                  // transition condition
        P1_is_marked -= 3;                        // demark input
        z = x - y;                                // preaction
        P3_marking_member_0[P3_is_marked + 0] = x;
        P3_marking_member_0[P3_is_marked + 1] = y;
        P3_marking_member_0[P3_is_marked + 2] = z;
        P3_is_marked += 3;                        // mark output
    }
}
```

### 1.4 循环结构

| 循环层 | 变量 | Trip Count | 说明 |
|--------|------|-----------|------|
| benchmark_body 外层 | lsf_cnt | 1232 | LOCAL_SCALE_FACTOR |
| benchmark_body 内层 | gsf_cnt | 1 | GLOBAL_SCALE_FACTOR |
| **无内层循环** | — | — | **126 个 if-else 块顺序执行，无嵌套循环** |

### 1.5 访存模式

| 变量 | 类型 | 大小 | 访问方式 | 说明 |
|------|------|------|---------|------|
| P1_is_marked | volatile int | 4B | 频繁 lw/sw | 每次迭代读 ~12 次 |
| P2_is_marked | volatile int | 4B | 频繁 lw/sw | 每次迭代读 ~120 次 |
| P3_is_marked | volatile int | 4B | 频繁 lw/sw | 每次迭代读 ~126 次 |
| P1_marking_member_0[3] | volatile long | 24B | ld 随机索引 | 6 个排列各读 2-3 个元素 |
| P2_marking_member_0[5] | volatile long | 40B | ld 随机索引 | 120 个排列各读 2-4 个元素 |
| P3_marking_member_0[6] | volatile long | 48B | sd 条件写入 | transition firing 时写入 |

**数据总量**: 3 个 int + 3 个 long 数组 = 12B + 112B = 124B → **完全驻 L1D，甚至在寄存器中**

### 1.6 计算特征

- **控制流密集型**: 核心是大量条件分支（126 个 guard check），大部分 transition 不 fire
- **运算类型**: 整数比较 (`bge`/`blt`/`bne`) + 少量加减法
- **分支特征**: 绝大多数分支 fall-through（not-taken），因为初始状态下只有极少 transition 满足条件
- **代码量极大**: `benchmark_body` 函数编译后 ~64KB（0x10426-0x14312），可能导致 I-cache 压力
- **volatile 变量**: 所有 Place 标记为 volatile，阻止编译器优化，强制每次从内存读取

## 2. 汇编热点分析

### 2.1 Spike 执行概况
```
Total instructions: 2,242,284
Cycles:  2,242,281
Instret: 2,242,284
IPC: 1.0000 (spike 顺序执行)
```

### 2.2 核心函数反汇编

`benchmark_body` 函数地址范围: `0x10426 - 0x14312`，共 ~64KB，1842 个唯一 PC。

**Transition 检查模式（T1, Permutation 0,1,2 为例）**:

```asm
# === 每次迭代开始：重置 Place 标记 ===
10454:  sw    a2,-1944(a7)       # P1_is_marked = 3
10458:  sw    t6,-1948(a5)       # P2_is_marked = 5
1045c:  sw    zero,-2028(gp)     # P3_is_marked = 0

# === T1 Guard Check (Permutation 0,1,2) ===
10460:  lw    t5,-1944(a7)       # t5 = P1_is_marked (volatile load)
10464:  bge   t1,t5,10480        # if (P1_is_marked < 3) skip  [t1=2]
10468:  lw    t5,-2028(gp)       # t5 = P3_is_marked (volatile load)
1046c:  blt   a2,t5,10480        # if (P3_is_marked > 3) skip  [a2=3]
10470:  ld    s0,8(t3)           # s0 = P1_marking_member_0[1]
10474:  ld    t5,16(t3)          # t5 = P1_marking_member_0[2]
10478:  bne   s0,t5,10480        # if (member[1] != member[2]) skip
1047c:  j     12ad0              # → transition body (rare path)

# === 下一个 Permutation (0,2,1) ===
10480:  lw    t5,-1944(a7)       # 再次 volatile load P1_is_marked
...                               # 重复相同模式

# === Transition Body (T1, Perm 0,1,2) ===
12ad0:  ld    t5,0(t3)           # x = P1_marking_member_0[0]
12ad4:  ld    s0,8(t3)           # y = P1_marking_member_0[1]
12ad8:  blt   t5,s0,12ae0        # if (x < y) → fire
12adc:  j     10480              # else → next permutation

12ae0:  lw    s1,-1944(a7)       # s1 = P1_is_marked
12ae4:  sub   s2,t5,s0           # z = x - y
12ae8:  addiw s1,s1,-3           # P1_is_marked -= 3
12aea:  sw    s1,-1944(a7)       # store P1_is_marked
12aee:  lw    s1,-2028(gp)       # s1 = P3_is_marked
12af2:  slli  s1,s1,0x3          # s1 *= 8 (long index)
12af4:  add   s1,s1,t0           # s1 = &P3_marking_member_0[P3_is_marked]
12af6:  sd    t5,0(s1)           # P3[...+0] = x
...                               # store y, z
12b1a:  addiw t5,t5,3            # P3_is_marked += 3
12b1c:  sw    t5,-2028(gp)       # store P3_is_marked
12b20:  j     10480              # → next permutation
```

**编译器优化观察**:
- 寄存器分配: `a7`=&P1_is_marked 基址, `a5`=&P2_is_marked 基址, `gp`+offset=P3_is_marked
- `t3`=P1_marking_member_0 基址, `a3`=P2_marking_member_0 基址, `t0`=P3_marking_member_0 基址
- 常量 `a2=3`, `t6=5`, `t1=2`, `a4=4` 在循环外初始化，避免重复加载
- volatile 语义严格执行：每个 guard check 都从内存重新 load P1/P2/P3_is_marked
- Transition body 放在函数尾部（cold path），通过 `j` 跳转到后半段

**循环回边**:
```asm
112c0:  bne   a0,t2,10452        # lsf_cnt != end? → 回到循环头
```

### 2.3 热点 PC 分布

由于没有内层循环，所有 126 个 transition 检查在每次迭代中顺序执行一遍。每个 PC 的执行次数与 `lsf × gsf + warmup = 1232 + 1 = 1233` 次吻合（部分为 797 = 被 early-exit 跳过的路径，部分为 1233）。

| 区域 | PC 范围 | 每 PC 执行次数 | 指令数(估) | 总执行次数 | 占比 |
|------|---------|---------------|-----------|-----------|------|
| **T1 guard checks (6 perm)** | `0x10460 - 0x1051c` | 797~1233 | ~42 | ~45,000 | 2.0% |
| **T2 guard checks (60 perm)** | `0x10520 - 0x10e00` | 797~1233 | ~420 | ~450,000 | 20.0% |
| **T3 guard checks (60 perm)** | `0x10e00 - 0x112c0` | 797~1233 | ~420 | ~450,000 | 20.0% |
| **Transition bodies** | `0x12ad0 - 0x14310` | 797 | ~极少命中 | ~少量 | <1% |
| **顺序直通区域合计** | `0x10426 - 0x14312` | — | 1842 PCs | 2,244,104 | 99.5% |
| pk/bbl 系统开销 | — | — | — | ~15,266 | 0.7% |
| **合计** | — | — | — | **~2,253,930** | **100%** |

**执行次数验证**: 每个 guard check PC 出现 1233 次（warmup 1 + 正式 1232）或 797 次（部分路径被分支跳过）。
用户态总指令 2,253,930 / 1233 次迭代 ≈ 1828 条/迭代，与 1842 个唯一 PC 基本吻合（大部分 PC 每迭代执行 1 次，少量被跳过）。

### 2.4 微架构分析

**指令混合** (benchmark_body):
- lw/ld: ~40% (volatile load 占主导)
- bge/blt/bne/beq: ~28% (条件分支，629 条)
- sw/sd: ~5% (状态重置 + transition firing)
- j: ~5% (transition body 跳转)
- addi/sub/slli/add: ~22% (地址计算 + 少量算术)

**关键特征**:

1. **分支高度可预测**: 每次迭代状态相同（重置后），所有 transition 的 guard check 结果完全相同。第一次迭代后，分支预测器可以 100% 预测。
2. **I-cache 压力**: 函数体 ~64KB，远超典型 L1I（32KB-64KB），在实际 OoO core 上可能导致 I-cache miss。
3. **volatile load 瓶颈**: 每个 guard check 都有 volatile lw，编译器不能将其提升到寄存器。但由于数据量极小（124B），全部在 L1D 中。
4. **无数据依赖链**: guard check 之间没有 RAW 依赖（每个 check 独立读 volatile 变量），理论上 OoO core 可以大量并行执行。

**关键依赖链**（单个 guard check）:
```
lw t5 (volatile) ──→ bge/blt (1 cycle latency)
lw t5 (volatile) ──→ bge/blt (1 cycle latency)
ld s0 ──┐
         ├──→ bne (1 cycle latency)
ld t5 ──┘
```
延迟: lw(2~3) + branch resolve(1) = 3~4 cycles per check

**预计 IPC (OoO core)**:
- 分支预测正确率极高（~99%+），可以持续推测执行
- 但 I-cache miss 可能成为瓶颈
- volatile load 可能限制乱序窗口利用率
- 预计 IPC: 1.5~3.0（取决于 I-cache 容量和 fetch bandwidth）

## 3. 总结

```
算法:           Petri 网模拟 (3 Place, 3 Transition, 126 排列检查)
数据量:         124B (3 个 volatile int + 3 个 volatile long 数组, 完全驻 L1D)
计算类型:       控制流密集型 (分支占比 ~28%)
函数体大小:     ~64KB (可能超过 L1I 容量)
内层循环:       无 (纯 if-else 链, 每迭代 ~1828 条指令)
热点函数占比:   99.5% (benchmark_body)
瓶颈预测:       I-cache bound (64KB 代码) + volatile load overhead
分支特征:       126 个 guard check, 每次迭代行为完全相同, 高度可预测
特殊说明:       所有变量 volatile, 阻止编译器优化
```
