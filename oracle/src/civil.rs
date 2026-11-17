//! Vectors for civil dates: construction, epoch days, weekday and printing.

use anyhow::Result;
use jiff::civil::{date, Date};

use crate::rng::Rng;

pub const COLUMNS: &str =
    "year|month|day|epochDay|weekday (0 = Monday)|dayOfYear|leapYear (0 or 1)|daysInMonth|text";

/// Dates worth checking by name: range limits, the epoch, and every kind of
/// month and leap year boundary.
const EDGES: &[(i16, i8, i8)] = &[
    (-9999, 1, 1),
    (9999, 12, 31),
    (0, 1, 1),
    (0, 2, 29),
    (0, 12, 31),
    (1, 1, 1),
    (-1, 12, 31),
    (-4, 2, 29),
    (-100, 3, 1),
    (-400, 2, 29),
    (1969, 12, 31),
    (1970, 1, 1),
    (1970, 1, 2),
    (1600, 2, 29),
    (1700, 2, 28),
    (1900, 2, 28),
    (1900, 3, 1),
    (2000, 2, 29),
    (2000, 3, 1),
    (2023, 2, 28),
    (2024, 2, 28),
    (2024, 2, 29),
    (2024, 3, 1),
    (2024, 12, 31),
    (2025, 1, 1),
    (2100, 2, 28),
    (2400, 2, 29),
];

pub fn rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut dates: Vec<Date> = Vec::new();
    for &(year, month, day) in EDGES {
        dates.push(Date::new(year, month, day)?);
    }
    for month in 1..=12 {
        for year in [2023, 2024] {
            let first = Date::new(year, month, 1)?;
            dates.push(first);
            dates.push(first.last_of_month());
        }
    }
    while dates.len() < 400 {
        let year = i16::try_from(rng.range(-9999, 9999))?;
        let month = i8::try_from(rng.range(1, 12))?;
        let first = Date::new(year, month, 1)?;
        let day = i8::try_from(rng.range(1, i64::from(first.days_in_month())))?;
        dates.push(Date::new(year, month, day)?);
    }
    let epoch = date(1970, 1, 1);
    Ok(dates
        .into_iter()
        .map(|d| {
            let epoch_day = d.duration_since(epoch).as_hours() / 24;
            format!(
                "{}|{}|{}|{}|{}|{}|{}|{}|{}",
                d.year(),
                d.month(),
                d.day(),
                epoch_day,
                d.weekday().to_monday_zero_offset(),
                d.day_of_year(),
                u8::from(d.in_leap_year()),
                d.days_in_month(),
                d,
            )
        })
        .collect())
}
