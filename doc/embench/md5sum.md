# md5sum 性能分析

## 1. 源码分析

### 1.1 基本信息
- **源文件**: `thirdparty/embench-iot/src/md5sum/md5.c`
- **算法描述**: MD5 消息摘要算法，对 1000 字节消息计算 128-bit 哈希
- **LOCAL_SCALE_FACTOR**: 66
- **数据类型**: `uint32_t`（32-bit unsigned integer）
- **MSG_SIZE**: 1000

### 1.2 调用链
```
benchmark() -> benchmark_body(lsf=66, gsf=1)
  +-> 循环 66x1 = 66 次
      +-> init_heap_beebs()
      +-> malloc_beebs(1000)
      +-> msg[i] = i (i=0..999)        # 初始化消息
      +-> md5(msg, 1000)
      |     +-> calloc_beebs(1080, 1)   # 分配 padded 消息
      |     +-> memcpy + padding        # 添加 0x80 和长度
      |     +-> for offset in 0..960 step 64:   # 16 个 512-bit chunk
      |     |     +-> 64 轮 ROUND 操作          # 核心热点
      |     +-> free_beebs()
      +-> free_beebs()
```

### 1.3 核心计算函数

```c
void md5(uint8_t *initial_msg, size_t initial_len) {
    // ... padding ...
    for (offset = 0; offset < new_len; offset += 64) {   // 遍历 512-bit chunk
        uint32_t *w = (uint32_t *)(msg + offset);
        uint32_t a = h0, b = h1, c = h2, d = h3;

        for (i = 0; i < 64; i++) {                        // 64 轮 ★热点
            uint32_t f, g;
            if (i < 16)       { f = (b & c) | ((~b) & d);      g = i; }
            else if (i < 32)  { f = (d & b) | ((~d) & c);      g = (5*i + 1) % 16; }
            else if (i < 48)  { f = b ^ c ^ d;                  g = (3*i + 5) % 16; }
            else              { f = c ^ (b | (~d));              g = (7*i) % 16; }

            uint32_t temp = d;
            d = c;
            c = b;
            b = b + LEFTROTATE((a + f + k[i] + w[g]), r[i]);
            a = temp;
        }
        h0 += a; h1 += b; h2 += c; h3 += d;
    }
}
```

### 1.4 循环结构

| 循环层 | 变量 | Trip Count | 说明 |
|--------|------|-----------|------|
| benchmark_body 外层 | lsf_cnt | 66 | LOCAL_SCALE_FACTOR |
| benchmark_body 内层 | gsf_cnt | 1 | GLOBAL_SCALE_FACTOR |
| chunk 循环 | offset | 16 | 1000B msg -> padded 1016B -> 16 个 64B chunk |
| **ROUND 循环** | **i** | **64** | **4 段 x 16 轮（最内层热点）** |

### 1.5 访存模式

| 数据 | 访问方式 | Stride | 说明 |
|------|---------|--------|------|
| r[64] | 按 i 索引 | 4B | 轮移位量表，栈上数组 |
| k[64] | 按 i 索引 | 4B | 常量表，栈上数组 |
| w[16] | 按 g 索引 | 不定 | 消息块，g 依赖 i 和轮次段，非顺序 |

**数据总量**: r[64]=256B + k[64]=256B + msg_padded=1080B + w=64B -> 约 1.7KB -> **完全驻 L1D**

### 1.6 计算特征

- **计算密集型**: 数据全在 L1/栈上，瓶颈在 ALU 依赖链
- **运算类型**: 32-bit 位运算（and/or/xor/not）+ 加法（addw）+ 移位/旋转（sllw/srlw/or）
- **分支**: 4 段 if-else 按 i 范围分派（i<16, i<32, i<48, else），高度可预测
- **核心特征**: 每轮 b 的更新依赖 a+f+k+w 的左旋结果，形成严格串行依赖链

## 2. 汇编热点分析

### 2.1 Spike 执行概况
```
Total instructions: 2,679,251
Total user instructions: 2,705,249
Cycles:  2,679,248
IPC: 1.0000 (spike 顺序执行)
```

### 2.2 核心函数反汇编

MD5 内层 64 轮循环的编译产物（编译器将 4 段分支和公共计算合并）:

```asm
# === 公共计算段 (每轮都执行) ===
10598:  slli   s11, a5, 0x20       # s11 = g << 32 (零扩展 g 到 64-bit)
1059c:  srli   a5, s11, 0x1e       # a5 = g * 4 (字节偏移)
105a0:  add    a5, a5, t0          # a5 = &w[g] (w 基址 + g*4)
105a2:  lw     s11, 0(a7)          # s11 = k[i] (从栈上 k 表加载)
105a6:  add    a5, a5, t6          # a5 += chunk_offset
105a8:  lw     a5, 0(a5)           # a5 = w[g] (加载消息字)
105aa:  addw   s11, s11, a4        # s11 = k[i] + f
105ae:  lw     a4, 0(a6)           # a4 = r[i] (从栈上 r 表加载)
105b2:  addw   a5, a5, s11         # a5 = w[g] + k[i] + f
105b6:  addw   a5, a5, t5          # a5 = w[g] + k[i] + f + a  (★关键累加)
105ba:  negw   t5, a4              # t5 = -r[i] = 32 - r[i]
105be:  sllw   a4, a5, a4          # a4 = sum << r[i]  (左旋上半)
105c2:  srlw   a5, a5, t5          # a5 = sum >> (32-r[i]) (左旋下半)
105c6:  or     a4, a4, a5          # a4 = LEFTROTATE(sum, r[i])
105c8:  addiw  a3, a3, 1           # i++
105ca:  addiw  t1, t1, 5           # 5*i 递增器 (用于 g 计算)
105cc:  addiw  t3, t3, 3           # 3*i 递增器
105ce:  addiw  t4, t4, 7           # 7*i 递增器
105d0:  addi   a7, a7, 4           # k 指针++
105d2:  addi   a6, a6, 4           # r 指针++
105d4:  addw   a4, a4, a2          # a4 = LEFTROTATE(...) + b (新 b 值)
105d6:  mv     t5, a0              # t5 = a_old (保存 d -> a)
105d8:  beq    a3, t2, 10608       # i == 64? -> 退出

# === 寄存器轮换 (a,b,c,d 每轮旋转) ===
105dc:  mv     a0, a1              # a = d_old (实际是上一轮的 c)
105de:  mv     a1, a2              # a1 = c_old (旋转)
105e0:  mv     a2, a4              # a2 = new_b
105e2:  bltu   s0, a3, 10580       # i > 15? -> 跳到段2/3/4的 f 计算

# === 段1: i < 16 的 f 计算 ===
105e6:  xor    a4, a1, a0          # a4 = c ^ d
105ea:  and    a4, a4, a2          # a4 = b & (c ^ d)
105ec:  xor    a4, a4, a0          # a4 = (b & c) | (~b & d) = f
105ee:  mv     a5, a3              # g = i
105f0:  j      10598               # -> 公共计算

# === 段2: 16 <= i < 32 的 f 计算 ===
10580:  xor    a4, a2, a1          # a4 = b ^ c
10584:  and    a4, a4, a0          # a4 = d & (b ^ c)
10586:  bgeu   s1, a3, 105f2       # i <= 31? -> 段2
1058a:  xor    a4, a2, a1          # a4 = b ^ c (段3入口)
1058e:  xor    a4, a4, a0          # a4 = b ^ c ^ d = f
10590:  andi   a5, t3, 15          # g = (3*i + 5) % 16
10594:  bgeu   s2, a3, 105fa       # i <= 47? -> 公共计算
# ... 段4: f = c ^ (b | ~d) ...

105f2:  xor    a4, a4, a1          # 段2: f = (d & b) | (~d & c)
105f4:  andi   a5, t1, 15          # g = (5*i + 1) % 16
105f8:  j      10598               # -> 公共计算
```

**编译器优化观察**:
- 4 段 if-else 编译为 bgeu 级联分支，段1最快（fall-through）
- r[] 和 k[] 在栈上分配，通过指针递增访问（避免每轮索引计算）
- `LEFTROTATE` 展开为 sllw + srlw + or 三条指令
- g 的计算利用 5*i/3*i/7*i 增量寄存器 + andi 取模，避免乘法

### 2.3 热点 PC 分布

| 区域 | PC 范围 | 每 PC 执行次数 | 指令数 | 总执行次数 | 占比 |
|------|---------|---------------|--------|-----------|------|
| **公共计算 + 段1** | `0x10598 - 0x105f0` | **68,608** | 23 | **1,578,400** | 58.4% |
| 段2 (16<=i<32) | `0x10580 - 0x10586` + `0x105f2-0x105f8` | 51,456/17,152 | 6 | 205,824 | 7.6% |
| 段3 (32<=i<48) | `0x1058a - 0x10594` | 34,304 | 4 | 137,216 | 5.1% |
| 段4 (48<=i<64) | `0x105fa - 0x10606` | 17,152 | 4 | 68,608 | 2.5% |
| 循环退出 + 轮换 | `0x105d8 - 0x105e2` | 67,536 | 4 | 270,144 | 10.0% |
| chunk 循环控制 | `0x10564 - 0x10576` | ~1,072 | 8 | ~8,576 | 0.3% |
| msg 初始化 | `0x106ac - 0x106b6` | 67,000 | 4 | 268,000 | 9.9% |
| benchmark_body 其他 | — | — | — | ~130,000 | 4.8% |
| pk/bbl 系统开销 | — | — | — | ~38,481 | 1.4% |
| **合计** | — | — | — | **~2,705,249** | **100%** |

**执行次数验证**: 68,608 = (66+1) x 16 x 64 = 67 x 1024 ✓
- 66 次 benchmark + 1 次 warmup = 67 次 md5 调用
- 每次 md5: 1000B 消息 -> padded 1016B -> 16 个 chunk -> 64 轮/chunk

### 2.4 内层循环微架构分析

**指令混合** (公共计算段, 23 条/iter, 段1):
- lw: 3 (13%)  — k[i], r[i], w[g]
- addw: 4 (17%) — 累加 k+f, w+k+f, sum+a, rot+b
- sllw/srlw: 2 (9%) — LEFTROTATE
- slli/srli: 2 (9%) — g 地址计算
- or: 1 (4%) — LEFTROTATE 合并
- xor/and: 3 (13%) — f 计算
- addiw: 4 (17%) — i++, 5i/3i/7i 递增
- addi: 2 (9%) — k/r 指针递增
- negw: 1 (4%) — 32-r[i]
- mv/beq: 1+0 (4%) — 寄存器轮换/分支

**关键依赖链** (每轮的串行路径):

```
lw k[i] ─────────────────────┐
                              ├→ addw s11=k[i]+f ──┐
(f 计算: xor+and+xor) ──────┘                     |
                                                    ├→ addw a5=w[g]+k[i]+f ──┐
lw w[g] ──────────(需 g 地址计算: slli+srli+add)──┘                         |
                                                                              ├→ addw a5+=a
lw r[i] ──→ negw t5=-r[i] ──┐                                               |
                              ├→ sllw ──┐                                     |
addw a5+=a ──────────────────┤          ├→ or a4 ──→ addw a4+=b (新 b)
                              └→ srlw ──┘
```

**循环携带依赖** (关键路径):
- `b` (a2): 每轮更新为 `LEFTROTATE(a + f + k[i] + w[g], r[i]) + b_old`
  - 路径: addw(1) + addw(1) + addw(1) + sllw(1) + srlw(1) + or(1) + addw(1) = **7 cycles**
  - 但 sllw 和 srlw 可并行，实际: addw + addw + addw + max(sllw,srlw) + or + addw = **6 cycles**
- `a,c,d`: 通过 mv 轮换，1 cycle（不在关键路径上）
- `k/r 指针`: addi 1 cycle（不是瓶颈）

**预计 IPC (OoO core)**:
- 23 条指令 / 6 cycles (关键路径) ≈ 3.8
- 但受限于 dispatch 宽度（典型 4-wide）和 load 端口
- 3 个 load (k, r, w) 可与 ALU 运算重叠
- 实际 IPC 预计 2.5-3.5，受 addw 依赖链和分支预测开销约束

## 3. 总结

```
算法:           MD5 消息摘要 (1000B 消息)
数据量:         ~1.7KB (r/k 表 + padded 消息, 全驻 L1D)
计算类型:       int32 位运算 (and/or/xor) + 加法 (addw) + 旋转 (sllw/srlw)
内层循环指令数: ~23 条 (段1), ~25 条 (段2-4 多 2-3 条分支/f 计算)
内层循环占比:   ~83.6% (md5 函数占总指令 88.7%)
瓶颈预测:       compute-bound (b 更新的 6-cycle 串行依赖链)
分支特征:       4 段 if-else 级联, 每段固定 16 轮, 高度可预测
```
