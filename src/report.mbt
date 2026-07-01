///|
/// Financial Reporting and Statement Generator.
/// Generates text-based formatted Balance Sheets, Income Statements, and Trial Balances.

///|
/// Formats a financial amount to fit a fixed width column, right-aligned.
fn right_align(s : String, width : Int) -> String {
  let len = s.length()
  if len >= width {
    return s
  }
  let mut padding = ""
  let diff = width - len
  for i = 0; i < diff; i = i + 1 {
    padding = padding + " "
  }
  padding + s
}

///|
/// Formats an account name to fit a fixed width column, left-aligned, padded with dots for readability (ledger style).
fn left_align_dots(s : String, width : Int) -> String {
  let len = s.length()
  if len >= width {
    return s
  }
  let mut res = s
  let diff = width - len
  for i = 0; i < diff; i = i + 1 {
    res = res + "."
  }
  res
}

///|
/// Generates a structured Balance Sheet report converted into a base currency.
/// Shows Assets, Liabilities, and Equity sections with totals, verifying the accounting equation.
pub fn generate_balance_sheet_report(
  ledger : Ledger,
  base : Currency,
  reg : ExchangeRegistry,
  locale : Locale,
) -> String {
  let mut report = ""
  report = report + "==================================================\n"
  report = report + "              资产负债表 (BALANCE SHEET)           \n"
  report = report +
    "             基准币种 (Base Currency): " +
    base.code +
    "    \n"
  report = report + "==================================================\n\n"

  let mut total_assets = 0L
  let mut total_liabilities = 0L
  let mut total_equity = 0L
  let mut total_revenue = 0L
  let mut total_expense = 0L

  let assets_lines = []
  let liabilities_lines = []
  let equity_lines = []

  for acc in ledger.accounts {
    // Convert to base currency
    let converted = reg.convert(acc.balance, base, RoundingMode::HalfEven)
    let formatted_val = converted.format(locale, true)
    let line = "  " +
      left_align_dots(acc.name, 30) +
      right_align(formatted_val, 15) +
      "\n"

    match acc.category {
      AccountCategory::Asset => {
        total_assets = total_assets + converted.amount
        assets_lines.push(line)
      }
      AccountCategory::Liability => {
        total_liabilities = total_liabilities + converted.amount
        liabilities_lines.push(line)
      }
      AccountCategory::Equity => {
        total_equity = total_equity + converted.amount
        equity_lines.push(line)
      }
      AccountCategory::Revenue =>
        total_revenue = total_revenue + converted.amount
      AccountCategory::Expense =>
        total_expense = total_expense + converted.amount
    }
  }

  // Section: Assets
  report = report + "资产账户 (ASSETS):\n"
  for line in assets_lines {
    report = report + line
  }
  report = report + "  ------------------------------------------------\n"
  let f_total_assets = Money::new(total_assets, base).format(locale, true)
  report = report +
    "  " +
    left_align_dots("资产总计 (Total Assets)", 30) +
    right_align(f_total_assets, 15) +
    "\n\n"

  // Section: Liabilities
  report = report + "负债账户 (LIABILITIES):\n"
  for line in liabilities_lines {
    report = report + line
  }
  report = report + "  ------------------------------------------------\n"
  let f_total_liab = Money::new(total_liabilities, base).format(locale, true)
  report = report +
    "  " +
    left_align_dots("负债总计 (Total Liabilities)", 30) +
    right_align(f_total_liab, 15) +
    "\n\n"

  // Section: Equity (including Net Income from Revenues and Expenses)
  report = report + "所有者权益 (EQUITY):\n"
  for line in equity_lines {
    report = report + line
  }

  // Add Net Income
  let net_income = total_revenue - total_expense
  let f_net_income = Money::new(net_income, base).format(locale, true)
  report = report +
    "  " +
    left_align_dots("本期净收益 (Net Income)", 30) +
    right_align(f_net_income, 15) +
    "\n"

  report = report + "  ------------------------------------------------\n"
  let combined_equity = total_equity + net_income
  let f_total_equity = Money::new(combined_equity, base).format(locale, true)
  report = report +
    "  " +
    left_align_dots("权益总计 (Total Equity)", 30) +
    right_align(f_total_equity, 15) +
    "\n\n"

  report = report + "==================================================\n"
  let combined_liab_equity = total_liabilities + combined_equity
  let f_combined = Money::new(combined_liab_equity, base).format(locale, true)
  report = report +
    "  " +
    left_align_dots("负债与权益总计 (Liabilities + Equity)", 30) +
    right_align(f_combined, 15) +
    "\n"
  report = report + "==================================================\n"

  report
}

///|
/// Generates a structured Income Statement report converted into a base currency.
/// Displays Revenues and Expenses, calculating Net Profit or Loss.
pub fn generate_income_statement_report(
  ledger : Ledger,
  base : Currency,
  reg : ExchangeRegistry,
  locale : Locale,
) -> String {
  let mut report = ""
  report = report + "==================================================\n"
  report = report + "              损益表 (INCOME STATEMENT)            \n"
  report = report +
    "             基准币种 (Base Currency): " +
    base.code +
    "    \n"
  report = report + "==================================================\n\n"

  let mut total_revenue = 0L
  let mut total_expense = 0L

  let revenue_lines = []
  let expense_lines = []

  for acc in ledger.accounts {
    let converted = reg.convert(acc.balance, base, RoundingMode::HalfEven)
    let formatted_val = converted.format(locale, true)
    let line = "  " +
      left_align_dots(acc.name, 30) +
      right_align(formatted_val, 15) +
      "\n"

    match acc.category {
      AccountCategory::Revenue => {
        total_revenue = total_revenue + converted.amount
        revenue_lines.push(line)
      }
      AccountCategory::Expense => {
        total_expense = total_expense + converted.amount
        expense_lines.push(line)
      }
      _ => ()
    }
  }

  // Section: Revenue
  report = report + "营业收入 (REVENUE):\n"
  for line in revenue_lines {
    report = report + line
  }
  report = report + "  ------------------------------------------------\n"
  let f_total_rev = Money::new(total_revenue, base).format(locale, true)
  report = report +
    "  " +
    left_align_dots("收入总计 (Total Revenue)", 30) +
    right_align(f_total_rev, 15) +
    "\n\n"

  // Section: Expenses
  report = report + "营业支出 (EXPENSES):\n"
  for line in expense_lines {
    report = report + line
  }
  report = report + "  ------------------------------------------------\n"
  let f_total_exp = Money::new(total_expense, base).format(locale, true)
  report = report +
    "  " +
    left_align_dots("支出总计 (Total Expenses)", 30) +
    right_align(f_total_exp, 15) +
    "\n\n"

  // Section: Net Income
  report = report + "==================================================\n"
  let net_profit = total_revenue - total_expense
  let f_net_profit = Money::new(net_profit, base).format(locale, true)
  report = report +
    "  " +
    left_align_dots("净利润 (Net Profit)", 30) +
    right_align(f_net_profit, 15) +
    "\n"
  report = report + "==================================================\n"

  report
}
