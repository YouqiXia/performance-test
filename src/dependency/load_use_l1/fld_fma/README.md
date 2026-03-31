# FLD→FMA→FSD (L1) Store-Forwarding Chain

测量 FLD→FMADD.D→FSD 的 store-forwarding 往返延迟。

## 文档事实

- FLD_lat(L1) 可从 `latency/LOAD/fld` 获取
- FMA_lat 可从 `latency/FMA/fmadd_d` 获取
- Store forwarding latency 可从 `store_fwd/fsd_fld` baseline 获取

## 待验证

- FLD→FMADD→FSD 链的总延迟
- 对比 store_fwd/fsd_fld baseline 可得 FMA 插入代价

## Critical Section

```asm
# 构造：fld→fmadd.d→fsd 三指令链，通过 store forwarding 形成回环
# ft0 = chain register, ft1=1.0 (mul identity), ft2=0.0 (add identity)
# fmadd.d: ft0 = ft0 * ft1 + ft2 = ft0 * 1.0 + 0.0 = ft0
# a1 = 固定 L1 地址，fsd 写回后 fld 通过 store forwarding 读取
# insn_per_iter=3
fld      ft0, 0(a1)
fmadd.d  ft0, ft0, ft1, ft2
fsd      ft0, 0(a1)
```

## 测试列表

| Test | 路径 | 链 | .rept | insn_per_iter | 说明 |
|------|------|-----|-------|---------------|------|
| FLD→FMA→FSD | fld_fma | ✅ | 100 | 3 | fld→fmadd.d→fsd 回环 |

## 解读

- `cycles/iter` = 往返延迟之和（FLD + FMA + FSD + store-forwarding）
- 对比 `store_fwd/fsd_fld` baseline（纯 fsd→fld 链）可得 FMA 插入代价
- FMA_overhead = `cycles/iter` - fsd_fld_baseline
- 若 FMA_overhead ≈ FMA_lat：forwarding 无额外惩罚
