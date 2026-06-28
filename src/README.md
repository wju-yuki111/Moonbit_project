# MoonMoney 源码模块说明 (Internal Docs)

这里包含了 MoonMoney 引擎的核心业务逻辑实现。

## 模块结构
- `currency.mbt`: 包含 ISO-4217 货币标准的定义与常用币种。
- `money.mbt`: 包含 `Money` 结构体的底层 `Int64` 定义及所有的财务四则运算与无损分配算法。
- `money_test.mbt`: 核心逻辑测试覆盖用例，包含负数边界、除零防御及跨币种安全防御。

## 设计哲学
在 `src` 目录下，我们坚持：
1. **零外部依赖**: 所有运算仅使用 MoonBit `core` 库，确保运行速度和跨平台（Wasm）兼容性极佳。
2. **Fail-Fast (快速失败)**: 对于跨币种运算或异常入参，直接触发 `abort`，在计算的最早阶段切断错误。
