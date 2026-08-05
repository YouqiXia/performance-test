# huffbench 性能分析

## 1. 源码分析

### 1.1 基本信息
- **源文件**: `thirdparty/embench-iot/src/huffbench/libhuffbench.c`
- **算法描述**: Huffman 编码 + 解码完整流程 (压缩后再解压，验证数据一致)
- **LOCAL_SCALE_FACTOR**: 11
- **数据类型**: `byte` (uint8), `bits32` (unsigned long), `size_t` (64-bit)
- **TEST_SIZE**: 500 字节

### 1.2 调用链
```
benchmark() -> benchmark_body(lsf=11, gsf=1)
  └-> 循环 11×1 = 11 次
      ├-> init_heap_beebs(heap, 8192)        # 堆分配器初始化
      ├-> memcpy(test_data <- orig_data, 500B)
      └-> compdecomp(test_data, 500)
          ├── [COMPRESSION]
          │   ├-> 频率统计: 遍历 500B 数据
          │   ├-> 建堆: heap_adjust × n 次
          │   ├-> 建 trie: while(n>1) heap_adjust × 2 + 合并
          │   ├-> 生成码表: 256 符号遍历 trie link
          │   └-> 编码: 500 字节 × 变长码位
          └── [DECOMPRESSION]
              ├-> 建解码表: 256 符号 trie 路径
              ├-> 插入排序: heap2[256] + outc[256] ★★★ 热点
              └-> 解码: 500 字节 × 变长码位查找 ★★ 热点
```

### 1.3 核心计算函数

**heap_adjust** (堆调整, 被压缩阶段多次调用):
```c
static void heap_adjust(size_t *freq, size_t *heap, int n, int k) {
    --heap;
    int v = heap[k];
    while (k <= (n / 2)) {
        j = k + k;
        if ((j < n) && (freq[heap[j]] > freq[heap[j+1]])) ++j;
        if (freq[v] < freq[heap[j]]) break;
        heap[k] = heap[j];
        k = j;
    }
    heap[k] = v;
}
```

**插入排序** (解码表排序, 最大热点):
```c
// sort outc based on heap2
for (i = 1; i < 256; ++i) {
    t = heap2[i]; c = outc[i]; j = i;
    while ((j) && (heap2[j-1] > t)) {  // ★★★ 最大热点
        heap2[j] = heap2[j-1];
        outc[j] = outc[j-1];
        --j;
    }
    heap2[j] = t; outc[j] = c;
}
```

**编码** (按位输出 Huffman 码):
```c
for (j = 0; j < data_len; ++j) {
    mask = 1 << (clen[*dptr] - 1);
    for (i = 0; i < clen[*dptr]; ++i) {  // ★ 热点: 逐位处理
        if (bit == 7) { comp[comp_len] = bout; ... }
        else { ++bit; bout <<= 1; }
        if (code[*dptr] & mask) bout |= 1;
        mask >>= 1;
    }
    ++dptr;
}
```

**解码** (按位读取并查 trie):
```c
while (n < data_len) {
    k = k * 2 + 1;                      // 右链
    if ((*cptr) & mask) ++k;             // 左链
    while (heap2[i] < k) ++i;           // ★★ 热点: 线性搜索
    if (k == heap2[i]) {                 // 找到匹配
        (*dptr) = outc[i]; ...
        k = 0; i = j;                   // 重置
    }
    if (mask > 1) mask >>= 1;
    else { mask = 0x80; ++cptr; }
}
```

### 1.4 循环结构

| 阶段 | 循环 | 迭代次数/call | 说明 |
|------|------|--------------|------|
| 频率统计 | 500 iter | 500 | 遍历数据 |
| 建堆 | n~36 次 heap_adjust | ~36 | 非零频率符号数 |
| 建 trie | ~35 次 × 2 次 heap_adjust | ~70 | 合并节点 |
| 码表生成 | 256 × trie 深度 | ~256×5 | 遍历 link 链 |
| **编码** | 500 × 平均码长 | **~2500** | **逐位处理** |
| 建解码表 | 256 × 码长 | ~256×5 | 建 trie 路径 |
| **插入排序** | **255 × 平均比较次数** | **~7500** | **O(n^2) 最大热点** |
| **解码** | **500 × 平均码长 × 搜索** | **~8000** | **线性搜索 heap2** |

### 1.5 访存模式

| 数据结构 | 大小 | 类型 | 访问模式 |
|----------|------|------|---------|
| freq[512] | 4096B | size_t | 随机读 (按字符索引) |
| heap[256] | 2048B | size_t | 堆操作: 父子跳转 |
| link[512] | 2048B | int | trie 链遍历 |
| code[256] | 2048B | bits32 | 顺序读 |
| clen[256] | 256B | byte | 顺序读 |
| heap2[256] | 2048B | bits32 | **插入排序: 大量移位** |
| outc[256] | 256B | char | **插入排序: 随 heap2 同步移位** |
| comp[501] | 501B | byte | 编码顺序写, 解码顺序读 |
| test_data[500] | 500B | byte | 编码顺序读, 解码顺序写 |

**数据总量**: ~11KB (栈上分配) -> **主体驻 L1D, 但结构较多**
**堆分配**: comp 通过 malloc_beebs 从 8KB 堆中分配

### 1.6 计算特征

- **控制流密集型**: 大量条件分支 (bit==7, mask>1, heap2[i]<k)
- **运算类型**: 整数移位、比较、位操作为主, 无乘法
- **访存**: 插入排序有大量数据搬移 (heap2 是 8B 元素, outc 是 1B 元素)
- **分支不可预测性**: 解码阶段的 `heap2[i] < k` 搜索长度数据依赖, 不够规律
- **与 matmult-int 本质不同**: 非计算密集, 而是控制/访存密集

## 2. 汇编热点分析

### 2.1 Spike 执行概况
```
Total instructions: 2,151,291
Cycles:  2,151,288
Instret: 2,151,291
IPC: 1.0000 (spike 顺序执行)
```

### 2.2 核心函数反汇编

#### 插入排序内层循环 (最大热点)

```asm
  # === while ((j) && (heap2[j-1] > t)): 移位循环 ===
  10862:  ld    a2, -8(a5)            # a2 = heap2[j-1]
  10866:  bgeu  a0, a2, 0x1087c       # if (t >= heap2[j-1]) break  ★条件分支
  1086a:  lbu   a1, -1(a4)            # a1 = outc[j-1]
  1086e:  sd    a2, 0(a5)             # heap2[j] = heap2[j-1]  (8B 移位)
  10870:  addi  a3, a3, -1            # j--
  10872:  sb    a1, 0(a4)             # outc[j] = outc[j-1]  (1B 移位)
  10876:  addi  a5, a5, -8            # heap2 指针 -= 8
  10878:  addi  a4, a4, -1            # outc 指针 -= 1
  1087a:  bnez  a3, 0x10862           # j != 0 ? -> 继续

  # === 插入: heap2[j] = t; outc[j] = c ===
  1087c:  slli  a5, a3, 0x3           # a5 = j * 8
  10880:  add   a5, a5, s4            # a5 = &heap2[j] (基址偏移后)
  10882:  add   a3, a3, t4            # a3 = &outc[j] (基址偏移后)
  10884:  addi  a7, a7, 1             # i++
  10886:  sd    a0, -2048(a5)         # heap2[j] = t
  1088a:  sb    t3, -256(a3)          # outc[j] = c
  ...
  10892:  bne   a7, t6, 0x10854       # i < 256 ? -> 外层继续
```

#### 解码搜索循环 (第二热点)

```asm
  # === while (heap2[i] < k) ++i ===
  108d8:  ld    a3, 0(a5)             # a3 = heap2[i]
  108da:  addi  a5, a5, 8             # heap2 指针 += 8
  108dc:  addi  a4, a4, 1             # i++
  108de:  bltu  a3, a2, 0x108d8       # heap2[i] < k ? -> 继续  ★数据依赖分支

  # === if (k == heap2[i]): 匹配 ===
  108e2:  beq   a2, a3, 0x10930       # k == heap2[i] ? -> 输出字符
```

#### 编码位循环 (第三热点)

```asm
  # === 编码主循环入口 ===
  10714:  lbu   a5, 0(t6)             # a5 = *dptr (当前字符)
  10718:  mv    a7, a5                # 保存字符
  1071a:  add   a5, a5, t1            # a5 = &clen[*dptr]
  1071c:  lbu   a5, -512(a5)          # a5 = clen[*dptr] (码长)
  10720:  beqz  a5, 0x10756           # 码长=0 ? 跳过

  # === 逐位编码循环 ===
  10722:  addiw a5, a5, -1            # a5 = clen - 1
  10724:  sllw  a3, t0, a5            # a3 = 1 << (clen-1) (mask)
  10728:  li    a1, 0                 # a1 = 0 (位计数)
  1072a:  beq   a0, t4, 0x10822       # bit == 7 ? -> 输出 byte
  1072e:  addiw a0, a0, 1             # bit++
  10730:  slliw a2, a2, 0x1           # bout <<= 1
  10734:  sext.w a5, a7               # a5 = 当前字符
  10738:  slli  a4, a5, 0x3           # a4 = char * 8
  1073c:  add   a4, a4, t5            # a4 = &heap2[char] 实际是 &code[char]
  1073e:  ld    a4, 0(a4)             # a4 = code[char]
  10740:  add   a5, a5, t1            # a5 = &clen[char]
  10742:  addi  a1, a1, 1             # i++
  10744:  and   a4, a4, a3            # a4 = code & mask
  10746:  beqz  a4, 0x1074c           # 位 = 0 ? 跳过
  10748:  ori   a2, a2, 1             # bout |= 1
  1074c:  lbu   a5, -512(a5)          # a5 = clen[char] (重读)
  10750:  srli  a3, a3, 0x1           # mask >>= 1
  10752:  bltu  a1, a5, 0x1072a       # i < clen ? -> 继续
```

### 2.3 热点 PC 分布

| 区域 | PC 范围 | 每 PC 执行次数 | 指令数 | 总执行次数 | 占比 |
|------|---------|---------------|--------|-----------|------|
| **解码搜索** `while(heap2[i]<k)` | `0x108d8 - 0x108de` | **92,940** | 4 | **371,760** | **17.3%** |
| **插入排序内层** | `0x10862 - 0x1087a` | **67,692~70,752** | 9 | **~609,000** | **28.3%** |
| **编码位循环** | `0x1072a - 0x10752` | **29,928** | ~14 | **~419,000** | **19.5%** |
| 解码外层 (位处理) | `0x108ba - 0x108ec` | 16,008~29,928 | ~14 | **~290,000** | **13.5%** |
| 插入排序外层 + 建解码表 | `0x10792 - 0x10842` | 3,060~3,732 | ~20 | ~70,000 | 3.3% |
| 频率统计 | `0x10570 - 0x10580` | 6,000 | 6 | 36,000 | 1.7% |
| 建 trie + heap_adjust | `0x10426 - 0x104ba` | ~3,072 | ~20 | ~60,000 | 2.8% |
| 码表生成 | `0x10692 - 0x106e2` | ~3,000 | ~15 | ~45,000 | 2.1% |
| memset (初始化) | 多段 | 12 | 多段 | ~60,000 | 2.8% |
| pk/bbl 系统开销 | — | — | — | ~190,531 | 8.9% |
| **合计** | — | — | — | **~2,151,291** | **100%** |

**执行次数验证**:
- 插入排序: 255 × (平均比较次数) × 12 calls = 67,692 per PC
  - 平均比较次数 ≈ 67,692 / (255 × 12) ≈ 22.1 (合理, 大部分元素为 0 排在前面)
- 解码搜索: 500 × (平均搜索步数) × 12 = 92,940 per PC
  - 平均搜索步数 ≈ 92,940 / (500 × 12) ≈ 15.5 (线性搜索, 数据依赖)
- 编码: 500 × (平均码长) × 12 = 29,928 per PC
  - 平均码长 ≈ 29,928 / (500 × 12) ≈ 4.99 (合理, Huffman 平均码长 ~5 bit)

### 2.4 内层循环微架构分析

#### 插入排序内层 (9 条/iter, 最大热点 28.3%)

**指令混合**:
- ld: 1 (11%) — 读 heap2[j-1]
- lbu: 1 (11%) — 读 outc[j-1]
- sd: 1 (11%) — 写 heap2[j]
- sb: 1 (11%) — 写 outc[j]
- addi: 3 (33%) — j--, 指针递减
- bgeu: 1 (11%) — break 条件
- bnez: 1 (11%) — 循环条件

**关键依赖链**:
```
ld a2,-8(a5) ──> bgeu a0,a2 (break 判断)
```
延迟: ld(2) + bgeu(1) = 3 cycles (最短路径)

**循环携带依赖**:
- `a5`/`a4`/`a3`: 指针递减, 1-cycle, 是下一次 ld 的地址源
- 关键: `a5 = a5-8` -> `ld a2,-8(a5)`, 地址依赖链仅 1 cycle

**预计 IPC (OoO core)**:
- 9 条 / 3 cycles ≈ 3.0 (理想情况, 无 break)
- 但 bgeu 是数据依赖分支: 比较结果取决于 ld 加载的数据, 分支预测准确率受数据分布影响
- 排序过程中 break 位置不规律, 分支误预测率可能较高
- 实际 IPC 可能降至 1.5~2.0

#### 解码搜索循环 (4 条/iter, 17.3%)

**指令混合**:
- ld: 1 (25%) — 读 heap2[i]
- addi: 2 (50%) — 指针递增, i++
- bltu: 1 (25%) — 循环条件

**关键依赖链**:
```
ld a3,0(a5) ──> bltu a3,a2 (搜索判断)
```
延迟: ld(2) + bltu(1) = 3 cycles

**循环携带依赖**:
- `a5`: 指针递增, 1-cycle, 不是瓶颈
- `a3` (ld 结果): 无携带, 每次独立加载

**预计 IPC (OoO core)**:
- 4 条 / 3 cycles ≈ 1.33
- 搜索长度数据依赖, bltu 分支在找到目标时 break, 不规律
- 线性搜索效率低, 每次解码一个字符都要搜索 ~15.5 步平均

## 3. 总结

```
算法:           Huffman 压缩 + 解压 (500B 数据)
数据量:         ~11KB (freq/heap/link/code/clen/heap2/outc, 栈上分配)
计算类型:       控制流密集 (分支/比较/位操作), 无乘法
热点分布:       插入排序 28.3% + 编码 19.5% + 解码搜索 17.3% + 解码外层 13.5%
                无单一主导热点, 执行分散
瓶颈预测:       control-flow-bound (数据依赖分支, 分支预测压力大)
                + memory-bound (插入排序的 ld/sd 数据搬移)
分支特征:       插入排序 break 位置不规律, 解码搜索长度数据依赖
                与 matmult-int 的可预测循环分支截然不同
特殊观察:       O(n^2) 插入排序是性能瓶颈, 若换为 O(n log n) 可显著加速
```
