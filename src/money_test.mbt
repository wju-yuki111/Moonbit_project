test "Money::add" {
  let m1 = Money::new(100L, usd)
  let m2 = Money::new(50L, usd)
  let result = m1.add(m2)
  assert_eq!(result.amount, 150L)
}

test "Money::allocate" {
  let fund = Money::new(100L, usd)
  let shares = fund.allocate([1, 1, 1])
  assert_eq!(shares[0].amount, 34L)
  assert_eq!(shares[1].amount, 33L)
  assert_eq!(shares[2].amount, 33L)
}

test "Money::allocate_zero_ratios" {
  let fund = Money::new(100L, usd)
  // Even if ratio values are extreme, it handles them correctly
  let shares = fund.allocate([10, 0])
  assert_eq!(shares[0].amount, 100L)
  assert_eq!(shares[1].amount, 0L)
}

test "Money::sub_negative" {
  let m1 = Money::new(50L, cny)
  let m2 = Money::new(100L, cny)
  let result = m1.sub(m2)
  assert_eq!(result.amount, -50L)
}

test "Money::mul_zero" {
  let m = Money::new(999L, eur)
  let result = m.mul(0L)
  assert_eq!(result.amount, 0L)
}
