//! Generates golden test vectors for jiff-force by running the real Jiff
//! crate, pinned to the release the port tracks.
//!
//! The output is a set of Apex data classes (`JiffOracle*Data.cls`). Hand
//! written Apex tests (`JiffOracle*Test.cls`) replay every row against the
//! port, which makes the Rust implementation the oracle for the Apex one.
//!
//! Usage: `cargo run --manifest-path oracle/Cargo.toml` from the repository
//! root, or `npm run oracle`, which also formats the result. `README.md`
//! lists the topics and how their rows are written.
//!
//! Some hand written tests carry their vectors inline instead. With `--check`
//! (`npm run oracle:check`) nothing is generated; those rows are replayed
//! against Jiff and every expected value that differs is reported.

mod civil;
mod date;
mod duration;
mod emit;
mod friendly;
mod gen;
mod offset;
mod replay;
mod rng;
mod span;
mod text;
mod time;
mod timestamp;
mod zone;
mod zoned;

use std::path::PathBuf;

use anyhow::{ensure, Context, Result};

use crate::rng::Rng;

/// Fixed so that regenerating produces identical files.
const SEED: u64 = 0x4A49_4646_2D46_4F52;

/// A topic: the suffix of its data class, its column description, and the
/// function that produces its rows.
type Topic = (
    &'static str,
    &'static str,
    fn(&mut Rng) -> Result<Vec<String>>,
);

/// Every topic but the first three, which `main` writes itself.
const TOPICS: &[Topic] = &[
    ("DateSpan", date::SPAN_COLUMNS, date::span_rows),
    ("DateDuration", date::DURATION_COLUMNS, date::duration_rows),
    (
        "DateDifference",
        date::DIFFERENCE_COLUMNS,
        date::difference_rows,
    ),
    ("DateCalendar", date::CALENDAR_COLUMNS, date::calendar_rows),
    ("DateWeekday", date::WEEKDAY_COLUMNS, date::weekday_rows),
    ("IsoWeekDate", date::WEEK_DATE_COLUMNS, date::week_date_rows),
    ("DateWith", date::WITH_COLUMNS, date::with_rows),
    ("TimeSpan", time::SPAN_COLUMNS, time::span_rows),
    ("TimeDuration", time::DURATION_COLUMNS, time::duration_rows),
    (
        "TimeDifference",
        time::DIFFERENCE_COLUMNS,
        time::difference_rows,
    ),
    ("TimeRound", time::ROUND_COLUMNS, time::round_rows),
    ("TimeWith", time::WITH_COLUMNS, time::with_rows),
    ("SpanIso", span::ISO_COLUMNS, span::iso_rows),
    ("SpanFriendly", span::FRIENDLY_COLUMNS, span::friendly_rows),
    (
        "SpanFriendlyConfig",
        span::FRIENDLY_CONFIG_COLUMNS,
        span::friendly_config_rows,
    ),
    ("SpanParseIso", span::PARSE_COLUMNS, span::parse_iso_rows),
    (
        "SpanParseFriendly",
        span::PARSE_COLUMNS,
        span::parse_friendly_rows,
    ),
    ("SpanMultiply", span::MULTIPLY_COLUMNS, span::multiply_rows),
    ("SpanSetter", span::SETTER_COLUMNS, span::setter_rows),
    ("DurationText", duration::TEXT_COLUMNS, |rng| {
        Ok(duration::text_rows(rng))
    }),
    (
        "DurationFriendlyConfig",
        duration::FRIENDLY_CONFIG_COLUMNS,
        |rng| Ok(duration::friendly_config_rows(rng)),
    ),
    ("DurationParseIso", duration::PARSE_COLUMNS, |rng| {
        Ok(duration::parse_iso_rows(rng))
    }),
    ("DurationParseFriendly", duration::PARSE_COLUMNS, |rng| {
        Ok(duration::parse_friendly_rows(rng))
    }),
    (
        "Timestamp",
        timestamp::CONSTRUCT_COLUMNS,
        timestamp::construct_rows,
    ),
    (
        "TimestampSpan",
        timestamp::SPAN_COLUMNS,
        timestamp::span_rows,
    ),
    (
        "TimestampDuration",
        timestamp::DURATION_COLUMNS,
        timestamp::duration_rows,
    ),
    (
        "TimestampDifference",
        timestamp::DIFFERENCE_COLUMNS,
        timestamp::difference_rows,
    ),
    (
        "TimestampRound",
        timestamp::ROUND_COLUMNS,
        timestamp::round_rows,
    ),
    (
        "TimestampText",
        timestamp::TEXT_COLUMNS,
        timestamp::text_rows,
    ),
    ("Offset", offset::CONSTRUCT_COLUMNS, offset::construct_rows),
    (
        "OffsetArithmetic",
        offset::ARITHMETIC_COLUMNS,
        offset::arithmetic_rows,
    ),
    ("OffsetRound", offset::ROUND_COLUMNS, offset::round_rows),
    (
        "TimeZoneAmericas",
        zone::TRANSITION_COLUMNS,
        zone::americas_rows,
    ),
    (
        "TimeZoneEurope",
        zone::TRANSITION_COLUMNS,
        zone::europe_rows,
    ),
    (
        "TimeZonePacific",
        zone::TRANSITION_COLUMNS,
        zone::pacific_rows,
    ),
    ("TimeZoneOffset", zone::OFFSET_COLUMNS, zone::offset_rows),
    ("TimeZoneCivil", zone::CIVIL_COLUMNS, zone::civil_rows),
    ("ZonedSpan", zoned::SPAN_COLUMNS, zoned::span_rows),
    (
        "ZonedDifference",
        zoned::DIFFERENCE_COLUMNS,
        zoned::difference_rows,
    ),
    ("ZonedRound", zoned::ROUND_COLUMNS, zoned::round_rows),
    (
        "ZonedCalendar",
        zoned::CALENDAR_COLUMNS,
        zoned::calendar_rows,
    ),
];

fn main() -> Result<()> {
    let mut check = false;
    let mut classes_arg = None;
    for arg in std::env::args_os().skip(1) {
        if arg == "--check" {
            check = true;
        } else {
            classes_arg = Some(PathBuf::from(arg));
        }
    }
    let classes_dir = classes_dir(classes_arg)?;
    if check {
        return replay::check(&classes_dir);
    }
    // The first three topics share one stream, in this order. They were
    // written before topics had streams of their own, and keeping them as
    // they are keeps their vectors as they are.
    let mut rng = Rng::new(SEED);
    emit::write_data_class(
        &classes_dir,
        "Date",
        civil::COLUMNS,
        &civil::rows(&mut rng)?,
    )?;
    emit::write_data_class(
        &classes_dir,
        "Duration",
        duration::ARITHMETIC_COLUMNS,
        &duration::arithmetic_rows(&mut rng),
    )?;
    emit::write_data_class(
        &classes_dir,
        "DurationRound",
        duration::ROUND_COLUMNS,
        &duration::round_rows(&mut rng),
    )?;
    // Every other topic draws from a stream of its own, so adding or changing
    // one topic leaves the vectors of the others exactly as they were.
    for &(topic, columns, rows) in TOPICS {
        let mut rng = Rng::for_topic(SEED, topic);
        emit::write_data_class(&classes_dir, topic, columns, &rows(&mut rng)?)?;
    }
    Ok(())
}

/// The Apex classes directory: the one given on the command line, or the
/// default location relative to this crate.
fn classes_dir(given: Option<PathBuf>) -> Result<PathBuf> {
    let dir = given.unwrap_or_else(|| {
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../force-app/main/default/classes")
    });
    let dir = dir
        .canonicalize()
        .with_context(|| format!("locating {}", dir.display()))?;
    ensure!(dir.is_dir(), "{} is not a directory", dir.display());
    Ok(dir)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn topics_have_distinct_names_that_do_not_shadow_the_first_three() {
        let mut names: Vec<&str> = TOPICS.iter().map(|&(name, _, _)| name).collect();
        names.extend(["Date", "Duration", "DurationRound"]);
        let total = names.len();
        names.sort_unstable();
        names.dedup();
        assert_eq!(names.len(), total);
    }

    #[test]
    fn every_topic_produces_rows_that_match_its_columns() -> Result<()> {
        for &(topic, columns, rows) in TOPICS {
            let rows = rows(&mut Rng::for_topic(SEED, topic))?;
            assert!(rows.len() >= 150, "{topic} has only {} rows", rows.len());
            // A row has a field for every column, unless it stops early at
            // an error.
            let width = columns.split('|').count();
            for row in &rows {
                let fields = row.split('|').count();
                assert!(
                    fields == width || (fields < width && row.ends_with("|ERR")),
                    "{topic}: {fields} fields for {width} columns in {row}"
                );
            }
        }
        Ok(())
    }

    #[test]
    fn regenerating_a_topic_gives_the_same_rows() -> Result<()> {
        for &(topic, _, rows) in TOPICS.iter().take(3) {
            let first = rows(&mut Rng::for_topic(SEED, topic))?;
            let second = rows(&mut Rng::for_topic(SEED, topic))?;
            assert_eq!(first, second, "{topic}");
        }
        Ok(())
    }
}
