# FLD→FMV.X.D Load Address Dependency

Load address dependency. cycles/iter = fld + fmv.x.d→addr forwarding 往返。

## 文档事实

- FLD latency (L1) 可从 `latency/LOAD/fld` 获取
- FMV.X.D latency 可从 `latency/FMV/fmv_x_d` 获取

## 待验证

- fld→fmv.x.d→addr 的往返 forwarding 延迟
- FP→INT 跨域 forwarding 是否引入额外惩罚

## Critical Section

```asm
# 构造：fld/fmv.x.d 交替链，t0 为自环指针，ft0 为 FP 中间值
# fld 通过 t0 地址加载到 ft0，fmv.x.d 将 ft0 恢复为 t0 地址
# insn_per_iter=2
fld      ft0, 0(t0)
fmv.x.d  t0, ft0
```

## 测试列表

| Test | 路径 | 链 | .rept | insn_per_iter | 说明 |
|------|------|-----|-------|---------------|------|
| FLD→FMV | fld_fmv | ✅ | 100 | 2 | fld→fmv.x.d 跨域地址回环 |

## 解读

- `cycles/iter` = FLD_lat(L1) + FMV.X.D_lat + forwarding overhead
- 对比 ld→add (load_use_l1/ld_alu) 可判断 FP→INT 跨域 forwarding 惩罚
- 该值是 fsd_fld_fmv 的 baseline（差值 = fsd 额外开销）
