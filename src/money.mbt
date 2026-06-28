/// Money represents a safe financial value bounded to a specific Currency.
/// It strictly uses `Int64` for internal representation to eliminate
/// floating-point calculation issues.
pub struct Money {
  amount : Int64
  currency : Currency
}

/// Creates a new Money instance from an Int64 amount and a Currency.
pub fn Money::new(amount : Int64, currency : Currency) -> Money {
  { amount, currency }
}

/// Creates a new Money instance from a standard Int amount.
pub fn Money::from_int(amount : Int, currency : Currency) -> Money {
  { amount: amount.to_int64(), currency }
}

/// Checks if two Money instances are exactly equal in amount and currency.
pub impl Eq for Money with op_equal(self, other) {
  self.amount == other.amount && self.currency.code == other.currency.code
}

/// Compares the amount of two Money instances. 
/// Aborts if the currencies do not match.
pub impl Compare for Money with compare(self, other) {
  if self.currency.code != other.currency.code {
    abort("Cannot compare money of different currencies")
  }
  self.amount.compare(other.amount)
}

/// Adds two Money amounts safely.
/// Aborts if the currencies do not match.
pub fn Money::add(self : Money, other : Money) -> Money {
  if self.currency.code != other.currency.code {
    abort("Currency mismatch")
  }
  { amount: self.amount + other.amount, currency: self.currency }
}

/// Subtracts two Money amounts safely.
/// Aborts if the currencies do not match.
pub fn Money::sub(self : Money, other : Money) -> Money {
  if self.currency.code != other.currency.code {
    abort("Currency mismatch")
  }
  { amount: self.amount - other.amount, currency: self.currency }
}

/// Multiplies a Money instance by a scalar Int64 value.
pub fn Money::mul(self : Money, multiplier : Int64) -> Money {
  { amount: self.amount * multiplier, currency: self.currency }
}

/// Allocates the Money based on an array of proportional ratios.
/// Safely distributes any remainder among the first N splits to prevent penny loss.
pub fn Money::allocate(self : Money, ratios : Array[Int]) -> Array[Money] {
  let mut total_ratio = 0L
  for ratio in ratios {
    total_ratio = total_ratio + ratio.to_int64()
  }
  let mut remainder = self.amount
  let results = []
  for ratio in ratios {
    let share = self.amount * ratio.to_int64() / total_ratio
    results.push({ amount: share, currency: self.currency })
    remainder = remainder - share
  }
  for i = 0; i < remainder.to_int(); i = i + 1 {
    results[i].amount = results[i].amount + 1L
  }
  results
}

/// Implements a simple string formatting for Money, e.g., "USD 1050".
pub impl Show for Money with output(self, logger) {
  logger.write_string(self.currency.code)
  logger.write_string(" ")
  logger.write_string(self.amount.to_string())
}
