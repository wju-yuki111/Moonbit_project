///|
/// Exchange rate structures and multi-currency conversion registry.
/// Supports fractional exchange rates to prevent intermediate rounding losses.

///|
/// Represents a precise exchange rate from a base currency to a target currency.
/// Exists in the form: 1 Base Currency = (rate_numerator / rate_denominator) Target Currency.
pub(all) struct ExchangeRate {
  base_currency : Currency
  target_currency : Currency
  rate_numerator : Int64
  rate_denominator : Int64
} derive(Eq, Debug, Compare)

///|
/// Creates a new ExchangeRate instance.
pub fn ExchangeRate::new(
  base : Currency,
  target : Currency,
  num : Int64,
  den : Int64,
) -> ExchangeRate {
  if den <= 0L {
    abort("Rate denominator must be positive")
  }
  if num <= 0L {
    abort("Rate numerator must be positive")
  }
  {
    base_currency: base,
    target_currency: target,
    rate_numerator: num,
    rate_denominator: den,
  }
}

///|
/// A registry containing multiple exchange rates and offering path-finding conversion capabilities.
pub(all) struct ExchangeRegistry {
  rates : Array[ExchangeRate]
}

///|
/// Creates an empty ExchangeRegistry.
pub fn ExchangeRegistry::new() -> ExchangeRegistry {
  { rates: [] }
}

///|
/// Adds an exchange rate to the registry. If a rate for the same pair already exists, it is overwritten.
pub fn ExchangeRegistry::add_rate(
  self : ExchangeRegistry,
  rate : ExchangeRate,
) -> Unit {
  // Remove existing duplicate rate if any
  let mut found_idx = -1
  for i = 0; i < self.rates.length(); i = i + 1 {
    if self.rates[i].base_currency.code == rate.base_currency.code &&
      self.rates[i].target_currency.code == rate.target_currency.code {
      found_idx = i
      break
    }
  }
  if found_idx >= 0 {
    self.rates[found_idx] = rate
  } else {
    self.rates.push(rate)
  }

  // Register reciprocal rate automatically if not already present
  let reciprocal_exists = self.rates
    .iter()
    .any(fn(r) {
      r.base_currency.code == rate.target_currency.code &&
      r.target_currency.code == rate.base_currency.code
    })
  if !reciprocal_exists {
    self.rates.push({
      base_currency: rate.target_currency,
      target_currency: rate.base_currency,
      rate_numerator: rate.rate_denominator,
      rate_denominator: rate.rate_numerator,
    })
  }
}

///|
/// Finds a direct rate path from base to target.
pub fn ExchangeRegistry::get_direct_rate(
  self : ExchangeRegistry,
  base : String,
  target : String,
) -> ExchangeRate? {
  for rate in self.rates {
    if rate.base_currency.code == base && rate.target_currency.code == target {
      return Some(rate)
    }
  }
  None
}

///|
/// Helper to calculate 10^n
fn power_of_10(n : Int) -> Int64 {
  let mut res = 1L
  let limit = if n < 0 { -n } else { n }
  for i = 0; i < limit; i = i + 1 {
    res = res * 10L
  }
  res
}

///|
/// Finds a path of conversion rates from current currency to target using Depth First Search (DFS).
/// Returns an array of rates representing the chain of conversions.
pub fn ExchangeRegistry::find_conversion_path(
  self : ExchangeRegistry,
  current : String,
  target : String,
  visited : Array[String],
) -> Array[ExchangeRate]? {
  if current == target {
    return Some([])
  }

  visited.push(current)

  // Try direct route first
  match self.get_direct_rate(current, target) {
    Some(rate) => {
      let _ = visited.pop()
      return Some([rate])
    }
    None => ()
  }

  // Try neighbors
  for rate in self.rates {
    if rate.base_currency.code == current {
      let next_code = rate.target_currency.code
      if !visited.contains(next_code) {
        match self.find_conversion_path(next_code, target, visited) {
          Some(subpath) => {
            let path = [rate]
            path.push_iter(subpath.iter())
            let _ = visited.pop()
            return Some(path)
          }
          None => ()
        }
      }
    }
  }

  let _ = visited.pop()
  None
}

///|
/// Converts a Money amount to a target Currency using the rates registered.
/// Employs multi-stage pathfinding conversion and applies safe scaling adjustments for minor unit exponents.
pub fn ExchangeRegistry::convert(
  self : ExchangeRegistry,
  money : Money,
  target : Currency,
  mode : RoundingMode,
) -> Money {
  if money.currency.code == target.code {
    return money
  }

  let path = match
    self.find_conversion_path(money.currency.code, target.code, []) {
    Some(p) => p
    None =>
      abort(
        "No exchange rate path found from " +
        money.currency.code +
        " to " +
        target.code,
      )
  }

  let mut current_amount = money.amount

  for rate in path {
    let base_exp = rate.base_currency.exponent
    let target_exp = rate.target_currency.exponent

    // Scale adjustment factor = 10^(target_exponent - base_exponent)
    let exp_diff = target_exp - base_exp
    let mut num = rate.rate_numerator
    let mut den = rate.rate_denominator

    if exp_diff > 0 {
      num = num * power_of_10(exp_diff)
    } else if exp_diff < 0 {
      den = den * power_of_10(-exp_diff)
    }

    current_amount = round_ratio(current_amount, num, den, mode)
  }

  { amount: current_amount, currency: target }
}
