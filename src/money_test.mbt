test "Money::add" {
  let m1 = Money::new(100L, usd)
  let m2 = Money::new(200L, usd)
  let m3 = m1.add(m2)
  assert_eq!(m3.amount, 300L)
}
