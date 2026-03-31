# riscv-uarch-bench — RISC-V Microarchitecture Benchmark Suite

通过内联汇编微基准测试逆向验证 RISC-V 乱序核的动态调度行为。通过 `arch/` 下的 profile 文件适配不同微架构，同一套测试代码覆盖多种处理器。

## 目录结构

```
├── Makefile              # 顶层构建，自动发现 src/**/main.c
├── uarch -> scripts/uarch  # CLI 入口
├── scripts/              # uarch CLI（Subcommand Dispatch 架构）
│   ├── uarch             # 主入口 dispatcher
│   ├── uarch-run         # 运行测试
│   ├── uarch-init        # 生成 config
│   ├── uarch-pack        # 打包部署
│   └── lib/              # 共享库（config 解析、测试发现、执行、结果收集）
├── gen_throughput.py     # Throughput 测试生成器（从 Excel 生成）
├── arch/                 # 微架构 profile
│   ├── default.h         # 默认 profile（64KB 4-way L1D）
│   └── template.h        # 新 profile 模板
├── doc/
│   └── RVA23_Instruction_Classification.xlsx  # RVA23 指令分类表
├── src/
│   ├── common/           # 公共库（perf_helpers, arch_params）
│   ├── dependency/       # 依赖延迟测试（12 个）
│   ├── throughput/       # 指令吞吐量测试（21 个分类，覆盖 ~270 条指令）
│   ├── store/            # Store 调度测试
│   ├── branch/           # Branch 行为测试
│   ├── mem_order/        # 内存排序测试
│   ├── bandwidth/        # 带宽吞吐测试
│   └── cache/            # Cache 特性测试
├── bin/                  # 编译产物 — 真机版
└── bin_spike/            # 编译产物 — spike 模拟版
```

## 快速开始

### 真机

```bash
make                                                # 本机编译（默认 ARCH=default）
make ARCH=sunchip                                   # 指定 arch profile
make CROSS_COMPILE=riscv64-unknown-linux-gnu-        # 交叉编译
./uarch run                                         # 运行所有测试（绑核 0，直出 stdout）
./uarch run -c 2                                    # 指定绑核
taskset -c 0 ./bin/dependency/alu_use               # 运行单个测试
```

### spike 模拟验证（x86 宿主机）

```bash
make spike                                          # 编译（产物在 bin_spike/）
make spike-run                                      # 编译后运行全部测试
```

spike 环境搭建见 [spike 模拟环境](#spike-模拟环境) 章节。

### 使用 uarch CLI 批量运行

`uarch` 是统一的 CLI 入口，支持子命令分发：

```bash
./uarch help                            # 查看所有子命令

# 生成默认配置文件
./uarch init spike run_spike.json       # spike 预设
./uarch init linux run_linux.json       # 真机预设
./uarch init custom run_qemu.json       # 自定义命令预设

# 使用配置运行（日志 + CSV 导出）
./uarch run run_spike.json

# 打包部署
./uarch pack
```

配置文件格式（最小化通用 JSON，无模式特定字段）：

```json
{
    "command":   "taskset -c 0 {elf}",
    "bindir":    "bin",
    "jobs":      1,
    "timeout":   1,
    "include":   ["throughput/ALU", "dependency"],
    "exclude":   ["cbo_zero"],
    "logdir":    "logs/k3",
    "output":    "logs/k3_summary.txt"
}
```

| 字段 | 说明 |
|------|------|
| `command` | 执行命令模板，`{elf}` 替换为测试二进制路径 |
| `bindir` | 编译产物目录 |
| `jobs` | 并行数，1=串行（真机推荐），N>1=并行（spike/custom） |
| `timeout` | 每测试超时（分钟） |
| `include` | 只跑指定目录（相对于 bindir），空=全部 |
| `exclude` | 跳过匹配的测试 |
| `logdir` | 日志目录，每个测试一个 `.log` 文件 |
| `output` | summary 输出文件路径 |

运行结果：

- **`<logdir>/summary.txt`** — 人读：每行 `test_path :: [variant] cycles/iter ...`
- **`<logdir>/results.csv`** — 机读：`test,variant,cycles_per_iter,insn_per_iter,ipc,...`
- **`<logdir>/<test>.log`** — 每个测试的完整输出

### 部署到目标机器

```bash
./uarch pack               # 生成 riscv_uarch_bench_YYYYMMDD_HHMMSS.tar.gz
# 部署：
scp riscv_uarch_bench_<timestamp>.tar.gz target:
ssh target 'tar xzf riscv_uarch_bench_<timestamp>.tar.gz && make ARCH=<profile>'
```

## Arch Profile 机制

`make ARCH=<name>` 选择 `arch/<name>.h`，将微架构参数注入所有测试。测试代码通过 `#include "arch_params.h"` 消费宏，无需硬编码。

新增 profile：`cp arch/template.h arch/<name>.h`，修改参数即可。

| 宏 | 说明 | 消费者 |
|----|------|--------|
| `ARCH_CACHELINE` | cacheline 字节数 | cache_size, load_use_l2, branch_order |
| `ARCH_L1D_SIZE` | L1D 大小 | pipeline_depth |
| `ARCH_L1D_WAYS` | L1D 组相联度 | pipeline_depth |
| `ARCH_L2_WORKING_SET` | L2 测试工作集 | load_use_l2, branch_order |
| `ARCH_L2_EVICT_BUF` | L1 驱逐 buffer | iq_pressure |

## 测试总览

### 依赖延迟（12 个）— `src/dependency/`

测量各类操作结果被不同 consumer 使用时的 forwarding latency。

| 测试 | 测量内容 | .rept | 关键构造 |
|------|----------|-------|----------|
| `alu_use` | ALU→ALU/MUL/DIV/LD/BR/ST/FLD/FSD | 100/20 | `t0` 自环链，`t1`=0 保值 |
| `mul_use` | MUL→ALU/MUL/DIV/LD/ST/FLD/FSD | 100/20 | `t0` 交替链 |
| `div_use` | DIV→ALU/MUL/DIV/LD/ST | 20 | DIV 很慢，`.rept 20` |
| `load_use_l1` | L1 LD→ALU/MUL/LD/ST（INT+FP） | 100 | 自环指针，L1 常驻 |
| `load_use_l2` | L2 LD→ALU/LD | 100 | 1MB 随机 pointer chase |
| `fadd_use` | FADD→FADD/FMUL/FMA/FSD | 100 | `ft0` FP 链 |
| `fmul_use` | FMUL→FMUL/FADD/FMA/FSD + 单精度 | 100 | `ft0` FP 链 |
| `fma_use` | FMA→FMA/FADD/FMUL/FSD | 100 | `ft0` FP 链 |
| `fdiv_use` | FDIV→FDIV/FADD/FMUL/FSD + 单精度 | 20 | FDIV 很慢 |
| `fsqrt_use` | FSQRT→FSQRT/FADD/FMUL + 单精度 | 20 | FSQRT 很慢 |
| `fp_misc` | FCVT/FMV/FMIN/FMAX/FCLASS/FSGNJ | 100 | 各种 FP misc 操作 |
| `pipeline_depth` | 投机唤醒重放惩罚（L1 set conflict） | 25 | 5 地址同 set，evict 制造 surprise miss |

### Store 调度（2 个）— `src/store/`

| 测试 | 测量内容 | 关键构造 |
|------|----------|----------|
| `store_split` | store data/addr 分离调度 | matmul 风格 C[j]+=A[k]*B[j]，Variant A addr 早 ready，Variant B addr 依赖 data |
| `st_ld_forward` | store→load forwarding 延迟 | 同地址 SD→LD 转发 vs 不同地址对照 |

### Branch 行为（2 个）— `src/branch/`

| 测试 | 测量内容 | 关键构造 |
|------|----------|----------|
| `branch_order` | branch resolve 是否乱序 | L2 pointer chase (~17cy) 作慢源，K=0..20 扫描 slow/fast 对 |
| `branch_redirect` | jalr 误预测 redirect 延迟 | 4KB PRNG jalr sled（1024 目标）vs 固定目标 baseline |

### 内存排序（5 个）— `src/mem_order/`

| 测试 | 测量内容 | 关键构造 |
|------|----------|----------|
| `ll_order` | Load-Load 顺序 | LD; fence r,r; LD vs 无 fence |
| `ls_order` | Load-Store 顺序 | LD; fence r,w; SD vs 无 fence |
| `sl_order` | Store-Load 顺序 | SD; fence w,r; LD vs 无 fence |
| `ss_order` | Store-Store 顺序 | SD; fence w,w; SD vs 无 fence |
| `mem_disambig` | 投机 load 与 store 地址消歧 | 不确定 store 地址下的 load 行为 |

### 带宽吞吐（5 个）— `src/bandwidth/`

| 测试 | 测量内容 | 关键构造 |
|------|----------|----------|
| `dispatch_width` | Dispatch 宽度 | 1/2/3/4/5 条独立 ALU 指令，观测 IPC |
| `fu_throughput` | 各 FU 持续吞吐量 | 全部功能单元独立指令流 |
| `iq_pressure` | Issue Queue 深度 | L2 LD 后 N=4..24 条依赖 ADD，观测 stall 拐点 |
| `rob_capacity` | ROB 有效容量 | 慢 DIV 间填充 N=32..80 条独立 ADD，观测 stall 拐点 |
| `cache_bandwidth` | 各级缓存带宽 | 4KB→8MB 工作集，stride-64B 连续 LD |

### Cache 特性（1 个）— `src/cache/`

| 测试 | 测量内容 | 关键构造 |
|------|----------|----------|
| `cache_size` | L1/L2 容量与延迟 | 多链交织 + XOR 混淆指针 + 跨页随机化，抗预取 |

### 指令吞吐量（21 个分类）— `src/throughput/`

每个分类一个 binary，内含该分类所有指令的 throughput 测试。通过 4 个目标寄存器轮换消除依赖，测量 FU 最大发射速率。

由 `gen_throughput.py` 从 `doc/RVA23_Instruction_Classification.xlsx` 自动生成。

| 分类 | 指令数 | Dispatch Target | 预期 Throughput |
|------|--------|-----------------|-----------------|
| ALU | 56 | INT Pipe 0/1/2/3 | 4/cycle |
| BMU | 40 | INT Pipe 0/1/2/3 | 1/cycle |
| MUL | 6 | INT Pipe 2 | 1/cycle |
| DIV | 8 | INT Pipe 0 | 1/17 cycle |
| BRU | 13 | INT Pipe 1 | 1/cycle |
| LOAD | 19 | MEM Pipe 0/1 | 2/cycle |
| STORE | 16 | MEM Pipe 0 | 1/cycle |
| FADD | 4 | FP Pipe 0/1 | 2/cycle |
| FMUL | 2 | FP Pipe 0/1 | 2/cycle |
| FMA | 8 | FP Pipe 0/1 | 2/cycle |
| FDIV | 2 | FP Pipe 0 | 1/20~23 cycle |
| FSQRT | 2 | FP Pipe 0 | TBD |
| FMISC | 31 | FP Pipe 0 | 1/cycle |
| FCMP | 12 | FP Pipe 1 | 1/cycle |
| FCVT_F2I | 9 | FP Pipe 1 | 1/cycle |
| FCVT_I2F | 8 | INT Pipe 3 | 1/cycle |
| FMV_F2I | 3 | FP Pipe 1 | 1/cycle |
| FMV_I2F | 3 | INT Pipe 3 | 1/cycle |
| FCLASS | 2 | FP Pipe 1 | 1/cycle |
| AMO | 22 | MEM Pipe (serialize) | serialize |
| CSR | 6 | — | serialize |

## 构建系统

Makefile 自动发现所有 `src/**/main.c`，每个测试编译为独立二进制：

```makefile
# 模式规则（简化）：bin/X/Y 由 src/X/Y/main.c + src/X/Y/*.S + common/ 构建
$(BINDIR)/%: $(SRCDIR)/%/main.c $(COMMON)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ $< $(wildcard $(dir $<)*.S) $(COMMON) $(LDFLAGS)
```

| 目标 | 命令 | 说明 |
|------|------|------|
| 本机编译 | `make` | 在目标机上直接编译 |
| 交叉编译 | `make CROSS_COMPILE=riscv64-unknown-linux-gnu-` | x86 上交叉编译 |
| spike 编译 | `make spike` | 带 `-DUSE_SPIKE`，产物在 `bin_spike/` |
| spike 运行 | `make spike-run` | 编译后逐个在 spike 上运行 |
| 列出测试 | `make list` | 显示所有已发现的测试 |
| 清理真机产物 | `make clean` | 删除 `bin/` |
| 清理 spike 产物 | `make clean-spike` | 删除 `bin_spike/` |
| 全部清理 | `make distclean` | 删除 `bin/` + `bin_spike/` |

spike 相关路径可通过变量覆盖（编译和运行均生效）：

```bash
make spike     SPIKE_CC=/path/to/riscv64-gcc
make spike-run SPIKE_BIN=/path/to/spike SPIKE_PK=/path/to/pk
```

## 性能测量基础设施

`src/common/perf_helpers.c` 提供统一的计数器接口：

```
perf_init()  → 初始化（Linux perf_event 或 CSR fallback）
perf_start() → 重置并启动计数器
perf_stop()  → 停止计数器，读取 cycles 和 instret
perf_print() → 输出人读行 + ##PERF## 机读标志行
perf_close() → 关闭文件描述符
```

`perf_print()` 每次调用输出两行：

```
  [ADD tput                      ]  cycles/iter:    0.25  insn/iter:  1.00  IPC: 4.0000  (...)   ← 人读
##PERF##|ADD tput|0.2500|1.0000|4.000000|25000|100000|100000|1##                                 ← 机读
```

`##PERF##` 标志行格式：`##PERF##|name|cyc/iter|insn/iter|ipc|cycles|instret|total_iters|instr_per_iter##`，供 `uarch run` 的日志收集模块抓取并生成 CSV。

**双模式支持**：

- **Linux 真机**（默认）：优先使用 Linux `perf_event_open` 硬件计数器，失败则 fallback 到 `rdcycle`/`rdinstret` CSR。如果 `perf_event_open` 因权限不足失败，可执行 `echo -1 | sudo tee /proc/sys/kernel/perf_event_paranoid` 解锁，或接受 CSR fallback
- **spike 模式**（`-DUSE_SPIKE`）：编译时条件编译跳过所有 Linux perf 代码，直接使用 `rdcycle`/`rdinstret` CSR。原有真机路径不受影响

## 代码规范

### .S 汇编文件

- 典型函数签名：`void test_xxx(uint64_t nloop [, uint64_t *buf])`，`a0` = nloop，`a1` = 可选内存指针
- 部分测试有更多参数（如 `store_split` 有 5 个参数 `a0`-`a4`，`mem_order` 系列有 3 个参数），具体见各测试 README
- `t3` 做外层循环计数器，`.rept N` 展开核心段，总迭代 = nloop × N
- 链式依赖通过 `t0`（INT）或 `ft0`（FP）维持
- 链断开的测试用 ⚠️ 标注，数据仅供定性参考
- 内存地址由 main.c 分配并通过参数传入，.S 不自行构造地址

### main.c 驱动文件

```c
perf_ctx_t ctx = perf_init();
// 分配 buffer、初始化 FP 寄存器...
fn(1000, buf);                           // warmup
perf_start(&ctx);
fn(NLOOP, buf);                          // 正式测量
perf_stop(&ctx, &cycles, &instret);
perf_print(name, cycles, instret, NLOOP * rept, instr_per_iter);
perf_close(&ctx);
```

### 新增测试

1. 在 `src/<类别>/` 下创建子目录
2. 放入 `main.c`（**必需**，Makefile 依赖此文件发现测试）
3. 放入 `<name>.S`（推荐，汇编核心代码；纯 C 测试如 `cache_size` 可省略）
4. 放入 `README.md`（推荐，说明测试目的和构造）
5. `make` 会自动发现并编译

每个测试的 README.md 应包含：标题与目标、文档事实、待验证问题、Critical Section（实际汇编代码）、测试列表表格（✅/⚠️）、解读方法。

## spike 模拟环境

spike（RISC-V 官方 ISA 功能模拟器）+ pk（proxy kernel）提供无需真机的验证环境。spike 不是时序模拟器（IPC 恒为 1），因此只能验证功能正确性，不能获取有意义的 cycle 数据。

### 验证能力

| 能验证 | 不能验证 |
|--------|----------|
| 程序编译通过、运行不崩溃 | 真实 cycle latency |
| 指令展开数量正确（insn/iter） | forwarding/bypass 行为 |
| 依赖链结构完整 | cache/分支预测/内存排序行为 |

### 从源码构建 spike + pk

**前置依赖**（Ubuntu/Debian）：

```bash
sudo apt-get install device-tree-compiler libboost-regex-dev libboost-system-dev
```

还需要一个 RISC-V Linux 交叉编译器（`riscv64-unknown-linux-gnu-gcc`）。Makefile 默认使用 `/opt/riscv-toolchain-bin-rv64gc-linux/bin/` 下的版本，如果路径不同请通过 `SPIKE_CC=` 变量覆盖。

**构建 spike**：

```bash
cd ~/workspace
git clone https://github.com/riscv-software-src/riscv-isa-sim.git
cd riscv-isa-sim
mkdir build && cd build
../configure --prefix=$HOME/workspace/riscv-spike
make -j$(nproc)
make install
```

**构建 pk**（proxy kernel，无需 install，直接使用 `build/pk`）：

```bash
cd ~/workspace
git clone https://github.com/riscv-software-src/riscv-pk.git
cd riscv-pk
git checkout 3bd964f    # 兼容新 spike 的版本
mkdir build && cd build
../configure --prefix=$HOME/workspace/riscv-spike \
  --host=riscv64-unknown-linux-gnu \
  CC=/opt/riscv-toolchain-bin-rv64gc-linux/bin/riscv64-unknown-linux-gnu-gcc  # 按本机实际路径调整
make -j$(nproc)
```

> **注意**：新版 spike 与 pk 的异常委派断言不兼容。构建 pk 前需编辑 `machine/minit.c`，注释掉 `delegate_traps()` 中的两行 `assert`（分别检查 `mideleg` 和 `medeleg`），然后再 `make`。

### 运行方式

```bash
make spike                              # 编译
make spike-run                          # 运行全部

# 或手动运行单个测试（必须指定 _zicntr 扩展）
~/workspace/riscv-spike/bin/spike --isa=rv64gc_zicntr \
  ~/workspace/riscv-pk/build/pk ./bin_spike/dependency/alu_use
```

`--isa=rv64gc_zicntr` 中的 `_zicntr` 扩展启用用户态 `rdcycle`/`rdinstret` 访问，缺少会触发非法指令异常。

### 技术细节

- pk 启动开销约 435K 指令（含 glibc `_start` 初始化），但在 `perf_start()`/`perf_stop()` 测量窗口之外，对 cycles/iter 和 insn/iter 零影响
- `NLOOP=10000` 时外层循环开销约 3%（`beqz`/`addi`/`j` 各 3 条 / `.rept 100` 次），与 NLOOP 大小无关
- spike 上 `cycles == instret`（IPC=1），所有 IPC 读数均为 1.0000

## 已知限制

- ⚠️ 标注的测试链断开，数据仅供定性参考，后续用回读法精确测量
- 单核 fence 测试只能测 fence 开销，严格排序验证需双线程
- FP 操作数需初始化为正常正数，避免慢路径
- 交替链（A→B→A）测的是往返 latency 之和，非单向 forwarding
- spike 环境下 IPC 恒为 1，cache/branch/memory ordering 行为不存在，仅验证功能正确性
