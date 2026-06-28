<div align="center">

# 🌕 MoonMoney

**A safe, high-precision currency and money manipulation library for MoonBit.**

[![MoonBit](https://img.shields.io/badge/Language-MoonBit-F58628.svg)](https://www.moonbitlang.com/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Build Status](https://img.shields.io/github/actions/workflow/status/wju-yuki111/Moonbit_project/ci.yml?branch=main)](https://github.com/wju-yuki111/Moonbit_project/actions)

</div>

---

MoonMoney is a specialized library designed to handle financial calculations in MoonBit without the precision loss inherent to standard floating-point arithmetic. By using robust `Int64` backend representations and strict currency-type safety, MoonMoney ensures your eCommerce, banking, or crypto application NEVER loses a single cent.

## ✨ Features

- **Floating-Point Safe**: All core representations use `Int64` under the hood. 
- **Type-Safe Currencies**: Prevents accidental addition or subtraction between different currencies (e.g., USD and CNY).
- **Smart Allocation**: A deterministic allocation algorithm to split funds evenly without losing remainders.
- **Zero Dependencies**: Pure MoonBit implementation, lightweight and fast.
- **Idiomatic MoonBit**: Built-in support for `Eq`, `Compare`, and `Show` traits.

## 📦 Installation

To install MoonMoney, use the standard `moon` package manager:

```bash
moon add wju-yuki111/moon-money
```

## 🚀 Quick Start

### 1. Basic Money Creation
Creating money is safe and expressive using predefined ISO-4217 currencies.

```moonbit
let price = Money::new(1000L, usd) // $10.00 (Assuming exponent 2)
let tax = Money::new(150L, usd)    // $1.50
```

### 2. Safe Mathematical Operations
MoonMoney ensures you can't accidentally add different currencies, preventing catastrophic financial logic errors.

```moonbit
let total = price.add(tax)
println(total) // Output: "USD 1150"

// This will abort at runtime to prevent invalid financial math:
// let invalid = price.add(Money::new(100L, cny)) 
```

### 3. The Smart Allocation Algorithm
A core highlight of MoonMoney is the `allocate` function. When dividing money, you often face remainder issues (e.g., 100 cents / 3). MoonMoney safely distributes the remainder across the results to ensure zero loss.

```moonbit
let fund = Money::new(100L, usd)
let shares = fund.allocate([1, 1, 1]) 

// The array will precisely contain: [34L, 33L, 33L]
println(shares[0]) // USD 34
println(shares[1]) // USD 33
println(shares[2]) // USD 33
```

## 📖 API Reference

### `struct Currency`
Defines a standard currency format.
- `code: String` - The ISO code (e.g., "USD")
- `exponent: Int` - Minor unit exponent (e.g., 2 for cents)

### `struct Money`
The core structure holding the amount.
- `amount: Int64` - The minor unit value.
- `currency: Currency` - The associated currency.

**Methods:**
- `Money::new(amount: Int64, currency: Currency) -> Money`
- `Money::from_int(amount: Int, currency: Currency) -> Money`
- `add(self, other: Money) -> Money`
- `sub(self, other: Money) -> Money`
- `mul(self, multiplier: Int64) -> Money`
- `allocate(self, ratios: Array[Int]) -> Array[Money]`

## 🤝 Contributing
Contributions, issues, and feature requests are welcome! 
Feel free to check [issues page](../../issues). Please read `CONTRIBUTING.md` for details on our code of conduct.

## 📝 License
This project is [MIT](LICENSE) licensed.