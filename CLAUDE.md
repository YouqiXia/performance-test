# riscv-uarch-bench — RISC-V Microarchitecture Benchmark Suite

## 项目概述

通过内联汇编微基准测试逆向验证 RISC-V 乱序核的动态调度行为。通过 `arch/` 下的 profile 文件适配不同微架构。

## 目录结构

```
├── Makefile              # 顶层构建，自动发现 src/**/main.c
├── uarch -> scripts/uarch  # CLI 入口符号链接
├── scripts/              # uarch CLI（Subcommand Dispatch 架构）
│   ├── uarch             # 主入口 dispatcher
│   ├── uarch-run         # 子命令：运行测试（config 模式或直出模式）
│   ├── uarch-init        # 子命令：生成默认 config
│   ├── uarch-pack        # 子命令：打包部署（支持 src/spike/cli 三种模式）
│   ├── uarch-check       # 子命令：比对结果与 Excel 参考值（四舍五入取整对比）
│   ├── uarch-update      # 子命令：从 Excel 同步参考值到 data/reference.json
│   └── lib/              # 共享库
│       ├── common.sh     # 颜色、路径、输出工具
│       ├── config.sh     # JSON config 解析
│       ├── discover.sh   # 测试发现与过滤
│       ├── execute.sh    # 测试执行调度
│       ├── collect.sh    # 结果收集与 CSV 生成
│       └── refcheck.py   # 参考值管理与结果比对（Python）
├── data/                 # 生成的参考数据
│   └── reference.json    # 从 Excel 提取的指令 latency/throughput 参考值
├── arch/                 # 微架构 profile（cache 几何、working set 等）
│   ├── default.h         # 默认 profile
│   └── template.h        # 新 profile 模板
├── gen_latency.py        # 生成 src/latency/ 的脚本
├── gen_throughput.py     # 生成 src/throughput/ 的脚本（读 Excel）
├── doc/RVA23_Instruction_Classification.xlsx  # 指令分类数据源
├── src/
│   ├── common/           # 公共库（perf_helpers, arch_params）
│   ├── dependency/       # 依赖延迟测试（手写，forwarding 矩阵）
│   ├── store/            # Store 调度测试
│   ├── branch/           # Branch 行为测试
│   ├── mem_order/        # 内存排序测试
│   ├── bandwidth/        # 带宽吞吐测试
│   ├── cache/            # Cache 特性测试
│   ├── latency/          # 指令 latency 测试（按 dispatch type 分组，gen_latency.py 生成）
│   └── throughput/       # 指令 throughput 测试（按 dispatch type 分组，gen_throughput.py 生成）
├── thirdparty/
│   ├── riscv-isa-sim/    # spike 模拟器（git submodule，含 install/）
│   └── embench-iot/      # Embench 基准测试（git submodule）
├── checkpoints/          # spike checkpoint 产物（-m64 + zstd 压缩）
├── bin/                  # 编译产物（镜像 src/ 层级）
├── bin_spike/            # spike 编译产物
└── bin_spike_ckpt/       # spike checkpoint 编译产物（-DCHECKPOINT）
```

## 构建与运行

```bash
# 本机编译（使用默认 arch profile）
make

# 指定 arch profile
make ARCH=sunchip

# 交叉编译
make CROSS_COMPILE=riscv64-unknown-linux-gnu-

# spike 模拟验证
make spike
make spike-run

# spike checkpoint（-m64 缩小内存占用，zstd 压缩）
make spike-checkpoint
./scripts/checkpoint_all.sh        # 批量生成，8 路并行，增量跳过已有

# 运行所有测试（绑核 0，直出 stdout）
./uarch run

# 使用 config 运行（日志 + CSV 导出）
./uarch init spike run_spike.json
./uarch run run_spike.json

# 运行单个测试
taskset -c 0 ./bin/dependency/alu_use

# 比对结果与 Excel 参考值（四舍五入取整后对比）
./uarch check logs/spike/results.csv

# 从 Excel 同步参考值（Excel 更新后执行）
./uarch update

# 打包部署（三种模式）
./uarch pack                  # 默认：源码打包
./uarch pack --mode spike     # 预编译产物打包
./uarch pack --mode cli       # 仅打包 uarch 命令相关
```

## Arch Profile 机制

通过 `make ARCH=<name>` 选择 `arch/<name>.h`，将微架构相关参数（L1D 大小、组相联度、working set 等）注入到所有测试中。test 代码通过 `#include "arch_params.h"` 获取这些宏，无需硬编码。

```bash
make ARCH=default       # 使用 arch/default.h（默认）
make ARCH=sunchip       # 使用 arch/sunchip.h
```

新增 profile：`cp arch/template.h arch/<name>.h`，修改参数，然后 `make ARCH=<name>`。

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

**重新生成**：
```bash
rm -rf src/latency/ && python3 gen_latency.py
rm -rf src/throughput/ && python3 gen_throughput.py
```

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
- warmup 调用后再正式测量
- **`perf_print` 必须传入正确的 `insn_per_iter`**：每个 variant 调用 `perf_print` 时，`insn_per_iter` 参数必须等于该 variant `.rept` 内层中每次迭代的指令条数（即 Critical Section 中的实际汇编指令数）。这是计算总指令数和验证 IPC 的关键参数。

### 新增测试

1. 在 `src/<类别>/<name>/` 创建 `main.c` + `<name>.S` + `README.md`（RISC-V）
2. `make spike` 编译 spike 版本，`make spike-run` 在模拟器上验证功能正确性
3. 确认构造正确后，`make CROSS_COMPILE=riscv64-unknown-linux-gnu-` 交叉编译部署到目标机

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

## 已知限制

- 链断开的测试（⚠️ 标注）数据仅供定性参考，后续用回读法精确测量
- 单核 fence 测试只能测 fence 开销，严格排序验证需双线程
- FP 操作数需初始化为正常正数，避免慢路径
- 交替链（A→B→A）测的是往返 latency 之和，非单向 forwarding
