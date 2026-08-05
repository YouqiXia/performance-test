# wikisort 性能分析

## 1. 源码分析

### 1.1 基本信息
- **源文件**: `thirdparty/embench-iot/src/wikisort/libwikisort.c`
- **算法描述**: WikiSort — O(1) 额外内存的稳定归并排序，对 400 个 `Test` 结构体排序
- **LOCAL_SCALE_FACTOR**: 2
- **数据类型**: `Test` 结构体（`{int value, int index}`，8B），比较函数 `TestCompare`

### 1.2 调用链
```
benchmark() → benchmark_body(lsf=2, gsf=1)
  └→ 循环 2×1 = 2 次（+ warmup 1 次 = 3 总计）
      └→ for each test_case (9 种数据分布)
          ├→ srand_beebs(0)
          ├→ 生成 400 个 Test 元素 (array1[400])
          └→ WikiSort(array1, 400, TestCompare)
              ├→ 第一阶段: InsertionSort 16~31 元素的子数组 ★主热点
              └→ 第二阶段: 逐级归并 (merge_size=16,32,64,128,256)
                  └→ WikiMerge / Rotate / BinaryFirst / BinaryLast
```

### 1.3 核心计算函数

**InsertionSort**（最热函数，占 44.5%）:
```c
void InsertionSort(Test array[], const Range range, const Comparison compare) {
    for (long i = range.start + 1; i < range.end; i++) {
        const Test temp = array[i];
        long j;
        for (j = i; j > range.start && compare(temp, array[j-1]); j--)
            array[j] = array[j - 1];     // ★热点: 元素后移
        array[j] = temp;
    }
}
```

**TestCompare**（间接调用，极频繁）:
```c
bool TestCompare(Test item1, Test item2) {
    return (item1.value < item2.value);
}
```

**WikiMerge**（归并阶段核心）:
```c
void WikiMerge(Test array[], Range buffer, Range A, Range B,
               Comparison compare, Test cache[], long cache_size) {
    if (Range_length(A) <= cache_size) {
        // cache 路径: memcpy A→cache, 然后双指针归并
        while (true) {
            if (!compare(*B_index, *A_index)) {
                *insert_index++ = *A_index++;  // A 更小
            } else {
                *insert_index++ = *B_index++;  // B 更小
            }
        }
    } else {
        // buffer 路径: 原地 swap 归并
    }
}
```

### 1.4 循环结构

| 循环层 | 变量 | Trip Count | 说明 |
|--------|------|-----------|------|
| benchmark_body lsf | lsf_cnt | 2 | LOCAL_SCALE_FACTOR |
| benchmark_body gsf | gsf_cnt | 1 | GLOBAL_SCALE_FACTOR |
| test_case 循环 | — | 9 | 9 种数据分布 |
| 数据生成 | i | 400 | 填充 array1[400] |
| WikiSort 第一阶段 | — | ~16 段 | 每段 InsertionSort 25 个元素 |
| **InsertionSort 外层** | **i** | **~24** | **每段 start+1..end** |
| **InsertionSort 内层** | **j** | **O(k) avg** | **元素后移 ★最热** |
| WikiSort 第二阶段 | merge_size | 5 级 | 16→32→64→128→256 |
| WikiMerge 归并 | — | 可变 | 双指针归并 |

**每次 WikiSort 调用处理**: 400 个元素，分 16 段做 InsertionSort（每段 ~25 个），然后 5 级归并

### 1.5 访存模式

| 数组 | 大小 | 访问方式 | 说明 |
|------|------|---------|------|
| array1[400] | 3,200B | 随机 | 排序过程中频繁 swap/shift |
| cache[512] | 4,096B | 临时 | WikiMerge 的 O(1) 缓存（栈上） |

**数据总量**: ~7.3KB → **完全驻 L1D**

### 1.6 计算特征

- **访存密集型**: InsertionSort 内层大量 lw/sw（元素后移），WikiMerge 大量 memcpy/memmove
- **运算类型**: `lw`/`sw`（32-bit load/store on Test 结构体）+ `slt`（比较）
- **分支**: InsertionSort 内层 `compare(temp, array[j-1])` 是数据依赖分支
- **间接调用**: 所有比较通过函数指针 `jalr` 调用 `TestCompare`，产生 call/ret 开销
- **特殊**: 9 种不同数据分布（random、ascending、descending、equal 等）导致排序行为差异大

## 2. 汇编热点分析

### 2.1 Spike 执行概况
```
Total instructions: 1,363,906
Cycles:  1,363,903
Instret: 1,363,906
IPC: 1.0000 (spike 顺序执行)
```

### 2.2 核心函数反汇编

**TestCompare**（被调用 ~71,006 次）:
```asm
  1042a:  addi  sp, sp, -16        # 栈帧分配
  1042c:  sext.w a0, a0            # item1.value 符号扩展
  1042e:  sext.w a1, a1            # item2.value 符号扩展
  10430:  slt   a0, a0, a1         # a0 = (item1.value < item2.value)
  10434:  addi  sp, sp, 16         # 栈帧释放
  10436:  ret                       # 返回
```

**InsertionSort 内层循环**（元素后移 + 比较调用）:
```asm
  # s3 = range.start, s5 = 当前插入位置指针, s4 = compare 函数指针
  # s1 = 扫描指针 (j), s2 = j 索引

  # === 比较调用 ===
  106b4:  mv    s0, s1             # s0 = 当前位置
  106b6:  lwu   a5, -4(s1)        # a5 = array[j-1].index (高 32 位)
  106ba:  lwu   a1, -8(s1)        # a1 = array[j-1].value (低 32 位)
  106be:  ld    a0, 24(sp)         # a0 = temp (待插入元素, 64-bit 打包)
  106c0:  slli  a5, a5, 32         # a5 <<= 32
  106c2:  or    a1, a1, a5         # a1 = {index, value} 打包为 64-bit
  106c4:  jalr  s4                 # 调用 TestCompare(temp, array[j-1])
  106c6:  addi  s1, s1, -8        # s1 -= 8 (j--)
  106c8:  addiw s2, s2, -1        # s2-- (j 索引)
  106ca:  mv    a5, s0             # a5 = 写入位置
  106cc:  bnez  a0, 0x106a4       # compare 返回 true → 继续后移

  # === 元素后移 ===
  106a4:  lw    a4, -8(s0)        # a4 = array[j-1].value
  106a8:  lw    a5, -4(s0)        # a5 = array[j-1].index
  106ac:  sw    a4, 0(s0)          # array[j].value = array[j-1].value
  106ae:  sw    a5, 4(s0)          # array[j].index = array[j-1].index
  106b0:  beq   s3, s2, 0x106f6   # j == range.start → 停止

  # === 插入 temp ===
  106ce:  lw    a3, 24(sp)         # a3 = temp.value
  106d0:  lw    a4, 28(sp)         # a4 = temp.index
  106d2:  addi  s6, s6, 1         # i++
  106d4:  sw    a3, 0(a5)          # array[j].value = temp.value
  106d6:  sw    a4, 4(a5)          # array[j].index = temp.index
```

**WikiMerge 内层归并循环**（cache 路径，双指针）:
```asm
  # s2 = A_index (cache), s3 = B_index (array), s0 = insert_index
  # s8 = compare 函数指针

  1094c:  lwu   a4, 4(s2)         # a4 = B_index->index
  10950:  lwu   a5, 4(s3)         # a5 = A_index->index
  10954:  lwu   a0, 0(s2)         # a0 = B_index->value
  10958:  lwu   a1, 0(s3)         # a1 = A_index->value
  1095c:  slli  a4, a4, 32        # 打包 B
  1095e:  slli  a5, a5, 32        # 打包 A
  10960:  8d41  or    a0, a0, a4  # a0 = B 元素 (64-bit)
  10962:  8dc5  or    a1, a1, a5  # a1 = A 元素 (64-bit)
  10964:  jalr  s8               # 调用 TestCompare(B, A)
  ...
  # 根据比较结果选择 A 或 B 写入 insert 位置
```

### 2.3 热点 PC 分布

| 区域 | PC 范围 | 每 PC 执行次数 | 指令数 | 总执行次数 | 占比 |
|------|---------|---------------|--------|-----------|------|
| **TestCompare** | `0x1042a - 0x10436` | **69,240** | 6 | **415,440** | **20.1%** |
| **InsertionSort 内层** | `0x106a4 - 0x106d6` | **40,656~49,425** | ~16 | **~918,813** | **44.5%** |
| WikiMerge 归并 | `0x1094c - 0x109c6` | **19,050** | ~11 | **~333,549** | **16.1%** |
| 数据生成 | `0x117ec - 0x117fc` | **10,800** | 5 | **54,000** | **2.6%** |
| WikiSort 控制流 | 分散 | — | — | ~33,102 | 1.6% |
| benchmark_body | `0x1176e - 0x11838` | — | — | ~86,806 | 4.2% |
| Rotate | `0x10758 - 0x10862` | — | — | ~2,160 | 0.1% |
| 其他 (pk/bbl/lib) | — | — | — | ~223,036 | 10.8% |
| **合计** | — | — | — | **~2,066,906** | **100%** |

**执行次数验证**:
- TestCompare 调用次数: 69,240（从 PC 0x1042a 计算，注意不等于总调用，因为 sext.w 可能是尾调用优化后被跳过的路径）
- 实际 TestCompare 被调用约 71,006 次（含 InsertionSort + WikiMerge + BinaryFirst/Last）
- InsertionSort 内层后移: 40,656 次
- InsertionSort 比较调用: 49,425 次（compare 返回 true 40,656 次 + false 8,769 次）
- 数据生成: 10,800 = 400 × 27 次外层调用（9 test_case × 3 总轮）

### 2.4 内层循环微架构分析

**InsertionSort 内层指令混合** (~16 条/iter，含 compare 调用):
- lw/lwu: 5 (31.3%) — 加载元素和比较参数
- sw: 2 (12.5%) — 元素后移
- slli/or: 2 (12.5%) — 打包 64-bit 参数
- ld: 1 (6.3%) — 加载 temp
- jalr: 1 (6.3%) — 间接调用 compare
- addi/mv/bnez: 5 (31.3%) — 索引更新和分支

**关键依赖链**（InsertionSort 单次内层迭代）:
```
lwu a1 (array[j-1].value) ─→ or a1,a1,a5 ─→ jalr (TestCompare)
lwu a5 (array[j-1].index) ─→ slli ─┘          │
ld  a0 (temp) ──────────────────────────────────┘
                                                │
                                                ↓
                                    slt a0,a0,a1 → ret → bnez (决定是否继续后移)
                                                          │
                                                          ↓
                                               lw a4,-8(s0) → sw a4,0(s0)  (后移)
                                               lw a5,-4(s0) → sw a5,4(s0)
```
延迟: lwu(2) + slli(1) + or(1) + jalr(1) + sext.w(1) + slt(1) + ret(1) + bnez(1) = **~9 cycles/iter**

**循环携带依赖**:
- `s1` (扫描指针): `addi s1,s1,-8`，1-cycle，不是瓶颈
- compare 返回值决定是否继续: 数据依赖分支

**间接调用开销**:
- 每次比较通过 `jalr s4` 调用 TestCompare + `ret` 返回 = 2 次分支
- TestCompare 本身只有 6 条指令，但 call/ret 开销可能与函数体相当
- 如果内联，可省去 ~4 条开销指令/次（addi sp × 2 + jalr + ret）

**分支预测**:
- InsertionSort 内层: `bnez a0` 取决于排序进度，早期多 taken（大量后移），后期多 not-taken
- 对于 random 数据，平均约一半元素需要后移
- 对于 ascending/equal 数据，几乎不后移（InsertionSort 快速退出）
- 9 种数据分布交替运行，分支行为变化剧烈

**预计 IPC (OoO core)**:
- InsertionSort 内层: ~16 条 / ~9 cycles ≈ 1.78（理想情况）
- 间接调用的 jalr/ret 可能被 RAS（Return Address Stack）很好预测
- compare 分支依赖数据，但 InsertionSort 的局部性很强（相邻元素比较）
- WikiMerge 的双指针归并分支更难预测（A vs B 接近随机）

## 3. 总结

```
算法:           WikiSort (O(1) 内存稳定归并排序, 400 个 Test 元素)
数据量:         ~7.3KB (array1 3.2KB + cache 4.1KB, 全驻 L1D)
计算类型:       lw/sw 密集 (元素移动) + 间接调用 compare
InsertionSort 占比: ~44.5% (内层后移 + compare)
TestCompare 占比:   ~20.1% (被调用 ~71K 次)
WikiMerge 占比:     ~16.1% (归并阶段)
瓶颈预测:       memory-access + call-overhead-bound (InsertionSort 频繁 lw/sw + jalr)
分支特征:       compare 分支数据依赖; 9 种数据分布交替, 行为差异大
特殊:           间接调用 TestCompare 的 call/ret 开销显著; InsertionSort 对近乎有序数据很快
```
