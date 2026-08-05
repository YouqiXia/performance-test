# depthconv 性能分析

## 1. 源码分析

### 1.1 基本信息
- **源文件**: `thirdparty/embench-iot/src/depthconv/depthconv.c`
- **算法描述**: TensorFlow Lite 量化 Depthwise Convolution (int8 输入/输出, int32 累加)
- **LOCAL_SCALE_FACTOR**: 1639
- **数据类型**: `int8_t` (输入/滤波器/输出), `int32_t` (累加器/bias)

### 1.2 调用链
```
benchmark() -> benchmark_body(lsf=1639, gsf=1)
  └-> 循环 1639×1 = 1639 次
      └-> DepthwiseConvPerChannel(...)
          └-> 7 层嵌套循环 (batch=1, out_y=1, out_x=1, in_channel=32, m=1, filter_y=4, filter_x=1)
              ├-> 内层: acc += filter_val * (input_val + input_offset)  ★热点
              └-> 尾部: MultiplyByQuantizedMultiplier + clamp + store
```

### 1.3 核心计算函数

```c
static void DepthwiseConvPerChannel(...) {
    for (int batch = 0; batch < 1; ++batch)
      for (int out_y = 0; out_y < 1; ++out_y)
        for (int out_x = 0; out_x < 1; ++out_x)
          for (int in_channel = 0; in_channel < 32; ++in_channel)
            for (int m = 0; m < 1; ++m) {
              int32_t acc = 0;
              for (int filter_y = 0; filter_y < 4; ++filter_y)    // ★热点
                for (int filter_x = 0; filter_x < 1; ++filter_x) {
                  // 边界检查 (此参数下恒为 true)
                  acc += filter_data[...] * (input_data[...] + 128);
                }
              acc += bias_data[output_channel];       // bias = 0
              acc = MultiplyByQuantizedMultiplier(acc, ...);  // 量化缩放
              acc = MAX(acc, -128); acc = MIN(acc, 127);      // clamp
              output_data[...] = (int8_t)acc;
            }
}
```

```c
static int32_t MultiplyByQuantizedMultiplier(int32_t x, int32_t quantized_multiplier, int shift) {
    const int64_t total_shift = 31 - shift;  // shift=-8, total_shift=39
    const int64_t round = (int64_t)1 << (total_shift - 1);
    int64_t result = x * ((int64_t)quantized_multiplier) + round;
    result = result >> total_shift;
    return result;
}
```

### 1.4 循环结构

| 循环层 | 变量 | Trip Count | 说明 |
|--------|------|-----------|------|
| benchmark_body 外层 | lsf_cnt | 1639 | LOCAL_SCALE_FACTOR |
| benchmark_body 内层 | gsf_cnt | 1 | GLOBAL_SCALE_FACTOR |
| batch | batch | 1 | 固定 |
| out_y | out_y | 1 | output_height |
| out_x | out_x | 1 | output_width |
| **in_channel** | **in_channel** | **32** | **输出通道遍历** |
| m | m | 1 | depth_multiplier |
| **filter_y** | **filter_y** | **4** | **滤波器高度（最内层热点）** |
| filter_x | filter_x | 1 | 滤波器宽度 |

**编译器优化**: batch/out_y/out_x/m/filter_x 均为 1，被编译器完全消除。实际只剩 in_channel(32) 和 filter_y(4) 两层循环，且 filter_y 循环以 stride=32 的方式遍历 input/filter 数组。

### 1.5 访存模式

| 数组 | 大小 | 访问方式 | Stride | 说明 |
|------|------|---------|--------|------|
| input_data[128] | 128B | int8 load | 32B (跨 filter_y) | filter_y 内: &input[batch,in_y,0,in_channel], stride=32 |
| filter_data[128] | 128B | int8 load | 32B (跨 filter_y) | filter_y 内: &filter[0,filter_y,0,out_channel], stride=32 |
| bias_data[32] | 128B | int32 load | 4B | 每通道一次 |
| output_multiplier[32] | 128B | int32 load | 4B | 每通道一次 |
| output_shift[32] | 128B | int32 load | 4B | 每通道一次 |
| output_data[32] | 32B | int8 store | 1B | 每通道一次 |

**数据总量**: 128 + 128 + 128 + 128 + 128 + 32 = 672B -> **完全驻 L1D**

### 1.6 计算特征

- **计算密集型**: 数据极小，全驻 L1D cache line 内
- **运算类型**: int8 load -> sext -> addiw(+128) -> mulw -> addw 累加；尾部 mul(64-bit) + sra + clamp
- **分支**: 内层循环 filter_y trip count=4，外层 in_channel trip count=32，高度可预测
- **特殊**: input_offset=128 使得 int8 输入在计算前加偏移，编译器用 `addiw s2,s2,128` 实现

## 2. 汇编热点分析

### 2.1 Spike 执行概况
```
Total instructions: 3,256,727
Cycles:  3,256,723
Instret: 3,256,727
IPC: 1.0000 (spike 顺序执行)
```

### 2.2 核心函数反汇编

编译器将 7 层循环坍缩为 2 层：外层 in_channel(32)，内层 filter_y(4)。filter_y 循环通过 stride=32 的指针递增实现。

```asm
000000000001042a <DepthwiseConvPerChannel.constprop.0>:
  # === prologue: 加载全局数据指针 ===
  1042a:  addi  sp, sp, -48
  1042c:  lui   a1, 0x7e              # a1 -> BIAS_DATA 基址
  10430:  lui   a2, 0x7c              # a2 -> OUTPUT_MULTIPLIER 基址
  10434:  lui   a3, 0x7c              # a3 -> OUTPUT_SHIFT 基址
  10438:  li    a4, 1                 # a4 = 1 (通道计数器起始)
  1043a:  lui   a7, 0x7c              # a7 -> FILTER_DATA 基址
  1043e:  lui   a6, 0x7c              # a6 -> INPUT_DATA 基址 (含偏移)
  ...
  10466:  li    s0, 128               # s0 = 128 = input_offset, 也是 filter_y 内循环终止条件(4*32=128)
  1046a:  li    t2, 30                # t2 = 30, 用于 MultiplyByQuantizedMultiplier
  1046c:  li    t0, 31                # t0 = 31, 用于 total_shift
  1046e:  li    t6, -128              # t6 = -128, clamp 下界
  10472:  li    t5, 127               # t5 = 127, clamp 上界
  10476:  li    t4, 33                # t4 = 33, 外层循环终止 (32+1)

  # === 外层 in_channel 循环入口 (32 次) ===
  1047a:  li    a5, 0                 # a5 = 0, filter_y 步进计数器
  1047c:  li    t3, 0                 # t3 = 0, 累加器 acc

  # === 设置 filter_y 指针 ===
  1047e:  add   s4, a7, a4            # s4 = &filter[0,0,0,out_channel]
  10482:  add   s3, a6, a4            # s3 = &input[0,0,0,in_channel]

  # === 内层 filter_y 循环 (4 次) ★★★ 热点 ===
  10486:  add   a0, s4, a5            # a0 = 数据指针 A (编译器常量传播后的偏移)
  1048a:  lb    s2, 0(a0)             # s2 = 值 A (int8 -> int32 符号扩展)
  1048e:  add   a0, s3, a5            # a0 = 数据指针 B
  10492:  lb    a0, 0(a0)             # a0 = 值 B (int8 -> int32 符号扩展)
  10496:  addiw s2, s2, 128           # s2 += input_offset (编译器将 +128 合并到此处)
  1049a:  addi  a5, a5, 32            # a5 += 32 (stride = depth=32)
  1049e:  mulw  a0, a0, s2            # a0 = filter_val * (input_val + 128)
  104a2:  addw  t3, a0, t3            # t3 = acc += product
  104a6:  bne   a5, s0, 0x10486       # filter_y < 4 ? (a5 < 128 ?)

  # === 量化缩放 (MultiplyByQuantizedMultiplier, 内联) ===
  104aa:  lw    a5, 0(a1)             # a5 = bias_data[out_channel]
  104ac:  lw    s2, 0(a2)             # s2 = output_multiplier[out_channel]
  104b0:  lw    a0, 0(a3)             # a0 = output_shift[out_channel] = -8
  104b2:  addw  a5, a5, t3            # a5 = acc + bias
  104b6:  mul   a5, a5, s2            # a5 = acc * quantized_multiplier (64-bit)
  104ba:  subw  t3, t2, a0            # t3 = 30 - shift = 30 - (-8) = 38
  104be:  sll   t3, s1, t3            # t3 = 1 << 38 (round)
  104c2:  subw  a0, t0, a0            # a0 = 31 - shift = 31 - (-8) = 39 (total_shift)
  104c6:  add   a5, a5, t3            # a5 += round
  104c8:  sra   a5, a5, a0            # a5 >>= total_shift (39)

  # === Clamp to [-128, 127] ===
  104cc:  sext.w a0, a5               # a0 = (int32_t)a5
  104d0:  bge   a0, t6, 0x104d8       # a0 >= -128 ? skip
  104d4:  li    a5, -128              # clamp to -128
  104d8:  sext.w t3, a5               # t3 = (int32_t)a5
  104dc:  add   a0, t1, a4            # a0 = &output_data[out_channel]
  104e0:  bge   t5, t3, 0x104e8       # 127 >= t3 ? skip
  104e4:  li    a5, 127               # clamp to 127
  104e8:  sb    a5, -1(a0)            # store output_data[out_channel]

  # === 外层循环尾部 ===
  104ec:  addi  a4, a4, 1             # out_channel++
  104ee:  addi  a1, a1, 4             # bias_data 指针 += 4
  104f0:  addi  a2, a2, 4             # output_multiplier 指针 += 4
  104f2:  addi  a3, a3, 4             # output_shift 指针 += 4
  104f4:  bne   a4, t4, 0x1047a       # out_channel < 33 ? (通道 1..32)
```

**编译器优化观察**:
- 7 层循环坍缩为 2 层，常量层被完全消除
- filter_y 步进通过 a5 += 32 (stride = depth) 实现，而非独立循环变量
- MultiplyByQuantizedMultiplier 完全内联
- input_offset=128 的加法通过 `addiw s2,s2,128` 实现，编译器通过常量传播和指针重组将两个 lb 分别指向 input/filter 数据区域
- 每通道的 quantize 只执行一次（在 filter_y 循环外）

### 2.3 热点 PC 分布

| 区域 | PC 范围 | 每 PC 执行次数 | 指令数 | 总执行次数 | 占比 |
|------|---------|---------------|--------|-----------|------|
| **filter_y 内层循环** | `0x10486 - 0x104a6` | **209,920** | 9 | **1,889,280** | **58.0%** |
| 外层循环体 (量化+clamp+store) | `0x1047a - 0x104f4` (excl inner) | 52,480 | 24 | 1,259,520 | 38.7% |
| benchmark_body 循环控制 | `0x10514 - 0x1051a` | 1,640 | 3 | 4,920 | 0.2% |
| pk/bbl 系统开销 | — | — | — | ~103,007 | 3.2% |
| **合计** | — | — | — | **~3,256,727** | **100%** |

**执行次数验证**:
- 内层: 209,920 = 32(channel) × 4(filter_y) × 1,640(calls) = 128 × 1,640 ✓
- 外层: 52,480 = 32(channel) × 1,640(calls) ✓
- calls = 1,639(lsf) + 1(warmup) = 1,640 ✓

### 2.4 内层循环微架构分析

**指令混合** (filter_y 内层, 9 条/iter):
- add: 2 (22%) — 地址计算
- lb: 2 (22%) — int8 load (filter + input)
- addiw: 1 (11%) — input_offset 加法
- addi: 1 (11%) — 指针步进
- mulw: 1 (11%) — 乘法
- addw: 1 (11%) — 累加
- bne: 1 (11%) — 循环控制

**关键依赖链**:
```
add a0,s4,a5 ──> lb s2,0(a0) ──> addiw s2,s2,128 ──┐
add a0,s3,a5 ──> lb a0,0(a0) ──────────────────────> mulw a0,a0,s2 ──> addw t3,a0,t3
```
延迟: add(1) + lb(2) + addiw(1) + mulw(3~4) + addw(1) = 8~9 cycles (最长路径)
或: add(1) + lb(2) + mulw(3~4) + addw(1) = 7~8 cycles (input path)

**循环携带依赖**:
- `t3`: 累加器, `addw t3,a0,t3` -> 下一次 `addw` 的输入, RAW 依赖
- `a5`: 地址步进, `addi a5,a5,32`, 1-cycle, 不是瓶颈

**预计 IPC (OoO core)**:
- 9 条指令 / 8~9 cycles ≈ 1.0~1.13
- 两个 lb 可并行发射（地址独立）
- mulw 等待两个 lb 结果, 是关键路径
- trip count=4, 循环很短, 可能受分支预测边际效应影响

## 3. 总结

```
算法:           量化 Depthwise Convolution (int8 in/out, int32 acc)
数据量:         672B (全驻 L1D, 甚至驻寄存器/cache line)
计算类型:       int8 lb + mulw + addw 密集, 尾部 mul(64-bit) + sra 量化
内层循环指令数: 9 条 (filter_y 内层)
内层循环占比:   58.0%
瓶颈预测:       compute-bound (lb->mulw->addw 依赖链, trip count=4 限制流水线利用)
分支特征:       内层 trip count=4 (短循环), 外层 trip count=32, 高度可预测
```
