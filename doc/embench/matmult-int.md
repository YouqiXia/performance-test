# matmult-int 性能分析

## 1. 源码分析

### 1.1 基本信息
- **源文件**: `thirdparty/embench-iot/src/matmult-int/matmult-int.c`
- **算法描述**: 20×20 整数矩阵乘法（long 类型）
- **LOCAL_SCALE_FACTOR**: 39
- **数据类型**: `long`（64-bit signed integer）

### 1.2 调用链
```
benchmark() → benchmark_body(lsf=39, gsf=1)
  └→ 循环 39×1 = 39 次
      ├→ memcpy(ArrayA ← ArrayA_ref, 3200B)
      ├→ memcpy(ArrayB ← ArrayB_ref, 3200B)
      └→ Test() → Multiply(A, B, Res)
          └→ 三重循环 20×20×20 = 8000 次内层迭代
```

### 1.3 核心计算函数

```c
void Multiply(matrix A, matrix B, matrix Res) {
    register int Outer, Inner, Index;
    for (Outer = 0; Outer < 20; Outer++)       // L1: 行
        for (Inner = 0; Inner < 20; Inner++) {  // L2: 列
            Res[Outer][Inner] = 0;
            for (Index = 0; Index < 20; Index++)// L3: 点积 ★热点
                Res[Outer][Inner] += A[Outer][Index] * B[Index][Inner];
        }
}
```

### 1.4 循环结构

| 循环层 | 变量 | Trip Count | 说明 |
|--------|------|-----------|------|
| benchmark_body 外层 | lsf_cnt | 39 | LOCAL_SCALE_FACTOR |
| benchmark_body 内层 | gsf_cnt | 1 | GLOBAL_SCALE_FACTOR |
| L1 | Outer | 20 | 矩阵行遍历 |
| L2 | Inner | 20 | 矩阵列遍历 |
| **L3** | **Index** | **20** | **点积累加（最内层热点）** |

### 1.5 访存模式

| 数组 | 访问方式 | Stride | 说明 |
|------|---------|--------|------|
| A[Outer][Index] | 行顺序 | 8B | L3 内 Index++，cache 友好 |
| B[Index][Inner] | 列跨越 | 160B (20×8B) | L3 内 Index++，跨行访问 |
| Res[Outer][Inner] | 单点反复读写 | — | L3 内不变，反复 load/store 同一地址 |

**数据总量**: 3 个 20×20 long 矩阵 = 3 × 3200B = 9.6KB → **完全驻 L1D**

### 1.6 计算特征

- **计算密集型**: 数据全在 L1，瓶颈在 MUL 吞吐和 ld→mul forwarding
- **运算类型**: 整数乘法 (`mul`) + 整数加法 (`add`)
- **分支**: 3 层循环控制，内层 L3 trip count=20，高度可预测

## 2. 汇编热点分析

### 2.1 Spike 执行概况
```
Total instructions: 3,569,512
Cycles:  2,696,483
Instret: 2,696,486
IPC: 1.0000 (spike 顺序执行)
```

### 2.2 核心函数反汇编

```asm
000000000001042a <Multiply>:
  # === prologue: 计算边界地址 ===
  1042a:  addi  t6, a0, 3360      # t6 = &A[20][0] = A 末尾, L1 终止条件
  1042e:  mv    t5, a2             # t5 = &Res[0][0], 保存 Res 基址
  10434:  addi  a7, a0, 160        # a7 = &A[0][20] = A 第 0 行末尾, L3 终止
  10438:  addi  t4, a1, 160        # t4 = &B[0][20], L2 终止条件

  # === L1: Outer loop (20 次) ===
  1043c:  mv    t1, a1             # t1 = &B[0][0], B 基址重置
  1043e:  mv    a6, t5             # a6 = &Res[Outer][0], Res 行指针重置

  # === L2: Inner loop (20 次) ===
  10440:  addi  t3, a7, -160       # t3 = &A[Outer][0], A 当前行起始
  10444:  sd    zero, 0(a6)        # Res[Outer][Inner] = 0
  10448:  mv    a5, t3             # a5 = &A[Outer][0], L3 的 A 指针
  1044a:  mv    a2, t1             # a2 = &B[0][Inner], L3 的 B 指针
  1044c:  li    a3, 0              # a3 = 0, 累加器

  # === L3: Index loop (20 次) ★★★ 热点 ===
  1044e:  ld    a4, 0(a5)          # a4 = A[Outer][Index]
  10450:  ld    a0, 0(a2)          # a0 = B[Index][Inner]
  10452:  addi  a5, a5, 8          # A 指针 += 8 (stride=8B)
  10454:  addi  a2, a2, 160        # B 指针 += 160 (stride=160B, 下一行同列)
  10458:  mul   a4, a4, a0         # a4 = A[i][k] * B[k][j]
  1045c:  add   a3, a3, a4         # a3 += a4 (累加)
  1045e:  sd    a3, 0(a6)          # Res[i][j] = a3 (写回)
  10462:  bne   a5, a7, 0x1044e    # Index < 20 ? → 继续

  # === L2 尾部 ===
  10466:  addi  t1, t1, 8          # B 列指针 += 8 (Inner++)
  10468:  addi  a6, a6, 8          # Res 列指针 += 8
  1046a:  bne   t1, t4, 0x10444    # Inner < 20 ? → 继续

  # === L1 尾部 ===
  1046e:  addi  a7, a5, 160        # 更新 A 行结束地址 (Outer++)
  10472:  addi  t5, t5, 160        # Res 行基址 += 160
  10476:  bne   a7, t6, 0x1043c    # Outer < 20 ? → 继续
  1047a:  ret
```

**编译器优化观察**:
- memcpy 被内联为 32B/iter 的 ld/sd 循环（4×8B 展开）
- Multiply 中使用指针递增替代数组索引（避免 slli+add 地址计算）
- B 的 stride=160B 直接编码为立即数
- 无循环展开（-O2 对 trip count=20 未展开）
- 每次 L3 迭代都 sd 写回 Res（保守但正确）

### 2.3 热点 PC 分布

| 区域 | PC 范围 | 每 PC 执行次数 | 指令数 | 总执行次数 | 占比 |
|------|---------|---------------|--------|-----------|------|
| **L3 内层循环** | `0x1044e - 0x10462` | **320,000** | 8 | **2,560,000** | **71.7%** |
| L2 循环 setup | `0x10444 - 0x1044c` | 16,000 | 4 | 64,000 | 1.8% |
| L2 尾部 | `0x10466 - 0x1046a` | 16,000 | 3 | 48,000 | 1.3% |
| memcpy A | `0x104d6 - 0x104f6` | 4,000 | 12 | 48,000 | 1.3% |
| memcpy B | `0x10500 - 0x1051c` | 4,000 | 12 | 48,000 | 1.3% |
| L1 循环 | `0x1043c - 0x10440` | 800 | 4 | 3,200 | 0.1% |
| L1 尾部 | `0x1046e - 0x10476` | 800 | 3 | 2,400 | 0.1% |
| pk/bbl 系统开销 | — | — | — | 772,701 | 21.6% |
| **合计** | — | — | — | **3,569,512** | **100%** |

**执行次数验证**: 320,000 = 20³ × (39 + 1) = 8,000 × 40 ✓

### 2.4 内层循环微架构分析

**指令混合** (L3, 8 条/iter):
- ld: 2 (25%)
- addi: 2 (25%)
- mul: 1 (12.5%)
- add: 1 (12.5%)
- sd: 1 (12.5%)
- bne: 1 (12.5%)

**关键依赖链**:
```
ld a4 ──┐
         ├→ mul a4,a4,a0 → add a3,a3,a4 → sd a3
ld a0 ──┘
```
延迟: ld(2) + mul(3~4) + add(1) = 6~7 cycles

**循环携带依赖**:
- `a3`: 累加器，`add a3,a3,a4` 的结果是下一次 `add` 的输入 → RAW 依赖
- `a5`/`a2`: 地址指针，`addi` 1-cycle，不是瓶颈

**预计 IPC (OoO core)**:
- 8 条指令 / 6~7 cycles ≈ 1.14~1.33
- 两个 ld 可并行发射，两个 addi 可并行
- mul→add 是串行链，限制 IPC 上界

## 3. 总结

```
算法:           20×20 矩阵乘法 (long)
数据量:         9.6KB (3 × 20×20×8B, 全驻 L1D)
计算类型:       int ld/mul/add 密集
内层循环指令数: 8 条
内层循环占比:   71.7%
瓶颈预测:       compute-bound (MUL throughput + ld→mul→add 依赖链)
分支特征:       3 层循环控制, trip count=20, 高度可预测
```
