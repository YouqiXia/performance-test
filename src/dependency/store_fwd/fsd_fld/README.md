# FSD↔FLD FP Store Forwarding

FP store forwarding latency. 作为 fld_fadd/fmul/fma 的 baseline。

## 文档事实

- FSD latency 可从 `latency/STORE/fsd` 获取
- FLD latency (L1) 可从 `latency/LOAD/fld` 获取

## 待验证

- FP fsd→fld store forwarding 的往返延迟
- FP store forwarding 与 INT store forwarding (sd_ld) 是否有差异

## Critical Section

```asm
# 构造：fsd/fld 交替链，ft0 为链寄存器，a1 为固定内存地址
# fsd 写 ft0 到 [a1]，fld 从 [a1] 读回 ft0（store forwarding）
# insn_per_iter=2
fsd  ft0, 0(a1)
fld  ft0, 0(a1)
```

## 测试列表

| Test | 路径 | 链 | .rept | insn_per_iter | 说明 |
|------|------|-----|-------|---------------|------|
| FSD↔FLD | fsd_fld | ✅ | 100 | 2 | fsd→fld store forwarding 回环 |

## 解读

- `cycles/iter` = fsd→fld store forwarding 往返延迟
- 对比 sd_ld 可判断 INT/FP store forwarding 路径是否共享
- 该值是 fld_fadd/fmul/fma 等 load-use 测试的 store forwarding baseline
