//! Vectors for `Offset`: construction, printing, arithmetic and rounding.

use anyhow::Result;
use jiff::tz::{Offset, OffsetRound};
use jiff::{SignedDuration, Span};

use crate::gen::{self, UnitValues};
use crate::rng::Rng;
use crate::text::{self, or_err, row, MODES, UNITS};

pub const CONSTRUCT_COLUMNS: &str = "constructor (HOURS, SECONDS or DURATION)|argument \
     (a count, or secs,nanos)|offset in seconds or ERR|text|negated offset in seconds|signum  \
     (a row whose offset is ERR stops there)";

pub const ARITHMETIC_COLUMNS: &str = "offset|span|offset + span|offset - span|\
     saturating sum|saturating difference|duration as secs,nanos|offset + duration|\
     offset - duration|saturating sum|saturating difference|other offset|\
     offset.until(other)|offset.since(other)|offset.durationUntil(other) as secs,nanos  \
     (offsets are seconds; ERR = error)";

pub const ROUND_COLUMNS: &str =
    "offset in seconds|smallest unit|increment|mode|rounded offset in seconds or ERR";

const MAX_SECONDS: i32 = 93_599;

/// Offsets worth checking by name: UTC, a second either side, half minutes
/// and half hours (the ties when rounding), real offsets and the limits.
const SECOND_EDGES: &[i32] = &[
    0, 1, -1, 29, 30, 31, -29, -30, -31, 59, 60, 61, -60, 90, -90, 899, 900, 1_799, 1_800, 1_801,
    -1_800, 2_700, 3_599, 3_600, 3_601, -3_600, 5_400, -5_400, 9_000, -9_000, -18_000, -17_762,
    19_800, 20_700, 34_200, 45_900, 50_400, -43_200, 86_399, 86_400, -86_400, 91_800, -91_800,
    93_569, 93_570, 93_598, 93_599, -93_569, -93_570, -93_598, -93_599,
];

/// The increments tried for each smallest unit, by the unit's index in
/// [`UNITS`], from nanoseconds (which Jiff rejects outright) up to hours.
const INCREMENTS: [&[i64]; 6] = [
    &[1, 1_000_000_000],
    &[1, 1_000_000],
    &[1, 1_000],
    &[1, 2, 5, 10, 15, 30, 45, 60, 90, 0, -1, 7, 3_600],
    &[1, 2, 5, 10, 15, 30, 45, 60, 90, 0, -1, 7, 1_440],
    &[1, 2, 3, 4, 6, 12, 24, 0, -1, 5, 13, 25, 26],
];

const HOUR_EDGES: [i8; 17] = [
    0,
    1,
    -1,
    5,
    -5,
    12,
    -12,
    14,
    24,
    -24,
    25,
    -25,
    26,
    -26,
    100,
    i8::MAX,
    i8::MIN,
];

/// Durations converted to an offset, which rounds them to the nearest second:
/// ties, the limits, and seconds that do not fit in 32 bits.
const DURATION_EDGES: [(i64, i32); 38] = [
    (0, 0),
    (0, 1),
    (0, -1),
    (0, 499_999_999),
    (0, 500_000_000),
    (0, 500_000_001),
    (0, -499_999_999),
    (0, -500_000_000),
    (0, -500_000_001),
    (0, 999_999_999),
    (0, -999_999_999),
    (1, 500_000_000),
    (-1, -500_000_000),
    (3_600, 0),
    (-3_600, 0),
    (19_800, 250_000_000),
    (-18_000, -750_000_000),
    (93_599, 0),
    (93_599, 499_999_999),
    (93_599, 500_000_000),
    (93_598, 500_000_000),
    (93_598, 999_999_999),
    (93_600, 0),
    (-93_599, 0),
    (-93_599, -499_999_999),
    (-93_599, -500_000_000),
    (-93_598, -500_000_000),
    (-93_600, 0),
    (i64::MAX, 0),
    (i64::MAX, 999_999_999),
    (i64::MIN, 0),
    (i64::MIN, -999_999_999),
    (2_147_483_647, 0),
    (2_147_483_648, 0),
    (-2_147_483_648, 0),
    (-2_147_483_649, 0),
    (4_294_967_296, 0),
    (4_294_967_296 + 3_600, 0),
];

/// Spans added to an offset: fractions of a second (which are dropped),
/// sums that reach the limits, and calendar units (which are rejected).
const ARITHMETIC_SPANS: &[&UnitValues] = &[
    &[],
    &[(6, 1)],
    &[(6, -1)],
    &[(5, 1)],
    &[(4, 1)],
    &[(4, -1)],
    &[(4, 25), (5, 59), (6, 59)],
    &[(4, -25), (5, -59), (6, -59)],
    &[(4, 26)],
    &[(4, 51), (5, 59), (6, 58)],
    &[(4, -51), (5, -59), (6, -58)],
    &[(6, 93_599)],
    &[(6, 93_600)],
    &[(6, 187_198)],
    &[(6, 187_199)],
    &[(7, 999)],
    &[(7, 1_000)],
    &[(7, 1_999)],
    &[(7, -1_999)],
    &[(9, 999_999_999)],
    &[(9, 1_000_000_000)],
    &[(6, 1), (9, 999_999_999)],
    &[(6, 1), (7, 500), (8, 500_000)],
    &[(3, 1)],
    &[(2, 1)],
    &[(1, 1)],
    &[(0, -1)],
    &[(3, 1), (4, 1)],
    &[(4, 175_307_616)],
    &[(9, i64::MAX)],
];

/// Durations added to an offset, with the same concerns.
const ARITHMETIC_DURATIONS: [(i64, i32); 24] = [
    (0, 0),
    (1, 0),
    (-1, 0),
    (0, 999_999_999),
    (0, -999_999_999),
    (1, 999_999_999),
    (-1, -999_999_999),
    (3_600, 0),
    (-3_600, 0),
    (93_599, 0),
    (93_599, 999_999_999),
    (93_600, 0),
    (-93_599, -999_999_999),
    (-93_600, 0),
    (187_198, 0),
    (187_199, 0),
    (-187_198, 0),
    (-187_199, 0),
    (i64::MAX, 999_999_999),
    (i64::MIN, -999_999_999),
    (i64::MIN, 0),
    (2_147_483_648, 0),
    (-2_147_483_649, 0),
    (4_294_967_296, 0),
];

fn construct_row(kind: &str, argument: String, result: Option<Offset>) -> String {
    let Some(offset) = result else {
        return row([kind.to_owned(), argument, text::ERR.to_owned()]);
    };
    row([
        kind.to_owned(),
        argument,
        text::offset(offset),
        offset.to_string(),
        text::offset(offset.negate()),
        offset.signum().to_string(),
    ])
}

pub fn construct_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();

    for hours in HOUR_EDGES {
        rows.push(construct_row(
            "HOURS",
            hours.to_string(),
            Offset::from_hours(hours).ok(),
        ));
    }
    for &seconds in SECOND_EDGES {
        rows.push(construct_row(
            "SECONDS",
            seconds.to_string(),
            Offset::from_seconds(seconds).ok(),
        ));
    }
    for seconds in [
        MAX_SECONDS + 1,
        -MAX_SECONDS - 1,
        100_000,
        i32::MAX,
        i32::MIN,
    ] {
        rows.push(construct_row(
            "SECONDS",
            seconds.to_string(),
            Offset::from_seconds(seconds).ok(),
        ));
    }
    for (secs, nanos) in DURATION_EDGES {
        let duration = SignedDuration::new(secs, nanos);
        rows.push(construct_row(
            "DURATION",
            text::duration(duration),
            Offset::try_from(duration).ok(),
        ));
    }
    while rows.len() < 300 {
        match rng.range(0, 3) {
            0 => {
                let hours = i8::try_from(rng.range(-30, 30))?;
                rows.push(construct_row(
                    "HOURS",
                    hours.to_string(),
                    Offset::from_hours(hours).ok(),
                ));
            }
            1 => {
                let seconds = i32::try_from(rng.range(-100_000, 100_000))?;
                rows.push(construct_row(
                    "SECONDS",
                    seconds.to_string(),
                    Offset::from_seconds(seconds).ok(),
                ));
            }
            _ => {
                let duration = SignedDuration::new(rng.range(-100_000, 100_000), gen::subsec(rng));
                rows.push(construct_row(
                    "DURATION",
                    text::duration(duration),
                    Offset::try_from(duration).ok(),
                ));
            }
        }
    }
    Ok(rows)
}

fn arbitrary_offset(rng: &mut Rng) -> Result<Offset> {
    let seconds = match rng.range(0, 3) {
        0 => i64::from(*rng.pick(SECOND_EDGES)),
        1 => rng.range(-25, 25) * 3_600,
        _ => rng.range(-i64::from(MAX_SECONDS), i64::from(MAX_SECONDS)),
    };
    Ok(Offset::from_seconds(i32::try_from(seconds)?)?)
}

fn arithmetic_row(offset: Offset, span: Span, duration: SignedDuration, other: Offset) -> String {
    row([
        text::offset(offset),
        text::span(&span),
        or_err(offset.checked_add(span), text::offset),
        or_err(offset.checked_sub(span), text::offset),
        or_err(offset.saturating_add(span), text::offset),
        or_err(offset.saturating_sub(span), text::offset),
        text::duration(duration),
        or_err(offset.checked_add(duration), text::offset),
        or_err(offset.checked_sub(duration), text::offset),
        or_err(offset.saturating_add(duration), text::offset),
        or_err(offset.saturating_sub(duration), text::offset),
        text::offset(other),
        text::span(&offset.until(other)),
        text::span(&offset.since(other)),
        text::duration(offset.duration_until(other)),
    ])
}

pub fn arithmetic_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    let starts = [0, 3_600, -18_000, MAX_SECONDS, -MAX_SECONDS];
    for (index, units) in ARITHMETIC_SPANS.iter().enumerate() {
        let span = gen::span_of(units)?;
        let (secs, nanos) = ARITHMETIC_DURATIONS[index % ARITHMETIC_DURATIONS.len()];
        for (which, start) in starts.into_iter().enumerate() {
            rows.push(arithmetic_row(
                Offset::from_seconds(start)?,
                span,
                SignedDuration::new(secs, nanos),
                Offset::from_seconds(starts[(which + index) % starts.len()])?,
            ));
        }
    }
    for (index, (secs, nanos)) in ARITHMETIC_DURATIONS.into_iter().enumerate() {
        rows.push(arithmetic_row(
            Offset::from_seconds(starts[index % starts.len()])?,
            Span::new().try_seconds(i64::try_from(index)? - 10)?,
            SignedDuration::new(secs, nanos),
            arbitrary_offset(rng)?,
        ));
    }
    while rows.len() < 340 {
        let span = match rng.range(0, 9) {
            0..=5 => gen::span(rng, &[4, 5, 6], 2, 20)?,
            6..=7 => gen::span(rng, &gen::TIME_UNITS, 3, 200_000)?,
            _ => gen::span(rng, &gen::ALL_UNITS, 2, 30)?,
        };
        let duration = if rng.range(0, 3) == 0 {
            gen::duration(rng)
        } else {
            SignedDuration::new(rng.range(-100_000, 100_000), gen::subsec(rng))
        };
        rows.push(arithmetic_row(
            arbitrary_offset(rng)?,
            span,
            duration,
            arbitrary_offset(rng)?,
        ));
    }
    Ok(rows)
}

fn round_row(offset: Offset, unit: usize, increment: i64, mode: usize) -> String {
    let (smallest, unit_name) = UNITS[unit];
    let (round_mode, mode_name) = MODES[mode];
    let options = OffsetRound::new()
        .smallest(smallest)
        .increment(increment)
        .mode(round_mode);
    row([
        text::offset(offset),
        unit_name.to_owned(),
        increment.to_string(),
        mode_name.to_owned(),
        or_err(offset.round(options), text::offset),
    ])
}

pub fn round_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    // Every mode at a tie on either side of UTC, for minutes and hours, and
    // at the limits, where rounding away from zero leaves the range.
    for mode in 0..MODES.len() {
        for seconds in [90, -90, MAX_SECONDS, -MAX_SECONDS] {
            rows.push(round_row(Offset::from_seconds(seconds)?, 4, 1, mode));
        }
        for seconds in [5_400, -5_400, MAX_SECONDS, -MAX_SECONDS] {
            rows.push(round_row(Offset::from_seconds(seconds)?, 5, 1, mode));
        }
        rows.push(round_row(Offset::from_seconds(-17_762)?, 3, 1, mode));
    }
    // Only seconds, minutes and hours can be the smallest unit.
    for unit in 0..UNITS.len() {
        rows.push(round_row(Offset::from_seconds(19_800)?, unit, 1, 6));
    }
    while rows.len() < 360 {
        let unit = match rng.range(0, 19) {
            0 => usize::try_from(rng.range(0, 2))?,
            1..=4 => 3,
            5..=12 => 4,
            _ => 5,
        };
        let increment = *rng.pick(INCREMENTS[unit]);
        let mode = usize::try_from(rng.range(0, 8))?;
        rows.push(round_row(arbitrary_offset(rng)?, unit, increment, mode));
    }
    Ok(rows)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_range_constant_is_jiffs() {
        assert_eq!(Offset::MAX.seconds(), MAX_SECONDS);
        assert_eq!(Offset::MIN.seconds(), -MAX_SECONDS);
    }

    #[test]
    fn a_failed_construction_ends_the_row() {
        assert_eq!(
            construct_row("HOURS", "-5".to_owned(), Offset::from_hours(-5).ok()),
            "HOURS|-5|-18000|-05|18000|-1"
        );
        assert_eq!(
            construct_row("HOURS", "26".to_owned(), Offset::from_hours(26).ok()),
            "HOURS|26|ERR"
        );
    }

    #[test]
    fn arbitrary_offsets_are_in_range() -> Result<()> {
        let mut rng = Rng::new(3);
        for _ in 0..1_000 {
            let seconds = arbitrary_offset(&mut rng)?.seconds();
            assert!((-MAX_SECONDS..=MAX_SECONDS).contains(&seconds));
        }
        Ok(())
    }
}
