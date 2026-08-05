# nettle-aes 性能分析

## 1. 源码分析

### 1.1 基本信息
- **源文件**: `thirdparty/embench-iot/src/nettle-aes/nettle-aes.c`
- **算法描述**: AES-256 加密 + 解密，对 256 字节明文进行 ECB 模式加解密
- **LOCAL_SCALE_FACTOR**: 76
- **数据类型**: `uint32_t`（32-bit unsigned integer）
- **密钥长度**: 256-bit (AES256)，轮数 = 14

### 1.2 调用链
```
benchmark() -> benchmark_body(lsf=76, gsf=1)
  +-> 循环 76x1 = 76 次
      +-> aes_set_encrypt_key(encctx, 8, key)       # 设置加密密钥
      |     +-> _aes_set_key(nr=14, nk=8, subkeys, key)
      +-> _nettle_aes_encrypt(rounds=14, keys, T, 256B, dst, src)
      |     +-> FOR_BLOCKS(256, dst, src, 16):       # 16 个 16B 块
      |           +-> LE_READ_UINT32 x 4 + XOR keys[0..3]
      |           +-> for i in 1..13:                 # 13 轮 AES_ROUND ★热点
      |           |     +-> 4x AES_ROUND (T-table lookup + XOR)
      |           +-> 4x AES_FINAL_ROUND (S-box lookup + XOR)
      |           +-> LE_WRITE_UINT32 x 4
      +-> aes_set_decrypt_key -> _aes_set_key + _nettle_aes_invert
      +-> _nettle_aes_decrypt(rounds=14, keys, T, 256B, dst, src)
            +-> FOR_BLOCKS: 同 encrypt 结构
```

### 1.3 核心计算函数

**AES_ROUND 宏**（T-table 实现）:
```c
#define AES_ROUND(T, w0, w1, w2, w3, k)         \
((  T->table[0][ B0(w0) ]                       \
  ^ T->table[1][ B1(w1) ]                       \
  ^ T->table[2][ B2(w2) ]                       \
  ^ T->table[3][ B3(w3) ]) ^ (k))
```

**加密主循环**:
```c
void _nettle_aes_encrypt(unsigned rounds, const uint32_t *keys,
                          const struct aes_table *T,
                          size_t length, uint8_t *dst, const uint8_t *src) {
    FOR_BLOCKS(length, dst, src, AES_BLOCK_SIZE) {
        uint32_t w0, w1, w2, w3;
        w0 = LE_READ_UINT32(src)     ^ keys[0];
        w1 = LE_READ_UINT32(src + 4) ^ keys[1];
        w2 = LE_READ_UINT32(src + 8) ^ keys[2];
        w3 = LE_READ_UINT32(src + 12)^ keys[3];

        for (i = 1; i < rounds; i++) {        // 13 轮 ★热点
            t0 = AES_ROUND(T, w0, w1, w2, w3, keys[4*i]);
            t1 = AES_ROUND(T, w1, w2, w3, w0, keys[4*i+1]);
            t2 = AES_ROUND(T, w2, w3, w0, w1, keys[4*i+2]);
            t3 = AES_ROUND(T, w3, w0, w1, w2, keys[4*i+3]);
            w0 = t0; w1 = t1; w2 = t2; w3 = t3;
        }
        // Final round: AES_FINAL_ROUND (S-box, no MixColumns)
    }
}
```

### 1.4 循环结构

| 循环层 | 变量 | Trip Count | 说明 |
|--------|------|-----------|------|
| benchmark_body 外层 | lsf_cnt | 76 | LOCAL_SCALE_FACTOR |
| benchmark_body 内层 | gsf_cnt | 1 | GLOBAL_SCALE_FACTOR |
| block 循环 (enc) | length | 16 | 256B / 16B = 16 块 |
| **round 循环 (enc)** | **i** | **13** | **AES-256 的 1..13 轮（热点）** |
| block 循环 (dec) | length | 16 | 同 encrypt |
| **round 循环 (dec)** | **i** | **13** | **同 encrypt** |

### 1.5 访存模式

| 数据 | 访问方式 | 说明 |
|------|---------|------|
| T->table[0..3][256] | 按字节值索引 | 4 个 1KB 的 T-table，共 4KB |
| T->sbox[256] | 按字节值索引 | 256B S-box（final round） |
| keys[60] | 顺序访问 | 240B 扩展密钥，每轮 4 个 word |
| plaintext/ciphertext | 16B 块顺序 | 256B 输入/输出 |

**数据总量**:
- `_aes_encrypt_table`: sbox(256B) + table[4][256](4KB) = 4.25KB
- `_aes_decrypt_table`: 同上 4.25KB
- 密钥 + 数据: ~1KB
- **合计 ~9.5KB -> 完全驻 L1D**
- **注意**: T-table 访问模式由明文字节决定，本质上是随机索引查表

### 1.6 计算特征

- **访存密集型**: 每轮 4 次 AES_ROUND，每次需 4 个 T-table load + 3 xor + 1 lw(key)
- **运算类型**: lw（T-table 查表）+ xor（列混合）+ srliw/andi（字节提取）
- **分支**: round 循环 13 次迭代，高度可预测
- **核心特征**: T-table 查表地址依赖上一轮输出，形成 load-use 依赖链

## 2. 汇编热点分析

### 2.1 Spike 执行概况
```
Total instructions: 4,649,368
Total user instructions: 4,731,081
Cycles:  4,649,364
IPC: 1.0000 (spike 顺序执行)
```

### 2.2 核心函数反汇编

AES encrypt 内层循环（一轮 = 4 个 AES_ROUND，119 条指令/iter）:

```asm
# === AES_ROUND 一轮开始 (对 w0,w1,w2,w3 进行 T-table 变换) ===
# --- 字节提取阶段 ---
106a6:  srliw  s0, a3, 0x18        # s0 = B3(w1) = w1 >> 24
106aa:  srliw  a0, a3, 0x8         # a0 = B1(w1) = (w1 >> 8) & 0xff
106ae:  srliw  t6, a6, 0x10        # t6 = B2(w2) = (w2 >> 16) & 0xff
106b2:  andi   s1, a3, 255         # s1 = B0(w1)
106b6:  srliw  a3, a3, 0x10        # a3 = B2(w1)
...
# --- T-table 索引计算 ---
106d0:  addi   s0, s0, 832         # 偏移到 table[3] (832 = 256*3 + 64)
106d4:  addi   t2, t2, 832         # table[3]
106dc:  addi   t6, t6, 576         # 偏移到 table[2] (576 = 256*2 + 64)
106e0:  addi   a3, a3, 576         # table[2]
...
106ee:  slli   s1, s1, 0x2         # B0 * 4 (uint32_t 索引)
106f0:  slli   s0, s0, 0x2         # B3 * 4
...
106fc:  add    s1, s1, a2          # s1 = &T->table[0][B0(w1)]
106fe:  add    s0, s0, a2          # s0 = &T->table[3][B3(w1)]
...
# --- T-table load ---
10710:  lw     s11, 256(s10)       # T->table[1][B1(w0)] (offset 256)
10716:  lw     s10, 256(s1)        # T->table[1][B0(w1)]
1071c:  lw     s1, 0(s0)           # T->table[3][B3(w1)]
1071e:  lw     s0, 0(t2)           # T->table[3][B3(w2)]
10722:  lw     t2, 1280(t0)        # T->table[3+2][...]
...
# --- XOR 合并 4 个 T-table 结果 ---
1074a:  xor    t3, s11, t3         # t0_partial ^= T[1][B1(w0)]
10752:  xor    a3, s10, s2         # t1_partial ^= ...
...
# --- Load round key & final XOR ---
107f6:  lw     s0, 0(s0)           # keys[4*i]
107f8:  lw     a0, 0(a0)           # keys[4*i+1]
107fa:  lw     t2, 0(t2)           # keys[4*i+2]
107fe:  lw     s2, 0(s2)           # keys[4*i+3]
...
10818:  xor    t3, t3, s2          # w0_new = T_result ^ keys[4*i]
1081c:  xor    a3, a3, s0          # w1_new ^= keys[4*i+1]
1081e:  xor    a6, a6, a0          # w2_new ^= keys[4*i+2]
10822:  xor    a7, a7, t2          # w3_new ^= keys[4*i+3]
# --- 循环控制 ---
10826:  addiw  t4, t4, 4           # round_offset += 4
10828:  bne    t5, s3, 106a6       # round++ != 14? -> 继续
```

**编译器优化观察**:
- T-table 的 4 个子表通过基址 + 偏移区分（0/256/576/832 对应 table[0..3]）
- 字节提取用 srliw + andi 组合，避免字节 load
- 每轮 4 个 AES_ROUND 完全展开，无函数调用
- Round key 通过计算偏移后直接 lw 加载
- 循环变量 t5 递增，与 s3(=rounds) 比较

### 2.3 热点 PC 分布

| 区域 | PC 范围 | 每 PC 执行次数 | 指令数 | 总执行次数 | 占比 |
|------|---------|---------------|--------|-----------|------|
| **Encrypt inner loop** | `0x106a6 - 0x10828` | **16,016** | 119 | **1,905,904** | 40.3% |
| Encrypt prologue/final | `0x1059c - 0x106a4`, `0x1082c - 0x10a22` | ~1,232 | ~184 | ~227,535 | 4.8% |
| **Decrypt inner loop** | 对称区域 | **16,016** | ~119 | ~1,905,904 | 40.3% |
| Decrypt prologue/final | — | ~1,232 | ~198 | ~243,705 | 5.2% |
| Key setup (x2) | `0x1042a - 0x1059a` | — | — | 269,500 | 5.7% |
| aes_invert | `0x10eb4 - 0x10fc2` | — | — | 154,924 | 3.3% |
| benchmark_body 其他 | — | — | — | ~23,609 | 0.5% |
| **合计** | — | — | — | **~4,731,081** | **100%** |

**执行次数验证**: 16,016 = (76+1) x 16 x 13 = 77 x 208 ✓
- 76 次 benchmark + 1 次 warmup = 77 次完整加解密
- 每次: 16 个 block x 13 轮 inner loop

### 2.4 内层循环微架构分析

**指令混合** (Encrypt inner loop, 119 条/iter):
- lw: 20 (16.8%) — 16 个 T-table load + 4 个 round key load
- xor: 16 (13.4%) — 4 个 AES_ROUND 各 3 个 T-table XOR + 1 个 key XOR
- srliw: 16 (13.4%) — 字节提取 (>>8, >>16, >>24)
- andi: 12 (10.1%) — 字节掩码 (& 0xff)
- slli: 16 (13.4%) — 索引 * 4
- add: 16 (13.4%) — 基址 + 偏移
- addi: 12 (10.1%) — T-table 子表偏移
- addiw: 2 (1.7%) — 循环控制
- bne: 1 (0.8%) — 循环分支
- 其他: 8 (6.7%) — sext.w, mv 等

**关键依赖链** (单个 AES_ROUND):

```
w0 (上一轮结果)
  |
  +-> andi B0(w0) ──→ slli ──→ add ──→ lw T[0][B0(w0)] ──┐
  +-> srliw B1(w1) ──→ andi ──→ addi ──→ slli ──→ add ──→ lw T[1][B1(w1)] ──→ xor ──┐
  +-> srliw B2(w2) ──→ andi ──→ addi ──→ slli ──→ add ──→ lw T[2][B2(w2)] ──→ xor ──→ xor ──→ xor(key) = w0_new
  +-> srliw B3(w3) ──→ addi ──→ slli ──→ add ──→ lw T[3][B3(w3)] ──→ xor ──┘         |
  lw keys[4*i] ─────────────────────────────────────────────────────────────────────────┘
```

**循环携带依赖** (关键路径 = 一轮 AES_ROUND):
- `w0-w3`: 每轮输出是下一轮的输入
- 单路径: srliw(1) + andi(1) + addi(1) + slli(1) + add(1) + **lw(2-4)** + xor(1) + xor(1) + xor(1) + xor(1) = **10-12 cycles**
- 但 4 个 ROUND 的字节提取可高度并行（不同的 w 互不依赖）
- **实际瓶颈**: T-table load latency（L1D hit = 2-4 cycles），因查表地址依赖上一轮 w 值

**预计 IPC (OoO core)**:
- 119 条指令 / ~12 cycles (关键路径) ≈ 理论上限 ~10
- 受限于 dispatch 宽度（4-wide）和 load 端口（通常 2 个）
- 每轮需要 20 个 load，但分布在 4 个独立 ROUND 中，可交错发射
- 预计 IPC: 3.0-4.0，受 load 端口和 T-table 地址依赖链限制

## 3. 总结

```
算法:           AES-256 ECB 加密 + 解密 (256B 数据)
数据量:         ~9.5KB (T-table 4KB x 2 + keys + data, 全驻 L1D)
计算类型:       T-table 查表 (lw) + XOR 合并 + 字节提取 (srliw/andi)
内层循环指令数: 119 条/轮
内层循环占比:   ~80.6% (encrypt + decrypt 内层循环)
瓶颈预测:       load-bound (T-table 查表地址依赖上一轮输出, load 端口竞争)
分支特征:       round 循环 13 次, block 循环 16 次, 高度可预测
```
