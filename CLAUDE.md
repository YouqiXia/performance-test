# riscv-uarch-bench — RISC-V Microarchitecture Benchmark Suite

## 项目概述

通过内联汇编微基准测试逆向验证 RISC-V 乱序核的动态调度行为。通过 `arch/` 下的 profile 文件适配不同微架构。

## 架构设计意图

本节说明仓库工作模式的设计决策和原理，不重复 README.md 已有的使用说明。

### env 驱动配置

工具链路径、ISA 字符串、arch profile 全部通过 `env/default.env` 集中管理。格式为纯 `KEY=VALUE`——这是 shell `source` 和 Makefile `-include` 的最大公约数，零依赖、零解析器。选择 env 而非 JSON 是因为消费者全是 shell 脚本和 Makefile。

每份 env 文件必须是完整定义（不做 overlay），切换环境时整份替换：`UARCH_ENV=mybox make`。

### install/ 与 thirdparty/ 分离

`thirdparty/` 存源码（git submodule），`install/` 存构建产物。脚本通过固定相对路径（`install/riscv-isa-sim/bin/spike`）引用，用户不需要配置 spike/pk 路径。这消除了旧版 Makefile 中散落在 `$HOME/workspace/` 下的硬编码路径。

### 为什么 linux/spike binary 分开编译

`CALC_NLOOP(X)` 在编译期展开为常量。spike 模拟需要小循环（100K 级 INSN_BUDGET），Linux 硬件需要大循环（200M 级���获得统计精度。这个差异无法运行时化（改成变量会动所有 main.c 且引入运行时开销），因此必须分开编译。`-DUSE_SPIKE` 只控制 INSN_BUDGET 和 CALC_NLOOP floor 值。

### 测量路径运行时 fallback

`perf_helpers.c` 中 `perf_init()` 始终尝试 `perf_event_open()`，失败则自动降级到 `rdcycle/rdinstret` CSR。这与 embench `boardsupport.c` 的行为对齐。旧版用编译期 `#if !defined(USE_SPIKE)` gate 切换测量路径，新版去掉该条件，让同一套测量代码在 Linux 和 spike 上都能正确工作。

### 二级 CLI dispatch

`uarch build` 下的 `thirdparty`/`uarch`/`embench` 三个 scope 逻辑完全不同（三方库 configure+make vs Makefile target vs scons），放一个文件里只会越来越臃���。二级 dispatch（`uarch-build` → `uarch-build-*`）与一级 `uarch` dispatcher 同构，每个子脚本独立维护。未来加 QEMU 只需新增 `uarch-build-thirdparty` 里的一个 case + `uarch init qemu` preset。

### `-DCHECKPOINT` 必须保持编译期

checkpoint 触发 ELF 页面预加载 + CSR 0x800 快照写入，是 one-shot 硬件指令，不适合运行时化。

### run config 的变量模板

`{spike}`、`{pk}`、`{march}` 在 config 加载时从 env+install/ 解析替换，`{elf}`、`{checkpoint}` 在测试执行时 per-test 替换。两阶段设计使 run config 可移植——换机器只改 env，不用重新 init。

### QEMU system-mode（TBD）

架构上已预留位置（env/install/build/init），但实现标 TBD。与 spike user-mode 不同，QEMU system-mode 提供真实 perf_event 能力（完整 Linux guest），适合无硬件环境下的性能测试。需要 kernel image + 最小 rootfs + guest 内自动化。

## 内部约定

### env 文件

```bash
# env/default.env — 纯 KEY=VALUE，无 export、无条件逻辑
RISCV_TOOLCHAIN=/opt/riscv
MARCH=rv64gcv_zba_zbb_zbs_zicbom_zicbop_zicntr_zifencei_zihintpause_zihintntl
ARCH=default
```

- Makefile：`-include env/$(or $(UARCH_ENV),default).env`
- Shell：`source "$PROJECT_DIR/env/${UARCH_ENV:-default}.env"`
- 工具链推导：linux/spike 用 `linux-gnu-gcc`，pk 构建用 `elf-gcc`，均从 `RISCV_TOOLCHAIN` 拼路径

### install/ 路径

```bash
SPIKE_BIN="$PROJECT_DIR/install/riscv-isa-sim/bin/spike"
SPIKE_PK="$PROJECT_DIR/install/pk/pk"
```

### bin/ 布局

```
bin/{linux,spike,checkpoint,embench/}
```

Makefile 通过 target-specific `BINDIR` 覆盖。

## Arch Profile 机制

通过 `ARCH` 变量（从 env 读取）选择 `arch/<ARCH>.h`，将微架构参数注入所有测试。`#include "arch_params.h"` 消费宏。

Profile 中必须定义的宏：

| 宏 | 说明 | 消费者 |
|----|------|--------|
| `ARCH_CACHELINE` | cacheline 大小（字节） | cache_size, load_use_l2, branch_order |
| `ARCH_L1D_SIZE` | L1D 大小（字节） | pipeline_depth |
| `ARCH_L1D_WAYS` | L1D 组相联度 | pipeline_depth |
| `ARCH_L2_WORKING_SET` | L2 测试工作集大小 | load_use_l2, branch_order |
| `ARCH_L2_EVICT_BUF` | L1 驱逐 buffer 大小 | iq_pressure |

## Latency / Throughput 测试

按 dispatch type 分组（ALU, BMU, MUL, DIV, LOAD, STORE, AMO, FADD, FMUL, FMA, FDIV, FSQRT, FMISC, FCLASS, FCMP, FCVT, FMV, BRU, CSR），每组一个目录、一个 binary。

**结构**：`src/{latency,throughput}/<DISPATCH_TYPE>/main.c` + `<type>.S`
- `.S` 文件包含多个 `test_<insn>` 函数，每个函数有独立标签（`.L_<insn>_loop`/`.L_<insn>_done`）
- `main.c` 用表驱动循环运行所有 variant，共享 perf_init/close 和 buffer 分配

**Latency 构造方法**：
- 自链法（输出回到输入）：`add t0,t0,t1`、`fadd.d ft0,ft0,ft1` 等，insn_per_iter=1
- 往返链（跨域指令）：如 `fclass.d t0,ft0` + `fmv.d.x ft0,t0`，insn_per_iter=2
- Store forwarding：`sd t0,0(a1)` + `ld t0,0(a1)`，insn_per_iter=2

**Throughput 构造方法**：
- 4 条独立指令 × `.rept N`，消除依赖，测最大发射带宽

## 代码规范

### .S 文件

- 每个函数签名：`void test_xxx(uint64_t nloop [, uint64_t *buf])`
- `a0` = nloop（外层循环次数），`a1` = 可选的内存指针
- 内部用 `t3` 做循环计数器，`.rept N` 展开核心段
- 总迭代 = nloop × N
- 需要内存地址的测试：由 main.c 分配并通过 `a1` 传入，.S 不自行构造地址
- 链式依赖通过 `t0`（INT）或 `ft0`（FP）维持
- 链断开的测试用 `⚠️` 标注

### main.c

- `#include "perf_helpers.h"`
- 分配 node/scratch buffer，初始化 FP 寄存器
- 使用 `perf_init/start/stop/print/close` API
- **每个 test variant 在 `perf_start` 之前必须有 warmup 调用**：用与正式测量相同的函数和参数调用一次，预热 icache/iTLB/branch predictor。禁止省略 warmup 直接测量。模板：
  ```c
  test_xxx(warmup_n, buf);      /* warmup — 必须有 */
  perf_start(&ctx);
  test_xxx(NLOOP, buf);         /* 正式测量 */
  perf_stop(&ctx, &cycles, &instret);
  ```
- **`perf_print` 必须传入正确的 `insn_per_iter`**：每个 variant 调用 `perf_print` 时，`insn_per_iter` 参数必须等于该 variant `.rept` 内层中每次迭代的指令条数（即 Critical Section 中的实际汇编指令数）。这是计算总指令数和验证 IPC 的关键参数。

### 新增测试

1. 在 `src/<类别>/<name>/` 创建 `main.c` + `<name>.S` + `README.md`（RISC-V）
2. `make spike` 编译 spike 版本，`make spike-run` 在模拟器上验证功能正确性
3. 确认构造正确后，`make` 交叉编译部署到目标机

### NLOOP 自动计算

`NLOOP` 由 `CALC_NLOOP(X)` 根据 `INSN_BUDGET` 自动计算（spike ~100K，Linux ~200M）。
每个 test 的 main.c 在 `#include "perf_helpers.h"` **之前** 定义：

```c
#define NLOOP  CALC_NLOOP(300)   /* .rept=100, max 3 insn/iter */
#include "perf_helpers.h"
```

**X 的计算方法**：取该 test 中最重 variant 的 `max(.rept × insn_per_iter)`。
- `.rept` 从 .S 文件中读取
- `insn_per_iter` 从 main.c 的 `run1/run2/perf_print` 调用中读取
- 特殊测试（无 .rept、C 内循环等）按实际每次外层迭代的总指令数计算

## 关键测试设计说明

以下测试采用了特殊构造，需要注意：

- **branch_redirect**: 使用 4KB jalr sled（1024 个 `j .Ljr_merge` 目标），PRNG 随机选择跳转地址使 BTB/iTTAGE 完全无法预测，测量纯 pipeline redirect 延迟
- **branch_order**: 使用 L2 pointer chase 作为慢源（working set 来自 `ARCH_L2_WORKING_SET`），K 从 0 到 20 扫描 slow/fast 对，通过曲线形状判断 branch resolve 是否 out-of-order
- **store_split**: 使用 matmul 风格核心（C[j] += A[k]*B[j]），Variant A addr 提前 ready，Variant B 人为让 addr 依赖 data，差值反映 store data/addr 分离调度程度
- **pipeline_depth**: 使用 L1 set conflict 制造 surprise miss（`ARCH_L1D_WAYS`+1 个同 set 地址 evict 第 1 个），对比 scheduler 是否有 miss predictor

## README 结构规范

每个测试的 README.md 必须包含以下章节：

1. **标题 + 一句话目标**
2. **文档事实** — 来自架构手册的已知参数
3. **待验证** — 本测试要回答的问题
4. **Critical Section** — 每个 test variant 的实际 `.rept` 内层汇编代码，必须与 .S 文件一致。每段代码上方有 `# 构造：` 注释说明：
   - 为什么选这个寄存器（如 t0 链式传递、t1=0/1 保持值不变）
   - 为什么选这种链结构（如自环指针、pointer chase、matmul 风格）
   - 为什么选这个 .rept 数量（如 DIV 很慢所以 .rept 20）
   - 标记 ⚠️ 的 test 必须解释链为什么断开（如 sd 不写回 t0、fld 写 ft0 不写 t0）
   - **必须标注 `insn_per_iter=N`**：即该 variant 每次 `.rept` 迭代中的指令条数，该值必须与 `perf_print` 调用中传入的 `instr_per_iter` 参数一致。格式示例：`# 构造：... insn_per_iter=2`
5. **测试列表** — 表格列出所有 test variant，标注 ✅（完整链）/ ⚠️（链断开）/ -（无链测试），每行必须包含 `.rept` 数和 `insn_per_iter` 列
6. **解读** — 如何从数据判读微架构行为

## 设计决策与原理

### 为什么用 `.rept` 展开而不是循环

`.rept N` 将核心指令段展开 N 次，使外层循环控制指令（`addi t3`/`blt`/`j` = 3 条）的占比降到 3/(N×insn_per_iter)。内层循环的控制指令会占用 dispatch/issue 资源，干扰吞吐量测量。

### 为什么 throughput 测试用 4 个目标寄存器轮换

消除 WAW/RAW 依赖，让调度器充分并行发射。4 个寄存器对应典型 4-wide dispatch 宽度。

### 为什么 latency 测试用自链法

自链法（`add t0,t0,t1`）形成最紧 RAW 依赖链，cycles/iter 即单条指令真实延迟。跨域指令无法自链，用往返链测往返 latency 之和。

### 为什么 cache_size 测试用 pointer chase + XOR 混淆

硬件预取器会识别规律 stride 导致 latency 偏低。pointer chase 强制串行访问，XOR 混淆 + 跨页随机化破坏预取检测。

### 为什么 warmup 调用在正式测量前

消除首次执行的 iTLB/dTLB miss、I$/D$ cold miss、branch predictor 冷启动等一次性开销。

### 为什么 dependency 测试按 producer→consumer 分子目录

旧版平铺测试的 forwarding 矩阵不够清晰。按 `<producer>_<consumer>` 对拆分后，每个测试只关注一个 forwarding 路径，易于定位瓶颈。

### 为什么 store/ 测试分为 case_b / case_c

每种内存排序行为需要在不同条件下对比（如有/无 fence、不同地址依赖模式），通过两组数据差异隔离被测行为。

### 为什么需要 bare-metal 模式

spike+pk 模式下 pk（proxy kernel）的 glibc 初始化约 435K 指令，对于某些场景（如 checkpoint 快照、极简环境验证）overhead 过大。bare-metal 模式通过 `bare_start.S` 直接从 `_start` 进入 main，用 HTIF 做 I/O，无 libc 依赖，适合生成干净的 checkpoint。

### 为什么 `perf_print` 要求传入 `insn_per_iter`

用于计算 `total_insn = total_iters × insn_per_iter` 并与硬件 instret 对比验证展开正确性。传错会导致 cycles/iter 和 IPC 物理含义偏离。

## 已知限制

- 链断开的测试（⚠️ 标注）数据仅供定性参考，后续用回读法精确测量
- 单核 fence 测试只能测 fence 开销，严格排序验证需双线程
- FP 操作数需初始化为正常正数，避免慢路径
- 交替链（A→B→A）测的是往返 latency 之和，非单向 forwarding
- latency/throughput 测试源码原由 `gen_latency.py`/`gen_throughput.py` 生成，生成器已移除，现有代码直接维护
