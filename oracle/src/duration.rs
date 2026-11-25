//! Vectors for `SignedDuration`: arithmetic, comparison, rounding, and ISO
//! 8601 and friendly printing and parsing.

use jiff::fmt::{friendly as jiff_friendly, temporal};
use jiff::{RoundMode, SignedDuration, SignedDurationRound, Unit};

use crate::friendly::{self, Config};
use crate::gen;
use crate::rng::Rng;
use crate::span::{usable, FRIENDLY_LABELS, FRIENDLY_TEXTS, ISO_TEXTS};
use crate::text::{self, or_err, row};

pub const ARITHMETIC_COLUMNS: &str = "aSecs,aNanos|bSecs,bNanos|a + b|a - b|factor|a * factor|\
     divisor|a / divisor|compare(a, b)|a as text  (results are secs,nanos or ERR)";

pub const ROUND_COLUMNS: &str =
    "secs,nanos|smallest unit|increment|mode|rounded as secs,nanos or ERR";

pub const TEXT_COLUMNS: &str = "duration as secs,nanos|ISO 8601 text|the same in lower case|\
     friendly text from the default printer|the duration the ISO text parses back to|\
     the duration the friendly text parses back to";

pub const FRIENDLY_CONFIG_COLUMNS: &str = "printer settings that differ from the default, \
     separated by ';'|duration as secs,nanos|friendly text from that printer";

pub const PARSE_COLUMNS: &str = "text ('<empty>' for the empty string)|\
     parsed as ISO 8601|parsed as friendly|parsed as either, the way SignedDuration::from_str \
     does  (each is secs,nanos or ERR)";

/// Durations whose text is worth pinning by name: zero, one of each unit,
/// fractions of every length, and the limits.
const PRINT_EDGES: &[(i64, i32)] = &[
    (0, 0),
    (0, 1),
    (0, -1),
    (0, 999),
    (0, 1_000),
    (0, 1_001),
    (0, 999_999),
    (0, 1_000_000),
    (0, 1_001_001),
    (0, 100_000_000),
    (0, 120_000_000),
    (0, 123_456_789),
    (0, 500_000_000),
    (0, -500_000_000),
    (0, 999_999_999),
    (0, -999_999_999),
    (1, 0),
    (-1, 0),
    (1, 500_000_000),
    (-1, -500_000_000),
    (1, 1),
    (59, 0),
    (60, 0),
    (61, 0),
    (-60, 0),
    (90, 0),
    (3_599, 0),
    (3_600, 0),
    (3_601, 0),
    (3_660, 0),
    (3_661, 0),
    (-3_661, 0),
    (5_400, 0),
    (9_000, 123_456_789),
    (86_399, 999_999_999),
    (86_400, 0),
    (-86_400, 0),
    (90_000, 0),
    (172_800, 0),
    (360_000, 0),
    (31_536_000, 0),
    (631_107_417_600, 0),
    (i64::MAX, 0),
    (i64::MAX, 999_999_999),
    (i64::MIN, 0),
    (i64::MIN, -999_999_999),
    (i64::MIN + 1, 0),
    (i64::MAX - 59, 0),
    (9_223_372_036_854_774_000, 0),
    (-9_223_372_036_854_774_000, 0),
    (9_223_372_036, 854_775_807),
    (-9_223_372_036, -854_775_808),
];

/// Inputs that test the limits of a duration rather than of a span.
const PARSE_EXTRAS: &[&str] = &[
    "PT2562047788015215H",
    "PT2562047788015216H",
    "-PT2562047788015215H",
    "-PT2562047788015216H",
    "PT2562047788015215H30M7S",
    "PT2562047788015215H30M8S",
    "-PT2562047788015215H30M8S",
    "-PT2562047788015215H30M9S",
    "PT153722867280912930M",
    "PT153722867280912931M",
    "PT9223372036854775807S",
    "PT9223372036854775807.999999999S",
    "PT9223372036854775808S",
    "-PT9223372036854775808S",
    "-PT9223372036854775808.999999999S",
    "-PT9223372036854775809S",
    "PT2562047788015215.5H",
    "PT0.5H0.5M",
    "PT1H60M60S",
    "PT100H100M100S",
    "2562047788015215h",
    "2562047788015216h",
    "2562047788015215h ago",
    "-2562047788015216h",
    "2562047788015215h 30m 7s 999ms 999us 999ns",
    "2562047788015215h 30m 8s",
    "2562047788015215h 30m 8s ago",
    "2562047788015215h 30m 8s 1ns ago",
    "153722867280912930m",
    "153722867280912931m",
    "9223372036854775807s",
    "9223372036854775808s",
    "9223372036854775808s ago",
    "9223372036854775807000ms",
    "9223372036854775807ms",
    "9223372036854775807us",
    "9223372036854775807ns",
    "-9223372036854775808ns",
    "9223372036854775807s 999ms 999us 999ns",
    "9223372036854775807s 1000ms",
    "2562047788015215:30:07.999999999",
    "2562047788015215:30:08",
    "-2562047788015215:30:08",
    "1h 60m 60s",
    "100h 100m 100s 1000ms 1000us 1000ns",
    "1000ms",
    "1500ms",
    "1000000us",
    "1000000000ns",
    "1500000000ns ago",
];

const SECONDS: &[i64] = &[
    0,
    1,
    -1,
    59,
    60,
    -60,
    3_599,
    3_600,
    86_399,
    86_400,
    -86_400,
    631_107_417_600,
    -631_107_417_600,
    i64::MAX,
    i64::MIN,
    i64::MAX - 1,
    i64::MIN + 1,
];

const NANOS: &[i32] = &[0, 1, 499_999_999, 500_000_000, 500_000_001, 999_999_999];

const FACTORS: &[i32] = &[
    0,
    1,
    -1,
    2,
    -2,
    3,
    7,
    60,
    1_000,
    1_000_000_000,
    i32::MAX,
    i32::MIN,
];

const UNITS: &[(Unit, &str)] = &[
    (Unit::Nanosecond, "NANOSECOND"),
    (Unit::Microsecond, "MICROSECOND"),
    (Unit::Millisecond, "MILLISECOND"),
    (Unit::Second, "SECOND"),
    (Unit::Minute, "MINUTE"),
    (Unit::Hour, "HOUR"),
];

const MODES: &[(RoundMode, &str)] = &[
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

const INCREMENTS: &[i64] = &[1, 2, 5, 7, 15, 30, 100, 1_000];

/// A duration whose two components agree in sign, as `SignedDuration` requires.
fn arbitrary(rng: &mut Rng) -> SignedDuration {
    let secs = if rng.range(0, 3) == 0 {
        *rng.pick(SECONDS)
    } else {
        let magnitude = *rng.pick(&[1_000_i64, 1_000_000, 1_000_000_000_000, i64::MAX]);
        rng.range(-magnitude, magnitude)
    };
    let nanos = if rng.range(0, 2) == 0 {
        *rng.pick(NANOS)
    } else {
        i32::try_from(rng.range(0, 999_999_999)).unwrap_or(0)
    };
    let nanos = if secs < 0 { -nanos } else { nanos };
    SignedDuration::new(secs, nanos)
}

fn parts(duration: SignedDuration) -> String {
    format!("{},{}", duration.as_secs(), duration.subsec_nanos())
}

fn optional(duration: Option<SignedDuration>) -> String {
    duration.map_or_else(|| "ERR".to_owned(), parts)
}

pub fn arithmetic_rows(rng: &mut Rng) -> Vec<String> {
    (0..300)
        .map(|_| {
            let a = arbitrary(rng);
            let b = arbitrary(rng);
            let factor = *rng.pick(FACTORS);
            let divisor = *rng.pick(&FACTORS[1..]);
            format!(
                "{}|{}|{}|{}|{}|{}|{}|{}|{}|{}",
                parts(a),
                parts(b),
                optional(a.checked_add(b)),
                optional(a.checked_sub(b)),
                factor,
                optional(a.checked_mul(factor)),
                divisor,
                optional(a.checked_div(divisor)),
                a.cmp(&b) as i8,
                a,
            )
        })
        .collect()
}

pub fn round_rows(rng: &mut Rng) -> Vec<String> {
    let mut rows: Vec<String> = (0..300)
        .map(|_| {
            let duration = arbitrary(rng);
            let &(unit, unit_name) = rng.pick(UNITS);
            let &(mode, mode_name) = rng.pick(MODES);
            let increment = *rng.pick(INCREMENTS);
            let options = SignedDurationRound::new()
                .smallest(unit)
                .increment(increment)
                .mode(mode);
            let rounded = duration.round(options).ok();
            format!(
                "{}|{unit_name}|{increment}|{mode_name}|{}",
                parts(duration),
                optional(rounded)
            )
        })
        .collect();
    rows.extend(tie_rows());
    rows
}

/// Nanoseconds in one of each unit in `UNITS`.
const NANOS_PER_UNIT: [i128; 6] = [
    1,
    1_000,
    1_000_000,
    1_000_000_000,
    60_000_000_000,
    3_600_000_000_000,
];

/// Durations exactly halfway between two multiples of the rounding step, in
/// every mode, for an even and an odd multiple on each side of zero. These are the only inputs on
/// which the five `HALF_*` modes disagree, and random durations almost never
/// land on them. Built without the random stream, so that adding them leaves
/// every other vector as it was.
fn tie_rows() -> Vec<String> {
    let mut rows = Vec::new();
    for (index, &(unit, unit_name)) in UNITS.iter().enumerate() {
        for increment in [1_i64, 2, 15] {
            let step = NANOS_PER_UNIT[index] * i128::from(increment);
            if step % 2 != 0 {
                continue;
            }
            for multiple in [0_i128, 1, -1, -2, 4_611_686_018_427] {
                let nanos = multiple * step + step / 2;
                let Some(duration) = SignedDuration::try_from_nanos_i128(nanos) else {
                    continue;
                };
                for &(mode, mode_name) in MODES {
                    let options = SignedDurationRound::new()
                        .smallest(unit)
                        .increment(increment)
                        .mode(mode);
                    rows.push(format!(
                        "{}|{unit_name}|{increment}|{mode_name}|{}",
                        parts(duration),
                        optional(duration.round(options).ok())
                    ));
                }
            }
        }
    }
    rows
}

fn text_row(duration: SignedDuration) -> String {
    let iso = duration.to_string();
    let lowercase = temporal::SpanPrinter::new()
        .lowercase(true)
        .duration_to_string(&duration);
    let friendly = format!("{duration:#}");
    let from_iso = or_err(
        temporal::SpanParser::new().parse_duration(&iso),
        text::duration,
    );
    let from_friendly = or_err(
        jiff_friendly::SpanParser::new().parse_duration(&friendly),
        text::duration,
    );
    row([
        text::duration(duration),
        iso,
        lowercase,
        friendly,
        from_iso,
        from_friendly,
    ])
}

pub fn text_rows(rng: &mut Rng) -> Vec<String> {
    let mut rows: Vec<String> = PRINT_EDGES
        .iter()
        .map(|&(secs, nanos)| text_row(SignedDuration::new(secs, nanos)))
        .collect();
    while rows.len() < 320 {
        rows.push(text_row(gen::duration(rng)));
    }
    rows
}

fn config_row(config: &Config, duration: SignedDuration) -> String {
    row([
        config.name(),
        text::duration(duration),
        config.printer().duration_to_string(&duration),
    ])
}

pub fn friendly_config_rows(rng: &mut Rng) -> Vec<String> {
    let mut rows = Vec::new();
    // Every setting on its own, against a duration with every unit, a
    // negative one, and zero.
    let everything = SignedDuration::new(4 * 3_600 + 30 * 60 + 15, 500_600_700);
    let negative = SignedDuration::new(-(26 * 3_600 + 5), -1_000);
    for config in friendly::single_setting_configs() {
        rows.push(config_row(&config, everything));
        rows.push(config_row(&config, negative));
        rows.push(config_row(&config, SignedDuration::ZERO));
    }
    for &(secs, nanos) in PRINT_EDGES.iter().rev().take(12) {
        let config = friendly::arbitrary_config(rng);
        rows.push(config_row(&config, SignedDuration::new(secs, nanos)));
    }
    while rows.len() < 450 {
        let config = friendly::arbitrary_config(rng);
        rows.push(config_row(&config, gen::duration(rng)));
    }
    rows
}

fn parse_row(input: &str) -> String {
    let parsed = if input == "<empty>" { "" } else { input };
    row([
        input.to_owned(),
        or_err(
            temporal::SpanParser::new().parse_duration(parsed),
            text::duration,
        ),
        or_err(
            jiff_friendly::SpanParser::new().parse_duration(parsed),
            text::duration,
        ),
        or_err(parsed.parse::<SignedDuration>(), text::duration),
    ])
}

/// A duration that prints with a manageable number of digits, for inputs
/// that are then damaged.
fn modest(rng: &mut Rng) -> SignedDuration {
    if rng.range(0, 3) == 0 {
        gen::duration(rng)
    } else {
        SignedDuration::new(rng.range(-400_000, 400_000), gen::subsec(rng))
    }
}

pub fn parse_iso_rows(rng: &mut Rng) -> Vec<String> {
    let mut rows: Vec<String> = ISO_TEXTS
        .iter()
        .chain(PARSE_EXTRAS.iter().filter(|input| input.contains('P')))
        .map(|input| parse_row(input))
        .collect();
    while rows.len() < 320 {
        let duration = modest(rng);
        let lowercase = rng.range(0, 3) == 0;
        let mut input = temporal::SpanPrinter::new()
            .lowercase(lowercase)
            .duration_to_string(&duration);
        if rng.range(0, 3) == 0 {
            input = input.replace('.', ",");
        }
        if rng.range(0, 2) != 0 {
            input = friendly::mangle(rng, &input, "PpTtDHMSdhms0123456789.,-+ ");
        }
        if usable(&input) {
            rows.push(parse_row(&input));
        }
    }
    rows
}

pub fn parse_friendly_rows(rng: &mut Rng) -> Vec<String> {
    let mut rows: Vec<String> = FRIENDLY_TEXTS
        .iter()
        .chain(PARSE_EXTRAS.iter().filter(|input| !input.contains('P')))
        .map(|input| parse_row(input))
        .collect();
    for (index, label) in FRIENDLY_LABELS.iter().enumerate() {
        let input = match index % 3 {
            0 => format!("3 {label}"),
            1 => format!("1{label} ago"),
            _ => format!("2{label}"),
        };
        rows.push(parse_row(&input));
    }
    while rows.len() < 500 {
        let duration = modest(rng);
        let mut input = friendly::arbitrary_config(rng)
            .printer()
            .duration_to_string(&duration);
        if rng.range(0, 2) != 0 {
            input = friendly::mangle(rng, &input, "dhmsuno0123456789.,:-+ ag");
        }
        if usable(&input) {
            rows.push(parse_row(&input));
        }
    }
    rows
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn text_rows_carry_both_formats_and_their_round_trips() {
        assert_eq!(
            text_row(SignedDuration::new(9_000, 500_000_000)),
            "9000,500000000|PT2H30M0.5S|PT2h30m0.5s|2h 30m 500ms|9000,500000000|9000,500000000"
        );
    }

    #[test]
    fn parse_rows_record_each_parser_separately() {
        assert_eq!(parse_row("PT1H"), "PT1H|3600,0|ERR|3600,0");
        assert_eq!(parse_row("1 hour ago"), "1 hour ago|ERR|-3600,0|-3600,0");
        assert_eq!(parse_row("<empty>"), "<empty>|ERR|ERR|ERR");
    }

    #[test]
    fn generated_durations_have_components_of_one_sign() {
        let mut rng = Rng::new(17);
        for _ in 0..500 {
            let d = modest(&mut rng);
            assert!(d.as_secs().signum() * i64::from(d.subsec_nanos().signum()) >= 0);
        }
    }
}
