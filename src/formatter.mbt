///|
/// Formatter and Parser for internationalized currency display.
/// Handles thousand grouping, decimal separators, symbol placement, and negative representations.

///|
/// SymbolPosition determines where the currency symbol (e.g. $, €) is positioned in the formatted string.
pub enum SymbolPosition {
  Prefix // e.g., "$1,234.56"
  Suffix // e.g., "1,234.56$"
  PrefixSpace // e.g., "USD 1,234.56"
  SuffixSpace // e.g., "1.234,56 €"
} derive(Eq, Debug, Compare)

///|
/// Locale configuration specifying formatting characters and symbol positioning rules.
pub struct Locale {
  thousand_separator : String
  decimal_separator : String
  symbol_position : SymbolPosition
} derive(Eq, Debug, Compare)

///|
/// Standard US Locale config. (e.g. $1,000.00)
pub fn Locale::us() -> Locale {
  {
    thousand_separator: ",",
    decimal_separator: ".",
    symbol_position: SymbolPosition::Prefix,
  }
}

///|
/// Standard Chinese Locale config. (e.g. ¥1,000.00)
pub fn Locale::cn() -> Locale {
  {
    thousand_separator: ",",
    decimal_separator: ".",
    symbol_position: SymbolPosition::Prefix,
  }
}

///|
/// German/Euro Zone Locale config. (e.g. 1.000,00 €)
pub fn Locale::de() -> Locale {
  {
    thousand_separator: ".",
    decimal_separator: ",",
    symbol_position: SymbolPosition::SuffixSpace,
  }
}

///|
/// French Locale config. (e.g. 1 000,00 €)
pub fn Locale::fr() -> Locale {
  {
    thousand_separator: " ",
    decimal_separator: ",",
    symbol_position: SymbolPosition::SuffixSpace,
  }
}

///|
/// Helper to format the integer part of a number with grouping separators.
fn format_integer(val : Int64, sep : String) -> String {
  let s = val.to_string()
  let len = s.length()
  if len <= 3 {
    return s
  }
  let mut res = ""
  let mut count = 0
  for i = len - 1; i >= 0; i = i - 1 {
    if count == 3 && s[i] != '-' {
      res = sep + res
      count = 0
    }
    let char_val = s[i].to_int().unsafe_to_char()
    let char_str = String::make(1, char_val)
    res = char_str + res
    count = count + 1
  }
  res
}

///|
/// Helper to format the decimal part of a number, padding with zeros if necessary.
fn format_decimal(val : Int64, exponent : Int) -> String {
  let abs_val = if val < 0L { -val } else { val }
  let mut s = abs_val.to_string()
  let len = s.length()
  if len < exponent {
    let padding = exponent - len
    for i = 0; i < padding; i = i + 1 {
      s = "0" + s
    }
  }
  s
}

///|
/// Formats a Money structure into a string based on the given Locale and option to show symbols.
/// 
/// Parameters:
/// - `money`: The Money instance to format.
/// - `locale`: Formatting characters configuration.
/// - `use_symbol`: If true, displays the symbol (e.g. "$"); otherwise, displays the currency code (e.g. "USD").
pub fn Money::format(
  self : Money,
  locale : Locale,
  use_symbol : Bool,
) -> String {
  let base_unit = power_of_10(self.currency.exponent)
  let integer_part = self.amount / base_unit
  let decimal_part = self.amount % base_unit

  let formatted_int = format_integer(integer_part, locale.thousand_separator)
  let formatted_dec = if self.currency.exponent > 0 {
    locale.decimal_separator +
    format_decimal(decimal_part, self.currency.exponent)
  } else {
    ""
  }

  let num_str = if self.amount < 0L && !formatted_int.has_prefix("-") {
    "-" + formatted_int + formatted_dec
  } else {
    formatted_int + formatted_dec
  }

  let symbol = if use_symbol {
    get_currency_symbol(self.currency.code)
  } else {
    self.currency.code
  }

  let space = if use_symbol { "" } else { " " }

  match locale.symbol_position {
    SymbolPosition::Prefix => symbol + space + num_str
    SymbolPosition::Suffix => num_str + space + symbol
    SymbolPosition::PrefixSpace => symbol + " " + num_str
    SymbolPosition::SuffixSpace => num_str + " " + symbol
  }
}

///|
/// Safe wrapper around the deprecated String::substring to localize warning suppression.
fn safe_substring(s : String, start : Int, end : Int) -> String {
  s.substring(start~, end~)
}

///|
/// Parses a string representation of money back into a Money instance.
/// Automatically handles formatting characters, signs, and ignores non-numeric characters based on locale rules.
/// 
/// Parameters:
/// - `s`: The input string to parse (e.g., "$1,234.56", "-1.000,00 €").
/// - `currency`: The expected Currency structure.
/// - `locale`: The Locale configuration used to interpret thousand and decimal separators.
pub fn Money::parse(s : String, currency : Currency, locale : Locale) -> Money? {
  let mut is_negative = false
  let mut int_digits = ""
  let mut dec_digits = ""
  let mut seen_decimal = false

  // We scan char-by-char
  for i = 0; i < s.length(); i = i + 1 {
    let raw_c = s[i]
    let c = raw_c.to_int().unsafe_to_char()
    let char_str = String::make(1, c)
    if c == '-' || c == '(' {
      is_negative = true
    } else if c >= '0' && c <= '9' {
      if seen_decimal {
        dec_digits = dec_digits + char_str
      } else {
        int_digits = int_digits + char_str
      }
    } else if char_str == locale.decimal_separator {
      seen_decimal = true
    }
  }

  if int_digits.length() == 0 && dec_digits.length() == 0 {
    return None
  }

  // Parse integer part
  let parsed_int = if int_digits.length() > 0 {
    @string.parse_int64(int_digits) catch {
      _ => return None
    }
  } else {
    0L
  }

  // Normalize decimal part to match currency exponent
  let mut parsed_dec = 0L
  if currency.exponent > 0 {
    let mut normalized_dec_str = dec_digits
    if normalized_dec_str.length() < currency.exponent {
      let diff = currency.exponent - normalized_dec_str.length()
      for i = 0; i < diff; i = i + 1 {
        normalized_dec_str = normalized_dec_str + "0"
      }
    } else if normalized_dec_str.length() > currency.exponent {
      normalized_dec_str = safe_substring(
        normalized_dec_str,
        0,
        currency.exponent,
      )
    }
    try {
      parsed_dec = @string.parse_int64(normalized_dec_str)
    } catch {
      _ => return None
    }
  }

  let base_unit = power_of_10(currency.exponent)
  let mut total_amount = parsed_int * base_unit + parsed_dec
  if is_negative {
    total_amount = -total_amount
  }

  Some({ amount: total_amount, currency })
}
