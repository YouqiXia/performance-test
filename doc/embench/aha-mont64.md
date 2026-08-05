# aha-mont64 性能分析

## 1. 源码分析

### 1.1 基本信息
- **源文件**: `thirdparty/embench-iot/src/aha-mont64/mont64.c`
- **算法描述**: Montgomery 乘法（Montgomery Multiplication）验证——用 MM 方法计算 (a*b)^4 mod m，并与直接计算结果对比
- **LOCAL_SCALE_FACTOR**: 472
- **数据类型**: `uint64_t`（64-bit unsigned integer）

### 1.2 调用链
```
benchmark() → benchmark_body(lsf=472, gsf=1)
  └→ 循环 472×1 = 472 次（+ warm_caches 1 次 = 473 次）
      ├→ 直接法: mulul64 × 3 + modul64 × 3  → p1 = (a*b)^4 mod m
      ├→ xbinGCD(hr, m, &rinv, &mprime)       → 求 r 的模逆和 m'
      ├→ modul64 × 2                          → abar, bbar (转换到 Montgomery 域)
      ├→ montmul × 3                          → p = (a*b)^4 mod m (MM 方法)
      ├→ mulul64 + modul64                    → 从 Montgomery 域转回
      └→ 比对 p == p1
```

### 1.3 核心计算函数

**mulul64** — 64×64→128 位乘法:
```c
void mulul64(uint64 u, uint64 v, uint64 *whi, uint64 *wlo) {
    unsigned __int128 result = (unsigned __int128)u * v;
    *wlo = result;
    *whi = result >> 64;
}
```
编译器使用 `mul` + `mulhu` 两条指令实现 128 位乘法。

**modul64** — 128÷64 取模（长除法）:
```c
uint64 modul64(uint64 x, uint64 y, uint64 z) {
    int64 i, t;
    for (i = 1; i <= 64; i++) {           // 固定 64 次迭代
        t = (int64)x >> 63;               // 算术右移取符号位
        x = (x << 1) | (y >> 63);         // 128-bit 左移
        y = y << 1;
        if ((x | t) >= z) { x = x - z; y = y + 1; }
    }
    return x;
}
```

**xbinGCD** — 扩展二进制 GCD（求模逆）:
```c
void xbinGCD(uint64 a, uint64 b, volatile uint64 *pu, volatile uint64 *pv) {
    uint64 alpha = a, beta = b, u = 1, v = 0;
    while (a > 0) {                        // 固定 64 次迭代（a 从 2^63 降到 0）
        a = a >> 1;
        if ((u & 1) == 0) { u >>= 1; v >>= 1; }
        else { u = ((u ^ beta) >> 1) + (u & beta); v = (v >> 1) + alpha; }
    }
    *pu = u; *pv = v;
}
```

**montmul** — Montgomery 乘法:
```c
uint64 montmul(uint64 abar, uint64 bbar, uint64 m, uint64 mprime) {
    uint64 thi, tlo, tm, tmmhi, tmmlo, uhi, ulo, ov;
    mulul64(abar, bbar, &thi, &tlo);       // t = abar * bbar (128-bit)
    tm = tlo * mprime;                      // tm = t_lo * m' (取低 64 位)
    mulul64(tm, m, &tmmhi, &tmmlo);        // tmm = tm * m (128-bit)
    ulo = tlo + tmmlo;                     // 128-bit 加法
    uhi = thi + tmmhi;
    if (ulo < tlo) uhi++;                  // 进位
    ov = (uhi < thi) | ((uhi == thi) & (ulo < tlo));
    ulo = uhi;                             // 右移 64 位
    ulo = ulo - (m & -(ov | (ulo >= m)));  // 条件减法（无分支）
    return ulo;
}
```

### 1.4 循环结构

| 循环层 | 变量 | Trip Count | 说明 |
|--------|------|-----------|------|
| benchmark_body 外层 | lsf_cnt | 472 | LOCAL_SCALE_FACTOR |
| benchmark_body 内层 | gsf_cnt | 1 | GLOBAL_SCALE_FACTOR |
| **modul64 内层** | **i** | **64** | **128÷64 长除法, 固定 64 次** |
| **xbinGCD 内层** | **while(a>0)** | **64** | **扩展 GCD, a 从 2^63 降到 0** |

每次 benchmark_body 迭代包含:
- 7 个 modul64 调用（各 64 次内层循环）
- 1 个 xbinGCD 调用（64 次内层循环）
- 3 个 montmul 调用（纯直线代码, 无循环）
- 7 个 mulul64 调用（内联为 2 条指令）

### 1.5 访存模式

| 数据 | 说明 |
|------|------|
| in_a, in_b, in_m | 3 个 64-bit 全局变量, 循环开始前加载到寄存器 |
| rinv, mprime | volatile 局部变量, 通过栈传递 |
| 中间变量 | 全部在寄存器中 |

**数据总量**: 极小, 几个 64-bit 标量, 完全驻寄存器/L1D。无数组访存。

### 1.6 计算特征

- **纯计算密集型**: 无数组, 无内存瓶颈, 全部是 64-bit 整数 ALU 运算
- **运算类型**: `mul`, `mulhu`（128 位乘法）, `slli`, `srli`, `srai`（移位）, `or`, `xor`, `and`（位运算）, `sub`, `add`, `bltu`, `bnez`（分支）
- **分支**: modul64 内层有数据依赖的条件分支 (`if (x|t) >= z`), 取决于输入数据, 约 50% taken
- **编译器优化**: 所有函数完全内联到 `benchmark_body`, 无函数调用开销

## 2. 汇编热点分析

### 2.1 Spike 执行概况
```
Total instructions: 2,133,489
Cycles:  2,133,486
Instret: 2,133,489
IPC: 1.0000 (spike 顺序执行)
```

用户态指令: 2,154,662（含 pk 启动）

### 2.2 核心函数反汇编

编译器将所有函数内联到 `benchmark_body` (0x10426-0x106a6), 总长 640 字节。关键区域:

**modul64 内联循环 (以第 1 个为例, 0x10462-0x10480)**:
```asm
  # === modul64 loop: 64 次迭代 ===
  10462:  srli  s0, a4, 0x3f      # s0 = y >> 63 (取 y 最高位)
  10466:  slli  t2, a5, 0x1       # t2 = x << 1
  1046a:  srai  a3, a5, 0x3f      # a3 = (int64)x >> 63 (符号位扩展)
  1046e:  or    a5, s0, t2        # a5 = (x << 1) | (y >> 63) → 新 x
  10472:  or    a3, a3, a5        # a3 = t | x (用于比较)
  10474:  addi  a2, a2, -1        # i--
  10476:  slli  a4, a4, 0x1       # a4 = y << 1 → 新 y
  10478:  bltu  a3, a1, 0x10480   # if ((x|t) < m) skip subtraction
  # --- 条件执行 (约 53% taken) ---
  1047c:  sub   a5, a5, a1        # x = x - m
  1047e:  addi  a4, a4, 1         # y = y + 1
  # ---
  10480:  bnez  a2, 0x10462       # i != 0 ? → 继续
```

**xbinGCD 内联循环 (0x104e2-0x10500)**:
```asm
  # === xbinGCD loop: 64 次迭代 ===
  104e2:  xor   a4, a1, a2        # a4 = beta ^ u
  104e6:  andi  t2, a2, 1         # t2 = u & 1
  104ea:  and   s2, a1, a2        # s2 = beta & u
  104ee:  srli  a4, a4, 0x1       # a4 = (beta ^ u) >> 1
  104f0:  srli  s0, s0, 0x1       # v >>= 1
  104f2:  srli  a2, a2, 0x1       # u >>= 1
  104f4:  beqz  t2, 0x104fe       # if ((u_old & 1) == 0) skip
  # --- 条件执行 (约 42% taken) ---
  104f8:  add   a2, s2, a4        # u = (beta & u) + ((beta ^ u) >> 1)
  104fc:  add   s0, s0, a6        # v = v + alpha
  # ---
  104fe:  addiw s1, s1, -1        # a--
  10500:  bnez  s1, 0x104e2       # a != 0 ? → 继续
```

**montmul 内联 (以第 1 个为例, 0x1055a-0x105ac)**:
```asm
  # === montmul: 纯直线代码, 无循环 ===
  1055a:  mul   a4, a2, a3        # tlo = abar * bbar (低 64 位)
  1055e:  ld    s5, 8(sp)         # 加载 mprime
  ...
  1056a:  mul   s5, s5, a4        # tm = tlo * mprime
  1056e:  mul   s4, s5, a1        # tmmlo = tm * m (低 64 位)
  10572:  mulhu a2, a2, a3        # thi = abar * bbar (高 64 位)
  10576:  add   a3, a4, s4        # ulo = tlo + tmmlo
  1057a:  sltu  s4, a3, a4        # carry = (ulo < tlo)
  1057e:  mulhu a3, s5, a1        # tmmhi = tm * m (高 64 位)
  10582:  add   a3, a3, a2        # uhi = tmmhi + thi
  10584:  add   a3, a3, s4        # uhi += carry
  10586:  sub   a4, a2, a3        # (溢出检测)
  1058a:  sltu  s5, a3, a1        # (uhi < m)?
  ...
  105a6:  neg   a4, a4            # 条件减法掩码
  105aa:  and   a4, a4, a1        # mask & m
  105ac:  sub   a3, a3, a4        # result = uhi - (mask & m)
```

### 2.3 热点 PC 分布

| 区域 | PC 范围 | 每 PC 执行次数 | 指令数 | 总执行次数 | 占比 |
|------|---------|---------------|--------|-----------|------|
| **modul64 ×7 (循环体)** | 多段 | **30,272** (always) | 9×7=63 | **1,907,136** | **88.5%** |
| modul64 ×7 (条件段) | 多段 | ~12k-16k (varies) | 2×7=14 | **187,308** | **8.7%** |
| **xbinGCD** (循环体) | `0x104e2-0x10500` | **30,272** | 9 | 归入上面 | — |
| xbinGCD (条件段) | `0x104f8-0x104fc` | **12,771** | 2 | 归入上面 | — |
| montmul ×3 (直线) | `0x1055a-0x10642` | 473 | 67 | **31,691** | **1.5%** |
| 其他 (setup/prologue) | — | 473 | ~30 | ~14,190 | 0.6% |
| pk/bbl 系统开销 | — | — | — | ~14,337 | 0.7% |
| **合计** | — | — | — | **~2,154,662** | **100%** |

**执行次数验证**:
- modul64/xbinGCD 每 PC: 30,272 = (472 + 1) × 64 = 473 × 64 ✓
- montmul 每 PC: 473 = 472 + 1 (lsf + warm_caches) ✓
- modul64 loop 1 条件段: 16,082 次 taken (53.1%), 数据依赖, 符合预期 ✓

### 2.4 内层循环微架构分析

**以 modul64 为代表** (占 97.2% 指令):

**指令混合** (每次迭代, 最多 11 条):
- 移位 (srli/slli/srai): 3 (27%)
- 逻辑运算 (or): 2 (18%)
- 分支 (bltu/bnez): 2 (18%)
- 算术 (addi): 1 (9%)
- 条件段 (sub/addi): 2 (18%, 约 50% 执行)
- 平均每次迭代: ~9.8 条指令

**关键依赖链**:
```
a5(x) ─→ srai a3,a5,63     ─→ or a3,a3,a5'  ─→ bltu a3,a1
      └→ slli t2,a5,0x1 ─┐
a4(y) ─→ srli s0,a4,63  ─┘→ or a5',s0,t2    (新 x)
      └→ slli a4,a4,1                        (新 y)
```

**循环携带依赖**:
- `a5` (x): `or a5,s0,t2` → 下一迭代的 `srai a3,a5,63` + `slli t2,a5,1`, 延迟 1 cycle (ALU→ALU)
- `a4` (y): `slli a4,a4,1` → 下一迭代的 `srli s0,a4,63`, 延迟 1 cycle
- 条件段: `bltu` 的结果依赖 `a3 = (x|t)`, 需要 x 和 t 都就绪

**分支预测挑战**:
- `bltu a3, a1` (条件减法): 取决于 128-bit 除法的中间值与除数的大小关系, 约 50% taken, **模式复杂, 难以预测**
- 这是本 benchmark 的关键微架构挑战: 数据依赖的条件分支, 每 64 次外层循环模式才重复

**预计 IPC (OoO core)**:
- 移位+逻辑链很短 (1-2 cycles), ALU 吞吐不是瓶颈
- **瓶颈在分支预测**: bltu 的方向依赖计算结果, 预测器难以学习
- 分支误预测将导致 pipeline flush, 预计 IPC 受限于分支预测准确率
- 乐观估计 IPC ~2.0-3.0, 悲观（大量误预测）~1.0-1.5

## 3. 总结

```
算法:           Montgomery 乘法验证 (64-bit)
数据量:         几个 64-bit 标量, 无数组, 全驻寄存器
计算类型:       int 移位/位运算密集 (srli/slli/srai/or/xor/and)
热点循环指令数: modul64: 9-11 条/iter, xbinGCD: 9-11 条/iter
热点循环占比:   97.2% (modul64 ×7 + xbinGCD ×1)
montmul 占比:   1.5% (纯直线 mul/mulhu 密集)
瓶颈预测:       branch-prediction-bound (modul64 中 ~50% taken 的数据依赖条件分支)
分支特征:       外层循环可预测; 内层 bltu 数据依赖, 约 50% taken, 难以预测
```
