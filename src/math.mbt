///|
/// Financial Mathematics and Commercial Business Calculations.
/// Supports compound interest, loan schedules, tax engines, and discount matrices.

///|
/// Represents a single payment entry in a loan amortization schedule.
pub(all) struct LoanPayment {
  period : Int
  payment : Money
  principal : Money
  interest : Money
  remaining_balance : Money
} derive(Eq, Debug, Compare)

///|
/// Calculates simple interest.
/// Interest = Principal * Rate * Periods.
/// 
/// Parameters:
/// - `principal`: The base Money amount.
/// - `rate_numerator` / `rate_denominator`: The precise interest rate per period.
/// - `periods`: The number of interest periods.
pub fn calculate_simple_interest(
  principal : Money,
  rate_numerator : Int64,
  rate_denominator : Int64,
  periods : Int64,
) -> Money {
  let interest_amount = round_ratio(
    principal.amount * periods,
    rate_numerator,
    rate_denominator,
    RoundingMode::HalfEven,
  )
  { amount: interest_amount, currency: principal.currency }
}

///|
/// Calculates compound interest.
/// Future Value = Principal * (1 + Rate)^Periods.
/// 
/// Parameters:
/// - `principal`: The base Money amount.
/// - `rate_numerator` / `rate_denominator`: Interest rate per compounding period.
/// - `periods`: The number of compounding periods.
pub fn calculate_compound_interest(
  principal : Money,
  rate_numerator : Int64,
  rate_denominator : Int64,
  periods : Int,
) -> Money {
  let mut current_amount = principal.amount
  for i = 0; i < periods; i = i + 1 {
    // New principal = Current Principal * (1 + Rate)
    // = Current Principal * (rate_denominator + rate_numerator) / rate_denominator
    current_amount = round_ratio(
      current_amount,
      rate_denominator + rate_numerator,
      rate_denominator,
      RoundingMode::HalfEven,
    )
  }
  { amount: current_amount, currency: principal.currency }
}

///|
/// Generates an amortization schedule for a loan using the Equal Principal method.
/// 
/// Parameters:
/// - `principal`: The total loan principal amount.
/// - `rate_numerator` / `rate_denominator`: Periodic interest rate.
/// - `periods`: Total number of payment periods (e.g. months).
pub fn generate_equal_principal_schedule(
  principal : Money,
  rate_numerator : Int64,
  rate_denominator : Int64,
  periods : Int,
) -> Array[LoanPayment] {
  if periods <= 0 {
    abort("Loan periods must be positive")
  }

  let schedule = []
  let mut remaining = principal.amount
  let periodic_principal = principal.amount / periods.to_int64()
  let principal_remainder = principal.amount % periods.to_int64()

  for i = 1; i <= periods; i = i + 1 {
    // Calculate principal portion for this period
    let principal_portion = if i == periods {
      periodic_principal + principal_remainder
    } else {
      periodic_principal
    }

    // Calculate interest portion for this period
    let interest_portion = round_ratio(
      remaining,
      rate_numerator,
      rate_denominator,
      RoundingMode::HalfEven,
    )

    let total_payment = principal_portion + interest_portion
    remaining = remaining - principal_portion

    schedule.push({
      period: i,
      payment: { amount: total_payment, currency: principal.currency },
      principal: { amount: principal_portion, currency: principal.currency },
      interest: { amount: interest_portion, currency: principal.currency },
      remaining_balance: { amount: remaining, currency: principal.currency },
    })
  }

  schedule
}

///|
/// Generates an amortization schedule for a loan using the Equal Installment (Annuity) method.
/// Uses a scaled integer representation to calculate periodic annuity factors.
pub fn generate_equal_installment_schedule(
  principal : Money,
  rate_numerator : Int64,
  rate_denominator : Int64,
  periods : Int,
) -> Array[LoanPayment] {
  if periods <= 0 {
    abort("Loan periods must be positive")
  }

  // Calculate periodic PMT = Principal * [R * (1+R)^N] / [(1+R)^N - 1]
  // We can simulate the compound rate (1+R)^N with high precision scaling factor.
  let scale = 1000000000L // 10^9 scaling
  let mut compound = scale
  for i = 0; i < periods; i = i + 1 {
    compound = round_ratio(
      compound,
      rate_denominator + rate_numerator,
      rate_denominator,
      RoundingMode::HalfEven,
    )
  }

  // numerator = R * (1+R)^N * Principal
  // denominator = (1+R)^N - 1
  // PMT_amount = round_ratio(Principal, R_scaled * compound, (compound - scale) * rate_denominator, HalfEven)
  let rate_scaled_compound = rate_numerator * compound
  let comp_minus_scale_rate_den = (compound - scale) * rate_denominator

  let pmt_amount = round_ratio(
    principal.amount,
    rate_scaled_compound,
    comp_minus_scale_rate_den,
    RoundingMode::HalfEven,
  )

  let schedule = []
  let mut remaining = principal.amount

  for i = 1; i <= periods; i = i + 1 {
    let interest_portion = round_ratio(
      remaining,
      rate_numerator,
      rate_denominator,
      RoundingMode::HalfEven,
    )

    let principal_portion = if i == periods {
      remaining
    } else {
      let mut p = pmt_amount - interest_portion
      if p > remaining {
        p = remaining
      }
      p
    }

    let actual_payment = principal_portion + interest_portion
    remaining = remaining - principal_portion

    schedule.push({
      period: i,
      payment: { amount: actual_payment, currency: principal.currency },
      principal: { amount: principal_portion, currency: principal.currency },
      interest: { amount: interest_portion, currency: principal.currency },
      remaining_balance: { amount: remaining, currency: principal.currency },
    })
  }

  schedule
}

///|
/// Calculates progressive income tax based on a list of tax brackets.
/// Brackets are expected to be sorted by limit in ascending order.
/// Each bracket defines: `(limit: Int64, rate_num: Int64, rate_den: Int64)`.
/// Where `limit` is the upper limit of that bracket in minor currency units (e.g. cents).
pub fn calculate_progressive_tax(
  income : Money,
  brackets : Array[(Int64, Int64, Int64)],
) -> Money {
  if income.amount <= 0L {
    return { amount: 0L, currency: income.currency }
  }

  let mut tax_accum = 0L
  let mut previous_limit = 0L

  for bracket in brackets {
    let (limit, rate_num, rate_den) = bracket
    if income.amount > limit {
      let taxable_in_bracket = limit - previous_limit
      tax_accum = tax_accum +
        round_ratio(
          taxable_in_bracket,
          rate_num,
          rate_den,
          RoundingMode::HalfEven,
        )
      previous_limit = limit
    } else {
      let taxable_in_bracket = income.amount - previous_limit
      tax_accum = tax_accum +
        round_ratio(
          taxable_in_bracket,
          rate_num,
          rate_den,
          RoundingMode::HalfEven,
        )
      previous_limit = income.amount
      break
    }
  }

  // If income exceeds the last bracket limit, tax the remainder at the last bracket rate
  if income.amount > previous_limit && brackets.length() > 0 {
    let (_, last_rate_num, last_rate_den) = brackets[brackets.length() - 1]
    let remainder = income.amount - previous_limit
    tax_accum = tax_accum +
      round_ratio(
        remainder,
        last_rate_num,
        last_rate_den,
        RoundingMode::HalfEven,
      )
  }

  { amount: tax_accum, currency: income.currency }
}

///|
/// Computes Value Added Tax (VAT) or Goods and Services Tax (GST) for a taxable item.
pub fn calculate_vat(
  net_price : Money,
  tax_rate_num : Int64,
  tax_rate_den : Int64,
) -> Money {
  let vat_amount = round_ratio(
    net_price.amount,
    tax_rate_num,
    tax_rate_den,
    RoundingMode::HalfEven,
  )
  { amount: vat_amount, currency: net_price.currency }
}

///|
/// Calculates tiered bulk discount.
/// Tier thresholds specify limits, and discount rate numerators / denominators.
/// Thresholds are: `Array[(threshold_amount: Int64, disc_num: Int64, disc_den: Int64)]`.
pub fn calculate_tiered_discount(
  subtotal : Money,
  tiers : Array[(Int64, Int64, Int64)],
) -> Money {
  let mut active_num = 0L
  let mut active_den = 1L

  for tier in tiers {
    let (threshold, num, den) = tier
    if subtotal.amount >= threshold {
      active_num = num
      active_den = den
    }
  }

  let discount_amount = round_ratio(
    subtotal.amount,
    active_num,
    active_den,
    RoundingMode::HalfEven,
  )
  { amount: discount_amount, currency: subtotal.currency }
}
