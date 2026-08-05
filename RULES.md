# performance-test 规则说明

这份文档是 `~/code/performance-test` 仓库的操作规则，目标是统一说明：

- 如何编译 `linux` / `spike` / `checkpoint`
- 如何生成 checkpoint
- 如何恢复 checkpoint
- 如何验证结果是否合理

## 1. 工作目录

下面所有命令默认都在仓库根目录执行：

```bash
cd ~/code/performance-test
```

## 2. 环境准备

开始任何编译或运行前，先执行：

```bash
source env/default.env
./uarch setup
```

规则：

- `env/default.env` 是 `RISCV_TOOLCHAIN`、`RISCV_ELF_TOOLCHAIN`、`MARCH`、`ARCH` 的唯一配置来源。
- 如果 `./uarch setup` 没通过，不要继续后续步骤；先把工具链、`spike`、`pk` 路径修好。

## 3. 第三方依赖

任何 `spike` 或 `checkpoint` 工作流开始前，都先编第三方依赖：

```bash
./uarch build thirdparty spike
./uarch build thirdparty pk
```

产物：

- `install/riscv-isa-sim/bin/spike`
- `install/pk/pk`

规则：

- `spike` 是运行 `bin/spike` 和 `bin/checkpoint` 的前提。
- `pk` 是执行 `spike pk <elf>` 的前提。

### 3.1 `uarch` 脚本用法

`./uarch` 是统一入口，内部再分发到 `scripts/uarch-*`。

常用命令：

```bash
./uarch setup
./uarch setup --env default
./uarch build thirdparty spike
./uarch build thirdparty pk
./uarch build thirdparty all
./uarch build uarch spike
./uarch build uarch checkpoint --jobs 4
./uarch init spike run_spike.json
./uarch init checkpoint run_ckpt.json
./uarch run run_spike.json
./uarch run -c 0
./uarch check logs/spike/results.csv
./uarch update
./uarch pack --mode spike
```

规则：

- `uarch setup` 用来检查 `env/`、工具链、`install/` 里的 `spike/pk`
- `uarch build thirdparty spike|pk|all` 只负责构建第三方依赖到 `install/`
- `uarch build uarch spike` 只编 `bin/spike/`
- `uarch build uarch checkpoint` 会先编 `bin/checkpoint/`，再生成 `checkpoints/`
- `uarch init spike` 生成 `"{spike} --isa={march} {pk} {elf}"` 形式的配置
- `uarch init checkpoint` 生成 `"{spike} --isa={march} --restore={checkpoint} {pk} {elf}"` 形式的配置
- `uarch run` 不带配置时默认跑 `bin/linux/`
- `uarch check` 比对 `results.csv` 和参考值
- `uarch update` 从 Excel 刷新 `data/reference.json`
- `uarch pack` 用于打包部署产物，`--mode spike` 会包含 `bin/spike/`

## 4. 编译规则

### 4.1 Linux 版本

编译所有 Linux 版本测试：

```bash
make
```

脚本方式：

```bash
./uarch build uarch linux --jobs <N>
```

输出目录：

```text
bin/linux/
```

### 4.2 Spike 版本

编译所有 spike 版本测试：

```bash
make spike
```

脚本方式：

```bash
./uarch build uarch spike --jobs <N>
```

输出目录：

```text
bin/spike/
```

规则：

- `linux` 和 `spike` 使用同一套源码。
- `spike` 版本额外带 `-DUSE_SPIKE`，所以 loop budget 和测量行为与 `linux` 不同。

### 4.3 Checkpoint 版本

编译所有 checkpoint 版本测试：

```bash
make checkpoint
```

脚本方式：

```bash
./uarch build uarch checkpoint --jobs <N>
```

输出目录：

```text
bin/checkpoint/
```

规则：

- `checkpoint` 同时带 `-DUSE_SPIKE` 和 `-DCHECKPOINT`
- `bin/checkpoint/...` 和 `bin/spike/...` 不是同一类 ELF

### 4.4 单个测试编译

编译单个 Linux 测试：

```bash
make bin/linux/latency/DIV/div
```

编译单个 spike 测试：

```bash
make BINDIR=bin/spike \
  CC="$RISCV_TOOLCHAIN/bin/riscv64-unknown-linux-gnu-gcc" \
  CFLAGS="-O2 -march=$MARCH -mabi=lp64d -static -I src/common -I . -DARCH_PROFILE_HEADER='\"arch/$ARCH.h\"' -DUSE_SPIKE" \
  bin/spike/latency/DIV/div
```

编译单个 checkpoint 测试：

```bash
make BINDIR=bin/checkpoint \
  CC="$RISCV_TOOLCHAIN/bin/riscv64-unknown-linux-gnu-gcc" \
  CFLAGS="-O2 -march=$MARCH -mabi=lp64d -static -I src/common -I . -DARCH_PROFILE_HEADER='\"arch/$ARCH.h\"' -DUSE_SPIKE -DCHECKPOINT" \
  bin/checkpoint/latency/DIV/div
```

## 5. 运行规则

### 5.1 Linux 版本

直接运行 Linux ELF：

```bash
taskset -c 0 ./bin/linux/latency/DIV/div
```

### 5.2 Spike 版本

直接运行 spike ELF：

```bash
LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH \
install/riscv-isa-sim/bin/spike --isa="$MARCH" \
  install/pk/pk bin/spike/latency/DIV/div
```

规则：

- 在 `spike+pk` 下，`perf_event_open()` 失败是预期行为。
- benchmark 会自动降级为 `rdcycle/rdinstret` 计数。
- spike 主要用于功能验证和指令数量 sanity check，不适合直接看真实微架构时序。

### 5.3 Checkpoint ELF 直跑验证

直接跑 checkpoint ELF，但不加 `--load` / `--save`：

```bash
install/riscv-isa-sim/bin/spike --isa="$MARCH" \
  install/pk/pk bin/checkpoint/latency/ALU/add
```

规则：

- 这条命令只验证 `bin/checkpoint/...` 能否正常启动和执行
- 不会生成新的 checkpoint
- `csrw 0x800, x0` 在这里不会触发保存，因为没有传 `--save`

## 6. Checkpoint 生成规则

### 6.1 批量生成

编 checkpoint 版 ELF，并批量生成 checkpoint：

```bash
./uarch build uarch checkpoint --jobs <N>
```

它会做两件事：

1. `make checkpoint`
2. 对 `bin/checkpoint/` 下每个可执行文件执行 `spike --save=...`

checkpoint 输出目录：

```text
checkpoints/
```

### 6.2 单个测试生成

为单个测试生成 checkpoint：

```bash
mkdir -p checkpoints/latency/DIV
LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH \
install/riscv-isa-sim/bin/spike --isa="$MARCH" -m64 \
  --save=checkpoints/latency/DIV/div \
  install/pk/pk bin/checkpoint/latency/DIV/div
```

生成结果通常包括：

- `div.bootram`
- `div.mainram` 或 `div.mainram.zst`
- `div.re_regs`
- `div.htif`

注意事项：

- 如果生成 checkpoint 时用了 `--compress-zstd` 但机器没装 `zstd`，会失败
- 对同一个前缀，如果同时存在 `.mainram`、`.mainram.zip`、`.mainram.zst` 多份，恢复会失败

规则：

- `--save` 后面给的是 checkpoint 前缀，不是目录。

## 7. Checkpoint 恢复规则

### 7.1 当前 spike 用 `--load`

本仓库当前这版 spike 应该使用：

```bash
--load=<checkpoint_prefix>
```

### 7.2 恢复单个 checkpoint

```bash
LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH \
install/riscv-isa-sim/bin/spike \
  --isa="$MARCH" \
  --load=checkpoints/latency/DIV/div \
  --instructions=1200000 \
  install/pk/pk bin/checkpoint/latency/DIV/div
```

规则：

- `--load` 传的是 checkpoint 前缀，不是 `*.bootram`
- 从 loader 机制看，`--load` 并不强制外层 ELF 和 checkpoint 文件名一一对应；没有 ELF 时会自动用 `none` 占位
- 恢复时用 `bin/checkpoint/...`，不要用 `bin/spike/...`
- spike 限制指令数用的是 `--instructions=<n>`

## 8. 验证规则

### 8.1 Benchmark 自己的输出

benchmark 会打印：

```text
cycles/iter
insn/iter
IPC
##PERF##
```

可用下面命令直接验证 benchmark 输出是否正常：

```bash
install/riscv-isa-sim/bin/spike --isa="$MARCH" \
  install/pk/pk bin/spike/latency/ALU/add
```

含义：

- `cycles/iter`：每个 benchmark 定义的工作单元平均用了多少周期
- `insn/iter`：每个 benchmark 定义的工作单元平均退休了多少条指令
- `IPC`：`instret / cycles`

规则：

- latency 测试优先看 `cycles/iter`
- throughput 测试通常优先看 `IPC`
- `instret` 比核心被测指令数略大是正常的，因为循环控制指令也会退休


### 8.2 查看执行 trace / commit log

standalone spike 同时开启执行 trace 和 commit log：

```bash
LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH \
install/riscv-isa-sim/bin/spike \
  -l \
  --log-commits \
  --isa="$MARCH" \
  install/pk/pk bin/spike/latency/DIV/div
```

规则：

- `-l` 和 `--log-commits` 是并列关系，可以单独用，也可以一起用
- `-l` 输出执行 trace（`PC + 机器码 + 反汇编`）
- `--log-commits` 输出提交日志（寄存器/访存写回）

## 9. Warmup 与 Checkpoint 的关系

当前 checkpoint ELF 的保存点在 `perf_init()` 里：

- `perf_init()` 里会执行 `csrw 0x800, x0`
- 恢复后从这里继续
- 后面的 warmup 仍然会跑

规则：

- 现在恢复 `DIV` checkpoint 后，warmup 仍然会执行
- 所以恢复后不是“只剩 10w 个 div”
- 如果想让保存点落在 warmup 之后，必须把 checkpoint 触发点移动到 warmup 后并重新生成 checkpoint

## 10. Model 集成规则

使用 `model` 时，ELF 不是被 `model` 当作 C 函数直接调用的。

路径大致是：

1. `model` 解析 ELF 路径和 `--spike-params`
2. `model` 创建内部 `NewSpikeInstGenerator`
3. 内部 `RawSpike` 负责加载 ELF / checkpoint
4. `model` 消费由内部 spike 吐出的指令流

规则：

- `model` 参数和 `spike` 参数是两层不同的命令行
- checkpoint / load / instruction limit 这类参数要放进 `--spike-params`

### 10.1 用 `uarch run` 跑 model

例如下面的 `run_model.json` 配置：

```json
{
  "command": "/work/home02/uatu/code/model/release/model --spike-params=\"-p1 --hartids=0 --isa=rv64gcv_zba_zbb_zbs_zfh_zfhmin_zfa_zicond_zcb_zicboz_zicbom_zicbop_zicntr_zicsr_zifencei_zimop_zkt_zvbb_zvfhmin_zvkt_zihintpause_zihintntl --priv=msu /workspace/perf_model/rhodes/model/model/thirdparty/riscv-pk-master/install/riscv64-unknown-linux-gnu/bin/pk\" {elf}",
  "bindir": "bin/spike",
  "jobs": 32,
  "timeout": 720,
  "include": ["latency", "throughput"],
  "exclude": [],
  "logdir": "logs/ALL",
  "output": "logs/ALL/summary.txt"
}
```

用法：

```bash
./uarch run run_model.json
```

规则：

- `bindir=bin/spike` 表示跑的是 `make spike` 生成的 ELF
- `{elf}` 会被 `uarch run` 逐个替换成 `./bin/spike/...`

### 10.2 用 model 跑切片

如果要在 `model` 里跑 `performance-test` 自己生成的 checkpoint 切片，命令结构应当是：

```bash
/work/home02/uatu/code/model/release/model \
  --spike-params="-p1 --hartids=0 --isa=rv64gcv_zba_zbb_zbs_zfh_zfhmin_zfa_zicond_zcb_zicboz_zicbom_zicbop_zicntr_zicsr_zifencei_zimop_zkt_zvbb_zvfhmin_zvkt_zihintpause_zihintntl --priv=msu --load=/work/home/uatu/code/performance-test/checkpoints/latency/DIV/div /workspace/perf_model/rhodes/model/model/thirdparty/riscv-pk-master/install/riscv64-unknown-linux-gnu/bin/pk" \
  /work/home/uatu/code/performance-test/bin/checkpoint/latency/DIV/div 
```

规则：

- `--load` 后面填的是 `performance-test` 生成的 checkpoint 前缀，比如：
  - `checkpoints/latency/DIV/div`
  - `checkpoints/latency/FDIV/fdiv_d`
- 不要带 `.bootram`
- `--spike-params` 放的是给内部 spike 的参数
- `model` 外层只负责解析和调度，不要把 `--log-commits` 放在外层
- 如果要换测试，只同时替换：
  - `--load=/work/home/uatu/code/performance-test/checkpoints/...`
  - 最后的 `/work/home/uatu/code/performance-test/bin/checkpoint/...`
- `cluster0-core0 [PASS]: ...` 会出现在对应测试的 `.log` 里

