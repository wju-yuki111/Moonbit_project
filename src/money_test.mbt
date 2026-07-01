///|
/// Comprehensive Test Suite for the MoonMoney Financial Framework.
/// Verifies rounding, path-finding exchange rates, I18n parser/formatters, financial math, and double-entry bookkeeping.

///|
test "Rounding Modes - positive ratios" {
  // 10 * 3 / 2 = 15 (exact)
  assert_eq(round_ratio(10L, 3L, 2L, RoundingMode::HalfEven), 15L)

  // 10 * 1 / 3 = 3.3333...
  // HalfUp
  assert_eq(round_ratio(10L, 1L, 3L, RoundingMode::HalfUp), 3L)
  // HalfEven
  assert_eq(round_ratio(10L, 1L, 3L, RoundingMode::HalfEven), 3L)

  // Halfway cases (e.g. 5/2 = 2.5)
  // 5 * 1 / 2 = 2.5
  // HalfUp -> 3
  assert_eq(round_ratio(5L, 1L, 2L, RoundingMode::HalfUp), 3L)
  // HalfDown -> 2
  assert_eq(round_ratio(5L, 1L, 2L, RoundingMode::HalfDown), 2L)
  // HalfEven (Bankers') -> 2 (nearest even)
  assert_eq(round_ratio(5L, 1L, 2L, RoundingMode::HalfEven), 2L)

  // 7 * 1 / 2 = 3.5
  // HalfEven -> 4 (nearest even)
  assert_eq(round_ratio(7L, 1L, 2L, RoundingMode::HalfEven), 4L)

  // Ceiling / Floor
  assert_eq(round_ratio(5L, 1L, 2L, RoundingMode::Ceiling), 3L)
  assert_eq(round_ratio(5L, 1L, 2L, RoundingMode::Floor), 2L)
  assert_eq(round_ratio(-5L, 1L, 2L, RoundingMode::Ceiling), -2L)
  assert_eq(round_ratio(-5L, 1L, 2L, RoundingMode::Floor), -3L)
}

///|
test "Rounding Modes - edge cases" {
  // Up vs Down
  assert_eq(round_ratio(10L, 1L, 3L, RoundingMode::Up), 4L)
  assert_eq(round_ratio(10L, 1L, 3L, RoundingMode::Down), 3L)
  assert_eq(round_ratio(-10L, 1L, 3L, RoundingMode::Up), -4L)
  assert_eq(round_ratio(-10L, 1L, 3L, RoundingMode::Down), -3L)
}

///|
test "Exchange Registry - direct conversion" {
  let reg = ExchangeRegistry::new()
  // 1 USD = 7 CNY (represented as 7 / 1)
  reg.add_rate(ExchangeRate::new(usd, cny, 7L, 1L))

  let m_usd = Money::new(100L, usd) // $1.00
  let m_cny = reg.convert(m_usd, cny, RoundingMode::HalfEven)

  // $1.00 = 7.00 CNY. Both USD and CNY have exponent 2, so scaling is 10^0.
  // 100 * 7 = 700 CNY
  assert_eq(m_cny.amount, 700L)
  assert_eq(m_cny.currency.code, "CNY")
}

///|
test "Exchange Registry - reciprocal conversion" {
  let reg = ExchangeRegistry::new()
  reg.add_rate(ExchangeRate::new(usd, cny, 7L, 1L))

  let m_cny = Money::new(700L, cny) // 7.00 CNY
  let m_usd = reg.convert(m_cny, usd, RoundingMode::HalfEven)

  // Reciprocal rate is 1 / 7
  // 700 * 1 / 7 = 100 USD ($1.00)
  assert_eq(m_usd.amount, 100L)
  assert_eq(m_usd.currency.code, "USD")
}

///|
test "Exchange Registry - multi-currency pathfinding conversion" {
  let reg = ExchangeRegistry::new()
  // 1 USD = 0.9 EUR (9 / 10)
  reg.add_rate(ExchangeRate::new(usd, eur, 9L, 10L))
  // 1 EUR = 160 JPY (160 / 1)
  reg.add_rate(ExchangeRate::new(eur, jpy, 160L, 1L))

  // USD -> EUR -> JPY
  let m_usd = Money::new(1000L, usd) // $10.00
  let m_jpy = reg.convert(m_usd, jpy, RoundingMode::HalfEven)

  // 1) USD -> EUR:
  // Base exp: 2 (USD), Target exp: 2 (EUR). Diff: 0.
  // 1000 * 9 / 10 = 900 EUR
  // 2) EUR -> JPY:
  // Base exp: 2 (EUR), Target exp: 0 (JPY). Diff: -2.
  // We divide by 10^2 = 100.
  // Rate: 160 / 1. Adjustment: den * 100 = 100.
  // 900 * 160 / 100 = 1440 JPY
  assert_eq(m_jpy.amount, 1440L)
  assert_eq(m_jpy.currency.code, "JPY")
}

///|
test "I18n Formatter - standard formats" {
  let m1 = Money::new(123456L, usd)
  assert_eq(m1.format(Locale::us(), true), "$1,234.56")
  assert_eq(m1.format(Locale::us(), false), "USD 1,234.56")

  let m2 = Money::new(123456L, eur)
  assert_eq(m2.format(Locale::de(), true), "1.234,56 €")
  assert_eq(m2.format(Locale::fr(), true), "1 234,56 €")

  let m_jpy = Money::new(123456L, jpy)
  assert_eq(m_jpy.format(Locale::us(), true), "¥123,456")
}

///|
test "I18n Parser - standard strings" {
  // Positive USD
  let p1 = Money::parse("$1,234.56", usd, Locale::us())
  assert_eq(p1 is None, false)
  assert_eq(p1.unwrap().amount, 123456L)

  // Negative Euro
  let p2 = Money::parse("- 1.234,56 €", eur, Locale::de())
  assert_eq(p2 is None, false)
  assert_eq(p2.unwrap().amount, -123456L)

  // With parentheses representation
  let p3 = Money::parse("(100)", usd, Locale::us())
  assert_eq(p3 is None, false)
  assert_eq(p3.unwrap().amount, -10000L) // $100.00 -> 10000 cents

  // Invalid string
  let p4 = Money::parse("abc", usd, Locale::us())
  assert_eq(p4 is None, true)
}

///|
test "Financial Math - simple and compound interest" {
  let principal = Money::new(100000L, usd) // $1000.00

  // Simple interest: 5% annual rate, 3 years
  let simple = calculate_simple_interest(principal, 5L, 100L, 3L)
  assert_eq(simple.amount, 15000L) // $150.00 interest

  // Compound interest: 5% annual rate compounded annually, 3 years
  let compound = calculate_compound_interest(principal, 5L, 100L, 3)
  // Year 1: 1000.00 * 1.05 = 1050.00
  // Year 2: 1050.00 * 1.05 = 1102.50
  // Year 3: 1102.50 * 1.05 = 1157.625 -> Bankers rounding to 1157.62
  assert_eq(compound.amount, 115762L)
}

///|
test "Financial Math - loan amortization schedules" {
  let principal = Money::new(120000L, usd) // $1200.00 loan
  // 1% periodic interest, 3 periods

  // Equal principal amortization
  let eq_princ = generate_equal_principal_schedule(principal, 1L, 100L, 3)
  assert_eq(eq_princ.length(), 3)

  // Periodic principal = 1200 / 3 = 400
  // Period 1 interest: 1200 * 0.01 = 12
  assert_eq(eq_princ[0].principal.amount, 40000L)
  assert_eq(eq_princ[0].interest.amount, 1200L)
  assert_eq(eq_princ[0].payment.amount, 41200L)
  assert_eq(eq_princ[0].remaining_balance.amount, 80000L)

  // Period 2 interest: 800 * 0.01 = 8
  assert_eq(eq_princ[1].principal.amount, 40000L)
  assert_eq(eq_princ[1].interest.amount, 800L)
  assert_eq(eq_princ[1].payment.amount, 40800L)

  // Period 3 interest: 400 * 0.01 = 4
  assert_eq(eq_princ[2].principal.amount, 40000L)
  assert_eq(eq_princ[2].interest.amount, 400L)
  assert_eq(eq_princ[2].payment.amount, 40400L)
  assert_eq(eq_princ[2].remaining_balance.amount, 0L)

  // Equal installment amortization (annuity)
  let eq_inst = generate_equal_installment_schedule(principal, 1L, 100L, 3)
  assert_eq(eq_inst.length(), 3)
  // PMT factor calculations should balance out remaining loan exactly to 0
  assert_eq(eq_inst[2].remaining_balance.amount, 0L)
}

///|
test "Financial Math - taxes and discounts" {
  let income = Money::new(100000L, usd) // $1000.00

  // Progressive tax brackets:
  // Bracket 1: up to 300.00 -> 10%
  // Bracket 2: up to 800.00 -> 20%
  // Bracket 3: above 800.00 -> 30%
  let brackets = [
    (30000L, 10L, 100L),
    (80000L, 20L, 100L),
    (1000000L, 30L, 100L),
  ]
  let tax = calculate_progressive_tax(income, brackets)
  // Bracket 1 portion: 300.00 * 0.10 = 30.00 (3000L)
  // Bracket 2 portion: (800.00 - 300.00) * 0.20 = 100.00 (10000L)
  // Bracket 3 remainder: (1000.00 - 800.00) * 0.30 = 60.00 (6000L)
  // Total tax: 30.00 + 100.00 + 60.00 = 190.00 (19000L)
  assert_eq(tax.amount, 19000L)

  // VAT tax: 100.00 with 17% VAT
  let net = Money::new(10000L, usd)
  let vat = calculate_vat(net, 17L, 100L)
  assert_eq(vat.amount, 1700L)

  // Tiered discount:
  // Threshold 500.00 -> 10% discount
  // Threshold 1000.00 -> 20% discount
  let disc_tiers = [(50000L, 10L, 100L), (100000L, 20L, 100L)]
  let discount = calculate_tiered_discount(income, disc_tiers)
  assert_eq(discount.amount, 20000L) // 20% discount on 1000.00
}

///|
test "Double-Entry Ledger - balanced book recording" {
  let ledger = Ledger::new()

  // Register accounts:
  // Asset: Cash (ID 1)
  // Revenue: Sales (ID 2)
  // Expense: Rent (ID 3)
  ledger.add_account({
    id: 1,
    name: "Cash",
    category: AccountCategory::Asset,
    balance: Money::new(0L, usd),
  })
  ledger.add_account({
    id: 2,
    name: "Sales",
    category: AccountCategory::Revenue,
    balance: Money::new(0L, usd),
  })
  ledger.add_account({
    id: 3,
    name: "Rent",
    category: AccountCategory::Expense,
    balance: Money::new(0L, usd),
  })

  // Record Transaction 1: Make a Sale of $100.00
  // Debit: Cash (ID 1) $100.00
  // Credit: Sales (ID 2) $100.00
  let t1 = Transaction::{
    id: 101,
    description: "Initial Sale",
    postings: [
      { account_id: 1, is_debit: true, amount: Money::new(10000L, usd) },
      { account_id: 2, is_debit: false, amount: Money::new(10000L, usd) },
    ],
  }
  let res1 = ledger.record_transaction(t1)
  assert_eq(res1 is Err(_), false)

  // Audit cash: Should have increased by $100.00
  let cash_acc = ledger.get_account(1).unwrap()
  assert_eq(cash_acc.balance.amount, 10000L)

  // Record Transaction 2: Pay Rent of $40.00
  // Debit: Rent (ID 3) $40.00
  // Credit: Cash (ID 1) $40.00
  let t2 = Transaction::{
    id: 102,
    description: "Monthly Rent Payment",
    postings: [
      { account_id: 3, is_debit: true, amount: Money::new(4000L, usd) },
      { account_id: 1, is_debit: false, amount: Money::new(4000L, usd) },
    ],
  }
  let res2 = ledger.record_transaction(t2)
  assert_eq(res2 is Err(_), false)

  // Cash balance should now be $60.00
  assert_eq(ledger.get_account(1).unwrap().balance.amount, 6000L)
  // Rent expense balance should be $40.00
  assert_eq(ledger.get_account(3).unwrap().balance.amount, 4000L)

  // Verify basic bookkeeping identity: Assets = Liabilities + Equity + Revenue - Expense
  // Assets (Cash: $60.00) = Liabilities (0) + Equity (0) + Revenue ($100.00) - Expense ($40.00)
  assert_eq(ledger.audit_balance(usd), true)
}

///|
test "Double-Entry Ledger - unbalance validation" {
  let ledger = Ledger::new()
  ledger.add_account({
    id: 1,
    name: "Cash",
    category: AccountCategory::Asset,
    balance: Money::new(0L, usd),
  })
  ledger.add_account({
    id: 2,
    name: "Sales",
    category: AccountCategory::Revenue,
    balance: Money::new(0L, usd),
  })

  // Unbalanced transaction: Debit $100, Credit $90
  let t = Transaction::{
    id: 103,
    description: "Bad entry",
    postings: [
      { account_id: 1, is_debit: true, amount: Money::new(10000L, usd) },
      { account_id: 2, is_debit: false, amount: Money::new(9000L, usd) },
    ],
  }
  let res = ledger.record_transaction(t)
  assert_eq(res is Err(_), true) // Must fail
}

///|
test "Ledger Reporting - balance sheets and income statement generation" {
  let ledger = Ledger::new()

  ledger.add_account({
    id: 1,
    name: "Bank Checking",
    category: AccountCategory::Asset,
    balance: Money::new(500000L, cny),
  })
  ledger.add_account({
    id: 2,
    name: "Inventory",
    category: AccountCategory::Asset,
    balance: Money::new(150000L, cny),
  })
  ledger.add_account({
    id: 3,
    name: "Accounts Payable",
    category: AccountCategory::Liability,
    balance: Money::new(100000L, cny),
  })
  ledger.add_account({
    id: 4,
    name: "Capital Stock",
    category: AccountCategory::Equity,
    balance: Money::new(400000L, cny),
  })
  ledger.add_account({
    id: 5,
    name: "Software Sales",
    category: AccountCategory::Revenue,
    balance: Money::new(200000L, cny),
  })
  ledger.add_account({
    id: 6,
    name: "Office Rent",
    category: AccountCategory::Expense,
    balance: Money::new(50000L, cny),
  })

  let reg = ExchangeRegistry::new()

  let bs = generate_balance_sheet_report(ledger, cny, reg, Locale::cn())
  assert_eq(bs.contains("Bank Checking"), true)
  assert_eq(bs.contains("Capital Stock"), true)
  assert_eq(bs.contains("Total Assets"), true)
  assert_eq(bs.contains("¥6,500.00"), true) // Total Assets: 5000.00 + 1500.00 = 6500.00

  let is_report = generate_income_statement_report(
    ledger,
    cny,
    reg,
    Locale::cn(),
  )
  assert_eq(is_report.contains("Software Sales"), true)
  assert_eq(is_report.contains("Office Rent"), true)
  assert_eq(is_report.contains("¥1,500.00"), true) // Net Profit: 2000.00 - 500.00 = 1500.00
}

///|
test "Registry - validation of multiple global currencies" {
  // Test a subset of the huge registry to ensure properties are exact

  // USD
  let c_usd = find_currency("USD").unwrap()
  assert_eq(c_usd.code, "USD")
  assert_eq(c_usd.exponent, 2)
  assert_eq(c_usd.numeric_code, 840)
  assert_eq(get_currency_symbol("USD"), "$")

  // CNY
  let c_cny = find_currency("CNY").unwrap()
  assert_eq(c_cny.code, "CNY")
  assert_eq(c_cny.exponent, 2)
  assert_eq(c_cny.numeric_code, 156)
  assert_eq(get_currency_symbol("CNY"), "¥")

  // EUR
  let c_eur = find_currency("EUR").unwrap()
  assert_eq(c_eur.code, "EUR")
  assert_eq(c_eur.exponent, 2)
  assert_eq(c_eur.numeric_code, 978)
  assert_eq(get_currency_symbol("EUR"), "€")

  // JPY
  let c_jpy = find_currency("JPY").unwrap()
  assert_eq(c_jpy.code, "JPY")
  assert_eq(c_jpy.exponent, 0)
  assert_eq(c_jpy.numeric_code, 392)
  assert_eq(get_currency_symbol("JPY"), "¥")

  // GBP
  let c_gbp = find_currency("GBP").unwrap()
  assert_eq(c_gbp.code, "GBP")
  assert_eq(c_gbp.exponent, 2)
  assert_eq(c_gbp.numeric_code, 826)
  assert_eq(get_currency_symbol("GBP"), "£")

  // BHD (3 exponent)
  let c_bhd = find_currency("BHD").unwrap()
  assert_eq(c_bhd.code, "BHD")
  assert_eq(c_bhd.exponent, 3)
  assert_eq(c_bhd.numeric_code, 48)

  // BIF (0 exponent)
  let c_bif = find_currency("BIF").unwrap()
  assert_eq(c_bif.code, "BIF")
  assert_eq(c_bif.exponent, 0)

  // KRW (0 exponent)
  let c_krw = find_currency("KRW").unwrap()
  assert_eq(c_krw.code, "KRW")
  assert_eq(c_krw.exponent, 0)
  assert_eq(c_krw.numeric_code, 410)

  // CAD
  let c_cad = find_currency("CAD").unwrap()
  assert_eq(c_cad.code, "CAD")
  assert_eq(c_cad.exponent, 2)
  assert_eq(c_cad.numeric_code, 124)

  // RUB
  let c_rub = find_currency("RUB").unwrap()
  assert_eq(c_rub.code, "RUB")
  assert_eq(c_rub.exponent, 2)
  assert_eq(get_currency_symbol("RUB"), "₽")

  // invalid
  assert_eq(is_valid_currency("INVALID"), false)
  assert_eq(find_currency("XYZ") is None, true)
}

///|
test "Registry - exhaustive check of all standard currencies to assure database integrity" {
  // AFN
  let c = find_currency("AFN").unwrap()
  assert_eq(c.code, "AFN")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 971)

  // ALL
  let c = find_currency("ALL").unwrap()
  assert_eq(c.code, "ALL")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 8)

  // AMD
  let c = find_currency("AMD").unwrap()
  assert_eq(c.code, "AMD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 51)

  // ANG
  let c = find_currency("ANG").unwrap()
  assert_eq(c.code, "ANG")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 532)

  // AOA
  let c = find_currency("AOA").unwrap()
  assert_eq(c.code, "AOA")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 973)

  // AUD
  let c = find_currency("AUD").unwrap()
  assert_eq(c.code, "AUD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 36)

  // AWG
  let c = find_currency("AWG").unwrap()
  assert_eq(c.code, "AWG")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 533)

  // AZN
  let c = find_currency("AZN").unwrap()
  assert_eq(c.code, "AZN")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 944)

  // BAM
  let c = find_currency("BAM").unwrap()
  assert_eq(c.code, "BAM")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 977)

  // BBD
  let c = find_currency("BBD").unwrap()
  assert_eq(c.code, "BBD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 52)

  // BDT
  let c = find_currency("BDT").unwrap()
  assert_eq(c.code, "BDT")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 50)

  // BGN
  let c = find_currency("BGN").unwrap()
  assert_eq(c.code, "BGN")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 975)

  // BMD
  let c = find_currency("BMD").unwrap()
  assert_eq(c.code, "BMD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 60)

  // BND
  let c = find_currency("BND").unwrap()
  assert_eq(c.code, "BND")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 96)

  // BOB
  let c = find_currency("BOB").unwrap()
  assert_eq(c.code, "BOB")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 68)

  // BRL
  let c = find_currency("BRL").unwrap()
  assert_eq(c.code, "BRL")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 986)

  // BSD
  let c = find_currency("BSD").unwrap()
  assert_eq(c.code, "BSD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 44)

  // BTN
  let c = find_currency("BTN").unwrap()
  assert_eq(c.code, "BTN")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 64)

  // BWP
  let c = find_currency("BWP").unwrap()
  assert_eq(c.code, "BWP")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 72)

  // BYN
  let c = find_currency("BYN").unwrap()
  assert_eq(c.code, "BYN")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 933)

  // BZD
  let c = find_currency("BZD").unwrap()
  assert_eq(c.code, "BZD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 84)

  // CDF
  let c = find_currency("CDF").unwrap()
  assert_eq(c.code, "CDF")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 976)

  // CHF
  let c = find_currency("CHF").unwrap()
  assert_eq(c.code, "CHF")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 756)

  // COP
  let c = find_currency("COP").unwrap()
  assert_eq(c.code, "COP")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 170)

  // CRC
  let c = find_currency("CRC").unwrap()
  assert_eq(c.code, "CRC")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 188)

  // CUP
  let c = find_currency("CUP").unwrap()
  assert_eq(c.code, "CUP")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 192)

  // CVE
  let c = find_currency("CVE").unwrap()
  assert_eq(c.code, "CVE")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 132)

  // CZK
  let c = find_currency("CZK").unwrap()
  assert_eq(c.code, "CZK")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 203)

  // DKK
  let c = find_currency("DKK").unwrap()
  assert_eq(c.code, "DKK")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 208)

  // DOP
  let c = find_currency("DOP").unwrap()
  assert_eq(c.code, "DOP")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 214)

  // DZD
  let c = find_currency("DZD").unwrap()
  assert_eq(c.code, "DZD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 12)

  // EGP
  let c = find_currency("EGP").unwrap()
  assert_eq(c.code, "EGP")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 818)

  // ERN
  let c = find_currency("ERN").unwrap()
  assert_eq(c.code, "ERN")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 232)

  // ETB
  let c = find_currency("ETB").unwrap()
  assert_eq(c.code, "ETB")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 230)

  // FJD
  let c = find_currency("FJD").unwrap()
  assert_eq(c.code, "FJD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 242)

  // FKP
  let c = find_currency("FKP").unwrap()
  assert_eq(c.code, "FKP")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 238)

  // GEL
  let c = find_currency("GEL").unwrap()
  assert_eq(c.code, "GEL")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 981)

  // GHS
  let c = find_currency("GHS").unwrap()
  assert_eq(c.code, "GHS")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 936)

  // GIP
  let c = find_currency("GIP").unwrap()
  assert_eq(c.code, "GIP")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 292)

  // GMD
  let c = find_currency("GMD").unwrap()
  assert_eq(c.code, "GMD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 270)

  // GTQ
  let c = find_currency("GTQ").unwrap()
  assert_eq(c.code, "GTQ")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 320)

  // GYD
  let c = find_currency("GYD").unwrap()
  assert_eq(c.code, "GYD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 328)

  // HNL
  let c = find_currency("HNL").unwrap()
  assert_eq(c.code, "HNL")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 340)

  // HRK
  let c = find_currency("HRK").unwrap()
  assert_eq(c.code, "HRK")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 191)

  // HTG
  let c = find_currency("HTG").unwrap()
  assert_eq(c.code, "HTG")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 332)

  // HUF
  let c = find_currency("HUF").unwrap()
  assert_eq(c.code, "HUF")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 348)

  // IDR
  let c = find_currency("IDR").unwrap()
  assert_eq(c.code, "IDR")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 360)

  // ILS
  let c = find_currency("ILS").unwrap()
  assert_eq(c.code, "ILS")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 376)

  // INR
  let c = find_currency("INR").unwrap()
  assert_eq(c.code, "INR")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 356)

  // IRR
  let c = find_currency("IRR").unwrap()
  assert_eq(c.code, "IRR")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 364)

  // JMD
  let c = find_currency("JMD").unwrap()
  assert_eq(c.code, "JMD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 388)

  // KES
  let c = find_currency("KES").unwrap()
  assert_eq(c.code, "KES")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 404)

  // KGS
  let c = find_currency("KGS").unwrap()
  assert_eq(c.code, "KGS")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 417)

  // KHR
  let c = find_currency("KHR").unwrap()
  assert_eq(c.code, "KHR")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 116)

  // KPW
  let c = find_currency("KPW").unwrap()
  assert_eq(c.code, "KPW")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 408)

  // KZT
  let c = find_currency("KZT").unwrap()
  assert_eq(c.code, "KZT")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 398)

  // LAK
  let c = find_currency("LAK").unwrap()
  assert_eq(c.code, "LAK")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 418)

  // LBP
  let c = find_currency("LBP").unwrap()
  assert_eq(c.code, "LBP")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 422)

  // LKR
  let c = find_currency("LKR").unwrap()
  assert_eq(c.code, "LKR")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 144)

  // LRD
  let c = find_currency("LRD").unwrap()
  assert_eq(c.code, "LRD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 430)

  // LSL
  let c = find_currency("LSL").unwrap()
  assert_eq(c.code, "LSL")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 426)

  // MAD
  let c = find_currency("MAD").unwrap()
  assert_eq(c.code, "MAD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 504)

  // MDL
  let c = find_currency("MDL").unwrap()
  assert_eq(c.code, "MDL")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 498)

  // MGA
  let c = find_currency("MGA").unwrap()
  assert_eq(c.code, "MGA")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 969)

  // MKD
  let c = find_currency("MKD").unwrap()
  assert_eq(c.code, "MKD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 807)

  // MMK
  let c = find_currency("MMK").unwrap()
  assert_eq(c.code, "MMK")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 104)

  // MNT
  let c = find_currency("MNT").unwrap()
  assert_eq(c.code, "MNT")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 496)

  // MOP
  let c = find_currency("MOP").unwrap()
  assert_eq(c.code, "MOP")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 446)

  // MRU
  let c = find_currency("MRU").unwrap()
  assert_eq(c.code, "MRU")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 929)

  // MUR
  let c = find_currency("MUR").unwrap()
  assert_eq(c.code, "MUR")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 480)

  // MVR
  let c = find_currency("MVR").unwrap()
  assert_eq(c.code, "MVR")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 462)

  // MWK
  let c = find_currency("MWK").unwrap()
  assert_eq(c.code, "MWK")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 454)

  // MYR
  let c = find_currency("MYR").unwrap()
  assert_eq(c.code, "MYR")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 458)

  // MZN
  let c = find_currency("MZN").unwrap()
  assert_eq(c.code, "MZN")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 943)

  // NAD
  let c = find_currency("NAD").unwrap()
  assert_eq(c.code, "NAD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 516)

  // NGN
  let c = find_currency("NGN").unwrap()
  assert_eq(c.code, "NGN")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 566)

  // NIO
  let c = find_currency("NIO").unwrap()
  assert_eq(c.code, "NIO")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 558)

  // NPR
  let c = find_currency("NPR").unwrap()
  assert_eq(c.code, "NPR")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 524)

  // PAB
  let c = find_currency("PAB").unwrap()
  assert_eq(c.code, "PAB")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 590)

  // PEN
  let c = find_currency("PEN").unwrap()
  assert_eq(c.code, "PEN")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 604)

  // PGK
  let c = find_currency("PGK").unwrap()
  assert_eq(c.code, "PGK")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 598)

  // PHP
  let c = find_currency("PHP").unwrap()
  assert_eq(c.code, "PHP")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 608)

  // PKR
  let c = find_currency("PKR").unwrap()
  assert_eq(c.code, "PKR")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 586)

  // PLN
  let c = find_currency("PLN").unwrap()
  assert_eq(c.code, "PLN")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 985)

  // QAR
  let c = find_currency("QAR").unwrap()
  assert_eq(c.code, "QAR")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 634)

  // RON
  let c = find_currency("RON").unwrap()
  assert_eq(c.code, "RON")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 946)

  // RSD
  let c = find_currency("RSD").unwrap()
  assert_eq(c.code, "RSD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 941)

  // SBD
  let c = find_currency("SBD").unwrap()
  assert_eq(c.code, "SBD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 90)

  // SCR
  let c = find_currency("SCR").unwrap()
  assert_eq(c.code, "SCR")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 690)

  // SDG
  let c = find_currency("SDG").unwrap()
  assert_eq(c.code, "SDG")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 938)

  // SEK
  let c = find_currency("SEK").unwrap()
  assert_eq(c.code, "SEK")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 752)

  // SGD
  let c = find_currency("SGD").unwrap()
  assert_eq(c.code, "SGD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 702)

  // SHP
  let c = find_currency("SHP").unwrap()
  assert_eq(c.code, "SHP")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 654)

  // SLL
  let c = find_currency("SLL").unwrap()
  assert_eq(c.code, "SLL")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 694)

  // SOS
  let c = find_currency("SOS").unwrap()
  assert_eq(c.code, "SOS")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 706)

  // SRD
  let c = find_currency("SRD").unwrap()
  assert_eq(c.code, "SRD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 968)

  // SSP
  let c = find_currency("SSP").unwrap()
  assert_eq(c.code, "SSP")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 728)

  // STN
  let c = find_currency("STN").unwrap()
  assert_eq(c.code, "STN")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 930)

  // SYP
  let c = find_currency("SYP").unwrap()
  assert_eq(c.code, "SYP")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 760)

  // SZL
  let c = find_currency("SZL").unwrap()
  assert_eq(c.code, "SZL")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 748)

  // THB
  let c = find_currency("THB").unwrap()
  assert_eq(c.code, "THB")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 764)

  // TJS
  let c = find_currency("TJS").unwrap()
  assert_eq(c.code, "TJS")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 972)

  // TMT
  let c = find_currency("TMT").unwrap()
  assert_eq(c.code, "TMT")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 934)

  // TOP
  let c = find_currency("TOP").unwrap()
  assert_eq(c.code, "TOP")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 776)

  // TTD
  let c = find_currency("TTD").unwrap()
  assert_eq(c.code, "TTD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 780)

  // TWD
  let c = find_currency("TWD").unwrap()
  assert_eq(c.code, "TWD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 901)

  // TZS
  let c = find_currency("TZS").unwrap()
  assert_eq(c.code, "TZS")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 834)

  // UAH
  let c = find_currency("UAH").unwrap()
  assert_eq(c.code, "UAH")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 980)

  // UYU
  let c = find_currency("UYU").unwrap()
  assert_eq(c.code, "UYU")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 858)

  // UZS
  let c = find_currency("UZS").unwrap()
  assert_eq(c.code, "UZS")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 860)

  // VES
  let c = find_currency("VES").unwrap()
  assert_eq(c.code, "VES")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 928)

  // WST
  let c = find_currency("WST").unwrap()
  assert_eq(c.code, "WST")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 882)

  // XCD
  let c = find_currency("XCD").unwrap()
  assert_eq(c.code, "XCD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 951)

  // YER
  let c = find_currency("YER").unwrap()
  assert_eq(c.code, "YER")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 886)

  // ZMW
  let c = find_currency("ZMW").unwrap()
  assert_eq(c.code, "ZMW")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 967)

  // ZWL
  let c = find_currency("ZWL").unwrap()
  assert_eq(c.code, "ZWL")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 932)

  // BTC
  let c = find_currency("BTC").unwrap()
  assert_eq(c.code, "BTC")
  assert_eq(c.exponent, 8)
  assert_eq(c.name, "Bitcoin")
  assert_eq(c.symbol, "₿")
  assert_eq(c.numeric_code, 0)

  // ETH
  let c = find_currency("ETH").unwrap()
  assert_eq(c.code, "ETH")
  assert_eq(c.exponent, 8)
  assert_eq(c.name, "Ethereum")
  assert_eq(c.symbol, "Ξ")

  // BHD
  let c = find_currency("BHD").unwrap()
  assert_eq(c.code, "BHD")
  assert_eq(c.exponent, 3)
  assert_eq(c.numeric_code, 48)

  // JPY
  let c = find_currency("JPY").unwrap()
  assert_eq(c.code, "JPY")
  assert_eq(c.exponent, 0)
  assert_eq(c.symbol, "¥")

  // KRW
  let c = find_currency("KRW").unwrap()
  assert_eq(c.code, "KRW")
  assert_eq(c.exponent, 0)
  assert_eq(c.numeric_code, 410)

  // VND
  let c = find_currency("VND").unwrap()
  assert_eq(c.code, "VND")
  assert_eq(c.exponent, 0)
  assert_eq(c.numeric_code, 704)

  // SEK
  let c = find_currency("SEK").unwrap()
  assert_eq(c.code, "SEK")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 752)

  // NZD
  let c = find_currency("NZD").unwrap()
  assert_eq(c.code, "NZD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 554)

  // SGD
  let c = find_currency("SGD").unwrap()
  assert_eq(c.code, "SGD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 702)

  // HKD
  let c = find_currency("HKD").unwrap()
  assert_eq(c.code, "HKD")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 344)

  // NOK
  let c = find_currency("NOK").unwrap()
  assert_eq(c.code, "NOK")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 578)

  // DKK
  let c = find_currency("DKK").unwrap()
  assert_eq(c.code, "DKK")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 208)

  // PLN
  let c = find_currency("PLN").unwrap()
  assert_eq(c.code, "PLN")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 985)

  // ILS
  let c = find_currency("ILS").unwrap()
  assert_eq(c.code, "ILS")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 376)

  // ZAR
  let c = find_currency("ZAR").unwrap()
  assert_eq(c.code, "ZAR")
  assert_eq(c.exponent, 2)
  assert_eq(c.numeric_code, 710)

  // BIF
  let c = find_currency("BIF").unwrap()
  assert_eq(c.code, "BIF")
  assert_eq(c.exponent, 0)
  assert_eq(c.numeric_code, 108)

  // UGX
  let c = find_currency("UGX").unwrap()
  assert_eq(c.code, "UGX")
  assert_eq(c.exponent, 0)
  assert_eq(c.numeric_code, 800)
}

///|
test "Exchange Registry - 6-step deep path conversion" {
  let reg = ExchangeRegistry::new()
  reg.add_rate(ExchangeRate::new(usd, eur, 9L, 10L)) // 1 USD = 0.9 EUR
  reg.add_rate(ExchangeRate::new(eur, gbp, 8L, 10L)) // 1 EUR = 0.8 GBP
  reg.add_rate(ExchangeRate::new(gbp, cad, 17L, 10L)) // 1 GBP = 1.7 CAD
  reg.add_rate(ExchangeRate::new(cad, aud, 11L, 10L)) // 1 CAD = 1.1 AUD
  reg.add_rate(ExchangeRate::new(aud, nzd, 11L, 10L)) // 1 AUD = 1.1 NZD
  reg.add_rate(ExchangeRate::new(nzd, sgd, 9L, 10L)) // 1 NZD = 0.9 SGD

  let m_usd = Money::new(1000000L, usd) // $10,000.00
  let m_sgd = reg.convert(m_usd, sgd, RoundingMode::HalfEven)

  // Math chain (all exponents are 2, so scale adjustment factor is 1 per step):
  // 1,000,000 * 0.9 = 900,000 EUR
  // 900,000 * 0.8 = 720,000 GBP
  // 720,000 * 1.7 = 1,224,000 CAD
  // 1,224,000 * 1.1 = 1,346,400 AUD
  // 1,346,400 * 1.1 = 1,481,040 NZD
  // 1,481,040 * 0.9 = 1,332,936 SGD
  assert_eq(m_sgd.amount, 1332936L)
}

///|
test "Double-Entry Ledger - Comprehensive corporate bookkeeping and report generation audit" {
  let ledger = Ledger::new()

  // Chart of accounts setup:
  // Assets
  ledger.add_account({
    id: 1001,
    name: "Cash",
    category: AccountCategory::Asset,
    balance: Money::new(0L, usd),
  })
  ledger.add_account({
    id: 1002,
    name: "Accounts Receivable",
    category: AccountCategory::Asset,
    balance: Money::new(0L, usd),
  })
  ledger.add_account({
    id: 1003,
    name: "Inventory",
    category: AccountCategory::Asset,
    balance: Money::new(0L, usd),
  })
  // Liabilities
  ledger.add_account({
    id: 2001,
    name: "Accounts Payable",
    category: AccountCategory::Liability,
    balance: Money::new(0L, usd),
  })
  // Equity
  ledger.add_account({
    id: 3001,
    name: "Common Stock",
    category: AccountCategory::Equity,
    balance: Money::new(0L, usd),
  })
  // Revenues
  ledger.add_account({
    id: 4001,
    name: "Sales Revenue",
    category: AccountCategory::Revenue,
    balance: Money::new(0L, usd),
  })
  // Expenses
  ledger.add_account({
    id: 5001,
    name: "Cost of Goods Sold",
    category: AccountCategory::Expense,
    balance: Money::new(0L, usd),
  })
  ledger.add_account({
    id: 5002,
    name: "Rent Expense",
    category: AccountCategory::Expense,
    balance: Money::new(0L, usd),
  })
  ledger.add_account({
    id: 5003,
    name: "Salary Expense",
    category: AccountCategory::Expense,
    balance: Money::new(0L, usd),
  })

  // Transaction 1: Capital investment of $500,000 cash.
  // Debit: Cash (1001) $500,000
  // Credit: Common Stock (3001) $500,000
  let t1 = Transaction::{
    id: 1,
    description: "Capital Investment",
    postings: [
      { account_id: 1001, is_debit: true, amount: Money::new(50000000L, usd) },
      { account_id: 3001, is_debit: false, amount: Money::new(50000000L, usd) },
    ],
  }
  assert_eq(ledger.record_transaction(t1) is Err(_), false)

  // Transaction 2: Buy inventory on credit for $80,000.
  // Debit: Inventory (1003) $80,000
  // Credit: Accounts Payable (2001) $80,000
  let t2 = Transaction::{
    id: 2,
    description: "Purchase Inventory",
    postings: [
      { account_id: 1003, is_debit: true, amount: Money::new(8000000L, usd) },
      { account_id: 2001, is_debit: false, amount: Money::new(8000000L, usd) },
    ],
  }
  assert_eq(ledger.record_transaction(t2) is Err(_), false)

  // Transaction 3: Pay office rent of $5,000.
  // Debit: Rent Expense (5002) $5,000
  // Credit: Cash (1001) $5,000
  let t3 = Transaction::{
    id: 3,
    description: "Office Rent",
    postings: [
      { account_id: 5002, is_debit: true, amount: Money::new(500000L, usd) },
      { account_id: 1001, is_debit: false, amount: Money::new(500000L, usd) },
    ],
  }
  assert_eq(ledger.record_transaction(t3) is Err(_), false)

  // Transaction 4: Sell products for $120,000 on credit.
  // Debit: Accounts Receivable (1002) $120,000
  // Credit: Sales Revenue (4001) $120,000
  let t4 = Transaction::{
    id: 4,
    description: "Sale of Products",
    postings: [
      { account_id: 1002, is_debit: true, amount: Money::new(12000000L, usd) },
      { account_id: 4001, is_debit: false, amount: Money::new(12000000L, usd) },
    ],
  }
  assert_eq(ledger.record_transaction(t4) is Err(_), false)

  // Transaction 5: Recognize cost of inventory sold for $50,000.
  // Debit: Cost of Goods Sold (5001) $50,000
  // Credit: Inventory (1003) $50,000
  let t5 = Transaction::{
    id: 5,
    description: "Recognize COGS",
    postings: [
      { account_id: 5001, is_debit: true, amount: Money::new(5000000L, usd) },
      { account_id: 1003, is_debit: false, amount: Money::new(5000000L, usd) },
    ],
  }
  assert_eq(ledger.record_transaction(t5) is Err(_), false)

  // Transaction 6: Pay salaries of $20,000.
  // Debit: Salary Expense (5003) $20,000
  // Credit: Cash (1001) $20,000
  let t6 = Transaction::{
    id: 6,
    description: "Pay Salaries",
    postings: [
      { account_id: 5003, is_debit: true, amount: Money::new(2000000L, usd) },
      { account_id: 1001, is_debit: false, amount: Money::new(2000000L, usd) },
    ],
  }
  assert_eq(ledger.record_transaction(t6) is Err(_), false)

  // Transaction 7: Pay $30,000 of accounts payable.
  // Debit: Accounts Payable (2001) $30,000
  // Credit: Cash (1001) $30,000
  let t7 = Transaction::{
    id: 7,
    description: "Pay Accounts Payable",
    postings: [
      { account_id: 2001, is_debit: true, amount: Money::new(3000000L, usd) },
      { account_id: 1001, is_debit: false, amount: Money::new(3000000L, usd) },
    ],
  }
  assert_eq(ledger.record_transaction(t7) is Err(_), false)

  // Verify ending account balances:
  // Cash balance: 0 + 500000 - 5000 - 20000 - 30000 = $445,000
  assert_eq(ledger.get_account(1001).unwrap().balance.amount, 44500000L)
  // Accounts Receivable: $120,000
  assert_eq(ledger.get_account(1002).unwrap().balance.amount, 12000000L)
  // Inventory: 80000 - 50000 = $30,000
  assert_eq(ledger.get_account(1003).unwrap().balance.amount, 3000000L)
  // Accounts Payable: 80000 - 30000 = $50,000
  assert_eq(ledger.get_account(2001).unwrap().balance.amount, 5000000L)

  // Verify Audit
  assert_eq(ledger.audit_balance(usd), true)

  // Generate Reports and audit text contents
  let reg = ExchangeRegistry::new()
  let bs_report = generate_balance_sheet_report(ledger, usd, reg, Locale::us())
  assert_eq(bs_report.contains("Bank Checking"), false)
  assert_eq(bs_report.contains("Cash"), true)
  assert_eq(bs_report.contains("Total Assets"), true)
  assert_eq(bs_report.contains("$595,000.00"), true) // Assets: Cash 445k + AR 120k + Inv 30k = 595k
  assert_eq(bs_report.contains("$50,000.00"), true) // Accounts Payable: 50k
  assert_eq(bs_report.contains("$500,000.00"), true) // Common Stock: 500k
  assert_eq(bs_report.contains("$45,000.00"), true) // Net Income: Sales 120k - COGS 50k - Rent 5k - Salaries 20k = 45k
  assert_eq(bs_report.contains("$545,000.00"), true) // Total Equity: Stock 500k + Net Income 45k = 545k

  let is_report = generate_income_statement_report(
    ledger,
    usd,
    reg,
    Locale::us(),
  )
  assert_eq(is_report.contains("Sales Revenue"), true)
  assert_eq(is_report.contains("Cost of Goods Sold"), true)
  assert_eq(is_report.contains("Rent Expense"), true)
  assert_eq(is_report.contains("Salary Expense"), true)
  assert_eq(is_report.contains("$45,000.00"), true) // Net Profit: 45k
}
