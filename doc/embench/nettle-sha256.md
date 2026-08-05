# nettle-sha256 性能分析

## 1. 源码分析

### 1.1 基本信息
- **源文件**: `thirdparty/embench-iot/src/nettle-sha256/nettle-sha256.c`
- **算法描述**: SHA-256 哈希，对 56 字节消息计算 256-bit 摘要
- **LOCAL_SCALE_FACTOR**: 562
- **数据类型**: `uint32_t`（32-bit unsigned integer）
- **消息长度**: 56 字节 ("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")

### 1.2 调用链
```
benchmark() -> benchmark_body(lsf=562, gsf=1)
  +-> 循环 562x1 = 562 次
      +-> memset(buffer, 0, 32)
      +-> sha256_init(&ctx)               # 初始化 H0..H7
      +-> sha256_update(&ctx, 56, msg)    # 处理 56 字节消息
      |     +-> MD_UPDATE: 56 < 64, 仅 memcpy 到 ctx.block, 不触发 compress
      +-> sha256_digest(&ctx, 32, buffer)
            +-> sha256_write_digest()
                  +-> MD_PAD: 添加 padding, 56+1=57 > 56(=64-8), 需额外块
                  |     +-> COMPRESS(ctx, block)       # 第 1 次压缩 (padding 块)
                  +-> WRITE_UINT64(bit_count)
                  +-> COMPRESS(ctx, block)              # 第 2 次压缩 (长度块)
                  +-> _nettle_write_be32(32, digest, state)
```

### 1.3 核心计算函数

**SHA-256 ROUND 宏**:
```c
#define ROUND(a,b,c,d,e,f,g,h,k,data) do {
    h += S1(e) + Choice(e,f,g) + k + data;
    d += h;
    h += S0(a) + Majority(a,b,c);
} while (0)

// 其中:
#define S0(x) (ROTL32(30,x) ^ ROTL32(19,x) ^ ROTL32(10,x))
#define S1(x) (ROTL32(26,x) ^ ROTL32(21,x) ^ ROTL32(7,x))
#define Choice(x,y,z)   (z ^ (x & (y ^ z)))
#define Majority(x,y,z) ((x & y) ^ (z & (x ^ y)))
```

**消息调度扩展 (EXPAND)**:
```c
#define s0(x) (ROTL32(25,x) ^ ROTL32(14,x) ^ ((x) >> 3))
#define s1(x) (ROTL32(15,x) ^ ROTL32(13,x) ^ ((x) >> 10))
#define EXPAND(W,i) (W[(i)&15] += s1(W[((i)-2)&15]) + W[((i)-7)&15] + s0(W[((i)-15)&15]))
```

**压缩函数结构**:
```c
void _nettle_sha256_compress(uint32_t *state, const uint8_t *input, const uint32_t *k) {
    uint32_t data[16], A, B, C, D, E, F, G, H;

    // 1. 读入 16 个 32-bit word (big-endian)
    for (i = 0; i < 16; i++) data[i] = READ_UINT32(input + i*4);

    // 2. 初始化工作变量
    A..H = state[0..7];

    // 3. 前 16 轮: 直接使用 data[] (8 ROUND 展开 x 2 次循环)
    for (i = 0; i < 16; i += 8) {
        ROUND(A,B,C,D,E,F,G,H, k[0], data[0]);
        ROUND(H,A,B,C,D,E,F,G, k[1], data[1]);
        // ... 8 个 ROUND 完全展开
    }

    // 4. 后 48 轮: EXPAND + ROUND (16 ROUND 展开 x 3 次循环)
    for (; i < 64; i += 16) {
        ROUND(A,B,C,D,E,F,G,H, k[0], EXPAND(data, 0));
        ROUND(H,A,B,C,D,E,F,G, k[1], EXPAND(data, 1));
        // ... 16 个 ROUND+EXPAND 完全展开
    }

    // 5. 更新 state
    state[0..7] += A..H;
}
```

### 1.4 循环结构

| 循环层 | 变量 | Trip Count | 说明 |
|--------|------|-----------|------|
| benchmark_body 外层 | lsf_cnt | 562 | LOCAL_SCALE_FACTOR |
| benchmark_body 内层 | gsf_cnt | 1 | GLOBAL_SCALE_FACTOR |
| compress 调用 | — | 2/iter | sha256_write_digest 内 2 次 COMPRESS |
| data load | i | 16 | 读入 16 个 big-endian word |
| **前 16 轮** | **i** | **2** | **8 ROUND/body x 2 = 16 轮** |
| **后 48 轮** | **i** | **3** | **16 ROUND+EXPAND/body x 3 = 48 轮** |

### 1.5 访存模式

| 数据 | 访问方式 | 说明 |
|------|---------|------|
| K[64] | 顺序访问 | 64 个轮常量，256B，只读 |
| data[16] | 前 16 轮顺序, 后 48 轮环形 | 64B，在栈上，EXPAND 原地更新 |
| state[8] | 首尾各一次 | 32B，ctx 结构内 |
| ctx.block[64] | 输入数据 | 64B |

**数据总量**: K(256B) + data(64B) + state(32B) + block(64B) = 416B -> **完全驻 L1D/栈**

### 1.6 计算特征

- **纯计算密集型**: 几乎所有数据在寄存器或栈上，无 cache miss
- **运算类型**: 32-bit 旋转（sllw/srlw/addw）+ 位运算（and/xor/or）+ 加法（addw）
- **分支**: 仅循环控制分支，极少，高度可预测
- **核心特征**: 每个 ROUND 中 `h` 和 `d` 的更新形成串行依赖链；8 个工作变量轮换使用

## 2. 汇编热点分析

### 2.1 Spike 执行概况
```
Total instructions: 4,499,995
Total user instructions: 4,504,413
Cycles:  4,499,991
IPC: 1.0000 (spike 顺序执行)
```

### 2.2 核心函数反汇编

**单个 ROUND 展开**（约 38 条指令，以第 1 轮为例）:

```asm
# === S1(e) 计算 ===
10530:  srliw  t5, a3, 0x6          # t5 = e >> 6
10534:  slliw  t4, a3, 0x1a         # t4 = e << 26
10538:  srliw  t6, a3, 0xb          # t6 = e >> 11
1053c:  addw   t4, t4, t5           # t4 = ROTL32(26, e)
10540:  slliw  t5, a3, 0x15         # t5 = e << 21
10544:  addw   t5, t5, t6           # t5 = ROTL32(21, e)
10548:  xor    t4, t4, t5           # t4 ^= ROTL32(21, e)
1054c:  srliw  t6, a3, 0x19         # t6 = e >> 25
10550:  slliw  t5, a3, 0x7          # t5 = e << 7
10554:  addw   t5, t5, t6           # t5 = ROTL32(7, e)
10558:  lw     t0, 0(t1)            # t0 = k[round] (轮常量)
1055c:  xor    t5, t5, t4           # t5 = S1(e) = ROTL(26)^ROTL(21)^ROTL(7)

# === Choice(e,f,g) + 累加 ===
10560:  lw     t4, 0(t3)            # t4 = data[round] (消息字)
10564:  xor    t6, a4, a5           # t6 = f ^ g
10568:  and    t6, a3, t6           # t6 = e & (f ^ g)
1056c:  addw   t4, t4, t0           # t4 = data + k
10570:  xor    t6, a5, t6           # t6 = Choice(e,f,g) = g ^ (e & (f^g))
10574:  addw   t4, t4, t5           # t4 += S1(e)
10578:  srliw  t0, s5, 0x2          # (开始计算 S0(a))

# === h += S1(e) + Choice + k + data ===
1057c:  slliw  t5, s5, 0x1e         # S0(a) 的一部分
10580:  addw   t4, t4, t6           # t4 += Choice(e,f,g)
10584:  addw   t4, t4, a1           # t4 += h (旧值) -> h_new 部分1

# === S0(a) 计算 ===
10588:  addw   t5, t5, t0           # ROTL32(30, a)
1058c:  slliw  a1, s5, 0x13         # a1 = a << 19
10590:  srliw  t0, s5, 0xd          # t0 = a >> 13
10594:  addw   a1, a1, t0           # a1 = ROTL32(19, a)
10598:  xor    t5, t5, a1           # t5 = ROTL(30) ^ ROTL(19)
1059c:  srliw  t6, s5, 0x16         # t6 = a >> 22
105a0:  slliw  a1, s5, 0xa          # a1 = a << 10
105a4:  addw   a1, a1, t6           # a1 = ROTL32(10, a)
105a8:  xor    a1, a1, t5           # a1 = S0(a) = ROTL(30)^ROTL(19)^ROTL(10)

# === Majority(a,b,c) ===
105ac:  xor    t5, s5, a7           # t5 = a ^ b
105b0:  and    t6, s5, a7           # t6 = a & b
105b4:  and    t5, t5, a6           # t5 = c & (a ^ b)
105b8:  xor    t5, t5, t6           # t5 = Majority(a,b,c)

# === d += h; h += S0(a) + Maj ===
105bc:  addw   a0, t4, a0           # d += h_new (d = d_old + h_new)
105c0:  addw   a1, a1, t5           # a1 = S0(a) + Majority
105c4:  addw   a1, a1, t4           # h_new_final = S0(a) + Maj + (S1+Ch+k+data+h_old)
```

**EXPAND 部分**（每个 W[i] 更新约 23 条额外指令）:

```asm
# === s1(W[(i-2) & 15]) ===
10a36:  srliw  t2, s7, 0x11         # W >> 17
10a3a:  slliw  s10, s7, 0xf         # W << 15
10a3e:  srliw  s6, s7, 0x13         # W >> 19
10a42:  addw   s10, s10, t2         # ROTL(15, W)
10a46:  slliw  t2, s7, 0xd          # W << 13
10a4a:  addw   t2, t2, s6           # ROTL(13, W)
10a4e:  xor    s10, s10, t2         # ROTL(15) ^ ROTL(13)
10a52:  slliw  s6, s4, 0x19         # (开始 s0 计算)
# === s0(W[(i-15) & 15]) ===
10a56:  srliw  t2, s4, 0x7
10a5e:  srliw  t2, s7, 0xa          # W >> 10
10a66:  xor    t2, t2, s10          # t2 = s1 完成
10a6a:  slliw  s10, s4, 0xe
10a6e:  addw   s10, s10, s8
10a72:  xor    s10, s6, s10
10a76:  srliw  s6, s4, 0x3          # W >> 3
10a7a:  xor    s6, s6, s10          # s6 = s0 完成
# === W[i] += s1 + W[(i-7)&15] + s0 ===
10a7e:  addw   t2, t2, s6           # s1 + s0
10a84:  addw   s10, t2, s6_saved    # W[i] = old + s1 + W[i-7] + s0
```

### 2.3 热点 PC 分布

| 区域 | PC 范围 | 每 PC 执行次数 | 指令数 | 总执行次数 | 占比 |
|------|---------|---------------|--------|-----------|------|
| data load (READ_UINT32) | `0x104c8 - 0x104f2` | 18,016 | 15 | 270,240 | 6.0% |
| **前 16 轮 ROUND** | `0x10530 - 0x109f8` | **2,252** | 307/body | **691,364** | 15.3% |
| **后 48 轮 ROUND+EXPAND** | `0x109fc - 0x118fc` | **3,378** | ~974/body | **3,291,298** | 73.1% |
| sha256_update | `0x118fe - 0x119e8` | ~1,126 | ~16 | 18,016 | 0.4% |
| sha256_write_digest | `0x119ea - 0x11b1a` | ~563 | ~100 | 56,300 | 1.2% |
| benchmark_body + 其他 | — | — | — | ~177,195 | 3.9% |
| **合计** | — | — | — | **~4,504,413** | **100%** |

**执行次数验证**:
- data load: 18,016 per PC = (562+1) x 2 x 16 = 563 x 32 = 18,016 ✓
  - 562 benchmark + 1 warmup = 563 次, 每次 2 个 compress, 每个 compress 16 次 data load
- 前 16 轮: 2,252 iterations = 1,126 x 2 (每次 compress 2 次循环体)
- 后 48 轮 PC=3,378: 这对应 EXPAND 部分的某些 PC，1,126 x 3 = 3,378 ✓

### 2.4 内层循环微架构分析

**指令混合** (单个 ROUND, ~38 条):
- slliw: 6 (15.8%) — 旋转左移部分（S0 x 3, S1 x 3）
- srliw: 6 (15.8%) — 旋转右移部分
- addw: 11 (28.9%) — 旋转合并 + 多级累加
- xor: 6 (15.8%) — S0/S1 合并 + Choice/Majority
- and: 3 (7.9%) — Choice, Majority
- lw: 2 (5.3%) — k[round], data[round]
- 其他: 4 (10.5%)

**关键依赖链** (单个 ROUND):

```
S1(e): slliw(1)+srliw(1) -> addw(1) -> xor(1) -> ... (3 路旋转合并) = ~5 ops
Choice(e,f,g): xor(1) -> and(1) -> xor(1) = 3 ops (与 S1 并行)

h_update:
  e ──→ S1(e) ─────────────────────┐
  e ──→ Choice(e,f,g) ─────────────┤
  lw k ─────────────────────────────┼→ addw(data+k) → addw(+S1) → addw(+Choice) → addw(+h_old) = h_partial
  lw data ──────────────────────────┘                                                     |
                                                                                           ├→ addw d += h_partial
  a ──→ S0(a) ──────────────────────┐                                                     |
  a,b,c ──→ Majority(a,b,c) ───────┼→ addw(S0+Maj) → addw(+h_partial) = h_new_final     |
```

**循环携带依赖** (ROUND 到 ROUND):
- 关键: `e_new = d_old + h_partial` 是下一轮的 `e` 输入（决定 S1 和 Choice）
- 路径: h_partial 计算需要 S1(e) + Choice(e,f,g) + 3 个 addw
  - S1(e): slliw(1) + addw(1) + slliw(1) + addw(1) + xor(1) + slliw(1) + addw(1) + xor(1) = **~5 cycles**
  - Choice: 可与 S1 并行
  - 累加链: addw(data+k)(1) + addw(+S1)(1) + addw(+Choice)(1) + addw(+h_old)(1) = **4 cycles**
  - 总关键路径: **~6-7 cycles/round** (S1 和 累加部分重叠)

- 次关键: `h_new` 是下一轮的 `a` 输入（决定 S0 和 Majority）
  - 需等 h_partial 完成后再加 S0+Maj: 额外 ~3 cycles
  - 但 S0(a) 的结果仅影响下下一轮的 `e`（经过一轮缓冲），不是直接关键路径

**EXPAND 额外开销**:
- 每个 EXPAND 需约 23 条指令（s0 + s1 + 3 个 addw）
- s1 和 s0 计算各需 ~8 条指令（旋转 + 移位 + xor）
- EXPAND 结果作为 `data` 输入 ROUND，与 ROUND 的 S1(e) 计算并行

**预计 IPC (OoO core)**:
- 前 16 轮: 38 条/round / 6-7 cycles ≈ 5.4-6.3（理论上限）
- 后 48 轮: 61 条/round / 7-8 cycles ≈ 7.6-8.7（理论上限，EXPAND 与 ROUND 并行）
- 受 4-wide dispatch 限制，预计实际 IPC: 2.5-3.5
- 纯 ALU 计算，无 cache miss，瓶颈在依赖链深度和 dispatch 宽度

## 3. 总结

```
算法:           SHA-256 哈希 (56B 消息)
数据量:         ~416B (K 表 + data[] + state, 全驻 L1D/栈)
计算类型:       int32 旋转 (sllw/srliw/addw) + 位运算 (and/xor) + 加法 (addw)
每 ROUND 指令数: 38 条 (前 16 轮), 61 条 (后 48 轮, 含 EXPAND)
核心函数占比:   ~94.4% (_nettle_sha256_compress)
瓶颈预测:       compute-bound (ROUND 间 6-7 cycle 串行依赖链, 纯 ALU)
分支特征:       极少分支 (2+3 次循环迭代), 完全可预测
```
