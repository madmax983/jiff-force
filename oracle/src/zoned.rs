//! Vectors for `ZonedDateTime`: span arithmetic, differences, rounding and
//! the calendar helpers, concentrated around changes of offset, where a day
//! can be 23 or 25 hours long and a clock reading can be skipped or repeated.
//!
//! Every value is written as an instant (`secs,nanos`). Together with the
//! zone, which every row names, the instant determines the zoned datetime, so
//! the Apex side never has to trust the port's own printing or parsing.
//!
//! The zones and period are those of `zone.rs`, where the platform's zone
//! data and Jiff's bundled copy agree.

use anyhow::Result;
use jiff::tz::TimeZone;
use jiff::{Span, Timestamp, Unit, ZonedDateTime, ZonedDateTimeRound};

use crate::gen;
use crate::rng::Rng;
use crate::text::{self, or_err, row, MODES, UNITS};
use crate::zone::{self, ZONES};

pub const SPAN_COLUMNS: &str = "zone|instant as secs,nanos|span|instant of zdt + span|\
     instant of zdt - span";

pub const DIFFERENCE_COLUMNS: &str = "zone|a|b|a.until(b) with largest unit YEAR|MONTH|WEEK|\
     DAY|HOUR|NANOSECOND|a.durationUntil(b)  (a and b as secs,nanos in the same zone)";

pub const ROUND_COLUMNS: &str =
    "zone|instant as secs,nanos|smallest unit|increment|mode|instant of the rounded zdt";

pub const CALENDAR_COLUMNS: &str = "zone|instant as secs,nanos|startOfDay|endOfDay|tomorrow|\
     yesterday|firstOfMonth|lastOfMonth  (each as the instant of the result, or ERR)";

/// Spans whose effect depends on the length of the day or month they cross.
const NAMED_SPANS: [(i64, i64, i64, i64); 12] = [
    // (months, days, hours, minutes)
    (0, 1, 0, 0),
    (0, -1, 0, 0),
    (0, 0, 24, 0),
    (0, 0, -24, 0),
    (0, 1, 1, 0),
    (0, 0, 1, 0),
    (0, 0, -1, 0),
    (0, 0, 0, 30),
    (1, 0, 0, 0),
    (-1, 0, 0, 0),
    (0, 7, 0, 0),
    (12, 0, 0, 0),
];

/// How far either side of a transition the probed instants may fall.
const NEAR: i64 = 36 * 3600;

fn zones() -> Result<Vec<(&'static str, TimeZone)>> {
    ZONES
        .iter()
        .map(|&name| Ok((name, TimeZone::get(name)?)))
        .collect()
}

/// An instant near a change of offset in `zone`, or anywhere in the period
/// for a zone without one. Whole minutes most of the time, so that the clock
/// readings line up with the gaps and folds.
fn instant(rng: &mut Rng, zone: &TimeZone) -> Result<Timestamp> {
    let transitions = zone::transitions(zone)?;
    let second = if transitions.is_empty() || rng.range(0, 4) == 0 {
        rng.range(zone::FIRST_SECOND + NEAR, zone::END_SECOND - NEAR)
    } else {
        let transition = rng.pick(&transitions);
        transition.second + rng.range(-NEAR, NEAR)
    };
    let (second, nanos) = match rng.range(0, 3) {
        0 => (second, gen::subsec(rng)),
        1 => (second - second.rem_euclid(60), 0),
        _ => (second - second.rem_euclid(1800), 0),
    };
    Ok(Timestamp::new(second, nanos)?)
}

fn zoned(name: &str, rng: &mut Rng) -> Result<ZonedDateTime> {
    let zone = TimeZone::get(name)?;
    Ok(instant(rng, &zone)?.to_zoned_datetime(zone))
}

fn instant_of(zdt: &ZonedDateTime) -> String {
    text::timestamp(zdt.timestamp())
}

fn span_of(months: i64, days: i64, hours: i64, minutes: i64) -> Result<Span> {
    Ok(Span::new()
        .try_months(months)?
        .try_days(days)?
        .try_hours(hours)?
        .try_minutes(minutes)?)
}

pub fn span_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    for (name, _) in zones()? {
        for &(months, days, hours, minutes) in &NAMED_SPANS {
            for _ in 0..3 {
                let zdt = zoned(name, rng)?;
                let span = span_of(months, days, hours, minutes)?;
                if stays_in_period(&zdt, span) {
                    rows.push(span_row(name, &zdt, span));
                }
            }
        }
    }
    while rows.len() < 600 {
        let name = *rng.pick(&ZONES);
        let zdt = zoned(name, rng)?;
        let span = gen::span(rng, &gen::ALL_UNITS, 3, 400)?;
        if stays_in_period(&zdt, span) {
            rows.push(span_row(name, &zdt, span));
        }
    }
    Ok(rows)
}

/// Whether every result of adding and subtracting `span` that Jiff produces
/// lies in the period where the platform's zone data and Jiff's agree.
fn stays_in_period(zdt: &ZonedDateTime, span: Span) -> bool {
    [zdt.checked_add(span), zdt.checked_sub(span)]
        .into_iter()
        .flatten()
        .all(|result| {
            let second = result.timestamp().as_second();
            (zone::FIRST_SECOND..zone::END_SECOND).contains(&second)
        })
}

fn span_row(name: &str, zdt: &ZonedDateTime, span: Span) -> String {
    row([
        name.to_owned(),
        instant_of(zdt),
        text::span(&span),
        or_err(zdt.checked_add(span), |z| instant_of(&z)),
        or_err(zdt.checked_sub(span), |z| instant_of(&z)),
    ])
}

const DIFFERENCE_UNITS: [Unit; 6] = [
    Unit::Year,
    Unit::Month,
    Unit::Week,
    Unit::Day,
    Unit::Hour,
    Unit::Nanosecond,
];

pub fn difference_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    while rows.len() < 450 {
        let name = *rng.pick(&ZONES);
        let zone = TimeZone::get(name)?;
        let a = instant(rng, &zone)?.to_zoned_datetime(zone.clone());
        // Mostly short distances, which cross one transition, and some long ones.
        let b = if rng.range(0, 3) == 0 {
            instant(rng, &zone)?.to_zoned_datetime(zone)
        } else {
            let seconds = rng.range(-3 * 24 * 3600, 40 * 24 * 3600);
            let b = a.checked_add(Span::new().try_seconds(seconds)?)?;
            if rng.range(0, 2) == 0 {
                b
            } else {
                // Same clock reading on another day, the case where days and
                // hours disagree most.
                b.with().time(a.time()).build()?
            }
        };
        let mut fields = vec![name.to_owned(), instant_of(&a), instant_of(&b)];
        for unit in DIFFERENCE_UNITS {
            fields.push(or_err(a.until((unit, &b)), |s| text::span(&s)));
        }
        fields.push(text::duration(a.duration_until(&b)));
        rows.push(row(fields));
    }
    Ok(rows)
}

/// Increments per smallest unit, nanosecond through day.
const INCREMENTS: [&[i64]; 7] = [
    &[1, 10, 500],
    &[1, 250],
    &[1, 100, 500],
    &[1, 15, 30],
    &[1, 15, 30],
    &[1, 2, 6, 12],
    &[1],
];

pub fn round_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    // Rounding to the day on the days that are not 24 hours long.
    for (name, zone) in zones()? {
        for transition in zone::transitions(&zone)?.iter().take(3) {
            for hour in [-13, -11, -1, 1, 11, 13] {
                let ts = Timestamp::from_second(transition.second + hour * 3600)?;
                for mode in [0, 1, 6, 8] {
                    rows.push(round_row(
                        name,
                        &ts.to_zoned_datetime(zone.clone()),
                        6,
                        1,
                        mode,
                    ));
                }
            }
        }
    }
    // Then every smaller unit, with increments, in every mode.
    let day_rows = rows.len();
    while rows.len() < day_rows * 2 {
        let name = *rng.pick(&ZONES);
        let zdt = zoned(name, rng)?;
        let unit = usize::try_from(rng.range(0, 6))?;
        let increment = *rng.pick(INCREMENTS[unit]);
        let mode = usize::try_from(rng.range(0, 8))?;
        rows.push(round_row(name, &zdt, unit, increment, mode));
    }
    Ok(rows)
}

fn round_row(name: &str, zdt: &ZonedDateTime, unit: usize, increment: i64, mode: usize) -> String {
    let (unit_value, unit_name) = UNITS[unit];
    let (mode_value, mode_name) = MODES[mode];
    let options = ZonedDateTimeRound::new()
        .smallest(unit_value)
        .increment(increment)
        .mode(mode_value);
    row([
        name.to_owned(),
        instant_of(zdt),
        unit_name.to_owned(),
        increment.to_string(),
        mode_name.to_owned(),
        or_err(zdt.round(options), |z| instant_of(&z)),
    ])
}

pub fn calendar_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    while rows.len() < 450 {
        let name = *rng.pick(&ZONES);
        let zdt = zoned(name, rng)?;
        rows.push(row([
            name.to_owned(),
            instant_of(&zdt),
            or_err(zdt.start_of_day(), |z| instant_of(&z)),
            or_err(zdt.end_of_day(), |z| instant_of(&z)),
            or_err(zdt.tomorrow(), |z| instant_of(&z)),
            or_err(zdt.yesterday(), |z| instant_of(&z)),
            or_err(zdt.first_of_month(), |z| instant_of(&z)),
            or_err(zdt.last_of_month(), |z| instant_of(&z)),
        ]));
    }
    Ok(rows)
}
