//! Vectors for civil time arithmetic, differences, rounding and the `with`
//! builder.

use anyhow::Result;
use jiff::civil::{Time, TimeRound};
use jiff::{SignedDuration, Span, Unit};

use crate::gen::{self, UnitValues};
use crate::rng::Rng;
use crate::text::{self, or_err, row, MODES, UNITS};

pub const SPAN_COLUMNS: &str = "time|span|time + span|time - span|wrapping sum|\
     wrapping difference|saturating sum|saturating difference  (ERR = error)";

pub const DURATION_COLUMNS: &str = "time|duration as secs,nanos|time + duration|\
     time - duration|wrapping sum|wrapping difference|saturating sum|saturating difference  \
     (ERR = error)";

pub const DIFFERENCE_COLUMNS: &str = "a|b|a.until(b) with largest unit HOUR|MINUTE|SECOND|\
     MILLISECOND|MICROSECOND|NANOSECOND|a.since(b) with largest unit HOUR|MINUTE|SECOND|\
     MILLISECOND|MICROSECOND|NANOSECOND|\
     a.durationUntil(b) as secs,nanos|a.until(b) with largest unit DAY";

pub const ROUND_COLUMNS: &str = "time|smallest unit|increment|mode|rounded time or ERR";

pub const WITH_COLUMNS: &str = "time|setters applied in order, separated by ';'|built time or ERR";

const NANOS_PER_DAY: i64 = 86_400_000_000_000;

/// A time as hour, minute, second and nanosecond.
type Hms = (i8, i8, i8, i32);

/// Times and spans whose sum is worth pinning by name: the two ends of the
/// day, whole days, calendar units and spans too long for 64 bit nanoseconds.
const SPAN_EDGES: &[(Hms, &UnitValues)] = &[
    ((23, 59, 59, 999_999_999), &[(9, 1)]),
    ((23, 59, 59, 999_999_999), &[(9, -1)]),
    ((0, 0, 0, 0), &[(9, -1)]),
    ((0, 0, 0, 0), &[(9, 1)]),
    ((0, 0, 0, 0), &[]),
    ((20, 10, 1, 0), &[(4, 1), (5, 49), (6, 59)]),
    ((20, 10, 1, 0), &[(4, 3), (5, 49), (6, 59)]),
    (
        (20, 10, 1, 0),
        &[(4, 3), (5, 49), (6, 58), (7, 999), (8, 999), (9, 1_000)],
    ),
    ((20, 10, 1, 0), &[(4, -20), (5, -10), (6, -1)]),
    ((20, 10, 1, 0), &[(4, -20), (5, -10), (6, -1), (9, -1)]),
    ((20, 10, 1, 0), &[(3, 1)]),
    ((20, 10, 1, 0), &[(3, -1)]),
    ((20, 10, 1, 0), &[(2, 1)]),
    ((20, 10, 1, 0), &[(1, 1)]),
    ((20, 10, 1, 0), &[(0, 1)]),
    ((20, 10, 1, 0), &[(3, 1), (4, 1)]),
    ((20, 10, 1, 0), &[(3, -1), (4, -1)]),
    ((20, 10, 1, 0), &[(0, 1), (9, 1)]),
    ((12, 0, 0, 0), &[(4, 11)]),
    ((12, 0, 0, 0), &[(4, 12)]),
    ((12, 0, 0, 0), &[(4, -12)]),
    ((12, 0, 0, 0), &[(4, -13)]),
    ((12, 0, 0, 0), &[(4, 24)]),
    ((12, 0, 0, 0), &[(4, -24)]),
    ((12, 0, 0, 0), &[(4, 25)]),
    ((12, 0, 0, 0), &[(4, 48)]),
    ((12, 0, 0, 0), &[(5, 720)]),
    ((12, 0, 0, 0), &[(5, 719)]),
    ((12, 0, 0, 0), &[(6, 43_200)]),
    ((12, 0, 0, 0), &[(6, 43_199)]),
    ((12, 0, 0, 0), &[(7, 43_199_999)]),
    ((12, 0, 0, 0), &[(8, 43_199_999_999)]),
    ((12, 0, 0, 0), &[(9, 43_199_999_999_999)]),
    ((12, 0, 0, 0), &[(9, 43_200_000_000_000)]),
    ((12, 0, 0, 0), &[(9, -43_200_000_000_000)]),
    ((12, 0, 0, 0), &[(9, -43_200_000_000_001)]),
    ((12, 0, 0, 0), &[(4, 175_307_616)]),
    ((12, 0, 0, 0), &[(4, -175_307_616)]),
    ((12, 0, 0, 0), &[(4, 175_307_615)]),
    ((12, 0, 0, 0), &[(5, 10_518_456_960)]),
    ((12, 0, 0, 0), &[(5, 10_518_456_959)]),
    ((12, 0, 0, 0), &[(6, 631_107_417_600)]),
    ((12, 0, 0, 0), &[(6, -631_107_417_599)]),
    ((12, 0, 0, 0), &[(7, 631_107_417_600_000)]),
    ((12, 0, 0, 0), &[(8, 631_107_417_600_000_000)]),
    ((12, 0, 0, 0), &[(8, -631_107_417_599_999_999)]),
    ((12, 0, 0, 0), &[(9, i64::MAX)]),
    ((12, 0, 0, 0), &[(9, -i64::MAX)]),
    ((0, 0, 0, 0), &[(9, i64::MAX)]),
    ((23, 59, 59, 999_999_999), &[(9, i64::MAX)]),
    ((23, 59, 59, 999_999_999), &[(9, -i64::MAX)]),
    // Together these exceed what 64 bits of nanoseconds can hold.
    ((12, 0, 0, 0), &[(4, 175_307_616), (5, 10_518_456_960)]),
    ((12, 0, 0, 0), &[(4, -175_307_616), (5, -10_518_456_960)]),
    (
        (12, 0, 0, 0),
        &[(4, 175_307_616), (5, 10_518_456_960), (6, 631_107_417_600)],
    ),
    (
        (1, 2, 3, 4),
        &[
            (4, 175_307_616),
            (5, 10_518_456_960),
            (6, 631_107_417_600),
            (7, 631_107_417_600_000),
            (8, 631_107_417_600_000_000),
            (9, i64::MAX),
        ],
    ),
    (
        (1, 2, 3, 4),
        &[
            (4, -175_307_616),
            (5, -10_518_456_960),
            (6, -631_107_417_600),
            (7, -631_107_417_600_000),
            (8, -631_107_417_600_000_000),
            (9, -i64::MAX),
        ],
    ),
    (
        (6, 30, 0, 0),
        &[(8, 631_107_417_600_000_000), (9, i64::MAX)],
    ),
    (
        (6, 30, 0, 0),
        &[(8, -631_107_417_600_000_000), (9, -i64::MAX)],
    ),
    (
        (6, 30, 0, 0),
        &[(7, 631_107_417_600_000), (8, 631_107_417_600_000_000)],
    ),
    ((6, 30, 0, 0), &[(6, 631_107_417_600), (9, i64::MAX)]),
    ((6, 30, 0, 0), &[(6, 1), (9, i64::MAX)]),
    ((6, 30, 0, 0), &[(6, -1), (9, -i64::MAX)]),
];

/// Durations added to the start, the middle and the end of the day. The last
/// four straddle the limits of a duration that fits in 64 bit nanoseconds.
const DURATION_EDGES: &[(i64, i32)] = &[
    (0, 0),
    (0, 1),
    (0, -1),
    (1, 0),
    (-1, 0),
    (43_199, 999_999_999),
    (43_200, 0),
    (-43_200, 0),
    (-43_200, -1),
    (86_399, 999_999_999),
    (86_400, 0),
    (86_400, 1),
    (-86_399, -999_999_999),
    (-86_400, 0),
    (172_800, 0),
    (i64::MAX, 999_999_999),
    (i64::MIN, -999_999_999),
    (i64::MIN, 0),
    (i64::MAX, 0),
    (9_223_372_036, 854_775_807),
    (9_223_372_036, 854_775_808),
    (-9_223_372_036, -854_775_808),
    (-9_223_372_036, -854_775_809),
];

/// The increments tried for each smallest unit, by the unit's index in
/// [`UNITS`]: ones that divide the next unit evenly, then ones Jiff rejects.
const INCREMENTS: [&[i64]; 6] = [
    &[
        1, 2, 4, 5, 8, 10, 20, 25, 40, 50, 100, 125, 200, 250, 500, 0, -1, 3, 7, 1_000, 1_001,
    ],
    &[
        1, 2, 4, 5, 8, 10, 20, 25, 40, 50, 100, 125, 200, 250, 500, 0, 3, 999, 1_000,
    ],
    &[
        1, 2, 4, 5, 8, 10, 20, 25, 40, 50, 100, 125, 200, 250, 500, 0, 6, 1_000, 2_000,
    ],
    &[1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30, 0, -5, 7, 45, 60, 120],
    &[1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30, 0, 7, 9, 60, 90],
    &[1, 2, 3, 4, 6, 8, 12, 0, -1, 5, 7, 24, 25, 48],
];

const NANOS_PER_UNIT: [i64; 6] = [
    1,
    1_000,
    1_000_000,
    1_000_000_000,
    60_000_000_000,
    3_600_000_000_000,
];

/// One call on Jiff's `TimeWith` builder.
#[derive(Clone, Copy)]
enum Setter {
    Hour(i8),
    Minute(i8),
    Second(i8),
    Millisecond(i16),
    Microsecond(i16),
    Nanosecond(i16),
    SubsecNanosecond(i32),
}

impl Setter {
    fn name(self) -> String {
        match self {
            Self::Hour(v) => format!("hour={v}"),
            Self::Minute(v) => format!("minute={v}"),
            Self::Second(v) => format!("second={v}"),
            Self::Millisecond(v) => format!("millisecond={v}"),
            Self::Microsecond(v) => format!("microsecond={v}"),
            Self::Nanosecond(v) => format!("nanosecond={v}"),
            Self::SubsecNanosecond(v) => format!("subsecNanosecond={v}"),
        }
    }
}

/// Setter sequences whose outcome depends on which setter wins.
const WITH_EDGES: &[(Hms, &[Setter])] = &[
    ((15, 45, 10, 123_456_789), &[]),
    ((15, 45, 10, 123_456_789), &[Setter::Hour(0)]),
    ((15, 45, 10, 123_456_789), &[Setter::Hour(23)]),
    ((15, 45, 10, 123_456_789), &[Setter::Hour(24)]),
    ((15, 45, 10, 123_456_789), &[Setter::Hour(-1)]),
    ((15, 45, 10, 123_456_789), &[Setter::Minute(59)]),
    ((15, 45, 10, 123_456_789), &[Setter::Minute(60)]),
    ((15, 45, 10, 123_456_789), &[Setter::Minute(-1)]),
    ((15, 45, 10, 123_456_789), &[Setter::Second(59)]),
    ((15, 45, 10, 123_456_789), &[Setter::Second(60)]),
    ((15, 45, 10, 123_456_789), &[Setter::Second(-1)]),
    ((15, 45, 10, 123_456_789), &[Setter::Millisecond(0)]),
    ((15, 45, 10, 123_456_789), &[Setter::Millisecond(999)]),
    ((15, 45, 10, 123_456_789), &[Setter::Millisecond(1_000)]),
    ((15, 45, 10, 123_456_789), &[Setter::Millisecond(-1)]),
    ((15, 45, 10, 123_456_789), &[Setter::Microsecond(0)]),
    ((15, 45, 10, 123_456_789), &[Setter::Microsecond(999)]),
    ((15, 45, 10, 123_456_789), &[Setter::Microsecond(1_000)]),
    ((15, 45, 10, 123_456_789), &[Setter::Nanosecond(0)]),
    ((15, 45, 10, 123_456_789), &[Setter::Nanosecond(999)]),
    ((15, 45, 10, 123_456_789), &[Setter::Nanosecond(1_000)]),
    ((15, 45, 10, 123_456_789), &[Setter::Nanosecond(-1)]),
    ((15, 45, 10, 123_456_789), &[Setter::SubsecNanosecond(0)]),
    ((15, 45, 10, 123_456_789), &[Setter::SubsecNanosecond(1)]),
    (
        (15, 45, 10, 123_456_789),
        &[Setter::SubsecNanosecond(999_999_999)],
    ),
    (
        (15, 45, 10, 123_456_789),
        &[Setter::SubsecNanosecond(1_000_000_000)],
    ),
    ((15, 45, 10, 123_456_789), &[Setter::SubsecNanosecond(-1)]),
    (
        (15, 45, 10, 123_456_789),
        &[
            Setter::Millisecond(1),
            Setter::Microsecond(2),
            Setter::Nanosecond(3),
        ],
    ),
    (
        (15, 45, 10, 123_456_789),
        &[Setter::Millisecond(1), Setter::SubsecNanosecond(5)],
    ),
    (
        (15, 45, 10, 123_456_789),
        &[Setter::SubsecNanosecond(5), Setter::Millisecond(1)],
    ),
    (
        (15, 45, 10, 123_456_789),
        &[Setter::SubsecNanosecond(5), Setter::Nanosecond(7)],
    ),
    (
        (15, 45, 10, 123_456_789),
        &[Setter::Nanosecond(7), Setter::SubsecNanosecond(5)],
    ),
    (
        (15, 45, 10, 123_456_789),
        &[Setter::Millisecond(1_000), Setter::SubsecNanosecond(5)],
    ),
    (
        (15, 45, 10, 123_456_789),
        &[
            Setter::SubsecNanosecond(1_000_000_000),
            Setter::Millisecond(1),
        ],
    ),
    (
        (15, 45, 10, 123_456_789),
        &[Setter::SubsecNanosecond(-5), Setter::Microsecond(1)],
    ),
    (
        (15, 45, 10, 123_456_789),
        &[Setter::Hour(30), Setter::Hour(3)],
    ),
    (
        (15, 45, 10, 123_456_789),
        &[Setter::Hour(3), Setter::Hour(30)],
    ),
    (
        (0, 0, 0, 0),
        &[
            Setter::Hour(23),
            Setter::Minute(59),
            Setter::Second(59),
            Setter::SubsecNanosecond(999_999_999),
        ],
    ),
    (
        (23, 59, 59, 999_999_999),
        &[
            Setter::Hour(0),
            Setter::Minute(0),
            Setter::Second(0),
            Setter::Millisecond(0),
        ],
    ),
];

fn time_of(parts: Hms) -> Result<Time> {
    Ok(Time::new(parts.0, parts.1, parts.2, parts.3)?)
}

/// The time that is `nanosecond` nanoseconds after midnight.
fn time_at(nanosecond: i64) -> Result<Time> {
    let nanosecond = nanosecond.rem_euclid(NANOS_PER_DAY);
    let second = nanosecond / 1_000_000_000;
    Ok(Time::new(
        i8::try_from(second / 3_600)?,
        i8::try_from(second / 60 % 60)?,
        i8::try_from(second % 60)?,
        i32::try_from(nanosecond % 1_000_000_000)?,
    )?)
}

/// A span of time units small enough that the sum often stays within the day.
fn clock_span(rng: &mut Rng) -> Result<Span> {
    const CAPS: [i64; 6] = [
        20,
        1_200,
        72_000,
        72_000_000,
        72_000_000_000,
        72_000_000_000_000,
    ];
    let negative = rng.range(0, 1) == 0;
    let mut span = Span::new();
    for _ in 0..rng.range(1, 3) {
        let unit = usize::try_from(rng.range(0, 5))?;
        let value = rng.range(1, CAPS[unit]);
        span = gen::set_unit(span, 4 + unit, if negative { -value } else { value })?;
    }
    Ok(span)
}

fn span_row(time: Time, span: Span) -> String {
    row([
        text::time(time),
        text::span(&span),
        or_err(time.checked_add(span), text::time),
        or_err(time.checked_sub(span), text::time),
        text::time(time.wrapping_add(span)),
        text::time(time.wrapping_sub(span)),
        text::time(time.saturating_add(span)),
        text::time(time.saturating_sub(span)),
    ])
}

pub fn span_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    for &(time, units) in SPAN_EDGES {
        rows.push(span_row(time_of(time)?, gen::span_of(units)?));
    }
    while rows.len() < 320 {
        let time = gen::time(rng)?;
        let span = match rng.range(0, 9) {
            0..=5 => clock_span(rng)?,
            6..=7 => gen::span(rng, &gen::TIME_UNITS, 3, i64::MAX)?,
            _ => gen::span(rng, &gen::ALL_UNITS, 3, 50)?,
        };
        rows.push(span_row(time, span));
    }
    Ok(rows)
}

fn duration_row(time: Time, duration: SignedDuration) -> String {
    row([
        text::time(time),
        text::duration(duration),
        or_err(time.checked_add(duration), text::time),
        or_err(time.checked_sub(duration), text::time),
        text::time(time.wrapping_add(duration)),
        text::time(time.wrapping_sub(duration)),
        text::time(time.saturating_add(duration)),
        text::time(time.saturating_sub(duration)),
    ])
}

pub fn duration_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    for time in [(0, 0, 0, 0), (12, 0, 0, 0), (23, 59, 59, 999_999_999)] {
        for &(secs, nanos) in DURATION_EDGES {
            rows.push(duration_row(
                time_of(time)?,
                SignedDuration::new(secs, nanos),
            ));
        }
    }
    while rows.len() < 300 {
        let duration = if rng.range(0, 2) == 0 {
            gen::duration(rng)
        } else {
            SignedDuration::new(rng.range(-90_000, 90_000), gen::subsec(rng))
        };
        rows.push(duration_row(gen::time(rng)?, duration));
    }
    Ok(rows)
}

fn difference_row(a: Time, b: Time) -> String {
    let show = |span: Span| text::span(&span);
    // Hours down to nanoseconds.
    let largest: Vec<Unit> = UNITS[..6].iter().rev().map(|&(unit, _)| unit).collect();
    let mut fields = vec![text::time(a), text::time(b)];
    fields.extend(largest.iter().map(|&unit| or_err(a.until((unit, b)), show)));
    fields.extend(largest.iter().map(|&unit| or_err(a.since((unit, b)), show)));
    fields.push(text::duration(a.duration_until(b)));
    fields.push(or_err(a.until((Unit::Day, b)), show));
    row(fields)
}

pub fn difference_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut times = vec![
        (Time::MIN, Time::MAX),
        (Time::MAX, Time::MIN),
        (Time::MIN, Time::MIN),
        (Time::MAX, Time::MAX),
        (time_of((0, 0, 0, 0))?, time_of((0, 0, 0, 1))?),
        (time_of((0, 0, 0, 1))?, time_of((0, 0, 0, 0))?),
        (time_of((3, 24, 30, 3_500))?, time_of((15, 30, 0, 0))?),
        (time_of((22, 35, 1, 0))?, time_of((22, 35, 3, 500_000_000))?),
        (time_of((23, 30, 0, 0))?, time_of((7, 0, 0, 0))?),
        (time_of((11, 59, 59, 999_999_999))?, time_of((12, 0, 0, 0))?),
        (time_of((12, 0, 0, 0))?, time_of((13, 0, 0, 0))?),
        (time_of((12, 0, 0, 0))?, time_of((12, 59, 59, 999_999_999))?),
        (time_of((12, 0, 0, 0))?, time_of((12, 1, 0, 0))?),
        (time_of((12, 0, 0, 0))?, time_of((12, 0, 1, 0))?),
        (time_of((12, 0, 0, 0))?, time_of((12, 0, 0, 1_000_000))?),
        (time_of((12, 0, 0, 0))?, time_of((12, 0, 0, 1_000))?),
        (time_of((12, 0, 0, 0))?, time_of((12, 0, 0, 999))?),
    ];
    while times.len() < 250 {
        let a = gen::time(rng)?;
        // Some pairs are within a second of each other, where only the
        // sub-second units are in play.
        let b = if rng.range(0, 4) == 0 {
            a.wrapping_add(SignedDuration::from_nanos(
                rng.range(-2_000_000_000, 2_000_000_000),
            ))
        } else {
            gen::time(rng)?
        };
        times.push((a, b));
    }
    Ok(times
        .into_iter()
        .map(|(a, b)| difference_row(a, b))
        .collect())
}

fn round_row(time: Time, unit: usize, increment: i64, mode: usize) -> String {
    let (smallest, unit_name) = UNITS[unit];
    let (round_mode, mode_name) = MODES[mode];
    let options = TimeRound::new()
        .smallest(smallest)
        .increment(increment)
        .mode(round_mode);
    row([
        text::time(time),
        unit_name.to_owned(),
        increment.to_string(),
        mode_name.to_owned(),
        or_err(time.round(options), text::time),
    ])
}

/// A time chosen to make rounding to `quantum` nanoseconds interesting:
/// exactly on a multiple, exactly half way, or a nanosecond either side.
fn time_near_a_tie(rng: &mut Rng, quantum: i64) -> Result<Time> {
    if quantum <= 0 || quantum > NANOS_PER_DAY {
        return gen::time(rng);
    }
    let multiple = rng.range(0, NANOS_PER_DAY / quantum) * quantum;
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
    // Rounding the last instants of the day wraps to midnight; keep them.
    time_at(nanosecond.clamp(0, NANOS_PER_DAY - 1))
}

pub fn round_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    // Every unit with every mode, for a tie and for the last instant of the
    // day, which rounds up to midnight.
    for (unit, quantum) in NANOS_PER_UNIT.into_iter().enumerate() {
        for mode in 0..MODES.len() {
            let tie = time_at(13 * 3_600_000_000_000 + quantum / 2 + quantum)?;
            rows.push(round_row(tie, unit, 1, mode));
            rows.push(round_row(Time::MAX, unit, 1, mode));
        }
    }
    // A day cannot be the smallest unit, and neither can anything larger.
    for unit in 6..UNITS.len() {
        rows.push(round_row(time_of((12, 30, 0, 0))?, unit, 1, 6));
    }
    while rows.len() < 450 {
        let unit = usize::try_from(rng.range(0, 5))?;
        let increment = *rng.pick(INCREMENTS[unit]);
        let mode = usize::try_from(rng.range(0, 8))?;
        let quantum = NANOS_PER_UNIT[unit].saturating_mul(increment);
        rows.push(round_row(
            time_near_a_tie(rng, quantum)?,
            unit,
            increment,
            mode,
        ));
    }
    Ok(rows)
}

fn with_row(time: Time, setters: &[Setter]) -> String {
    let mut builder = time.with();
    for &setter in setters {
        builder = match setter {
            Setter::Hour(v) => builder.hour(v),
            Setter::Minute(v) => builder.minute(v),
            Setter::Second(v) => builder.second(v),
            Setter::Millisecond(v) => builder.millisecond(v),
            Setter::Microsecond(v) => builder.microsecond(v),
            Setter::Nanosecond(v) => builder.nanosecond(v),
            Setter::SubsecNanosecond(v) => builder.subsec_nanosecond(v),
        };
    }
    let names: Vec<String> = setters.iter().map(|s| s.name()).collect();
    let names = if names.is_empty() {
        "none".to_owned()
    } else {
        names.join(";")
    };
    row([text::time(time), names, or_err(builder.build(), text::time)])
}

fn arbitrary_setter(rng: &mut Rng) -> Result<Setter> {
    Ok(match rng.range(0, 6) {
        0 => Setter::Hour(i8::try_from(rng.range(-1, 25))?),
        1 => Setter::Minute(i8::try_from(rng.range(-1, 61))?),
        2 => Setter::Second(i8::try_from(rng.range(-1, 61))?),
        3 => Setter::Millisecond(i16::try_from(rng.range(-20, 1_020))?),
        4 => Setter::Microsecond(i16::try_from(rng.range(-20, 1_020))?),
        5 => Setter::Nanosecond(i16::try_from(rng.range(-20, 1_020))?),
        _ => Setter::SubsecNanosecond(i32::try_from(rng.range(-20_000_000, 1_020_000_000))?),
    })
}

pub fn with_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    for &(time, setters) in WITH_EDGES {
        rows.push(with_row(time_of(time)?, setters));
    }
    while rows.len() < 300 {
        let time = gen::time(rng)?;
        let mut setters = Vec::new();
        for _ in 0..rng.range(1, 4) {
            setters.push(arbitrary_setter(rng)?);
        }
        rows.push(with_row(time, &setters));
    }
    Ok(rows)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn time_at_counts_nanoseconds_from_midnight_and_wraps() -> Result<()> {
        assert_eq!(time_at(0)?, Time::MIN);
        assert_eq!(time_at(NANOS_PER_DAY - 1)?, Time::MAX);
        assert_eq!(time_at(NANOS_PER_DAY)?, Time::MIN);
        assert_eq!(time_at(-1)?, Time::MAX);
        assert_eq!(time_at(3_723_000_000_004)?, Time::new(1, 2, 3, 4)?);
        Ok(())
    }

    #[test]
    fn times_near_a_tie_are_valid_for_any_quantum() -> Result<()> {
        let mut rng = Rng::new(5);
        for quantum in [
            -1,
            0,
            1,
            2,
            1_000,
            3_600_000_000_000,
            NANOS_PER_DAY,
            i64::MAX,
        ] {
            for _ in 0..200 {
                time_near_a_tie(&mut rng, quantum)?;
            }
        }
        Ok(())
    }

    #[test]
    fn increments_are_listed_for_every_time_unit() {
        assert_eq!(INCREMENTS.len(), NANOS_PER_UNIT.len());
        assert_eq!(UNITS[5].0, Unit::Hour);
    }
}
