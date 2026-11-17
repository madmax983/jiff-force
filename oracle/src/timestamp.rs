//! Vectors for `Timestamp`: construction from each unit, arithmetic,
//! differences, rounding and printing.

use anyhow::Result;
use jiff::tz::Offset;
use jiff::{SignedDuration, Span, Timestamp, TimestampRound, Unit};

use crate::gen::{self, UnitValues};
use crate::rng::Rng;
use crate::text::{self, or_err, row, MODES, UNITS};

pub const CONSTRUCT_COLUMNS: &str = "constructor (SECOND, MILLISECOND, MICROSECOND, \
     NANOSECOND, PARTS or DURATION)|argument (a count of that unit, or secs,nanos)|\
     timestamp as secs,nanos or ERR|asMillisecond|asMicrosecond|asNanosecond|text  \
     (a row whose timestamp is ERR stops there)";

pub const SPAN_COLUMNS: &str = "timestamp as secs,nanos|span|timestamp + span|\
     timestamp - span|saturating sum|saturating difference  (ERR = error)";

pub const DURATION_COLUMNS: &str = "timestamp as secs,nanos|duration as secs,nanos|\
     timestamp + duration|timestamp - duration|saturating sum|saturating difference  \
     (ERR = error)";

pub const DIFFERENCE_COLUMNS: &str = "a|b|a.until(b) with largest unit HOUR|MINUTE|SECOND|\
     MILLISECOND|MICROSECOND|NANOSECOND|a.since(b) with largest unit HOUR|MINUTE|SECOND|\
     MILLISECOND|MICROSECOND|NANOSECOND|\
     a.durationUntil(b) as secs,nanos|a.until(b) with largest unit DAY  \
     (timestamps are secs,nanos; ERR = error)";

pub const ROUND_COLUMNS: &str =
    "timestamp as secs,nanos|smallest unit|increment|mode|rounded timestamp or ERR";

pub const TEXT_COLUMNS: &str =
    "timestamp as secs,nanos|text|offset in seconds|text with that offset";

const MIN_SECOND: i64 = -377_705_023_201;
const MAX_SECOND: i64 = 253_402_207_200;
const NANOS_PER_DAY: i64 = 86_400_000_000_000;

/// Counts of seconds, milliseconds or microseconds, as multiples of the
/// unit's size `scale` in seconds: the limits and a step either side.
fn count_edges(scale: i64) -> Vec<i64> {
    let candidates = [
        0,
        1,
        -1,
        scale - 1,
        scale,
        scale + 1,
        -scale + 1,
        -scale,
        -scale - 1,
        1_500 * scale / 1_000,
        -1_500 * scale / 1_000,
        MIN_SECOND * scale,
        MIN_SECOND * scale - 1,
        MIN_SECOND * scale + 1,
        MAX_SECOND * scale,
        MAX_SECOND * scale + scale - 1,
        MAX_SECOND * scale + scale,
        MAX_SECOND * scale + 1,
        i64::MAX,
        i64::MIN,
    ];
    // For whole seconds several of these coincide; keep the first of each.
    let mut edges = Vec::new();
    for candidate in candidates {
        if !edges.contains(&candidate) {
            edges.push(candidate);
        }
    }
    edges
}

/// Seconds and nanoseconds given to `Timestamp::new` and
/// `Timestamp::from_duration`: signs that disagree, fractions out of range,
/// and both ends of the range.
const PARTS_EDGES: &[(i64, i32)] = &[
    (0, 0),
    (0, 1),
    (0, -1),
    (0, 999_999_999),
    (0, -999_999_999),
    (0, 1_000_000_000),
    (0, -1_000_000_000),
    (0, i32::MAX),
    (0, i32::MIN),
    (1, -1),
    (-1, 1),
    (2, -999_999_999),
    (-2, 999_999_999),
    (1, 500_000_000),
    (-1, -500_000_000),
    (-1, 500_000_000),
    (1, -500_000_000),
    (MIN_SECOND, 0),
    (MIN_SECOND, 1),
    (MIN_SECOND, 999_999_999),
    (MIN_SECOND, -1),
    (MIN_SECOND + 1, -1),
    (MIN_SECOND + 1, -999_999_999),
    (MIN_SECOND - 1, 0),
    (MIN_SECOND - 1, 999_999_999),
    (MAX_SECOND, 0),
    (MAX_SECOND, 999_999_999),
    (MAX_SECOND, -1),
    (MAX_SECOND + 1, 0),
    (MAX_SECOND + 1, -1),
    (i64::MAX, 0),
    (i64::MIN, 0),
    (i64::MAX, 999_999_999),
    (i64::MIN, -999_999_999),
];

/// Offsets, in seconds, that a timestamp is printed with: whole hours, the
/// odd real ones, the limits, and values that round to a different minute.
const OFFSET_EDGES: &[i32] = &[
    0,
    1,
    -1,
    29,
    30,
    31,
    -29,
    -30,
    -31,
    59,
    60,
    -60,
    89,
    90,
    3_569,
    3_570,
    3_599,
    3_600,
    -3_600,
    3_629,
    3_630,
    -3_570,
    7_200,
    -18_000,
    19_800,
    20_700,
    34_200,
    45_900,
    50_400,
    -43_200,
    86_400,
    -86_400,
    93_569,
    93_570,
    93_599,
    -93_569,
    -93_570,
    -93_599,
    -93_599 + 30,
];

/// The increments tried for each smallest unit, by the unit's index in
/// [`UNITS`]: ones that divide a day evenly, then ones Jiff rejects.
const INCREMENTS: [&[i64]; 6] = [
    &[
        1,
        2,
        5,
        10,
        100,
        1_000,
        500_000_000,
        1_000_000_000,
        86_400_000_000_000,
        0,
        -1,
        7,
        11,
    ],
    &[
        1,
        2,
        5,
        10,
        100,
        1_000,
        500_000,
        1_000_000,
        86_400_000_000,
        0,
        7,
        86_400_000_001,
    ],
    &[
        1,
        2,
        5,
        10,
        100,
        250,
        1_000,
        60_000,
        86_400_000,
        0,
        7,
        86_400_001,
        172_800_000,
    ],
    &[
        1, 2, 5, 10, 15, 30, 45, 60, 90, 3_600, 86_400, 0, -1, 7, 11, 86_401, 172_800,
    ],
    &[
        1, 2, 5, 10, 15, 30, 45, 60, 90, 720, 1_440, 0, 7, 25, 50, 1_441, 2_880,
    ],
    &[1, 2, 3, 4, 6, 8, 12, 24, 0, -1, 5, 7, 9, 25, 48],
];

const NANOS_PER_UNIT: [i64; 6] = [
    1,
    1_000,
    1_000_000,
    1_000_000_000,
    60_000_000_000,
    3_600_000_000_000,
];

fn construct_row(kind: &str, argument: String, result: Option<Timestamp>) -> String {
    let Some(timestamp) = result else {
        return row([kind.to_owned(), argument, text::ERR.to_owned()]);
    };
    row([
        kind.to_owned(),
        argument,
        text::timestamp(timestamp),
        timestamp.as_millisecond().to_string(),
        timestamp.as_microsecond().to_string(),
        timestamp.as_nanosecond().to_string(),
        timestamp.to_string(),
    ])
}

fn from_second(second: i64) -> String {
    construct_row(
        "SECOND",
        second.to_string(),
        Timestamp::from_second(second).ok(),
    )
}

fn from_millisecond(millisecond: i64) -> String {
    construct_row(
        "MILLISECOND",
        millisecond.to_string(),
        Timestamp::from_millisecond(millisecond).ok(),
    )
}

fn from_microsecond(microsecond: i64) -> String {
    construct_row(
        "MICROSECOND",
        microsecond.to_string(),
        Timestamp::from_microsecond(microsecond).ok(),
    )
}

fn from_nanosecond(nanosecond: i128) -> String {
    construct_row(
        "NANOSECOND",
        nanosecond.to_string(),
        Timestamp::from_nanosecond(nanosecond).ok(),
    )
}

fn from_parts(second: i64, nanosecond: i32) -> String {
    construct_row(
        "PARTS",
        format!("{second},{nanosecond}"),
        Timestamp::new(second, nanosecond).ok(),
    )
}

fn from_duration(duration: SignedDuration) -> String {
    construct_row(
        "DURATION",
        text::duration(duration),
        Timestamp::from_duration(duration).ok(),
    )
}

/// Counts of nanoseconds, which need more than 64 bits to reach the ends of
/// the range.
fn nanosecond_edges() -> [i128; 20] {
    let min = i128::from(MIN_SECOND) * 1_000_000_000;
    let max = i128::from(MAX_SECOND) * 1_000_000_000 + 999_999_999;
    [
        0,
        1,
        -1,
        999_999_999,
        1_000_000_000,
        -999_999_999,
        -1_000_000_000,
        -1_000_000_001,
        i128::from(i64::MAX),
        i128::from(i64::MIN),
        i128::from(i64::MAX) + 1,
        i128::from(i64::MIN) - 1,
        min,
        min - 1,
        min + 1,
        max,
        max - 1,
        max + 1,
        1_000_000_000_000_000_000_000_000_000_000,
        -1_000_000_000_000_000_000_000_000_000_000,
    ]
}

/// A row for a random instant, mostly in range with a margin either side
/// that is not, given to a random constructor.
fn arbitrary_construct_row(rng: &mut Rng) -> Result<String> {
    let second = rng.range(MIN_SECOND - 20_000_000_000, MAX_SECOND + 20_000_000_000);
    let fraction = i64::from(gen::subsec(rng));
    let signed = if second < 0 { -fraction } else { fraction };
    Ok(match rng.range(0, 5) {
        0 => from_second(second),
        1 => from_millisecond(second * 1_000 + signed / 1_000_000),
        2 => from_microsecond(second * 1_000_000 + signed / 1_000),
        3 => from_nanosecond(i128::from(second) * 1_000_000_000 + i128::from(signed)),
        // The two parts need not agree in sign.
        4 => from_parts(second, i32::try_from(rng.range(-999_999_999, 999_999_999))?),
        _ => from_duration(SignedDuration::new(second, i32::try_from(signed)?)),
    })
}

pub fn construct_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    rows.extend(count_edges(1).into_iter().map(from_second));
    rows.extend(count_edges(1_000).into_iter().map(from_millisecond));
    rows.extend(count_edges(1_000_000).into_iter().map(from_microsecond));
    rows.extend(nanosecond_edges().into_iter().map(from_nanosecond));
    for &(second, nanosecond) in PARTS_EDGES {
        rows.push(from_parts(second, nanosecond));
    }
    for &(second, nanosecond) in PARTS_EDGES {
        // A duration holds at most 999,999,999 nanoseconds of either sign.
        if nanosecond.unsigned_abs() < 1_000_000_000 {
            rows.push(from_duration(SignedDuration::new(second, nanosecond)));
        }
    }
    while rows.len() < 340 {
        rows.push(arbitrary_construct_row(rng)?);
    }
    Ok(rows)
}

fn span_row(timestamp: Timestamp, span: Span) -> String {
    row([
        text::timestamp(timestamp),
        text::span(&span),
        or_err(timestamp.checked_add(span), text::timestamp),
        or_err(timestamp.checked_sub(span), text::timestamp),
        or_err(timestamp.saturating_add(span), text::timestamp),
        or_err(timestamp.saturating_sub(span), text::timestamp),
    ])
}

pub fn span_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let edges: &[&UnitValues] = &[
        &[],
        &[(9, 1)],
        &[(9, -1)],
        &[(8, 1)],
        &[(7, 1)],
        &[(6, 1)],
        &[(6, -1)],
        &[(5, 1)],
        &[(4, 1)],
        &[(4, -1)],
        &[(4, 24)],
        &[(3, 1)],
        &[(3, -1)],
        &[(2, 1)],
        &[(1, 1)],
        &[(0, 1)],
        &[(3, 1), (4, 1)],
        &[(4, 1), (5, 30), (6, 15), (7, 500), (8, 250), (9, 125)],
        &[(4, -1), (5, -30), (6, -15), (7, -500), (8, -250), (9, -125)],
        &[(6, 1), (9, 999_999_999)],
        &[(9, 1_000_000_000)],
        &[(9, i64::MAX)],
        &[(9, -i64::MAX)],
        &[(4, 175_307_616)],
        &[(4, -175_307_616)],
        &[(6, 631_107_230_401)],
        &[(6, -631_107_230_401)],
        &[(6, 631_107_230_400)],
        &[(6, 631_107_417_600)],
        &[(7, 631_107_417_600_000)],
        &[(8, 631_107_417_600_000_000)],
        &[(4, 175_307_616), (5, 10_518_456_960), (6, 631_107_417_600)],
    ];
    let starts = [
        Timestamp::UNIX_EPOCH,
        Timestamp::MIN,
        Timestamp::MAX,
        Timestamp::new(1_709_164_800, 500_000_000)?,
        Timestamp::new(-1, -1)?,
    ];
    let mut rows = Vec::new();
    for units in edges {
        for start in starts {
            rows.push(span_row(start, gen::span_of(units)?));
        }
    }
    while rows.len() < 340 {
        let timestamp = gen::timestamp(rng)?;
        let span = match rng.range(0, 9) {
            0..=4 => gen::span(rng, &gen::TIME_UNITS, 3, 2_000_000)?,
            5..=7 => gen::span(rng, &gen::TIME_UNITS, 3, i64::MAX)?,
            _ => gen::span(rng, &gen::ALL_UNITS, 3, 50)?,
        };
        rows.push(span_row(timestamp, span));
    }
    Ok(rows)
}

fn duration_row(timestamp: Timestamp, duration: SignedDuration) -> String {
    row([
        text::timestamp(timestamp),
        text::duration(duration),
        or_err(timestamp.checked_add(duration), text::timestamp),
        or_err(timestamp.checked_sub(duration), text::timestamp),
        or_err(timestamp.saturating_add(duration), text::timestamp),
        or_err(timestamp.saturating_sub(duration), text::timestamp),
    ])
}

pub fn duration_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let edges = [
        (0, 0),
        (0, 1),
        (0, -1),
        (1, 0),
        (-1, 0),
        (0, 999_999_999),
        (0, -999_999_999),
        (86_400, 0),
        (-86_400, 0),
        (MAX_SECOND, 999_999_999),
        (MIN_SECOND, 0),
        (-MIN_SECOND, 0),
        (MAX_SECOND - MIN_SECOND, 999_999_999),
        (MAX_SECOND - MIN_SECOND + 1, 0),
        (MIN_SECOND - MAX_SECOND, -999_999_999),
        (MIN_SECOND - MAX_SECOND - 1, 0),
        (i64::MAX, 999_999_999),
        (i64::MIN, -999_999_999),
        (i64::MIN, 0),
        (i64::MAX, 0),
    ];
    let starts = [
        Timestamp::UNIX_EPOCH,
        Timestamp::MIN,
        Timestamp::MAX,
        Timestamp::new(1_709_164_800, 500_000_000)?,
        Timestamp::new(-1, -1)?,
    ];
    let mut rows = Vec::new();
    for (secs, nanos) in edges {
        for start in starts {
            rows.push(duration_row(start, SignedDuration::new(secs, nanos)));
        }
    }
    while rows.len() < 320 {
        let duration = if rng.range(0, 2) == 0 {
            gen::duration(rng)
        } else {
            SignedDuration::new(rng.range(-5_000_000_000, 5_000_000_000), gen::subsec(rng))
        };
        rows.push(duration_row(gen::timestamp(rng)?, duration));
    }
    Ok(rows)
}

fn difference_row(a: Timestamp, b: Timestamp) -> String {
    let show = |span: Span| text::span(&span);
    // Hours down to nanoseconds.
    let largest: Vec<Unit> = UNITS[..6].iter().rev().map(|&(unit, _)| unit).collect();
    let mut fields = vec![text::timestamp(a), text::timestamp(b)];
    fields.extend(largest.iter().map(|&unit| or_err(a.until((unit, b)), show)));
    fields.extend(largest.iter().map(|&unit| or_err(a.since((unit, b)), show)));
    fields.push(text::duration(a.duration_until(b)));
    fields.push(or_err(a.until((Unit::Day, b)), show));
    row(fields)
}

pub fn difference_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut pairs = vec![
        (Timestamp::MIN, Timestamp::MAX),
        (Timestamp::MAX, Timestamp::MIN),
        (Timestamp::UNIX_EPOCH, Timestamp::UNIX_EPOCH),
        (Timestamp::UNIX_EPOCH, Timestamp::MAX),
        (Timestamp::UNIX_EPOCH, Timestamp::MIN),
        (Timestamp::MAX, Timestamp::MAX),
        (Timestamp::new(0, 1)?, Timestamp::new(0, -1)?),
        (
            Timestamp::new(-1, -999_999_999)?,
            Timestamp::new(1, 999_999_999)?,
        ),
        (
            Timestamp::new(1, 999_999_999)?,
            Timestamp::new(-1, -999_999_999)?,
        ),
        (Timestamp::new(0, 0)?, Timestamp::new(3_600, 0)?),
        (Timestamp::new(0, 0)?, Timestamp::new(3_599, 999_999_999)?),
        (Timestamp::new(0, 0)?, Timestamp::new(86_400, 0)?),
        // The furthest apart two timestamps can be in 64 bit nanoseconds,
        // and one nanosecond further.
        (
            Timestamp::new(0, 0)?,
            Timestamp::new(9_223_372_036, 854_775_807)?,
        ),
        (
            Timestamp::new(0, 0)?,
            Timestamp::new(9_223_372_036, 854_775_808)?,
        ),
        (
            Timestamp::new(0, 0)?,
            Timestamp::new(-9_223_372_036, -854_775_807)?,
        ),
        (
            Timestamp::new(0, 0)?,
            Timestamp::new(-9_223_372_036, -854_775_808)?,
        ),
        (
            Timestamp::new(9_223_372_036, 854_775_808)?,
            Timestamp::new(0, 0)?,
        ),
        (
            Timestamp::new(1_000_000_000, 0)?,
            Timestamp::new(1_709_164_800, 0)?,
        ),
    ];
    while pairs.len() < 260 {
        let a = gen::timestamp(rng)?;
        // Most pairs are close enough for the difference to fit in every
        // unit; the rest are anywhere, where small units overflow.
        let b = match rng.range(0, 3) {
            0 => gen::timestamp(rng)?,
            1 => a.saturating_add(SignedDuration::new(
                rng.range(-200_000, 200_000),
                gen::subsec(rng),
            ))?,
            _ => a.saturating_add(SignedDuration::new(
                rng.range(-9_000_000_000, 9_000_000_000),
                gen::subsec(rng),
            ))?,
        };
        pairs.push((a, b));
    }
    Ok(pairs
        .into_iter()
        .map(|(a, b)| difference_row(a, b))
        .collect())
}

fn round_row(timestamp: Timestamp, unit: usize, increment: i64, mode: usize) -> String {
    let (smallest, unit_name) = UNITS[unit];
    let (round_mode, mode_name) = MODES[mode];
    let options = TimestampRound::new()
        .smallest(smallest)
        .increment(increment)
        .mode(round_mode);
    row([
        text::timestamp(timestamp),
        unit_name.to_owned(),
        increment.to_string(),
        mode_name.to_owned(),
        or_err(timestamp.round(options), text::timestamp),
    ])
}

/// A timestamp chosen to make rounding to `quantum` nanoseconds interesting:
/// exactly on a multiple, exactly half way, or a nanosecond either side, on
/// either side of the epoch.
fn timestamp_near_a_tie(rng: &mut Rng, quantum: i64) -> Result<Timestamp> {
    if quantum <= 0 || quantum > NANOS_PER_DAY {
        return gen::timestamp(rng);
    }
    // Within about 285 years of the epoch, so that the nanoseconds fit in 64
    // bits with room to spare for the adjustments below.
    let anywhere =
        rng.range(-9_000_000_000, 9_000_000_000) * 1_000_000_000 + rng.range(0, 999_999_999);
    let multiple = anywhere - anywhere.rem_euclid(quantum);
    let half = quantum / 2;
    let nanosecond = match rng.range(0, 7) {
        0 => multiple,
        1 => multiple + half,
        2 => multiple + half - 1,
        3 => multiple + half + 1,
        4 => multiple + 1,
        5 => multiple - 1,
        _ => multiple + rng.range(0, quantum - 1),
    };
    Ok(Timestamp::from_nanosecond(i128::from(nanosecond))?)
}

pub fn round_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    // Every unit with every mode, for a tie after the epoch and the same tie
    // before it, where "up" and "away from zero" part ways.
    for (unit, quantum) in NANOS_PER_UNIT.into_iter().enumerate() {
        for mode in 0..MODES.len() {
            let tie = 1_709_164_800_000_000_000 + quantum + quantum / 2;
            rows.push(round_row(
                Timestamp::from_nanosecond(i128::from(tie))?,
                unit,
                1,
                mode,
            ));
            rows.push(round_row(
                Timestamp::from_nanosecond(i128::from(-tie))?,
                unit,
                1,
                mode,
            ));
        }
    }
    // Rounding at the limits can leave the range.
    for unit in 0..NANOS_PER_UNIT.len() {
        for mode in [0, 1, 2, 3, 6] {
            rows.push(round_row(Timestamp::MAX, unit, 1, mode));
            rows.push(round_row(Timestamp::MIN, unit, 1, mode));
        }
    }
    // A day cannot be the smallest unit, and neither can anything larger.
    for unit in 6..UNITS.len() {
        rows.push(round_row(Timestamp::new(1_709_164_800, 0)?, unit, 1, 6));
    }
    while rows.len() < 480 {
        let unit = usize::try_from(rng.range(0, 5))?;
        let increment = *rng.pick(INCREMENTS[unit]);
        let mode = usize::try_from(rng.range(0, 8))?;
        let quantum = NANOS_PER_UNIT[unit].saturating_mul(increment);
        rows.push(round_row(
            timestamp_near_a_tie(rng, quantum)?,
            unit,
            increment,
            mode,
        ));
    }
    Ok(rows)
}

fn text_row(timestamp: Timestamp, offset: Offset) -> String {
    row([
        text::timestamp(timestamp),
        timestamp.to_string(),
        text::offset(offset),
        timestamp.display_with_offset(offset).to_string(),
    ])
}

pub fn text_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    let timestamps = [
        Timestamp::UNIX_EPOCH,
        Timestamp::MIN,
        Timestamp::MAX,
        Timestamp::new(1_709_164_800, 0)?,
        Timestamp::new(-1, 0)?,
        Timestamp::new(0, -1)?,
        Timestamp::new(0, 1)?,
        Timestamp::new(0, 1_000)?,
        Timestamp::new(0, 1_000_000)?,
        Timestamp::new(0, 100_000_000)?,
        Timestamp::new(0, 120_000_000)?,
        Timestamp::new(-62_135_596_800, 0)?,
        Timestamp::new(-62_135_596_801, 0)?,
        Timestamp::new(-62_167_219_200, 0)?,
        Timestamp::new(-62_167_219_201, 0)?,
        Timestamp::new(253_402_207_199, 999_999_999)?,
    ];
    for (index, timestamp) in timestamps.into_iter().enumerate() {
        rows.push(text_row(timestamp, Offset::UTC));
        rows.push(text_row(
            timestamp,
            Offset::from_seconds(OFFSET_EDGES[index % OFFSET_EDGES.len()])?,
        ));
    }
    for &seconds in OFFSET_EDGES {
        rows.push(text_row(
            Timestamp::new(1_709_164_800, 123_456_789)?,
            Offset::from_seconds(seconds)?,
        ));
        rows.push(text_row(
            gen::timestamp(rng)?,
            Offset::from_seconds(seconds)?,
        ));
    }
    while rows.len() < 320 {
        let seconds = match rng.range(0, 2) {
            0 => rng.range(-25, 25) * 3_600,
            1 => rng.range(-100, 100) * 900,
            _ => rng.range(-93_599, 93_599),
        };
        rows.push(text_row(
            gen::timestamp(rng)?,
            Offset::from_seconds(i32::try_from(seconds)?)?,
        ));
    }
    Ok(rows)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_range_constants_are_jiffs() {
        assert_eq!(Timestamp::MIN.as_second(), MIN_SECOND);
        assert_eq!(Timestamp::MAX.as_second(), MAX_SECOND);
    }

    #[test]
    fn count_edges_straddle_both_limits() {
        let edges = count_edges(1_000);
        assert!(edges.contains(&(MIN_SECOND * 1_000)));
        assert!(edges.contains(&(MIN_SECOND * 1_000 - 1)));
        assert!(edges.contains(&(MAX_SECOND * 1_000 + 999)));
        assert!(edges.contains(&(MAX_SECOND * 1_000 + 1_000)));
    }

    #[test]
    fn a_failed_construction_ends_the_row() {
        assert_eq!(
            construct_row("SECOND", "1".to_owned(), Timestamp::from_second(1).ok()),
            "SECOND|1|1,0|1000|1000000|1000000000|1970-01-01T00:00:01Z"
        );
        assert_eq!(
            construct_row(
                "SECOND",
                "x".to_owned(),
                Timestamp::from_second(i64::MAX).ok()
            ),
            "SECOND|x|ERR"
        );
    }

    #[test]
    fn timestamps_near_a_tie_are_valid_for_any_quantum() -> Result<()> {
        let mut rng = Rng::new(5);
        for quantum in [
            -1,
            0,
            1,
            2,
            1_000,
            500_000_000,
            45_000_000_000,
            NANOS_PER_DAY,
            i64::MAX,
        ] {
            for _ in 0..300 {
                timestamp_near_a_tie(&mut rng, quantum)?;
            }
        }
        Ok(())
    }
}
