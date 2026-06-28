pub struct Money {
  amount : Int64
  currency : Currency
}

pub fn Money::new(amount : Int64, currency : Currency) -> Money {
  { amount, currency }
}

pub fn Money::from_int(amount : Int, currency : Currency) -> Money {
  { amount: amount.to_int64(), currency }
}

pub impl Eq for Money with op_equal(self, other) {
  self.amount == other.amount && self.currency.code == other.currency.code
}

pub impl Compare for Money with compare(self, other) {
  if self.currency.code != other.currency.code {
    abort("Cannot compare money of different currencies")
  }
  self.amount.compare(other.amount)
}

pub fn Money::add(self : Money, other : Money) -> Money {
  if self.currency.code != other.currency.code {
    abort("Currency mismatch")
  }
  { amount: self.amount + other.amount, currency: self.currency }
}

pub fn Money::sub(self : Money, other : Money) -> Money {
  if self.currency.code != other.currency.code {
    abort("Currency mismatch")
  }
  { amount: self.amount - other.amount, currency: self.currency }
}

pub fn Money::mul(self : Money, multiplier : Int64) -> Money {
  { amount: self.amount * multiplier, currency: self.currency }
}

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
