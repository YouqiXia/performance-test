# tarfind 性能分析

## 1. 源码分析

### 1.1 基本信息

| 项目 | 值 |
|------|-----|
| 源文件 | `thirdparty/embench-iot/src/tarfind/tarfind.c` |
| 算法描述 | 模拟 TAR 归档文件中的文件名搜索，构建归档头数组后用线性搜索+字符串比较查找目标文件 |
| LOCAL_SCALE_FACTOR | 46 |
| 数据类型 | `tar_header_t`（257 字节结构体）、`char`（文件名）、`int`（索引） |
| 归档文件数 | ARCHIVE_FILES = 35 |
| 搜索次数 | N_SEARCHES = 5 |

### 1.2 调用链

```
benchmark()
  benchmark_body(46, 1)                // LSF=46, GSF=1
    for lsf_cnt in 0..45:
      for gsf_cnt in 0..0:
        init_heap_beebs(heap, 8995)    // 初始化堆
        malloc_beebs(8995)             // 分配 35 个 tar_header_t
        for i in 0..34:                // 构建归档
          memset(c, 0, 257)            // 清零结构体
          flen = 5 + i % 94            // 文件名长度 5..98
          c->isLink = '0'
          for p in 0..flen-1:          // 生成随机文件名
            c->filename[p] = rand_beebs() % 26 + 65  // 'A'..'Z'
        found = 0
        for p in 0..4:                 // 5 次搜索
          search = hdr[(p+17) % 35].filename  // 选择搜索目标
          for i in 0..34:              // 线性遍历归档
            // inline strcmp
            for c1,c2 = ...; *c1!=0 && *c2!=0 && *c1==*c2; c1++,c2++
            if (*c1==0 && *c2==0): found++; break
```

### 1.3 核心计算函数

**归档构建阶段**：
```c
for (i = 0; i < files; i++) {
  tar_header_t *c = &hdr[i];
  memset(c, 0, sizeof(tar_header_t));  // 257 字节清零
  int flen = 5 + i % 94;
  c->isLink = '0';
  for (p = 0; p < flen; p++) {
    c->filename[p] = rand_beebs() % 26 + 65;  // 伪随机大写字母
  }
  c->size[0] = '0';
}
```

**搜索阶段**（内联 strcmp）：
```c
for (p = 0; p < N_SEARCHES; p++) {
  char *search = hdr[(p + ARCHIVE_FILES/2) % ARCHIVE_FILES].filename;
  for (i = 0; i < files; i++) {
    char *c1, *c2;
    for (c1 = hdr[i].filename, c2 = search;
         (*c1 != '\0' && *c2 != '\0' && *c1 == *c2);
         c1++, c2++);
    if (*c1 == '\0' && *c2 == '\0') {
      found++;
      break;
    }
  }
}
```

**rand_beebs**（线性同余 PRNG）：
```c
// seed = seed * 1103515245 + 12345; return (seed >> 16) & 0x7fffffff;
```

### 1.4 循环结构

| 循环层 | 变量 | Trip Count | 说明 |
|--------|------|------------|------|
| L0 | lsf_cnt | 46 | LSF 缩放循环 |
| L1 | gsf_cnt | 1 | GSF 缩放循环 |
| L2a | i (构建) | 35 | 构建 35 个归档条目 |
| L3a | p (文件名) | 5..98 | 生成随机文件名字符，平均 ~51.5 |
| L2b | p (搜索) | 5 | 5 次搜索 |
| L3b | i (遍历) | 0..34 | 线性搜索归档 |
| L4b | c1,c2 (strcmp) | 1..~50 | 字符串比较，首字符不匹配则 1 次 |

**rand_beebs 调用次数**：每次外层迭代 sum(5+i%94 for i in 0..34) = 35*5 + sum(0..34) = 175 + 595 = 770 次。总计 46 x 770 = 35,420 次。

### 1.5 访存模式

- **堆上数组**：35 个 `tar_header_t`（每个 257 字节），总 8,995 字节，分配在静态堆上
- **顺序写入**：构建阶段顺序遍历每个结构体，memset 清零后逐字节写入文件名
- **随机读取**：搜索阶段按线性顺序遍历，但搜索目标来自数组中间位置
- **字节级比较**：strcmp 内层循环逐字节 lbu + 比较
- **工作集**：~9KB 堆 + 全局 PRNG 种子，L1D 可完全容纳

### 1.6 计算特征

- **三阶段**：(1) memset 清零 (2) rand_beebs + 字符生成 (3) 线性搜索 + strcmp
- **乘法密集**：rand_beebs 包含 64 位乘法（`mul`）+ 取模运算（`mul` + `mulw`）
- **字符比较**：搜索阶段核心是 lbu + beq/bne 循环
- **无浮点**：纯整数操作

## 2. 汇编热点分析

### 2.1 Spike 执行概况

| 指标 | 值 |
|------|-----|
| 总指令数 (instret) | 1,088,137 |
| 总周期数 (cycles) | 1,088,134 |
| IPC (spike) | 1.0000 |
| trace 总行数 | 1,905,744 |
| 用户态指令数 | ~1,248,552 |

### 2.2 核心函数反汇编

**rand_beebs()** (0x1059c，占 34.8%)：

```asm
1059c:  ld    a0, -2012(gp)        # seed = load global seed
105a0:  lui   a5, 0x41c65          # 乘数高位 = 0x41C65000
105a4:  addi  a5, a5, -403         # a5 = 0x41C64E6D (= 1103515245)
105a8:  mul   a0, a0, a5           # seed * 1103515245
105ac:  lui   a5, 0x3              # 加数高位
105ae:  addi  a5, a5, 57           # a5 = 0x3039 (= 12345)
105b2:  add   a0, a0, a5           # seed + 12345
105b4:  slli  a0, a0, 0x21         # 左移 33 位（清除高 33 位）
105b6:  srli  a0, a0, 0x21         # 右移 33 位（保留低 31 位）
105b8:  sd    a0, -2012(gp)        # 存回 global seed
105bc:  srli  a0, a0, 0x10         # >> 16（取高 15 位作为返回值）
105be:  ret
```

**构建阶段的字符生成循环** (0x104aa - 0x104ce)：

```asm
# rand_beebs() 返回后，计算 result % 26 + 65
104aa:  jal   rand_beebs            # a0 = rand_beebs()
104ae:  mul   a5, a0, s1            # a5 = a0 * 0x4EC4EC4F (magic number for /26)
104b2:  sraiw a3, a0, 0x1f          # a3 = sign extension
104b6:  addi  s8, s8, 1             # 指针递增
104b8:  srai  a5, a5, 0x23          # a5 >>= 35 (完成 /26)
104ba:  subw  a5, a5, a3            # 修正负数除法
104bc:  mulw  a5, s2, a5            # a5 = 26 * (a0/26)
104c0:  subw  a0, a0, a5            # a0 = a0 % 26 (取余)
104c2:  addiw a0, a0, 65            # a0 += 'A'
104c6:  sb    a0, -1(s8)            # 存储字符到 filename
104ca:  bne   s8, s0, 104aa         # 循环直到 flen 个字符
```

**搜索阶段的内联 strcmp 循环** (0x104f6 - 0x10522)：

```asm
# 外层：遍历所有 header
104f4:  mv    a1, s6                # a1 = &hdr[0]（搜索起始）
104f6:  lbu   a4, 0(a1)            # a4 = hdr[i].filename[0]
104fa:  mv    a3, a1               # c1 = &hdr[i].filename
104fc:  mv    a5, a0               # c2 = search
104fe:  bnez  a4, 1050c            # filename[0] != 0 则进入比较
10500:  j     10560                # 空文件名，检查是否完全匹配

# 内层：逐字符比较
10502:  bne   a2, a4, 10516        # *c2 != *c1 -> 不匹配，下一个 header
10506:  lbu   a4, 0(a3)            # a4 = *c1（下一个字符）
1050a:  beqz  a4, 10560            # *c1 == 0 -> 到达末尾
1050c:  lbu   a2, 0(a5)            # a2 = *c2（搜索字符串的下一个字符）
10510:  addi  a3, a3, 1            # c1++
10512:  addi  a5, a5, 1            # c2++
10514:  bnez  a2, 10502            # *c2 != 0 则继续比较

# 不匹配，移动到下一个 header
10516:  addi  a1, a1, 257          # a1 += sizeof(tar_header_t)
1051a:  bne   a6, a1, 104f6        # 未遍历完则继续

# 外层搜索移动到下一个目标
1051e:  addi  a0, a0, 257          # search 指向下一个搜索目标
10522:  bne   a0, a7, 104f4        # 5 次搜索未完则继续
```

### 2.3 热点 PC 分布

| 函数 | 指令数 | 占比 | 说明 |
|------|--------|------|------|
| benchmark_body() | 508,053 | 40.7% | 包含搜索循环和构建循环 |
| rand_beebs() | 434,656 | 34.8% | PRNG（每次 12 条指令） |
| memset() | 299,916 | 24.0% | 清零 tar_header_t 结构体 |
| malloc_beebs() | 846 | 0.1% | 堆分配（仅 46 次调用） |

**benchmark_body 内部 PC 分布**：
- 构建循环（0x104aa-0x104da）：每个 PC 执行 36,190 次 = 46 x 770 + 余量
- 搜索循环（0x104f6-0x10522）：每个 PC 执行 10,244 次（外层）或 5,779 次（strcmp 内层）

### 2.4 内层循环微架构分析

**rand_beebs 循环**（构建阶段热点）：

```
ld seed -> mul -> add -> slli -> srli -> sd seed -> srli -> ret
                                                          -> mul -> sraiw -> ...
```

- 关键路径：`ld seed` -> `mul` -> `add` -> `slli` -> `srli` -> `sd seed`
- 循环携带依赖：seed 的 load-mul-store-load 链，但 store forwarding 可避免实际 L1D 访问
- mul 延迟（通常 3-4 cycles）是瓶颈
- 每次 rand_beebs 调用 12 条指令，加上调用者的取模计算（mul + mulw + sub + addi + sb）约 7 条
- 总计每字符生成 ~19 条指令 + jal/ret 开销

**搜索阶段 strcmp 内层循环**：

```
lbu a4, (a3) -> [pipeline]
lbu a2, (a5) -> [pipeline]
bne a2, a4   -> [depends on both loads]
addi a3, 1
addi a5, 1
bnez a2      -> [depends on a2 load]
```

- 6 条指令/iteration
- 两个独立的 lbu 可并行发出
- load-to-branch 延迟：lbu (1 cycle L1D hit) -> bne/bnez
- 循环携带依赖：a3/a5 指针递增（1 cycle），不在关键路径上
- 分支预测：首字符比较（大部分不匹配）高度可预测，但匹配路径的比较次数不定

**预计 IPC（乱序核）**：
- rand_beebs 调用链：mul 延迟限制，预计 IPC ~1.5-2.0
- strcmp 循环：2 个独立 lbu + 2 个 addi 可并行，但 load-to-branch 是关键路径，预计 IPC ~2.0-2.5
- memset：编译器可能用宽 store 展开，IPC 受 store 带宽限制，预计 IPC ~2.0-3.0
- 综合预计 IPC：1.5-2.0

## 3. 总结

| 项目 | 值 |
|------|-----|
| 算法 | TAR 归档文件名搜索（构建+线性查找+strcmp） |
| 数据量 | 35 个 257B 结构体 = ~9KB，5 次搜索 x 46 外层迭代 |
| 计算类型 | 整数乘法（PRNG）+ 字节比较（strcmp）+ 内存清零（memset） |
| 内层循环指令数 | rand_beebs: 12 条，strcmp: 6 条/字符 |
| 内层循环占比 | benchmark_body 40.7% + rand_beebs 34.8% + memset 24.0% = 99.5% |
| 瓶颈预测 | mul 延迟（PRNG 链）、load-to-branch（strcmp）、store 带宽（memset） |

**微架构敏感点**：
1. **乘法器延迟**：rand_beebs 中 `mul` 是循环携带依赖的瓶颈，mul 延迟直接决定 PRNG 吞吐率
2. **Store forwarding**：rand_beebs 的 seed 经历 sd -> ld 链（下一次调用），store forwarding 效率影响关键路径
3. **字节加载效率**：strcmp 循环的 lbu 对，两个独立地址的并行度取决于 load port 数量
4. **memset 优化**：257 字节清零，编译器/库是否用 sd 展开（8B 一次 vs 1B 一次）影响显著
5. **分支预测**：strcmp 的首字符比较大部分不匹配（26 种字母随机选择），预测为 not-taken 准确率高；搜索命中时的 break 跳转可预测性较差
6. **函数调用开销**：rand_beebs 每字符调用一次（jal+ret），若内联可消除约 2 条/调用的开销
