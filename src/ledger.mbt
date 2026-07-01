///|
/// Double-Entry Bookkeeping Ledger Engine.
/// Provides accounts, postings, balanced transactions, and financial statements.

///|
/// Five core categories of accounts in double-entry bookkeeping.
pub(all) enum AccountCategory {
  Asset
  Liability
  Equity
  Revenue
  Expense
} derive(Eq, Debug, Compare)

///|
/// Represents an account in the ledger.
pub(all) struct Account {
  id : Int
  name : String
  category : AccountCategory
  mut balance : Money
} derive(Eq, Debug, Compare)

///|
/// Represents a single debit or credit entry in a transaction.
pub(all) struct Posting {
  account_id : Int
  is_debit : Bool
  amount : Money
} derive(Eq, Debug, Compare)

///|
/// Represents a balanced journal transaction containing multiple postings.
pub(all) struct Transaction {
  id : Int
  description : String
  postings : Array[Posting]
} derive(Eq, Debug, Compare)

///|
/// A ledger containing all accounts and recorded transactions.
pub(all) struct Ledger {
  accounts : Array[Account]
  transactions : Array[Transaction]
}

///|
/// Creates a new empty Ledger.
pub fn Ledger::new() -> Ledger {
  { accounts: [], transactions: [] }
}

///|
/// Registers a new Account in the ledger. Aborts if the account ID is already registered.
pub fn Ledger::add_account(self : Ledger, account : Account) -> Unit {
  for acc in self.accounts {
    if acc.id == account.id {
      abort("Account ID already exists")
    }
  }
  self.accounts.push(account)
}

///|
/// Retrieves an account by its ID.
pub fn Ledger::get_account(self : Ledger, id : Int) -> Account? {
  for acc in self.accounts {
    if acc.id == id {
      return Some(acc)
    }
  }
  None
}

///|
/// Validates and records a Transaction in the ledger.
/// Enforces strict double-entry balance rules: Total Debits must equal Total Credits.
/// Updates account balances atomically if successful.
pub fn Ledger::record_transaction(
  self : Ledger,
  tx : Transaction,
) -> Result[Unit, String] {
  if tx.postings.length() < 2 {
    return Err("Transaction must have at least 2 postings")
  }

  let first_currency = tx.postings[0].amount.currency.code
  let mut debit_sum = 0L
  let mut credit_sum = 0L

  // Verify currency consistency and sum debits/credits
  for posting in tx.postings {
    if posting.amount.currency.code != first_currency {
      return Err("Multi-currency transaction postings are not supported")
    }

    // Check if account exists
    match self.get_account(posting.account_id) {
      None =>
        return Err(
          "Account ID " + posting.account_id.to_string() + " not found",
        )
      Some(_) => ()
    }

    if posting.is_debit {
      debit_sum = debit_sum + posting.amount.amount
    } else {
      credit_sum = credit_sum + posting.amount.amount
    }
  }

  if debit_sum != credit_sum {
    return Err(
      "Transaction is out of balance. Debits: " +
      debit_sum.to_string() +
      ", Credits: " +
      credit_sum.to_string(),
    )
  }

  // Apply entries to accounts
  for posting in tx.postings {
    let acc = match self.get_account(posting.account_id) {
      Some(a) => a
      None => abort("Account unexpectedly missing") // already validated
    }

    if posting.amount.currency.code != acc.balance.currency.code {
      return Err("Posting currency mismatch with account base currency")
    }

    let is_debit = posting.is_debit
    let amt = posting.amount.amount

    match acc.category {
      AccountCategory::Asset | AccountCategory::Expense =>
        if is_debit {
          acc.balance = {
            amount: acc.balance.amount + amt,
            currency: acc.balance.currency,
          }
        } else {
          acc.balance = {
            amount: acc.balance.amount - amt,
            currency: acc.balance.currency,
          }
        }
      AccountCategory::Liability
      | AccountCategory::Equity
      | AccountCategory::Revenue =>
        if is_debit {
          acc.balance = {
            amount: acc.balance.amount - amt,
            currency: acc.balance.currency,
          }
        } else {
          acc.balance = {
            amount: acc.balance.amount + amt,
            currency: acc.balance.currency,
          }
        }
    }
  }

  self.transactions.push(tx)
  Ok(())
}

///|
/// Verifies the structural integrity of the entire ledger.
/// Checks that the fundamental accounting equation holds: Assets = Liabilities + Equity.
/// Sums all revenues and expenses to calculate retained earnings.
pub fn Ledger::audit_balance(self : Ledger, base_currency : Currency) -> Bool {
  let mut total_assets = 0L
  let mut total_liabilities = 0L
  let mut total_equity = 0L
  let mut total_revenue = 0L
  let mut total_expense = 0L

  for acc in self.accounts {
    if acc.balance.currency.code != base_currency.code {
      continue // skip mismatched currencies for core audit
    }
    match acc.category {
      AccountCategory::Asset => total_assets = total_assets + acc.balance.amount
      AccountCategory::Liability =>
        total_liabilities = total_liabilities + acc.balance.amount
      AccountCategory::Equity =>
        total_equity = total_equity + acc.balance.amount
      AccountCategory::Revenue =>
        total_revenue = total_revenue + acc.balance.amount
      AccountCategory::Expense =>
        total_expense = total_expense + acc.balance.amount
    }
  }

  // Accounting Equation: Assets = Liabilities + Equity + (Revenues - Expenses)
  // Let Net Income = Revenues - Expenses
  let net_income = total_revenue - total_expense
  let right_side = total_liabilities + total_equity + net_income
  total_assets == right_side
}
