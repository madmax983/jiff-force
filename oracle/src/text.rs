//! How values are written in a vector row. Every encoding here has a matching
//! reader in the Apex class `JiffOracleSupport`, which builds the value with
//! plain constructors rather than with the port's own parsers.

use std::fmt::Display;

use jiff::civil::{Date, DateTime, ISOWeekDate, Time, Weekday};
use jiff::tz::Offset;
use jiff::{RoundMode, SignedDuration, Span, Timestamp, Unit};

/// What a row records when Jiff reported an error.
pub const ERR: &str = "ERR";

/// Every unit, smallest first, with the name of its `JiffUnit` constant.
pub const UNITS: [(Unit, &str); 10] = [
    (Unit::Nanosecond, "NANOSECOND"),
    (Unit::Microsecond, "MICROSECOND"),
    (Unit::Millisecond, "MILLISECOND"),
    (Unit::Second, "SECOND"),
    (Unit::Minute, "MINUTE"),
    (Unit::Hour, "HOUR"),
    (Unit::Day, "DAY"),
    (Unit::Week, "WEEK"),
    (Unit::Month, "MONTH"),
    (Unit::Year, "YEAR"),
];

/// Every rounding mode with the name of its `JiffRoundMode` constant.
pub const MODES: [(RoundMode, &str); 9] = [
    (RoundMode::Ceil, "CEIL"),
    (RoundMode::Floor, "FLOOR"),
    (RoundMode::Expand, "EXPAND"),
    (RoundMode::Trunc, "TRUNC"),
    (RoundMode::HalfCeil, "HALF_CEIL"),
    (RoundMode::HalfFloor, "HALF_FLOOR"),
    (RoundMode::HalfExpand, "HALF_EXPAND"),
    (RoundMode::HalfTrunc, "HALF_TRUNC"),
    (RoundMode::HalfEven, "HALF_EVEN"),
];

/// The labels of a span's units in a row, largest unit first.
const SPAN_LABELS: [&str; 10] = ["y", "mo", "w", "d", "h", "m", "s", "ms", "us", "ns"];

/// The value of every unit of a span, largest unit first.
pub fn span_fields(span: &Span) -> [i64; 10] {
    [
        i64::from(span.get_years()),
        i64::from(span.get_months()),
        i64::from(span.get_weeks()),
        i64::from(span.get_days()),
        i64::from(span.get_hours()),
        span.get_minutes(),
        span.get_seconds(),
        span.get_milliseconds(),
        span.get_microseconds(),
        span.get_nanoseconds(),
    ]
}

/// A span as its non-zero units, each with its own sign: `-1y -2mo`. The zero
/// span is `0`. Unlike ISO 8601, no two spans share a spelling.
pub fn span(span: &Span) -> String {
    let tokens: Vec<String> = span_fields(span)
        .iter()
        .zip(SPAN_LABELS)
        .filter(|(value, _)| **value != 0)
        .map(|(value, label)| format!("{value}{label}"))
        .collect();
    if tokens.is_empty() {
        "0".to_owned()
    } else {
        tokens.join(" ")
    }
}

/// A duration as `seconds,nanoseconds`.
pub fn duration(duration: SignedDuration) -> String {
    format!("{},{}", duration.as_secs(), duration.subsec_nanos())
}

/// A timestamp as `seconds,nanoseconds` since the Unix epoch.
pub fn timestamp(timestamp: Timestamp) -> String {
    format!(
        "{},{}",
        timestamp.as_second(),
        timestamp.subsec_nanosecond()
    )
}

/// An offset as its number of seconds east of UTC.
pub fn offset(offset: Offset) -> String {
    offset.seconds().to_string()
}

/// A weekday as its distance from Monday, which is its `JiffWeekday` ordinal.
pub fn weekday(weekday: Weekday) -> String {
    weekday.to_monday_zero_offset().to_string()
}

/// An ISO week date as `year,week,weekday`.
pub fn week_date(week_date: ISOWeekDate) -> String {
    format!(
        "{},{},{}",
        week_date.year(),
        week_date.week(),
        weekday(week_date.weekday())
    )
}

/// A civil date in ISO 8601, as Jiff prints it.
pub fn date(date: Date) -> String {
    date.to_string()
}

/// A civil time in ISO 8601, as Jiff prints it.
pub fn time(time: Time) -> String {
    time.to_string()
}

/// A civil datetime in ISO 8601, as Jiff prints it.
pub fn datetime(datetime: DateTime) -> String {
    datetime.to_string()
}

/// A fallible result: the value written by `show`, or `ERR`.
pub fn or_err<T, E>(result: Result<T, E>, show: impl FnOnce(T) -> String) -> String {
    result.map_or_else(|_| ERR.to_owned(), show)
}

/// Like [`or_err`] for a value that is absent rather than an error.
pub fn or_none<T>(value: Option<T>, show: impl FnOnce(T) -> String) -> String {
    value.map_or_else(|| "NONE".to_owned(), show)
}

/// Joins the fields of a row with the column separator.
pub fn row<I>(fields: I) -> String
where
    I: IntoIterator,
    I::Item: Display,
{
    let fields: Vec<String> = fields.into_iter().map(|f| f.to_string()).collect();
    debug_assert!(
        fields.iter().all(|f| !f.contains('|')),
        "a field contains the column separator: {fields:?}"
    );
    debug_assert!(
        fields.last().is_none_or(|f| !f.is_empty()),
        "a row must not end with an empty field (Apex drops them when splitting): {fields:?}"
    );
    fields.join("|")
}

#[cfg(test)]
mod tests {
    use jiff::ToSpan;

    use super::*;

    #[test]
    fn spans_list_only_their_non_zero_units() {
        assert_eq!(span(&Span::new()), "0");
        assert_eq!(span(&1.year().months(2).nanoseconds(3)), "1y 2mo 3ns");
        assert_eq!(span(&-1.hours().minutes(30)), "-1h -30m");
        assert_eq!(
            span(
                &1.year()
                    .months(2)
                    .weeks(3)
                    .days(4)
                    .hours(5)
                    .minutes(6)
                    .seconds(7)
                    .milliseconds(8)
                    .microseconds(9)
                    .nanoseconds(10)
            ),
            "1y 2mo 3w 4d 5h 6m 7s 8ms 9us 10ns"
        );
    }

    #[test]
    fn durations_and_timestamps_are_seconds_then_nanoseconds() {
        assert_eq!(
            duration(SignedDuration::new(-1, -500_000_000)),
            "-1,-500000000"
        );
        assert_eq!(
            timestamp(Timestamp::constant(-1, -500_000_000)),
            "-1,-500000000"
        );
        assert_eq!(timestamp(Timestamp::UNIX_EPOCH), "0,0");
    }

    #[test]
    fn errors_and_absent_values_have_fixed_spellings() {
        let failed: Result<i32, ()> = Err(());
        assert_eq!(or_err(failed, |v| v.to_string()), "ERR");
        assert_eq!(or_err(Ok::<i32, ()>(7), |v| v.to_string()), "7");
        assert_eq!(or_none(None::<i32>, |v| v.to_string()), "NONE");
        assert_eq!(or_none(Some(7), |v| v.to_string()), "7");
    }

    #[test]
    fn rows_are_pipe_separated() {
        assert_eq!(row(["a", "b", "c"]), "a|b|c");
        assert_eq!(row([1, 2]), "1|2");
    }

    #[test]
    fn units_are_listed_smallest_first_and_modes_are_all_there() {
        assert_eq!(UNITS[0], (Unit::Nanosecond, "NANOSECOND"));
        assert_eq!(UNITS[9], (Unit::Year, "YEAR"));
        assert!(UNITS.windows(2).all(|pair| pair[0].0 < pair[1].0));
        assert_eq!(MODES.len(), 9);
    }
}
