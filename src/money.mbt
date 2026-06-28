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
