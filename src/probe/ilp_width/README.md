# ilp_width — Issue Width Probe

扫描 K=1..8 条独立 `addi` 链，测量每个 K 的 IPC，通过 plateau 定位机器有效 integer-ALU issue 宽度。**PoC 用例**，用于验证 `probe/` harness 的端到端流程（JSON 输出 → `scripts/probe_report.py` → `reference/<arch>.yaml` 对比）。

## 文档事实

- `arch/default.h` 注释声明：4-wide dispatch OoO 核
- 预期 IPC 随 K 上升到机器整数发射宽度后饱和

## 待验证

- 机器整数 ALU 发射宽度 W（本测试直接给出 K→IPC 曲线的 plateau）
- IPC plateau 值是否达到 theoretical W（若低于 W，说明存在 dispatch/rename/其他前端瓶颈）

## Critical Section

每个 variant 的外层 iteration 的总 `addi` 数约 60–64 条（见 `ilp_width.S`），cycles/outer-iter 可跨 K 直接对比。

```asm
# 构造：K 条互相独立的自增链（无跨链依赖），.rept 次数为 floor(64/K)
# 目的：饱和到机器 integer issue 宽度为止 — 超过宽度后额外的链无法并行
# 寄存器选择：t0,t1,t2,t4,t5,t6 (6 caller-saved)，K≥7 时扩展到 s0/s1 (save/restore)
# t3 用作 outer loop counter
# 每次 .rept 迭代的 insn_per_iter = K
# 总 insn_per_outer ≈ 64 (constant across K)

# K=4 示例（.rept 16 × 4 addi = 64 insns）
.rept 16
addi  t0, t0, 1       # chain 0
addi  t1, t1, 1       # chain 1
addi  t2, t2, 1       # chain 2
addi  t4, t4, 1       # chain 3
.endr
```

所有链都是 `addi reg, reg, 1` 的自链形式，形成 1-cycle RAW 依赖，确保同一链内每周期最多发射 1 条。

## 测试列表

| K | .rept | insn_per_iter | 总 insn/outer | 状态 |
|---|------:|--------------:|--------------:|:----:|
| 1 |    64 |             1 |            64 |  ✅  |
| 2 |    32 |             2 |            64 |  ✅  |
| 3 |    21 |             3 |            63 |  ✅  |
| 4 |    16 |             4 |            64 |  ✅  |
| 5 |    12 |             5 |            60 |  ✅  |
| 6 |    10 |             6 |            60 |  ✅  |
| 7 |     9 |             7 |            63 |  ✅  |
| 8 |     8 |             8 |            64 |  ✅  |

`insn_per_iter` 在 main.c 的 `variants[]` 里是"总 insn/outer"，传给 `perf_print` 作 total-instret 校验。

## 解读

- **理想曲线**：IPC(K=1)≈1 → IPC(K=W)≈W → IPC(K>W)≈W（plateau）
- **plateau 左沿 = W**：`scripts/probe_report.py` 用 `detect_plateau` 返回"第一个 y ≥ 0.95×max(y) 的 K"
- **plateau 值 < W**：前端（fetch/decode/rename）存在瓶颈，ALU 发射宽度被掩盖
- **plateau 不清晰**：可能是端口绑定（部分 ALU 不对称），需要改用 mul/load 等不同 dispatch type 再测一次

## 运行

```bash
# Spike smoke test
make spike
install/riscv-isa-sim/bin/spike --isa=$MARCH install/pk/pk \
    ./bin/spike/probe/ilp_width > out/probe/default/ilp_width.log

# Linux perf measurement
make
./bin/linux/probe/ilp_width > out/probe/default/ilp_width.log

# Generate report
python3 scripts/probe_report.py \
    --logs out/probe/default/ilp_width.log \
    --reference reference/default.yaml \
    --output out/probe/default/report.md
```

## 局限

- PoC 级构造：只覆盖 integer ALU，没有区分 int/fp/mem 端口
- 未使用 nop 填充对照组：如果机器对 mov-elim / zero-idiom 敏感，结果可能偏移
- `addi reg, reg, 1` 的自链理论上对 late-ALU 优化敏感，但对 plateau 位置判定无影响
