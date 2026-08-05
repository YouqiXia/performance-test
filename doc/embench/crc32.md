# crc32 性能分析

## 1. 源码分析

### 1.1 基本信息
- **源文件**: `thirdparty/embench-iot/src/crc32/crc_32.c`
- **算法描述**: CRC-32 校验和计算（ANSI X3.66 多项式），对 1024 个伪随机字节计算 CRC-32
- **LOCAL_SCALE_FACTOR**: 170
- **数据类型**: `DWORD`（unsigned long, 64-bit）, 查找表 `UNS_32_BITS`（unsigned long）

### 1.2 调用链
```
benchmark() → benchmark_body(lsf=170, gsf=1)
  └→ 循环 170×1 = 170 次（+ warm_caches 1 次 = 171 次）
      ├→ srand_beebs(0)            — 重置 PRNG 种子
      └→ crc32pseudo()
          └→ 循环 1024 次
              ├→ rand_beebs()      — 生成伪随机字节
              └→ UPDC32(octet, crc) — CRC-32 查表更新
```

### 1.3 核心计算函数

**crc32pseudo** — CRC-32 计算主循环:
```c
DWORD crc32pseudo() {
    int i;
    register DWORD oldcrc32 = 0xFFFFFFFF;
    for (i = 0; i < 1024; ++i) {
        oldcrc32 = UPDC32(rand_beebs(), oldcrc32);
    }
    return ~oldcrc32;
}
```

**UPDC32 宏** — CRC-32 查表更新:
```c
#define UPDC32(octet, crc) (crc_32_tab[((crc) ^ ((BYTE)octet)) & 0xff] ^ ((crc) >> 8))
```

**rand_beebs** — 线性同余 PRNG:
```c
// seed = seed * 1103515245 + 12345, 返回 (seed >> 16) & 0x7fff
```

### 1.4 循环结构

| 循环层 | 变量 | Trip Count | 说明 |
|--------|------|-----------|------|
| benchmark_body 外层 | lsf_cnt | 170 | LOCAL_SCALE_FACTOR |
| benchmark_body 内层 | gsf_cnt | 1 | GLOBAL_SCALE_FACTOR |
| **crc32pseudo** | **i** | **1024** | **CRC 查表更新（最内层热点）** |

### 1.5 访存模式

| 数据 | 访问方式 | 说明 |
|------|---------|------|
| crc_32_tab[256] | 随机查表 | 256 × 8B = 2KB, 索引由 CRC⊕随机数低 8 位决定 |
| seed | 读-改-写 | 1 个 64-bit 全局变量, 每次 rand_beebs 调用更新 |

**数据总量**: CRC 查找表 2KB + seed 8B → **完全驻 L1D**

### 1.6 计算特征

- **混合型**: rand_beebs 是纯计算（mul + add + shift）, CRC 更新是查表（ld + xor + shift）
- **运算类型**: `mul`（PRNG）, `xor`, `srli`, `andi`（CRC 更新）, `ld`（查表）
- **分支**: 单层循环, trip count=1024, 高度可预测
- **编译器优化**: crc32pseudo 和 rand_beebs 均内联到 benchmark_body; rand_beebs 通过 `jal` 调用（未完全内联, 因 volatile seed）

## 2. 汇编热点分析

### 2.1 Spike 执行概况
```
Total instructions: 4,006,267
Cycles:  4,006,264
Instret: 4,006,267
IPC: 1.0000 (spike 顺序执行)
```

用户态指令: 4,046,367（含 pk 启动）

### 2.2 核心函数反汇编

**benchmark_body 内 CRC 主循环 (0x10460-0x10478) + rand_beebs (0x104d6-0x104fc)**:

```asm
  # === CRC 内层循环 (1024 次) ★★★ 热点 ===
  10460:  jal   ra, 0x104d6       # 调用 rand_beebs()
  10464:  xor   a5, s0, a0        # a5 = oldcrc32 ^ rand_result
  10468:  andi  a5, a5, 255       # a5 = (crc ^ octet) & 0xff → 表索引
  1046c:  slli  a5, a5, 0x3       # a5 *= 8 (每个表项 8 字节)
  1046e:  add   a5, a5, s1        # a5 = &crc_32_tab[index]
  10470:  ld    a5, 0(a5)         # a5 = crc_32_tab[index]
  10472:  srli  s0, s0, 0x8       # s0 = oldcrc32 >> 8
  10474:  addiw s7, s7, -1        # i--
  10476:  xor   s0, s0, a5        # s0 = (oldcrc32 >> 8) ^ table[index] → 新 CRC
  10478:  bnez  s7, 0x10460       # i != 0 ? → 继续

  # === rand_beebs 函数 (0x104d6-0x104fc) ===
  104d6:  lui   a4, 0x7e          # a4 = 高位基址
  104da:  ld    a0, -1936(a4)     # a0 = seed (从内存加载)
  104de:  lui   a5, 0x41c65       # a5 = 1103515245 (高位)
  104e2:  addi  a5, a5, -403      # a5 = 1103515245 (LCG 乘数)
  104e6:  mul   a0, a0, a5        # a0 = seed * 1103515245
  104ea:  lui   a5, 0x3           # a5 = 12288 (高位)
  104ec:  addi  a5, a5, 57        # a5 = 12345 (LCG 加数)
  104f0:  add   a0, a0, a5        # a0 = seed * 1103515245 + 12345
  104f2:  slli  a0, a0, 0x21      # a0 <<= 33 (截断到 31 位)
  104f4:  srli  a0, a0, 0x21      # a0 >>= 33 (取低 31 位 = seed & 0x7fffffff)
  104f6:  sd    a0, -1936(a4)     # 存回 seed
  104fa:  srli  a0, a0, 0x10      # a0 = seed >> 16 (返回值)
  104fc:  ret                     # 返回到 CRC 循环
```

**编译器优化观察**:
- rand_beebs 未内联（因为 seed 是全局变量, 每次都要 ld/sd）
- CRC 主循环紧凑, 10 条指令 + 函数调用
- LCG 常量通过 lui+addi 分两步加载
- 无循环展开（-O2 对 trip count=1024 未展开）

### 2.3 热点 PC 分布

| 区域 | PC 范围 | 每 PC 执行次数 | 指令数 | 总执行次数 | 占比 |
|------|---------|---------------|--------|-----------|------|
| **CRC 内层循环** | `0x10460-0x10478` | **175,104** | 10 | **1,751,040** | **43.3%** |
| **rand_beebs** | `0x104d6-0x104fc` | **175,104** | 13 | **2,276,352** | **56.3%** |
| 外层循环 setup | `0x10452-0x1045c` | 171 | 4 | 684 | <0.1% |
| 外层循环尾部 | `0x1047c-0x10484` | 171 | 4 | 684 | <0.1% |
| srand_beebs | `0x104fe-0x1050a` | 171 | 5 | 855 | <0.1% |
| pk/bbl 系统开销 | — | — | — | ~18,752 | 0.5% |
| **合计** | — | — | — | **~4,046,367** | **100%** |

**执行次数验证**: 175,104 = (170 + 1) × 1024 = 171 × 1024 ✓

### 2.4 内层循环微架构分析

**指令混合** (CRC 循环 10 条 + rand_beebs 13 条 = 23 条/iter):
- jal/ret: 2 (8.7%) — 函数调用开销
- ld/sd: 3 (13.0%) — seed 读写 + 查表
- mul: 1 (4.3%) — PRNG 乘法
- add/addi/addiw: 4 (17.4%) — 地址计算 + 常量加载
- lui: 3 (13.0%) — 常量/基址加载
- xor/andi: 3 (13.0%) — CRC/PRNG 逻辑
- slli/srli: 4 (17.4%) — 移位操作
- bnez: 1 (4.3%) — 循环控制

**关键依赖链 (每次迭代)**:
```
[rand_beebs]
ld seed ──→ mul seed,seed,const ──→ add seed,seed,const ──→ slli ──→ srli ──→ sd seed
                                                                            └→ srli a0 (返回值)

[CRC update]
xor a5,s0,a0 ──→ andi a5,255 ──→ slli a5,3 ──→ add a5,a5,s1 ──→ ld a5,0(a5) ──→ xor s0,s0,a5
                                                                                     ↑
                                                                    srli s0,s0,8 ────┘
```

**循环携带依赖**:
1. **seed** (跨函数): `sd seed` → 下一迭代 `ld seed`, 延迟 = store-forwarding ~2-3 cycles
2. **s0** (CRC 累加器): `xor s0,s0,a5` → 下一迭代 `xor a5,s0,a0`, 延迟 = 1 cycle (ALU)

**关键路径分析**:
```
ld seed(2) → mul(3~4) → add(1) → slli(1) → srli(1) → sd(store)
                                                     → srli(1) → xor(1) → andi(1) → slli(1) → add(1) → ld table(2) → xor s0(1)
```
- rand_beebs 路径: ld(2) + mul(3~4) + add(1) + slli(1) + srli(1) + sd/srli(1) = ~9-10 cycles
- CRC 路径: xor(1) + andi(1) + slli(1) + add(1) + ld(2) + xor(1) = 7 cycles
- 但 CRC 路径等待 rand_beebs 返回值, 两段串行
- **总关键路径: ~12-14 cycles/iter** (受 ld→mul→...→ld 链限制)

**预计 IPC (OoO core)**:
- 23 条指令 / 12-14 cycles ≈ 1.6-1.9
- seed 的 store-forwarding 是潜在瓶颈
- 表查找 ld 依赖随机索引, 但表仅 2KB, 全在 L1D
- 分支高度可预测 (trip count=1024, 几乎 100% taken)
- jal/ret 开销: 现代 OoO 核的 RAS 可完美预测

## 3. 总结

```
算法:           CRC-32 查表法 + LCG 伪随机数
数据量:         2KB CRC 表 + 8B seed, 全驻 L1D
计算类型:       mul(PRNG) + ld(查表) + xor/shift(CRC 更新)
内层循环指令数: 23 条 (10 CRC + 13 rand_beebs)
内层循环占比:   99.5%
瓶颈预测:       compute-bound (ld→mul→...→ld 串行依赖链, ~12-14 cycles/iter)
分支特征:       单层循环 trip count=1024, 高度可预测, 无数据依赖分支
```
