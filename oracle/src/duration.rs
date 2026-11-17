//! Vectors for `SignedDuration`: arithmetic, comparison, printing and rounding.

use jiff::{RoundMode, SignedDuration, SignedDurationRound, Unit};

use crate::rng::Rng;

pub const ARITHMETIC_COLUMNS: &str = "aSecs,aNanos|bSecs,bNanos|a + b|a - b|factor|a * factor|\
     divisor|a / divisor|compare(a, b)|a as text  (results are secs,nanos or ERR)";

pub const ROUND_COLUMNS: &str =
    "secs,nanos|smallest unit|increment|mode|rounded as secs,nanos or ERR";

const SECONDS: &[i64] = &[
    0,
    1,
    -1,
    59,
    60,
    -60,
    3_599,
    3_600,
    86_399,
    86_400,
    -86_400,
    631_107_417_600,
    -631_107_417_600,
    i64::MAX,
    i64::MIN,
    i64::MAX - 1,
    i64::MIN + 1,
];

const NANOS: &[i32] = &[0, 1, 499_999_999, 500_000_000, 500_000_001, 999_999_999];

const FACTORS: &[i32] = &[
    0,
    1,
    -1,
    2,
    -2,
    3,
    7,
    60,
    1_000,
    1_000_000_000,
    i32::MAX,
    i32::MIN,
];

const UNITS: &[(Unit, &str)] = &[
    (Unit::Nanosecond, "NANOSECOND"),
    (Unit::Microsecond, "MICROSECOND"),
    (Unit::Millisecond, "MILLISECOND"),
    (Unit::Second, "SECOND"),
    (Unit::Minute, "MINUTE"),
    (Unit::Hour, "HOUR"),
];

const MODES: &[(RoundMode, &str)] = &[
    (RoundMode::Ceil, "CEIL"),
    (RoundMode::Floor, "FLOOR"),
    (RoundMode::Expand, "EXPAND"),
    (RoundMode::Trunc, "TRUNC"),
    (RoundMode::HalfCeil, "HALF_CEIL"),
    (RoundMode::HalfFloor, "HALF_FLOOR"),
    (RoundMode::HalfExpand, "HALF_EXPAND"),
    (RoundMode::HalfTrunc, "HALF_TRUNC"),
    (RoundMode::HalfEven, "HALF_EVEN"),
];

const INCREMENTS: &[i64] = &[1, 2, 5, 7, 15, 30, 100, 1_000];

/// A duration whose two components agree in sign, as `SignedDuration` requires.
fn arbitrary(rng: &mut Rng) -> SignedDuration {
    let secs = if rng.range(0, 3) == 0 {
        *rng.pick(SECONDS)
    } else {
        let magnitude = *rng.pick(&[1_000_i64, 1_000_000, 1_000_000_000_000, i64::MAX]);
        rng.range(-magnitude, magnitude)
    };
    let nanos = if rng.range(0, 2) == 0 {
        *rng.pick(NANOS)
    } else {
        i32::try_from(rng.range(0, 999_999_999)).unwrap_or(0)
    };
    let nanos = if secs < 0 { -nanos } else { nanos };
    SignedDuration::new(secs, nanos)
}

fn parts(duration: SignedDuration) -> String {
    format!("{},{}", duration.as_secs(), duration.subsec_nanos())
}

fn optional(duration: Option<SignedDuration>) -> String {
    duration.map_or_else(|| "ERR".to_owned(), parts)
}

pub fn arithmetic_rows(rng: &mut Rng) -> Vec<String> {
    (0..300)
        .map(|_| {
            let a = arbitrary(rng);
            let b = arbitrary(rng);
            let factor = *rng.pick(FACTORS);
            let divisor = *rng.pick(&FACTORS[1..]);
            format!(
                "{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
                parts(a),
                parts(b),
                optional(a.checked_add(b)),
                optional(a.checked_sub(b)),
                factor,
                optional(a.checked_mul(factor)),
                divisor,
                optional(a.checked_div(divisor)),
                a.cmp(&b) as i8,
                a,
            )
        })
        .collect()
}

pub fn round_rows(rng: &mut Rng) -> Vec<String> {
    (0..300)
        .map(|_| {
            let duration = arbitrary(rng);
            let &(unit, unit_name) = rng.pick(UNITS);
            let &(mode, mode_name) = rng.pick(MODES);
            let increment = *rng.pick(INCREMENTS);
            let options = SignedDurationRound::new()
                .smallest(unit)
                .increment(increment)
                .mode(mode);
            let rounded = duration.round(options).ok();
            format!(
                "{}|{unit_name}|{increment}|{mode_name}|{}",
                parts(duration),
                optional(rounded)
            )
        })
        .collect()
}
