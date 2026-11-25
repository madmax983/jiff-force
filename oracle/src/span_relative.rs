//! Vectors for the span operations that need to know how long a day or a
//! month is: rounding, totals, comparison and arithmetic relative to a date,
//! a datetime or a zoned datetime (or with days taken as 24 hours), and the
//! rounded `until` of each datetime type.
//!
//! A relative reference is written as one field: `-` for none, `24h` for
//! "days are 24 hours", `D:<date>`, `DT:<datetime>`, or `Z:<zone>:<instant>`
//! with the instant as `secs,nanos`. Zoned references stay within the zones
//! and period of `zone.rs`, where the platform's zone data agrees with Jiff's.

use anyhow::Result;
use jiff::civil::{Date, DateDifference, DateTime, DateTimeDifference};
use jiff::tz::TimeZone;
use jiff::{
    RoundMode, Span, SpanArithmetic, SpanCompare, SpanRelativeTo, SpanRound, SpanTotal, Timestamp,
    TimestampDifference, ZonedDateTime, ZonedDateTimeDifference,
};

use crate::gen;
use crate::rng::Rng;
use crate::text::{self, or_err, row, MODES, UNITS};
use crate::zone::{self, ZONES};

pub const ROUND_COLUMNS: &str = "span|relative|smallest unit|largest unit or -|increment|mode|\
     rounded span or ERR";

pub const TOTAL_COLUMNS: &str = "span|relative|unit|total as a double, or ERR";

pub const COMPARE_COLUMNS: &str = "a|b|relative|a.compare(b) as -1, 0 or 1, or ERR";

pub const ARITHMETIC_COLUMNS: &str = "a|b|relative|a + b|a - b  (spans, or ERR)";

pub const DIFFERENCE_COLUMNS: &str = "kind (D, DT, TS or Z:<zone>)|a|b|largest unit or -|\
     smallest unit or -|increment|mode|a.until(b)|a.since(b)  (dates and datetimes as ISO \
     8601, timestamps and zoned instants as secs,nanos; spans or ERR)";

/// A relative reference, kept with what is needed to write it out.
enum Relative {
    None,
    Days24,
    Date(Date),
    DateTime(DateTime),
    Zoned(&'static str, ZonedDateTime),
}

impl Relative {
    fn text(&self) -> String {
        match self {
            Self::None => "-".to_owned(),
            Self::Days24 => "24h".to_owned(),
            Self::Date(d) => format!("D:{}", text::date(*d)),
            Self::DateTime(dt) => format!("DT:{}", text::datetime(*dt)),
            Self::Zoned(name, zdt) => format!("Z:{name}:{}", text::timestamp(zdt.timestamp())),
        }
    }

    fn get(&self) -> Option<SpanRelativeTo<'_>> {
        match self {
            Self::None => None,
            Self::Days24 => Some(SpanRelativeTo::days_are_24_hours()),
            Self::Date(d) => Some(SpanRelativeTo::from(*d)),
            Self::DateTime(dt) => Some(SpanRelativeTo::from(*dt)),
            Self::Zoned(_, zdt) => Some(SpanRelativeTo::from(zdt)),
        }
    }
}

/// Month ends and leap days, where calendar units are least regular.
const EDGE_DATES: [(i16, i8, i8); 8] = [
    (2024, 1, 31),
    (2024, 2, 29),
    (2023, 2, 28),
    (2024, 3, 31),
    (2023, 12, 31),
    (2000, 2, 29),
    (1999, 12, 31),
    (2024, 7, 15),
];

/// A zoned datetime near a change of offset, in one of the agreed zones.
fn zoned(rng: &mut Rng) -> Result<(&'static str, ZonedDateTime)> {
    let name = *rng.pick(&ZONES);
    let zone = TimeZone::get(name)?;
    let transitions = zone::transitions(&zone)?;
    let second = if transitions.is_empty() || rng.range(0, 3) == 0 {
        rng.range(
            zone::FIRST_SECOND + 86_400 * 400,
            zone::END_SECOND - 86_400 * 400,
        )
    } else {
        rng.pick(&transitions).second + rng.range(-40 * 3600, 40 * 3600)
    };
    let second = second - second.rem_euclid(1800);
    Ok((
        name,
        Timestamp::from_second(second)?.to_zoned_datetime(zone),
    ))
}

fn relative(rng: &mut Rng) -> Result<Relative> {
    Ok(match rng.range(0, 9) {
        0 => Relative::None,
        1 => Relative::Days24,
        2 | 3 => {
            let &(y, m, d) = rng.pick(&EDGE_DATES);
            Relative::Date(Date::new(y, m, d)?)
        }
        4 => Relative::Date(gen::date(rng)?),
        5 | 6 => {
            let &(y, m, d) = rng.pick(&EDGE_DATES);
            Relative::DateTime(Date::new(y, m, d)?.to_datetime(gen::time(rng)?))
        }
        _ => {
            let (name, zdt) = zoned(rng)?;
            Relative::Zoned(name, zdt)
        }
    })
}

/// A span of modest size, so that adding it to a reference stays in range
/// most of the time and the results stay meaningful to check.
fn span(rng: &mut Rng) -> Result<Span> {
    let span = gen::span(rng, &gen::ALL_UNITS, 3, 500)?;
    Ok(span)
}

fn optional_unit(rng: &mut Rng, smallest: usize) -> Option<usize> {
    if rng.range(0, 2) == 0 {
        None
    } else {
        Some(usize::try_from(rng.range(i64::try_from(smallest).unwrap_or(0), 9)).unwrap_or(9))
    }
}

/// Increments that are valid for most units, and some that are not.
const INCREMENTS: [i64; 6] = [1, 1, 1, 2, 5, 15];

pub fn round_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    while rows.len() < 500 {
        let span = span(rng)?;
        let rel = relative(rng)?;
        let smallest = usize::try_from(rng.range(0, 9))?;
        let largest = optional_unit(rng, smallest);
        let increment = *rng.pick(&INCREMENTS);
        let mode = usize::try_from(rng.range(0, 8))?;
        let mut options = SpanRound::new()
            .smallest(UNITS[smallest].0)
            .increment(increment)
            .mode(MODES[mode].0);
        if let Some(largest) = largest {
            options = options.largest(UNITS[largest].0);
        }
        if let Some(r) = rel.get() {
            options = options.relative(r);
        }
        rows.push(row([
            text::span(&span),
            rel.text(),
            UNITS[smallest].1.to_owned(),
            largest.map_or_else(|| "-".to_owned(), |l| UNITS[l].1.to_owned()),
            increment.to_string(),
            MODES[mode].1.to_owned(),
            or_err(span.round(options), |s| text::span(&s)),
        ]));
    }
    Ok(rows)
}

pub fn total_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    while rows.len() < 400 {
        let span = span(rng)?;
        let rel = relative(rng)?;
        let unit = usize::try_from(rng.range(0, 9))?;
        let mut options = SpanTotal::from(UNITS[unit].0);
        if let Some(r) = rel.get() {
            options = options.relative(r);
        }
        rows.push(row([
            text::span(&span),
            rel.text(),
            UNITS[unit].1.to_owned(),
            or_err(span.total(options), |t| format!("{t:?}")),
        ]));
    }
    Ok(rows)
}

pub fn compare_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    while rows.len() < 400 {
        let a = span(rng)?;
        // Often a span of nearly the same length in other units.
        let b = if rng.range(0, 2) == 0 {
            span(rng)?
        } else {
            let unit = usize::try_from(rng.range(3, 9))?;
            a.round(SpanRound::new().smallest(UNITS[unit].0).days_are_24_hours())
                .or_else(|_| span(rng))?
        };
        let rel = relative(rng)?;
        let mut options = SpanCompare::from(b);
        if let Some(r) = rel.get() {
            options = options.relative(r);
        }
        rows.push(row([
            text::span(&a),
            text::span(&b),
            rel.text(),
            or_err(a.compare(options), |o| (o as i8).to_string()),
        ]));
    }
    Ok(rows)
}

pub fn arithmetic_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    while rows.len() < 400 {
        let a = span(rng)?;
        let b = span(rng)?;
        let rel = relative(rng)?;
        let add = rel.get().map_or_else(
            || a.checked_add(SpanArithmetic::from(b)),
            |r| a.checked_add(SpanArithmetic::from(b).relative(r)),
        );
        let sub = rel.get().map_or_else(
            || a.checked_sub(SpanArithmetic::from(b)),
            |r| a.checked_sub(SpanArithmetic::from(b).relative(r)),
        );
        rows.push(row([
            text::span(&a),
            text::span(&b),
            rel.text(),
            or_err(add, |s| text::span(&s)),
            or_err(sub, |s| text::span(&s)),
        ]));
    }
    Ok(rows)
}

/// The settings of one rounded difference.
struct Settings {
    largest: Option<usize>,
    smallest: Option<usize>,
    increment: i64,
    mode: usize,
}

impl Settings {
    fn draw(rng: &mut Rng, finest: usize) -> Result<Self> {
        let smallest = if rng.range(0, 3) == 0 {
            None
        } else {
            Some(usize::try_from(rng.range(i64::try_from(finest)?, 9))?)
        };
        let largest = optional_unit(rng, smallest.unwrap_or(finest));
        Ok(Self {
            largest,
            smallest,
            increment: *rng.pick(&INCREMENTS),
            mode: usize::try_from(rng.range(0, 8))?,
        })
    }

    fn unit(index: Option<usize>) -> String {
        index.map_or_else(|| "-".to_owned(), |i| UNITS[i].1.to_owned())
    }

    fn fields(&self) -> [String; 4] {
        [
            Self::unit(self.largest),
            Self::unit(self.smallest),
            self.increment.to_string(),
            MODES[self.mode].1.to_owned(),
        ]
    }

    const fn mode(&self) -> RoundMode {
        MODES[self.mode].0
    }
}

/// Applies the settings to any of the difference builders, which share
/// their method names but not a trait.
macro_rules! configure {
    ($builder:expr, $settings:expr) => {{
        let mut builder = $builder
            .increment($settings.increment)
            .mode($settings.mode());
        if let Some(largest) = $settings.largest {
            builder = builder.largest(UNITS[largest].0);
        }
        if let Some(smallest) = $settings.smallest {
            builder = builder.smallest(UNITS[smallest].0);
        }
        builder
    }};
}

pub fn difference_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    while rows.len() < 480 {
        match rows.len() % 4 {
            0 => {
                let &(year, month, day) = rng.pick(&EDGE_DATES);
                let start = Date::new(year, month, day)?;
                let end = start.checked_add(Span::new().try_days(rng.range(-800, 800))?)?;
                let settings = Settings::draw(rng, 6)?;
                let until = start.until(configure!(DateDifference::new(end), settings));
                let since = start.since(configure!(DateDifference::new(end), settings));
                let [largest, smallest, increment, mode] = settings.fields();
                rows.push(row([
                    "D".to_owned(),
                    text::date(start),
                    text::date(end),
                    largest,
                    smallest,
                    increment,
                    mode,
                    or_err(until, |span| text::span(&span)),
                    or_err(since, |span| text::span(&span)),
                ]));
            }
            1 => {
                let &(year, month, day) = rng.pick(&EDGE_DATES);
                let start = Date::new(year, month, day)?.to_datetime(gen::time(rng)?);
                let end =
                    start.checked_add(Span::new().try_minutes(rng.range(-600_000, 600_000))?)?;
                let settings = Settings::draw(rng, 0)?;
                let until = start.until(configure!(DateTimeDifference::new(end), settings));
                let since = start.since(configure!(DateTimeDifference::new(end), settings));
                let [largest, smallest, increment, mode] = settings.fields();
                rows.push(row([
                    "DT".to_owned(),
                    text::datetime(start),
                    text::datetime(end),
                    largest,
                    smallest,
                    increment,
                    mode,
                    or_err(until, |span| text::span(&span)),
                    or_err(since, |span| text::span(&span)),
                ]));
            }
            2 => {
                let start = Timestamp::new(rng.range(0, 2_000_000_000), gen::subsec(rng))?;
                let end = start
                    .checked_add(Span::new().try_seconds(rng.range(-9_000_000, 9_000_000))?)?;
                // Timestamps have no calendar units; keep to what they allow.
                let settings = Settings::draw(rng, 0)?;
                let settings = Settings {
                    largest: settings.largest.map(|unit| unit.min(5)),
                    smallest: settings.smallest.map(|unit| unit.min(5)),
                    ..settings
                };
                let until = start.until(configure!(TimestampDifference::new(end), settings));
                let since = start.since(configure!(TimestampDifference::new(end), settings));
                let [largest, smallest, increment, mode] = settings.fields();
                rows.push(row([
                    "TS".to_owned(),
                    text::timestamp(start),
                    text::timestamp(end),
                    largest,
                    smallest,
                    increment,
                    mode,
                    or_err(until, |span| text::span(&span)),
                    or_err(since, |span| text::span(&span)),
                ]));
            }
            _ => {
                let (name, start) = zoned(rng)?;
                let end =
                    start.checked_add(Span::new().try_minutes(rng.range(-200_000, 200_000))?)?;
                let settings = Settings::draw(rng, 0)?;
                let until = start.until(configure!(ZonedDateTimeDifference::new(&end), settings));
                let since = start.since(configure!(ZonedDateTimeDifference::new(&end), settings));
                let [largest, smallest, increment, mode] = settings.fields();
                rows.push(row([
                    format!("Z:{name}"),
                    text::timestamp(start.timestamp()),
                    text::timestamp(end.timestamp()),
                    largest,
                    smallest,
                    increment,
                    mode,
                    or_err(until, |span| text::span(&span)),
                    or_err(since, |span| text::span(&span)),
                ]));
            }
        }
    }
    Ok(rows)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn writes_each_kind_of_relative_reference() -> Result<()> {
        let date = Date::new(2024, 2, 29)?;
        assert_eq!(Relative::None.text(), "-");
        assert_eq!(Relative::Days24.text(), "24h");
        assert_eq!(Relative::Date(date).text(), "D:2024-02-29");
        assert_eq!(
            Relative::DateTime(date.to_datetime(jiff::civil::Time::midnight())).text(),
            "DT:2024-02-29T00:00:00"
        );
        let zdt = Timestamp::from_second(0)?.to_zoned_datetime(TimeZone::UTC);
        assert_eq!(Relative::Zoned("UTC", zdt).text(), "Z:UTC:0,0");
        Ok(())
    }
}
