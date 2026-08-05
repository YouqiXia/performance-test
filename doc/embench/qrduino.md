# qrduino 性能分析

## 1. 源码分析

### 1.1 基本信息
- **源文件**: `thirdparty/embench-iot/src/qrduino/qrtest.c`, `qrencode.c`, `qrframe.c`
- **算法描述**: QR 二维码编码器，输入字符串 "http://www.mageec.com"，生成 QR Version 1 (21x21) 二维码
- **LOCAL_SCALE_FACTOR**: 5
- **数据类型**: `unsigned char` (8-bit)，位操作密集

### 1.2 调用链
```
benchmark() → benchmark_body(lsf=5, gsf=1)
  └→ 循环 5×1 = 5 次 (+1 warmup = 6 次)
      ├→ initeccsize(1, 22) → initecc(1, vers)     # 确定 QR 版本
      ├→ memcpy(strinbuf, encode, 22)               # 拷贝输入字符串
      ├→ initframe()                                 # 初始化 QR 帧 (finder/alignment/timing patterns)
      │   ├→ calloc_beebs(), malloc_beebs()          # 分配 framebase, framask, rlens
      │   ├→ putfind()                               # 3 个 finder pattern
      │   ├→ doaligns()                              # alignment pattern (version 1 无)
      │   └→ putvpat()                               # version pattern (version < 7 无)
      ├→ qrencode()                                  # ★★★ 核心：编码 + 掩码选择
      │   ├→ stringtoqr()                            # 字符串→QR 数据格式 + Reed-Solomon ECC
      │   │   ├→ initrspoly()                        # 初始化 RS 生成多项式
      │   │   └→ appendrs() × (neccblk1+neccblk2)   # 计算 ECC
      │   ├→ fillframe()                             # 将数据位填入 QR 帧 (含 ismasked 检查)
      │   └→ for mask = 0..7:                        # ★ 8 种掩码模式逐一尝试
      │       ├→ applymask(mask)                     # 应用掩码到 QR 帧
      │       ├→ badcheck()                          # ★★★ 计算掩码质量分数
      │       │   ├→ 2x2 block scan: WD×WD          # 检查同色 2x2 块
      │       │   ├→ X runs: WD rows × badruns()     # X 方向连续同色统计
      │       │   ├→ Y runs: WD cols × badruns()     # Y 方向连续同色统计
      │       │   └→ BW balance                      # 黑白平衡度
      │       └→ memcpy(reset frame)                 # 重置帧，尝试下一个掩码
      ├→ freeframe()                                 # 释放帧内存
      └→ freeecc()                                   # 释放 ECC 内存
```

### 1.3 核心计算函数

**badcheck()** -- 占总执行时间 ~69%（含内联的 badcheck + badruns 调用）:

```c
static int badcheck() {
    unsigned char x, y, h, b, b1;
    unsigned thisbad = 0;
    int bw = 0;

    // 1. 2x2 blocks: O(WD^2)
    for (y = 0; y < WD - 1; y++)
        for (x = 0; x < WD - 1; x++)
            if (all_black || all_white) thisbad += N2;

    // 2. X runs: O(WD^2) + badruns per row
    for (y = 0; y < WD; y++) {
        for (x = 0; x < WD; x++) {
            b1 = QRBIT(x, y);     // 位操作: framebase[(x>>3)+y*WDB] >> (7-(x&7)) & 1
            if (b1 == b) rlens[h]++;
            else rlens[++h] = 1;
            bw += b ? 1 : -1;
        }
        thisbad += badruns(h);
    }

    // 3. Y runs: O(WD^2) + badruns per col
    for (x = 0; x < WD; x++) {
        for (y = 0; y < WD; y++) {
            b1 = QRBIT(x, y);
            ...
        }
        thisbad += badruns(h);
    }
    return thisbad;
}
```

**applymask()** -- 占总执行时间 ~19%:

```c
static void applymask(unsigned char m) {
    // 8 种掩码模式，每种都遍历 WD×WD 像素
    // 对每个 (x,y)：检查掩码条件 + ismasked() + TOGQRBIT()
    for (y = 0; y < WD; y++)
        for (x = 0; x < WD; x++)
            if (mask_condition(m, x, y) && !ismasked(x, y))
                TOGQRBIT(x, y);
}
```

**QRBIT 宏** -- 位级操作（每次像素访问的核心开销）:
```c
#define QRBIT(x,y) ((framebase[((x)>>3) + (y)*WDB] >> (7-((x)&7))) & 1)
```

### 1.4 循环结构

| 循环层 | 变量 | Trip Count | 说明 |
|--------|------|-----------|------|
| benchmark_body 外层 | lsf_cnt | 5 (+1 warmup) | LOCAL_SCALE_FACTOR |
| qrencode mask 选择 | mask | 8 | 8 种掩码模式 |
| **badcheck 2x2** | x,y | 20×20=400 | WD-1 = 20 |
| **badcheck X runs** | x,y | **21×21=441** | **WD=21, 内含 QRBIT 位操作** |
| **badcheck Y runs** | x,y | **21×21=441** | **WD=21, 列遍历** |
| **applymask** | x,y | **21×21=441** | **WD=21, 含 ismasked + TOGQRBIT** |
| **badruns** | i | ~21 | 每行/列调用一次 |
| fillframe | bits | 8×data_len | 数据位逐个填入 |
| appendrs | i,j | dlen×eclen | Reed-Solomon ECC 计算 |

**总迭代次数估算**:
- badcheck: 被调用 8 次/mask × 6 次/benchmark = 48 次，每次 ~3×441 = 1323 像素操作
- applymask: 被调用 8 次/mask × 6 = 48 次，每次 441 像素操作
- badruns: 被调用 48 × (21+21) = 2016 次

### 1.5 访存模式

| 数据结构 | 大小 | 访问方式 | 说明 |
|----------|------|---------|------|
| framebase (QR 帧) | WDB×WD = 3×21 = 63B | 位级读写 (QRBIT/SETQRBIT/TOGQRBIT) | 热数据，全驻 L1D |
| framask (掩码位图) | ~28B | 位级读 (ismasked) | 热数据 |
| rlens (run lengths) | 22B | 顺序读写 | badcheck 使用 |
| strinbuf (输入/ECC) | ~50B | 顺序读写 | stringtoqr/appendrs |
| g0log/g0exp (GF 表) | 2×256B = 512B | 随机查表 | Reed-Solomon ECC |

**数据总量**: ~700B → **完全驻 L1D**

### 1.6 计算特征

- **位操作密集型**: QRBIT/SETQRBIT/TOGQRBIT 每次涉及 shift + AND/OR + byte load/store
- **运算类型**: 整数位操作 (`srliw`, `andi`, `or`, `xor`) + `mulw`（WDB×y 地址计算）+ 比较分支
- **分支特征**: 多层嵌套循环，trip count=21 (小)，条件分支（掩码条件、ismasked）混合
- **GF(256) 查表**: appendrs 中 `glog()`/`gexp()` 为 256B 表的随机查表

## 2. 汇编热点分析

### 2.1 Spike 执行概况
```
Total instructions: 2,896,341
Cycles:  2,896,338
Instret: 2,896,341
IPC: 1.0000 (spike 顺序执行)
```

### 2.2 核心函数反汇编

**badcheck X runs 内层循环**（内联在 qrencode 中，~0x11190-0x111e0）:

```asm
# === badcheck X runs: for (x = 0; x < WD; x++) { b1 = QRBIT(x,y); ... } ===

111a4:  lbu   a7,-2012(gp)       # a7 = WDB (bytes per row = 3)
111a8:  ld    a6,-2028(gp)       # a6 = qrframe 基址
111ac:  andi  a4,a2,255          # a4 = x & 0xff
111b0:  mulw  a7,a7,s11          # a7 = WDB * y (行偏移, mulw 每迭代)
111b4:  srliw a4,a4,0x3          # a4 = x >> 3 (byte index)
111b8:  mv    t1,a5              # t1 = prev bit value
111ba:  not   a1,a2              # a1 = ~x
111be:  andi  a1,a1,7            # a1 = 7 - (x & 7) [bit position]
111c0:  ld    a3,-2004(gp)       # a3 = rlens 基址
111c4:  addiw t3,a0,1            # t3 = h + 1
111c8:  addw  a4,a4,a7           # a4 = (x>>3) + WDB*y
111cc:  add   a5,a6,a4           # a5 = &framebase[byte_offset]
111d0:  lbu   a5,0(a5)           # a5 = framebase[byte_offset]
111d4:  sraw  a5,a5,a1           # a5 >>= bit_position
111d8:  andi  a5,a5,1            # a5 = QRBIT(x, y) 结果
111da:  bne   a5,t1,11182        # if (b1 != b) → new run

# === 同色 run 继续 ===
111de:  add   a3,a3,a0           # a3 = &rlens[h]
111e0:  lbu   a4,0(a3)           # a4 = rlens[h]
111e4:  addiw a4,a4,1            # a4 += 1
111e6:  sb    a4,0(a3)           # rlens[h]++
111ea:  j     1118c              # → 更新 bw, x++, 继续

# === 颜色切换 ===
11182:  andi  a0,t3,255          # a0 = (h+1) & 0xff
11186:  add   a3,a3,a0           # a3 = &rlens[h+1]
11188:  sb    s8,0(a3)           # rlens[++h] = 1
1118c:  addiw a2,a2,1            # x++
1118e:  lbu   s6,-2011(gp)       # s6 = WD (volatile load)
11192:  andi  a1,a2,255          # a1 = x & 0xff
11196:  li    a3,-1              # prep for bw update
11198:  beqz  a5,1119c           # if (b == 0) bw -= 1
1119a:  li    a3,1               # else bw += 1
1119c:  addw  s10,a3,s10         # bw += (b ? 1 : -1)
111a0:  bgeu  a1,s6,11366        # if (x >= WD) → row done, call badruns
```

**applymask 内层循环**（mask 5 为例，0x10612-0x10694）:

```asm
# === applymask mask=5: for (x = 0; x < WD; x++) ===
1061a:  beq   a2,a6,10b62        # if (r3x == 3) r3x = 0
1061e:  sub   a3,a2,a7           # a3 = r3x (mod 3 logic)
10622:  snez  a1,a2              # a1 = (x != 0)
10626:  seqz  a3,a3              # a3 = (r3x == r3y)
1062a:  addiw a2,a2,1            # x++
1062c:  and   a1,a1,a3           # a1 = (x&y&1) condition...
1062e:  andi  a2,a2,255          # x &= 0xff
10632:  and   a3,a4,a0           # more mask condition bits
10636:  addw  a3,a3,a1           # combine conditions
10638:  andi  a3,a3,1            # test bit 0
1063a:  bnez  a3,10694           # if condition not met → skip

# === ismasked(x, y) inline ===
1063c:  bltu  a0,a4,10bbc        # if (x > y) swap → skip to swap path
10640:  mv    s0,a0              # s0 = min(x,y) or max depending on swap
10642:  mv    a3,a4              # a3 = the other
10644:  mulw  a1,s0,s0           # a1 = y*y
10648:  ld    t2,-1996(gp)       # t2 = framask 基址
1064c:  addw  a1,a1,s0           # a1 = y*y + y
1064e:  srliw a1,a1,0x1          # a1 = y*(y+1)/2
10652:  addw  a3,a3,a1           # a3 = bt = y*(y+1)/2 + x (triangle index)
10654:  srliw a1,a3,0x3          # a1 = bt >> 3
10658:  add   a1,a1,t2           # a1 = &framask[bt>>3]
1065a:  lbu   a1,0(a1)           # a1 = framask byte
1065e:  not   a3,a3              # bit position
10662:  andi  a3,a3,7            # a3 = 7 - (bt & 7)
10664:  sraw  a3,a1,a3           # extract bit
10668:  andi  a3,a3,1            # a3 = ismasked result
1066a:  bnez  a3,10694           # if masked → skip TOGQRBIT

# === TOGQRBIT(x, y) ===
1066c:  lbu   s0,-2012(gp)       # s0 = WDB
10670:  ld    t2,-2028(gp)       # t2 = qrframe
10674:  srliw a1,a4,0x3          # a1 = x >> 3
10678:  mulw  s0,s0,t3           # s0 = WDB * y
1067c:  andi  a3,a4,7            # a3 = x & 7
10680:  sraw  a3,t5,a3           # a3 = 0x80 >> (x&7)
10684:  addw  a1,a1,s0           # a1 = byte offset
10686:  add   a1,a1,t2           # a1 = &framebase[offset]
10688:  lbu   t2,0(a1)           # read byte
1068c:  xor   a3,a3,t2           # toggle bit
10690:  sb    a3,0(a1)           # write back

# === 循环尾部 ===
10694:  lbu   a3,-2011(gp)       # a3 = WD
10698:  addiw a4,a4,1            # x++
1069a:  andi  a4,a4,255          # x &= 0xff
1069e:  bltu  a4,a3,1061a        # x < WD? → 继续
```

**appendrs 内层循环**（RS ECC 计算，0x10562-0x1058a）:

```asm
# === appendrs: for (j = 1; j < eclen; j++) ===
10562:  lbu   a5,-1(a6)          # a5 = genpoly[eclen-j]
10566:  lbu   a1,1(a2)           # a1 = ecbuf[j]
1056a:  addi  a6,a6,-1           # genpoly 指针--
1056c:  addw  a5,a5,a7           # a5 = fb + genpoly[eclen-j]
10570:  bge   a4,a5,10578        # if (a5 < 255) skip modnn
10574:  addiw a5,a5,-255         # modnn: a5 -= 255
10578:  slli  a5,a5,0x20         # zero-extend
1057a:  srli  a5,a5,0x20         # 
1057c:  add   a5,a5,s1           # a5 = &g0exp[a5]
1057e:  lbu   a5,0(a5)           # a5 = gexp(modnn(fb+genpoly[...]))
10582:  addi  a2,a2,1            # ecbuf 指针++
10584:  xor   a5,a5,a1           # a5 = ecbuf[j] ^ gexp(...)
10586:  sb    a5,-1(a2)          # ecbuf[j-1] = result
1058a:  bne   a2,s2,10562        # j < eclen? → 继续
```

### 2.3 热点 PC 分布

| 区域 | PC 范围 | 每 PC 执行次数 | 指令数 | 总执行次数 | 占比 |
|------|---------|---------------|--------|-----------|------|
| **badcheck 内联 (X/Y runs + blocks)** | `0x11100 - 0x11420` | ~13,750 | ~多 PC | 2,049,960 | 58.7% |
| **applymask** | `0x105e2 - 0x10c08` | varies | ~多 PC | 677,988 | 19.4% |
| **badruns** | `0x10426 - 0x104da` | ~13,911 | 7 | 342,648 | 9.8% |
| qrencode 主体 | `0x10c08 - 0x11100` | varies | — | 292,206 | 8.4% |
| initframe | `0x116f4 - 0x12500` | varies | — | 64,686 | 1.9% |
| appendrs | `0x104da - 0x105e2` | varies | — | 30,144 | 0.9% |
| qrencode 尾部 | `0x11420 - 0x116f4` | varies | — | 7,524 | 0.2% |
| pk/bbl + 其他 | — | — | — | 27,623 | 0.8% |
| **合计** | — | — | — | **~3,492,779** | **100%** |

**执行次数验证**:
- badruns 调用次数: 每 PC 13911 / 21(WD) ≈ 662 → 但 badruns 被 X 和 Y 方向各调 21 次 × 8 mask × 6 iter = 2016 次 → 13911 次/PC 是 loop 内部每次迭代的次数
- applymask 内层: 21×21 × 8 masks × 6 iter = 21,168 像素 → 但有条件跳过，实际 < 21168

### 2.4 内层循环微架构分析

**badcheck X runs 指令混合** (16 条/iter):
- lbu: 4 (25%) — 位操作读 framebase, rlens, WD
- ld: 2 (12.5%) — qrframe/rlens 基址
- mulw: 1 (6.25%) — WDB*y 行偏移计算
- srliw/sraw/andi/not: 4 (25%) — 位提取
- addw/addiw: 3 (18.75%) — 索引计算
- bne/bgeu: 2 (12.5%) — 颜色比较 + 循环控制

**关键依赖链** (badcheck X runs):
```
lbu a7 (WDB) ──→ mulw a7,a7,s11 ──→ addw a4,a4,a7 ──→ add a5,a6,a4 ──→ lbu a5 ──→ sraw ──→ andi ──→ bne
```
延迟: lbu(2) + mulw(3) + addw(1) + add(1) + lbu(2) + sraw(1) + andi(1) + branch(1) = **12 cycles**

**applymask 关键依赖链**:
```
ismasked:  mulw(s0*s0) ──→ addw ──→ srliw ──→ add ──→ lbu ──→ sraw ──→ andi ──→ bnez
TOGQRBIT:  mulw(WDB*y) ──→ addw ──→ add ──→ lbu ──→ xor ──→ sb
```
ismasked 延迟: mulw(3) + addw(1) + srliw(1) + add(1) + lbu(2) + sraw(1) + andi(1) = **10 cycles**

**循环携带依赖**:
- badcheck: `a2` (x 计数器) 每迭代 +1, `a0/t3` (h) 条件更新, `s10` (bw) 累加 — 均为 1 cycle ALU
- applymask: `a4` (x 计数器), `a2/t3` (r3x/r3y) — 均为 1 cycle ALU

**预计 IPC (OoO core)**:
- badcheck X runs: 16 条/12 cycles ≈ 1.33 IPC（mulw→lbu 依赖链是瓶颈）
- applymask: 含 ismasked (10 cycles) + TOGQRBIT (conditional)，多路并行可能提升
- mulw 每迭代都要计算 WDB*y 行偏移，编译器未提升到外层循环（因为 WDB 通过 volatile-like 全局加载）

## 3. 总结

```
算法:           QR Version 1 (21x21) 编码 + 8 种掩码评估
数据量:         ~700B (帧 63B + 掩码 28B + runs 22B + GF表 512B, 全驻 L1D)
计算类型:       位操作密集型 (QRBIT/SETQRBIT/TOGQRBIT) + GF(256) 查表
内层循环指令数: badcheck ~16 条, applymask ~20 条
热点函数占比:   badcheck 68.5%, applymask 19.4%, badruns 9.8%
瓶颈预测:       compute-bound (mulw 行偏移计算 + 位提取依赖链 ~12 cycles)
分支特征:       双层循环 trip=21, 条件分支 (掩码/颜色比较)
特殊说明:       mulw 在每次像素访问中出现 (WDB*y), 是最大延迟贡献者
```
