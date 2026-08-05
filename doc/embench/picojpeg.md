# picojpeg 性能分析

## 1. 源码分析

### 1.1 基本信息

| 项目 | 内容 |
|------|------|
| 源文件 | `libpicojpeg.c` (2526行), `picojpeg_test.c` |
| 算法描述 | 微型 JPEG 解码器 (picojpeg)，支持 baseline DCT JPEG 解码，包含 Huffman 解码、反量化、Winograd IDCT、色彩空间转换 (YCbCr -> RGB) |
| LOCAL_SCALE_FACTOR | 5 |
| GLOBAL_SCALE_FACTOR | 1 (默认) |
| 数据类型 | `uint8` (unsigned char), `int16` (signed short), `uint16` (unsigned short), `long` (用于 IDCT 乘法) |
| 输入数据 | 内嵌 276 字节 JPEG 数据 (64x51 像素，YH2V2 采样) |

### 1.2 调用链

```
benchmark()
  -> benchmark_body(lsf=5, gsf=1)
       -> 5次迭代:
            pjpeg_decode_init()          -- 解析 JPEG header
            for(;;):
              pjpeg_decode_mcu()         -- 解码每个 MCU (核心热点)
                -> decodeNextMCU()
                    -> huffDecode()      -- Huffman 解码 (逐位读取)
                        -> getBit()      -- 从比特流读取 1 bit
                    -> getBits()         -- 读取 N bits
                        -> getOctet()    -- 读取 1 字节
                            -> getChar() -- 从输入缓冲区读取
                    -> idctRows()        -- 1D IDCT (行方向, Winograd)
                    -> idctCols()        -- 1D IDCT (列方向, Winograd)
                    -> transformBlock()
                        -> copyY()       -- Y 通道复制到 RGB
                        -> convertCb()   -- Cb -> RGB 色彩转换
                        -> convertCr()   -- Cr -> RGB 色彩转换
                        -> upsampleCb/Cr() -- 色度上采样
```

### 1.3 核心计算函数

**huffDecode -- Huffman 逐位解码:**
```c
static uint8 huffDecode(const HuffTable *pHuffTable, const uint8 *pHuffVal) {
    uint8 i = 0;
    uint16 code = getBit();
    for (;;) {
        uint16 maxCode;
        if (i == 16) return 0;
        maxCode = pHuffTable->mMaxCode[i];
        if ((code <= maxCode) && (maxCode != 0xFFFF)) break;
        i++;
        code <<= 1;
        code |= getBit();
    }
    j = pHuffTable->mValPtr[i];
    j = (uint8)(j + (code - pHuffTable->mMinCode[i]));
    return pHuffVal[j];
}
```

**idctRows / idctCols -- Winograd IDCT:**
```c
// 每行/列: 5 次乘法 (imul_b1_b3, imul_b2, imul_b4, imul_b5)
// 乘法函数: x * const + 128, 然后算术右移 8 位
static int16 imul_b1_b3(int16 w) {
    long x = (w * 362L); x += 128L;
    return (int16)(x >> 8);
}
```

**convertCr -- Cr 色彩空间转换:**
```c
for (i = 64; i > 0; i--) {
    uint8 cr = (uint8)*pSrc++;
    crR = (cr + ((cr * 103U) >> 8U)) - 179;
    *pDstR = addAndClamp(pDstR[0], crR);
    pDstR++;
    crG = ((cr * 183U) >> 8U) - 91;
    *pDstG = subAndClamp(pDstG[0], crG);
    pDstG++;
}
```

### 1.4 循环结构

| 循环层 | 变量 | Trip Count | 说明 |
|--------|------|-----------|------|
| L0 | lsf_cnt | 5 | LOCAL_SCALE_FACTOR |
| L1 | gsf_cnt | 1 | GLOBAL_SCALE_FACTOR |
| L2 | MCU loop | ~40 | 64x51 图像, YH2V2: (4*7)=28 MCU, 每 MCU 6 block |
| L3 | mcuBlock | 6 | YH2V2: 4Y + 1Cb + 1Cr |
| L4-huffDecode | i | 1-16 | Huffman 表逐位匹配 |
| L4-idctRows | i | 8 | 8 行 IDCT |
| L4-idctCols | i | 8 | 8 列 IDCT |
| L4-copyY/convertCb/Cr | i | 64 | 8x8 block 像素处理 |
| L4-upsampleCb/Cr | y*x | 4*4=16 | 色度上采样 |
| L4-coefficient decode | k | 0-63 | 每 block 最多 64 个 DCT 系数 |

### 1.5 访存模式

- **顺序读取**: JPEG 比特流通过 `gInBuf[256]` 缓冲区顺序消费
- **随机写入**: IDCT 系数写入 `gCoeffBuf[64]` (int16)，列方向 IDCT 步长为 8 (16字节)
- **全局变量密集**: 大量全局 static 变量 (gBitBuf, gBitsLeft, gInBufOfs 等)，频繁 load/store 到 gp-relative 地址
- **小数组**: 所有 buffer 都很小 (gCoeffBuf 128B, gMCUBufR/G/B 各 256B)，完全在 L1 cache 内
- **查表**: ZAG 表 (64B), Huffman 表 (mMinCode/mMaxCode/mValPtr 各 16 entry), 量化表 (64 int16)

### 1.6 计算特征

- **位操作密集**: Huffman 解码逐 bit 操作，大量移位和掩码
- **短整数算术**: 主要是 16-bit 乘法和移位 (IDCT 的 imul_b* 函数, 色彩转换的 `cr * 103U >> 8`)
- **饱和截断**: `clamp()` / `addAndClamp()` / `subAndClamp()` 进行 0-255 范围截断
- **分支密集**: huffDecode 内层循环每次迭代都有条件分支; getBit 需要检查 gBitsLeft 是否为 0
- **函数调用频繁**: huffDecode -> getBit 每次 1 bit 读取都是函数调用

## 2. 汇编热点分析

### 2.1 Spike 执行概况

| 指标 | 值 |
|------|-----|
| Total cycles | 2,820,273 |
| Total instret | 2,820,276 |
| IPC (spike) | 1.0000 |
| Trace 总行数 | 4,191,546 |
| 用户态指令数 | 3,660,807 |

### 2.2 核心函数反汇编

**getBit -- 读取 1 bit (占总指令 2.8%):**
```asm
getBit:
    lhu   a0, gBitBuf(gp)       # 加载 16-bit 比特缓冲区
    lbu   a5, gBitsLeft(gp)     # 加载剩余 bit 数
    srli  a2, a0, 15            # 取最高 bit 作为返回值
    beqz  a5, .Lrefill          # 若无剩余 bit, 需要 refill
    addiw a5, a5, -1            # gBitsLeft--
    slliw a0, a0, 1             # gBitBuf <<= 1
    sh    a0, gBitBuf(gp)       # 写回
    sb    a5, gBitsLeft(gp)     # 写回
    mv    a0, a2                # 返回值
    ret
```

**huffDecode 内层循环 -- Huffman 表匹配:**
```asm
.Lloop:
    lhu   a5, 0(s1)             # maxCode = pHuffTable->mMaxCode[i]
    sext.w a4, a0               # code (sign-extend)
    slliw s2, a0, 1             # code << 1 (为下次迭代准备)
    bltu  a5, a4, .Lnext        # if maxCode < code, 继续
    bne   a5, s5, .Lfound       # if maxCode != 0xFFFF, 找到
.Lnext:
    jal   getBit                # 读取下一个 bit
    or    a0, a0, s2            # code |= getBit()
    slli  a0, a0, 0x30          # 截断为 16-bit
    srli  a0, a0, 0x30
    addiw s0, s0, 1             # i++
    addi  s1, s1, 2             # 指向下一个 maxCode entry
    bne   s0, s4, .Lloop        # if i != 16, 继续循环
```

**convertCr 内层循环 -- Cr 到 RGB 转换 (占总指令 ~10%):**
```asm
    # a5 = cr, t3 = 常数 103, a6 = 常数 183, a7 = 常数 91
.Lcr_loop:
    lbu   a5, 0(a0)             # cr = *pSrc (低 8 位)
    lbu   t4, 0(a1)             # *pDstR 当前值
    addi  a0, a0, 2             # pSrc += 1 (int16 步长)
    mulw  a4, a5, t3            # cr * 103
    addiw t5, a5, -179          # cr - 179
    srliw a4, a4, 8             # (cr * 103) >> 8
    addw  a4, a4, t5            # crR = (cr*103>>8) + cr - 179
    addw  a4, a4, t4            # crR + *pDstR
    slli  a4, a4, 0x30          # 截断为 uint16
    srli  a4, a4, 0x30
    mv    t4, a4
    bgeu  a6, a4, .Lno_clamp_r  # if crR <= 255, 不需要 clamp
    not   a4, a4                # clamp 逻辑
    slli  t5, a4, 0x30
    srai  t4, t5, 0x3f          # t4 = (a5 < 0) ? 0 : 255
.Lno_clamp_r:
    mulw  a5, a5, a7            # cr * 183
    sb    t4, 0(a1)             # *pDstR = clamped_value
    lbu   a4, 0(a2)             # *pDstG 当前值
    addi  a1, a1, 1             # pDstR++
    srliw a5, a5, 8             # (cr * 183) >> 8
    subw  a5, a7, a5            # crG = 91 - (cr*183>>8)
    addw  a5, a5, a4            # *pDstG - crG
    ...clamp and store...
    bne   a3, a4, .Lcr_loop     # 循环到下一个像素
```

### 2.3 热点 PC 分布

| 函数 | 动态指令数 | 占比 |
|------|-----------|------|
| pjpeg_decode_mcu (含内联) | 2,781,480 | 75.98% |
| huffDecode | 226,950 | 6.20% |
| getBits | 128,298 | 3.50% |
| getBit | 103,032 | 2.81% |
| getChar | 55,050 | 1.50% |
| getOctet | 49,188 | 1.34% |
| processMarkers | 31,716 | 0.87% |
| pjpeg_decode_init | 3,426 | 0.09% |
| other (libc/pk等) | 281,667 | 7.69% |

注: `pjpeg_decode_mcu` 中内联了 idctRows, idctCols, transformBlock, copyY, convertCb, convertCr, upsampleCb/Cr 等函数，是主要热点。huffDecode/getBit/getBits/getOctet/getChar 是独立函数。

**pjpeg_decode_mcu 内部热点子区域:**

- **系数清零循环** (0x11bfc-0x11c0a): 每 PC 执行 60,174 次 -- 6条指令 x 60174 = 361,044 条
  这是对 gCoeffBuf 按 ZAG 顺序清零的循环，每个 block 都会执行
- **convertCr 循环** (0x1252c-0x12594): 每 PC 执行 21,504 次 -- ~28条指令 x 21504 = 602,112 条
- **convertCb 循环** (0x11e78-0x11ee2): 每 PC 执行 21,504 次 -- ~28条指令 x 21504 = 602,112 条

### 2.4 内层循环微架构分析

**系数清零循环 (最热循环):**
```asm
    lb    a4, 0(a5)       # 从 ZAG 表读取索引
    addi  a5, a5, 1       # ZAG 指针++
    slli  a4, a4, 1       # 索引 * 2 (int16 步长)
    add   a4, a4, s0      # gCoeffBuf + index
    sh    zero, 0(a4)     # gCoeffBuf[index] = 0
    bne   a3, a5, loop    # 循环
```
- 6 条指令/迭代
- 依赖链: lb -> slli -> add -> sh (3 级 ALU 依赖 + 1 store)
- lb 有 load-use 延迟 (通常 3-4 周期)
- 循环携带依赖: addi a5,a5,1 (1 周期)，但 lb 的地址依赖在 a5 上
- 预计 IPC: 受 lb load-use 延迟限制，约 1.5-2.0 (若 L1 命中)

**色彩转换循环 (convertCr):**
- 每迭代约 28 条指令
- 包含 2 个 mulw (cr*103, cr*183)
- 包含 2 个 clamp 分支 (通常不触发, branch 可预测)
- 依赖链: lbu -> mulw -> srliw -> addw -> addw -> slli -> srli (长链)
- 预计 IPC: 约 1.5-2.0, 受乘法延迟和 load-use 限制

## 3. 总结

| 项目 | 内容 |
|------|------|
| 算法 | JPEG baseline DCT 解码 (Huffman + 反量化 + Winograd IDCT + YCbCr->RGB) |
| 数据量 | 276 字节 JPEG, 64x51 像素, YH2V2 采样, 5次重复 |
| 计算类型 | 位操作 (Huffman), 16-bit 整数乘法 (IDCT/色彩转换), 字节级 load/store |
| 内层循环指令数 | 系数清零: 6条; 色彩转换: ~28条; Huffman: ~12条/bit |
| 内层循环占比 | pjpeg_decode_mcu (含内联): 76%; 加上 huffDecode/getBit/getBits: ~90% |
| 瓶颈预测 | 1) **load-use 延迟**: 全局变量频繁读写 (gBitBuf/gBitsLeft) 形成 RAW 依赖; 2) **分支预测**: huffDecode 逐 bit 循环的退出分支取决于 Huffman 码长 (1-16 bit 不等), 不规则; 3) **函数调用开销**: huffDecode -> getBit 每读 1 bit 都是完整的 call/ret; 4) **乘法延迟**: IDCT 和色彩转换中的 mulw 指令串行依赖 |
