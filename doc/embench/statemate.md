# statemate 性能分析

## 1. 源码分析

### 1.1 基本信息

| 项目 | 值 |
|------|-----|
| 源文件 | `thirdparty/embench-iot/src/statemate/libstatemate.c` |
| 算法描述 | STARC 自动生成的状态图（StateChart）代码，模拟汽车车窗升降控制器 |
| LOCAL_SCALE_FACTOR | 3330 |
| 数据类型 | `char`（状态变量、Bitlist 位标记）、`int`/`unsigned long`（计时器、计数器） |
| 代码来源 | C-LAB STARC 代码生成器，原始 StateChart 描述汽车车窗升降控制逻辑 |

### 1.2 调用链

```
benchmark()
  benchmark_body(3330, 1)              // LSF=3330, GSF=1
    for lsf_cnt in 0..3329:
      for gsf_cnt in 0..0:
        memset(Bitlist, 0, 64)         // 清零 64 字节 Bitlist
        init()                         // 初始化所有状态机 next_state = 0
        interface()                    // 更新接口计时器
        FH_DU()                        // 主状态机执行
          while (!stable):             // 稳定点迭代（通常 2 次）
            step++
            switch(FH_STEUERUNG_DUMMY) // 虚拟驱动状态机
            // 设置 active/copy 位
            generic_KINDERSICHERUNG_CTRL()   // 儿童安全锁控制
            // 复制状态到 FH_DU 镜像变量
            generic_FH_TUERMODUL_CTRL()      // 车门模块控制（最复杂）
            // 复制状态到 FH_DU 镜像变量
            generic_EINKLEMMSCHUTZ_CTRL()    // 防夹控制
            // 复制状态到 FH_DU 镜像变量
            generic_BLOCK_ERKENNUNG_CTRL()   // 阻塞检测控制
            // 复制状态到 FH_DU 镜像变量
            // 更新 _old 变量，copy -> current
```

### 1.3 核心计算函数

`FH_DU()` 是主执行体，包含一个 `while (!stable)` 循环。每次循环先设 `stable=1`，然后执行所有子状态机。任何状态机发生状态转换都会设 `stable=0`，触发再次迭代。

```c
void FH_DU(void) {
  time = 1;
  stable = 0;
  step = 0;
  while (!stable) {
    stable = 1;
    step++;
    // FH_STEUERUNG_DUMMY 状态机（3 states: SCHLIESSEN/BEREIT/OEFFNEN）
    switch (FH_STEUERUNG_DUMMY_FH_STEUERUNG_DUMMY_next_state) { ... }

    // 设置子状态机 active 位
    // generic_KINDERSICHERUNG_CTRL()  -- 嵌入在 FH_DU 中（被 inline）
    // ... 大量变量赋值（状态镜像）...
    // generic_FH_TUERMODUL_CTRL()     -- 被 inline
    // ... 大量变量赋值 ...
    // generic_EINKLEMMSCHUTZ_CTRL()   -- 调用
    // ... 大量变量赋值 ...
    // generic_BLOCK_ERKENNUNG_CTRL()  -- 调用
    // ... 大量变量赋值 ...
    // 更新 _old = _current, _current = _copy
  }
}
```

`generic_FH_TUERMODUL_CTRL()` 是最复杂的子状态机，包含多层嵌套 switch-case：

```c
void generic_FH_TUERMODUL_CTRL(void) {
  // B_FH_TUERMODUL_CTRL_next_state: 3 states
  switch (B_FH_TUERMODUL_CTRL_next_state) {
    case 3: // INITIALISIERT
      switch (INITIALISIERT_FH_TUERMODUL_CTRL_next_state) {
        case 1: // OEFFNEN
          switch (OEFFNEN_FH_TUERMODUL_CTRL_next_state) { ... }
        case 2: // SCHLIESSEN
          switch (SCHLIESSEN_FH_TUERMODUL_CTRL_next_state) {
            case 1: // TIPP_SCHLIESSEN
              switch (TIPP_SCHLIESSEN_FH_TUERMODUL_CTRL_next_state) { ... }
            case 2: // MANUELL_SCHLIESSEN
              switch (MANUELL_SCHLIESSEN_FH_TUERMODUL_CTRL_next_state) { ... }
          }
        case 3: // BEREIT
      }
  }
  // A_FH_TUERMODUL_CTRL_next_state: WIEDERHOLSPERRE 子状态机
  switch (A_FH_TUERMODUL_CTRL_next_state) { ... }
}
```

### 1.4 循环结构

| 循环层 | 变量 | Trip Count | 说明 |
|--------|------|------------|------|
| L0 | lsf_cnt | 3330 | LSF 缩放循环 |
| L1 | gsf_cnt | 1 | GSF 缩放循环 |
| L2 | while(!stable) | ~2 | FH_DU 稳定点迭代，初始化后通常 2 次收敛 |

总外层迭代：3330 次 FH_DU 调用，每次 ~2 轮稳定点循环 = ~6660 轮状态机执行。

### 1.5 访存模式

- **全局变量密集**：约 50+ 个全局 `char`/`int`/`unsigned long` 变量，编译器通过 gp 相对寻址访问（如 `lbu a0, -1999(gp)`）
- **Bitlist 数组**：64 字节 char 数组，用作位标记，通过索引访问（`lbu`/`sb`）
- **无动态分配**：所有数据都是全局变量或栈上局部变量
- **工作集极小**：所有活跃数据 < 512 字节，完全驻留 L1D cache
- **写回模式**：每轮循环末尾大量 `sb`/`sw` 写回 `_old`、`_copy` 变量

### 1.6 计算特征

- **纯控制流**：几乎没有算术计算，核心是 switch-case + if-else 链
- **分支密集**：每个子状态机都是 2-4 路 switch + 多个条件判断
- **分支高度可预测**：初始化后状态不变，每次迭代走相同路径，分支模式固定
- **字节级操作**：大量 `lbu`/`sb` 操作（char 类型全局变量）
- **无浮点**：`#define float int` 将所有浮点替换为整数

## 2. 汇编热点分析

### 2.1 Spike 执行概况

| 指标 | 值 |
|------|-----|
| 总指令数 (instret) | 1,711,663 |
| 总周期数 (cycles) | 1,711,660 |
| IPC (spike) | 1.0000 |
| trace 总行数 | 2,500,062 |
| 用户态指令数 | ~1,849,760 |

### 2.2 核心函数反汇编

**benchmark_body 主循环** (0x111e8)：

```asm
# 每次迭代：清零 Bitlist + init + interface + FH_DU
11204:  sd    zero, 0(s0)           # memset Bitlist[0..7] = 0
11208:  sd    zero, 8(s0)           # Bitlist[8..15] = 0
1120c:  sd    zero, 16(s0)          # Bitlist[16..23] = 0
11210:  sd    zero, 24(s0)          # Bitlist[24..31] = 0
11214:  sd    zero, 32(s0)          # Bitlist[32..39] = 0
11218:  sd    zero, 40(s0)          # Bitlist[40..47] = 0
1121c:  sd    zero, 48(s0)          # Bitlist[48..55] = 0
11220:  sd    zero, 56(s0)          # Bitlist[56..63] = 0
11224:  jal   init                  # 初始化状态机
11228:  jal   interface             # 更新接口计时器
1122c:  addiw s1, s1, 1             # gsf_cnt++
1122e:  jal   FH_DU                 # 主状态机执行
11232:  bne   s1, s2, 11204         # gsf_cnt < gsf ?
```

**FH_DU() 函数** (0x10d5c，占 78.7%)：

编译器将 `generic_KINDERSICHERUNG_CTRL` 和 `generic_FH_TUERMODUL_CTRL` 内联到 FH_DU 中。函数开头加载大量全局变量到寄存器：

```asm
10d5c:  lbu   a3, -1987(gp)        # FH_DU__S_FH_TMBFZUCAN
10d60:  lbu   t5, -1988(gp)        # FH_DU__S_FH_TMBFZUCAN_old
10d66:  lbu   a6, -1991(gp)        # FH_DU__S_FH_TMBFAUFDISC
# ... 保存 callee-saved 寄存器 ...
10d84:  addi  a5, gp, -1748        # a5 = &Bitlist[0]
10d88:  lbu   t2, -1992(gp)        # FH_DU__S_FH_TMBFAUFDISC_old
10d8c:  lbu   t0, -1986(gp)        # FH_DU__S_FH_TMBFAUFCAN_old
# ... 更多全局变量加载 ...
```

状态机 switch-case 编译为分支链：

```asm
# FH_STEUERUNG_DUMMY 状态机
10dc4:  beq   a0, s6, 11188        # case 2: BEREIT
10dca:  beq   a0, s6, 11176        # case 3: OEFFNEN
10dce:  bne   a0, a2, 10dde        # case 1: SCHLIESSEN
10dd2:  lbu   a0, -1999(gp)        # FH_DU__MFHZ
10dd6:  bnez  a0, 10dec            # if (MFHZ) ...
10dd8:  lbu   a0, -2001(gp)        # FH_DU__MFHZ_old
10ddc:  beqz  a0, 10dec            # if (!MFHZ_old) ...
10dde:  sb    zero, -2019(gp)      # stable = 0
```

大量变量赋值段（状态镜像传递）：

```asm
# FH_DU -> FH_TUERMODUL 变量同步
10ed6:  sb    a0, -1994(gp)        # FH_DU__S_FH_AUFDISC = ...
10eda:  sb    a4, -1981(gp)        # FH_DU__S_FH_FTAUF = ...
10ede:  sb    a1, -1993(gp)        # FH_DU__S_FH_ZUDISC = ...
10ee2:  sb    a3, -1980(gp)        # FH_DU__S_FH_FTZU = ...
10ee6:  sb    t0, -2002(gp)        # FH_DU__MFHA = ...
10eea:  sb    t6, -1999(gp)        # FH_DU__MFHZ = ...
# ... 约 15 条 sb/sw 指令 ...
```

### 2.3 热点 PC 分布

| 函数 | 指令数 | 占比 | 说明 |
|------|--------|------|------|
| FH_DU() | 1,455,647 | 78.7% | 主状态机（含内联的子状态机） |
| interface() | 69,951 | 3.8% | 接口计时器更新 |
| init() | 66,620 | 3.6% | 状态机初始化 |
| benchmark_body() | 53,339 | 2.9% | 外层循环 + memset Bitlist |
| generic_BLOCK_ERKENNUNG_CTRL() | 39,972 | 2.2% | 阻塞检测（未内联） |
| generic_EINKLEMMSCHUTZ_CTRL() | 26,648 | 1.4% | 防夹控制（未内联） |
| 其他 | ~138,583 | 7.4% | 内核态等 |

FH_DU 内部指令分布高度均匀，每个 PC 执行 6,662 次（= 3330 lsf x ~2 stable 迭代），说明 while 循环每次恰好执行 2 轮。

### 2.4 内层循环微架构分析

**FH_DU while 循环特征**：

- **指令混合**：
  - `lbu`/`sb`：字节级全局变量读写（~40%）
  - `beq`/`bne`/`bnez`/`beqz`：条件分支（~25%）
  - `lw`/`sw`：32 位全局变量读写（~10%）
  - `li`/`addi`/`mv`：常量和寄存器传递（~15%）
  - `jal`：函数调用 generic_EINKLEMMSCHUTZ_CTRL, generic_BLOCK_ERKENNUNG_CTRL（~10%）

- **依赖链**：
  - 全局变量 load -> 比较 -> 分支：`lbu a0, offset(gp)` -> `beqz a0, target`
  - load-to-branch 延迟是关键路径（L1D 1-cycle hit + branch resolve）

- **分支可预测性**：
  - 初始化后状态确定，每次 FH_DU 执行走完全相同的路径
  - 3330 次重复后，分支预测器应达到 >99% 准确率
  - switch-case 编译为级联 beq/bne，目标固定

- **循环携带依赖**：
  - `stable` 变量在 while 循环间传递（但编译器已将其保持在寄存器中）
  - 各 `_old` = `_current`、`_current` = `_copy` 的赋值无数据依赖，可并行执行

- **预计 IPC（乱序核）**：
  - 大量独立的 sb/lbu 到不同地址，可并行执行
  - 分支高度可预测（固定路径）
  - 主要瓶颈：store buffer 容量（大量连续 sb 指令）
  - 预计 IPC：2.0-3.0

## 3. 总结

| 项目 | 值 |
|------|-----|
| 算法 | StateChart 状态机模拟（汽车车窗升降控制器） |
| 数据量 | ~50 个全局变量，64 字节 Bitlist |
| 计算类型 | 纯控制流（switch-case + if-else），字节级读写 |
| 内层循环指令数 | FH_DU while 循环体 ~219 条/iteration |
| 内层循环占比 | FH_DU 78.7%（含内联子状态机） |
| 瓶颈预测 | store buffer 容量（大量 sb），分支预测高度可预测 |

**微架构敏感点**：
1. **分支预测友好**：状态机每次走相同路径，级联 beq/bne 模式固定，TAGE 预测器可轻松记忆
2. **全局变量访问模式**：gp-relative 寻址，所有变量在 ~256B 范围内，L1D 完全命中
3. **字节操作密集**：大量 lbu/sb（char 类型状态变量），byte 级 load/store 效率影响性能
4. **Store-to-Load 转发**：同一变量可能在 while 循环的不同阶段先 sb 再 lbu，store forwarding 延迟影响关键路径
5. **函数调用开销**：generic_EINKLEMMSCHUTZ_CTRL 和 generic_BLOCK_ERKENNUNG_CTRL 未被内联，每次 while 循环 2 次 jal/ret
