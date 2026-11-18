//! Vectors for `Span`: ISO 8601 and friendly printing and parsing,
//! multiplication, and the sign rules of the setters.

use anyhow::Result;
use jiff::fmt::{friendly as jiff_friendly, temporal};
use jiff::Span;

use crate::friendly::{self, Config};
use crate::gen::{self, UnitValues};
use crate::rng::Rng;
use crate::text::{self, or_err, row};

pub const ISO_COLUMNS: &str =
    "span|ISO 8601 text|the same in lower case|the span that text parses back to";

pub const FRIENDLY_COLUMNS: &str =
    "span|friendly text from the default printer|the span that text parses back to";

pub const FRIENDLY_CONFIG_COLUMNS: &str = "printer settings that differ from the default, \
     separated by ';'|span|friendly text from that printer";

pub const PARSE_COLUMNS: &str = "text ('<empty>' for the empty string)|\
     parsed as ISO 8601|parsed as friendly|parsed as either, the way Span::from_str does  \
     (each is a span or ERR)";

pub const MULTIPLY_COLUMNS: &str = "span|factor|span * factor or ERR";

pub const SETTER_COLUMNS: &str = "setters applied in order to an empty span, as unit=value \
     separated by ';'|resulting span or ERR|its signum (omitted after ERR)";

/// The labels of the span units in a setter list, largest unit first.
const LABELS: [&str; 10] = ["y", "mo", "w", "d", "h", "m", "s", "ms", "us", "ns"];

/// Spans whose text is worth pinning by name: zero, every unit alone, sub
/// second units that must be folded into a fraction, and the limits.
const PRINT_EDGES: &[&UnitValues] = &[
    &[],
    &[(0, 1)],
    &[(1, 1)],
    &[(2, 1)],
    &[(3, 1)],
    &[(4, 1)],
    &[(5, 1)],
    &[(6, 1)],
    &[(7, 1)],
    &[(8, 1)],
    &[(9, 1)],
    &[(0, -1)],
    &[(3, -1)],
    &[(6, -1)],
    &[(9, -1)],
    &[
        (0, 2),
        (1, 2),
        (2, 2),
        (3, 2),
        (4, 2),
        (5, 2),
        (6, 2),
        (7, 2),
        (8, 2),
        (9, 2),
    ],
    &[
        (0, -1),
        (1, -2),
        (2, -3),
        (3, -4),
        (4, -5),
        (5, -6),
        (6, -7),
        (7, -8),
        (8, -9),
        (9, -10),
    ],
    &[(0, 1), (1, 2), (3, 3), (4, 4), (5, 5), (6, 6)],
    &[(1, 2), (3, 35), (4, 2), (5, 30)],
    &[(4, 2), (5, 30)],
    &[(5, 90)],
    &[(5, 120)],
    &[(6, 3_600)],
    &[(4, 1), (6, 1)],
    &[(4, 1), (9, 1)],
    &[(3, 1), (9, 1)],
    &[(0, 1), (9, 1)],
    &[(7, 500)],
    &[(7, 1_000)],
    &[(7, 1_500)],
    &[(7, -1_500)],
    &[(8, 1)],
    &[(8, 1_000_000)],
    &[(8, 1_500_000)],
    &[(9, 1_000_000_000)],
    &[(9, 1_000_000_001)],
    &[(9, 999_999_999)],
    &[(9, 123_456_789)],
    &[(9, 100_000_000)],
    &[(9, 120_000_000)],
    &[(6, 1), (7, 1), (8, 1), (9, 1)],
    &[(6, 1), (7, 999), (8, 999), (9, 999)],
    &[(6, 1), (7, 999), (8, 999), (9, 1_000)],
    &[(6, 59), (7, 1_000)],
    &[(7, 1), (8, 1), (9, 1)],
    &[(7, 1_000), (8, 1_000_000), (9, 1_000_000_000)],
    &[(6, -1), (7, -500)],
    &[(4, 1), (5, 30), (6, 15), (7, 500)],
    &[(4, 1), (5, 30)],
    &[(4, 1), (5, 15)],
    &[(4, 2), (5, 0), (6, 30)],
    &[(5, 1), (6, 30)],
    &[(5, 1), (6, 30), (7, 250)],
    &[(4, 100), (5, 100), (6, 100)],
    &[(0, 19_998)],
    &[(1, 239_976)],
    &[(2, 1_043_497)],
    &[(3, 7_304_484)],
    &[(4, 175_307_616)],
    &[(5, 10_518_456_960)],
    &[(6, 631_107_417_600)],
    &[(7, 631_107_417_600_000)],
    &[(8, 631_107_417_600_000_000)],
    &[(9, i64::MAX)],
    &[(9, -i64::MAX)],
    &[(6, 631_107_417_600), (7, 631_107_417_600_000)],
    &[(6, 631_107_417_600), (9, i64::MAX)],
    &[
        (6, 631_107_417_600),
        (7, 631_107_417_600_000),
        (8, 631_107_417_600_000_000),
        (9, i64::MAX),
    ],
    &[
        (0, 19_998),
        (1, 239_976),
        (2, 1_043_497),
        (3, 7_304_484),
        (4, 175_307_616),
        (5, 10_518_456_960),
        (6, 631_107_417_600),
        (7, 631_107_417_600_000),
        (8, 631_107_417_600_000_000),
        (9, i64::MAX),
    ],
    &[
        (0, -19_998),
        (1, -239_976),
        (2, -1_043_497),
        (3, -7_304_484),
        (4, -175_307_616),
        (5, -10_518_456_960),
        (6, -631_107_417_600),
        (7, -631_107_417_600_000),
        (8, -631_107_417_600_000_000),
        (9, -i64::MAX),
    ],
];

/// ISO 8601 durations, well formed and not.
pub const ISO_TEXTS: &[&str] = &[
    "P1Y2M3W4DT5H6M7S",
    "P1Y",
    "P1M",
    "P1W",
    "P1D",
    "PT1H",
    "PT1M",
    "PT1S",
    "P0D",
    "PT0S",
    "P0Y0M0W0DT0H0M0S",
    "-P1D",
    "+P1D",
    "-PT0S",
    "--P1D",
    "+-P1D",
    "P-1D",
    "P+1D",
    "PT-1H",
    "p1y2m3w4dt5h6m7s",
    "P1y2M3w4Dt5h6M7s",
    "-p1d",
    "PT1.5H",
    "PT1,5H",
    "PT0.5H",
    "PT1.25H",
    "PT1.999999999H",
    "PT0.000000001H",
    "PT1.5M",
    "PT1,5M",
    "PT0.000000001M",
    "PT1.5S",
    "PT1,5S",
    "PT0.5S",
    "PT.5S",
    "PT1.S",
    "PT1.0S",
    "PT1.000S",
    "PT0.001S",
    "PT0.000001S",
    "PT0.000000001S",
    "PT0.0000000001S",
    "PT1.123456789S",
    "PT1.1234567890S",
    "PT0.999999999S",
    "PT59.999999999S",
    "-PT1.5S",
    "-PT0.000000001S",
    "PT1.5H30M",
    "PT1.5H0M",
    "PT1.5M30S",
    "PT1H1.5M",
    "PT1H1.5M1S",
    "PT1H30M1.5S",
    "P1.5D",
    "P1.5Y",
    "P1.5W",
    "P1.5M",
    "P1DT1.5H",
    "P",
    "PT",
    "P1",
    "PT1",
    "P1DT",
    "P1T1H",
    "1D",
    "T1H",
    "P1H",
    "PT1D",
    "PT1Y",
    "P1S",
    "P1Y1Y",
    "P1D1D",
    "PT1H1H",
    "P1M1Y",
    "P1D1M",
    "P1D1W",
    "P1W1D",
    "PT1M1H",
    "PT1S1M",
    "PT1S1H",
    "P1Y1D",
    "P1Y1W",
    "P1MT1M",
    "P1M1DT1M1S",
    "PT1H1S",
    "P01Y02M03DT04H05M06S",
    "P0001D",
    "PT00000000000000000001S",
    "P19998Y",
    "P19999Y",
    "-P19998Y",
    "-P19999Y",
    "P239976M",
    "P239977M",
    "P1043497W",
    "P1043498W",
    "P7304484D",
    "P7304485D",
    "PT175307616H",
    "PT175307617H",
    "PT10518456960M",
    "PT10518456961M",
    "PT631107417600S",
    "PT631107417601S",
    "PT631107417600.999999999S",
    "PT9223372036854775807S",
    "PT9223372036854775808S",
    "PT99999999999999999999S",
    "P99999999999999999999D",
    "PT175307616.5H",
    "PT175307615.5H",
    "PT10518456960.5M",
    "PT10518456959.5M",
    "PT2562047788015215H",
    " P1D",
    "P1D ",
    "P 1D",
    "P1 D",
    "P1DT 1H",
    "P1D\n",
    "\tP1D",
    "P1D1",
    "P1DX",
    "PXD",
    "P1X",
    "P1DT1H1X",
    "PT1H30",
    "P1Y2M3W4DT5H6M7S8",
    "<empty>",
    "-",
    "+",
    "P-",
    "T",
    "PP1D",
    "PTT1H",
    "P1DTT1H",
    "P1DT1HT1M",
    "PT1H:30M",
    "P1Y2M3W4DT5H6M7.5S",
    "P1Y2M3W4DT5H6.5M",
    "P1Y2M3W4DT5.5H",
    "-P1Y2M3W4DT5H6M7.123456789S",
    "PT24H",
    "PT1440M",
    "PT86400S",
    "PT90M",
    "PT3600.000000001S",
    "P1W1DT1H",
    "P2M35DT2H30M",
    "PT2h30m0.123456789s",
    "PT2H30M0,123456789S",
    "\u{2212}P1D",
    "P1D\u{b5}",
    "P١D",
];

/// The labels the friendly format accepts for each unit.
pub const FRIENDLY_LABELS: &[&str] = &[
    "years",
    "year",
    "yrs",
    "yr",
    "y",
    "months",
    "month",
    "mos",
    "mo",
    "weeks",
    "week",
    "wks",
    "wk",
    "w",
    "days",
    "day",
    "d",
    "hours",
    "hour",
    "hrs",
    "hr",
    "h",
    "minutes",
    "minute",
    "mins",
    "min",
    "m",
    "seconds",
    "second",
    "secs",
    "sec",
    "s",
    "milliseconds",
    "millisecond",
    "millis",
    "milli",
    "msecs",
    "msec",
    "ms",
    "microseconds",
    "microsecond",
    "micros",
    "micro",
    "usecs",
    "usec",
    "us",
    "\u{b5}s",
    "\u{b5}secs",
    "\u{b5}sec",
    "\u{3bc}s",
    "\u{3bc}secs",
    "\u{3bc}sec",
    "nanoseconds",
    "nanosecond",
    "nanos",
    "nano",
    "nsecs",
    "nsec",
    "ns",
    // Not labels.
    "M",
    "Y",
    "D",
    "H",
    "S",
    "Years",
    "MS",
    "yea",
    "yearss",
    "mon",
    "mth",
    "wee",
    "dy",
    "ho",
    "mi",
    "se",
    "mss",
    "u",
    "n",
    "nss",
    "x",
];

/// Friendly durations, well formed and not.
pub const FRIENDLY_TEXTS: &[&str] = &[
    "40d",
    "40 days",
    "1y1d",
    "1yr 1d",
    "3d4h59m",
    "3 days, 4 hours, 59 minutes",
    "3d 4h 59m",
    "2h30m",
    "2h 30m",
    "1w4d",
    "1 wk 4 days",
    "0.0021s",
    "0s",
    "0d",
    "0 days",
    "3 mins 34s 123ms",
    "3 mins 34.123 secs",
    "3 mins 34,123s",
    "1y1mo1d1h1m1.1s",
    "1yr 1mo 1day 1hr 1min 1.1sec",
    "1 year, 1 month, 1 day, 1 hour, 1 minute 1.1 seconds",
    "1 year, 1 month, 1 day, 01:01:01.1",
    "2 months, 35 days, 02:30:00",
    "1y 2mo 3w 4d 5h 6m 7s 8ms 9us 10ns",
    "1y2mo3w4d5h6m7s8ms9us10ns",
    "1 year 2 months 3 weeks 4 days 5 hours 6 minutes 7 seconds 8 milliseconds \
     9 microseconds 10 nanoseconds",
    "1 year, 2 months, 3 weeks, 4 days, 5 hours, 6 minutes, 7 seconds, 8 milliseconds, \
     9 microseconds, 10 nanoseconds",
    "1y 1y",
    "1d 1d",
    "1h 1h",
    "1mo 1y",
    "1d 1w",
    "1m 1h",
    "1s 1m",
    "1ns 1us",
    "1ms 1s",
    "1y 1d 1mo",
    "5h ago",
    "5h  ago",
    "5hago",
    "5h ago ",
    "5h ago ago",
    "5h Ago",
    "5h AGO",
    "ago",
    " ago",
    "ago 5h",
    "0s ago",
    "1y 2mo ago",
    "1 year, 2 months ago",
    "1 year, 2 months, ago",
    "-5h",
    "+5h",
    "- 5h",
    "+ 5h",
    "-  5h",
    "--5h",
    "-5h ago",
    "+5h ago",
    "-0s",
    "-1y 2mo",
    "1y -2mo",
    "1y +2mo",
    "1.5h",
    "1,5h",
    "1.5 hours",
    "1.5hrs",
    "0.5h",
    ".5h",
    "1.h",
    "1.0h",
    "1.25h",
    "1.999999999h",
    "1.0000000001h",
    "1.5m",
    "1.5 mins",
    "1.5s",
    "1.5ms",
    "1.5us",
    "1.5ns",
    "0.5ns",
    "1.5d",
    "1.5w",
    "1.5mo",
    "1.5y",
    "1.5h 30m",
    "1.5h 0m",
    "1h 1.5m",
    "1h 1.5m 3s",
    "1h 30m 1.5s",
    "1d 1.5h",
    "1.123456789s",
    "1.1234567890s",
    "0.000000001s",
    "0.000000001h",
    "0.000000001m",
    "0.999999999ms",
    "0.001ms",
    "0.001us",
    "0.0001us",
    "00:00:00",
    "01:02:03",
    "1:2:3",
    "001:002:003",
    "01:02:03.5",
    "01:02:03,5",
    "01:02:03.123456789",
    "01:02:03.1234567890",
    "01:02:03.",
    "01:02",
    "01:02:",
    ":02:03",
    "01::03",
    "01:02:03:04",
    "24:00:00",
    "25:61:61",
    "99:99:99",
    "100:00:00",
    "175307616:00:00",
    "175307617:00:00",
    "00:10518456960:00",
    "00:00:631107417600",
    "00:00:631107417601",
    "-01:02:03",
    "+01:02:03",
    "- 01:02:03",
    "01:02:03 ago",
    "-01:02:03 ago",
    "1d 01:02:03",
    "1d, 01:02:03",
    "1d,01:02:03",
    "1d01:02:03",
    "1d 01:02:03 ago",
    "-1d 01:02:03",
    "1h 01:02:03",
    "1m 01:02:03",
    "1y 2mo 3w 4d 05:06:07.008009010",
    "01:02:03 1d",
    "01:02:03 4s",
    "1h, 30m",
    "1h,30m",
    "1h ,30m",
    "1h,, 30m",
    "1h, ",
    "1h,",
    ",1h",
    "1h , 30m",
    "1 h",
    "1  h",
    "1   hour",
    "1\th",
    "1h\t30m",
    "1h\n30m",
    " 1h",
    "1h ",
    "  1h  ",
    "1h   30m",
    "<empty>",
    " ",
    "1",
    "h",
    "1 2h",
    "h1",
    "1hh",
    "1h30",
    "1h 30",
    "one hour",
    "1e3s",
    "0x10s",
    "1_000s",
    "1,000s",
    "1 000s",
    "P1D",
    "PT1H",
    "p1d",
    "-P1D",
    "19998y",
    "19999y",
    "-19998y",
    "-19999y",
    "239976mo",
    "239977mo",
    "1043497w",
    "1043498w",
    "7304484d",
    "7304485d",
    "175307616h",
    "175307617h",
    "10518456960m",
    "10518456961m",
    "631107417600s",
    "631107417601s",
    "631107417600000ms",
    "631107417600001ms",
    "631107417600000000us",
    "631107417600000001us",
    "9223372036854775807ns",
    "9223372036854775808ns",
    "-9223372036854775807ns",
    "-9223372036854775808ns",
    "99999999999999999999s",
    "175307616.5h",
    "175307615.5h",
    "631107417600.5s",
    "631107417599.999999999s",
    "000001h",
    "00000000000000000000001h",
    "1h 0m",
    "0h 1m",
    "0y 0mo 0w 0d 0h 0m 0s 0ms 0us 0ns",
    "1 hour 30 mins ago",
    "2 hours 30 minutes ago",
    "1y 1s",
    "1mo 1m",
    "1m 1mo",
    "1ms 1m",
    "10 millis 5 micros 1 nano",
    "1 \u{b5}s",
    "1\u{3bc}s",
    "1 \u{3bc}secs ago",
    "\u{2212}5h",
    "5h\u{a0}ago",
    "١h",
];

/// A span for printing: any mix of units, clock sized time units (where
/// fractions and the hours-minutes-seconds form matter), or sub-second units
/// that carry into each other.
fn printable(rng: &mut Rng) -> Result<Span> {
    match rng.range(0, 11) {
        0..=3 => gen::span(rng, &gen::ALL_UNITS, 5, 5_000),
        4..=6 => {
            const CAPS: [i64; 6] = [48, 120, 120, 2_500, 2_500, 2_500];
            let negative = rng.range(0, 3) == 0;
            let mut span = Span::new();
            for _ in 0..rng.range(1, 4) {
                let unit = usize::try_from(rng.range(0, 5))?;
                let value = rng.range(0, CAPS[unit]);
                span = gen::set_unit(span, 4 + unit, if negative { -value } else { value })?;
            }
            if rng.range(0, 2) == 0 {
                let days = rng.range(1, 40);
                span = span.try_days(if negative { -days } else { days })?;
            }
            Ok(span)
        }
        7..=8 => gen::span(rng, &[6, 7, 8, 9], 4, 3_000_000_000),
        9 => gen::span(rng, &gen::TIME_UNITS, 3, i64::MAX),
        _ => gen::span(rng, &gen::ALL_UNITS, 10, i64::MAX),
    }
}

fn show(span: Span) -> String {
    text::span(&span)
}

fn iso_row(span: Span) -> String {
    let iso = span.to_string();
    let lowercase = temporal::SpanPrinter::new()
        .lowercase(true)
        .span_to_string(&span);
    let back = or_err(temporal::SpanParser::new().parse_span(&iso), show);
    row([text::span(&span), iso, lowercase, back])
}

pub fn iso_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    for units in PRINT_EDGES {
        rows.push(iso_row(gen::span_of(units)?));
    }
    while rows.len() < 320 {
        rows.push(iso_row(printable(rng)?));
    }
    Ok(rows)
}

fn friendly_row(span: Span) -> String {
    let friendly = span.to_friendly();
    let back = or_err(jiff_friendly::SpanParser::new().parse_span(&friendly), show);
    row([text::span(&span), friendly, back])
}

pub fn friendly_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    for units in PRINT_EDGES {
        rows.push(friendly_row(gen::span_of(units)?));
    }
    while rows.len() < 300 {
        rows.push(friendly_row(printable(rng)?));
    }
    Ok(rows)
}

fn config_row(config: &Config, span: Span) -> String {
    row([
        config.name(),
        text::span(&span),
        config.printer().span_to_string(&span),
    ])
}

pub fn friendly_config_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    // Every setting on its own, against a span with a bit of everything, a
    // negative clock sized span, and zero.
    let everything = gen::span_of(&[(0, 1), (1, 2), (3, 3), (4, 4), (5, 30), (6, 15), (7, 500)])?;
    let clock = gen::span_of(&[(4, -1), (5, -30), (6, -45), (7, -250), (9, -1)])?;
    for config in friendly::single_setting_configs() {
        rows.push(config_row(&config, everything));
        rows.push(config_row(&config, clock));
        rows.push(config_row(&config, Span::new()));
    }
    while rows.len() < 450 {
        let config = friendly::arbitrary_config(rng);
        let span = if rng.range(0, 14) == 0 {
            Span::new()
        } else {
            printable(rng)?
        };
        rows.push(config_row(&config, span));
    }
    Ok(rows)
}

fn parse_row(input: &str) -> String {
    let parsed = if input == "<empty>" { "" } else { input };
    row([
        input.to_owned(),
        or_err(temporal::SpanParser::new().parse_span(parsed), show),
        or_err(jiff_friendly::SpanParser::new().parse_span(parsed), show),
        or_err(parsed.parse::<Span>(), show),
    ])
}

/// Whether a parser input can be written as a field of a row.
pub fn usable(input: &str) -> bool {
    !input.is_empty() && !input.contains('|') && input != "<empty>"
}

pub fn parse_iso_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows: Vec<String> = ISO_TEXTS.iter().map(|input| parse_row(input)).collect();
    while rows.len() < 300 {
        let span = printable(rng)?;
        let lowercase = rng.range(0, 3) == 0;
        let mut input = temporal::SpanPrinter::new()
            .lowercase(lowercase)
            .span_to_string(&span);
        if rng.range(0, 3) == 0 {
            input = input.replace('.', ",");
        }
        // A third are left as Jiff printed them; the rest are damaged.
        if rng.range(0, 2) != 0 {
            input = friendly::mangle(rng, &input, "PpTtYMWDHSymwdhs0123456789.,-+ ");
        }
        if usable(&input) {
            rows.push(parse_row(&input));
        }
    }
    Ok(rows)
}

pub fn parse_friendly_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows: Vec<String> = FRIENDLY_TEXTS
        .iter()
        .map(|input| parse_row(input))
        .collect();
    for (index, label) in FRIENDLY_LABELS.iter().enumerate() {
        // Alternate between the tight and the spaced spelling, and between
        // singular and plural values, which the labels do not depend on.
        let input = match index % 3 {
            0 => format!("1{label}"),
            1 => format!("2 {label}"),
            _ => format!("3 {label} ago"),
        };
        rows.push(parse_row(&input));
    }
    while rows.len() < 480 {
        let span = printable(rng)?;
        let mut input = friendly::arbitrary_config(rng)
            .printer()
            .span_to_string(&span);
        if rng.range(0, 2) != 0 {
            input = friendly::mangle(rng, &input, "ydhmsuno0123456789.,:-+ ag");
        }
        if usable(&input) {
            rows.push(parse_row(&input));
        }
    }
    Ok(rows)
}

fn multiply_row(span: Span, factor: i64) -> String {
    row([
        text::span(&span),
        factor.to_string(),
        or_err(span.checked_mul(factor), show),
    ])
}

pub fn multiply_rows(rng: &mut Rng) -> Result<Vec<String>> {
    const FACTORS: [i64; 16] = [
        0,
        1,
        -1,
        2,
        -2,
        3,
        7,
        -10,
        60,
        1_000,
        19_998,
        19_999,
        1_000_000_000,
        i64::MAX,
        i64::MIN,
        i64::MIN + 1,
    ];
    let mut rows = Vec::new();
    for units in PRINT_EDGES.iter().step_by(3) {
        let span = gen::span_of(units)?;
        for factor in [0, 1, -1, 2, i64::MIN] {
            rows.push(multiply_row(span, factor));
        }
    }
    // Each unit at half its limit and one above: doubling is the boundary.
    for (index, limit) in gen::SPAN_LIMITS.into_iter().enumerate() {
        for value in [limit / 2, limit / 2 + 1, -(limit / 2), -(limit / 2) - 1] {
            let span = gen::set_unit(Span::new(), index, value)?;
            rows.push(multiply_row(span, 2));
            rows.push(multiply_row(span, -2));
        }
    }
    while rows.len() < 320 {
        let span = match rng.range(0, 3) {
            0 => gen::span(rng, &gen::ALL_UNITS, 4, i64::MAX)?,
            _ => gen::span(rng, &gen::ALL_UNITS, 4, 5_000)?,
        };
        let factor = match rng.range(0, 3) {
            0 => *rng.pick(&FACTORS),
            1 => rng.range(-10, 10),
            _ => rng.range(-100_000, 100_000),
        };
        rows.push(multiply_row(span, factor));
    }
    Ok(rows)
}

fn setter_row(setters: &UnitValues) -> String {
    let names: Vec<String> = setters
        .iter()
        .map(|&(index, value)| format!("{}={value}", LABELS[index]))
        .collect();
    gen::span_of(setters).map_or_else(
        |_| row([names.join(";"), text::ERR.to_owned()]),
        |span| {
            row([
                names.join(";"),
                text::span(&span),
                span.signum().to_string(),
            ])
        },
    )
}

pub fn setter_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    // A negative value makes the whole span negative, a positive value keeps
    // the sign the span has, and zero changes nothing unless it empties the
    // span.
    let sequences: &[&UnitValues] = &[
        &[(0, 1)],
        &[(0, -1)],
        &[(0, 0)],
        &[(0, 1), (1, 2)],
        &[(0, -1), (1, 2)],
        &[(0, 1), (1, -2)],
        &[(0, -1), (1, -2)],
        &[(0, -1), (1, 0)],
        &[(0, 1), (1, 0)],
        &[(0, -1), (0, 0)],
        &[(0, 1), (0, 0)],
        &[(0, -1), (0, 1)],
        &[(0, 1), (0, -1)],
        &[(0, -1), (1, -2), (0, 0)],
        &[(0, -1), (1, -2), (0, 0), (1, 0)],
        &[(0, -1), (1, -2), (0, 0), (1, 0), (3, 5)],
        &[(0, -1), (1, 2), (3, -3)],
        &[(0, -1), (1, 2), (3, 3)],
        &[(9, -1), (0, 1)],
        &[(9, 1), (0, -1)],
        &[(4, 0), (5, 0), (6, -1)],
        &[(4, 0), (5, 0), (6, 0)],
        &[(4, -5), (4, 5), (4, 0)],
        &[(4, -5), (5, -5), (4, 5)],
        &[(4, -5), (5, -5), (4, 0)],
        &[(4, -5), (5, -5), (4, 0), (5, 3)],
        &[(9, i64::MAX)],
        &[(9, -i64::MAX)],
        &[(9, i64::MIN)],
        &[(0, i64::MIN)],
        &[(0, i64::MAX)],
    ];
    for setters in sequences {
        rows.push(setter_row(setters));
    }
    // Every unit at its limit and one past it, in both directions.
    for (index, limit) in gen::SPAN_LIMITS.into_iter().enumerate() {
        rows.push(setter_row(&[(index, limit)]));
        rows.push(setter_row(&[(index, -limit)]));
        if limit != i64::MAX {
            rows.push(setter_row(&[(index, limit + 1)]));
            rows.push(setter_row(&[(index, -limit - 1)]));
            rows.push(setter_row(&[(index, -1), (index, limit + 1)]));
        }
    }
    while rows.len() < 320 {
        let mut setters = Vec::new();
        for _ in 0..rng.range(1, 6) {
            let index = usize::try_from(rng.range(0, 9))?;
            let value = match rng.range(0, 11) {
                0..=2 => 0,
                3..=6 => rng.range(-9, 9),
                7..=9 => rng.range(-19_998, 19_998),
                _ => rng.range(-300_000, 300_000),
            };
            setters.push((index, value));
        }
        rows.push(setter_row(&setters));
    }
    Ok(rows)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_empty_input_has_a_spelling_of_its_own() {
        assert_eq!(parse_row("<empty>"), "<empty>|ERR|ERR|ERR");
        assert!(!usable(""));
        assert!(!usable("a|b"));
        assert!(!usable("<empty>"));
        assert!(usable("P1D"));
    }

    #[test]
    fn parse_rows_record_each_parser_separately() {
        assert_eq!(parse_row("P1D"), "P1D|1d|ERR|1d");
        assert_eq!(parse_row("1 day"), "1 day|ERR|1d|1d");
    }

    #[test]
    fn setter_rows_stop_at_the_first_error() {
        assert_eq!(setter_row(&[(0, 19_999), (1, 1)]), "y=19999;mo=1|ERR");
        assert_eq!(setter_row(&[(0, -1), (1, 2)]), "y=-1;mo=2|-1y -2mo|-1");
    }

    #[test]
    fn hand_written_inputs_fit_in_a_row() {
        for input in ISO_TEXTS.iter().chain(FRIENDLY_TEXTS) {
            assert!(!input.contains('|'), "{input}");
            assert!(!input.is_empty());
        }
    }
}
