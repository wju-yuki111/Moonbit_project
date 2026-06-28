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
