# FSD→FLD→FMV.X.D Store Address Dependency

Store address dependency. 对比 fld_fmv 差值 = fsd addr 依赖 + store_fwd 开销。

## 文档事实

- FSD latency 可从 `latency/STORE/fsd` 获取
- FLD latency (L1) 可从 `latency/LOAD/fld` 获取
- FMV.X.D latency 可从 `latency/FMV/fmv_x_d` 获取

## 待验证

- fsd→fld→fmv.x.d 三指令链的往返延迟
- 对比 fld_fmv 的差值是否等于 store forwarding 延迟

## Critical Section

```asm
# 构造：fsd/fld/fmv.x.d 三指令链，t0 为自环指针，ft0 为 FP 中间值
# fsd 将 ft0（含地址位）写入 [t0]，fld 通过 store forwarding 读回 ft0
# fmv.x.d 将 ft0 恢复为 t0 地址，形成完整回环
# Pre-loop: fmv.d.x ft0, t0 确保首次 fsd 写入有效指针
# insn_per_iter=3
fsd      ft0, 0(t0)
fld      ft0, 0(t0)
fmv.x.d  t0, ft0
```

## 测试列表

| Test | 路径 | 链 | .rept | insn_per_iter | 说明 |
|------|------|-----|-------|---------------|------|
| FSD→FLD→FMV | fsd_fld_fmv | ✅ | 100 | 3 | fsd→fld→fmv.x.d 跨域地址回环 |

## 解读

- `cycles/iter` = FSD_store_fwd + FLD_lat + FMV.X.D_lat + forwarding overhead
- 差值 = `cycles/iter(fsd_fld_fmv)` - `cycles/iter(fld_fmv)` = fsd 引入的 store forwarding 额外延迟
- 若差值 ≈ store_fwd latency (sd_ld)：fsd 的 store forwarding 路径与 sd 一致
- 若差值 > store_fwd latency：FP store forwarding 存在额外跨域惩罚
