test "Money::add" {
  let m1 = Money::new(100L, usd)
  let m2 = Money::new(200L, usd)
  let m3 = m1.add(m2)
  assert_eq!(m3.amount, 300L)
}

test "Money::allocate" {
  let m = Money::new(100L, usd)
  let allocated = m.allocate([1, 1, 1])
  assert_eq!(allocated[0].amount, 34L)
  assert_eq!(allocated[1].amount, 33L)
  assert_eq!(allocated[2].amount, 33L)
}
