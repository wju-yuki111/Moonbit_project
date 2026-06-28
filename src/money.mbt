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
