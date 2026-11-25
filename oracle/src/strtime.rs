//! Vectors for `strftime` / `strptime` (`jiff::fmt::strtime`) and for RFC 2822
//! and RFC 9110 (`jiff::fmt::rfc2822`).
//!
//! A value is written with a kind and its text: `D:<date>`, `T:<time>`,
//! `DT:<datetime>`, `TS:<secs,nanos>` or `Z:<zone>:<secs,nanos>`. Zoned values
//! stay in the zones and period of `zone.rs`. `%Z` (the abbreviation) is only
//! used with UTC and New York, whose abbreviations the platform and Jiff
//! agree on.

use anyhow::Result;
use jiff::fmt::{rfc2822, strtime};
use jiff::tz::TimeZone;
use jiff::{Timestamp, ZonedDateTime};

use crate::gen;
use crate::rng::Rng;
use crate::text::{self, or_err, row};
use crate::zone::{self, ZONES};

pub const FORMAT_COLUMNS: &str = "value (D:, T:, DT:, TS: or Z:<zone>:)|format|output or ERR";

pub const PARSE_COLUMNS: &str =
    "format|input|target kind (D, T, DT, TS or Z)|parsed value (same encoding as a value) or ERR";

pub const RFC2822_PARSE_COLUMNS: &str = "input ('<empty>' for the empty string)|\
     offset in seconds of the parsed zoned datetime|its instant as secs,nanos|\
     the input parsed as a timestamp, as secs,nanos  (each ERR when Jiff rejects the input)";

pub const RFC2822_PRINT_COLUMNS: &str = "value (Z:<zone>:<instant> or TS:<instant>)|RFC 2822 text \
     or ERR|RFC 9110 text (timestamps only, else -)";

/// Formats for dates, times and everything that has both, with every flag.
const DATE_FORMATS: [&str; 16] = [
    "%Y-%m-%d",
    "%F",
    "%D",
    "%a %A %b %B %h",
    "%^a %^B %#A",
    "%-d %_d %0e %e",
    "%j %-j %U %W %V %G %g %u %w",
    "%C %y %Y %_10Y %-Y %07Y",
    "%x",
    "%d/%m/%Y",
    "%A, %B %-d, %Y",
    "%Y%m%d",
    "%v",
    "%_3d/%_3m",
    "%%Y %n%t",
    "%Ey %Oy",
];

const TIME_FORMATS: [&str; 14] = [
    "%H:%M:%S",
    "%T",
    "%R",
    "%I:%M %p",
    "%l:%M %P",
    "%k %-H %_H %0k",
    "%r",
    "%X",
    "%H:%M:%S%.f",
    "%H:%M:%S%.3f",
    "%f %3f %6f %9f",
    "%N %-N",
    "%s",
    "%H%M%S",
];

const ZONED_FORMATS: [&str; 10] = [
    "%Y-%m-%dT%H:%M:%S%z",
    "%Y-%m-%dT%H:%M:%S%:z",
    "%::z %:::z",
    "%c",
    "%Y-%m-%d %H:%M:%S %Q",
    "%:Q",
    "%a, %d %b %Y %T %z",
    "%s %z",
    "%F %T%.f %:z [%Q]",
    "%+",
];

/// `%Z` only for the zones whose abbreviations agree.
const ABBREVIATION_FORMATS: [&str; 2] = ["%Y-%m-%d %H:%M %Z", "%T %Z"];

fn zone_value(rng: &mut Rng) -> Result<(&'static str, ZonedDateTime)> {
    let name = *rng.pick(&ZONES);
    let zone = TimeZone::get(name)?;
    let second = rng.range(zone::FIRST_SECOND + 86_400, zone::END_SECOND - 86_400);
    let nanos = gen::subsec(rng);
    Ok((name, Timestamp::new(second, nanos)?.to_zoned_datetime(zone)))
}

fn zoned_text(name: &str, zdt: &ZonedDateTime) -> String {
    format!("Z:{name}:{}", text::timestamp(zdt.timestamp()))
}

fn format_with<T: Into<strtime::BrokenDownTime>>(format: &str, value: T) -> String {
    or_err(value.into().to_string(format), |s| s)
}

pub fn format_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    while rows.len() < 500 {
        match rows.len() % 5 {
            0 => {
                let date = gen::date(rng)?;
                let format = *rng.pick(&DATE_FORMATS);
                rows.push(row([
                    format!("D:{}", text::date(date)),
                    format.to_owned(),
                    format_with(format, date),
                ]));
            }
            1 => {
                let time = gen::time(rng)?;
                let format = *rng.pick(&TIME_FORMATS);
                rows.push(row([
                    format!("T:{}", text::time(time)),
                    format.to_owned(),
                    format_with(format, time),
                ]));
            }
            2 => {
                let datetime = gen::date(rng)?.to_datetime(gen::time(rng)?);
                let format = if rng.range(0, 1) == 0 {
                    *rng.pick(&DATE_FORMATS)
                } else {
                    *rng.pick(&TIME_FORMATS)
                };
                rows.push(row([
                    format!("DT:{}", text::datetime(datetime)),
                    format.to_owned(),
                    format_with(format, datetime),
                ]));
            }
            3 => {
                let ts =
                    Timestamp::new(rng.range(-2_000_000_000, 4_000_000_000), gen::subsec(rng))?;
                let format = *rng.pick(&ZONED_FORMATS);
                rows.push(row([
                    format!("TS:{}", text::timestamp(ts)),
                    format.to_owned(),
                    format_with(format, ts),
                ]));
            }
            _ => {
                let (name, zdt) = zone_value(rng)?;
                let format = if matches!(name, "UTC" | "America/New_York") && rng.range(0, 2) == 0 {
                    *rng.pick(&ABBREVIATION_FORMATS)
                } else {
                    *rng.pick(&ZONED_FORMATS)
                };
                rows.push(row([
                    zoned_text(name, &zdt),
                    format.to_owned(),
                    format_with(format, &zdt),
                ]));
            }
        }
    }
    Ok(rows)
}

/// Formats to parse with, each for one kind of target.
const PARSE_FORMATS: [(&str, &str); 14] = [
    ("%Y-%m-%d", "D"),
    ("%d/%m/%Y", "D"),
    ("%A, %B %-d, %Y", "D"),
    ("%Y %j", "D"),
    ("%G-W%V-%u", "D"),
    ("%H:%M:%S", "T"),
    ("%I:%M:%S %p", "T"),
    ("%H:%M:%S%.f", "T"),
    ("%Y-%m-%d %H:%M", "DT"),
    ("%a %b %e %H:%M:%S %Y", "DT"),
    ("%s", "TS"),
    ("%Y-%m-%dT%H:%M:%S%z", "TS"),
    ("%Y-%m-%d %H:%M:%S %Q", "Z"),
    ("%Y-%m-%dT%H:%M:%S%:z[%Q]", "Z"),
];

/// Inputs that must be rejected, or accepted, for reasons a random value
/// would not exercise.
const PARSE_EDGES: [(&str, &str, &str); 14] = [
    ("%Y-%m-%d", "2023-02-29", "D"),
    ("%Y-%m-%d", "2024-02-29", "D"),
    ("%Y-%m-%d", "2024-2-9", "D"),
    ("%Y-%m-%d", "2024-02-29x", "D"),
    ("%A, %B %-d, %Y", "Monday, February 29, 2024", "D"),
    ("%A, %B %-d, %Y", "thursday, FEBRUARY 29, 2024", "D"),
    ("%H:%M:%S", "24:00:00", "T"),
    ("%H:%M:%S", "23:59:60", "T"),
    ("%I:%M %p", "12:30 am", "T"),
    ("%I:%M %p", "13:30 PM", "T"),
    (
        "%Y-%m-%d %H:%M:%S %Q",
        "2024-03-10 02:30:00 America/New_York",
        "Z",
    ),
    (
        "%Y-%m-%d %H:%M:%S %Q",
        "2024-11-03 01:30:00 America/New_York",
        "Z",
    ),
    ("%Y-%m-%dT%H:%M:%S%z", "2024-07-04T08:39:00-0400", "TS"),
    ("%s", "-1", "TS"),
];

fn parsed_text(kind: &str, format: &str, input: &str) -> String {
    let Ok(parsed) = strtime::parse(format, input) else {
        return text::ERR.to_owned();
    };
    match kind {
        "D" => or_err(parsed.to_date(), |d| format!("D:{}", text::date(d))),
        "T" => or_err(parsed.to_time(), |t| format!("T:{}", text::time(t))),
        "DT" => or_err(parsed.to_datetime(), |dt| {
            format!("DT:{}", text::datetime(dt))
        }),
        "TS" => or_err(parsed.to_timestamp(), |ts| {
            format!("TS:{}", text::timestamp(ts))
        }),
        _ => or_err(parsed.to_zoned_datetime(), |z| {
            let name = z.time_zone().iana_name().unwrap_or("?").to_owned();
            zoned_text(&name, &z)
        }),
    }
}

pub fn parse_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows: Vec<String> = PARSE_EDGES
        .iter()
        .map(|&(format, input, kind)| {
            row([
                format.to_owned(),
                input.to_owned(),
                kind.to_owned(),
                parsed_text(kind, format, input),
            ])
        })
        .collect();
    while rows.len() < 400 {
        let &(format, kind) = rng.pick(&PARSE_FORMATS);
        // Produce the input by formatting a value Jiff can represent, so most
        // rows parse; a few are then damaged to exercise the errors.
        let (_, zdt) = zone_value(rng)?;
        let source = if kind == "Z" {
            zdt.clone()
        } else {
            zdt.with_time_zone(TimeZone::UTC)
        };
        let Ok(mut input) = strtime::format(format, &source) else {
            continue;
        };
        if rng.range(0, 6) == 0 {
            let cut = usize::try_from(rng.range(0, i64::try_from(input.len())?))?;
            input.truncate(cut);
        }
        rows.push(row([
            format.to_owned(),
            input.clone(),
            kind.to_owned(),
            parsed_text(kind, format, &input),
        ]));
    }
    Ok(rows)
}

const RFC2822_INPUTS: [&str; 14] = [
    "Thu, 04 Jul 2024 08:39:00 -0400",
    "Thu, 4 Jul 2024 08:39:00 -0400",
    "4 Jul 2024 08:39 +0000",
    "Thu, 04 Jul 2024 08:39:00 GMT",
    "Thu, 04 Jul 2024 08:39:00 EDT",
    "Thu, 04 Jul 2024 08:39:00 UT",
    "Fri, 04 Jul 2024 08:39:00 -0400",
    "Thu, 04 Jul 24 08:39:00 -0400",
    "Thu, 04 Jul 2024 08:39:60 -0400",
    "Thu,04 Jul 2024 08:39:00 -0400",
    "Thu, 04 Jul 2024 08:39:00 -0400 (comment)",
    "Sat, 29 Feb 2025 00:00:00 +0000",
    "Mon, 01 Jan 1900 00:00:00 +0000",
    "",
];

pub fn rfc2822_parse_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut inputs: Vec<String> = RFC2822_INPUTS.iter().map(|&s| s.to_owned()).collect();
    // What Jiff prints must read back, in every zone and at any time of day.
    while inputs.len() < 150 {
        let (_, zdt) = zone_value(rng)?;
        inputs.push(rfc2822::to_string(&zdt)?);
    }
    Ok(inputs
        .iter()
        .map(|input| {
            let zoned = rfc2822::parse(input);
            let printable = if input.is_empty() { "<empty>" } else { input };
            row([
                printable.to_owned(),
                or_err(zoned.as_ref().map(|z| z.offset().seconds()), |s| {
                    s.to_string()
                }),
                or_err(
                    zoned.as_ref().map(ZonedDateTime::timestamp),
                    text::timestamp,
                ),
                or_err(
                    rfc2822::DateTimeParser::new().parse_timestamp(input),
                    text::timestamp,
                ),
            ])
        })
        .collect())
}

pub fn rfc2822_print_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let printer = rfc2822::DateTimePrinter::new();
    let mut rows = Vec::new();
    while rows.len() < 150 {
        if rows.len() % 2 == 0 {
            let (name, zdt) = zone_value(rng)?;
            rows.push(row([
                zoned_text(name, &zdt),
                or_err(rfc2822::to_string(&zdt), |s| s),
                "-".to_owned(),
            ]));
        } else {
            let ts = Timestamp::new(rng.range(-2_000_000_000, 4_000_000_000), gen::subsec(rng))?;
            rows.push(row([
                format!("TS:{}", text::timestamp(ts)),
                or_err(printer.timestamp_to_string(&ts), |s| s),
                or_err(printer.timestamp_to_rfc9110_string(&ts), |s| s),
            ]));
        }
    }
    Ok(rows)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parsed_values_use_the_value_encoding() {
        assert_eq!(parsed_text("D", "%Y-%m-%d", "2024-02-29"), "D:2024-02-29");
        assert_eq!(parsed_text("D", "%Y-%m-%d", "2023-02-29"), "ERR");
        assert_eq!(parsed_text("TS", "%s", "-1"), "TS:-1,0");
    }
}
