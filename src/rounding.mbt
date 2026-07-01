///|
/// RoundingMode defines the standard rounding modes used in financial and mathematical computations.
pub(all) enum RoundingMode {
  HalfUp // Rounds towards the nearest neighbor unless both neighbors are equidistant, in which case round up.
  HalfDown // Rounds towards the nearest neighbor unless both neighbors are equidistant, in which case round down.
  HalfEven // Rounds towards the nearest neighbor unless both neighbors are equidistant, in which case round to the even neighbor. (Bankers' Rounding)
  Ceiling // Rounds towards positive infinity.
  Floor // Rounds towards negative infinity.
  Up // Rounds away from zero.
  Down // Rounds towards zero (truncation).
} derive(Eq, Debug, Compare)

///|
/// Performs division of a product `(n * num) / den` using a specified RoundingMode.
/// This prevents any intermediate precision loss and is critical for accurate currency calculations.
/// 
/// Parameters:
/// - `n`: The base value.
/// - `num`: The multiplier (numerator).
/// - `den`: The divisor (denominator).
/// - `mode`: The RoundingMode to use.
/// 
/// Returns the rounded Int64 result.
pub fn round_ratio(
  n : Int64,
  num : Int64,
  den : Int64,
  mode : RoundingMode,
) -> Int64 {
  if den == 0L {
    abort("Division by zero in round_ratio")
  }

  let val = n * num
  let q = val / den
  let r = val % den

  if r == 0L {
    return q
  }

  // Normalize signs so that denominator is positive
  let (real_q, real_r, real_den) = if den < 0L {
    (-q, -r, -den)
  } else {
    (q, r, den)
  }

  // Decide whether to round up (away from zero, or towards positive infinity depending on mode)
  let increment = match mode {
    RoundingMode::Down => false
    RoundingMode::Up => true
    RoundingMode::Ceiling => real_r > 0L
    RoundingMode::Floor => real_r < 0L
    RoundingMode::HalfUp => {
      let abs_r = if real_r < 0L { -real_r } else { real_r }
      let double_abs_r = abs_r * 2L
      if double_abs_r > real_den {
        true
      } else if double_abs_r == real_den {
        // Halfway case: round up
        true
      } else {
        false
      }
    }
    RoundingMode::HalfDown => {
      let abs_r = if real_r < 0L { -real_r } else { real_r }
      let double_abs_r = abs_r * 2L
      if double_abs_r > real_den {
        true
      } else {
        false
      }
    }
    RoundingMode::HalfEven => {
      let abs_r = if real_r < 0L { -real_r } else { real_r }
      let double_abs_r = abs_r * 2L
      if double_abs_r > real_den {
        true
      } else if double_abs_r == real_den {
        // Round to even
        real_q % 2L != 0L
      } else {
        false
      }
    }
  }

  if increment {
    if real_r > 0L {
      real_q + 1L
    } else {
      real_q - 1L
    }
  } else {
    real_q
  }
}
