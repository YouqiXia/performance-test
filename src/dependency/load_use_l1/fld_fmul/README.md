# FLD→FMUL→FSD (L1) Store-Forwarding Chain

测量 FLD→FMUL.D→FSD 的 store-forwarding 往返延迟。

## 文档事实

- FLD_lat(L1) 可从 `latency/LOAD/fld` 获取
- FMUL_lat 可从 `latency/FMUL/fmul_d` 获取
- Store forwarding latency 可从 `store_fwd/fsd_fld` baseline 获取

## 待验证

- FLD→FMUL→FSD 链的总延迟
- 对比 store_fwd/fsd_fld baseline 可得 FMUL 插入代价

## Critical Section

```asm
# 构造：fld→fmul.d→fsd 三指令链，通过 store forwarding 形成回环
# ft0 = chain register, ft1=1.0 (fmul identity)
# a1 = 固定 L1 地址，fsd 写回后 fld 通过 store forwarding 读取
# insn_per_iter=3
fld     ft0, 0(a1)
fmul.d  ft0, ft0, ft1
fsd     ft0, 0(a1)
```

## 测试列表

| Test | 路径 | 链 | .rept | insn_per_iter | 说明 |
|------|------|-----|-------|---------------|------|
| FLD→FMUL→FSD | fld_fmul | ✅ | 100 | 3 | fld→fmul.d→fsd 回环 |

## 解读

- `cycles/iter` = 往返延迟之和（FLD + FMUL + FSD + store-forwarding）
- 对比 `store_fwd/fsd_fld` baseline（纯 fsd→fld 链）可得 FMUL 插入代价
- FMUL_overhead = `cycles/iter` - fsd_fld_baseline
- 若 FMUL_overhead ≈ FMUL_lat：forwarding 无额外惩罚
