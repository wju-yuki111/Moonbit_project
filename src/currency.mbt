///|
/// Currency represents an ISO-4217 standard currency definition.
/// It contains a `code` for string identification and an `exponent`
/// defining the number of minor units (e.g., 2 for USD cents).
pub struct Currency {
  code : String
  exponent : Int
} derive(Eq, Compare)

///|
/// United States Dollar (USD), exponent: 2
pub let usd : Currency = { code: "USD", exponent: 2 }

///|
/// Chinese Yuan (CNY), exponent: 2
pub let cny : Currency = { code: "CNY", exponent: 2 }

///|
/// Euro (EUR), exponent: 2
pub let eur : Currency = { code: "EUR", exponent: 2 }

///|
/// Japanese Yen (JPY), exponent: 0
pub let jpy : Currency = { code: "JPY", exponent: 0 }
