# riscv-uarch-bench — RISC-V Microarchitecture Benchmark Suite

通过内联汇编微基准测试逆向验证 RISC-V 乱序核的动态调度行为。通过 `arch/` 下的 profile 文件适配不同微架构，同一套测试代码覆盖多种处理器。

## 目录结构

```
├── Makefile              # 顶层构建，自动发现 src/**/main.c
├── uarch -> scripts/uarch  # CLI 入口符号链接
├── env/                  # 环境配置（工具链路径、ISA、arch profile）
│   ├── default.env       # 默认配置（纯 KEY=VALUE，shell/make 通吃）
│   └── example.env       # 模板，注释说明每个变量
├── scripts/              # uarch CLI（二级 Subcommand Dispatch 架构）
│   ├── uarch             # 一级 dispatcher
│   ├── uarch-build             # 二级 dispatcher → uarch-build-*
│   ├── uarch-build-thirdparty  # 三方库构建 → install/
│   ├── uarch-build-uarch       # benchmark 构建 → bin/
│   ├── uarch-build-embench     # embench 构建 → bin/embench/
│   ├── uarch-setup       # 环境检查 + env 管理
│   ├── uarch-run         # 运行测试（config 模式或直出模式）
│   ├── uarch-init        # 生成 run config（从 env + install/ 推导路径）
│   ├── uarch-check       # 比对结果与 Excel 参考值（四舍五入取整对比）
│   ├── uarch-update      # 从 Excel 同步参考值到 data/reference.json
│   ├── uarch-pack        # 打包部署（支持 src/spike/cli 三种模式）
│   └── lib/              # 共享库
│       ├── common.sh     # 颜色、路径、输出工具、env 加载、install/ 路径常量
│       ├── config.sh     # JSON config 解析 + 变量模板替换
│       ├── discover.sh   # 测试发现与过滤
│       ├── execute.sh    # 测试执行调度
│       ├── collect.sh    # 结果收集与 CSV 生成
│       └── refcheck.py   # 参考值管理与结果比对（Python）
├── arch/                 # 微架构 profile
│   ├── default.h         # 默认 profile（64KB 4-way L1D）
│   ├── template.h        # 新 profile 模板
│   └── embench/          # Embench 板级支持（boardsupport.c/h）
├── doc/
│   ├── RVA23_Instruction_Classification.xlsx  # RVA23 指令分类表
│   ├── k3.pdf            # K3 微架构规格文档
│   └── embench/          # Embench 各测试的分析文档（19 篇）
├── data/
│   └── reference.json    # 从 Excel 提取的指令 latency/throughput 参考值
├── src/
│   ├── common/           # 公共库（perf_helpers, arch_params）
│   ├── dependency/       # 依赖延迟测试（8 子分类，35 个，手写）
│   ├── latency/          # 指令 latency 测试（17 分类，39 个）
│   ├── throughput/       # 指令 throughput 测试（21 分类，271 个）
│   ├── store/            # Store 调度与内存排序测试（3 子分类，6 个）
│   ├── pipeline_depth/   # 投机唤醒 replay 测试（1 个）
│   ├── cache/            # Cache 特性测试（cache_size, tlb_size）
│   └── workload/         # 算法 workload 测试（9 分类，38 个，汇编实现）
├── thirdparty/
│   ├── riscv-isa-sim/    # spike 模拟器（git submodule，master-johann 分支）
│   └── embench-iot/      # Embench IoT 基准测试（git submodule）
├── install/              # 三方库构建产物（.gitignore，uarch build thirdparty 生成）
│   ├── riscv-isa-sim/    # spike binary + libs
│   └── pk/               # proxy kernel
├── bin/                  # 编译产物（.gitignore）
│   ├── linux/            # 交叉编译真机版（INSN_BUDGET=200M）
│   ├── spike/            # spike+pk 版（INSN_BUDGET=100K）
│   ├── checkpoint/       # spike checkpoint 版（-DCHECKPOINT）
│   └── embench/          # embench 产物
└── checkpoints/          # spike checkpoint 产物（zstd 压缩）
```

## 快速开始

### 环境配置

```bash
# 1. 配置工具链路径（编辑 env/default.env）
cat env/default.env
# RISCV_TOOLCHAIN=/opt/riscv
# MARCH=rv64gcv_zba_zbb_zbs_zicbom_zicbop_zicntr_zifencei_zihintpause_zihintntl
# ARCH=default

# 2. 检查环境
./uarch setup

# 3. 构建三方库（spike + pk）
./uarch build thirdparty spike         # → install/riscv-isa-sim/
./uarch build thirdparty pk            # → install/pk/
```

### 真机

```bash
make                                                # 交叉编译（默认 ARCH=default，产物在 bin/linux/）
make ARCH=sunchip                                   # 指定 arch profile
./uarch run                                         # 运行所有测试（绑核 0，直出 stdout）
./uarch run -c 2                                    # 指定绑核
taskset -c 0 ./bin/linux/dependency/int_fwd/alu_mul # 运行单个测试
```

### spike 模拟验证（x86 宿主机）

```bash
make spike                                          # 编译（产物在 bin/spike/）
make spike-run                                      # 编译后运行全部测试
```

spike 环境搭建见 [spike 模拟环境](#spike-模拟环境) 章节。

### 使用 uarch CLI

`uarch` 是统一的 CLI 入口，支持二级子命令分发：

```bash
./uarch help                            # 查看所有子命令

# 三方库构建
./uarch build thirdparty spike         # 构建 spike → install/riscv-isa-sim/
./uarch build thirdparty pk            # 构建 pk → install/pk/
./uarch build thirdparty all           # 按依赖序全部构建

# benchmark 编译
./uarch build uarch spike              # spike+pk 编译 → bin/spike/
./uarch build uarch linux              # 交叉编译 → bin/linux/
./uarch build uarch checkpoint         # checkpoint 编译 + 批量生成
./uarch build uarch all                # 以上全部
./uarch build embench linux            # 编译 embench → bin/embench/linux/

# 生成运行配置
./uarch init spike run_spike.json       # spike 预设
./uarch init linux run_linux.json       # 真机预设
./uarch init checkpoint run_ckpt.json   # checkpoint 预设

# 使用配置运行（日志 + CSV 导出）
./uarch run run_spike.json

# 参考值管理
./uarch update                          # 从 Excel 同步参考值到 data/reference.json
./uarch check logs/spike/results.csv    # 比对 CSV 与参考值（四舍五入取整）

# 打包部署
./uarch pack                            # 源码打包
./uarch pack --mode spike               # 预编译产物打包
./uarch pack --mode cli                 # 仅打包 uarch CLI

# 环境管理
./uarch setup                           # 检查 env + toolchain + install/
./uarch setup --env mybox              # 切换到 env/mybox.env
```

配置文件格式（最小化通用 JSON，支持变量模板）：

```json
{
    "command":   "taskset -c 0 {elf}",
    "bindir":    "bin/linux",
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
| `command` | 执行命令模板，支持变量：`{elf}`（测试路径）、`{spike}`/`{pk}`/`{march}`（从 env+install 解析）、`{checkpoint}`（从 elf 路径推导） |
| `bindir` | 编译产物目录（如 `bin/linux`、`bin/spike`） |
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
ssh target 'tar xzf riscv_uarch_bench_<timestamp>.tar.gz && make'
```

部署后在目标机上编辑 `env/default.env` 配置本地工具链路径，然后 `make` 即可。

## Arch Profile 机制

`make ARCH=<name>` 选择 `arch/<name>.h`，将微架构参数注入所有测试。测试代码通过 `#include "arch_params.h"` 消费宏，无需硬编码。

新增 profile：`cp arch/template.h arch/<name>.h`，修改参数即可。

| 宏 | 说明 | 消费者 |
|----|------|--------|
| `ARCH_CACHELINE` | cacheline 字节数 | cache_size, load_use_l2 |
| `ARCH_L1D_SIZE` | L1D 大小 | pipeline_depth |
| `ARCH_L1D_WAYS` | L1D 组相联度 | pipeline_depth |
| `ARCH_L2_WORKING_SET` | L2 测试工作集 | load_use_l2 |
| `ARCH_L2_EVICT_BUF` | L1 驱逐 buffer | pipeline_depth |

## 测试总览（392 个）

### 依赖延迟（35 个）— `src/dependency/`

测量各类操作结果被不同 consumer 使用时的 forwarding latency。按依赖类型分为 8 个子分类：

| 子分类 | 数量 | 测量内容 |
|--------|------|----------|
| `int_fwd/` | 3 | 整数 forwarding 链（alu→mul, alu→div, mul→div） |
| `fp_fwd/` | 7 | 浮点 forwarding 链（fadd→fmul, fmul→fma, fdiv→fadd 等） |
| `load_use_l1/` | 6 | L1 命中的 load-use latency（ld→alu, ld→mul, fld→fadd 等） |
| `load_use_l2/` | 4 | L2 命中的 load-use latency（1MB 随机 pointer chase） |
| `store_fwd/` | 2 | Store-to-load forwarding（sd→ld, fsd→fld） |
| `cross_domain/` | 3 | 跨域 forwarding（fclass, fcvt, fmv 往返链） |
| `addr_dep/` | 2 | 地址依赖链（fld→fmv→addr, fsd→fld→fmv→addr） |
| `ILP/` | 8 | 指令级并行度（add_ilp1-4, load_ilp1-4） |

### 指令 Latency（39 个）— `src/latency/`

测量单条指令的执行延迟。通过自链法（输出回到输入）或往返链（跨域指令）构造。

| 分类 | 数量 | 测试指令 |
|------|------|----------|
| ALU | 1 | add |
| BMU | 1 | clz |
| MUL | 1 | mul |
| DIV | 1 | div |
| LOAD | 1 | ld |
| STORE | 2 | sd, fsd |
| AMO | 2 | amoadd.d, amoadd.w |
| FADD | 2 | fadd.d, fadd.s |
| FMUL | 2 | fmul.d, fmul.s |
| FMA | 2 | fmadd.d, fmadd.s |
| FDIV | 2 | fdiv.d, fdiv.s |
| FSQRT | 2 | fsqrt.d, fsqrt.s |
| FMISC | 8 | fmin, fround, fsgnj, fcvt.d.s/h 等 |
| FCLASS | 2 | fclass.d, fclass.s |
| FCMP | 2 | feq.d, feq.s |
| FCVT | 4 | fcvt.d.l, fcvt.l.d, fcvt.l.s, fcvt.s.l |
| FMV | 4 | fmv.d.x, fmv.w.x, fmv.x.d, fmv.x.w |

### 指令 Throughput（271 个）— `src/throughput/`

测量 FU 最大发射速率。通过 4 个目标寄存器轮换消除依赖。

| 分类 | 指令数 | Dispatch Target | 预期 Throughput |
|------|--------|-----------------|-----------------|
| ALU | 56 | INT Pipe 0/1/2/3 | 4/cycle |
| BMU | 40 | INT Pipe 0/1/2/3 | 1/cycle |
| MUL | 6 | INT Pipe 2 | 1/cycle |
| DIV | 8 | INT Pipe 0 | 1/17 cycle |
| BRU | 13 | INT Pipe 1 | 1/cycle |
| LOAD | 19 | MEM Pipe 0/1 | 2/cycle |
| STORE | 15 | MEM Pipe 0 | 1/cycle |
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

### Store 调度与内存排序（6 个）— `src/store/`

| 测试 | 数量 | 测量内容 |
|------|------|----------|
| `load_bypass/` | 2 | Load 是否越过地址未知的 store（case_b/case_c） |
| `load_load/` | 2 | Load-Load 排序行为 |
| `store_buffer/` | 2 | Store buffer 行为 |

### Pipeline Depth（1 个）— `src/pipeline_depth/`

利用 L1 set conflict 制造 surprise miss，观测 speculative wakeup replay penalty。对比 scheduler 是否有 miss predictor。

### Cache 特性（2 个）— `src/cache/`

| 测试 | 测量内容 | 关键构造 |
|------|----------|----------|
| `cache_size/` | L1/L2 容量与延迟 | 多链交织 + XOR 混淆指针 + 跨页随机化，抗预取 |
| `tlb_size/` | TLB 容量与行为 | TBD |

### 算法 Workload（38 个）— `src/workload/`

真实算法的 RISC-V 汇编实现，用于测量整体 IPC 表现。

| 分类 | 数量 | 包含测试 |
|------|------|----------|
| `math/` | 9 | dot_product, fib_iterative, fib_recursive, gcd, is_prime, mat_multi, power_fast, power_naive, sqrt_newton |
| `bit/` | 5 | bitcount, bitcount_fast, bit_reverse, find_msb, msb_binary |
| `string/` | 5 | str_cmp, str_cpy, str_len, str_match, str_reverse |
| `tree/` | 4 | tree_heap, tree_iterative, tree_recursive, tree_search |
| `algo/` | 3 | edit_distance, knapsack, lcs |
| `container/` | 3 | arr_sum, queue, stack |
| `graph/` | 3 | bfs, dfs, dijkstra |
| `search/` | 3 | binary_search, hash_search, linear_search |
| `other/` | 3 | crc32, huffman, quick_select |

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
| 交叉编译 | `make` | 产物在 `bin/linux/`，工具链从 `env/default.env` 读取 |
| spike 编译 | `make spike` | 带 `-DUSE_SPIKE`，产物在 `bin/spike/` |
| spike 运行 | `make spike-run` | 编译后逐个在 spike 上运行 |
| checkpoint 编译 | `make checkpoint` | 带 `-DCHECKPOINT`，产物在 `bin/checkpoint/` |
| 列出测试 | `make list` | 显示所有已发现的测试（当前 392 个） |
| 全部清理 | `make distclean` | 删除 `bin/` 下所有子目录 |

工具链和 ISA 字符串统一从 `env/default.env` 读取，不再需要命令行传入路径。spike/pk 路径从 `install/` 自动推导。

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

**运行时自动检测**：

所有构建版本包含相同的测量代码。`perf_init()` 尝试 `perf_event_open()`，成功��使用 Linux 硬件计数器，失败（如 spike+pk 不支持该 syscall）则自动降级到 `rdcycle`/`rdinstret` CSR。如果 Linux 上 `perf_event_open` 因权限不足失败，可执行 `echo -1 | sudo tee /proc/sys/kernel/perf_event_paranoid` 解锁。

`-DUSE_SPIKE` 仅控制 `INSN_BUDGET`（100K vs 200M）和 `CALC_NLOOP` floor 值，不影响测量路径选择。

## 参考值比对

从 Excel 提取的指令 latency/throughput 参考值存储在 `data/reference.json`，用于自动化结果校验：

```bash
./uarch update                          # 从 Excel 同步到 reference.json
./uarch check logs/spike/results.csv    # 比对 CSV，四舍五入取整后对比
```

## 代码规范

### .S 汇编文件

- 典型函数签名：`void test_xxx(uint64_t nloop [, uint64_t *buf])`，`a0` = nloop，`a1` = 可选内存指针
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

还需要配置 `env/default.env` 中的 `RISCV_TOOLCHAIN` 指向已安装的 RISC-V 工具链。

**通过 uarch CLI 构建**（推荐）：

```bash
./uarch build thirdparty spike         # configure + make → install/riscv-isa-sim/
./uarch build thirdparty pk            # configure + make → install/pk/
```

> **注意**：新版 spike 与 pk 的异常委派断言不兼容。构建 pk 前需编辑 `thirdparty/riscv-pk/machine/minit.c`，注释掉 `delegate_traps()` 中的两行 `assert`（分别检查 `mideleg` 和 `medeleg`），然后再构建。

### 运行方式

```bash
make spike                              # 编译
make spike-run                          # 运行全部

# 或手动运行单个测试
install/riscv-isa-sim/bin/spike --isa=$(grep MARCH env/default.env | cut -d= -f2) \
  install/pk/pk ./bin/spike/dependency/int_fwd/alu_mul
```

ISA 字符串中的 `_zicntr` 扩展启用用户态 `rdcycle`/`rdinstret` 访问，缺少会触发非法指令异常。

### 技术细节

- pk 启动开销约 435K 指令（含 glibc `_start` 初始化），但在 `perf_start()`/`perf_stop()` 测量窗口之外，对 cycles/iter 和 insn/iter 零影响
- `NLOOP=10000` 时外层循环开销约 3%（`beqz`/`addi`/`j` 各 3 条 / `.rept 100` 次），与 NLOOP 大小无关
- spike 上 `cycles == instret`（IPC=1），所有 IPC 读数均为 1.0000
- spike 版本的 `perf_event_open()` 会失败（pk 不支持），自动降级到 rdcycle/rdinstret CSR，无需额外配置

## 已知限制

- ⚠️ 标注的测试链断开，数据仅供定性参考，后续用回读法精确测量
- 单核 fence 测试只能测 fence 开销，严格排序验证需双线程
- FP 操作数需初始化为正常正数，避免慢路径
- 交替链（A→B→A）测的是往返 latency 之和，非单向 forwarding
- spike 环境下 IPC 恒为 1，cache/branch/memory ordering 行为不存在，仅验证功能正确性
- latency/throughput 测试源码原由 `gen_latency.py`/`gen_throughput.py` 生成，生成器已移除，现有代码直接维护
