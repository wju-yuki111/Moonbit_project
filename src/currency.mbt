///|
/// Currency represents an ISO-4217 standard currency definition.
/// It contains a `code` for string identification, an `exponent`
/// defining the number of minor units (e.g., 2 for USD cents),
/// and international metadata such as English name, symbol, and numeric code.
pub(all) struct Currency {
  code : String
  exponent : Int
  name : String
  symbol : String
  numeric_code : Int
} derive(Eq, Compare, Debug)
