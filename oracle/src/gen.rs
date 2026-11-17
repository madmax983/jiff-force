//! Seeded generators for the inputs that several topics share: dates, times,
//! spans, durations and timestamps. Each mixes hand picked edge cases with
//! values spread over the type's whole range.

use anyhow::Result;
use jiff::civil::{Date, Time};
use jiff::{SignedDuration, Span, Timestamp};

use crate::rng::Rng;

/// The largest magnitude each span unit may hold, largest unit first (the
/// order of [`crate::text::span_fields`]).
pub const SPAN_LIMITS: [i64; 10] = [
    19_998,
    239_976,
    1_043_497,
    7_304_484,
    175_307_616,
    10_518_456_960,
    631_107_417_600,
    631_107_417_600_000,
    631_107_417_600_000_000,
    i64::MAX,
];

/// Indexes into [`SPAN_LIMITS`] of the calendar units: years through days.
pub const CALENDAR_UNITS: [usize; 4] = [0, 1, 2, 3];
/// Indexes into [`SPAN_LIMITS`] of the time units: hours through nanoseconds.
pub const TIME_UNITS: [usize; 6] = [4, 5, 6, 7, 8, 9];
/// Indexes into [`SPAN_LIMITS`] of every unit.
pub const ALL_UNITS: [usize; 10] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

const DATE_EDGES: &[(i16, i8, i8)] = &[
    (-9999, 1, 1),
    (-9999, 1, 2),
    (-9999, 12, 31),
    (9999, 12, 31),
    (9999, 12, 30),
    (9999, 1, 1),
    (0, 1, 1),
    (0, 2, 29),
    (-1, 12, 31),
    (1, 1, 1),
    (1969, 12, 31),
    (1970, 1, 1),
    (1900, 2, 28),
    (2000, 2, 29),
    (2023, 1, 31),
    (2023, 2, 28),
    (2023, 12, 31),
    (2024, 1, 31),
    (2024, 2, 29),
    (2024, 3, 31),
    (2024, 12, 30),
    (2024, 12, 31),
    (2025, 1, 1),
    (2026, 1, 1),
    (2020, 12, 31),
    (2021, 1, 3),
];

const TIME_EDGES: &[(i8, i8, i8, i32)] = &[
    (0, 0, 0, 0),
    (0, 0, 0, 1),
    (0, 0, 0, 999_999_999),
    (0, 0, 1, 0),
    (0, 59, 59, 999_999_999),
    (11, 59, 59, 999_999_999),
    (12, 0, 0, 0),
    (12, 30, 0, 0),
    (12, 29, 59, 999_999_999),
    (12, 30, 30, 500_000_000),
    (23, 0, 0, 0),
    (23, 30, 0, 0),
    (23, 59, 59, 0),
    (23, 59, 59, 499_999_999),
    (23, 59, 59, 500_000_000),
    (23, 59, 59, 999_999_000),
    (23, 59, 59, 999_999_998),
    (23, 59, 59, 999_999_999),
];

const SUBSEC_EDGES: &[i32] = &[
    0,
    1,
    999,
    1_000,
    500_000,
    999_999,
    1_000_000,
    123_456_789,
    499_999_999,
    500_000_000,
    500_000_001,
    999_000_000,
    999_999_000,
    999_999_999,
];

const DURATION_SECOND_EDGES: &[i64] = &[
    0,
    1,
    -1,
    59,
    60,
    3_599,
    3_600,
    -3_600,
    43_200,
    86_399,
    86_400,
    -86_400,
    86_401,
    172_800,
    31_536_000,
    93_599,
    -93_599,
    93_600,
    631_107_417_600,
    -631_107_417_600,
    i64::MAX,
    i64::MIN,
    i64::MAX - 1,
    i64::MIN + 1,
];

const TIMESTAMP_SECOND_EDGES: &[i64] = &[
    0,
    1,
    -1,
    -377_705_023_201,
    -377_705_023_200,
    253_402_207_200,
    253_402_207_199,
    86_400,
    -86_400,
    951_782_400,
    1_709_164_800,
    2_147_483_647,
    2_147_483_648,
    -2_147_483_648,
    4_102_444_800,
    -62_135_596_800,
];

/// A number of sub-second nanoseconds: often zero or an edge, otherwise
/// uniform at millisecond, microsecond or nanosecond precision.
pub fn subsec(rng: &mut Rng) -> i32 {
    let nanos = match rng.range(0, 9) {
        0..=2 => 0,
        3..=4 => i64::from(*rng.pick(SUBSEC_EDGES)),
        5 => rng.range(0, 999) * 1_000_000,
        6 => rng.range(0, 999_999) * 1_000,
        _ => rng.range(0, 999_999_999),
    };
    i32::try_from(nanos).unwrap_or(0)
}

/// A civil date: an edge, anywhere in Jiff's range, or in the last century.
pub fn date(rng: &mut Rng) -> Result<Date> {
    let (lo, hi) = match rng.range(0, 9) {
        0..=1 => {
            let &(year, month, day) = rng.pick(DATE_EDGES);
            return Ok(Date::new(year, month, day)?);
        }
        2..=5 => (-9999, 9999),
        _ => (1900, 2100),
    };
    let year = i16::try_from(rng.range(lo, hi))?;
    let month = i8::try_from(rng.range(1, 12))?;
    let first = Date::new(year, month, 1)?;
    // Favour the ends of the month, where clamping happens.
    let last = i64::from(first.days_in_month());
    let day = if rng.range(0, 3) == 0 {
        rng.range(last - 3, last)
    } else {
        rng.range(1, last)
    };
    Ok(Date::new(year, month, i8::try_from(day)?)?)
}

/// A civil time: an edge, or uniform over the day.
pub fn time(rng: &mut Rng) -> Result<Time> {
    if rng.range(0, 4) == 0 {
        let &(hour, minute, second, nanos) = rng.pick(TIME_EDGES);
        return Ok(Time::new(hour, minute, second, nanos)?);
    }
    Ok(Time::new(
        i8::try_from(rng.range(0, 23))?,
        i8::try_from(rng.range(0, 59))?,
        i8::try_from(rng.range(0, 59))?,
        subsec(rng),
    )?)
}

/// A magnitude in `1..=limit`: usually small, sometimes anywhere in range,
/// sometimes at or just under the limit.
pub fn magnitude(rng: &mut Rng, limit: i64) -> i64 {
    match rng.range(0, 24) {
        0..=11 => rng.range(1, limit.min(30)),
        12..=18 => rng.range(1, limit.min(5_000)),
        19..=21 => rng.range(1, limit),
        _ => limit - rng.range(0, 2).min(limit - 1),
    }
}

/// Sets the unit at `index` (0 is years, 9 is nanoseconds) of a span.
pub fn set_unit(span: Span, index: usize, value: i64) -> Result<Span, jiff::Error> {
    match index {
        0 => span.try_years(value),
        1 => span.try_months(value),
        2 => span.try_weeks(value),
        3 => span.try_days(value),
        4 => span.try_hours(value),
        5 => span.try_minutes(value),
        6 => span.try_seconds(value),
        7 => span.try_milliseconds(value),
        8 => span.try_microseconds(value),
        _ => span.try_nanoseconds(value),
    }
}

/// The units of a span as `(index, value)` pairs, where index 0 is years and
/// index 9 is nanoseconds. This is how hand written cases spell a span.
pub type UnitValues = [(usize, i64)];

/// The span with the given units, set in order.
pub fn span_of(units: &UnitValues) -> Result<Span> {
    let mut span = Span::new();
    for &(index, value) in units {
        span = set_unit(span, index, value)?;
    }
    Ok(span)
}

/// A span with between one and `max_units` of the units in `allowed`, all of
/// one sign, each no larger than `cap` (and never beyond the unit's limit).
pub fn span(rng: &mut Rng, allowed: &[usize], max_units: i64, cap: i64) -> Result<Span> {
    let negative = rng.range(0, 2) == 0;
    let count = rng.range(1, max_units);
    let mut span = Span::new();
    for _ in 0..count {
        let index = *rng.pick(allowed);
        let value = magnitude(rng, SPAN_LIMITS[index].min(cap));
        span = set_unit(span, index, if negative { -value } else { value })?;
    }
    Ok(span)
}

/// A signed duration whose two components agree in sign: an edge, or a
/// magnitude drawn from one of several scales from nanoseconds to `i64::MAX`
/// seconds.
pub fn duration(rng: &mut Rng) -> SignedDuration {
    let secs = match rng.range(0, 9) {
        0..=1 => *rng.pick(DURATION_SECOND_EDGES),
        2 => 0,
        3..=4 => rng.range(-200_000, 200_000),
        5..=6 => rng.range(-40_000_000, 40_000_000),
        7 => rng.range(-700_000_000_000, 700_000_000_000),
        8 => rng.range(-10_000_000_000_000, 10_000_000_000_000),
        _ => rng.range(i64::MIN, i64::MAX),
    };
    let nanos = subsec(rng);
    let negative = secs < 0 || (secs == 0 && rng.range(0, 1) == 0);
    SignedDuration::new(secs, if negative { -nanos } else { nanos })
}

/// A timestamp: an edge, in the Unix era, or anywhere in Jiff's range.
pub fn timestamp(rng: &mut Rng) -> Result<Timestamp> {
    let min = Timestamp::MIN.as_second();
    let max = Timestamp::MAX.as_second();
    let second = match rng.range(0, 9) {
        0..=1 => *rng.pick(TIMESTAMP_SECOND_EDGES),
        2..=5 => rng.range(-1_000_000_000, 4_200_000_000),
        _ => rng.range(min, max),
    };
    let nanos = subsec(rng);
    // The fraction takes the sign of the seconds, except that nothing lies
    // before the minimum second.
    let nanos = if second < 0 && second != min {
        -nanos
    } else {
        nanos
    };
    Ok(Timestamp::new(second, nanos)?)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::text;

    #[test]
    fn generated_values_stay_in_range() -> Result<()> {
        let mut rng = Rng::new(7);
        for _ in 0..2_000 {
            date(&mut rng)?;
            time(&mut rng)?;
            timestamp(&mut rng)?;
            let nanos = subsec(&mut rng);
            assert!((0..=999_999_999).contains(&nanos));
            let d = duration(&mut rng);
            assert!(d.as_secs().signum() * i64::from(d.subsec_nanos().signum()) >= 0);
        }
        Ok(())
    }

    #[test]
    fn magnitudes_are_positive_and_within_the_limit() {
        let mut rng = Rng::new(11);
        for limit in [1, 2, 30, 19_998, i64::MAX] {
            for _ in 0..500 {
                let value = magnitude(&mut rng, limit);
                assert!((1..=limit).contains(&value), "{value} for limit {limit}");
            }
        }
    }

    #[test]
    fn spans_use_only_the_allowed_units_and_one_sign() -> Result<()> {
        let mut rng = Rng::new(13);
        for _ in 0..500 {
            let s = span(&mut rng, &TIME_UNITS, 3, i64::MAX)?;
            let fields = text::span_fields(&s);
            assert!(fields[..4].iter().all(|v| *v == 0));
            assert!(fields.iter().all(|v| *v >= 0) || fields.iter().all(|v| *v <= 0));
            assert!(!s.is_zero());
        }
        Ok(())
    }

    #[test]
    fn span_of_sets_units_in_order() -> Result<()> {
        assert!(span_of(&[])?.is_zero());
        assert_eq!(text::span(&span_of(&[(0, 1), (9, 2)])?), "1y 2ns");
        // A later value for the same unit replaces the earlier one.
        assert_eq!(text::span(&span_of(&[(4, 1), (4, 3)])?), "3h");
        assert!(span_of(&[(0, 19_999)]).is_err());
        Ok(())
    }

    #[test]
    fn set_unit_reaches_every_unit_and_checks_its_limit() -> Result<()> {
        for (index, limit) in SPAN_LIMITS.into_iter().enumerate() {
            let s = set_unit(Span::new(), index, limit)?;
            assert_eq!(text::span_fields(&s)[index], limit);
            if limit != i64::MAX {
                assert!(set_unit(Span::new(), index, limit + 1).is_err());
            }
        }
        Ok(())
    }
}
