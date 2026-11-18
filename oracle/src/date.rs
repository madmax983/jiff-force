//! Vectors for civil date arithmetic, differences, calendar queries, ISO week
//! dates and the `with` builder.

use anyhow::Result;
use jiff::civil::{Date, Era, ISOWeekDate, Weekday};
use jiff::{SignedDuration, Span, Unit};

use crate::gen::{self, UnitValues};
use crate::rng::Rng;
use crate::text::{self, or_err, or_none, row};

pub const SPAN_COLUMNS: &str =
    "date|span|date + span|date - span|saturating sum|saturating difference  (ERR = error)";

pub const DURATION_COLUMNS: &str = "date|duration as secs,nanos|date + duration|\
     date - duration|saturating sum|saturating difference  (ERR = error)";

pub const DIFFERENCE_COLUMNS: &str = "a|b|a.until(b) with largest unit DAY|WEEK|MONTH|YEAR|\
     a.since(b) with largest unit DAY|WEEK|MONTH|YEAR|a.durationUntil(b) as secs,nanos|\
     a.until(b) with largest unit HOUR";

pub const CALENDAR_COLUMNS: &str = "date|dayOfYear|dayOfYearNoLeap or NONE|firstOfMonth|\
     lastOfMonth|firstOfYear|lastOfYear|tomorrow|yesterday|ISO week date as year,week,weekday|\
     daysInYear|eraYear,era";

pub const WEEKDAY_COLUMNS: &str = "date|weekday (0 = Monday)|nth|nthWeekday(nth, weekday)|\
     nth of month|nthWeekdayOfMonth(nth of month, weekday)  (ERR = error)";

pub const WEEK_DATE_COLUMNS: &str = "year|week|weekday (0 = Monday)|date or ERR|weeksInYear|\
     daysInYear|firstOfWeek|lastOfWeek|firstOfYear|lastOfYear|tomorrow|yesterday  \
     (week dates are year,week,weekday; a row whose date is ERR stops there)";

pub const WITH_COLUMNS: &str = "date|setters applied in order, separated by ';'|built date or ERR";

/// A date as year, month and day.
type Ymd = (i16, i8, i8);

/// Pairs of a date and a span whose sum is worth pinning by name: month end
/// clamping, leap days, the limits of the range and spans with time units.
const SPAN_EDGES: &[(Ymd, &UnitValues)] = &[
    ((2024, 2, 29), &[(0, 1)]),
    ((2024, 2, 29), &[(0, 4)]),
    ((2024, 2, 29), &[(0, -1)]),
    ((2023, 2, 28), &[(0, 1)]),
    ((2024, 1, 31), &[(1, 1)]),
    ((2023, 1, 31), &[(1, 1)]),
    ((2024, 3, 31), &[(1, -1)]),
    ((2024, 5, 31), &[(1, 1)]),
    ((2024, 12, 31), &[(1, 2)]),
    ((2024, 10, 31), &[(1, 13)]),
    ((2024, 1, 31), &[(1, 1), (3, 1)]),
    ((2024, 1, 31), &[(1, 1), (3, 30)]),
    ((2024, 3, 1), &[(1, -1), (3, -1)]),
    ((2024, 2, 29), &[(0, 1), (1, 12)]),
    ((2021, 12, 31), &[(2, 1)]),
    ((2021, 12, 31), &[(2, 52), (3, 1)]),
    ((2024, 2, 28), &[(3, 1)]),
    ((2024, 2, 28), &[(3, 2)]),
    ((2023, 2, 28), &[(3, 1)]),
    ((2024, 3, 1), &[(3, -1)]),
    ((1970, 1, 1), &[(3, -1)]),
    ((1970, 1, 1), &[(3, 7_304_484)]),
    ((9999, 12, 31), &[(3, 1)]),
    ((9999, 12, 31), &[(3, -1)]),
    ((9999, 12, 31), &[(3, 0)]),
    ((-9999, 1, 1), &[(3, -1)]),
    ((-9999, 1, 1), &[(3, 1)]),
    ((-9999, 1, 1), &[(3, 7_304_483)]),
    ((-9999, 1, 1), &[(3, 7_304_484)]),
    ((9999, 12, 31), &[(3, -7_304_483)]),
    ((9999, 12, 31), &[(3, -7_304_484)]),
    ((-9999, 1, 1), &[(0, 19_998)]),
    ((-9999, 1, 1), &[(0, 19_998), (1, 11), (3, 30)]),
    ((-9999, 1, 1), &[(0, 19_998), (1, 11), (3, 31)]),
    ((9999, 12, 31), &[(0, -19_998)]),
    ((-9999, 1, 1), &[(1, 239_976)]),
    ((-9999, 1, 1), &[(1, 239_975)]),
    ((-9999, 1, 1), &[(2, 1_043_497)]),
    ((-9999, 1, 1), &[(2, 1_043_496)]),
    ((9999, 1, 1), &[(0, 1)]),
    ((9999, 12, 1), &[(1, 1)]),
    ((2024, 6, 15), &[(4, 23)]),
    ((2024, 6, 15), &[(4, 24)]),
    ((2024, 6, 15), &[(4, 25)]),
    ((2024, 6, 15), &[(4, -1)]),
    ((2024, 6, 15), &[(4, -24)]),
    ((2024, 6, 15), &[(4, -47)]),
    ((2024, 6, 15), &[(4, 48)]),
    ((2024, 6, 15), &[(5, 1_439)]),
    ((2024, 6, 15), &[(5, 1_440)]),
    ((2024, 6, 15), &[(6, 86_399)]),
    ((2024, 6, 15), &[(6, 86_400)]),
    ((2024, 6, 15), &[(7, 86_400_000)]),
    ((2024, 6, 15), &[(8, 86_400_000_000)]),
    ((2024, 6, 15), &[(9, 86_399_999_999_999)]),
    ((2024, 6, 15), &[(9, 86_400_000_000_000)]),
    ((2024, 6, 15), &[(9, -86_400_000_000_000)]),
    ((2024, 6, 15), &[(4, 12), (5, 720)]),
    (
        (2024, 6, 15),
        &[(4, 23), (5, 59), (6, 59), (9, 999_999_999)],
    ),
    (
        (2024, 6, 15),
        &[(4, 23), (5, 59), (6, 59), (9, 1_000_000_000)],
    ),
    ((2024, 6, 15), &[(3, 1), (4, 24)]),
    ((2024, 6, 15), &[(1, 1), (4, 36)]),
    ((2024, 6, 15), &[(4, 175_307_616)]),
    ((2024, 6, 15), &[(9, i64::MAX)]),
    ((2024, 6, 15), &[(9, -i64::MAX)]),
    ((9999, 12, 31), &[(4, 23)]),
    ((9999, 12, 31), &[(4, 24)]),
    ((-9999, 1, 1), &[(4, -1)]),
    ((-9999, 1, 1), &[(4, -24)]),
    ((2024, 6, 15), &[]),
];

/// Durations, in seconds and nanoseconds, added to every kind of date.
const DURATION_EDGES: &[(i64, i32)] = &[
    (0, 0),
    (0, 1),
    (0, -1),
    (86_399, 999_999_999),
    (86_400, 0),
    (86_400, 1),
    (-86_399, -999_999_999),
    (-86_400, 0),
    (-86_400, -1),
    (172_799, 0),
    (172_800, 0),
    (-172_800, 0),
    (31_622_400, 0),
    (631_107_331_200, 0),
    (631_107_417_599, 999_999_999),
    (631_107_417_600, 0),
    (-631_107_331_200, 0),
    (-631_107_417_600, 0),
    (i64::MAX, 999_999_999),
    (i64::MIN, -999_999_999),
    (i64::MIN, 0),
    (i64::MAX, 0),
];

/// Pairs of dates whose difference depends on month lengths or leap days.
const DIFFERENCE_EDGES: &[(Ymd, Ymd)] = &[
    ((2024, 1, 31), (2024, 2, 29)),
    ((2024, 2, 29), (2024, 1, 31)),
    ((2024, 1, 31), (2024, 3, 1)),
    ((2024, 3, 31), (2024, 2, 29)),
    ((2024, 3, 30), (2024, 2, 29)),
    ((2023, 1, 31), (2023, 2, 28)),
    ((2023, 1, 31), (2023, 3, 1)),
    ((2024, 2, 29), (2025, 2, 28)),
    ((2024, 2, 29), (2025, 3, 1)),
    ((2024, 2, 29), (2028, 2, 29)),
    ((2025, 2, 28), (2024, 2, 29)),
    ((2024, 2, 29), (2023, 2, 28)),
    ((2024, 2, 29), (2023, 3, 1)),
    ((2020, 12, 31), (2021, 1, 1)),
    ((2021, 1, 1), (2020, 12, 31)),
    ((2021, 1, 1), (2021, 12, 31)),
    ((2021, 1, 1), (2022, 1, 1)),
    ((2021, 12, 31), (2021, 1, 1)),
    ((2024, 5, 31), (2024, 6, 30)),
    ((2024, 6, 30), (2024, 5, 31)),
    ((2024, 5, 31), (2024, 7, 1)),
    ((2024, 7, 31), (2024, 6, 30)),
    ((2024, 8, 31), (2024, 2, 29)),
    ((2024, 8, 30), (2025, 2, 28)),
    ((2024, 8, 31), (2025, 2, 28)),
    ((1970, 1, 1), (1970, 1, 1)),
    ((1970, 1, 1), (1970, 1, 8)),
    ((1970, 1, 8), (1970, 1, 1)),
    ((1970, 1, 1), (1970, 1, 7)),
    ((1969, 12, 31), (1970, 1, 1)),
    ((-9999, 1, 1), (9999, 12, 31)),
    ((9999, 12, 31), (-9999, 1, 1)),
    ((-9999, 1, 1), (-9999, 1, 2)),
    ((9999, 12, 31), (9999, 12, 30)),
    ((-9999, 12, 31), (9999, 1, 1)),
    ((0, 1, 1), (-1, 12, 31)),
    ((0, 2, 29), (1, 2, 28)),
    ((1900, 2, 28), (1900, 3, 1)),
    ((2000, 2, 28), (2000, 3, 1)),
    ((2100, 2, 28), (2100, 3, 1)),
];

/// Setter sequences for the `with` builder whose outcome depends on which
/// setter wins or on whether the result exists.
const WITH_EDGES: &[(Ymd, &[Setter])] = &[
    ((2024, 2, 29), &[]),
    ((2024, 2, 29), &[Setter::Year(2023)]),
    ((2024, 2, 29), &[Setter::Year(2028)]),
    ((2024, 2, 29), &[Setter::Year(2023), Setter::Day(28)]),
    ((2024, 10, 31), &[Setter::Month(11)]),
    ((2024, 10, 31), &[Setter::Month(11), Setter::Day(30)]),
    ((2024, 10, 31), &[Setter::Month(12)]),
    ((2024, 10, 31), &[Setter::Month(0)]),
    ((2024, 10, 31), &[Setter::Month(13)]),
    ((2024, 10, 31), &[Setter::Month(-1)]),
    ((2024, 10, 31), &[Setter::Day(0)]),
    ((2024, 10, 31), &[Setter::Day(32)]),
    ((2024, 10, 31), &[Setter::Day(-1)]),
    ((2024, 2, 1), &[Setter::Day(29)]),
    ((2023, 2, 1), &[Setter::Day(29)]),
    ((2024, 2, 1), &[Setter::Day(30)]),
    ((2024, 4, 1), &[Setter::Day(31)]),
    ((2024, 1, 1), &[Setter::Year(9999)]),
    ((2024, 1, 1), &[Setter::Year(-9999)]),
    ((2024, 1, 1), &[Setter::Year(10_000)]),
    ((2024, 1, 1), &[Setter::Year(-10_000)]),
    ((2024, 1, 1), &[Setter::Year(i16::MAX)]),
    ((2024, 1, 1), &[Setter::Year(i16::MIN)]),
    ((2024, 1, 1), &[Setter::Year(0)]),
    ((2024, 1, 1), &[Setter::Year(2000), Setter::Year(2001)]),
    ((2024, 1, 1), &[Setter::Month(13), Setter::Month(2)]),
    ((2024, 1, 1), &[Setter::Day(40), Setter::Day(4)]),
    ((2024, 1, 1), &[Setter::EraYear(1, Era::CE)]),
    ((2024, 1, 1), &[Setter::EraYear(0, Era::CE)]),
    ((2024, 1, 1), &[Setter::EraYear(9999, Era::CE)]),
    ((2024, 1, 1), &[Setter::EraYear(10_000, Era::CE)]),
    ((2024, 1, 1), &[Setter::EraYear(-1, Era::CE)]),
    ((2024, 1, 1), &[Setter::EraYear(1, Era::BCE)]),
    ((2024, 1, 1), &[Setter::EraYear(0, Era::BCE)]),
    ((2024, 1, 1), &[Setter::EraYear(509, Era::BCE)]),
    ((2024, 1, 1), &[Setter::EraYear(10_000, Era::BCE)]),
    ((2024, 1, 1), &[Setter::EraYear(10_001, Era::BCE)]),
    ((2024, 1, 1), &[Setter::EraYear(-1, Era::BCE)]),
    ((2024, 2, 29), &[Setter::EraYear(5, Era::BCE)]),
    ((2024, 2, 29), &[Setter::EraYear(4, Era::BCE)]),
    (
        (2024, 1, 1),
        &[Setter::Year(1999), Setter::EraYear(5, Era::BCE)],
    ),
    (
        (2024, 1, 1),
        &[Setter::EraYear(5, Era::BCE), Setter::Year(1999)],
    ),
    (
        (2024, 1, 1),
        &[Setter::EraYear(0, Era::CE), Setter::Year(1999)],
    ),
    ((2024, 1, 1), &[Setter::DayOfYear(1)]),
    ((2024, 1, 1), &[Setter::DayOfYear(60)]),
    ((2023, 1, 1), &[Setter::DayOfYear(60)]),
    ((2024, 1, 1), &[Setter::DayOfYear(366)]),
    ((2023, 1, 1), &[Setter::DayOfYear(366)]),
    ((2023, 1, 1), &[Setter::DayOfYear(365)]),
    ((2024, 1, 1), &[Setter::DayOfYear(367)]),
    ((2024, 1, 1), &[Setter::DayOfYear(0)]),
    ((2024, 1, 1), &[Setter::DayOfYear(-1)]),
    ((2024, 1, 1), &[Setter::DayOfYearNoLeap(1)]),
    ((2024, 1, 1), &[Setter::DayOfYearNoLeap(59)]),
    ((2024, 1, 1), &[Setter::DayOfYearNoLeap(60)]),
    ((2023, 1, 1), &[Setter::DayOfYearNoLeap(60)]),
    ((2024, 1, 1), &[Setter::DayOfYearNoLeap(365)]),
    ((2024, 1, 1), &[Setter::DayOfYearNoLeap(366)]),
    ((2024, 1, 1), &[Setter::DayOfYearNoLeap(0)]),
    ((2024, 7, 4), &[Setter::DayOfYear(60), Setter::Month(12)]),
    ((2024, 7, 4), &[Setter::Month(13), Setter::DayOfYear(60)]),
    ((2024, 7, 4), &[Setter::DayOfYear(60), Setter::Day(9)]),
    ((2024, 7, 4), &[Setter::Day(9), Setter::DayOfYear(60)]),
    ((2024, 7, 4), &[Setter::DayOfYear(400), Setter::Day(9)]),
    (
        (2024, 7, 4),
        &[Setter::DayOfYear(60), Setter::DayOfYearNoLeap(60)],
    ),
    (
        (2024, 7, 4),
        &[Setter::DayOfYearNoLeap(60), Setter::DayOfYear(60)],
    ),
    ((2024, 7, 4), &[Setter::Year(2023), Setter::DayOfYear(366)]),
    ((2023, 7, 4), &[Setter::Year(2024), Setter::DayOfYear(366)]),
    ((9999, 12, 31), &[Setter::DayOfYear(365)]),
    ((-9999, 1, 1), &[Setter::DayOfYearNoLeap(365)]),
];

/// One call on Jiff's `DateWith` builder.
#[derive(Clone, Copy)]
enum Setter {
    Year(i16),
    EraYear(i16, Era),
    Month(i8),
    Day(i8),
    DayOfYear(i16),
    DayOfYearNoLeap(i16),
}

impl Setter {
    fn name(self) -> String {
        match self {
            Self::Year(year) => format!("year={year}"),
            Self::EraYear(year, Era::CE) => format!("eraYear={year}:CE"),
            Self::EraYear(year, Era::BCE) => format!("eraYear={year}:BCE"),
            Self::Month(month) => format!("month={month}"),
            Self::Day(day) => format!("day={day}"),
            Self::DayOfYear(day) => format!("dayOfYear={day}"),
            Self::DayOfYearNoLeap(day) => format!("dayOfYearNoLeap={day}"),
        }
    }
}

fn weekday_at(index: i64) -> Weekday {
    Weekday::Monday.wrapping_add(index)
}

fn span_row(date: Date, span: Span) -> String {
    row([
        text::date(date),
        text::span(&span),
        or_err(date.checked_add(span), text::date),
        or_err(date.checked_sub(span), text::date),
        text::date(date.saturating_add(span)),
        text::date(date.saturating_sub(span)),
    ])
}

pub fn span_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    for &((year, month, day), units) in SPAN_EDGES {
        rows.push(span_row(Date::new(year, month, day)?, gen::span_of(units)?));
    }
    while rows.len() < 320 {
        let date = gen::date(rng)?;
        // Mostly calendar units of a size that keeps the sum in range, with
        // a share of time units and of spans large enough to overflow.
        let span = match rng.range(0, 9) {
            0..=4 => gen::span(rng, &gen::CALENDAR_UNITS, 3, 400)?,
            5..=6 => gen::span(rng, &gen::ALL_UNITS, 4, 100_000)?,
            7 => gen::span(rng, &gen::TIME_UNITS, 2, i64::MAX)?,
            _ => gen::span(rng, &gen::CALENDAR_UNITS, 2, i64::MAX)?,
        };
        rows.push(span_row(date, span));
    }
    Ok(rows)
}

fn duration_row(date: Date, duration: SignedDuration) -> String {
    row([
        text::date(date),
        text::duration(duration),
        or_err(date.checked_add(duration), text::date),
        or_err(date.checked_sub(duration), text::date),
        text::date(date.saturating_add(duration)),
        text::date(date.saturating_sub(duration)),
    ])
}

pub fn duration_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    for &(year, month, day) in &[(2024, 2, 28), (1970, 1, 1), (-9999, 1, 1), (9999, 12, 31)] {
        let date = Date::new(year, month, day)?;
        for &(secs, nanos) in DURATION_EDGES {
            rows.push(duration_row(date, SignedDuration::new(secs, nanos)));
        }
    }
    while rows.len() < 300 {
        // Durations of any size mostly overflow, so most are kept to a few
        // years, with a fraction that must not carry into the date.
        let duration = if rng.range(0, 2) == 0 {
            gen::duration(rng)
        } else {
            SignedDuration::new(rng.range(-90_000_000, 90_000_000), gen::subsec(rng))
        };
        rows.push(duration_row(gen::date(rng)?, duration));
    }
    Ok(rows)
}

fn difference_row(a: Date, b: Date) -> String {
    let largest = [Unit::Day, Unit::Week, Unit::Month, Unit::Year];
    let show = |span: Span| text::span(&span);
    let mut fields = vec![text::date(a), text::date(b)];
    fields.extend(largest.iter().map(|&unit| or_err(a.until((unit, b)), show)));
    fields.extend(largest.iter().map(|&unit| or_err(a.since((unit, b)), show)));
    fields.push(text::duration(a.duration_until(b)));
    fields.push(or_err(a.until((Unit::Hour, b)), show));
    row(fields)
}

pub fn difference_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    for &((y1, m1, d1), (y2, m2, d2)) in DIFFERENCE_EDGES {
        rows.push(difference_row(
            Date::new(y1, m1, d1)?,
            Date::new(y2, m2, d2)?,
        ));
    }
    while rows.len() < 300 {
        let a = gen::date(rng)?;
        // Half the pairs are close together, where the months and days of
        // the two dates interact; the rest are anywhere.
        let b = if rng.range(0, 1) == 0 {
            a.saturating_add(Span::new().try_days(rng.range(-800, 800))?)
        } else {
            gen::date(rng)?
        };
        rows.push(difference_row(a, b));
    }
    Ok(rows)
}

fn calendar_row(date: Date) -> String {
    let (era_year, era) = date.era_year();
    let era = match era {
        Era::CE => "CE",
        Era::BCE => "BCE",
    };
    row([
        text::date(date),
        date.day_of_year().to_string(),
        or_none(date.day_of_year_no_leap(), |day| day.to_string()),
        text::date(date.first_of_month()),
        text::date(date.last_of_month()),
        text::date(date.first_of_year()),
        text::date(date.last_of_year()),
        or_err(date.tomorrow(), text::date),
        or_err(date.yesterday(), text::date),
        text::week_date(date.iso_week_date()),
        date.days_in_year().to_string(),
        format!("{era_year},{era}"),
    ])
}

pub fn calendar_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut dates = vec![Date::MIN, Date::MAX];
    // The days around every new year from 2019 to 2027 cover all seven
    // weekdays for January 1st, and so every way an ISO week year can start.
    for year in 2019..=2027 {
        for (month, day) in [(1, 1), (1, 2), (1, 3), (1, 4), (2, 28), (3, 1)] {
            dates.push(Date::new(year, month, day)?);
        }
        for day in 27..=31 {
            dates.push(Date::new(year, 12, day)?);
        }
    }
    for year in [-9999, -4, 0, 1, 4, 1900, 2000, 9999] {
        for (month, day) in [(1, 1), (12, 31), (2, 28), (3, 1), (6, 15)] {
            dates.push(Date::new(year, month, day)?);
        }
    }
    while dates.len() < 300 {
        dates.push(gen::date(rng)?);
    }
    Ok(dates.into_iter().map(calendar_row).collect())
}

fn weekday_row(date: Date, weekday: Weekday, nth: i32, nth_of_month: i8) -> String {
    row([
        text::date(date),
        text::weekday(weekday),
        nth.to_string(),
        or_err(date.nth_weekday(nth, weekday), text::date),
        nth_of_month.to_string(),
        or_err(date.nth_weekday_of_month(nth_of_month, weekday), text::date),
    ])
}

pub fn weekday_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    // Every weekday and every small `nth` from two dates a few days apart,
    // so that each case of "is the start itself the weekday" is hit.
    for (year, month, day) in [(2024, 3, 1), (2024, 2, 5)] {
        let date = Date::new(year, month, day)?;
        for index in 0..7 {
            for nth in -6..=6_i8 {
                rows.push(weekday_row(date, weekday_at(index), i32::from(nth), nth));
            }
        }
    }
    for (year, month, day) in [(-9999, 1, 1), (9999, 12, 31), (9999, 12, 1), (-9999, 1, 31)] {
        let date = Date::new(year, month, day)?;
        for index in [0, 3, 6] {
            for (nth, nth_of_month) in [(1, 1), (-1, -1), (2, 5), (-2, -5), (0, 0)] {
                rows.push(weekday_row(date, weekday_at(index), nth, nth_of_month));
            }
        }
    }
    let far = [
        (1_043_497, i8::MAX),
        (-1_043_497, i8::MIN),
        (1_043_498, 7),
        (i32::MAX, -7),
        (i32::MIN, 53),
    ];
    for (nth, nth_of_month) in far {
        rows.push(weekday_row(
            Date::new(-9999, 1, 1)?,
            Weekday::Monday,
            nth,
            nth_of_month,
        ));
        rows.push(weekday_row(
            Date::new(9999, 12, 31)?,
            Weekday::Friday,
            nth,
            nth_of_month,
        ));
        rows.push(weekday_row(
            Date::new(2024, 6, 15)?,
            Weekday::Sunday,
            nth,
            nth_of_month,
        ));
    }
    while rows.len() < 400 {
        let date = gen::date(rng)?;
        let weekday = weekday_at(rng.range(0, 6));
        let nth = match rng.range(0, 9) {
            0..=6 => rng.range(-60, 60),
            7..=8 => rng.range(-20_000, 20_000),
            _ => rng.range(-1_100_000, 1_100_000),
        };
        let nth_of_month = rng.range(-6, 6);
        rows.push(weekday_row(
            date,
            weekday,
            i32::try_from(nth)?,
            i8::try_from(nth_of_month)?,
        ));
    }
    Ok(rows)
}

fn week_date_row(year: i16, week: i8, weekday: Weekday) -> String {
    let head = [year.to_string(), week.to_string(), text::weekday(weekday)];
    let Ok(week_date) = ISOWeekDate::new(year, week, weekday) else {
        return row(head.into_iter().chain([text::ERR.to_owned()]));
    };
    row(head.into_iter().chain([
        text::date(week_date.date()),
        week_date.weeks_in_year().to_string(),
        week_date.days_in_year().to_string(),
        or_err(week_date.first_of_week(), text::week_date),
        or_err(week_date.last_of_week(), text::week_date),
        or_err(week_date.first_of_year(), text::week_date),
        or_err(week_date.last_of_year(), text::week_date),
        or_err(week_date.tomorrow(), text::week_date),
        or_err(week_date.yesterday(), text::week_date),
    ]))
}

pub fn week_date_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    // Week 1, 52 and 53 of years that start on each weekday, long and short.
    for year in 2015..=2027_i16 {
        for (week, index) in [(1, 0), (1, 6), (52, 0), (52, 6), (53, 0), (53, 6)] {
            rows.push(week_date_row(year, week, weekday_at(index)));
        }
    }
    for year in [-9999, 9999_i16] {
        for week in [1, 2, 51, 52, 53_i8] {
            for index in [0, 1, 4, 5, 6] {
                rows.push(week_date_row(year, week, weekday_at(index)));
            }
        }
    }
    for (year, week) in [
        (2024, 0),
        (2024, -1),
        (2024, 54),
        (2024, i8::MAX),
        (10_000, 1),
        (-10_000, 1),
        (i16::MAX, 1),
        (i16::MIN, 52),
        (0, 1),
        (0, 53),
        (-1, 52),
        (-1, 53),
    ] {
        rows.push(week_date_row(year, week, Weekday::Thursday));
    }
    while rows.len() < 320 {
        let year = i16::try_from(rng.range(-9999, 9999))?;
        let week = i8::try_from(if rng.range(0, 4) == 0 {
            rng.range(50, 54)
        } else {
            rng.range(1, 52)
        })?;
        rows.push(week_date_row(year, week, weekday_at(rng.range(0, 6))));
    }
    Ok(rows)
}

fn with_row(date: Date, setters: &[Setter]) -> String {
    let mut builder = date.with();
    for &setter in setters {
        builder = match setter {
            Setter::Year(year) => builder.year(year),
            Setter::EraYear(year, era) => builder.era_year(year, era),
            Setter::Month(month) => builder.month(month),
            Setter::Day(day) => builder.day(day),
            Setter::DayOfYear(day) => builder.day_of_year(day),
            Setter::DayOfYearNoLeap(day) => builder.day_of_year_no_leap(day),
        };
    }
    let names: Vec<String> = setters.iter().map(|s| s.name()).collect();
    let names = if names.is_empty() {
        "none".to_owned()
    } else {
        names.join(";")
    };
    row([text::date(date), names, or_err(builder.build(), text::date)])
}

fn arbitrary_setter(rng: &mut Rng) -> Result<Setter> {
    Ok(match rng.range(0, 11) {
        0..=2 => Setter::Year(i16::try_from(match rng.range(0, 5) {
            0 => rng.range(-10_050, 10_050),
            _ => rng.range(1890, 2110),
        })?),
        3 => Setter::EraYear(
            i16::try_from(rng.range(-5, 10_005))?,
            if rng.range(0, 1) == 0 {
                Era::CE
            } else {
                Era::BCE
            },
        ),
        4..=6 => Setter::Month(i8::try_from(rng.range(0, 13))?),
        7..=9 => Setter::Day(i8::try_from(match rng.range(0, 2) {
            0 => rng.range(27, 32),
            _ => rng.range(0, 31),
        })?),
        10 => Setter::DayOfYear(i16::try_from(rng.range(0, 367))?),
        _ => Setter::DayOfYearNoLeap(i16::try_from(rng.range(0, 366))?),
    })
}

pub fn with_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    for &((year, month, day), setters) in WITH_EDGES {
        rows.push(with_row(Date::new(year, month, day)?, setters));
    }
    while rows.len() < 300 {
        let date = gen::date(rng)?;
        let mut setters = Vec::new();
        for _ in 0..rng.range(1, 3) {
            setters.push(arbitrary_setter(rng)?);
        }
        rows.push(with_row(date, &setters));
    }
    Ok(rows)
}
