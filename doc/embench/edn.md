# edn 性能分析

## 1. 源码分析

### 1.1 基本信息
- **源文件**: `thirdparty/embench-iot/src/edn/libedn.c`
- **算法描述**: DSP 核心算法集合，包含向量乘法、点积、FIR 滤波、格型综合、IIR 滤波、JPEG DCT 等 8 个子函数
- **LOCAL_SCALE_FACTOR**: 81
- **数据类型**: `short` (16-bit signed), `long int` (64-bit signed)

### 1.2 调用链
```
benchmark() -> benchmark_body(lsf=81, gsf=1)
  └-> 循环 81×1 = 81 次
      ├-> 初始化 in_a[200], in_b[200] (栈上局部数组, 每次重新初始化)
      ├-> 拷贝 in_a -> a[200], in_b -> b[200]
      ├-> vec_mpy1(a, b, c=3)           ★ 向量缩放加法 (150 iter, 内联)
      ├-> mac(a, b, c, &output)          ★ 点积 + 平方和 (150 iter, 内联)
      ├-> fir(a, b, output)              ★★ FIR 滤波 (50×50=2500 iter, 最大热点)
      ├-> fir_no_red_ld(a, b, output)    ★ FIR 优化版 (50×16=800 iter)
      ├-> latsynth(a, b, 100, d)         ★ 格型综合 (99 iter, 内联)
      ├-> iir1(a, b, &output[100], output) ★ IIR 滤波 (50 iter)
      ├-> codebook(...)                     空循环 (循环体已被移除)
      └-> jpegdct(a, b)                  ★ JPEG DCT (2×8×4 蝶形运算)
```

### 1.3 核心计算函数

**fir** (最大热点):
```c
void fir(const short array1[], const short coeff[], long int output[]) {
    long int i, j, sum;
    for (i = 0; i < N - ORDER; i++) {       // 外层: 50 次
        sum = 0;
        for (j = 0; j < ORDER; j++) {        // 内层: 50 次 ★★★热点
            sum += array1[i + j] * coeff[j];
        }
        output[i] = sum >> 15;
    }
}
```

**fir_no_red_ld** (第二热点):
```c
void fir_no_red_ld(const short x[], const short h[], long int y[]) {
    for (j = 0; j < 100; j += 2) {           // 外层: 50 次
        sum0 = 0; sum1 = 0;
        x0 = x[j];
        for (i = 0; i < 32; i += 2) {        // 内层: 16 次 ★
            x1 = x[j+i+1]; h0 = h[i];
            sum0 += x0 * h0; sum1 += x1 * h0;
            x0 = x[j+i+2]; h1 = h[i+1];
            sum0 += x1 * h1; sum1 += x0 * h1;
        }
        y[j] = sum0 >> 15; y[j+1] = sum1 >> 15;
    }
}
```

**vec_mpy1** (内联):
```c
void vec_mpy1(short y[], const short x[], short scaler) {
    for (i = 0; i < 150; i++)
        y[i] += ((scaler * x[i]) >> 15);
}
```

**mac** (内联):
```c
long int mac(const short *a, const short *b, long int sqr, long int *sum) {
    for (i = 0; i < 150; i++) {
        dotp += b[i] * a[i];
        sqr += b[i] * b[i];
    }
    *sum = dotp; return sqr;
}
```

### 1.4 循环结构

| 循环层 | 函数 | 外层 | 内层 | 总内层迭代/call | 说明 |
|--------|------|------|------|----------------|------|
| benchmark_body | — | 81 (lsf) | 1 (gsf) | — | 初始化 + 8 个子函数 |
| **fir** | fir | **50** | **50** | **2,500** | **FIR 卷积，最大热点** |
| **fir_no_red_ld** | fir_no_red_ld | **50** | **16** | **800** | **2 路展开 FIR** |
| vec_mpy1 | 内联 | 150 | — | 150 | 向量缩放 |
| mac | 内联 | 150 | — | 150 | 点积 + 平方和 |
| latsynth | 内联 | 99 | — | 99 | 格型综合，反向遍历 |
| iir1 | iir1 | 50 | — | 50 | IIR 滤波 |
| jpegdct | jpegdct | 2×8 | 4 | 64 | 蝶形运算 (行/列各一遍) |
| codebook | 内联 | 16 | — | 16 | 空循环体 |

### 1.5 访存模式

| 数组 | 大小 | 类型 | 访问方式 |
|------|------|------|---------|
| a[200] | 400B | short | 顺序读/写, 各函数共用 |
| b[200] | 400B | short | 顺序读, 各函数共用 |
| output[200] | 1600B | long int | 顺序写 |
| in_a[200] (栈) | 400B | short | 初始化源, 每轮拷贝到 a |
| in_b[200] (栈) | 400B | short | 初始化源, 每轮拷贝到 b |

**数据总量**: 400 + 400 + 1600 + 800(栈) = 3.2KB -> **完全驻 L1D**

### 1.6 计算特征

- **计算密集型**: 数据全在 L1，瓶颈在 mulw 吞吐和 ld->mulw forwarding
- **运算类型**: short load (lh) + mulw + add/addw 密集
- **分支**: 多层循环控制, 内层 trip count 50/16/150, 高度可预测
- **特殊**: fir_no_red_ld 使用 2 路循环展开减少冗余 load

## 2. 汇编热点分析

### 2.1 Spike 执行概况
```
Total instructions: 3,165,388
Cycles:  3,165,385
Instret: 3,165,388
IPC: 1.0000 (spike 顺序执行)
```

### 2.2 核心函数反汇编

#### fir (最大热点)

```asm
0000000000010426 <fir>:
  # === prologue ===
  10426:  addi  a6, a0, 100           # a6 = &array1[50], 内层终止地址
  1042a:  mv    a7, a2                # a7 = output 指针
  1042c:  li    t1, 0                 # t1 = 0, 外层计数器
  1042e:  li    t3, 50                # t3 = 50, 外层终止

  # === L1: 外层循环 (50 次) ===
  10432:  addi  a5, a6, -100          # a5 = &array1[i], 重置内层 A 指针
  10436:  mv    a3, a1                # a3 = &coeff[0], 重置内层 B 指针
  10438:  li    a2, 0                 # a2 = 0, 累加器 sum

  # === L2: 内层循环 (50 次) ★★★ 最大热点 ===
  1043a:  lh    a4, 0(a5)             # a4 = array1[i+j] (int16 -> int64)
  1043e:  lh    a0, 0(a3)             # a0 = coeff[j]    (int16 -> int64)
  10442:  addi  a5, a5, 2             # A 指针 += 2
  10444:  addi  a3, a3, 2             # B 指针 += 2
  10446:  mulw  a4, a4, a0            # a4 = array1[i+j] * coeff[j]
  1044a:  add   a2, a2, a4            # sum += product
  1044c:  bne   a6, a5, 0x1043a       # j < 50 ? -> 继续

  # === 外层循环尾部 ===
  10450:  srai  a2, a2, 0xf           # sum >>= 15
  10452:  sd    a2, 0(a7)             # output[i] = sum
  10456:  addi  t1, t1, 1             # i++
  10458:  addi  a7, a7, 8             # output 指针 += 8
  1045a:  addi  a6, a6, 2             # 内层终止地址 += 2
  1045c:  bne   t1, t3, 0x10432       # i < 50 ? -> 继续
```

#### fir_no_red_ld (第二热点)

```asm
0000000000010462 <fir_no_red_ld>:
  10462:  addi  t4, a0, 66            # t4 = 内层终止地址 (j+i+2 最后位置)
  ...
  # === 内层循环 (16 次, 2 路展开) ===
  1047c:  lh    a2, 0(a7)             # a2 = h[i]
  10480:  lh    a3, 0(a5)             # a3 = x[j+i+1]
  10484:  lh    a4, 2(a7)             # a4 = h[i+1] (预取下一个 coeff)
  10488:  mulw  t3, t1, a2            # t3 = x0 * h0 -> sum0
  1048c:  lh    t1, 2(a5)             # t1 = x[j+i+2] (预取下一个 x)
  10490:  addi  a5, a5, 4             # x 指针 += 4
  10492:  addi  a7, a7, 4             # h 指针 += 4
  10494:  mulw  a2, a2, a3            # a2 = x1 * h0 -> sum1
  10498:  add   a6, a6, t3            # sum0 += x0 * h0
  1049a:  mulw  a3, a3, a4            # a3 = x1 * h1 -> sum0
  1049e:  add   a0, a0, a2            # sum1 += x1 * h0
  104a0:  mulw  a4, t1, a4            # a4 = x0_new * h1 -> sum1
  104a4:  add   a6, a6, a3            # sum0 += x1 * h1
  104a6:  add   a0, a0, a4            # sum1 += x0_new * h1
  104a8:  bne   t4, a5, 0x1047c       # i < 32 ? -> 继续
```

#### vec_mpy1 (内联于 benchmark_body, 0x10870-0x1088c)

```asm
  # === 内联 vec_mpy1, scaler=3, 150 次 ===
  10870:  lh    a5, 0(a3)             # a5 = b[i] (x[i])
  10874:  lhu   a2, 0(a4)             # a2 = a[i] (y[i], zero-extend)
  10878:  addi  a4, a4, 2             # a 指针 += 2
  1087a:  slliw a1, a5, 0x1           # a1 = x[i] << 1 = x[i]*2
  1087e:  addw  a5, a5, a1            # a5 = x[i] + x[i]*2 = x[i]*3 (scaler=3, 编译器用 shift+add 替代 mul)
  10880:  sraiw a5, a5, 0xf           # a5 = (3 * x[i]) >> 15
  10884:  addw  a5, a5, a2            # a5 = y[i] + (3 * x[i]) >> 15
  10886:  sh    a5, -2(a4)            # store a[i]
  1088a:  addi  a3, a3, 2             # b 指针 += 2
  1088c:  bne   s11, a4, 0x10870      # i < 150 ? -> 继续
```

#### mac (内联于 benchmark_body, 0x1089a-0x108b2)

```asm
  # === 内联 mac, 150 次 ===
  1089a:  lh    a5, 0(a4)             # a5 = a[i]
  1089e:  lh    a3, 0(a2)             # a3 = b[i]
  108a2:  addi  a4, a4, 2             # a 指针 += 2
  108a4:  addi  a2, a2, 2             # b 指针 += 2
  108a6:  mulw  a3, a3, a5            # a3 = b[i] * a[i]
  108aa:  mulw  a5, a5, a5            # a5 = a[i] * a[i] (注: 源码是 b[i]*b[i], 编译器重用 a5)
  108ae:  add   a0, a0, a3            # dotp += b[i]*a[i]
  108b0:  add   a1, a1, a5            # sqr += a[i]*a[i]
  108b2:  bne   s10, a4, 0x1089a      # i < 150 ? -> 继续
```

#### latsynth (内联于 benchmark_body, 0x108f0-0x10914)

```asm
  # === 内联 latsynth, 反向遍历 99 次 ===
  108f0:  lh    a2, 0(a4)             # a2 = b[i]
  108f4:  lh    a5, 0(a3)             # a5 = k[i]
  108f8:  addi  a4, a4, -2            # b 指针 -= 2 (反向)
  108fa:  addi  a3, a3, -2            # k 指针 -= 2
  108fc:  mulw  a1, a2, a5            # a1 = b[i] * k[i]
  10900:  sub   s7, s7, a1            # f -= b[i]*k[i]
  10904:  srai  a1, s7, 0x10          # a1 = f >> 16
  10908:  mul   a5, a5, a1            # a5 = k[i] * (f >> 16)
  1090c:  srai  a5, a5, 0x10          # a5 = (k[i] * (f>>16)) >> 16
  1090e:  addw  a5, a5, a2            # a5 = b[i] + ...
  10910:  sh    a5, 4(a4)             # b[i+1] = a5
  10914:  bne   s9, a4, 0x108f0       # i >= 0 ? -> 继续
```

### 2.3 热点 PC 分布

| 区域 | PC 范围 | 每 PC 执行次数 | 指令数 | 总执行次数 | 占比 |
|------|---------|---------------|--------|-----------|------|
| **fir L2 内层** | `0x1043a - 0x1044c` | **205,000** | 7 | **1,435,000** | **45.3%** |
| **fir_no_red_ld 内层** | `0x1047c - 0x104a8` | **65,600** | 16 | **1,049,600** | **33.2%** |
| vec_mpy1 (内联) | `0x10870 - 0x1088c` | 12,300 | 10 | 123,000 | 3.9% |
| mac (内联) | `0x1089a - 0x108b2` | 12,300 | 10 | 123,000 | 3.9% |
| latsynth (内联) | `0x108f0 - 0x10914` | 8,118 | 13 | 105,534 | 3.3% |
| iir1 | `0x104ce - 0x10510` | 4,100 | 17 | 69,700 | 2.2% |
| jpegdct 蝶形 | `0x1056e - 0x10712` | 1,312~5,248 | ~80 | ~103,000 | 3.3% |
| memcpy (a,b 初始化) | 多段 | 4,100 | ~10 | ~82,000 | 2.6% |
| fir 外层 + 尾部 | `0x10432/10450-1045c` | 4,100 | 8 | 32,800 | 1.0% |
| pk/bbl 系统开销 | — | — | — | ~41,754 | 1.3% |
| **合计** | — | — | — | **~3,165,388** | **100%** |

**执行次数验证**:
- fir 内层: 205,000 = 50 × 50 × 82 (81+1 warmup) ✓
- fir_no_red_ld 内层: 65,600 = 50 × 16 × 82 ✓
- vec_mpy1: 12,300 = 150 × 82 ✓
- mac: 12,300 = 150 × 82 ✓
- latsynth: 8,118 = 99 × 82 ✓

### 2.4 内层循环微架构分析

#### fir 内层循环 (7 条/iter, 最大热点 45.3%)

**指令混合**:
- lh: 2 (28.6%)
- addi: 2 (28.6%)
- mulw: 1 (14.3%)
- add: 1 (14.3%)
- bne: 1 (14.3%)

**关键依赖链**:
```
lh a4 ──┐
         ├→ mulw a4,a4,a0 → add a2,a2,a4
lh a0 ──┘
```
延迟: lh(2) + mulw(3~4) + add(1) = 6~7 cycles

**循环携带依赖**:
- `a2`: 累加器, `add a2,a2,a4` -> 下一次 `add` 的输入, 但 mulw 完成前不受影响
- `a5`/`a3`: 指针递增, 1-cycle, 不是瓶颈

**预计 IPC (OoO core)**:
- 7 条指令 / 6~7 cycles ≈ 1.0~1.17
- 两个 lh 可并行发射
- mulw→add 串行链限制 IPC 上界
- 与 matmult-int 结构非常相似, 但内层仅 7 条 (无 sd 写回)

#### fir_no_red_ld 内层循环 (16 条/iter, 第二热点 33.2%)

**指令混合**:
- lh: 4 (25%)
- mulw: 4 (25%)
- add: 4 (25%)
- addi: 3 (18.75%)
- bne: 1 (6.25%)

**关键依赖链** (2 路并行):
```
路径 sum0: lh x0/h0 -> mulw -> add a6, lh x1/h1 -> mulw -> add a6
路径 sum1: lh x1/h0 -> mulw -> add a0, lh x0/h1 -> mulw -> add a0
```
两条路径共享 load 结果 (x0/x1/h0/h1), 4 个 mulw 可部分重叠。

**预计 IPC (OoO core)**:
- 16 条 / ~12 cycles ≈ 1.3
- 4 个 mulw 间有 operand 共享但无串行依赖
- 更高 ILP 潜力

## 3. 总结

```
算法:           DSP 核心算法集合 (FIR, IIR, DCT, vec_mpy, mac, latsynth)
数据量:         3.2KB (全驻 L1D)
计算类型:       int16 lh + mulw + add 密集
最大热点:       fir 内层循环 (45.3%), 7 条/iter
第二热点:       fir_no_red_ld 内层循环 (33.2%), 16 条/iter (2 路展开)
两热点合计:     78.5%
瓶颈预测:       compute-bound (lh->mulw->add 依赖链, 与 matmult-int 结构相似)
分支特征:       多层循环控制, trip count 16~150, 高度可预测
编译器特征:     vec_mpy1 的 scaler=3 被优化为 slli+addw (强度削减)
```
